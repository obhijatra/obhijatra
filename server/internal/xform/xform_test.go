package xform

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

const instanceOK = `<data id="hh" version="7"><q>1</q><meta><instanceID>uuid:1</instanceID></meta></data>`

// xformOK is a minimal valid XForm in the usual prefixed style.
const xformOK = `<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>T</h:title>
    <model>
      <instance id="lookup"><root><item/></root></instance>
      <instance><survey id="hh_survey" version="2026110401"><q/><meta><instanceID/></meta></survey></instance>
    </model>
  </h:head>
  <h:body/>
</h:html>`

func TestParseInstance(t *testing.T) {
	cases := []struct {
		name, xml string
		want      Instance
		wantErr   error
		wantText  string
	}{
		{
			name: "ODK Collect style with orx namespace",
			xml:  `<?xml version='1.0' ?><data id="hh" version="7" xmlns:orx="http://openrosa.org/xforms"><q>1</q><orx:meta><orx:instanceID>uuid:5a1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d</orx:instanceID></orx:meta></data>`,
			want: Instance{FormID: "hh", Version: "7", InstanceID: "uuid:5a1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d"},
		},
		{
			name: "no XML declaration (the reported bug)",
			xml:  instanceOK,
			want: Instance{FormID: "hh", Version: "7", InstanceID: "uuid:1"},
		},
		{
			name: "byte-order mark, comments and whitespace around the root",
			xml:  "\xEF\xBB\xBF<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- c -->\n" + instanceOK + "\n<!-- end -->\n",
			want: Instance{FormID: "hh", Version: "7", InstanceID: "uuid:1"},
		},
		{
			name: "plain meta, orx:version, whitespace",
			xml:  "<data id=\"hh\" xmlns:orx=\"http://openrosa.org/xforms\" orx:version=\"2\">\n <meta>\n  <instanceID> uuid:x-1 </instanceID>\n </meta>\n</data>",
			want: Instance{FormID: "hh", Version: "2", InstanceID: "uuid:x-1"},
		},
		{name: "instanceID nested too deep is not meta/instanceID", xml: `<data id="hh"><group><meta><instanceID>uuid:1</instanceID></meta></group></data>`, wantErr: ErrNotInstance, wantText: "instanceID is missing"},
		{name: "no form id", xml: `<data><meta><instanceID>uuid:1</instanceID></meta></data>`, wantErr: ErrNotInstance, wantText: "no id attribute"},
		{name: "two instanceIDs", xml: `<data id="hh"><meta><instanceID>uuid:1</instanceID><instanceID>uuid:2</instanceID></meta></data>`, wantErr: ErrNotInstance, wantText: "more than one"},
		{name: "markup in instanceID", xml: `<data id="hh"><meta><instanceID>uuid:1<b/></instanceID></meta></data>`, wantErr: ErrNotInstance, wantText: "text only"},
		{name: "path characters in instanceID", xml: `<data id="hh"><meta><instanceID>../../etc</instanceID></meta></data>`, wantErr: ErrNotInstance, wantText: "not allowed"},
		{name: "two roots", xml: instanceOK + `<data id="hh"/>`, wantErr: ErrMalformed, wantText: "more than one root"},
		{name: "text after the root", xml: instanceOK + `junk`, wantErr: ErrMalformed, wantText: "text outside"},
		{name: "text before the root", xml: `junk` + instanceOK, wantErr: ErrMalformed, wantText: "text outside"},
		{name: "XML declaration not at the start", xml: ` <?xml version="1.0"?>` + instanceOK, wantErr: ErrMalformed, wantText: "very start"},
		{name: "repeated attribute", xml: `<data id="hh" id="hh2"><meta><instanceID>uuid:1</instanceID></meta></data>`, wantErr: ErrMalformed, wantText: "more than once"},
		{name: "undeclared element prefix", xml: `<data id="hh"><orx:meta><orx:instanceID>uuid:1</orx:instanceID></orx:meta></data>`, wantErr: ErrMalformed, wantText: "not declared"},
		{name: "undeclared attribute prefix", xml: `<data id="hh" jr:x="1"><meta><instanceID>uuid:1</instanceID></meta></data>`, wantErr: ErrMalformed, wantText: "not declared"},
		{name: "prefix bound to an empty URI", xml: `<data id="hh" xmlns:p=""><meta><instanceID>uuid:1</instanceID></meta></data>`, wantErr: ErrMalformed, wantText: "empty URI"},
		{name: "non-UTF-8 encoding", xml: `<?xml version="1.0" encoding="ISO-8859-1"?>` + instanceOK, wantErr: ErrMalformed, wantText: "only UTF-8"},
		{name: "invalid UTF-8 bytes", xml: "<data id=\"hh\"><q>\xff</q><meta><instanceID>uuid:1</instanceID></meta></data>", wantErr: ErrMalformed, wantText: "UTF-8"},
		{name: "unclosed element", xml: `<data id="hh"><meta>`, wantErr: ErrMalformed, wantText: "before every element is closed"},
		{name: "mismatched tags", xml: `<data id="hh"></meta>`, wantErr: ErrMalformed, wantText: "line 1"},
		{name: "empty", xml: ``, wantErr: ErrMalformed, wantText: "empty"},
		{name: "only a comment", xml: `<!-- nothing -->`, wantErr: ErrMalformed, wantText: "empty"},
		{name: "DOCTYPE without entities", xml: `<!DOCTYPE data>` + instanceOK, wantErr: ErrMalformed, wantText: "document type"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := ParseInstance(strings.NewReader(c.xml))
			if c.wantErr != nil {
				if !errors.Is(err, c.wantErr) || !strings.Contains(err.Error(), c.wantText) {
					t.Fatalf("want %v containing %q, got %v", c.wantErr, c.wantText, err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if got != c.want {
				t.Errorf("got %+v, want %+v", got, c.want)
			}
		})
	}
}

func TestParseDefinition(t *testing.T) {
	good := map[string]struct {
		xml  string
		want Definition
	}{
		"prefixed h:html with declaration": {xformOK, Definition{FormID: "hh_survey", Version: "2026110401"}},
		// The reported bug: a plain <html xmlns=...> root and no <?xml ...?>.
		"plain html root in the XHTML namespace, no declaration": {
			`<html xmlns="http://www.w3.org/1999/xhtml" xmlns:x="http://www.w3.org/2002/xforms" xmlns:orx="http://openrosa.org/xforms">
			  <head><x:model><x:instance><x:data id="f" orx:version="3"><x:meta><x:instanceID/></x:meta></x:data></x:instance></x:model></head>
			  <body/></html>`,
			Definition{FormID: "f", Version: "3"},
		},
		"byte-order mark": {"\xEF\xBB\xBF" + xformOK, Definition{FormID: "hh_survey", Version: "2026110401"}},
	}
	for name, c := range good {
		t.Run(name, func(t *testing.T) {
			got, err := ParseDefinition(strings.NewReader(c.xml))
			if err != nil {
				t.Fatal(err)
			}
			if got != c.want {
				t.Errorf("got %+v, want %+v", got, c.want)
			}
		})
	}

	const (
		h  = `xmlns:h="http://www.w3.org/1999/xhtml"`
		xf = `xmlns="http://www.w3.org/2002/xforms"`
	)
	bad := []struct {
		name, xml string
		wantErr   error
		wantText  string
	}{
		{"root is not html", `<data id="x"/>`, ErrNotXForm, "must be <h:html>"},
		{"html in no namespace", `<html><head><model><instance><d id="x"/></instance></model></head></html>`, ErrNotXForm, "no namespace"},
		{"html in the wrong namespace", `<html xmlns="http://example.org/"><head/></html>`, ErrNotXForm, "http://example.org/"},
		{"undeclared h: prefix", `<h:html><h:head/></h:html>`, ErrMalformed, "not declared"},
		{"no head", `<h:html ` + h + `><h:body/></h:html>`, ErrNotXForm, "no <h:head>"},
		{"no model", `<h:html ` + h + `><h:head><h:title>T</h:title></h:head></h:html>`, ErrNotXForm, "no <model>"},
		{"model in no namespace", `<h:html ` + h + `><h:head><model><instance><d id="x"/></instance></model></h:head></h:html>`, ErrNotXForm, "no <model>"},
		{"model outside head", `<h:html ` + h + ` ` + xf + `><h:head/><model><instance><d id="x"/></instance></model></h:html>`, ErrNotXForm, "no <model>"},
		{"only secondary instances", `<h:html ` + h + ` ` + xf + `><h:head><model><instance id="a"><r/></instance></model></h:head></h:html>`, ErrNotXForm, "no primary"},
		{"empty primary instance", `<h:html ` + h + ` ` + xf + `><h:head><model><instance/></model></h:head></h:html>`, ErrNotXForm, "empty"},
		{"primary instance root without id", `<h:html ` + h + ` ` + xf + `><h:head><model><instance><r/></instance></model></h:head></h:html>`, ErrNotXForm, "no id attribute"},
		{"primary instance with two roots", `<h:html ` + h + ` ` + xf + `><h:head><model><instance><d id="x"/><d id="y"/></instance></model></h:head></h:html>`, ErrNotXForm, "exactly one root"},
		{"text after the document", xformOK + `x`, ErrMalformed, "text outside"},
		{"broken after the primary instance", strings.Replace(xformOK, "<h:body/>", "<h:body>", 1), ErrMalformed, "closed"},
		{"DOCTYPE", `<!DOCTYPE html>` + xformOK[len(`<?xml version="1.0"?>`):], ErrMalformed, "document type"},
	}
	for _, c := range bad {
		t.Run(c.name, func(t *testing.T) {
			_, err := ParseDefinition(strings.NewReader(c.xml))
			if !errors.Is(err, c.wantErr) || !strings.Contains(err.Error(), c.wantText) {
				t.Fatalf("want %v containing %q, got %v", c.wantErr, c.wantText, err)
			}
		})
	}
}

// parsers runs a check against both entry points, which share the reader.
var parsers = map[string]func(string) error{
	"ParseInstance":   func(s string) error { _, err := ParseInstance(strings.NewReader(s)); return err },
	"ParseDefinition": func(s string) error { _, err := ParseDefinition(strings.NewReader(s)); return err },
}

// XXE: an external entity must never be resolved, whether it names a local
// file, a remote URL, a parameter entity or an external DTD.
func TestXXEIsRefused(t *testing.T) {
	secret := filepath.Join(t.TempDir(), "secret.txt")
	if err := os.WriteFile(secret, []byte("TOP-SECRET-CONTENT"), 0o600); err != nil {
		t.Fatal(err)
	}

	var hits atomic.Int64
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		fmt.Fprint(w, `<!ENTITY leak "LEAKED-FROM-SERVER">`)
	}))
	defer srv.Close()

	fileURL := "file://" + filepath.ToSlash(secret)
	payloads := map[string]string{
		"general entity naming a local file": `<?xml version="1.0"?>
<!DOCTYPE data [<!ENTITY xxe SYSTEM "` + fileURL + `">]>
<data id="hh"><q>&xxe;</q><meta><instanceID>uuid:1</instanceID></meta></data>`,
		"general entity naming a URL": `<!DOCTYPE data [<!ENTITY xxe SYSTEM "` + srv.URL + `/x">]>
<data id="hh"><q>&xxe;</q><meta><instanceID>uuid:1</instanceID></meta></data>`,
		"parameter entity naming a URL": `<!DOCTYPE data [<!ENTITY % remote SYSTEM "` + srv.URL + `/p.dtd"> %remote;]>
<data id="hh"><q>&leak;</q><meta><instanceID>uuid:1</instanceID></meta></data>`,
		"external DTD": `<!DOCTYPE data SYSTEM "` + srv.URL + `/evil.dtd">
<data id="hh"><q>&leak;</q><meta><instanceID>uuid:1</instanceID></meta></data>`,
		"public external DTD inside an XForm": `<!DOCTYPE h:html PUBLIC "-//X//Y" "` + srv.URL + `/xform.dtd">` + xformOK[len(`<?xml version="1.0"?>`):],
		// XForm-shaped, so both parsers get as far as the reference.
		"entity used without any DTD": strings.Replace(xformOK, "<q/>", "<q>&xxe;</q>", 1),
	}

	for name, doc := range payloads {
		for parser, parse := range parsers {
			t.Run(name+"/"+parser, func(t *testing.T) {
				err := parse(doc)
				if !errors.Is(err, ErrMalformed) {
					t.Fatalf("want ErrMalformed, got %v", err)
				}
				if strings.Contains(err.Error(), "TOP-SECRET") || strings.Contains(err.Error(), "LEAKED") {
					t.Fatalf("external content leaked into the error: %v", err)
				}
			})
		}
	}
	if n := hits.Load(); n != 0 {
		t.Errorf("the parser fetched %d external resources; it must fetch none", n)
	}
}

// Billion laughs: nested entity definitions that would expand a 1 KB
// document to about 3 GB. It must be refused at once, using almost no
// memory. So must the "quadratic blow-up" variant (one large entity used
// many times) and the same references without a DTD.
func TestEntityExpansionIsRefused(t *testing.T) {
	var lol strings.Builder
	lol.WriteString(`<?xml version="1.0"?><!DOCTYPE data [<!ENTITY lol0 "lol">`)
	for i := 1; i <= 9; i++ {
		fmt.Fprintf(&lol, `<!ENTITY lol%d "%s">`, i, strings.Repeat(fmt.Sprintf("&lol%d;", i-1), 10))
	}
	lol.WriteString(`]><data id="hh"><q>&lol9;</q><meta><instanceID>uuid:1</instanceID></meta></data>`)

	big := strings.Repeat("A", 100_000)
	quadratic := `<!DOCTYPE data [<!ENTITY a "` + big + `">]><data id="hh"><q>` +
		strings.Repeat("&a;", 1000) + `</q><meta><instanceID>uuid:1</instanceID></meta></data>`

	payloads := map[string]string{
		"billion laughs":                 lol.String(),
		"quadratic blow-up":              quadratic,
		"billion laughs body, no DTD":    strings.Replace(xformOK, "<q/>", "<q>&lol9;</q>", 1),
		"billion laughs inside an XForm": strings.Replace(lol.String(), `<data id="hh"><q>&lol9;</q><meta><instanceID>uuid:1</instanceID></meta></data>`, xformOK[len(`<?xml version="1.0"?>`):], 1),
	}

	for name, doc := range payloads {
		for parser, parse := range parsers {
			t.Run(name+"/"+parser, func(t *testing.T) {
				var before, after runtime.MemStats
				runtime.GC()
				runtime.ReadMemStats(&before)
				start := time.Now()

				err := parse(doc)

				elapsed := time.Since(start)
				runtime.ReadMemStats(&after)
				if !errors.Is(err, ErrMalformed) {
					t.Fatalf("want ErrMalformed, got %v", err)
				}
				// The document itself is at most ~400 KB; the expansion
				// would be gigabytes.
				if allocated := after.TotalAlloc - before.TotalAlloc; allocated > 8<<20 {
					t.Errorf("parsing allocated %d bytes; entity expansion is not being prevented", allocated)
				}
				if elapsed > 2*time.Second {
					t.Errorf("parsing took %s; entity expansion is not being prevented", elapsed)
				}
			})
		}
	}
}

func TestSizeAndDepthLimits(t *testing.T) {
	const (
		head = `<data id="hh"><meta><instanceID>uuid:1</instanceID></meta><q>`
		tail = `</q></data>`
	)
	exact := head + strings.Repeat("a", schema.MaxXMLSize-len(head)-len(tail)) + tail
	if len(exact) != schema.MaxXMLSize {
		t.Fatalf("test document is %d bytes", len(exact))
	}
	if _, err := ParseInstance(strings.NewReader(exact)); err != nil {
		t.Errorf("a document of exactly %d bytes must be accepted: %v", schema.MaxXMLSize, err)
	}
	over := head + strings.Repeat("a", schema.MaxXMLSize-len(head)-len(tail)+1) + tail
	if _, err := ParseInstance(strings.NewReader(over)); !errors.Is(err, ErrTooLarge) {
		t.Errorf("a document one byte over the limit must fail with ErrTooLarge, got %v", err)
	}

	nested := func(levels int) string {
		return `<data id="hh"><meta><instanceID>uuid:1</instanceID></meta>` +
			strings.Repeat("<g>", levels-1) + strings.Repeat("</g>", levels-1) + `</data>`
	}
	if _, err := ParseInstance(strings.NewReader(nested(MaxDepth))); err != nil {
		t.Errorf("%d levels must be accepted: %v", MaxDepth, err)
	}
	if _, err := ParseInstance(strings.NewReader(nested(MaxDepth + 1))); !errors.Is(err, ErrMalformed) || !strings.Contains(err.Error(), "nested") {
		t.Errorf("%d levels must be refused, got %v", MaxDepth+1, err)
	}
}

// A failing underlying reader is reported as a read error, not as bad XML.
func TestReadErrorIsNotBlamedOnTheDocument(t *testing.T) {
	boom := errors.New("disk on fire")
	_, err := ParseInstance(&failingReader{data: []byte(`<data id="hh"><meta>`), err: boom})
	if !errors.Is(err, boom) || errors.Is(err, ErrMalformed) {
		t.Fatalf("want the read error, got %v", err)
	}
}

type failingReader struct {
	data []byte
	err  error
}

func (f *failingReader) Read(p []byte) (int, error) {
	if len(f.data) == 0 {
		return 0, f.err
	}
	n := copy(p, f.data)
	f.data = f.data[n:]
	return n, nil
}
