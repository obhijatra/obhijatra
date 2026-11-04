package audit

import (
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// VerifyResult describes a walk of the audit chain.
type VerifyResult struct {
	Entries  int64  // rows checked
	HeadSeq  int64  // seq of the last good row
	HeadHash string // hash of the last good row (GenesisHash if none)

	OK bool

	// When OK is false: the first row that does not link correctly.
	BrokenSeq int64
	BrokenID  string
	Problem   string
}

// Verify walks the chain from the first row, in seq order, and stops at the
// first broken link. It checks that seq values run 1, 2, 3... without gaps
// (a gap means rows were deleted), that each prev_hash equals the hash of
// the row before, and that each stored hash matches the row's contents.
//
// Removing rows from the end of the chain cannot be detected from the
// database alone; compare HeadSeq and HeadHash with a copy kept elsewhere.
func Verify(app core.App) (VerifyResult, error) {
	result := VerifyResult{HeadHash: GenesisHash}

	if !app.HasTable(schema.Audit) {
		return result, fmt.Errorf("there is no audit table; has `obhijatra-server init` been run?")
	}

	rows, err := app.DB().
		Select("id", "seq", "actor", "actor_collection", "device", "action", "collection",
			"record_id", "before_hash", "after_hash", "at", "prev_hash", "hash").
		From(schema.Audit).
		OrderBy("seq ASC").
		Rows()
	if err != nil {
		return result, fmt.Errorf("read audit chain: %w", err)
	}
	defer rows.Close()

	expectedSeq := int64(1)
	prevHash := GenesisHash

	for rows.Next() {
		var e Entry
		if err := rows.ScanStruct(&e); err != nil {
			return result, fmt.Errorf("read audit row %d: %w", expectedSeq, err)
		}

		fail := func(problem string) (VerifyResult, error) {
			result.OK = false
			result.BrokenSeq = e.Seq
			result.BrokenID = e.ID
			result.Problem = problem
			return result, nil
		}

		if e.Seq > expectedSeq {
			missing := e.Seq - expectedSeq
			return fail(fmt.Sprintf("expected entry %d but found entry %d: %d entr%s missing",
				expectedSeq, e.Seq, missing, plural(missing)))
		}
		if e.Seq < expectedSeq {
			return fail(fmt.Sprintf("expected entry %d but found entry %d again", expectedSeq, e.Seq))
		}
		if e.PrevHash != prevHash {
			return fail("its link to the previous entry (prev_hash) does not match that entry's hash")
		}
		computed, err := ComputeHash(e)
		if err != nil {
			return fail("its contents cannot be encoded: " + err.Error())
		}
		if computed != e.Hash {
			return fail("its contents were changed after it was written (stored hash does not match)")
		}

		result.Entries++
		result.HeadSeq = e.Seq
		result.HeadHash = e.Hash
		prevHash = e.Hash
		expectedSeq++
	}
	if err := rows.Err(); err != nil {
		return result, fmt.Errorf("read audit chain: %w", err)
	}

	result.OK = true
	return result, nil
}

func plural(n int64) string {
	if n == 1 {
		return "y"
	}
	return "ies"
}
