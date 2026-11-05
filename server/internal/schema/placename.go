package schema

import (
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"
)

// invisible are characters that change nothing a person can see in a place
// name, so they are removed: zero-width space, word joiner, byte-order
// mark and soft hyphen. Zero-width joiner and non-joiner stay, because
// Bangla uses them to choose letter shapes.
var invisible = map[rune]bool{'\u200b': true, '\u2060': true, '\ufeff': true, '\u00ad': true}

// CleanPlaceName is how a place name is stored: Unicode NFC (so a Bangla
// letter typed as one character or as two is the same text), invisible
// characters removed, and every run of spaces one space, trimmed.
func CleanPlaceName(name string) string {
	name = norm.NFC.String(name)
	var b strings.Builder
	space := false
	for _, r := range name {
		switch {
		case invisible[r]:
			continue
		case unicode.IsSpace(r):
			space = true
			continue
		}
		if space && b.Len() > 0 {
			b.WriteByte(' ')
		}
		space = false
		b.WriteRune(r)
	}
	return b.String()
}

// PlaceNameKey is what two place names must share to count as the same
// name: the clean name with every letter folded to one case form, the
// same equivalence strings.EqualFold uses (so σ, ς and Σ match).
func PlaceNameKey(name string) string {
	clean := CleanPlaceName(name)
	var b strings.Builder
	b.Grow(len(clean))
	for _, r := range clean {
		b.WriteRune(foldRune(r))
	}
	return b.String()
}

// foldRune is the smallest rune in r's case-folding orbit.
func foldRune(r rune) rune {
	least := r
	for f := unicode.SimpleFold(r); f != r; f = unicode.SimpleFold(f) {
		if f < least {
			least = f
		}
	}
	return least
}

// UnsafeTextRune reports whether r has no place in a name or code: control
// characters and line or paragraph separators (which break a line), the
// bidirectional marks, overrides and isolates (which can make text display
// in a misleading order), and invisible spaces and joiners other than the
// zero-width joiner and non-joiner, which Bangla spelling needs.
func UnsafeTextRune(r rune) bool {
	switch {
	case unicode.IsControl(r),
		r >= '\u202a' && r <= '\u202e', r >= '\u2066' && r <= '\u2069',
		r == '\u2028', r == '\u2029',
		r == '\u200e', r == '\u200f', r == '\u061c',
		r == '\u200b', r == '\u2060', r == '\ufeff':
		return true
	}
	return false
}

// TextLength is the length of s in characters, as the record fields count
// it.
func TextLength(s string) int { return utf8.RuneCountInString(s) }
