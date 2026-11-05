# 6. People screens and one-time passwords

Date: 6 November 2026

Status: Accepted

## Context

After Google and SMS-code sign-in (decision 5), organisation admins could add phone numbers and confirm email addresses only in the server's technical dashboard, which non-technical admins cannot be expected to use. The owner chose (6 November 2026) to build People screens in the manager app next, and to give new email-and-password users a one-time password that they must change at first sign-in, because most organisations will not have email (SMTP) set up on their server.

## Decision

- **People screens** in the manager app, for active org admins only: add people, edit their role, place, email address, email confirmation, mobile number and status, unlock sign-in, and give a new one-time password. Nobody is deleted; people are deactivated.
- **One-time passwords** are made in the manager app from a secure random source (12 characters from an unambiguous 30-character alphabet, about 59 bits), shown once, and cleared from the clipboard when the reveal closes. The account gets `must_change_password`, which nobody can set on themselves, and which needs an email address.
- **A server gate** answers a person with a one-time password only what choosing a new password needs (their own record, their own password change, sign-in, and the public version and sign-in-method checks), never with related records expanded. Every other request gets 403 with the reason code `password_change_required`, which both apps turn into a "Choose your own password" step.
- **Choosing your own password** needs the current password (org admins included, although PocketBase would let them skip it), must differ from the one-time password, clears the flag and ends every old session. The field app's lock rules are unchanged: an SMS code or Google still needs the PIN or screen lock.
- **Integrity:** a change that would leave no active org admin is refused, for updates and deletes, superusers included. A write based on a copy someone else changed since it was loaded is refused (HTTP 409), so a request already under way cannot undo an admin's reset, demotion or deactivation; an admin's own authority is read again inside the write. Setting the flag alone also ends sessions.

## Consequences

- Organisations can run day to day without the server dashboard.
- An admin passes each one-time password on by hand. If the organisation later sets up email, an emailed invitation can be added.
- An independent security review on 6 November 2026 found and had fixed: reading related records through the gate with `expand`, stale writes undoing resets and demotions, admins changing their own password without the current one, deleting the last org admin, the one-time password left on the clipboard, admins giving themselves a one-time password, keeping the one-time password as the new one, and the flag alone not ending sessions.
- Places (the organisation tree) still cannot be added in the manager app; that is the next gap.
