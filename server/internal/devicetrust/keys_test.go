package devicetrust

import (
	"crypto/ecdh"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"math/big"
	"testing"
)

func mustHex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func encodePoint(p edPoint) []byte {
	be := p.y.FillBytes(make([]byte, KeyLength))
	le := make([]byte, KeyLength)
	for i := range be {
		le[i] = be[KeyLength-1-i]
	}
	le[KeyLength-1] |= byte(p.x.Bit(0)) << 7
	return le
}

func TestRealSigningKeysAreAccepted(t *testing.T) {
	// The base point of Ed25519 (RFC 8032).
	if err := CheckSignKey(mustHex(t, "5866666666666666666666666666666666666666666666666666666666666666")); err != nil {
		t.Errorf("base point: %v", err)
	}
	for i := 0; i < 50; i++ {
		pub, _, _ := ed25519.GenerateKey(rand.Reader)
		if err := CheckSignKey(pub); err != nil {
			t.Fatalf("generated key %x: %v", []byte(pub), err)
		}
		p, ok := decodePoint(pub)
		if !ok || hex.EncodeToString(encodePoint(p)) != hex.EncodeToString(pub) {
			t.Fatalf("decoding does not round-trip for %x", []byte(pub))
		}
	}
}

// Every small-order point is refused: the ones libsodium lists, and the
// torsion points found by multiplying random curve points by the group
// order.
func TestSmallOrderSigningKeysAreRefused(t *testing.T) {
	for _, h := range []string{
		"0000000000000000000000000000000000000000000000000000000000000000",
		"0100000000000000000000000000000000000000000000000000000000000000",
		"26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05",
		"c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a",
		"ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
		"edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", // p: non-canonical
		"eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", // p+1: non-canonical
		"0000000000000000000000000000000000000000000000000000000000000080", // -0
	} {
		if err := CheckSignKey(mustHex(t, h)); err == nil {
			t.Errorf("%s was accepted", h)
		}
	}

	order, _ := new(big.Int).SetString("7237005577332262213973186563042994240857116359379907606001950938285454250989", 10)
	found := map[string]bool{}
	for tries := 0; len(found) < 8 && tries < 400; tries++ {
		b := make([]byte, KeyLength)
		_, _ = rand.Read(b)
		p, ok := decodePoint(b)
		if !ok {
			continue
		}
		// order * P lies in the torsion subgroup.
		q := edPoint{big.NewInt(0), big.NewInt(1)}
		for i := order.BitLen() - 1; i >= 0; i-- {
			q = q.add(q)
			if order.Bit(i) == 1 {
				q = q.add(p)
			}
		}
		enc := encodePoint(q)
		found[hex.EncodeToString(enc)] = true
		if err := CheckSignKey(enc); err == nil {
			t.Fatalf("torsion point %x was accepted", enc)
		}
	}
	if len(found) < 8 {
		t.Errorf("found %d of the 8 torsion points", len(found))
	}
}

func TestEncryptionKeys(t *testing.T) {
	k, _ := ecdh.X25519().GenerateKey(rand.Reader)
	if err := CheckEncKey(k.PublicKey().Bytes()); err != nil {
		t.Errorf("generated key: %v", err)
	}
	for _, h := range []string{
		"0000000000000000000000000000000000000000000000000000000000000000",
		"0100000000000000000000000000000000000000000000000000000000000000",
		"e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800",
	} {
		if err := CheckEncKey(mustHex(t, h)); err == nil {
			t.Errorf("low-order key %s was accepted", h)
		}
	}
}
