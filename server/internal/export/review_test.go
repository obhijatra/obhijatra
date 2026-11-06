package export

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/obhijatra/obhijatra/server/internal/xform"
)

func tablesFor(t *testing.T, formXML string) (*Tables, map[string]*bytes.Buffer) {
	t.Helper()
	fields, err := xform.ParseFields(strings.NewReader(formXML))
	if err != nil {
		t.Fatal(err)
	}
	files := map[string]*bytes.Buffer{}
	tables, err := NewTables("f", fields, func(name string) (io.Writer, error) {
		files[name] = &bytes.Buffer{}
		return files[name], nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return tables, files
}

const simpleForm = `<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
 <h:head><model><instance><data id="f">
  <name/><g><r jr:template=""><x/></r></g><meta><instanceID/></meta>
 </data></instance></model></h:head>
 <h:body><group ref="/data/g"><repeat nodeset="/data/g/r"><input ref="x"/></repeat></group></h:body>
</h:html>`

// Review finding 1: an element repeated many times is joined in linear
// time.
func TestManyCopiesOfOneAnswerAreJoinedQuickly(t *testing.T) {
	tables, files := tablesFor(t, simpleForm)
	xml := "<data id=\"f\">" + strings.Repeat("<name>xxxxxxxxxxxxxxxxxx</name>", 300000) +
		"<meta><instanceID>uuid:a</instanceID></meta></data>"
	start := time.Now()
	if err := tables.Add(strings.NewReader(xml), Metadata{InstanceID: "uuid:a"}); err != nil {
		t.Fatal(err)
	}
	if d := time.Since(start); d > 5*time.Second {
		t.Errorf("took %v", d)
	}
	if !strings.Contains(files["f.csv"].String(), strings.Repeat("x", 18*300000)) {
		t.Error("the copies were not joined, as Central joins them")
	}
}

// Review finding 3: elements outside the form cost nothing, however deep
// and long their names.
func TestDeepUnknownElementsAreCheap(t *testing.T) {
	tables, _ := tablesFor(t, simpleForm)
	name := strings.Repeat("n", 50000)
	xml := "<data id=\"f\">" + strings.Repeat("<"+name+">", 98) + strings.Repeat("</"+name+">", 98) +
		"<meta><instanceID>uuid:a</instanceID></meta></data>"
	start := time.Now()
	if err := tables.Add(strings.NewReader(xml), Metadata{InstanceID: "uuid:a"}); err != nil {
		t.Fatal(err)
	}
	if _, err := tables.MediaNames(strings.NewReader(xml)); err != nil {
		t.Fatal(err)
	}
	if d := time.Since(start); d > 5*time.Second {
		t.Errorf("took %v", d)
	}
}

// Review finding 3: one submission writes at most MaxRepeatRows repeat
// rows, with a warning.
func TestRepeatRowsPerSubmissionAreCapped(t *testing.T) {
	tables, files := tablesFor(t, simpleForm)
	xml := "<data id=\"f\"><g>" + strings.Repeat("<r><x>1</x></r>", MaxRepeatRows+5) + "</g>" +
		"<meta><instanceID>uuid:a</instanceID></meta></data>"
	if err := tables.Add(strings.NewReader(xml), Metadata{InstanceID: "uuid:a"}); err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(files["f-r.csv"].String(), "\r\n") - 1; got != MaxRepeatRows {
		t.Errorf("%d rows", got)
	}
	if len(tables.Warnings) != 1 || !strings.Contains(tables.Warnings[0], "5 repeat entries") {
		t.Errorf("warnings %v", tables.Warnings)
	}
}

// Review finding 8: repeats are numbered per repeat context, as Central
// does, even when a group around them appears twice.
func TestRepeatKeysAreNumberedPerContext(t *testing.T) {
	tables, files := tablesFor(t, simpleForm)
	xml := `<data id="f"><g><r><x>1</x></r></g><g><r><x>2</x></r></g><meta><instanceID>uuid:a</instanceID></meta></data>`
	if err := tables.Add(strings.NewReader(xml), Metadata{InstanceID: "uuid:a"}); err != nil {
		t.Fatal(err)
	}
	want := "x,PARENT_KEY,KEY\r\n1,uuid:a,uuid:a/g/r[1]\r\n2,uuid:a,uuid:a/g/r[2]\r\n"
	if got := strings.TrimPrefix(files["f-r.csv"].String(), "\ufeff"); got != want {
		t.Errorf("got %q", got)
	}
}

// Review finding 7: copies of a repeat with different children make one
// layout, and every answer lands in its repeat's table.
func TestRepeatCopiesWithDifferentChildren(t *testing.T) {
	form := `<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
 <h:head><model><instance><data id="f">
  <r jr:template=""><x/></r><a/><r><x/><y/></r><meta><instanceID/></meta>
 </data></instance></model></h:head>
 <h:body><repeat nodeset="/data/r"><input ref="x"/><input ref="y"/></repeat></h:body>
</h:html>`
	tables, files := tablesFor(t, form)
	xml := `<data id="f"><r><x>1</x><y>2</y></r><a>3</a><meta><instanceID>uuid:a</instanceID></meta></data>`
	if err := tables.Add(strings.NewReader(xml), Metadata{InstanceID: "uuid:a"}); err != nil {
		t.Fatal(err)
	}
	if got := files["f-r.csv"].String(); !strings.Contains(got, "x,y,PARENT_KEY,KEY\r\n1,2,uuid:a,uuid:a/r[1]") {
		t.Errorf("f-r.csv %q", got)
	}
	if got := files["f.csv"].String(); !strings.Contains(got, "SubmissionDate,a,meta-instanceID,KEY") {
		t.Errorf("f.csv %q", got)
	}
}

// Review finding 11: line breaks inside an answer stay byte for byte.
func TestLineBreaksInsideAnAnswerAreKept(t *testing.T) {
	tables, files := tablesFor(t, simpleForm)
	xml := "<data id=\"f\"><name>line1\nline2&#13;x</name><meta><instanceID>uuid:a</instanceID></meta></data>"
	if err := tables.Add(strings.NewReader(xml), Metadata{InstanceID: "uuid:a"}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(files["f.csv"].String(), "\"line1\nline2\rx\"") {
		t.Errorf("got %q", files["f.csv"].String())
	}
}

// Review findings 4 and 5: names in the package never collide, ignoring
// case, and lose characters that could disguise a file's type.
func TestEntryNamesNeverCollide(t *testing.T) {
	fields, _ := xform.ParseFields(strings.NewReader(simpleForm))
	store := []Submission{
		{ID: "r1", Meta: Metadata{InstanceID: "uuid:a"}, XML: opener(`<data id="f"><meta><instanceID>uuid:a</instanceID></meta></data>`)},
		{ID: "r2", Meta: Metadata{InstanceID: "uuid_a"}, XML: opener(`<data id="f"><meta><instanceID>uuid_a</instanceID></meta></data>`),
			Media: []Media{{Name: "photo\u202egpj.exe", SHA256: sum("x"), Open: opener("x")}}},
		{ID: "r3", Meta: Metadata{InstanceID: "UUID:A"}, XML: opener(`<data id="f"><meta><instanceID>UUID:A</instanceID></meta></data>`)},
	}
	p := &Package{FormID: "f", Fields: fields, IncludeMedia: true, ExportedBy: map[string]string{},
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
		}}
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
	seen := map[string]bool{}
	var names []string
	for _, f := range z.File {
		k := strings.ToLower(f.Name)
		if seen[k] {
			t.Errorf("two entries called %s", f.Name)
		}
		seen[k] = true
		names = append(names, f.Name)
		if strings.ContainsRune(f.Name, '\u202e') {
			t.Errorf("%q keeps a bidirectional override", f.Name)
		}
	}
	if !seen["submissions/uuid_a~r2.xml"] || !seen["submissions/uuid_a~r3.xml"] || !seen["media/photogpj.exe"] {
		t.Errorf("names %v", names)
	}
}

// Review finding 2: a media file missing from storage is a warning, not a
// broken package; a submission that cannot be read again fails the write.
func TestMissingFilesAndUnreadableSubmissions(t *testing.T) {
	fields, _ := xform.ParseFields(strings.NewReader(simpleForm))
	missing := func() (io.ReadCloser, error) { return nil, errors.New("no such file") }
	good := Submission{ID: "r1", Meta: Metadata{InstanceID: "uuid:a"},
		XML:   opener(`<data id="f"><meta><instanceID>uuid:a</instanceID></meta></data>`),
		Media: []Media{{Name: "a.jpg", SHA256: sum("a"), Open: missing}}}
	mk := func(reload []Submission) *Prepared {
		p := &Package{FormID: "f", Fields: fields, IncludeMedia: true, ExportedBy: map[string]string{},
			Each:   func(fn func(Submission) error) error { return fn(good) },
			Reload: func([]string) ([]Submission, error) { return reload, nil }}
		pr, err := p.Prepare(t.TempDir())
		if err != nil {
			t.Fatal(err)
		}
		return pr
	}

	pr := mk([]Submission{good})
	defer pr.Close()
	var buf bytes.Buffer
	if _, err := pr.Write(&buf); err != nil {
		t.Fatalf("a missing media file broke the package: %v", err)
	}
	if pr.Files != 0 || !strings.Contains(fmt.Sprint(pr.warnings), "could not be read") {
		t.Errorf("files %d, warnings %v", pr.Files, pr.warnings)
	}

	bad := good
	bad.XML = missing
	pr2 := mk([]Submission{bad})
	defer pr2.Close()
	if _, err := pr2.Write(io.Discard); err == nil {
		t.Error("an unreadable submission did not fail the write")
	}
}

// Review finding 10: numbers in exponent form are numbers.
func TestFormulaGuardKnowsExponents(t *testing.T) {
	for _, v := range []string{"-1.5E-4", "-2e3", "+.5", "-0.25"} {
		if GuardFormula(v) != v {
			t.Errorf("%s was changed", v)
		}
	}
	for _, v := range []string{"-Infinity", "+Inf", "-NaN", "-1e", "--1", "+1,000"} {
		if GuardFormula(v) != "'"+v {
			t.Errorf("%s was not guarded", v)
		}
	}
}
