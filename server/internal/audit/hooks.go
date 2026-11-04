package audit

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// hookPriority makes the audit wrappers run before every other handler, so
// the transaction they open encloses all other hooks and the write itself.
const hookPriority = -1000

const (
	collectionsTable = "_collections"
	paramsTable      = "_params"
	settingsParamKey = "settings"
)

// Register binds the audit chain to app. Call it once, before the app
// bootstraps or serves.
func Register(app core.App) {
	// Record writes, from any source: API, Dashboard, Go code, CLI.
	for _, h := range []struct {
		hook   *hook.TaggedHook[*core.RecordEvent]
		action string
	}{
		{app.OnRecordCreate(), ActionCreate},
		{app.OnRecordUpdate(), ActionUpdate},
		{app.OnRecordDelete(), ActionDelete},
	} {
		action := h.action
		h.hook.Bind(&hook.Handler[*core.RecordEvent]{
			Id:       "obhijatraAuditRecord_" + action,
			Priority: hookPriority,
			Func: func(e *core.RecordEvent) error {
				collection := e.Record.Collection()
				if collection.Name == schema.Audit {
					return ErrAppendOnly
				}
				if collection.IsView() {
					return e.Next()
				}
				return wrap(&e.App, action, collection.Name, func() string { return e.Record.Id }, e.Next)
			},
		})
	}

	// Schema writes: collections created, changed or deleted.
	for _, h := range []struct {
		hook   *hook.TaggedHook[*core.CollectionEvent]
		action string
	}{
		{app.OnCollectionCreate(), ActionCreate},
		{app.OnCollectionUpdate(), ActionUpdate},
		{app.OnCollectionDelete(), ActionDelete},
	} {
		action := h.action
		h.hook.Bind(&hook.Handler[*core.CollectionEvent]{
			Id:       "obhijatraAuditCollection_" + action,
			Priority: hookPriority,
			Func: func(e *core.CollectionEvent) error {
				if err := guardAuditCollection(e, action); err != nil {
					return err
				}
				return wrap(&e.App, action, collectionsTable, func() string { return e.Collection.Id }, e.Next)
			},
		})
	}

	// Server settings (rate limits, log retention, SMTP, superuser IPs...).
	for _, h := range []struct {
		hook   *hook.TaggedHook[*core.ModelEvent]
		action string
	}{
		{app.OnModelCreate(paramsTable), ActionCreate},
		{app.OnModelUpdate(paramsTable), ActionUpdate},
	} {
		action := h.action
		h.hook.Bind(&hook.Handler[*core.ModelEvent]{
			Id:       "obhijatraAuditSettings_" + action,
			Priority: hookPriority,
			Func: func(e *core.ModelEvent) error {
				if fmt.Sprint(e.Model.PK()) != settingsParamKey {
					return e.Next()
				}
				return wrap(&e.App, action, paramsTable, func() string { return settingsParamKey }, e.Next)
			},
		})
	}

	bindRequestAttribution(app)
}

// wrap runs next inside a transaction and appends one audit entry for it in
// that same transaction. If next or the append fails, both roll back.
//
// table is the database table written: a record's collection name, or
// "_collections" for schema changes and "_params" for server settings. It
// becomes the entry's "collection" column.
//
// appRef points at the event's App field: handlers that run after this one,
// and the database write itself, must use the transactional app.
func wrap(appRef *core.App, action, table string, id func() string, next func() error) error {
	original := *appRef

	return original.RunInTransaction(func(txApp core.App) error {
		*appRef = txApp
		defer func() { *appRef = original }()

		enabled, err := isEnabled(txApp)
		if err != nil {
			return err
		}

		var before string
		if enabled && action != ActionCreate {
			if before, err = rowHash(txApp, table, id()); err != nil {
				return err
			}
		}

		if err := next(); err != nil {
			return err
		}

		if !enabled {
			// The write may have been the creation of the audit table itself.
			if enabled, err = isEnabled(txApp); err != nil || !enabled {
				return err
			}
		}

		var after string
		if action != ActionDelete {
			if after, err = rowHash(txApp, table, id()); err != nil {
				return err
			}
		}

		actor := ActorOf(txApp)

		return appendEntry(txApp, Entry{
			Actor:           actor.ID,
			ActorCollection: actor.Collection,
			Device:          actor.Device,
			Action:          action,
			Collection:      table,
			RecordID:        id(),
			BeforeHash:      before,
			AfterHash:       after,
		})
	})
}

// guardAuditCollection keeps the audit collection itself in place: it cannot
// be deleted or renamed, lose or retype a field, or gain a create, update
// or delete API rule. These checks bind superusers and migrations alike.
func guardAuditCollection(e *core.CollectionEvent, action string) error {
	switch action {
	case ActionDelete:
		if e.Collection.Name == schema.Audit {
			return ErrAppendOnly
		}
	case ActionUpdate:
		old, err := e.App.FindCollectionByNameOrId(e.Collection.Id)
		if err != nil || old.Name != schema.Audit {
			return nil
		}
		if e.Collection.Name != schema.Audit {
			return errors.New("the audit collection cannot be renamed")
		}
		if e.Collection.CreateRule != nil || e.Collection.UpdateRule != nil || e.Collection.DeleteRule != nil {
			return errors.New("the audit collection cannot have a create, update or delete API rule")
		}
		for _, f := range old.Fields {
			nf := e.Collection.Fields.GetById(f.GetId())
			if nf == nil || nf.GetName() != f.GetName() || nf.Type() != f.Type() {
				return fmt.Errorf("the audit collection's field %q cannot be removed, renamed or retyped", f.GetName())
			}
		}
	}
	return nil
}
