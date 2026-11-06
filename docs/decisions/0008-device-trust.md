# 8. Device trust: every device approved, every request signed

Date: 6 November 2026

Status: Accepted

## Context

The blueprint (v3) asks for zero trust: a password alone must not be enough to reach the organisation's data. Every phone, computer and browser that uses Obhijatra is enrolled with its own keys and approved by a person, and the server checks every request against that approval.

The owner chose (6 November 2026):

- **Devices and sessions now.** The organisation-key ceremony (an offline organisation key that signs device records) comes later.
- **Every device must be approved**, web browsers included.
- **Who approves:** branch managers approve the field staff phones in their own part of the tree. Org admins approve any device. An org admin's device needs two different org admins.
- **The check code is 18 digits in 6 groups of 3**, typed in Bangla or English digits, instead of the blueprint's six words. Digits are the same in both languages, easy to read aloud over a phone call, and need no word list in two languages.

## Decision

### Keys

Each device makes two key pairs and keeps the private keys in the platform's secure storage. The keys never leave the device.

- **Ed25519 signing key.** Signs requests ([RFC 8032](https://www.rfc-editor.org/rfc/rfc8032)).
- **X25519 encryption key.** Registered now, for the end-to-end encryption planned in the blueprint.

Public keys are sent as 32 bytes in standard base64 with padding, written the one canonical way. The server refuses keys that are not real keys:

- an Ed25519 key that is not a valid curve point, or has "small order";
- an X25519 key of low order.

A small-order signing key would accept one fixed signature for every message. Whoever enrolled it would then need no private key at all.

### Enrolment

1. The person signs in as usual (password, SMS code or Google).
2. The app sends `POST /api/obhijatra/v1/devices/enrol` with `label`, `platform` (`android`, `ios`, `windows`, `macos`, `linux` or `web`), `sign_public_key` and `enc_public_key`. The request is signed with the new signing key, with the device header set to `enrol`. This proves the device holds the key.
3. The server records the device as **pending** and ties the session to it.

Details:

- A session already used by another device, or ended, cannot enrol.
- Enrolling the same keys again returns the same device.
- A person may have at most 3 devices waiting.
- A person who must change a one-time password may enrol and read the device's status. They then change the password from the waiting device.

### The check code

The device shows an 18-digit code worked out from its two public keys:

```
digest = SHA-256("obhijatra-device-code-v1" || 0x00 || signKey || encKey)
code   = big-endian uint64(digest[0..8]) mod 10^18, written as 18 digits with leading zeros
shown  = six groups of three digits, for example "225 142 753 699 752 889"
```

How the code is used:

- The approver reads the code on the person's device, in person or on a phone call with someone they know. They then type it into the manager app.
- The approver's app works out the same code from the keys the server holds. The server checks the code again.
- If anyone swapped the keys on the way, the two codes differ.
- The code is not secret. It only proves that the device in front of the approver is the one on the server.
- Spaces, dashes and Bangla digits (০–৯) are accepted when typing.

### Approval

`POST /api/obhijatra/v1/devices/{id}/approve` with `{"code": "…"}`. Who may approve:

- **An org admin** may approve any device.
- **A branch manager** may approve the devices of field staff whose place is in their part of the tree.
- **Nobody approves their own device.**
- **An org admin's device** needs two different org admins. The first approval leaves it pending with `needs_second_approval: true`.
- **The server's command line**, `obhijatra-server device approve <id> "<code>"`, counts as a full approval. Whoever can run the server program already holds all the data. This is how the first org admin's first device is approved.
- **A first approval counts only while its approver is still an active org admin.** If that admin has left or been demoted, the next approval counts as the first.
- **Promotion to org admin** puts the person's approved devices back to waiting for two org admins. Otherwise one admin could approve a supervisor's phone alone and then promote the supervisor.

An approval lasts 365 days. After that, the device can only read its own status until someone approves it again with the same code.

Devices are changed only through these routes and commands:

- The records API cannot create or change devices, for anyone but a superuser.
- Not even a superuser can set the fields that decide trust: owner, keys, status, expiry and approvers.

Every approval is an entry in the audit chain.

### Signed requests

Every request by a signed-in field or staff user carries four headers:

| Header | Value |
|---|---|
| `X-Obhijatra-Device` | the device id (`enrol` when enrolling) |
| `X-Obhijatra-Time` | Unix time in seconds |
| `X-Obhijatra-Nonce` | 16 random bytes, base64url without padding (22 characters) |
| `X-Obhijatra-Signature` | Ed25519 signature of the message below, base64url without padding |

The signed message is:

```
"OBHIJATRA-REQUEST-V1\n" + METHOD + "\n" + target + "\n" + time + "\n" + nonce + "\n" + hex(SHA-256(body))
```

- `METHOD` is upper case.
- `target` is the path and query exactly as sent, for example `/api/collections/forms/records?page=1`.
- `body` is the exact bytes sent. An empty body still has a hash. A multipart upload must be put together in full before it is signed.

The server refuses a request when:

- its time is more than 5 minutes from the server's clock;
- its time is from before the server last started;
- its nonce was already used by that device within the window;
- its signature does not match;
- its device is not the person's own.

The server then checks the device:

- An **active** device within its approval works normally.
- A **pending** or **expired** device may only:
  - read its own status (`GET /api/obhijatra/v1/devices/me`);
  - refresh its session;
  - for a person who must replace a one-time password, and nobody else, do what choosing the new password needs.

  It cannot read or change the account. Otherwise a thief with a password could change it from their own waiting phone.
- A **revoked** device is refused.

A refused request never takes a session for its device.

**File downloads.** A download with a person's file token (`/api/files/…?token=`) must also be signed by an approved device of that person. A download link that leaks, for example from a log, is then of no use to anyone.

**Live updates.** The server checks the device and session again before each live update (realtime). After a device is switched off, its approval runs out or its session ends, updates stop at once and the connection carries on signed out.

Every refusal gives a reason code in `data.reason.code`, so the apps can show the right screen:

- `device_signature_required`
- `device_signature_invalid`
- `device_unknown`: the device id is not one of the person's devices, for example after the server was restored from an older backup. The app enrols again with the same keys, and the device needs approval again.
- `device_clock`
- `device_not_approved`
- `device_revoked`
- `device_expired`
- `session_revoked`
- `session_other_device`

Requests without a signed-in person need no device: sign-in, the public `meta` and sign-in-method checks.

The signature does not cover other headers, such as the session token or the content type. TLS protects them on the way. A signature still cannot be used twice, nor moved to another request.

**Superusers** are not device-checked. These are the installation and recovery accounts that `obhijatra-server init` makes. They are used rarely, for the server's own maintenance, and every write they make is in the audit chain.

### Sessions

Every sign-in and token refresh writes a session row:

- The row holds the SHA-256 of a token that is unique to it.
- The row belongs to one device: the device that signed the sign-in, or the first device that uses it.
- A session used from any other device is refused.

Sessions end in these cases:

- An org admin ends a session.
- A device is switched off. All its sessions end with it.
- An admin changes the person's email, phone, confirmation, role or status. As before, this ends all their sessions.

### Switching a device off

`POST /api/obhijatra/v1/devices/{id}/revoke`, or `obhijatra-server device revoke <id>`. Who may do it:

- the owner, for a lost phone;
- an org admin;
- a branch manager, for field staff in their part of the tree.

A switched-off device stays off. To use it again, the person enrols it as a new device.

### Test vectors

The server and both apps check these values in their tests.

| Input | Expected |
|---|---|
| Code for signing key bytes `00 01 … 1f` and encryption key bytes `20 21 … 3f` | `225142753699752889` (`225 142 753 699 752 889`) |
| Signature with the all-zero 32-byte Ed25519 seed over `Message("post", "/api/x?a=1", "1793836800", "AAAAAAAAAAAAAAAAAAAAAA", "{}")` | `jd5i3Nw3804mIJ7v6JiJZiZL0-fApy9xIFWavKqJpDe7ZsVhMVdXvkYfyBnm2GlRzO-fV95bdXGvCeL1YG9PAg` |

## Consequences

- A stolen password, SMS code or session token is not enough on its own. The thief also needs a device that an approver has seen and checked.
- A session copied to another device stops working.
- Losing a phone is handled by switching it off. Its sessions end at once.
- Every organisation runs a one-time bootstrap: the first org admin approves their own first device from the server's command line (`docs/setup/devices.md`). After that, approvals happen in the manager app.
- Org admins are never locked out entirely, because the server's command line can always approve or switch off a device.
- Each device's clock must be within 5 minutes of the server's. The app shows a clear message when it is not.
- The replay memory is kept in the server's memory, in three time buckets. Dropping old nonces costs nothing, however busy the server is.
- After a restart, the server starts answering only once the second it started in has passed. Signatures made in that second or before are refused, so a restart costs at most one retry.
- A request body is hashed as it streams in. PocketBase keeps it on disk beyond 16 MB, so a large body is never held in memory before its signature is checked.
- A person promoted to org admin keeps the devices approved before the promotion. The promotion itself needs an org admin.

An independent security review on 6 November 2026 found the issues below. All were fixed, with tests, before the apps were built:

- a waiting device could change the account's password;
- live updates continued after a device was switched off;
- small-order keys were accepted;
- the replay memory slowed down under load;
- the two-admin rule could be bypassed by promotion;
- a first approval by a former admin still counted;
- file links worked without a device;
- a refused request could take a session;
- one second of slack was allowed after a restart;
- "bearer" in lower case was not recognised;
- line separators, invisible characters and bidirectional marks were allowed in device and place names.

A second independent review on 6 November 2026 covered the apps. It found no serious issues. The issues it did find were fixed with tests before release:

- the manager app could stay open after its device and session were lost;
- the manager's waiting screen kept checking after the session had ended;
- an old device check could act for the next person to sign in;
- the first admin's server command carried the code, inviting it to be sent by message;
- a switched-off phone still offered to fill in forms;
- on a shared phone, each new person destroyed the previous person's approval (keys are now kept per person);
- the field app did not retry once after a server restart.

**Known limits** (`docs/setup/devices.md` tells organisations what to do):

- **Windows:** the manager app keeps its key seeds in a file encrypted for the Windows user (DPAPI). The plugin keeps that file in the roaming profile, so on networks with roaming profiles the keys can follow the person to other computers. Fixing this needs our own small Windows key store in the local profile, or hardware-bound keys.
- **macOS:** the keys are in the login keychain, which the Mac's migration tools copy to a new Mac. Keys bound to one Mac need the data-protection keychain with "this device only" access, which needs a signed build with the Keychain Sharing entitlement.
- **Fewer than three org admins:** an org admin's device cannot get two approvals in the app. The server command line approves it instead.

**Deferred**, as the blueprint plans:

- the organisation key and organisation-signed device records;
- hardware attestation (Play Integrity or App Attest) and hardware-bound keys on desktops;
- certificate pinning;
- end-to-end encryption with the X25519 keys.
