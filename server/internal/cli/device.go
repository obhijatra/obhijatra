package cli

import (
	"errors"
	"fmt"
	"strings"
	"text/tabwriter"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Who `obhijatra-server device …` writes as in the audit chain.
var (
	DeviceApproveActor = audit.CLIActor("device approve")
	DeviceRevokeActor  = audit.CLIActor("device revoke")
)

// NewDeviceCommand returns `obhijatra-server device list|approve|revoke`.
func NewDeviceCommand(app core.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "device",
		Short: "List, approve or switch off the phones and computers people use",
		Long: "Every phone, tablet, computer and web browser must be approved before it can see or\n" +
			"send any data. Organisation admins and branch managers approve devices in the manager\n" +
			"app. Use these commands on the server for the first organisation admin's first device,\n" +
			"or when no admin can approve one.\n\n" +
			"They work on this computer's data folder (--dir), so only someone who can run the server\n" +
			"program here can use them. They are safe to run while the server is running, and every\n" +
			"change is recorded in the audit chain.",
	}
	cmd.AddCommand(deviceList(app), deviceApprove(app), deviceRevoke(app))
	return cmd
}

func deviceList(app core.App) *cobra.Command {
	var all bool
	c := &cobra.Command{
		Use:          "list",
		Short:        "List devices waiting for approval (--all: every device)",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			filter := "status = '" + schema.DevicePending + "'"
			if all {
				filter = ""
			}
			devices, err := app.FindRecordsByFilter(schema.Devices, filter, "-created", 0, 0)
			if err != nil {
				return err
			}
			out := cmd.OutOrStdout()
			if len(devices) == 0 {
				if all {
					fmt.Fprintln(out, "No devices yet.")
				} else {
					fmt.Fprintln(out, "No devices are waiting for approval.")
				}
				return nil
			}
			w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
			fmt.Fprintln(w, "ID\tSTATUS\tPERSON\tDEVICE\tENROLLED\tAPPROVED UNTIL")
			for _, d := range devices {
				until := "-"
				if d.GetString("status") == schema.DeviceActive {
					until = d.GetDateTime("expires").Time().UTC().Format("2 Jan 2006")
				}
				fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\n", d.Id, d.GetString("status"), ownerName(app, d),
					oneLine(d.GetString("label"))+" ("+d.GetString("platform")+")",
					d.GetDateTime("created").Time().UTC().Format("2 Jan 2006 15:04 UTC"), until)
			}
			if err := w.Flush(); err != nil {
				return err
			}
			fmt.Fprintln(out, "\nTo approve one, ask its owner for the 18 numbers on its screen and run:")
			fmt.Fprintln(out, "  obhijatra-server device approve <ID> \"<the 18 numbers>\"")
			return nil
		},
	}
	c.Flags().BoolVar(&all, "all", false, "list every device, not only those waiting")
	return c
}

func deviceApprove(app core.App) *cobra.Command {
	return &cobra.Command{
		Use:   "approve <id> <the 18 numbers>",
		Short: "Approve a device after checking the numbers on its screen",
		Long: "approve checks the 18 numbers the device shows (spaces and Bangla digits are fine; put\n" +
			"them in quotes) and approves it for a year. Read the numbers from the device itself, in\n" +
			"person or by a phone call to someone you know, never from a message: they are what\n" +
			"proves the device in front of the person is the one on the server.\n\n" +
			"This one approval is enough, even for an organisation admin's device.",
		Args:         cobra.ExactArgs(2),
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			d, err := api.ActivateFromCommandLine(app, DeviceApproveActor, strings.TrimSpace(args[0]), args[1])
			if err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Approved %s of %s until %s. This is recorded in the audit chain.\n",
				oneLine(d.GetString("label")), ownerName(app, d), d.GetDateTime("expires").Time().UTC().Format("2 January 2006"))
			return nil
		},
	}
}

func deviceRevoke(app core.App) *cobra.Command {
	return &cobra.Command{
		Use:          "revoke <id>",
		Short:        "Switch a device off at once and end its sessions",
		Long:         "revoke switches the device off for good: it can no longer see or send data, and it is\nsigned out. To use it again, its owner enrols it again and someone approves it.",
		Args:         cobra.ExactArgs(1),
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			var d *core.Record
			err := audit.RunAs(app, DeviceRevokeActor, func(txApp core.App) error {
				var err error
				d, err = txApp.FindRecordById(schema.Devices, strings.TrimSpace(args[0]))
				if err != nil {
					return errors.New("no device has this id")
				}
				return api.RevokeDevice(txApp, d)
			})
			if err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Switched off %s of %s and ended its sessions. This is recorded in the audit chain.\n",
				oneLine(d.GetString("label")), ownerName(app, d))
			return nil
		},
	}
}

// ownerName is how the command line names a device's owner: email address
// or phone number, and the kind of account.
func ownerName(app core.App, d *core.Record) string {
	collection, id := schema.FieldUsers, d.GetString("field_user")
	if id == "" {
		collection, id = schema.StaffUsers, d.GetString("staff_user")
	}
	r, err := app.FindRecordById(collection, id)
	if err != nil {
		return "an unknown person"
	}
	who := r.Email()
	if who == "" {
		who = r.GetString("phone")
	}
	kind := accountKind(collection)
	if collection == schema.StaffUsers && r.GetString("role") == schema.RoleOrgAdmin {
		kind = "organisation admin"
	}
	return oneLine(who) + " (" + kind + ")"
}

// oneLine keeps a stored label from moving the terminal's cursor or
// pretending to be another line: control and invisible characters go.
func oneLine(s string) string {
	return strings.Map(func(r rune) rune {
		if r < 0x20 || r == 0x7f || schema.UnsafeTextRune(r) {
			return -1
		}
		return r
	}, s)
}
