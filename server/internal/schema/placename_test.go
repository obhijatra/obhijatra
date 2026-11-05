package schema

import "testing"

func TestPlaceNameKey(t *testing.T) {
	same := [][2]string{
		{"\u09a8\u09df\u09be\u09aa\u09be\u09dc\u09be", "\u09a8\u09af\u09bc\u09be\u09aa\u09be\u09a1\u09bc\u09be"}, // নয়াপাড়া: য় and ড় as one character, and as two
		{"Branch 1", " branch  1 "},
		{"Branch 1", "Branch\u200b 1"},
		{"Branch 1", "Branch\u00a01"},
		{"ΟΔΟΣ", "οδος"},
		{"οδοσ", "οδος"},
	}
	for _, p := range same {
		if PlaceNameKey(p[0]) != PlaceNameKey(p[1]) {
			t.Errorf("%q and %q should share a key: %q / %q", p[0], p[1], PlaceNameKey(p[0]), PlaceNameKey(p[1]))
		}
	}
	if PlaceNameKey("Branch 1") == PlaceNameKey("Branch 2") {
		t.Error("different names share a key")
	}
	// Zero-width joiner and non-joiner change Bangla shapes: kept.
	if CleanPlaceName("র\u200dযা") != "র\u200dযা" {
		t.Error("the zero-width joiner was removed")
	}
	if !UnsafeTextRune('\u202e') || !UnsafeTextRune('\n') || UnsafeTextRune('ক') {
		t.Error("UnsafeTextRune")
	}
}
