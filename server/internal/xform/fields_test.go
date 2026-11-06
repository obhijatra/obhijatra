package xform

import (
	"strings"
	"testing"
)

// A form as pyxform writes it: a group, a repeat with a jr:template copy and
// a nested repeat, a geopoint, a select multiple inside a group with a
// relative ref, a note, a secondary instance and meta/instanceID.
const householdForm = `<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml"
  xmlns:jr="http://openrosa.org/javarosa" xmlns:orx="http://openrosa.org/xforms">
 <h:head>
  <h:title>Household visit</h:title>
  <model>
   <instance>
    <data id="household_visit" version="2026110601">
     <respondent>
      <name/>
      <age/>
     </respondent>
     <location/>
     <members jr:template="">
      <member_name/>
      <phones jr:template=""><phone/></phones>
     </members>
     <members>
      <member_name/>
      <phones><phone/></phones>
     </members>
     <needs><which/></needs>
     <photo/>
     <meta><instanceID/></meta>
    </data>
   </instance>
   <instance id="villages"><root><item><name>A</name></item></root></instance>
   <bind nodeset="/data/respondent/name" type="string"/>
   <bind nodeset="/data/respondent/age" type="int"/>
   <bind nodeset="/data/location" type="geopoint"/>
   <bind nodeset="/data/members/member_name" type="string"/>
   <bind nodeset="/data/members/phones/phone" type="xsd:string"/>
   <bind nodeset="/data/needs/which" type="string"/>
   <bind nodeset="/data/photo" type="binary"/>
   <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
  </model>
 </h:head>
 <h:body>
  <group ref="/data/respondent">
   <input ref="/data/respondent/name"/>
   <input ref="age"/>
  </group>
  <input ref="/data/location"/>
  <group ref="/data/members">
   <repeat nodeset="/data/members">
    <input ref="/data/members/member_name"/>
    <group ref="/data/members/phones">
     <repeat nodeset="/data/members/phones"><input ref="phone"/></repeat>
    </group>
   </repeat>
  </group>
  <group ref="/data/needs">
   <select ref="which"><item><label>Food</label><value>food</value></item></select>
  </group>
  <upload ref="/data/photo" mediatype="image/*"/>
 </h:body>
</h:html>`

func TestFieldsFollowTheInstanceInODKCentralsWay(t *testing.T) {
	fields, err := ParseFields(strings.NewReader(householdForm))
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, f := range fields {
		s := f.Path + " " + f.Kind
		if f.Kind == KindValue {
			s += " " + f.Type
		}
		if f.SelectMultiple {
			s += " multiple"
		}
		got = append(got, s)
	}
	want := []string{
		"/respondent structure",
		"/respondent/name value string",
		"/respondent/age value int",
		"/location value geopoint",
		"/members repeat",
		"/members/member_name value string",
		"/members/phones repeat",
		"/members/phones/phone value string",
		"/needs structure",
		"/needs/which value string multiple",
		"/photo value binary",
		"/meta structure",
		"/meta/instanceID value string",
	}
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("fields:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

func TestFieldsRefuseWhatTheReaderRefuses(t *testing.T) {
	for name, doc := range map[string]string{
		"doctype":     `<!DOCTYPE x [<!ENTITY a "b">]>` + householdForm[strings.Index(householdForm, "<h:html"):],
		"not a form":  `<data id="x"/>`,
		"no instance": `<h:html xmlns:h="http://www.w3.org/1999/xhtml"><h:head/></h:html>`,
	} {
		if _, err := ParseFields(strings.NewReader(doc)); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}
