package xform

import (
	"errors"
	"strings"
	"testing"
)

func TestParseInstance(t *testing.T) {
	cases := []struct {
		name, xml string
		want      Instance
		wantErr   string
	}{
		{
			name: "ODK Collect style with orx namespace",
			xml:  `<?xml version='1.0' ?><data id="hh" version="7" xmlns:orx="http://openrosa.org/xforms"><q>1</q><orx:meta><orx:instanceID>uuid:5a1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d</orx:instanceID></orx:meta></data>`,
			want: Instance{FormID: "hh", Version: "7", InstanceID: "uuid:5a1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d"},
		},
		{
			name: "plain meta, orx:version, whitespace",
			xml:  "<data id=\"hh\" xmlns:orx=\"http://openrosa.org/xforms\" orx:version=\"2\">\n <meta>\n  <instanceID> uuid:x-1 </instanceID>\n </meta>\n</data>",
			want: Instance{FormID: "hh", Version: "2", InstanceID: "uuid:x-1"},
		},
		{
			name:    "instanceID nested too deep is not meta/instanceID",
			xml:     `<data id="hh"><group><meta><instanceID>uuid:1</instanceID></meta></group></data>`,
			wantErr: "instanceID is missing",
		},
		{name: "no form id", xml: `<data><meta><instanceID>uuid:1</instanceID></meta></data>`, wantErr: "no id attribute"},
		{name: "DOCTYPE", xml: `<!DOCTYPE data [<!ENTITY e "x">]><data id="hh"><meta><instanceID>uuid:1</instanceID></meta></data>`, wantErr: "document type"},
		{name: "markup in instanceID", xml: `<data id="hh"><meta><instanceID>uuid:1<b/></instanceID></meta></data>`, wantErr: "text only"},
		{name: "path characters in instanceID", xml: `<data id="hh"><meta><instanceID>../../etc</instanceID></meta></data>`, wantErr: "not allowed"},
		{name: "two roots", xml: `<data id="hh"><meta><instanceID>uuid:1</instanceID></meta></data><data id="hh"/>`, wantErr: "more than one root"},
		{name: "broken XML", xml: `<data id="hh"><meta>`, wantErr: "not a valid"},
		{name: "empty", xml: ``, wantErr: "empty"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := ParseInstance(strings.NewReader(c.xml))
			if c.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), c.wantErr) || !errors.Is(err, ErrNotXML) {
					t.Fatalf("want error containing %q, got %v", c.wantErr, err)
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
	const form = `<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head><h:title>T</h:title>
    <model>
      <instance id="lookup"><root><item/></root></instance>
      <instance><survey id="hh_survey" version="2026110401"><q/><meta><instanceID/></meta></survey></instance>
    </model>
  </h:head>
  <h:body/>
</h:html>`

	got, err := ParseDefinition(strings.NewReader(form))
	if err != nil {
		t.Fatal(err)
	}
	if got != (Definition{FormID: "hh_survey", Version: "2026110401"}) {
		t.Errorf("got %+v", got)
	}

	for name, bad := range map[string]string{
		"not html":           `<data id="x"/>`,
		"no primary":         `<h:html xmlns:h="http://www.w3.org/1999/xhtml"><h:head><model><instance id="a"><r/></instance></model></h:head></h:html>`,
		"primary without id": `<h:html xmlns:h="http://www.w3.org/1999/xhtml"><h:head><model><instance><r/></instance></model></h:head></h:html>`,
		"doctype":            `<!DOCTYPE html><h:html xmlns:h="http://www.w3.org/1999/xhtml"/>`,
	} {
		if _, err := ParseDefinition(strings.NewReader(bad)); err == nil {
			t.Errorf("%s: want an error", name)
		}
	}
}
