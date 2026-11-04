package setup

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"
	"golang.org/x/term"
)

// Environment variables init reads passwords from when the flags are not
// given, so they need not appear on the command line.
const (
	SuperuserPasswordEnv = "OBHIJATRA_INIT_SUPERUSER_PASSWORD"
	AdminPasswordEnv     = "OBHIJATRA_INIT_ADMIN_PASSWORD"
)

// NewInitCommand returns `obhijatra-server init`. envFile is called when the
// command runs, after the global flags have been parsed.
func NewInitCommand(app core.App, envFile func() string) *cobra.Command {
	var (
		o              Options
		superuserIPs   string
		proxyHeaders   string
		nonInteractive bool
	)

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Set up a new Obhijatra server with the security baseline switched on (run once, before serve)",
		Long: "init creates the data folder, writes the settings key to a private file, creates one superuser,\n" +
			"switches on the login rate limit and year-long logs, records the organisation settings and\n" +
			"creates the first organisation admin. It asks for anything not given as a flag.\n\n" +
			"Passwords can also be given in " + SuperuserPasswordEnv + " and " + AdminPasswordEnv + ",\n" +
			"which keeps them out of the command history.",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			out := cmd.OutOrStdout()
			o.EnvFile = envFile()
			o.SuperuserIPs = splitList(superuserIPs)
			o.TrustedProxyHeaders = splitList(proxyHeaders)

			if cmd.Flags().Changed("superuser-password") || cmd.Flags().Changed("admin-password") {
				fmt.Fprintln(out, "Note: passwords given as flags can be seen by other users of this computer and stay in the shell history.")
			}
			if o.SuperuserPassword == "" {
				o.SuperuserPassword = os.Getenv(SuperuserPasswordEnv)
			}
			if o.AdminPassword == "" {
				o.AdminPassword = os.Getenv(AdminPasswordEnv)
			}

			interactive := !nonInteractive && term.IsTerminal(int(os.Stdin.Fd()))
			if interactive {
				if err := ask(out, &o); err != nil {
					return err
				}
			}

			report, err := Run(app, o)
			if err != nil {
				return err
			}
			report.Color = isColorTerminal(out)
			report.WritePosture(out)
			return nil
		},
	}

	f := cmd.Flags()
	f.StringVar(&o.OrgName, "org-name", "", "organisation name")
	f.StringVar(&o.Country, "country", "", "two-letter ISO code of the hosting country, e.g. BD")
	f.StringVar(&o.AppURL, "url", "", "address people will use to reach this server, e.g. https://data.example.org")
	f.StringVar(&o.SuperuserEmail, "superuser-email", "", "email of the single superuser (installation and recovery only)")
	f.StringVar(&o.SuperuserPassword, "superuser-password", "", "superuser password, at least 12 characters (prefer "+SuperuserPasswordEnv+")")
	f.StringVar(&o.AdminName, "admin-name", "", "name of the first organisation admin")
	f.StringVar(&o.AdminEmail, "admin-email", "", "email of the first organisation admin")
	f.StringVar(&o.AdminPassword, "admin-password", "", "organisation admin password, at least 12 characters (prefer "+AdminPasswordEnv+")")
	f.StringVar(&superuserIPs, "superuser-ips", "", "optional comma-separated IP addresses or ranges allowed to use superuser accounts")
	f.StringVar(&proxyHeaders, "trusted-proxy-header", "",
		"only behind a reverse proxy (Caddy, NGINX...): the header it puts each user's IP address in, e.g. X-Forwarded-For")
	f.BoolVar(&o.TrustedProxyUseLeftmost, "trusted-proxy-use-left", false,
		"use the left-most address in that header (only if your proxy replaces the header the client sent)")
	f.BoolVar(&nonInteractive, "non-interactive", false, "never ask questions; fail if anything is missing")

	return cmd
}

// ask fills in every missing answer from the terminal.
func ask(out io.Writer, o *Options) error {
	in := bufio.NewReader(os.Stdin)

	fmt.Fprintln(out, "Setting up a new Obhijatra server. Press Enter to accept a value in [brackets].")

	text := func(label string, dst *string, def string) error {
		if *dst != "" {
			return nil
		}
		if def != "" {
			fmt.Fprintf(out, "%s [%s]: ", label, def)
		} else {
			fmt.Fprintf(out, "%s: ", label)
		}
		line, err := in.ReadString('\n')
		if err != nil && !errors.Is(err, io.EOF) {
			return err
		}
		*dst = strings.TrimSpace(line)
		if *dst == "" {
			*dst = def
		}
		return nil
	}
	secret := func(label string, dst *string) error {
		if *dst != "" {
			return nil
		}
		for {
			fmt.Fprintf(out, "%s (at least %d characters, not shown): ", label, MinPasswordLength)
			first, err := term.ReadPassword(int(os.Stdin.Fd()))
			fmt.Fprintln(out)
			if err != nil {
				return err
			}
			fmt.Fprintf(out, "Type it again: ")
			second, err := term.ReadPassword(int(os.Stdin.Fd()))
			fmt.Fprintln(out)
			if err != nil {
				return err
			}
			if string(first) != string(second) {
				fmt.Fprintln(out, "The two entries were different. Please try again.")
				continue
			}
			*dst = string(first)
			return nil
		}
	}

	steps := []func() error{
		func() error { return text("Organisation name", &o.OrgName, "") },
		func() error { return text("Hosting country (two-letter code)", &o.Country, "BD") },
		func() error { return text("Server address", &o.AppURL, DefaultAppURL) },
		func() error { return text("Superuser email (installation and recovery only)", &o.SuperuserEmail, "") },
		func() error { return secret("Superuser password", &o.SuperuserPassword) },
		func() error { return text("First organisation admin's name", &o.AdminName, "") },
		func() error { return text("First organisation admin's email", &o.AdminEmail, "") },
		func() error { return secret("Organisation admin password", &o.AdminPassword) },
	}
	for _, step := range steps {
		if err := step(); err != nil {
			return err
		}
	}
	return nil
}

// isColorTerminal reports whether w is a terminal that should show colour
// (not when NO_COLOR is set).
func isColorTerminal(w io.Writer) bool {
	f, ok := w.(*os.File)
	return ok && os.Getenv("NO_COLOR") == "" && term.IsTerminal(int(f.Fd()))
}

func splitList(s string) []string {
	var out []string
	for _, part := range strings.Split(s, ",") {
		if p := strings.TrimSpace(part); p != "" {
			out = append(out, p)
		}
	}
	return out
}
