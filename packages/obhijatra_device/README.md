# obhijatra_device

Device trust for Obhijatra, shared by the field app (through `obhijatra_core`) and the manager app (web and desktop). Pure Dart, no Flutter, safe to compile for the web.

It holds what the apps and the server must agree on byte for byte (`docs/decisions/0008-device-trust.md`):

- the 18-digit device check code (`deviceCheckCode`, `groupCheckCode`, `normaliseCheckCode`);
- the signed request message, the request headers and the reason codes;
- `SigningHttpClient`, which signs every request and never follows redirects;
- `SoftwareDeviceKeys`, Ed25519 and X25519 keys made from two 32-byte seeds, for platforms whose secure storage keeps the seeds (Android, iOS, Windows, macOS, Linux).

The tests check the published test vectors in ADR 0008.
