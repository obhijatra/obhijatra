package obhijatra_test

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"strings"
	"testing"

	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const versionsURL = "/api/collections/form_versions/records"

// plainHTMLXForm is a valid XForm with a plain <html xmlns=...> root and no
// <?xml ...?> declaration: both used to be refused as "invalid mime type".
func plainHTMLXForm(version string) []byte {
	return []byte(`<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xf="http://www.w3.org/2002/xforms">
  <head><title>Household visit</title>
    <xf:model>
      <xf:instance><xf:data id="` + testutil.FormID + `" version="` + version + `"><xf:household_size/><xf:meta><xf:instanceID/></xf:meta></xf:data></xf:instance>
    </xf:model>
  </head>
  <body/>
</html>`)
}

func TestXMLFieldsAreValidatedByContent(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	upload := func(name, version string, xform []byte, status int, content ...string) tests.ApiScenario {
		body, contentType := testutil.FormVersionUpload(t, o.Form.Id, version, xform, false)
		return tests.ApiScenario{
			Name: name, Method: http.MethodPost, URL: versionsURL, Body: body,
			Headers:        map[string]string{"Content-Type": contentType, "Authorization": testutil.Token(t, o.Admin)},
			ExpectedStatus: status, ExpectedContent: content,
		}
	}

	const xxe = `<?xml version="1.0"?><!DOCTYPE h:html [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>`
	billionLaughs := `<!DOCTYPE h:html [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">` +
		`<!ENTITY c "&b;&b;&b;&b;&b;&b;&b;&b;&b;&b;"><!ENTITY d "&c;&c;&c;&c;&c;&c;&c;&c;&c;&c;">]>`
	withoutDecl := func(b []byte) string { return strings.TrimPrefix(string(b), `<?xml version="1.0"?>`) }

	runShared(t, app, []tests.ApiScenario{
		upload("an XForm with a plain <html xmlns> root and no XML declaration is accepted",
			"2026110410", plainHTMLXForm("2026110410"), 200, `"version":"2026110410"`),
		upload("the usual prefixed XForm is accepted",
			"2026110411", testutil.XForm(testutil.FormID, "2026110411"), 200, `"version":"2026110411"`),
		upload("an XForm with an external entity (XXE) is refused",
			"2026110412", []byte(xxe+withoutDecl(testutil.XForm(testutil.FormID, "2026110412"))),
			400, `"xform":{"code":"validation_invalid_xml"`, `document type declarations`),
		upload("an XForm with nested entities (billion laughs) is refused",
			"2026110413", []byte(billionLaughs+withoutDecl(testutil.XForm(testutil.FormID, "2026110413"))),
			400, `"xform":{"code":"validation_invalid_xml"`),
		upload("an HTML page is not an XForm",
			"2026110414", []byte(`<html xmlns="http://www.w3.org/1999/xhtml"><head><title>x</title></head><body/></html>`),
			400, `"xform":{"code":"validation_invalid_xform"`, `no <model>`),
		upload("an XForm whose root is not in the XHTML namespace is refused",
			"2026110415", []byte(`<html><head><model><instance><data id="household_visit" version="2026110415"/></instance></model></head></html>`),
			400, `"xform":{"code":"validation_invalid_xform"`),
		upload("text after the document is refused",
			"2026110416", append(testutil.XForm(testutil.FormID, "2026110416"), "trailing"...),
			400, `"xform":{"code":"validation_invalid_xml"`),
		upload("a version string that differs from the XForm is refused",
			"2026110417", testutil.XForm(testutil.FormID, "2026110499"),
			400, `"version":{"code":"validation_xform_mismatch"`),
		upload("an XForm for another form is refused",
			"2026110418", testutil.XForm("another_form", "2026110418"),
			400, `"xform":{"code":"validation_xform_mismatch"`),
		upload("an XForm over the size limit is refused",
			"2026110419", oversizeXForm("2026110419"),
			400, `"xform":{"code":"validation_file_size_limit"`),

		// The submission route: the reported bug, an instance with no
		// <?xml ...?> declaration.
		submitScenario(t, "a submission without an XML declaration is accepted", o.Field1,
			[]byte(`<data id="household_visit" version="2026110401"><household_size>2</household_size><meta><instanceID>uuid:e0000000-0000-4000-8000-000000000001</instanceID></meta></data>`),
			nil, 200, `"status":"received"`),
		submitScenario(t, "a submission with an external entity is refused", o.Field1,
			[]byte(`<!DOCTYPE data [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><data id="household_visit" version="2026110401"><household_size>&xxe;</household_size><meta><instanceID>uuid:e0000000-0000-4000-8000-000000000002</instanceID></meta></data>`),
			nil, 400, `not well-formed XML`),
	})

	if n, _ := app.CountRecords(schema.Submissions); n != 1 {
		t.Errorf("%d submissions stored, want 1", n)
	}
}

func oversizeXForm(version string) []byte {
	xf := string(testutil.XForm(testutil.FormID, version))
	padding := "<!--" + strings.Repeat("x", schema.MaxXMLSize) + "-->"
	return []byte(strings.Replace(xf, "<h:head>", "<h:head>"+padding, 1))
}

// The submission XML is checked whoever writes the record: Go code (and so
// the Dashboard and superusers) cannot store an unsafe or inconsistent one.
func TestSubmissionXMLHookBindsEveryWriter(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	col, err := app.FindCollectionByNameOrId(schema.Submissions)
	if err != nil {
		t.Fatal(err)
	}
	newSubmission := func(instanceID string, xml []byte) *core.Record {
		f, err := filesystem.NewFileFromBytes(xml, "submission.xml")
		if err != nil {
			t.Fatal(err)
		}
		sum := sha256.Sum256(xml)
		r := core.NewRecord(col)
		r.Load(map[string]any{
			"instance_id": instanceID, "form": o.Form.Id, "form_version": o.Version.Id,
			"xml": f, "xml_sha256": hex.EncodeToString(sum[:]), "submitted_by": o.Field1.Id,
			"location_path": o.Field1.GetString("location_path"), "review_state": schema.ReviewReceived,
		})
		return r
	}

	const id = "uuid:f0000000-0000-4000-8000-000000000001"
	good := testutil.Instance(id, testutil.FormVersion, 3)

	for name, c := range map[string]struct {
		record *core.Record
		want   string
	}{
		"external entity": {
			newSubmission(id, []byte(`<!DOCTYPE data [<!ENTITY x SYSTEM "file:///etc/passwd">]>`+string(good))),
			"validation_invalid_xml",
		},
		"not a submission": {newSubmission(id, []byte(`<data id="household_visit"/>`)), "validation_invalid_instance"},
		"instance_id differs from the XML": {
			newSubmission("uuid:f0000000-0000-4000-8000-000000000099", good), "validation_submission_mismatch",
		},
		"XML names an unknown form version": {
			newSubmission(id, testutil.Instance(id, "1999", 3)), "validation_submission_mismatch",
		},
	} {
		err := app.Save(c.record)
		if err == nil || !strings.Contains(errorCodes(err), c.want) {
			t.Errorf("%s: want a %s refusal, got %v", name, c.want, err)
		}
	}

	if err := app.Save(newSubmission(id, good)); err != nil {
		t.Errorf("a valid submission must be stored: %v", err)
	}
}

// errorCodes renders an error and its validation error codes, so tests can
// look for a code.
func errorCodes(err error) string {
	out := []string{err.Error()}
	var ve validation.Errors
	if errors.As(err, &ve) {
		for _, e := range ve {
			if c, ok := e.(validation.Error); ok {
				out = append(out, c.Code())
			}
		}
	}
	return strings.Join(out, " ")
}

func TestXFormDownloadNeedsAFileToken(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	fileURL := func(v *core.Record) string {
		return "/api/files/form_versions/" + v.Id + "/" + v.GetString("xform")
	}
	withToken := func(v *core.Record, token string) string { return fileURL(v) + "?token=" + token }
	xform := string(testutil.XForm(testutil.FormID, testutil.FormVersion))
	notFound := []string{`"status":404`}

	runShared(t, app, []tests.ApiScenario{
		{
			Name: "a guest cannot download a published XForm", Method: http.MethodGet, URL: fileURL(o.Version),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "an Authorization header alone is not enough", Method: http.MethodGet, URL: fileURL(o.Version),
			Headers: auth(t, o.Field1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "an auth token is not a file token", Method: http.MethodGet, URL: withToken(o.Version, testutil.Token(t, o.Field1)),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "an active field user downloads a published XForm with a file token", Method: http.MethodGet,
			URL: withToken(o.Version, testutil.FileToken(t, o.Field1)), ExpectedStatus: 200, ExpectedContent: []string{xform},
		},
		{
			Name: "a field user cannot download an unpublished XForm", Method: http.MethodGet,
			URL: withToken(o.Unpublished, testutil.FileToken(t, o.Field1)), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "an inactive user's file token is refused", Method: http.MethodGet,
			URL: withToken(o.Version, testutil.FileToken(t, o.Gone1)), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "an M&E officer downloads an unpublished XForm", Method: http.MethodGet,
			URL: withToken(o.Unpublished, testutil.FileToken(t, o.ME1)), ExpectedStatus: 200, ExpectedContent: []string{`version="2026110402"`},
		},
		{
			Name: "a guest cannot list form versions", Method: http.MethodGet, URL: versionsURL,
			ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
	})

	col, _ := app.FindCollectionByNameOrId(schema.FormVersions)
	if f, ok := col.Fields.GetByName("xform").(*core.FileField); !ok || !f.Protected || len(f.MimeTypes) != 0 {
		t.Error("form_versions.xform must be protected and have no MIME-type list")
	}
}
