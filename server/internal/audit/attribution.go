package audit

import (
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
)

// bindRequestAttribution wraps PocketBase's write requests (record CRUD,
// collection changes, settings changes) in a transaction attributed to the
// request's authenticated record, so the audit entries the model hooks
// write name the real actor, including superusers using the Dashboard.
//
// PocketBase's handlers are built for this: they delay writing the response
// until the transaction commits.
func bindRequestAttribution(app core.App) {
	recordHandler := func(id string) *hook.Handler[*core.RecordRequestEvent] {
		return &hook.Handler[*core.RecordRequestEvent]{
			Id:       id,
			Priority: hookPriority,
			Func: func(e *core.RecordRequestEvent) error {
				return attribute(&e.App, ActorFromRequest(e.RequestEvent), e.Next)
			},
		}
	}
	app.OnRecordCreateRequest().Bind(recordHandler("obhijatraAuditAttributeRecordCreate"))
	app.OnRecordUpdateRequest().Bind(recordHandler("obhijatraAuditAttributeRecordUpdate"))
	app.OnRecordDeleteRequest().Bind(recordHandler("obhijatraAuditAttributeRecordDelete"))

	collectionHandler := func(id string) *hook.Handler[*core.CollectionRequestEvent] {
		return &hook.Handler[*core.CollectionRequestEvent]{
			Id:       id,
			Priority: hookPriority,
			Func: func(e *core.CollectionRequestEvent) error {
				return attribute(&e.App, ActorFromRequest(e.RequestEvent), e.Next)
			},
		}
	}
	app.OnCollectionCreateRequest().Bind(collectionHandler("obhijatraAuditAttributeCollectionCreate"))
	app.OnCollectionUpdateRequest().Bind(collectionHandler("obhijatraAuditAttributeCollectionUpdate"))
	app.OnCollectionDeleteRequest().Bind(collectionHandler("obhijatraAuditAttributeCollectionDelete"))

	app.OnCollectionsImportRequest().Bind(&hook.Handler[*core.CollectionsImportRequestEvent]{
		Id:       "obhijatraAuditAttributeCollectionsImport",
		Priority: hookPriority,
		Func: func(e *core.CollectionsImportRequestEvent) error {
			return attribute(&e.App, ActorFromRequest(e.RequestEvent), e.Next)
		},
	})

	app.OnSettingsUpdateRequest().Bind(&hook.Handler[*core.SettingsUpdateRequestEvent]{
		Id:       "obhijatraAuditAttributeSettingsUpdate",
		Priority: hookPriority,
		Func: func(e *core.SettingsUpdateRequestEvent) error {
			return attribute(&e.App, ActorFromRequest(e.RequestEvent), e.Next)
		},
	})
}

// attribute runs next in a transaction attributed to actor, pointing the
// event's App at the transactional app for the duration.
func attribute(appRef *core.App, actor Actor, next func() error) error {
	original := *appRef

	return RunAs(original, actor, func(txApp core.App) error {
		*appRef = txApp
		defer func() { *appRef = original }()

		return next()
	})
}
