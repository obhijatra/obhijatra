package devicetrust

import (
	"crypto/ecdh"
	"crypto/rand"
	"errors"
	"math/big"
)

// A public key must be a real key: a "small-order" Ed25519 key verifies
// one fixed signature for every message, so whoever enrols it needs no
// private key at all, and a low-order X25519 key gives everyone the same
// shared secret.
var (
	errWeakSignKey = errors.New("the signing key is not a valid Ed25519 public key")
	errWeakEncKey  = errors.New("the encryption key is not a valid X25519 public key")
)

// Curve25519 in twisted Edwards form: -x^2 + y^2 = 1 + d x^2 y^2 (mod p).
var (
	edP       = new(big.Int).Sub(new(big.Int).Lsh(big.NewInt(1), 255), big.NewInt(19))
	edD       = mulMod(big.NewInt(-121665), new(big.Int).ModInverse(big.NewInt(121666), edP))
	edSqrtM1  = new(big.Int).Exp(big.NewInt(2), new(big.Int).Rsh(new(big.Int).Sub(edP, big.NewInt(1)), 2), edP)
	edSqrtExp = new(big.Int).Rsh(new(big.Int).Sub(edP, big.NewInt(5)), 3) // (p-5)/8
)

func mulMod(a, b *big.Int) *big.Int {
	r := new(big.Int).Mul(a, b)
	return r.Mod(r, edP)
}

type edPoint struct{ x, y *big.Int }

// decodePoint reads a canonical point encoding (RFC 8032, 5.1.3), or
// returns false.
func decodePoint(b []byte) (edPoint, bool) {
	if len(b) != KeyLength {
		return edPoint{}, false
	}
	le := make([]byte, KeyLength)
	for i := range b {
		le[KeyLength-1-i] = b[i]
	}
	sign := le[0] >> 7
	le[0] &= 0x7f
	y := new(big.Int).SetBytes(le)
	if y.Cmp(edP) >= 0 {
		return edPoint{}, false // y written in a non-canonical way
	}
	yy := mulMod(y, y)
	u := new(big.Int).Sub(yy, big.NewInt(1))
	u.Mod(u, edP)
	v := new(big.Int).Add(mulMod(edD, yy), big.NewInt(1))
	v.Mod(v, edP)
	// x = u v^3 (u v^7)^((p-5)/8)
	v3 := mulMod(mulMod(v, v), v)
	x := mulMod(u, v3)
	x = mulMod(x, new(big.Int).Exp(mulMod(u, mulMod(v3, mulMod(v3, v))), edSqrtExp, edP))
	vxx := mulMod(v, mulMod(x, x))
	negU := new(big.Int).Sub(edP, u)
	negU.Mod(negU, edP)
	switch {
	case vxx.Cmp(u) == 0:
	case vxx.Cmp(negU) == 0:
		x = mulMod(x, edSqrtM1)
	default:
		return edPoint{}, false // not on the curve
	}
	if x.Sign() == 0 && sign == 1 {
		return edPoint{}, false // "-0"
	}
	if uint(x.Bit(0)) != uint(sign) {
		x.Sub(edP, x)
	}
	return edPoint{x, y}, true
}

// add is the complete twisted Edwards addition (a = -1).
func (p edPoint) add(q edPoint) edPoint {
	x1x2 := mulMod(p.x, q.x)
	y1y2 := mulMod(p.y, q.y)
	dxy := mulMod(edD, mulMod(x1x2, y1y2))
	one := big.NewInt(1)
	xNum := new(big.Int).Add(mulMod(p.x, q.y), mulMod(p.y, q.x))
	xDen := new(big.Int).Add(one, dxy)
	yNum := new(big.Int).Add(y1y2, x1x2)
	yDen := new(big.Int).Sub(one, dxy)
	xDen.Mod(xDen, edP)
	yDen.Mod(yDen, edP)
	return edPoint{
		mulMod(xNum, new(big.Int).ModInverse(xDen, edP)),
		mulMod(yNum, new(big.Int).ModInverse(yDen, edP)),
	}
}

func (p edPoint) isIdentity() bool { return p.x.Sign() == 0 && p.y.Cmp(big.NewInt(1)) == 0 }

// CheckSignKey refuses an Ed25519 public key that is not a canonical
// encoding of a curve point, or whose point has small order (8P is the
// identity).
func CheckSignKey(key []byte) error {
	p, ok := decodePoint(key)
	if !ok {
		return errWeakSignKey
	}
	q := p.add(p)
	q = q.add(q)
	q = q.add(q)
	if q.isIdentity() {
		return errWeakSignKey
	}
	return nil
}

// CheckEncKey refuses an X25519 public key of low order, which would give
// the same shared secret with every key.
func CheckEncKey(key []byte) error {
	pub, err := ecdh.X25519().NewPublicKey(key)
	if err != nil {
		return errWeakEncKey
	}
	priv, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		return err
	}
	if _, err := priv.ECDH(pub); err != nil {
		return errWeakEncKey
	}
	return nil
}
