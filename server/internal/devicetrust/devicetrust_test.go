package devicetrust

import (
	"crypto/ed25519"
	"encoding/base64"
	"testing"
)

// The test vectors in docs/decisions/0008-device-trust.md; the apps check
// the same values.
func TestCodeVector(t *testing.T) {
	sign := make([]byte, 32)
	enc := make([]byte, 32)
	for i := range sign {
		sign[i] = byte(i)
		enc[i] = byte(32 + i)
	}
	got := Code(sign, enc)
	t.Logf("code for keys 00..1f / 20..3f: %s", GroupCode(got))
	if got != "225142753699752889" {
		t.Fatalf("code %q, want the published vector 225142753699752889", got)
	}
	if NormaliseCode(GroupCode(got)) != got {
		t.Fatal("grouping and normalising do not round-trip")
	}
}

func TestBanglaDigits(t *testing.T) {
	if NormaliseCode("৪৮২ ৯১৩-0৫৭") != "482913057" {
		t.Fatal(NormaliseCode("৪৮২ ৯১৩-0৫৭"))
	}
}

func TestMessageAndVerify(t *testing.T) {
	seed := make([]byte, 32)
	priv := ed25519.NewKeyFromSeed(seed)
	pub := priv.Public().(ed25519.PublicKey)
	msg := Message("post", "/api/x?a=1", "1793836800", "AAAAAAAAAAAAAAAAAAAAAA", []byte("{}"))
	t.Logf("message: %q", msg)
	sig := base64.RawURLEncoding.EncodeToString(ed25519.Sign(priv, msg))
	t.Logf("signature with the all-zero seed: %s", sig)
	if sig != "jd5i3Nw3804mIJ7v6JiJZiZL0-fApy9xIFWavKqJpDe7ZsVhMVdXvkYfyBnm2GlRzO-fV95bdXGvCeL1YG9PAg" {
		t.Fatalf("signature %s differs from the published vector", sig)
	}
	if !Verify(pub, msg, sig) || Verify(pub, append(msg, '!'), sig) {
		t.Fatal("verify")
	}
	if !ValidNonce("AAAAAAAAAAAAAAAAAAAAAA") || ValidNonce("short") {
		t.Fatal("nonce")
	}
}

func TestKeysHaveOneSpelling(t *testing.T) {
	good := base64.StdEncoding.EncodeToString(make([]byte, 32)) // ends "A="
	if _, err := DecodeKey(good); err != nil {
		t.Fatal(err)
	}
	for _, bad := range []string{
		good[:len(good)-2] + "B=", // the same bytes with stray bits set
		good[:len(good)-1],        // no padding
		" " + good, good + "\n",
		base64.RawURLEncoding.EncodeToString(make([]byte, 32)),
		base64.StdEncoding.EncodeToString(make([]byte, 31)),
	} {
		if _, err := DecodeKey(bad); err == nil {
			t.Errorf("%q was accepted", bad)
		}
	}
}
