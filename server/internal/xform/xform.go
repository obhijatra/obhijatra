// Package xform reads the few facts the server needs from ODK XForms XML:
// a form definition's id and version, and a submission instance's form id,
// form version and instanceID.
//
// It never resolves DTDs or external entities (Go's encoding/xml does not),
// rejects any document that declares one, and is meant to be given a
// size-limited reader.
package xform

import (
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strings"
)

// orxNamespace is the OpenRosa namespace; ODK accepts orx:version as an
// alternative to a plain version attribute.
const orxNamespace = "http://openrosa.org/xforms"

// ErrNotXML is wrapped by every parse failure.
var ErrNotXML = errors.New("not a valid XForms document")

// instanceIDPattern accepts ODK's "uuid:<uuid>" and similar identifiers but
// nothing that could be confused with a path or markup.
var instanceIDPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$`)

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

func newDecoder(r io.Reader) *xml.Decoder {
	d := xml.NewDecoder(r)
	d.Strict = true
	return d
}

// next returns the next token, refusing DTDs and entity declarations.
func next(d *xml.Decoder) (xml.Token, error) {
	tok, err := d.Token()
	if err != nil {
		return nil, err
	}
	if dir, ok := tok.(xml.Directive); ok {
		if strings.HasPrefix(strings.TrimSpace(string(dir)), "DOCTYPE") {
			return nil, fmt.Errorf("%w: document type declarations are not allowed", ErrNotXML)
		}
		return nil, fmt.Errorf("%w: XML directives are not allowed", ErrNotXML)
	}
	return tok, nil
}

func idAndVersion(el xml.StartElement) (id, version string) {
	for _, a := range el.Attr {
		switch {
		case a.Name.Local == "id" && a.Name.Space == "":
			id = strings.TrimSpace(a.Value)
		case a.Name.Local == "version" && (a.Name.Space == "" || a.Name.Space == orxNamespace):
			if version == "" || a.Name.Space == "" {
				version = strings.TrimSpace(a.Value)
			}
		}
	}
	return id, version
}

// ParseDefinition reads the primary instance of an XForm definition:
// html > head > model > the first instance without an id attribute > its
// root element.
func ParseDefinition(r io.Reader) (Definition, error) {
	d := newDecoder(r)

	var (
		depth           int
		inModel         bool
		modelDepth      int
		inPrimary       bool
		primaryDepth    int
		seenRootElement bool
	)

	for {
		tok, err := next(d)
		if err == io.EOF {
			break
		}
		if err != nil {
			return Definition{}, wrapErr(err)
		}

		switch t := tok.(type) {
		case xml.StartElement:
			depth++
			if !seenRootElement {
				seenRootElement = true
				if t.Name.Local != "html" {
					return Definition{}, fmt.Errorf("%w: the root element is <%s>, expected <html>", ErrNotXML, t.Name.Local)
				}
				continue
			}
			switch {
			case inPrimary && depth == primaryDepth+1:
				id, version := idAndVersion(t)
				if id == "" {
					return Definition{}, fmt.Errorf("%w: the primary instance has no id attribute", ErrNotXML)
				}
				return Definition{FormID: id, Version: version}, nil
			case inModel && !inPrimary && depth == modelDepth+1 && t.Name.Local == "instance" && !hasAttr(t, "id"):
				inPrimary = true
				primaryDepth = depth
			case !inModel && t.Name.Local == "model":
				inModel = true
				modelDepth = depth
			}
		case xml.EndElement:
			if inPrimary && depth == primaryDepth {
				return Definition{}, fmt.Errorf("%w: the primary instance is empty", ErrNotXML)
			}
			depth--
		}
	}

	return Definition{}, fmt.Errorf("%w: no primary <instance> found inside <model>", ErrNotXML)
}

// ParseInstance reads a submission instance: the root element's id and
// version attributes and the text of its meta/instanceID child.
func ParseInstance(r io.Reader) (Instance, error) {
	d := newDecoder(r)

	var (
		inst        Instance
		depth       int
		inMeta      bool
		inID        bool
		idText      strings.Builder
		foundID     bool
		seenRoot    bool
		rootEnded   bool
		textElement int
	)

	for {
		tok, err := next(d)
		if err == io.EOF {
			break
		}
		if err != nil {
			return Instance{}, wrapErr(err)
		}

		switch t := tok.(type) {
		case xml.StartElement:
			if rootEnded {
				return Instance{}, fmt.Errorf("%w: more than one root element", ErrNotXML)
			}
			depth++
			switch {
			case !seenRoot:
				seenRoot = true
				inst.FormID, inst.Version = idAndVersion(t)
			case depth == 2 && t.Name.Local == "meta":
				inMeta = true
			case inMeta && depth == 3 && t.Name.Local == "instanceID":
				if foundID {
					return Instance{}, fmt.Errorf("%w: more than one meta/instanceID", ErrNotXML)
				}
				inID = true
				textElement = depth
			case inID:
				return Instance{}, fmt.Errorf("%w: meta/instanceID must contain text only", ErrNotXML)
			}
		case xml.CharData:
			if inID {
				idText.Write(t)
			}
		case xml.EndElement:
			if inID && depth == textElement {
				inID = false
				foundID = true
				inst.InstanceID = strings.TrimSpace(idText.String())
			}
			if inMeta && depth == 2 {
				inMeta = false
			}
			depth--
			if depth == 0 {
				rootEnded = true
			}
		}
	}

	switch {
	case !seenRoot:
		return Instance{}, fmt.Errorf("%w: the document is empty", ErrNotXML)
	case inst.FormID == "":
		return Instance{}, fmt.Errorf("%w: the root element has no id attribute (the form id)", ErrNotXML)
	case !foundID || inst.InstanceID == "":
		return Instance{}, fmt.Errorf("%w: meta/instanceID is missing", ErrNotXML)
	case !instanceIDPattern.MatchString(inst.InstanceID):
		return Instance{}, fmt.Errorf("%w: meta/instanceID has characters or a length that are not allowed", ErrNotXML)
	}

	return inst, nil
}

func hasAttr(el xml.StartElement, local string) bool {
	for _, a := range el.Attr {
		if a.Name.Local == local {
			return true
		}
	}
	return false
}

func wrapErr(err error) error {
	if errors.Is(err, ErrNotXML) {
		return err
	}
	return fmt.Errorf("%w: %v", ErrNotXML, err)
}
