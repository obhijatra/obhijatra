# Setting up Google sign-in and SMS-code sign-in

Last checked: 5 November 2026. For: the organisation admin. Time needed: about 20 minutes for Google, 15 minutes for SMS.

Everyone can always sign in with an email address and password. You can add two more ways, each switched on separately in the manager app under **Settings → Sign-in methods**:

- **Google**: people tap "Continue with Google" and choose their Google account. It works only for people you have already added with that same email address.
- **SMS code**: people type their mobile number and receive a 6-digit code by SMS. Your organisation pays your SMS provider for each message. Organisation admins cannot use SMS codes, because a stolen or swapped SIM card would then give someone control of every account.

Nothing is sent to Aninda Studio. Google learns only that the person signed in; your SMS provider learns the phone number and the code.

## Words used in this guide

- **Google Cloud project**: a free workspace in Google's console where you register your organisation as a "client" that may use Google sign-in.
- **Client ID and client secret**: two pieces of text Google gives you. The ID is like a username for your server; the secret is like its password. Keep the secret private.
- **Redirect address**: the page on your server Google sends people back to after they sign in. The manager app shows it to you, ready to copy.
- **SMS provider**: the company that sends text messages for you. Most have a web interface (an "API") described in a guide for developers.

## Before you start

Until the manager app has screens for people's accounts (a later release), you change accounts in the server's admin dashboard (`https://your-server/_/`, signed in as the superuser): open **field_users** or **staff_users**, then the person's record.

- Your server needs a web address that starts with `https://` and has a real domain name, for example `https://obhijatra.example.org`. Google refuses plain `http://` addresses and bare numbers such as `203.0.113.5` ([Google's rules for redirect addresses](https://support.google.com/cloud/answer/15549257)). SMS codes work without this.
- Every person who will sign in with Google needs an account in Obhijatra with the **same email address** as their Google account, and that email address must be marked as confirmed (**Verified**). The address must be a **Gmail** address or an address in your organisation's **Google Workspace**. A Google account made with some other email address (for example a work address on another mail service) is refused, because Google cannot vouch that the address still belongs to the person.
- Every person who will sign in by SMS needs their mobile number on their account, in international form: `+880` then the number without its first `0`. For example, `01712345678` becomes `+8801712345678`.

## Part 1: Google sign-in

**1. Open the Google Auth Platform.** Go to `https://console.cloud.google.com/auth/clients` and sign in with the Google account your organisation will use to manage this. If asked, create a project: name it, for example, `Obhijatra sign-in`, and click **Create**.

**2. Register your organisation.** The first time, Google asks you to describe the app people will see when they sign in. Enter your organisation's name as the app name and your support email address. For **Audience**:
- choose **Internal** if all your staff use your organisation's own Google Workspace accounts;
- otherwise choose **External**. Then open **Audience** again and click **Publish app**, so that people other than test users can sign in.

Obhijatra asks Google only for the person's name and email address, which Google treats as basic information.
*UNVERIFIED – check before use: the exact screen and button names in this step, and whether Google asks for a review of an External app that requests only name and email.*

**3. Create the client.** On the **Clients** page click **Create client**. For **Application type** choose **Web application**. Give it a name, for example `Obhijatra server`.

**4. Add the redirect address.** In the manager app, open **Settings → Sign-in methods** and copy the address under **Redirect address for Google**. It ends in `/api/oauth2-redirect`. Back in Google, under **Authorised redirect URIs** click **Add URI**, paste it, and click **Create**.

**5. Copy the ID and the secret.** Google now shows the **Client ID** (it ends in `.apps.googleusercontent.com`) and the **Client secret**. Copy both now: Google shows the secret only once.

**6. Switch it on in Obhijatra.** In **Settings → Sign-in methods**, paste the client ID and the client secret, switch on **Google**, and click **Save**. Google can take from 5 minutes to a few hours to accept a new redirect address, so if the first try says `redirect_uri_mismatch`, wait and try again.

**7. Try it.** Sign out of the manager app, click **Continue with Google**, and choose your Google account. You should arrive signed in.

If someone sees "No Obhijatra account here uses this Google email address", add their account with that address, or correct the address on their account. If they see "Your organisation admin must confirm your email address", mark their account as **Verified**. If they see "Google cannot vouch that this email address belongs to this Google account", they need a Gmail or Google Workspace address, or another way to sign in.

Changing someone's email address, phone number, role or confirmation signs them out on every device.

## Part 2: SMS codes

**1. Find your SMS provider's guide for sending one message.** Look for a page called something like "Send SMS API" or "HTTP API". You need:
- the web address for sending, which must start with `https://`;
- whether it uses **GET** or **POST**;
- for POST, whether the body is **JSON** or a **form**;
- where the phone number, the message text and your API key or token go;
- what the provider replies when the message is accepted (for example `"status":"SUCCESS"`).

**2. Fill in the form.** In the manager app open **Settings → Sign-in methods → SMS codes**. Copy the provider's example into the form, and replace the real values with these placeholders:

| Put this | Where the guide has | Becomes, for example |
|---|---|---|
| `{phone}` | the number with a plus sign | `+8801712345678` |
| `{phone_digits}` | the number without a plus sign | `8801712345678` |
| `{message}` | the text of the SMS | `123456 is your Obhijatra sign-in code. …` |
| `{secret}` | your API key or token | (hidden) |

Type your API key or token into **Secret key**, not into the address or body: Obhijatra keeps it encrypted and never shows it again. If you later change the provider's server name in **Address**, type the key again; Obhijatra will not send a saved key to a different server.

An example, for a made-up provider whose guide says "POST JSON `{"to": "8801…", "text": "…"}` to `https://api.example-sms.com/v1/send` with the header `Authorization: Bearer YOUR-KEY`":

| Field | What to enter |
|---|---|
| Method | POST |
| Address | `https://api.example-sms.com/v1/send` |
| Body format | JSON |
| Body | `{"to": "{phone_digits}", "text": "{message}"}` |
| Extra header | Name `Authorization`, value `Bearer {secret}` |
| Secret key | your API key |
| Success text | `SUCCESS` (whatever the provider replies on success; leave empty if unsure) |

**3. Send a test.** Type your own mobile number under **Send test SMS** and click **Send test SMS**. You should receive "Obhijatra test message: your SMS settings work." If not, the screen shows what the provider answered; compare it with the provider's guide.

**4. Switch it on.** Switch on **SMS codes** and click **Save**.

**5. Add numbers to accounts.** Put each person's mobile number on their account in international form. People cannot change their own number.

## Limits and costs

- A code is 6 digits, lasts 5 minutes, and allows 3 tries. It works once.
- One number can receive at most 3 codes in 15 minutes and 10 in a day. One internet connection (for example a branch office) can ask for at most 30 codes in 15 minutes.
- Wrong codes count towards the same lock as wrong passwords: after 10 wrong tries from one place, sign-in is locked there for 15 minutes. You can unlock it sooner, or run `obhijatra-server unlock +8801712345678` on the server.
- Codes are never sent to numbers that have no account, to deactivated accounts, or to organisation admins, but the screen looks the same to the person either way. This stops strangers from finding out which numbers have accounts.
- Across the organisation, at most 3 codes a day per person with a phone number are sent (at least 100 a day), in case someone tries to run up your SMS bill.
- Someone who asks for 10 codes for one number blocks SMS sign-in for that number for a day. The person can still sign in another way.
- On the field app, an SMS code or Google cannot open the app lock on its own. To reset a forgotten app PIN, people sign in with their email address and password. If their account has no password, give it one (or an email address and password) so they can.

## If something goes wrong

- **The test SMS fails with "not allowed".** The provider's address points at the server itself or a reserved network address. Use the provider's public address.
- **"The address must start with https://".** Ask your provider for their secure (HTTPS) address. Obhijatra does not send codes or keys over unencrypted connections.
- **People receive no code but the test works.** Check the number on their account (international form) and that their account is active. Organisation admins never receive codes.
