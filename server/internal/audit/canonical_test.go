package audit

import (
	"testing"
)

func TestCanonicalJSON(t *testing.T) {
	got, err := CanonicalJSON(map[string]any{
		"b":      "line\nbreak \"quoted\" back\\slash \x01 é",
		"a":      int64(42),
		"z":      nil,
		"é": "after z: keys sort by UTF-16 code units",
	})
	if err != nil {
		t.Fatal(err)
	}
	want := `{"a":42,"b":"line\nbreak \"quoted\" back\\slash \u0001 é","z":null,"é":"after z: keys sort by UTF-16 code units"}`
	if string(got) != want {
		t.Errorf("got  %s\nwant %s", got, want)
	}

	if _, err := CanonicalJSON(map[string]any{"bad": "\xff"}); err == nil {
		t.Error("invalid UTF-8 must be refused")
	}
	if _, err := CanonicalJSON(map[string]any{"big": int64(1 << 60)}); err == nil {
		t.Error("integers beyond 2^53 must be refused")
	}
}

// TestHashVector pins the chain format. If this test fails, the format has
// changed and every existing chain would stop verifying: do not update the
// expected value without a migration plan. The same vector is in ADR 0002
// so that other implementations (the manager app, an auditor's script) can
// check themselves against it.
func TestHashVector(t *testing.T) {
	e := Entry{
		ID:              "a00000000000001",
		Seq:             1,
		Actor:           "b00000000000001",
		ActorCollection: "staff_users",
		Device:          "",
		Action:          ActionCreate,
		Collection:      "locations",
		RecordID:        "c00000000000001",
		BeforeHash:      "",
		AfterHash:       "0000000000000000000000000000000000000000000000000000000000000001",
		At:              "2026-11-04T00:00:00.000000Z",
		PrevHash:        GenesisHash,
	}

	canonical, err := e.Canonical()
	if err != nil {
		t.Fatal(err)
	}
	wantCanonical := `{"action":"create","actor":"b00000000000001","actor_collection":"staff_users",` +
		`"after_hash":"0000000000000000000000000000000000000000000000000000000000000001",` +
		`"at":"2026-11-04T00:00:00.000000Z","before_hash":"","collection":"locations","device":"",` +
		`"id":"a00000000000001","prev_hash":"0000000000000000000000000000000000000000000000000000000000000000",` +
		`"record_id":"c00000000000001","seq":1}`
	if string(canonical) != wantCanonical {
		t.Fatalf("canonical form changed:\n got  %s\n want %s", canonical, wantCanonical)
	}

	hash, err := ComputeHash(e)
	if err != nil {
		t.Fatal(err)
	}
	const wantHash = "b7e9f0d81ff8d2a5adf53d4ec7c79c569a7816595a0e28f68a8a76be309b8d0d"
	if hash != wantHash {
		t.Errorf("hash = %s, want %s", hash, wantHash)
	}
}
