package api

import (
	"strconv"
	"testing"
	"time"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

func TestTheReplayMemory(t *testing.T) {
	w := schema.SignatureWindow
	t0 := time.Date(2026, 11, 6, 9, 0, 0, 0, time.UTC)
	nonces.buckets[0] = nil // start empty

	if !useNonce("d", "n1", t0) || useNonce("d", "n1", t0) {
		t.Fatal("a nonce must work once")
	}
	if !useNonce("other", "n1", t0) {
		t.Fatal("nonces are per device")
	}
	// Kept for more than twice the window, whenever within a bucket it
	// was first seen.
	for _, first := range []time.Duration{0, w - time.Second} {
		nonces.buckets[0] = nil
		seen := t0.Add(first)
		_ = useNonce("d", "start", t0)
		if !useNonce("d", "x", seen) {
			t.Fatal("fresh nonce refused")
		}
		for at := seen; at.Before(seen.Add(2*w + time.Second)); at = at.Add(30 * time.Second) {
			if useNonce("d", "x", at) {
				t.Fatalf("nonce first seen at +%v replayed at +%v", first, at.Sub(t0))
			}
		}
	}
	// Forgotten after a long quiet spell, without scanning.
	if !useNonce("d", "x", t0.Add(time.Hour)) {
		t.Error("an old nonce is still remembered after an hour")
	}
}

func BenchmarkTheReplayMemory(b *testing.B) {
	nonces.buckets[0] = nil
	now := time.Now()
	for i := 0; i < 300_000; i++ {
		useNonce("d", strconv.Itoa(i), now)
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		useNonce("e", strconv.Itoa(i), now)
	}
}
