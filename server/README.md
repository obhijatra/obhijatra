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

If a reverse proxy (Caddy, NGINX) will sit in front of the server, add `--trusted-proxy-header X-Forwarded-For` (see "Run it with HTTPS", option B).

At the end, `init` prints a security summary. Read any line marked `[WARNING]` (red on screen): for example, a web address that does not start with `https://`. A plain `http://` address on this computer or a private network is marked `[TESTING ONLY]`.

## Run it

1. In the same folder, type `./obhijatra-server serve` and press Enter.
2. By default it listens on `127.0.0.1:8090`. Use `--http` to change the address, for example `serve --http 0.0.0.0:8090`.
3. The server refuses to start if `init` has not been run.

## Run it with HTTPS

HTTPS encrypts everything between the apps and the server, including passwords. Use it for every real organisation. Plain `http://` is only for testing on one computer or a private network. Choose **one** of these two options.

### Option A: the server gets its own certificate (simplest)

The server asks Let's Encrypt (a free certificate service) for a certificate and renews it by itself.

1. Get a web address (domain name) for the server, for example `data.example.org`.
2. In your domain's settings (DNS, the internet's address book), point that name at the public IP address of the server computer.
3. Make sure ports 80 and 443 of the server computer can be reached from the internet (ask whoever manages the firewall or router).
4. On Linux, allow the program to use ports 80 and 443 without being the administrator: type `sudo setcap 'cap_net_bind_service=+ep' ./obhijatra-server_0.1.0-dev_linux_amd64` and press Enter. (Windows does not need this step.)
5. Type `./obhijatra-server serve data.example.org` and press Enter. The server listens on ports 80 and 443 and sends every `http://` visit to `https://`.
6. In a web browser, open `https://data.example.org/api/health`. A padlock next to the address means HTTPS works. The certificate is kept in `pb_data/.autocert_cache`.
7. If you gave `init` a different web address, open the Dashboard at `https://data.example.org/_/`, sign in as the superuser, go to **Settings**, set **Application URL** to `https://data.example.org` and save.

### Option B: behind Caddy or NGINX (a reverse proxy)

A reverse proxy is a separate program that receives the visits, handles HTTPS and passes them to the server.

1. Start the server so that only programs on the same computer can reach it: `./obhijatra-server serve --http 127.0.0.1:8090`.
2. Install Caddy (caddyserver.com). Steps 1 to 3 of option A apply to Caddy too: the web address, DNS and ports 80 and 443.
3. Write this in Caddy's settings file (the `Caddyfile`), with your own web address, and start Caddy. Caddy gets and renews the certificate by itself.

   ```
   data.example.org {
       request_body {
           max_size 130MiB
       }
       reverse_proxy 127.0.0.1:8090
   }
   ```

   NGINX works too, with a certificate you obtain yourself (for example with certbot). Inside its `location / { ... }` block, use `proxy_pass http://127.0.0.1:8090;`, `proxy_set_header Host $host;`, `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` and `proxy_set_header X-Forwarded-Proto $scheme;`, and set `client_max_body_size 130M;`.
4. Tell the server which header carries each user's real IP address. When setting up, add `--trusted-proxy-header X-Forwarded-For` to `init`. On a server that is already set up: open the Dashboard (`https://data.example.org/_/`), go to **Settings**, then **Application**, open **IP proxy headers**, type `X-Forwarded-For` and save. Without this, everyone seems to come from the proxy's address: they share one sign-in allowance, and one person's wrong passwords can lock a whole office out.
5. Do not use `--trusted-proxy-use-left` with these settings. The server then takes the right-most address in the header, the one your proxy added, which a visitor cannot fake.
6. Open `https://data.example.org/api/health` in a web browser and check for the padlock, as in option A.

## Check the audit log

`./obhijatra-server audit verify` re-checks the tamper-evident audit chain. Exit status 0 means intact.

## If someone cannot sign in

- 10 wrong passwords within 15 minutes from one internet address (IP address) lock that account **for that address** for 15 minutes. The same person can still sign in from another address.
- 30 wrong passwords within 15 minutes from all addresses together lock an ordinary account everywhere for 15 minutes. Organisation admins and superusers are never locked everywhere: their sign-ins slow down instead, up to 30 seconds per attempt.
- A deactivated account gets the same "Sign-in failed" message as a wrong password.
- Waiting 15 minutes is enough. An organisation admin can unlock the account sooner.
- Up to 30 people can sign in each minute from one internet connection. If more try at once, the app says the server is busy and tries again a minute later.
- If the server runs behind a reverse proxy, set the trusted proxy header ("Run it with HTTPS", option B, step 4), or everyone shares one allowance.

### If an organisation admin is locked out

When no other organisation admin can unlock them, someone with access to the server computer can:

1. Open a terminal in the folder where the program and `pb_data` are.
2. Type `./obhijatra-server unlock admin@example.org` (with the admin's email address) and press Enter. The server may keep running.
3. Read the answer: it says how many locks were lifted and how many wrong passwords were cleared. This is recorded in the audit chain.
4. The admin can now sign in.

Details: `docs/decisions/0002-obhijatra-server.md`, "Sign-in protection".

## Tests

`go test ./... && go vet ./...`

CI also checks for known vulnerabilities with govulncheck (Go code) and OSV-Scanner (`pubspec.lock` and `go.mod`). Accepted exceptions, each with a reason and an end date, are in `osv-scanner.toml`.

See `docs/decisions/0002-obhijatra-server.md` for how it works.
