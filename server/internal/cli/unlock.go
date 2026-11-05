package cli

import (
	"fmt"
	"net/mail"
	"strings"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/lockout"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// UnlockActor is who `obhijatra-server unlock` writes as in the audit chain.
var UnlockActor = audit.CLIActor("unlock")

// NewUnlockCommand returns `obhijatra-server unlock <email>`.
func NewUnlockCommand(app core.App) *cobra.Command {
	return &cobra.Command{
		Use:   "unlock <email or phone>",
		Short: "Lift the sign-in locks on an account and clear its wrong-password count",
		Long: "unlock lifts every sign-in lock on the account (or accounts) with this email address or\n" +
			"phone number (international form, for example +8801712345678),\n" +
			"from every internet address, and clears its count of wrong passwords, which also ends\n" +
			"the waiting of an organisation admin or superuser account. Use it when an organisation\n" +
			"admin is locked out and no other admin can unlock them.\n\n" +
			"It works on this computer's data folder (--dir), so only someone who can run the server\n" +
			"program here can use it. It is safe to run while the server is running. Every lock it\n" +
			"lifts and every count it clears is recorded in the audit chain as done by \"unlock\".\n\n" +
			"Exit status 0 means the account was found; 1 means no account has this address or number.",
		Args:         cobra.ExactArgs(1),
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			out := cmd.OutOrStdout()
			identity := strings.TrimSpace(args[0])
			if strings.HasPrefix(identity, "+") {
				if !schema.PhoneRegex.MatchString(identity) {
					return fmt.Errorf("%q is not a phone number in international form (for example +8801712345678)", args[0])
				}
			} else if addr, err := mail.ParseAddress(identity); err != nil || addr.Address != identity {
				return fmt.Errorf("%q is not an email address or a phone number in international form", args[0])
			}

			results, err := lockout.Unlock(app, UnlockActor, identity)
			if err != nil {
				return err
			}
			if len(results) == 0 {
				return fmt.Errorf("no account has %s; nothing was changed", identity)
			}

			for _, r := range results {
				kind := accountKind(r.Collection)
				if r.Locks == 0 && r.Failures == 0 {
					fmt.Fprintf(out, "The %s %s was not locked and had no wrong passwords. Nothing was changed.\n", kind, r.Identity())
					continue
				}
				fmt.Fprintf(out, "The %s %s is unlocked: %d lock%s lifted, %d recent wrong password%s cleared.\n",
					kind, r.Identity(), r.Locks, plural(r.Locks), r.Failures, plural(r.Failures))
				fmt.Fprintln(out, "  This is recorded in the audit chain.")
			}
			return nil
		},
	}
}

func accountKind(collection string) string {
	switch collection {
	case schema.FieldUsers:
		return "field user"
	case schema.StaffUsers:
		return "staff user"
	case schema.Superusers:
		return "superuser"
	}
	return collection + " account"
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
