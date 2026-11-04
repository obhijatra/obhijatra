# obhijatra-server

The Obhijatra server: PocketBase (included in `vendor/`) plus Obhijatra's own rules. It is one program and one data folder (`pb_data`). Status: pre-alpha.

## Get the program

Build it yourself (needs Go; no internet needed afterwards):

1. Open a terminal in this `server` folder.
2. Type `sh scripts/build-all.sh` and press Enter.
3. The programs appear in `dist/`, one per platform (Linux, Windows, macOS on Apple chips), with a `SHA256SUMS` file to check them.

## Set it up (once)

1. Open a terminal in the folder where the program is, e.g. `./obhijatra-server_0.1.0-dev_linux_amd64`.
2. Type `./obhijatra-server init` and press Enter (on Windows, run the `.exe`).
3. Answer the questions: organisation name, hosting country, web address, the one superuser's email and password, and the first organisation admin's name, email and password. Passwords need at least 12 characters.
4. `init` creates the `pb_data` folder and a private settings-key file next to it. **Back this file up somewhere safe and keep it secret.** Without it the server cannot start.

To skip the questions, use `--non-interactive` with the flags shown by `init --help`. Prefer the environment variables it names for passwords.

## Run it

1. In the same folder, type `./obhijatra-server serve` and press Enter.
2. By default it listens on `127.0.0.1:8090`. Use `--http` to change the address, for example `serve --http 0.0.0.0:8090`.
3. The server refuses to start if `init` has not been run.

## Check the audit log

`./obhijatra-server audit verify` re-checks the tamper-evident audit chain. Exit status 0 means intact.

## If someone cannot sign in

- 10 wrong passwords within 15 minutes lock that account for 15 minutes. Waiting 15 minutes is enough; an organisation admin can also unlock it sooner.
- Up to 30 people can sign in each minute from one internet connection. If more try at once, the app says the server is busy and tries again a minute later.
- If the server runs behind a reverse proxy, set PocketBase's trusted-proxy setting, or everyone shares one allowance.

Details: `docs/decisions/0002-obhijatra-server.md`, "Sign-in protection".

## Tests

`go test ./... && go vet ./...`

See `docs/decisions/0002-obhijatra-server.md` for how it works.
