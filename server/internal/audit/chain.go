// Package audit keeps Obhijatra's tamper-evident audit chain.
//
// Every create, update and delete of a record, a collection (schema) or the
// server settings appends one row to the "audit" collection inside the same
// database transaction as the change. Each row stores the SHA-256 of the
// previous row, so deleting or editing any row breaks the chain from that
// point on, which `obhijatra-server audit verify` reports.
//
// The chain is append-only against the API and every Go code path,
// superusers and the Dashboard included. It is tamper-evident, not
// tamper-proof, against someone who can edit the database file: such a
// person can rewrite the chain from any row onwards. Off-server anchors of
// the head hash (zero-trust milestone) close that gap.
package audit

import (
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"time"
	"unicode/utf8"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// GenesisHash is the prev_hash of the first row in the chain.
const GenesisHash = "0000000000000000000000000000000000000000000000000000000000000000"

// Actions recorded in the chain.
const (
	ActionCreate = "create"
	ActionUpdate = "update"
	ActionDelete = "delete"
)

// TimeFormat is the layout of the "at" field: RFC 3339, UTC, microseconds.
const TimeFormat = "2006-01-02T15:04:05.000000Z"

// ErrAppendOnly is returned for any attempt to create, change or delete an
// audit row other than through the chain itself.
var ErrAppendOnly = errors.New("the audit log is append-only: its rows cannot be created, changed or deleted directly")

// Entry is one row of the audit chain.
type Entry struct {
	ID              string `db:"id"`
	Seq             int64  `db:"seq"`
	Actor           string `db:"actor"`
	ActorCollection string `db:"actor_collection"`
	Device          string `db:"device"`
	Action          string `db:"action"`
	Collection      string `db:"collection"`
	RecordID        string `db:"record_id"`
	BeforeHash      string `db:"before_hash"`
	AfterHash       string `db:"after_hash"`
	At              string `db:"at"`
	PrevHash        string `db:"prev_hash"`
	Hash            string `db:"hash"`
}

// Canonical returns the canonical JSON of every field except hash.
func (e Entry) Canonical() ([]byte, error) {
	return CanonicalJSON(map[string]any{
		"id":               e.ID,
		"seq":              e.Seq,
		"actor":            e.Actor,
		"actor_collection": e.ActorCollection,
		"device":           e.Device,
		"action":           e.Action,
		"collection":       e.Collection,
		"record_id":        e.RecordID,
		"before_hash":      e.BeforeHash,
		"after_hash":       e.AfterHash,
		"at":               e.At,
		"prev_hash":        e.PrevHash,
	})
}

// ComputeHash returns lower-case hex SHA-256 of the prev_hash text (64 hex
// characters, as stored) followed by the entry's canonical JSON.
func ComputeHash(e Entry) (string, error) {
	canonical, err := e.Canonical()
	if err != nil {
		return "", err
	}

	h := sha256.New()
	h.Write([]byte(e.PrevHash))
	h.Write(canonical)

	return hex.EncodeToString(h.Sum(nil)), nil
}

// isEnabled reports whether the audit table exists in txApp's database.
// It is false only before the initial migration has created it. If the
// collection is registered but its table is missing, something removed it
// behind PocketBase's back, and every write is refused (fail closed).
func isEnabled(txApp core.App) (bool, error) {
	if txApp.HasTable(schema.Audit) {
		return true, nil
	}
	if _, err := txApp.FindCollectionByNameOrId(schema.Audit); err == nil {
		return false, errors.New("the audit collection exists but its table is missing; refusing to write without an audit trail")
	}
	return false, nil
}

// appendEntry adds e to the chain. txApp must be inside a transaction so
// that reading the head and inserting the new row cannot interleave with
// another writer; the unique index on seq rejects a fork even if they did.
func appendEntry(txApp core.App, e Entry) error {
	if txApp.TxInfo() == nil {
		return errors.New("audit: appendEntry called outside a transaction")
	}

	var head struct {
		Seq  int64  `db:"seq"`
		Hash string `db:"hash"`
	}
	err := txApp.NonconcurrentDB().
		Select("seq", "hash").
		From(schema.Audit).
		OrderBy("seq DESC").
		Limit(1).
		One(&head)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		head.Seq = 0
		head.Hash = GenesisHash
	case err != nil:
		return fmt.Errorf("audit: read chain head: %w", err)
	}

	e.ID = security.RandomStringWithAlphabet(core.DefaultIdLength, core.DefaultIdAlphabet)
	e.Seq = head.Seq + 1
	e.PrevHash = head.Hash
	e.At = time.Now().UTC().Format(TimeFormat)

	e.Hash, err = ComputeHash(e)
	if err != nil {
		return fmt.Errorf("audit: hash entry: %w", err)
	}

	// A raw insert, not app.Save: the record hooks reject every model-level
	// write to the audit collection, so this is the only way in.
	_, err = txApp.NonconcurrentDB().Insert(schema.Audit, dbx.Params{
		"id":               e.ID,
		"seq":              e.Seq,
		"actor":            e.Actor,
		"actor_collection": e.ActorCollection,
		"device":           e.Device,
		"action":           e.Action,
		"collection":       e.Collection,
		"record_id":        e.RecordID,
		"before_hash":      e.BeforeHash,
		"after_hash":       e.AfterHash,
		"at":               e.At,
		"prev_hash":        e.PrevHash,
		"hash":             e.Hash,
	}).Execute()
	if err != nil {
		return fmt.Errorf("audit: append entry: %w", err)
	}

	return nil
}

// rowHash returns the SHA-256 of the canonical JSON of a stored database
// row (every column, values as SQLite returns them as text, NULL as null),
// or "" if the row does not exist. It describes exactly what was persisted,
// including password hashes and encrypted settings, without copying any
// value into the audit chain.
func rowHash(txApp core.App, table, id string) (string, error) {
	if id == "" {
		return "", nil
	}

	row := dbx.NullStringMap{}
	err := txApp.NonconcurrentDB().
		Select("*").
		From(table).
		Where(dbx.HashExp{"id": id}).
		Limit(1).
		One(row)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("audit: read %s/%s: %w", table, id, err)
	}

	obj := make(map[string]any, len(row))
	for k, v := range row {
		switch {
		case !v.Valid:
			obj[k] = nil
		case utf8.ValidString(v.String):
			obj[k] = v.String
		default:
			// PocketBase stores text and numbers only; a binary value would
			// come from outside it. Encode it losslessly and visibly.
			obj[k] = "\x00base64:" + base64.StdEncoding.EncodeToString([]byte(v.String))
		}
	}

	canonical, err := CanonicalJSON(obj)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(canonical)

	return hex.EncodeToString(sum[:]), nil
}
