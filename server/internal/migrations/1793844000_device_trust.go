package migrations

import (
	"errors"
	"fmt"
	"slices"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion8 is the schema version this migration produces.
const SchemaVersion8 = 8

func init() {
	m.Register(deviceTrustUp, deviceTrustDown)
}

// deviceTrustUp (6 November 2026) turns on device trust
// (docs/decisions/0008-device-trust.md): devices enrol as "pending" with
// their public keys and platform, and are approved by one approver, or by
// two org admins for an org admin's device; branch managers see the
// devices of field staff in their part of the tree; one public signing
// key belongs to one device.
//
// Every step can run again without harm.
func deviceTrustUp(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Devices)
	if err != nil {
		return err
	}
	status, ok := c.Fields.GetByName("status").(*core.SelectField)
	if !ok {
		return errors.New("schema version 8: the devices status field is missing")
	}
	if !slices.Contains(status.Values, schema.DevicePending) {
		status.Values = append(status.Values, schema.DevicePending)
	}
	if c.Fields.GetByName("platform") == nil {
		c.Fields.Add(&core.SelectField{Name: "platform", MaxSelect: 1, Values: schema.DevicePlatforms})
	}
	if c.Fields.GetByName("approved_at") == nil {
		c.Fields.Add(&core.DateField{Name: "approved_at"})
	}
	if c.Fields.GetByName("first_approved_by") == nil {
		first, err := relationTo(app, schema.StaffUsers, "first_approved_by", false)
		if err != nil {
			return err
		}
		first.Help = "The first of the two org admins who approve an org admin's device"
		c.Fields.Add(first)
	}
	c.ListRule = types.Pointer(schema.DevicesRead)
	c.ViewRule = types.Pointer(schema.DevicesRead)
	// Devices are enrolled, approved and switched off only through the
	// device routes, which check who may do what; the records API cannot
	// write them at all.
	c.CreateRule = nil
	c.UpdateRule = nil
	c.AddIndex("idx_devices_sign_public_key", true, "`sign_public_key`", "`sign_public_key` != ''")
	if err := app.Save(c); err != nil {
		return fmt.Errorf("schema version 8, %s: %w", schema.Devices, err)
	}
	if err := raiseSchemaVersion(app, SchemaVersion8); err != nil {
		return fmt.Errorf("schema version 8, schema version: %w", err)
	}
	return nil
}

func deviceTrustDown(app core.App) error {
	return errors.New("schema version 8 cannot be rolled back; restore a backup instead")
}
