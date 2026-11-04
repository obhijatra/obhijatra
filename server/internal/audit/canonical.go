package audit

import (
	"bytes"
	"errors"
	"fmt"
	"slices"
	"unicode/utf16"
	"unicode/utf8"
)

// CanonicalJSON encodes a flat JSON object deterministically, following the
// rules of RFC 8785 (JSON Canonicalization Scheme) for the value types the
// audit chain uses:
//
//   - members sorted by key, comparing keys as UTF-16 code units;
//   - no whitespace between tokens;
//   - strings escaped minimally: \" \\ \b \f \n \r \t, other characters
//     below U+0020 as \u00xx (lower-case hex), everything else as UTF-8;
//   - integers in plain decimal, within ±(2^53-1);
//   - nil as null.
//
// Any implementation in any language that follows these rules produces the
// same bytes, so the chain can be verified outside Obhijatra.
func CanonicalJSON(obj map[string]any) ([]byte, error) {
	keys := make([]string, 0, len(obj))
	for k := range obj {
		keys = append(keys, k)
	}
	slices.SortFunc(keys, compareUTF16)

	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, k := range keys {
		if i > 0 {
			buf.WriteByte(',')
		}
		if err := writeString(&buf, k); err != nil {
			return nil, fmt.Errorf("key %q: %w", k, err)
		}
		buf.WriteByte(':')
		if err := writeValue(&buf, obj[k]); err != nil {
			return nil, fmt.Errorf("value of %q: %w", k, err)
		}
	}
	buf.WriteByte('}')

	return buf.Bytes(), nil
}

const maxSafeInteger = 1<<53 - 1

func writeValue(buf *bytes.Buffer, v any) error {
	switch val := v.(type) {
	case nil:
		buf.WriteString("null")
	case string:
		return writeString(buf, val)
	case int64:
		if val > maxSafeInteger || val < -maxSafeInteger {
			return errors.New("integer outside the safe JSON range")
		}
		fmt.Fprintf(buf, "%d", val)
	case int:
		return writeValue(buf, int64(val))
	default:
		return fmt.Errorf("unsupported type %T", v)
	}
	return nil
}

func writeString(buf *bytes.Buffer, s string) error {
	if !utf8.ValidString(s) {
		return errors.New("string is not valid UTF-8")
	}

	const hex = "0123456789abcdef"

	buf.WriteByte('"')
	for _, r := range s {
		switch r {
		case '"':
			buf.WriteString(`\"`)
		case '\\':
			buf.WriteString(`\\`)
		case '\b':
			buf.WriteString(`\b`)
		case '\f':
			buf.WriteString(`\f`)
		case '\n':
			buf.WriteString(`\n`)
		case '\r':
			buf.WriteString(`\r`)
		case '\t':
			buf.WriteString(`\t`)
		default:
			if r < 0x20 {
				buf.WriteString(`\u00`)
				buf.WriteByte(hex[r>>4])
				buf.WriteByte(hex[r&0xf])
			} else {
				buf.WriteRune(r)
			}
		}
	}
	buf.WriteByte('"')

	return nil
}

func compareUTF16(a, b string) int {
	return slices.Compare(utf16.Encode([]rune(a)), utf16.Encode([]rune(b)))
}
