package export

import (
	"archive/zip"
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/obhijatra/obhijatra/server/internal/xform"
)

// FormatVersion is the version of the package layout in manifest.json.
const FormatVersion = 1

// Opener opens a stored file for reading.
type Opener func() (io.ReadCloser, error)

// Media is one file a submission sent with its XML.
type Media struct {
	Name   string // the name the XML refers to
	SHA256 string // as recorded when the file arrived
	Open   Opener
}

// Submission is one submission to export.
type Submission struct {
	ID    string // the server's record id
	Meta  Metadata
	XML   Opener
	Media []Media // what the server holds, whether or not the XML refers to it
}

// FormVersion is one version of the form whose XML goes in the package.
type FormVersion struct {
	Version string
	XML     Opener
}

// Package describes one download.
type Package struct {
	FormID    string
	FormTitle string
	// Fields lays out the CSV tables; ODK Central uses the newest
	// version's fields, and so does Obhijatra.
	Fields         []xform.Field
	ColumnsVersion string
	Versions       []FormVersion

	Organisation string
	ExportedAt   time.Time
	ExportedBy   map[string]string // id, name, role
	Device       string
	Filters      map[string]any
	IncludeMedia bool

	ServerVersion string
	SchemaVersion int

	// Each calls fn for every submission to export (Prepare).
	Each func(fn func(Submission) error) error
	// Reload returns the submissions with these ids, in this order
	// (Write), so the files match the tables even if submissions arrive
	// or change between the two passes.
	Reload func(ids []string) ([]Submission, error)
}

// reloadBatch is how many submissions Write reloads at once.
const reloadBatch = 200

// Prepared is a package whose tables are written and whose numbers are
// known, ready to stream.
type Prepared struct {
	p        *Package
	dir      string
	tables   []*Table
	Count    int // submissions
	Files    int // media files to include
	warnings []string
}

// Prepare writes the CSV tables to files in a new folder inside tempDir
// and counts what the package will hold. Nothing has been sent yet, so an
// error here can still become a normal error response. Call Close when
// done.
func (p *Package) Prepare(tempDir string) (*Prepared, error) {
	dir, err := os.MkdirTemp(tempDir, "export-")
	if err != nil {
		return nil, err
	}
	pr := &Prepared{p: p, dir: dir}
	var files []*os.File
	defer func() {
		for _, f := range files {
			_ = f.Close()
		}
	}()

	ids, err := os.Create(filepath.Join(dir, "ids"))
	if err != nil {
		pr.Close()
		return nil, err
	}
	files = append(files, ids)

	tables, err := NewTables(p.FormID, p.Fields, func(name string) (io.Writer, error) {
		f, err := os.Create(filepath.Join(dir, name))
		if err != nil {
			return nil, err
		}
		files = append(files, f)
		return f, nil
	})
	if err != nil {
		pr.Close()
		return nil, err
	}

	err = p.Each(func(s Submission) error {
		rc, err := s.XML()
		if err != nil {
			return fmt.Errorf("submission %s: %w", s.Meta.InstanceID, err)
		}
		defer rc.Close()
		body, err := io.ReadAll(rc)
		if err != nil {
			return fmt.Errorf("submission %s: %w", s.Meta.InstanceID, err)
		}
		names, err := tables.MediaNames(bytes.NewReader(body))
		if err != nil {
			return fmt.Errorf("submission %s: %w", s.Meta.InstanceID, err)
		}
		held := map[string]bool{}
		for _, m := range s.Media {
			held[m.Name] = true
		}
		s.Meta.AttachmentsExpected = len(names)
		for _, n := range names {
			if held[n] {
				s.Meta.AttachmentsPresent++
			}
		}
		if p.IncludeMedia {
			pr.Files += len(s.Media)
		}
		pr.Count++
		if _, err := io.WriteString(ids, s.ID+"\n"); err != nil {
			return err
		}
		return tables.Add(bytes.NewReader(body), s.Meta)
	})
	if err == nil {
		err = tables.Flush()
	}
	if err != nil {
		pr.Close()
		return nil, err
	}
	pr.tables = tables.All()
	return pr, nil
}

// reload calls fn for every submission Prepare listed, in its order.
func (pr *Prepared) reload(fn func(Submission) error) error {
	f, err := os.Open(filepath.Join(pr.dir, "ids"))
	if err != nil {
		return err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	batch := make([]string, 0, reloadBatch)
	flush := func() error {
		if len(batch) == 0 {
			return nil
		}
		subs, err := pr.p.Reload(batch)
		if err != nil {
			return err
		}
		if len(subs) != len(batch) {
			return fmt.Errorf("%d of %d submissions could not be read again", len(batch)-len(subs), len(batch))
		}
		for _, s := range subs {
			if err := fn(s); err != nil {
				return err
			}
		}
		batch = batch[:0]
		return nil
	}
	for sc.Scan() {
		batch = append(batch, sc.Text())
		if len(batch) == reloadBatch {
			if err := flush(); err != nil {
				return err
			}
		}
	}
	if err := sc.Err(); err != nil {
		return err
	}
	return flush()
}

// Close removes the prepared tables.
func (pr *Prepared) Close() { _ = os.RemoveAll(pr.dir) }

// fileEntry is one line of the manifest's file list.
type fileEntry struct {
	Path   string `json:"path"`
	Bytes  int64  `json:"bytes"`
	SHA256 string `json:"sha256"`
}

// Write streams the package as a zip file to w and returns the SHA-256 of
// its manifest.json.
func (pr *Prepared) Write(w io.Writer) (string, error) {
	p := pr.p
	z := zip.NewWriter(w)
	var list []fileEntry
	modified := p.ExportedAt

	add := func(name string, method uint16, r io.Reader) (string, error) {
		fw, err := z.CreateHeader(&zip.FileHeader{Name: name, Method: method, Modified: modified})
		if err != nil {
			return "", err
		}
		h := sha256.New()
		n, err := io.Copy(io.MultiWriter(fw, h), r)
		if err != nil {
			return "", fmt.Errorf("%s: %w", name, err)
		}
		sum := hex.EncodeToString(h.Sum(nil))
		list = append(list, fileEntry{Path: name, Bytes: n, SHA256: sum})
		return sum, nil
	}
	addOpened := func(name string, method uint16, open Opener) (string, error) {
		rc, err := open()
		if err != nil {
			return "", fmt.Errorf("%s: %w", name, err)
		}
		defer rc.Close()
		return add(name, method, rc)
	}

	// 1. The CSV tables, root first.
	for _, t := range pr.tables {
		if _, err := addOpened(t.Name, zip.Deflate, func() (io.ReadCloser, error) {
			return os.Open(filepath.Join(pr.dir, t.Name))
		}); err != nil {
			return "", err
		}
	}

	// 2. The form's XML, each version once.
	for _, v := range p.Versions {
		name := "forms/" + SafeName(p.FormID+"_"+v.Version) + ".xml"
		if _, err := addOpened(name, zip.Deflate, v.XML); err != nil {
			return "", err
		}
	}

	// 3. Each submission's XML as it arrived, and 4. its media files.
	mediaAt := map[string]string{} // path in the package -> SHA-256
	var media []struct {
		path, want string
		open       Opener
	}
	err := pr.reload(func(s Submission) error {
		name := "submissions/" + SafeName(strings.ReplaceAll(s.Meta.InstanceID, ":", "_")) + ".xml"
		if _, err := addOpened(name, zip.Deflate, s.XML); err != nil {
			return err
		}
		if !p.IncludeMedia {
			return nil
		}
		for _, m := range s.Media {
			path := "media/" + SafeName(m.Name)
			if sum, taken := mediaAt[path]; taken && sum != m.SHA256 {
				// Two submissions sent different files with one name:
				// the second goes in a folder of its own.
				path = "media/" + SafeName(strings.ReplaceAll(s.Meta.InstanceID, ":", "_")) + "/" + SafeName(m.Name)
				pr.warnings = append(pr.warnings, fmt.Sprintf(
					"%s: another submission sent a different file called %q, so this one is at %s", s.Meta.InstanceID, m.Name, path))
			} else if taken {
				continue // the very same file, already included
			}
			mediaAt[path] = m.SHA256
			media = append(media, struct {
				path, want string
				open       Opener
			}{path, m.SHA256, m.Open})
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	for _, m := range media {
		sum, err := addOpened(m.path, zip.Store, m.open)
		if err != nil {
			return "", err
		}
		if m.want != "" && sum != m.want {
			pr.warnings = append(pr.warnings, fmt.Sprintf(
				"%s: the file's SHA-256 is not the one recorded when it arrived; it may have been damaged on the server", m.path))
		}
	}

	// 5. A plain-language description.
	if _, err := add("README.txt", zip.Deflate, strings.NewReader(readme(p, pr))); err != nil {
		return "", err
	}

	// 6. The manifest, last, listing every other file with its SHA-256.
	tableNames := make([]string, len(pr.tables))
	for i, t := range pr.tables {
		tableNames[i] = t.Name
	}
	manifest := map[string]any{
		"format":            "obhijatra-export",
		"format_version":    FormatVersion,
		"obhijatra_version": p.ServerVersion,
		"schema_version":    p.SchemaVersion,
		"organisation":      p.Organisation,
		"form": map[string]any{
			"id":                   p.FormID,
			"title":                p.FormTitle,
			"columns_from_version": p.ColumnsVersion,
		},
		"exported_at":   p.ExportedAt.UTC().Format(time.RFC3339),
		"exported_by":   p.ExportedBy,
		"device":        p.Device,
		"filters":       p.Filters,
		"include_media": p.IncludeMedia,
		"submissions":   pr.Count,
		"media_files":   len(media),
		"tables":        tableNames,
		"csv": map[string]any{
			"layout":        "ODK Central (groupPaths on, select multiples in one column)",
			"encoding":      "UTF-8 with a byte-order mark",
			"line_endings":  "CRLF",
			"formula_guard": "a cell starting with = + - @, a tab or a carriage return, other than a plain number, starts with an apostrophe; the XML files hold the exact answers",
		},
		"files":    list,
		"warnings": nonNil(pr.warnings),
	}
	body, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(body)
	fw, err := z.CreateHeader(&zip.FileHeader{Name: "manifest.json", Method: zip.Deflate, Modified: modified})
	if err != nil {
		return "", err
	}
	if _, err := fw.Write(body); err != nil {
		return "", err
	}
	if err := z.Close(); err != nil {
		return "", err
	}
	return hex.EncodeToString(sum[:]), nil
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

func readme(p *Package, pr *Prepared) string {
	var b strings.Builder
	title := p.FormTitle
	if title == "" {
		title = p.FormID
	}
	fmt.Fprintf(&b, "Obhijatra export: %s\r\n", title)
	fmt.Fprintf(&b, "Organisation: %s\r\n", p.Organisation)
	fmt.Fprintf(&b, "Exported: %s by %s\r\n", p.ExportedAt.UTC().Format("2 January 2006 15:04 UTC"), p.ExportedBy["name"])
	fmt.Fprintf(&b, "Submissions: %d. Media files: %d.\r\n\r\n", pr.Count, pr.Files)
	b.WriteString("This file holds personal data. Keep it only as long as you need it, store it where only the right people can open it, and delete it when you are done.\r\n\r\n")
	b.WriteString("What is in it\r\n")
	fmt.Fprintf(&b, "- %s: one row per submission, in ODK Central's layout. Open it in Excel with a double click; Bangla shows correctly.\r\n", pr.tables[0].Name)
	if len(pr.tables) > 1 {
		b.WriteString("- One more CSV file per repeat group (for example household members). Each row's PARENT_KEY is the KEY of the row it belongs to.\r\n")
	}
	b.WriteString("- forms/: the form's XML (XForm), so the data can be read without Obhijatra.\r\n")
	b.WriteString("- submissions/: each submission's XML exactly as the phone sent it.\r\n")
	if p.IncludeMedia {
		b.WriteString("- media/: photos, recordings and other files sent with the submissions. The CSV files name them.\r\n")
	}
	b.WriteString("- manifest.json: who exported what, with which filters, and the SHA-256 of every file, so you can check that nothing changed.\r\n\r\n")
	fmt.Fprintf(&b, "The columns follow form version %s. Answers to questions that older versions had and this one does not are in the XML files.\r\n", p.ColumnsVersion)
	b.WriteString("To stop a spreadsheet from running an answer as a formula, an answer that starts with = + - or @ (other than a plain number) starts with an apostrophe in the CSV files. The XML files hold every answer exactly as it was sent.\r\n")
	return b.String()
}
