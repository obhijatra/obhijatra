// Package cli holds obhijatra-server commands other than init.
package cli

import (
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"

	"github.com/obhijatra/obhijatra/server/internal/audit"
)

// NewAuditCommand returns `obhijatra-server audit`, with `verify`.
func NewAuditCommand(app core.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "audit",
		Short: "Work with the tamper-evident audit chain",
	}

	cmd.AddCommand(&cobra.Command{
		Use:   "verify",
		Short: "Re-check every link of the audit chain and report the first broken one",
		Long: "verify reads the audit chain from its first entry and checks that no entry is missing,\n" +
			"that each entry links to the one before it, and that no entry was changed after it was\n" +
			"written. It only reads; it is safe to run while the server is running.\n\n" +
			"Exit status 0 means the chain is intact; 1 means it is broken or could not be read.",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			out := cmd.OutOrStdout()

			result, err := audit.Verify(app)
			if err != nil {
				return err
			}

			if !result.OK {
				fmt.Fprintf(out, "The audit chain is BROKEN at entry %d (id %s): %s.\n", result.BrokenSeq, result.BrokenID, result.Problem)
				fmt.Fprintf(out, "The %d entries before it are intact; the last intact entry is %d with hash %s.\n",
					result.Entries, result.HeadSeq, result.HeadHash)
				fmt.Fprintln(out, "Entries from the broken one onward cannot be trusted. Treat this as a security incident.")
				return fmt.Errorf("audit chain broken at entry %d", result.BrokenSeq)
			}

			if result.Entries == 0 {
				fmt.Fprintln(out, "The audit chain is empty. Nothing has been recorded yet.")
				return nil
			}

			fmt.Fprintf(out, "The audit chain is intact: %d entries, no gaps, no changes.\n", result.Entries)
			fmt.Fprintf(out, "Last entry: %d, hash %s.\n", result.HeadSeq, result.HeadHash)
			fmt.Fprintln(out, "Compare this with the last head you recorded off the server: entries removed from the")
			fmt.Fprintln(out, "end of the chain can only be detected that way.")
			return nil
		},
	})

	return cmd
}
