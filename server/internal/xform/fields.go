package xform

import (
	"encoding/xml"
	"io"
	"strings"
)

// Kinds of Field.
const (
	KindValue     = "value"     // a question, calculation or metadata value
	KindStructure = "structure" // a group: holds other fields, no value of its own
	KindRepeat    = "repeat"    // a repeat group: its own table in an export
)

// Field is one node of a form's primary instance, as ODK Central lists it
// for exports.
type Field struct {
	// Path below the instance root, for example "/household/members/name"
	// (the root element itself is not part of it).
	Path string
	// Name is the node's local name, the last step of Path.
	Name string
	Kind string
	// Type is the XForms bind type of a value ("string", "int", "geopoint",
	// "binary", ...), "string" when the form binds no type; empty for
	// structures and repeats.
	Type string
	// SelectMultiple marks a value answered by a <select> control.
	SelectMultiple bool
}

// ParseFields reads a form definition with the same hardened reader as
// ParseDefinition and returns the fields of its primary instance in
// document order (depth first: a group, then everything inside it).
//
// Like ODK Central, it takes the tree from the primary instance, value
// types from <bind nodeset type>, repeats from <repeat nodeset> and select
// multiples from <select ref> in the body. Several copies of a repeat in
// the instance (including a jr:template copy) count once.
func ParseFields(r io.Reader) ([]Field, error) {
	x := newReader(r)

	const (
		headDepth     = 2
		modelDepth    = 3
		instanceDepth = 4
		rootDepth     = 5
	)
	var (
		inHead, inModel, inPrimary, inBody bool
		seenPrimary                        bool
		rootName                           string

		// the instance tree, in order of first appearance
		order    []string
		parent   = map[string]bool{} // path -> has element children
		instPath []string            // names below the root of the open instance elements

		types   = map[string]string{} // absolute nodeset -> bind type
		repeats = map[string]bool{}   // absolute nodeset of <repeat>
		selects = map[string]bool{}   // absolute ref of <select>

		// body context: the absolute path each open body element stands
		// for, so relative refs resolve against the nearest one
		bodyCtx []string
	)

	resolve := func(ref string) string {
		ref = strings.TrimSpace(ref)
		if ref == "" || strings.HasPrefix(ref, "/") {
			return ref
		}
		base := ""
		for i := len(bodyCtx) - 1; i >= 0; i-- {
			if bodyCtx[i] != "" {
				base = bodyCtx[i]
				break
			}
		}
		return base + "/" + ref
	}

	for {
		tok, err := x.next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}

		switch t := tok.(type) {
		case xml.StartElement:
			d := x.depth
			switch {
			case d == 1:
				if t.Name != htmlName {
					return nil, notXForm("the root element must be <h:html> in the XHTML namespace (%s), not %s", XHTMLNamespace, describe(t.Name))
				}
			case d == headDepth && t.Name == headName:
				inHead = true
			case d == headDepth && t.Name.Local == "body":
				inBody = true
			case d == modelDepth && inHead && t.Name == modelName:
				inModel = true
			case d == instanceDepth && inModel && t.Name == instanceName && !seenPrimary && !hasAttr(t, "id"):
				inPrimary, seenPrimary = true, true
			case d == instanceDepth && inModel && t.Name.Local == "bind":
				if ns, ty := attr(t, "nodeset"), attr(t, "type"); ns != "" && ty != "" {
					types[strings.TrimSpace(ns)] = localType(ty)
				}
			case d == rootDepth && inPrimary:
				if rootName != "" {
					return nil, notXForm("the primary <instance> must have exactly one root element")
				}
				rootName = t.Name.Local
			case d > rootDepth && inPrimary:
				instPath = append(instPath, t.Name.Local)
				p := "/" + strings.Join(instPath, "/")
				if _, seen := parent[p]; !seen {
					parent[p] = false
					order = append(order, p)
				}
				if len(instPath) > 1 {
					parent["/"+strings.Join(instPath[:len(instPath)-1], "/")] = true
				}
			case inBody:
				ctx := ""
				switch t.Name.Local {
				case "repeat":
					ctx = resolve(attr(t, "nodeset"))
					if ctx != "" {
						repeats[ctx] = true
					}
				case "group":
					ctx = resolve(attr(t, "ref"))
				case "select":
					if ref := resolve(attr(t, "ref")); ref != "" {
						selects[ref] = true
					}
				}
				bodyCtx = append(bodyCtx, ctx)
			}
		case xml.EndElement:
			closed := x.depth + 1 // the depth of the element that just closed
			switch {
			case inBody && closed > headDepth:
				bodyCtx = bodyCtx[:len(bodyCtx)-1]
			case closed == headDepth:
				inHead, inBody = false, false
			case closed == modelDepth:
				inModel = false
			case closed == instanceDepth && inPrimary:
				inPrimary = false
			case closed > rootDepth && inPrimary:
				instPath = instPath[:len(instPath)-1]
			}
		}
	}

	if rootName == "" {
		return nil, notXForm("the form has no primary instance with a root element")
	}

	abs := func(p string) string { return "/" + rootName + p }
	fields := make([]Field, 0, len(order))
	for _, p := range order {
		f := Field{Path: p, Name: p[strings.LastIndexByte(p, '/')+1:]}
		switch {
		case repeats[abs(p)]:
			f.Kind = KindRepeat
		case parent[p]:
			f.Kind = KindStructure
		default:
			f.Kind = KindValue
			f.Type = types[abs(p)]
			if f.Type == "" {
				f.Type = "string"
			}
			f.SelectMultiple = selects[abs(p)]
		}
		fields = append(fields, f)
	}
	return fields, nil
}

// attr returns the value of the attribute local in no namespace.
func attr(el xml.StartElement, local string) string {
	for _, a := range el.Attr {
		if a.Name.Local == local && a.Name.Space == "" {
			return a.Value
		}
	}
	return ""
}

// localType drops a namespace prefix from a bind type ("xsd:int" -> "int").
func localType(t string) string {
	t = strings.TrimSpace(t)
	if i := strings.LastIndexByte(t, ':'); i >= 0 {
		t = t[i+1:]
	}
	return t
}

// TokenReader yields the tokens of one XML document after the checks in
// the package comment (size, UTF-8, no declarations, well-formedness,
// nesting depth), for code that walks a whole instance.
type TokenReader struct{ x *reader }

// NewTokenReader reads one document from r.
func NewTokenReader(r io.Reader) *TokenReader { return &TokenReader{newReader(r)} }

// Next returns the next token, io.EOF at the clean end of the document, or
// an error wrapping ErrTooLarge or ErrMalformed.
func (t *TokenReader) Next() (xml.Token, error) { return t.x.next() }

// Depth is the nesting depth after the last token: 1 inside the root
// element, 0 outside it.
func (t *TokenReader) Depth() int { return t.x.depth }
