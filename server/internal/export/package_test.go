package export

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/obhijatra/obhijatra/server/internal/xform"
)

func opener(s string) Opener {
	return func() (io.ReadCloser, error) { return io.NopCloser(strings.NewReader(s)), nil }
}

func sum(s string) string { h := sha256.Sum256([]byte(s)); return hex.EncodeToString(h[:]) }

func sub(id, instanceID string, media ...Media) Submission {
	xml := strings.Replace(instance, "uuid:abc", instanceID, 1)
	return Submission{ID: id, Meta: Metadata{InstanceID: instanceID, FormVersion: "2026110601"}, XML: opener(xml), Media: media}
}

// The package holds what Prepare listed even if more submissions arrive
// before it is written, every file is in the manifest with its SHA-256,
// and two different files with one name both survive.
func TestPackage(t *testing.T) {
	fields, err := xform.ParseFields(strings.NewReader(form))
	if err != nil {
		t.Fatal(err)
	}
	store := []Submission{
		sub("r1", "uuid:one", Media{Name: "1700000000.jpg", SHA256: sum("photo one"), Open: opener("photo one")}),
		sub("r2", "uuid:two", Media{Name: "1700000000.jpg", SHA256: sum("photo two"), Open: opener("photo two")}),
	}
	p := &Package{
		FormID: "household_visit", FormTitle: "Household visit", Fields: fields, ColumnsVersion: "2026110601",
		Versions:     []FormVersion{{Version: "2026110601", XML: opener(form)}},
		Organisation: "Sample Development Society", ExportedAt: time.Date(2026, 11, 6, 9, 0, 0, 0, time.UTC),
		ExportedBy: map[string]string{"id": "u1", "name": "Admin", "role": "org_admin"},
		Filters:    map[string]any{}, IncludeMedia: true,
		Each: func(fn func(Submission) error) error {
			for _, s := range store {
				if err := fn(s); err != nil {
					return err
				}
			}
			return nil
		},
		Reload: func(ids []string) ([]Submission, error) {
			var out []Submission
			for _, id := range ids {
				for _, s := range store {
					if s.ID == id {
						out = append(out, s)
					}
				}
			}
			return out, nil
		},
	}
	pr, err := p.Prepare(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer pr.Close()
	if pr.Count != 2 || pr.Files != 2 {
		t.Errorf("count %d, files %d", pr.Count, pr.Files)
	}
	store = append(store, sub("r3", "uuid:late")) // arrives after Prepare

	var buf bytes.Buffer
	manifestSum, err := pr.Write(&buf)
	if err != nil {
		t.Fatal(err)
	}

	z, err := zip.NewReader(bytes.NewReader(buf.Bytes()), int64(buf.Len()))
	if err != nil {
		t.Fatal(err)
	}
	contents := map[string]string{}
	var names []string
	for _, f := range z.File {
		rc, _ := f.Open()
		b, _ := io.ReadAll(rc)
		rc.Close()
		contents[f.Name] = string(b)
		names = append(names, f.Name)
	}
	want := []string{
		"household_visit.csv", "household_visit-members.csv", "household_visit-phones.csv",
		"forms/household_visit_2026110601.xml",
		"submissions/uuid_one.xml", "submissions/uuid_two.xml",
		"media/1700000000.jpg", "media/uuid_two/1700000000.jpg",
		"README.txt", "manifest.json",
	}
	if strings.Join(names, "\n") != strings.Join(want, "\n") {
		t.Fatalf("files:\n%s", strings.Join(names, "\n"))
	}
	if contents["media/1700000000.jpg"] != "photo one" || contents["media/uuid_two/1700000000.jpg"] != "photo two" {
		t.Error("media contents")
	}
	if strings.Contains(contents["household_visit.csv"], "uuid:late") {
		t.Error("a submission that arrived after Prepare is in the tables")
	}

	if sum(contents["manifest.json"]) != manifestSum {
		t.Error("Write returned another manifest SHA-256")
	}
	var m struct {
		Submissions int `json:"submissions"`
		MediaFiles  int `json:"media_files"`
		Files       []struct {
			Path   string `json:"path"`
			Bytes  int64  `json:"bytes"`
			SHA256 string `json:"sha256"`
		} `json:"files"`
		Warnings []string `json:"warnings"`
	}
	if err := json.Unmarshal([]byte(contents["manifest.json"]), &m); err != nil {
		t.Fatal(err)
	}
	if m.Submissions != 2 || m.MediaFiles != 2 || len(m.Files) != len(want)-1 || len(m.Warnings) != 1 {
		t.Errorf("manifest: %+v", m)
	}
	for _, f := range m.Files {
		if sum(contents[f.Path]) != f.SHA256 || int64(len(contents[f.Path])) != f.Bytes {
			t.Errorf("manifest entry for %s does not match the file", f.Path)
		}
	}
}

// A media file damaged on the server is still included, with a warning.
func TestADamagedFileIsFlagged(t *testing.T) {
	fields, _ := xform.ParseFields(strings.NewReader(form))
	s := sub("r1", "uuid:one", Media{Name: "1700000000.jpg", SHA256: sum("original"), Open: opener("changed")})
	p := &Package{FormID: "f", Fields: fields, IncludeMedia: true, ExportedBy: map[string]string{},
		Each:   func(fn func(Submission) error) error { return fn(s) },
		Reload: func([]string) ([]Submission, error) { return []Submission{s}, nil }}
	pr, err := p.Prepare(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer pr.Close()
	var buf bytes.Buffer
	if _, err := pr.Write(&buf); err != nil {
		t.Fatal(err)
	}
	z, _ := zip.NewReader(bytes.NewReader(buf.Bytes()), int64(buf.Len()))
	for _, f := range z.File {
		if f.Name == "manifest.json" {
			rc, _ := f.Open()
			b, _ := io.ReadAll(rc)
			if !strings.Contains(string(b), "may have been damaged") {
				t.Errorf("no warning: %s", b)
			}
		}
	}
}
