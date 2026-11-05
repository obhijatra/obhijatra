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

Public keys are sent as 32 bytes in standard base64 with padding, written the one canonical way.

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
- A **pending** or **expired** device may only read its own status (`GET /api/obhijatra/v1/devices/me`). It may also do what changing a one-time password needs.
- A **revoked** device is refused.

Every refusal gives a reason code in `data.reason.code`, so the apps can show the right screen:

- `device_signature_required`
- `device_signature_invalid`
- `device_clock`
- `device_not_approved`
- `device_revoked`
- `device_expired`
- `session_revoked`
- `session_other_device`

Requests without a signed-in person need no device: sign-in, the public `meta` and sign-in-method checks.

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
- The replay memory is kept in the server's memory. Signatures made before a restart are refused after it, so a restart costs at most one retry.
- A person promoted to org admin keeps the devices approved before the promotion. The promotion itself needs an org admin.

**Deferred**, as the blueprint plans:

- the organisation key and organisation-signed device records;
- hardware attestation (Play Integrity or App Attest);
- certificate pinning;
- end-to-end encryption with the X25519 keys.
