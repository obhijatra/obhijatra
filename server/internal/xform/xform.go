// Package xform reads the few facts the server needs from ODK XForms XML:
// a form definition's id and version, and a submission instance's form id,
// form version and instanceID.
//
// Every document is read to its last byte by a hardened reader built on Go's
// encoding/xml, which never fetches anything and never expands an entity
// beyond the five predefined ones (&lt; &gt; &amp; &apos; &quot;) and
// numeric character references. On top of that the reader refuses:
//
//   - anything larger than schema.MaxXMLSize (10 MiB);
//   - any encoding other than UTF-8 (a leading byte-order mark is allowed);
//   - any document type declaration (<!DOCTYPE ...>) or other <!...>
//     declaration, so no entity can be defined at all: external entities
//     (XXE) and entity expansion ("billion laughs") are impossible;
//   - a document that is not well-formed: not exactly one root element,
//     text outside the root, an XML declaration anywhere but the very start,
//     a repeated attribute, or an undeclared namespace prefix;
//   - elements nested more than MaxDepth levels deep.
//
// MIME types are never consulted: what makes a file acceptable is its
// content, checked here.
package xform

import (
	"bufio"
	"bytes"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strings"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Namespaces the checks rely on.
const (
	XHTMLNamespace    = "http://www.w3.org/1999/xhtml"
	XFormsNamespace   = "http://www.w3.org/2002/xforms"
	OpenRosaNamespace = "http://openrosa.org/xforms" // orx:version, orx:meta
	xmlNamespace      = "http://www.w3.org/XML/1998/namespace"
)

// MaxDepth is the deepest element nesting accepted. Real XForms nest groups
// and repeats a dozen or so levels; the limit stops a document of millions of
// nested elements from making the parser hold millions of open elements.
const MaxDepth = 100

// Errors. Every error the parsers return wraps exactly one of the first four;
// a failure of the underlying reader is returned as it is.
var (
	// ErrTooLarge: the document is larger than schema.MaxXMLSize.
	ErrTooLarge = fmt.Errorf("larger than the %d MB limit", schema.MaxXMLSize>>20)
	// ErrMalformed: not well-formed XML, not UTF-8, or a construct the
	// server refuses (DOCTYPE, entity declarations, nesting too deep).
	ErrMalformed = errors.New("not well-formed XML")
	// ErrNotXForm: well-formed XML, but not an XForm definition.
	ErrNotXForm = errors.New("not an XForm")
	// ErrNotInstance: well-formed XML, but not a form submission.
	ErrNotInstance = errors.New("not a form submission")
)

// instanceIDPattern accepts ODK's "uuid:<uuid>" and similar identifiers but
// nothing that could be confused with a path or markup.
var instanceIDPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$`)

var (
	htmlName     = xml.Name{Space: XHTMLNamespace, Local: "html"}
	headName     = xml.Name{Space: XHTMLNamespace, Local: "head"}
	modelName    = xml.Name{Space: XFormsNamespace, Local: "model"}
	instanceName = xml.Name{Space: XFormsNamespace, Local: "instance"}
)

// Definition is what the server reads from a form definition.
type Definition struct {
	FormID  string // id attribute of the primary instance's root element
	Version string // its version (or orx:version) attribute
}

// Instance is what the server reads from a filled-in submission.
type Instance struct {
	FormID     string // id attribute of the root element
	Version    string // version (or orx:version) attribute of the root element
	InstanceID string // text of /<root>/meta/instanceID
}

// ParseDefinition checks a whole XForm definition and returns its form id
// and version. The document must be <h:html> in the XHTML namespace, with an
// <h:head> child holding a <model> in the XForms namespace, whose primary
// instance (the first <instance> without an id attribute) has exactly one
// root element carrying the form id.
func ParseDefinition(r io.Reader) (Definition, error) {
	x := newReader(r)

	const (
		headDepth     = 2
		modelDepth    = 3
		instanceDepth = 4
		rootDepth     = 5
	)
	var (
		def                         Definition
		inHead, inModel, inPrimary  bool
		seenHead, seenModel, seenPr bool
		primaryRoots                int
	)

	for {
		tok, err := x.next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return Definition{}, err
		}

		switch t := tok.(type) {
		case xml.StartElement:
			switch d := x.depth; {
			case d == 1:
				if t.Name != htmlName {
					return Definition{}, notXForm("the root element must be <h:html> in the XHTML namespace (%s), not %s", XHTMLNamespace, describe(t.Name))
				}
			case d == headDepth && t.Name == headName && !seenHead:
				inHead, seenHead = true, true
			case d == modelDepth && inHead && t.Name == modelName && !seenModel:
				inModel, seenModel = true, true
			case d == instanceDepth && inModel && t.Name == instanceName && !seenPr && !hasAttr(t, "id"):
				inPrimary, seenPr = true, true
			case d == rootDepth && inPrimary:
				primaryRoots++
				if primaryRoots > 1 {
					return Definition{}, notXForm("the primary <instance> must have exactly one root element")
				}
				def.FormID, def.Version = idAndVersion(t)
				if def.FormID == "" {
					return Definition{}, notXForm("the primary instance's root element <%s> has no id attribute (the form id)", t.Name.Local)
				}
			}
		case xml.EndElement:
			switch x.depth + 1 { // the depth of the element that just closed
			case headDepth:
				inHead = false
			case modelDepth:
				inModel = false
			case instanceDepth:
				inPrimary = false
			}
		}
	}

	switch {
	case !seenHead:
		return Definition{}, notXForm("<h:html> has no <h:head> child")
	case !seenModel:
		return Definition{}, notXForm("<h:head> has no <model> child in the XForms namespace (%s)", XFormsNamespace)
	case !seenPr:
		return Definition{}, notXForm("<model> has no primary <instance> (an <instance> without an id attribute)")
	case primaryRoots == 0:
		return Definition{}, notXForm("the primary <instance> is empty")
	}
	return def, nil
}

// ParseInstance checks a whole submission instance and returns the root
// element's id and version attributes and the text of its meta/instanceID
// child (in any namespace, as ODK Collect writes orx:meta/orx:instanceID).
func ParseInstance(r io.Reader) (Instance, error) {
	x := newReader(r)

	var (
		inst    Instance
		inMeta  bool
		inID    bool
		idText  strings.Builder
		foundID bool
	)

	for {
		tok, err := x.next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return Instance{}, err
		}

		switch t := tok.(type) {
		case xml.StartElement:
			switch d := x.depth; {
			case d == 1:
				inst.FormID, inst.Version = idAndVersion(t)
			case inID:
				return Instance{}, notInstance("meta/instanceID must contain text only")
			case d == 2 && t.Name.Local == "meta":
				inMeta = true
			case d == 3 && inMeta && t.Name.Local == "instanceID":
				if foundID {
					return Instance{}, notInstance("there is more than one meta/instanceID")
				}
				inID = true
			}
		case xml.CharData:
			if inID {
				idText.Write(t)
			}
		case xml.EndElement:
			switch x.depth + 1 {
			case 3:
				if inID {
					inID, foundID = false, true
					inst.InstanceID = strings.TrimSpace(idText.String())
				}
			case 2:
				inMeta = false
			}
		}
	}

	switch {
	case inst.FormID == "":
		return Instance{}, notInstance("the root element has no id attribute (the form id)")
	case !foundID || inst.InstanceID == "":
		return Instance{}, notInstance("meta/instanceID is missing")
	case !instanceIDPattern.MatchString(inst.InstanceID):
		return Instance{}, notInstance("meta/instanceID has characters or a length that are not allowed")
	}
	return inst, nil
}

// ---------------------------------------------------------------------
// The hardened reader
// ---------------------------------------------------------------------

var utf8BOM = []byte{0xEF, 0xBB, 0xBF}

// reader yields the tokens of one XML document after applying every check in
// the package comment. depth is the nesting depth after the last token: 1
// while inside the root element's start tag's content, 0 outside it.
type reader struct {
	d   *xml.Decoder
	src *limitReader

	depth    int
	tokens   int
	rootSeen bool
	rootDone bool

	// bound counts, for each namespace URI, how many in-scope declarations
	// bind it; frames holds the URIs each open element declared.
	bound  map[string]int
	frames [][]string

	badEncoding string
}

func newReader(r io.Reader) *reader {
	x := &reader{
		src:   &limitReader{r: r, left: schema.MaxXMLSize},
		bound: map[string]int{},
	}

	br := bufio.NewReader(x.src)
	if head, err := br.Peek(len(utf8BOM)); err == nil && bytes.Equal(head, utf8BOM) {
		_, _ = br.Discard(len(utf8BOM))
	}

	d := xml.NewDecoder(br) // br is an io.ByteReader, so no second buffer
	d.Strict = true
	d.AutoClose = nil
	d.Entity = nil // only the five predefined entities
	d.CharsetReader = func(label string, _ io.Reader) (io.Reader, error) {
		x.badEncoding = label
		return nil, errors.New("only UTF-8 is accepted")
	}
	x.d = d

	return x
}

// next returns the next token, io.EOF at the clean end of a document with a
// root element, or an error wrapping ErrTooLarge or ErrMalformed.
func (x *reader) next() (xml.Token, error) {
	tok, err := x.d.Token()
	if err == io.EOF {
		if !x.rootSeen {
			return nil, malformed("the document is empty")
		}
		return nil, io.EOF
	}
	if err != nil {
		return nil, x.wrap(err)
	}

	first := x.tokens == 0
	x.tokens++

	switch t := tok.(type) {
	case xml.ProcInst:
		if strings.EqualFold(t.Target, "xml") && !(first && t.Target == "xml") {
			return nil, malformed("the XML declaration (<?xml ...?>) may appear only at the very start")
		}
	case xml.Directive:
		if isDoctype(t) {
			return nil, malformed("document type declarations (<!DOCTYPE ...>) are not allowed")
		}
		return nil, malformed("<!...> declarations are not allowed")
	case xml.CharData:
		if x.depth == 0 && len(bytes.TrimLeft(t, " \t\r\n")) > 0 {
			return nil, malformed("there is text outside the root element")
		}
	case xml.StartElement:
		if x.rootDone {
			return nil, malformed("there is more than one root element")
		}
		x.rootSeen = true
		x.depth++
		if x.depth > MaxDepth {
			return nil, malformed("elements are nested more than %d levels deep", MaxDepth)
		}
		if err := x.open(t); err != nil {
			return nil, err
		}
	case xml.EndElement:
		x.close()
		x.depth--
		if x.depth == 0 {
			x.rootDone = true
		}
	}

	return tok, nil
}

// open records the namespaces t declares and checks that its own name and
// its attributes use only declared prefixes and that no attribute repeats.
func (x *reader) open(t xml.StartElement) error {
	var declared []string
	for _, a := range t.Attr {
		switch {
		case a.Name.Space == "xmlns": // xmlns:p="uri"
			if a.Value == "" {
				return malformed("the namespace prefix %q is declared with an empty URI", a.Name.Local)
			}
			declared = append(declared, a.Value)
		case a.Name.Space == "" && a.Name.Local == "xmlns" && a.Value != "": // xmlns="uri"
			declared = append(declared, a.Value)
		}
	}
	for _, uri := range declared {
		x.bound[uri]++
	}
	x.frames = append(x.frames, declared)

	// encoding/xml replaces a declared prefix by its URI and leaves an
	// undeclared one as it is; a name whose space is not a bound URI
	// therefore carries an undeclared prefix.
	if !x.isBound(t.Name.Space) {
		return malformed("the element <%s:%s> uses a namespace prefix that is not declared", t.Name.Space, t.Name.Local)
	}
	for _, a := range t.Attr {
		if a.Name.Space != "xmlns" && !x.isBound(a.Name.Space) {
			return malformed("the attribute %s:%s of <%s> uses a namespace prefix that is not declared", a.Name.Space, a.Name.Local, t.Name.Local)
		}
	}

	if dup, ok := repeatedAttr(t.Attr); ok {
		return malformed("the attribute %q appears more than once in <%s>", dup, t.Name.Local)
	}
	return nil
}

func (x *reader) close() {
	n := len(x.frames) - 1
	for _, uri := range x.frames[n] {
		if x.bound[uri]--; x.bound[uri] == 0 {
			delete(x.bound, uri)
		}
	}
	x.frames = x.frames[:n]
}

func (x *reader) isBound(space string) bool {
	return space == "" || space == xmlNamespace || x.bound[space] > 0
}

// wrap turns a decoder error into a plain-language error.
func (x *reader) wrap(err error) error {
	switch {
	case errors.Is(err, ErrTooLarge):
		return ErrTooLarge
	case x.src.err != nil:
		return fmt.Errorf("the document could not be read: %w", x.src.err)
	case x.badEncoding != "":
		return malformed("the document declares the %q character encoding; only UTF-8 is accepted", x.badEncoding)
	}

	var se *xml.SyntaxError
	if errors.As(err, &se) {
		if se.Msg == "unexpected EOF" {
			return malformed("the document ends before every element is closed")
		}
		return malformed("line %d: %s", se.Line, se.Msg)
	}
	return malformed("%v", err)
}

func repeatedAttr(attrs []xml.Attr) (string, bool) {
	if len(attrs) < 2 {
		return "", false
	}
	if len(attrs) <= 16 {
		for i := 1; i < len(attrs); i++ {
			for j := range i {
				if attrs[i].Name == attrs[j].Name {
					return attrs[i].Name.Local, true
				}
			}
		}
		return "", false
	}
	seen := make(map[xml.Name]struct{}, len(attrs))
	for _, a := range attrs {
		if _, ok := seen[a.Name]; ok {
			return a.Name.Local, true
		}
		seen[a.Name] = struct{}{}
	}
	return "", false
}

func isDoctype(d xml.Directive) bool {
	s := bytes.TrimSpace(d)
	return len(s) >= 7 && strings.EqualFold(string(s[:7]), "DOCTYPE")
}

// limitReader passes at most left bytes through and fails with ErrTooLarge
// on the first byte beyond them. It keeps the first error of the underlying
// reader, so a read failure is not mistaken for bad XML.
type limitReader struct {
	r    io.Reader
	left int64
	err  error
}

func (l *limitReader) Read(p []byte) (int, error) {
	if l.left < 0 {
		return 0, ErrTooLarge
	}
	if int64(len(p)) > l.left+1 {
		p = p[:l.left+1]
	}
	n, err := l.r.Read(p)
	l.left -= int64(n)
	if l.left < 0 {
		return 0, ErrTooLarge
	}
	if err != nil && err != io.EOF && l.err == nil {
		l.err = err
	}
	return n, err
}

// ---------------------------------------------------------------------

func idAndVersion(el xml.StartElement) (id, version string) {
	for _, a := range el.Attr {
		switch {
		case a.Name.Local == "id" && a.Name.Space == "":
			id = strings.TrimSpace(a.Value)
		case a.Name.Local == "version" && (a.Name.Space == "" || a.Name.Space == OpenRosaNamespace):
			if version == "" || a.Name.Space == "" {
				version = strings.TrimSpace(a.Value)
			}
		}
	}
	return id, version
}

func hasAttr(el xml.StartElement, local string) bool {
	for _, a := range el.Attr {
		if a.Name.Local == local && a.Name.Space == "" {
			return true
		}
	}
	return false
}

func describe(n xml.Name) string {
	if n.Space == "" {
		return fmt.Sprintf("<%s> in no namespace", n.Local)
	}
	return fmt.Sprintf("<%s> in the namespace %s", n.Local, n.Space)
}

func malformed(format string, args ...any) error {
	return fmt.Errorf("%w: %s", ErrMalformed, fmt.Sprintf(format, args...))
}

func notXForm(format string, args ...any) error {
	return fmt.Errorf("%w: %s", ErrNotXForm, fmt.Sprintf(format, args...))
}

func notInstance(format string, args ...any) error {
	return fmt.Errorf("%w: %s", ErrNotInstance, fmt.Sprintf(format, args...))
}
