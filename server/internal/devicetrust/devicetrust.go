// Package devicetrust holds the pieces of device-signed requests that the
// server, its command line and the apps must agree on byte for byte
// (docs/decisions/0008-device-trust.md): the device check code, the
// signed message and the header names.
package devicetrust

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
)

// Request headers of a device-signed request.
const (
	HeaderDevice    = "X-Obhijatra-Device"
	HeaderTime      = "X-Obhijatra-Time"
	HeaderNonce     = "X-Obhijatra-Nonce"
	HeaderSignature = "X-Obhijatra-Signature"
)

// KeyLength is the length of an Ed25519 or X25519 public key.
const KeyLength = 32

// codeLabel separates the check code from every other use of the keys.
const codeLabel = "obhijatra-device-code-v1"

// CodeDigits is the length of a device check code.
const CodeDigits = 18

// DecodeKey reads a public key in standard base64 (with padding), written
// the one canonical way, so a key cannot be stored twice under two
// spellings.
func DecodeKey(b64 string) ([]byte, error) {
	key, err := base64.StdEncoding.Strict().DecodeString(b64)
	if err != nil || len(key) != KeyLength || base64.StdEncoding.EncodeToString(key) != b64 {
		return nil, errors.New("a public key must be 32 bytes in standard base64")
	}
	return key, nil
}

// Code is a device's check code: 18 decimal digits derived from its two
// public keys. The device shows it; the person approving the device types
// it; both sides derive it from the keys, so a key swapped on the way
// gives a different code. It is not secret.
//
//	digest = SHA-256("obhijatra-device-code-v1" || 0x00 || signKey || encKey)
//	code   = big-endian uint64(digest[0:8]) mod 10^18, as 18 digits
func Code(signKey, encKey []byte) string {
	h := sha256.New()
	h.Write([]byte(codeLabel))
	h.Write([]byte{0})
	h.Write(signKey)
	h.Write(encKey)
	n := binary.BigEndian.Uint64(h.Sum(nil)[:8])
	return fmt.Sprintf("%018d", n%1_000_000_000_000_000_000)
}

// GroupCode writes a code as six groups of three digits.
func GroupCode(code string) string {
	var groups []string
	for i := 0; i+3 <= len(code); i += 3 {
		groups = append(groups, code[i:i+3])
	}
	return strings.Join(groups, " ")
}

// NormaliseCode keeps only the digits of what a person typed, Bangla
// digits read as their ASCII values.
func NormaliseCode(typed string) string {
	var b strings.Builder
	for _, r := range typed {
		switch {
		case r >= '0' && r <= '9':
			b.WriteRune(r)
		case r >= '০' && r <= '৯':
			b.WriteRune('0' + (r - '০'))
		}
	}
	return b.String()
}

// Message is what a device signs for one request:
//
//	"OBHIJATRA-REQUEST-V1\n" + method + "\n" + target + "\n" + time + "\n" +
//	nonce + "\n" + hex(SHA-256(body))
//
// target is the request target exactly as sent: the path and, if any,
// "?" and the query.
func Message(method, target, unixTime, nonce string, body []byte) []byte {
	sum := sha256.Sum256(body)
	return []byte("OBHIJATRA-REQUEST-V1\n" + strings.ToUpper(method) + "\n" + target + "\n" +
		unixTime + "\n" + nonce + "\n" + hex.EncodeToString(sum[:]))
}

// Verify checks a base64url (no padding) signature over message with an
// Ed25519 public key.
func Verify(signKey, message []byte, signatureB64 string) bool {
	sig, err := base64.RawURLEncoding.DecodeString(signatureB64)
	if err != nil || len(sig) != ed25519.SignatureSize || len(signKey) != ed25519.PublicKeySize {
		return false
	}
	return ed25519.Verify(signKey, message, sig)
}

// ValidNonce reports whether nonce is 16 bytes in base64url without
// padding (22 characters).
func ValidNonce(nonce string) bool {
	b, err := base64.RawURLEncoding.DecodeString(nonce)
	return err == nil && len(b) == 16
}
