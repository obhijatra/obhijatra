// Package export builds the download package of a form's submissions
// (docs/decisions/0009-data-export.md): CSV tables in ODK Central's layout,
// the media files, each submission's original XML, the form's XML and a
// manifest with the SHA-256 of every file.
package export

import (
	"encoding/xml"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"

	"github.com/obhijatra/obhijatra/server/internal/schema"
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
	out                  *csvWriter
}

// MaxRepeatRows is the most repeat rows one submission writes to the
// tables. Real forms have far fewer; the limit stops one hostile
// submission from filling the server's disk during an export. Rows beyond
// it are left out with a warning; the submission's XML keeps them.
const MaxRepeatRows = 20000

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
	byPath  map[string]*Table // repeat path -> its table
	columns map[string]column // field path -> column
	fields  map[string]xform.Field
	binary  map[string]bool // paths of binary (media) fields

	// Warnings collects what a reader of the package should know.
	Warnings []string

	meta struct {
		key, submitterID, submitterName, present, expected, status, review, device, edits, version int
	}
}

// NewTables lays out the tables for a form's fields, which must be in
// document order (xform.ParseFields). Each table writes to the writer open
// returns for its file name.
func NewTables(formID string, fields []xform.Field, open func(name string) (io.Writer, error)) (*Tables, error) {
	t := &Tables{formID: formID, byPath: map[string]*Table{}, columns: map[string]column{},
		fields: map[string]xform.Field{}, binary: map[string]bool{}}
	t.root = &Table{Name: SafeName(formID) + ".csv", Header: []string{"SubmissionDate"}}
	t.tables = []*Table{t.root}

	var repeats []*Table
	for _, f := range fields {
		if f.Kind == xform.KindRepeat {
			r := &Table{Path: f.Path}
			repeats = append(repeats, r)
			t.tables = append(t.tables, r)
			t.byPath[f.Path] = r
		}
	}
	for _, f := range fields {
		t.fields[f.Path] = f
		if f.Kind != xform.KindValue {
			continue
		}
		// A value belongs to the table of its nearest enclosing repeat.
		tb := t.root
		for p := parentOf(f.Path); p != ""; p = parentOf(p) {
			if r, ok := t.byPath[p]; ok {
				tb = r
				break
			}
		}
		base := strings.ReplaceAll(strings.TrimPrefix(f.Path[len(tb.Path):], "/"), "/", "-")
		c := column{table: tb, idx: len(tb.Header)}
		if f.Type == "geopoint" {
			c.geopoint = true
			tb.Header = append(tb.Header, base+"-Latitude", base+"-Longitude", base+"-Altitude", base+"-Accuracy")
		} else {
			tb.Header = append(tb.Header, base)
		}
		if f.Type == "binary" {
			t.binary[f.Path] = true
		}
		t.columns[f.Path] = c
	}
	for _, r := range repeats {
		r.parentKeyIdx = len(r.Header)
		r.keyIdx = len(r.Header) + 1
		r.Header = append(r.Header, "PARENT_KEY", "KEY")
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
	// share a name, and never two tables with one file name.
	totals := map[string]int{}
	for _, r := range repeats {
		totals[nameOf(r.Path)]++
	}
	counts := map[string]int{}
	used := map[string]bool{strings.ToLower(t.root.Name): true}
	for _, r := range repeats {
		n := nameOf(r.Path)
		base := formID + "-" + n
		if totals[n] > 1 {
			counts[n]++
			base = fmt.Sprintf("%s-%s~%d", formID, n, counts[n])
		}
		name := SafeName(base) + ".csv"
		for i := 2; used[strings.ToLower(name)]; i++ {
			name = SafeName(fmt.Sprintf("%s~%d", base, i)) + ".csv"
		}
		used[strings.ToLower(name)] = true
		r.Name = name
	}

	for _, tb := range t.tables {
		w, err := open(tb.Name)
		if err != nil {
			return nil, err
		}
		tb.out = &csvWriter{w: w}
		if _, err := io.WriteString(w, utf8BOM); err != nil {
			return nil, err
		}
		if err := tb.out.write(tb.Header); err != nil {
			return nil, err
		}
	}
	return t, nil
}

// All returns every table, the root first.
func (t *Tables) All() []*Table { return t.tables }

// frame is one open element while a submission is read. Elements outside
// the form share one frame and carry no path, so hostile nesting costs
// nothing.
type frame struct {
	path   string
	field  xform.Field
	known  bool
	row    []strings.Builder // the row values of this frame write to
	table  *Table            // set for a repeat frame
	key    string            // ODK Central's key path of this element
	ctx    *frame            // the nearest enclosing repeat, or the root
	counts map[string]int    // on a repeat or root frame: repeats seen inside it, by path
	text   strings.Builder
}

var unknownFrame = &frame{}

// open returns the frame of a child element named name of parent.
func (t *Tables) open(parent *frame, name string) *frame {
	if !parent.known {
		return unknownFrame
	}
	path := parent.path + "/" + name
	field, ok := t.fields[path]
	if !ok {
		return unknownFrame
	}
	f := &frame{path: path, field: field, known: true, row: parent.row, key: parent.key, ctx: parent.ctx}
	switch field.Kind {
	case xform.KindRepeat:
		if f.ctx.counts == nil {
			f.ctx.counts = map[string]int{}
		}
		f.ctx.counts[path]++
		f.table = t.byPath[path]
		f.row = make([]strings.Builder, len(f.table.Header))
		f.key = fmt.Sprintf("%s/%s[%d]", parent.key, field.Name, f.ctx.counts[path])
		f.row[f.table.parentKeyIdx].WriteString(f.ctx.key)
		f.row[f.table.keyIdx].WriteString(f.key)
		f.ctx = f
	case xform.KindStructure:
		f.key = parent.key + "/" + field.Name
	}
	return f
}

// MediaNames returns the file names the XML gives as answers to media
// questions, in order, without repeats.
func (t *Tables) MediaNames(instanceXML io.Reader) ([]string, error) {
	var names []string
	seen := map[string]bool{}
	r := xform.NewTokenReader(instanceXML)
	var stack []*frame
	for {
		tok, err := r.Next()
		if err == io.EOF {
			return names, nil
		}
		if err != nil {
			return nil, err
		}
		switch e := tok.(type) {
		case xml.StartElement:
			if len(stack) == 0 {
				stack = append(stack, &frame{known: true})
				continue
			}
			parent := stack[len(stack)-1]
			f := unknownFrame
			if parent.known {
				if p := parent.path + "/" + e.Name.Local; t.fields[p].Kind != "" {
					f = &frame{path: p, known: true, field: t.fields[p]}
				}
			}
			stack = append(stack, f)
		case xml.CharData:
			if len(stack) == 0 {
				continue // white space around the root element
			}
			if f := stack[len(stack)-1]; f.known && t.binary[f.path] {
				f.text.Write(e)
			}
		case xml.EndElement:
			f := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			if f.known && t.binary[f.path] {
				if n := strings.TrimSpace(f.text.String()); n != "" && !seen[n] {
					seen[n] = true
					names = append(names, n)
				}
			}
		}
	}
}

// Add writes one submission: its root row and the rows of its repeats.
func (t *Tables) Add(instanceXML io.Reader, m Metadata) error {
	root := &frame{known: true, row: make([]strings.Builder, len(t.root.Header)), key: m.InstanceID}
	root.ctx = root
	r := xform.NewTokenReader(instanceXML)
	var stack []*frame
	repeatRows, dropped := 0, 0

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
				stack = append(stack, root)
				continue
			}
			stack = append(stack, t.open(stack[len(stack)-1], e.Name.Local))
		case xml.CharData:
			if len(stack) > 0 {
				if f := stack[len(stack)-1]; f.known && f.field.Kind == xform.KindValue {
					f.text.Write(e)
				}
			}
		case xml.EndElement:
			f := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			if !f.known || f == root {
				continue
			}
			switch f.field.Kind {
			case xform.KindRepeat:
				if repeatRows >= MaxRepeatRows {
					dropped++
					continue
				}
				repeatRows++
				if err := f.table.write(f.row); err != nil {
					return err
				}
			case xform.KindValue:
				c := t.columns[f.path]
				if c.geopoint {
					parts := strings.Fields(f.text.String())
					for i := 0; i < 4; i++ {
						f.row[c.idx+i].Reset()
						if i < len(parts) {
							f.row[c.idx+i].WriteString(parts[i])
						}
					}
				} else {
					f.row[c.idx].WriteString(f.text.String())
				}
			}
		}
	}
	if dropped > 0 {
		t.Warnings = append(t.Warnings, fmt.Sprintf(
			"%s: %d repeat entries beyond the first %d are not in the CSV files; the XML file has them all", m.InstanceID, dropped, MaxRepeatRows))
	}

	row := root.row
	set := func(i int, v string) { row[i].Reset(); row[i].WriteString(v) }
	set(0, m.SubmissionDate)
	set(t.meta.key, m.InstanceID)
	set(t.meta.submitterID, m.SubmitterID)
	set(t.meta.submitterName, m.SubmitterName)
	set(t.meta.present, strconv.Itoa(m.AttachmentsPresent))
	set(t.meta.expected, strconv.Itoa(m.AttachmentsExpected))
	set(t.meta.review, m.ReviewState)
	set(t.meta.device, m.DeviceID)
	set(t.meta.edits, "0")
	set(t.meta.version, m.FormVersion)
	return t.root.write(row)
}

// Flush is kept for callers; rows are written as they are made.
func (t *Tables) Flush() error { return nil }

func (tb *Table) write(row []strings.Builder) error {
	out := make([]string, len(row))
	for i := range row {
		out[i] = GuardFormula(row[i].String())
	}
	tb.Rows++
	return tb.out.write(out)
}

// csvWriter writes RFC 4180 records ending in CRLF. Unlike encoding/csv
// it never changes a cell: line breaks inside an answer stay as they are.
type csvWriter struct {
	w   io.Writer
	buf []byte
}

func (c *csvWriter) write(cells []string) error {
	c.buf = c.buf[:0]
	for i, v := range cells {
		if i > 0 {
			c.buf = append(c.buf, ',')
		}
		if !strings.ContainsAny(v, ",\"\r\n") {
			c.buf = append(c.buf, v...)
			continue
		}
		c.buf = append(c.buf, '"')
		c.buf = append(c.buf, strings.ReplaceAll(v, `"`, `""`)...)
		c.buf = append(c.buf, '"')
	}
	c.buf = append(c.buf, '\r', '\n')
	_, err := c.w.Write(c.buf)
	return err
}

func nameOf(path string) string { return path[strings.LastIndexByte(path, '/')+1:] }

func parentOf(path string) string {
	if i := strings.LastIndexByte(path, '/'); i > 0 {
		return path[:i]
	}
	return ""
}

// plainNumber is a decimal number as a form records one.
var plainNumber = regexp.MustCompile(`^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$`)

// GuardFormula stops a spreadsheet from running a cell as a formula
// (OWASP "CSV injection"): text that starts with =, +, -, @, a tab or a
// carriage return gets a leading apostrophe, unless it is a plain decimal
// number such as -12.5, -1.5E-4 or +8801712345678. The original XML in the
// package keeps every answer exactly as it was sent.
func GuardFormula(v string) string {
	if v == "" {
		return v
	}
	switch v[0] {
	case '=', '+', '-', '@', '\t', '\r':
		if plainNumber.MatchString(v) {
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
		case schema.UnsafeTextRune(r):
			return -1 // bidirectional and invisible characters could disguise a file's type
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
