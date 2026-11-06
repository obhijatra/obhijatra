# Downloading submissions

Last checked: 6 November 2026. For: organisation admins and M&E staff. Time needed: a minute or two per download.

You can download a form's submissions as one zip file. It holds:

- a spreadsheet of the answers;
- each submission exactly as the phone sent it;
- the form itself;
- the photos and other files, if you choose.

Excel shows Bangla correctly when you double-click the spreadsheet. The layout is the same as ODK Central's, so tools made for ODK can read it.

## Words used in this guide

- **Zip file**: one file that holds several files. Double-click it to open it, or right-click it and choose **Extract All** (Windows) or double-click it (Mac).
- **CSV**: a simple spreadsheet file that Excel, Google Sheets and statistics programs open.
- **Repeat group**: a set of questions asked several times in one form, for example once for each household member. Each repeat group gets its own CSV file.
- **Review state**: what a reviewer decided about a submission: Received, Edited, Has issues, Approved or Rejected.

## Who can download

| Person | What they can download |
|---|---|
| Organisation admin | Every submission |
| M&E staff | The submissions from their own part of the organisation |
| Everyone else | Nothing |

Every download is recorded: who downloaded what, when, with which filters, and from which device. Organisation admins can see every download.

## Download

**1. Open Submissions.** In the manager app, open **Submissions**.

**2. Click Download.** The **Download submissions** window opens with the form and filters you were looking at.

**3. Choose what to download:**
- **Form**: the form whose submissions you want.
- **From** and **To (this day included)**: the days the submissions arrived, in your computer's time zone. Leave both as **Any day** to download everything.
- **Review states**: all are chosen at first. Untick the ones you don't want.
- **Include photos and other files**: on at first. This makes the download larger.

**4. Click Download.** You see one of these:

- **"The server is preparing the file…"**, then how much has arrived.
- **Confirm it's you.** This appears if you signed in more than 15 minutes ago. Type **Your password** and click **Confirm**, or use the other way it offers. The download then starts again by itself.

**5. Save the file.** On Windows or Mac, choose where to save it. In a web browser, it goes to your downloads folder. When it says **Download complete**, the file is ready.

**6. Open the spreadsheet.** Open the zip file, then double-click the CSV file named after the form, for example `household_visit.csv`.

## What is in the zip file

| File | What it holds |
|---|---|
| `<form>.csv` | One row per submission. The first column is when it arrived. The last columns tell you who sent it, its review state and the form version. |
| `<form>-<group>.csv` | One per repeat group. Each row's `PARENT_KEY` matches the `KEY` of the submission (or group) it belongs to. |
| `forms/` | The form's XML. |
| `submissions/` | Each submission exactly as the phone sent it. |
| `media/` | Photos, recordings and files, if you included them. The spreadsheet names them. |
| `README.txt` | This list, in short. |
| `manifest.json` | Who downloaded it and with which filters, plus a fingerprint (SHA-256) of every file. With the fingerprints you can check later that nothing in the package changed. |

To keep a spreadsheet from running an answer as a formula, the CSV puts an apostrophe (`'`) in front of any answer that starts with `=`, `+`, `-` or `@`. Plain numbers such as `-12.5` or `+8801712345678` are not changed. The files in `submissions/` keep every answer exactly as it was sent.

## Keep the data safe

The file holds personal data, such as names and phone numbers.

- Save it only on a computer that locks with a password.
- Share it only with people who need it, and never by a public link.
- Delete it, and empty the Recycle Bin or Trash, when you no longer need it.

## If something goes wrong

- **"Confirm it's you"** appears: your last sign-in was more than 15 minutes ago. Confirm, and the download continues.
- **"The download was not complete. Try again."**: the connection broke or the server stopped. The incomplete file is removed. Try again, perhaps with **Include photos and other files** off, or with fewer days.
- **"This form has no version yet, so there is nothing to download."**: publish a version of the form first.
- **Very large downloads in a web browser** can be slow, because the browser holds the whole file in memory until it is saved. Use the Windows or Mac app, or leave photos out.
- **Download is missing from Submissions**: only organisation admins and M&E staff see it.
