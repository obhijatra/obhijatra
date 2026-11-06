# Approving phones, computers and browsers

Last checked: 6 November 2026. For: organisation admins and branch managers. Time needed: about 2 minutes per device.

Obhijatra works only on devices that a person has approved. A password, an SMS code or a Google sign-in is not enough on its own: the device must be approved too. This applies to every field app phone, and to every computer and web browser that runs the manager app. A stolen password is then of no use without a device you have checked yourself.

## Words used in this guide

- **Device**: a phone, a computer, or one web browser on a computer. Two browsers on the same computer are two devices.
- **The 18 numbers**: a check code the device shows while it waits for approval, in six groups of three, for example `225 142 753 699 752 889`. In Bangla the app shows Bangla digits. The numbers are not secret, but they prove that the device in front of the person is the one the server knows.
- **Approve**: you type the 18 numbers into the manager app, and the device starts working.
- **Switch off**: a device stops working at once, and whoever uses it is signed out.
- **Server command line**: commands typed on the computer that runs the Obhijatra server, for example `obhijatra-server device list`.

## Who approves what

| Device of | Who can approve it |
|---|---|
| Field staff | Their branch manager (for places in the branch manager's part of the organisation), or any organisation admin |
| Office staff (not organisation admins) | Any organisation admin |
| An organisation admin | Two different organisation admins, one after the other |

Rules that always apply:

- Nobody approves their own device.
- An approval lasts one year. After that the device shows its numbers again and is approved the same way.
- The person who runs the server can approve any device from the server command line. This counts as a full approval.

If your organisation has fewer than three organisation admins, an admin's device cannot get two approvals in the app. Approve it once in the app, then have the person who runs the server approve it from the server command line (see Part 1).

## Golden rule: read the numbers yourself

Read the 18 numbers from the person's own screen, or hear them read out on a phone call with someone whose voice you know. Never accept the numbers by SMS, WhatsApp, email or chat. Someone who has stolen a password could send you the numbers of their own device.

If the numbers do not match, the manager app refuses them before anything is sent. Do not approve the device. Ask the person to check that they are reading the screen of the device they are holding.

## Part 1: the first organisation admin's first device

At the start nobody can approve anyone in the app, so the first device is approved on the server.

**1. Sign in.** Open the manager app and sign in as the first organisation admin. It shows **Waiting for approval**, **This device's numbers**, and **This device's id**.

**2. List the waiting devices.** On the server, run:

```
obhijatra-server device list
```

It shows each waiting device with its **ID**, the person and when it was added. If your data folder is not next to the program, add `--dir` and the folder, as for the other `obhijatra-server` commands.

**3. Check the ID.** Find the line whose ID matches **This device's id** on the manager's screen.

**4. Approve it.** Read the 18 numbers from the manager's screen yourself and run:

```
obhijatra-server device approve <ID> "<the 18 numbers>"
```

For example: `obhijatra-server device approve k3n9q0w2e8r5t1y "225 142 753 699 752 889"`. Spaces and Bangla digits are fine. If the numbers do not match, nothing is approved; check them again.

**5. Wait a moment.** The manager app checks every 15 seconds and opens by itself.

Use the same commands whenever no organisation admin can approve a device in the app:

- `obhijatra-server device list --all` shows every device.
- `obhijatra-server device revoke <ID>` switches a device off.

Every approval and switch-off is recorded in the audit trail.

## Part 2: approving a device in the manager app

**1. The person signs in on the new device.** The field app shows **Waiting for approval** and **This phone's numbers**. The manager app shows **This device's numbers**.

**2. Open Devices.** In your manager app, open **Devices**, then **Other people's devices**. The device is under **Waiting for approval**, with the person's name, their email or phone number, the device (for example "Field app, Android") and when it was added.

**3. Click Approve.** Ask the person to read out the 18 numbers from their own screen, in person or on a phone call. Type them into **The 18 numbers** exactly as you hear them.

**4. Click Approve device.** You see one of these:

- **Device approved**, with the date until which it is approved. The person's device opens by itself within 15 seconds.
- **Needs one more organisation admin**, for an organisation admin's device. A second, different organisation admin repeats steps 2 to 4.

Branch managers see only the phones of field staff in their part of the organisation.

## Part 3: a lost phone or computer

Switch it off at once. Whoever uses it is signed out straight away, and it cannot see or send any data.

- **Your own device:** open **My devices** (organisation admins and branch managers: open **Devices**, then the **My devices** tab), find it, and click **Switch off**.
- **Someone else's device:** open **Devices**, then **Other people's devices**, find it, and click **Switch off**.

A switched-off device stays off. If the person finds it again, they choose **Set up this phone again** (field app) or **Set up this device again** (manager app). It gets new numbers and must be approved again. Forms that were not yet sent stay on the phone.

## Part 4: shared phones

People can share a field phone. Each person's approval is kept separately on the phone. The first time each person signs in, their phone must be approved for them. After that, they can switch back and forth without new approvals.

## If something goes wrong

- **"This device's date or time is wrong."** The device's clock is more than 5 minutes from the server's. On a phone, turn on automatic date and time. On a computer, set the correct date, time and time zone. Then check again.
- **"Please update your browser."** The manager in a browser needs Chrome or Edge 137 or later, Firefox 130 or later, or Safari 17 or later. These browsers keep the device's keys so that nobody can copy them.
- **"Open the secure address."** Browsers keep keys only for pages whose address starts with `https://`.
- **"Three of your devices are already waiting."** Approve them, or switch off the ones not in use, then try again.
- **"The server no longer knew this device."** This happens after the server was restored from an older backup. The device sets itself up again with the same numbers, and must be approved again.
- **"This session belongs to another device."** Sign in again on this device.
- **A private or incognito browser window** cannot keep the keys. Open a normal window.

## Known limits

- **Windows with roaming profiles.** On a Windows computer whose user profile roams between computers (common on organisation networks), the manager app's keys can follow the person to other computers. On such computers, use the manager in a web browser instead.
- **Moving to a new Mac.** The Mac's migration tools copy the manager app's keys to the new Mac. After moving, switch off the old Mac's device in **My devices**, then set the manager up again on the new Mac.
- **Superusers.** The installation and recovery accounts made by `obhijatra-server init` are not device-checked. Use them only for server maintenance, and keep their passwords offline.
