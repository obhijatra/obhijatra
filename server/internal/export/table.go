// Package export builds the download package of a form's submissions
// (docs/decisions/0009-data-export.md): CSV tables in ODK Central's layout,
// the media files, each submission's original XML, the form's XML and a
// manifest with the SHA-256 of every file.
package export

import (
	"encoding/csv"
	"encoding/xml"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/obhijatra/obhijatra/server/internal/xform"
)

// utf8BOM starts every CSV file, so that Excel reads Bangla as UTF-8 when
// the file is opened with a double click. ODK Central writes no BOM; tools
// that read Central's files read these too.
const utf8BOM = "\ufeff"

// Metadata is what the server knows about a submission besides its XML.
type Metadata struct {
	SubmissionDate      string // RFC 3339 UTC with milliseconds, as Central writes it
	InstanceID          string
	SubmitterID         string
	SubmitterName       string
	AttachmentsPresent  int
	AttachmentsExpected int
	ReviewState         string // ODK Central's value: "", "edited", "hasIssues", "approved" or "rejected"
	DeviceID            string
	FormVersion         string
}

// column is where a value field goes: its table and first column.
type column struct {
	table    *Table
	idx      int
	geopoint bool
}

// Table is one CSV file: the submissions themselves, or one repeat group.
type Table struct {
	// Name is the file name in the package, for example "household.csv" or
	// "household-members.csv", as ODK Central names them.
	Name   string
	Path   string // the repeat's path; "" for the root table
	Header []string
	Rows   int

	parentKeyIdx, keyIdx int
	out                  *csv.Writer
}

// Tables turns submissions into CSV rows in ODK Central's layout
// (central-backend lib/data/briefcase.js, groupPaths on, select multiples
// not split): one root table and one table per repeat group, with
// SubmissionDate first and Central's metadata columns last in the root
// table, PARENT_KEY and KEY last in each repeat table, geopoints in four
// columns, and repeat keys such as "uuid:…/members[2]".
type Tables struct {
	formID  string
	root    *Table
	tables  []*Table
	columns map[string]column // field path -> column
	fields  map[string]xform.Field
	binary  map[string]bool // paths of binary (media) fields

	meta struct {
		key, submitterID, submitterName, present, expected, status, review, device, edits, version int
	}
}

// NewTables lays out the tables for a form's fields. Each table writes to
// the writer open returns for its file name.
func NewTables(formID string, fields []xform.Field, open func(name string) (io.Writer, error)) (*Tables, error) {
	t := &Tables{formID: formID, columns: map[string]column{}, fields: map[string]xform.Field{}, binary: map[string]bool{}}
	t.root = &Table{Name: SafeName(formID) + ".csv", Header: []string{"SubmissionDate"}}
	t.tables = []*Table{t.root}
	stack := []*Table{t.root}

	var repeats []*Table
	for i, f := range fields {
		t.fields[f.Path] = f
		top := stack[len(stack)-1]
		switch f.Kind {
		case xform.KindRepeat:
			r := &Table{Path: f.Path}
			repeats = append(repeats, r)
			t.tables = append(t.tables, r)
			stack = append(stack, r)
		case xform.KindStructure:
		default:
			base := strings.ReplaceAll(strings.TrimPrefix(f.Path[len(top.Path):], "/"), "/", "-")
			c := column{table: top, idx: len(top.Header)}
			if f.Type == "geopoint" {
				c.geopoint = true
				top.Header = append(top.Header, base+"-Latitude", base+"-Longitude", base+"-Altitude", base+"-Accuracy")
			} else {
				top.Header = append(top.Header, base)
			}
			if f.Type == "binary" {
				t.binary[f.Path] = true
			}
			t.columns[f.Path] = c
		}

		// Close the repeats the next field is not inside.
		var next *xform.Field
		if i+1 < len(fields) {
			next = &fields[i+1]
		}
		for len(stack) > 1 && (next == nil || !strings.HasPrefix(next.Path, stack[len(stack)-1].Path+"/")) {
			r := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			r.parentKeyIdx = len(r.Header)
			r.keyIdx = len(r.Header) + 1
			r.Header = append(r.Header, "PARENT_KEY", "KEY")
		}
	}

	h := &t.root.Header
	add := func(name string) int { *h = append(*h, name); return len(*h) - 1 }
	t.meta.key = add("KEY")
	t.meta.submitterID = add("SubmitterID")
	t.meta.submitterName = add("SubmitterName")
	t.meta.present = add("AttachmentsPresent")
	t.meta.expected = add("AttachmentsExpected")
	t.meta.status = add("Status")
	t.meta.review = add("ReviewState")
	t.meta.device = add("DeviceID")
	t.meta.edits = add("Edits")
	t.meta.version = add("FormVersion")

	// File names: <form>-<repeat>.csv, with ~1, ~2 … when two repeats
	// share a name.
	totals := map[string]int{}
	for _, r := range repeats {
		totals[nameOf(r.Path)]++
	}
	counts := map[string]int{}
	for _, r := range repeats {
		n := nameOf(r.Path)
		if totals[n] > 1 {
			counts[n]++
			r.Name = SafeName(fmt.Sprintf("%s-%s~%d", formID, n, counts[n])) + ".csv"
		} else {
			r.Name = SafeName(formID+"-"+n) + ".csv"
		}
	}

	for _, tb := range t.tables {
		w, err := open(tb.Name)
		if err != nil {
			return nil, err
		}
		if _, err := io.WriteString(w, utf8BOM); err != nil {
			return nil, err
		}
		tb.out = csv.NewWriter(w)
		tb.out.UseCRLF = true
		if err := tb.out.Write(tb.Header); err != nil {
			return nil, err
		}
	}
	return t, nil
}

// All returns every table, the root first.
func (t *Tables) All() []*Table { return t.tables }

// MediaNames returns the file names the XML gives as answers to media
// questions, in order, without repeats.
func (t *Tables) MediaNames(instanceXML io.Reader) ([]string, error) {
	var names []string
	seen := map[string]bool{}
	err := walk(instanceXML, func(path string, text string) {
		if t.binary[path] {
			if n := strings.TrimSpace(text); n != "" && !seen[n] {
				seen[n] = true
				names = append(names, n)
			}
		}
	})
	return names, err
}

// Add writes one submission: its root row and the rows of its repeats.
func (t *Tables) Add(instanceXML io.Reader, m Metadata) error {
	type frame struct {
		path      string
		known     bool
		field     xform.Field
		row       []string // the row values of this frame write to
		table     *Table   // set for a repeat frame
		key       string   // ODK Central's key path of this element
		repeatKey string   // the key of the nearest enclosing repeat, or the instance id
		counts    map[string]int
		text      strings.Builder
	}

	rootRow := make([]string, len(t.root.Header))
	r := xform.NewTokenReader(instanceXML)
	var stack []*frame

	for {
		tok, err := r.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		switch e := tok.(type) {
		case xml.StartElement:
			if len(stack) == 0 {
				stack = append(stack, &frame{known: true, row: rootRow, key: m.InstanceID, repeatKey: m.InstanceID})
				continue
			}
			parent := stack[len(stack)-1]
			f := &frame{path: parent.path + "/" + e.Name.Local}
			field, ok := t.fields[f.path]
			if !parent.known || !ok {
				stack = append(stack, f) // not in the form: skipped, like Central
				continue
			}
			f.known, f.field = true, field
			f.row, f.key, f.repeatKey = parent.row, parent.key, parent.repeatKey
			switch field.Kind {
			case xform.KindRepeat:
				if parent.counts == nil {
					parent.counts = map[string]int{}
				}
				parent.counts[f.path]++
				f.table = t.tableFor(f.path)
				f.row = make([]string, len(f.table.Header))
				f.key = fmt.Sprintf("%s/%s[%d]", parent.key, field.Name, parent.counts[f.path])
				f.row[f.table.parentKeyIdx] = parent.repeatKey
				f.row[f.table.keyIdx] = f.key
				f.repeatKey = f.key
			case xform.KindStructure:
				f.key = parent.key + "/" + field.Name
			}
			stack = append(stack, f)
		case xml.CharData:
			if len(stack) > 0 {
				if f := stack[len(stack)-1]; f.known && f.field.Kind == xform.KindValue {
					f.text.Write(e)
				}
			}
		case xml.EndElement:
			f := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			if !f.known || f.path == "" {
				continue
			}
			switch f.field.Kind {
			case xform.KindRepeat:
				if err := f.table.write(f.row); err != nil {
					return err
				}
			case xform.KindValue:
				c := t.columns[f.path]
				text := f.text.String()
				if c.geopoint {
					parts := strings.Fields(text)
					for i := 0; i < 4 && i < len(parts); i++ {
						f.row[c.idx+i] = parts[i]
					}
				} else {
					f.row[c.idx] = f.row[c.idx] + text
				}
			}
		}
	}

	rootRow[0] = m.SubmissionDate
	rootRow[t.meta.key] = m.InstanceID
	rootRow[t.meta.submitterID] = m.SubmitterID
	rootRow[t.meta.submitterName] = m.SubmitterName
	rootRow[t.meta.present] = strconv.Itoa(m.AttachmentsPresent)
	rootRow[t.meta.expected] = strconv.Itoa(m.AttachmentsExpected)
	rootRow[t.meta.review] = m.ReviewState
	rootRow[t.meta.device] = m.DeviceID
	rootRow[t.meta.edits] = "0"
	rootRow[t.meta.version] = m.FormVersion
	return t.root.write(rootRow)
}

// Flush writes out what the CSV writers hold.
func (t *Tables) Flush() error {
	for _, tb := range t.tables {
		tb.out.Flush()
		if err := tb.out.Error(); err != nil {
			return err
		}
	}
	return nil
}

func (t *Tables) tableFor(path string) *Table {
	for _, tb := range t.tables {
		if tb.Path == path {
			return tb
		}
	}
	return nil
}

func (tb *Table) write(row []string) error {
	out := make([]string, len(row))
	for i, v := range row {
		out[i] = GuardFormula(v)
	}
	tb.Rows++
	return tb.out.Write(out)
}

// walk calls fn with the path below the root and the text of every element
// of an instance (text split across tokens is joined).
func walk(instanceXML io.Reader, fn func(path, text string)) error {
	r := xform.NewTokenReader(instanceXML)
	var path []string
	var texts []*strings.Builder
	for {
		tok, err := r.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		switch e := tok.(type) {
		case xml.StartElement:
			path = append(path, e.Name.Local)
			texts = append(texts, &strings.Builder{})
		case xml.CharData:
			if len(texts) > 0 {
				texts[len(texts)-1].Write(e)
			}
		case xml.EndElement:
			if len(path) > 1 {
				fn("/"+strings.Join(path[1:], "/"), texts[len(texts)-1].String())
			}
			path, texts = path[:len(path)-1], texts[:len(texts)-1]
		}
	}
}

func nameOf(path string) string { return path[strings.LastIndexByte(path, '/')+1:] }

// GuardFormula stops a spreadsheet from running a cell as a formula
// (OWASP "CSV injection"): text that starts with =, +, -, @, a tab or a
// carriage return gets a leading apostrophe, unless it is a plain number
// such as -12.5 or +8801712345678. The original XML in the package keeps
// every answer exactly as it was sent.
func GuardFormula(v string) string {
	if v == "" {
		return v
	}
	switch v[0] {
	case '=', '+', '-', '@', '\t', '\r':
		if _, err := strconv.ParseFloat(v, 64); err == nil && !strings.ContainsAny(v, "eExXpP") {
			return v
		}
		return "'" + v
	}
	return v
}

// SafeName makes a file name safe on every operating system, as ODK
// Central's sanitize-filename does: characters / \ ? < > : * | " and
// control characters are removed, and so are leading and trailing dots and
// spaces; a name that would be empty becomes "_".
func SafeName(s string) string {
	s = strings.Map(func(r rune) rune {
		switch {
		case r < 0x20, r == 0x7f, r >= 0x80 && r < 0xa0:
			return -1
		case strings.ContainsRune(`/\?<>:*|"`, r):
			return -1
		}
		return r
	}, s)
	s = strings.Trim(s, ". ")
	switch strings.ToUpper(strings.SplitN(s, ".", 2)[0]) {
	case "CON", "PRN", "AUX", "NUL",
		"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
		"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9":
		s = "_" + s
	}
	if s == "" {
		return "_"
	}
	if len(s) > 200 {
		s = strings.ToValidUTF8(s[:200], "")
	}
	return s
}
