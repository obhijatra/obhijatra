# Setting up your organisation's places

Last checked: 6 November 2026. For: the organisation admin.

Places are your organisation's offices and areas: for example **head office → region → area → branch**. Every person works at a place, and every form is stamped with its place. A supervisor sees the people and forms in their own place and every place inside it.

You manage places in the manager app under **Places** (organisation admins only).

## Add places one by one

- Click **Add place**, or open the **⋮** menu (**Actions for …**) beside a place and choose **Add a place inside**.
- Give it a **Name** and, if you use them, a **Code** (for example a branch code). Two places at the same level cannot have the same name, and two places anywhere cannot have the same code.
- **A place cannot be moved later.** Choose where it goes carefully.

## Import many places from a spreadsheet

1. In Excel or Google Sheets, make one row per place. Put the levels in columns from the top down, for example **Region | Area | Branch**, and, if you like, a last column named **code**. The first row holds the column names. Bangla names are fine.
2. Save it as **CSV UTF-8** (Excel: **File → Save As → CSV UTF-8**; Google Sheets: **File → Download → Comma-separated values**).
3. In **Places**, click **Import from a spreadsheet**, choose where the new places go, and choose the file.
4. Check the preview: how many places are new, how many are already there, and any problems with their line numbers. Fix any problems in the spreadsheet and choose the file again.
5. Click **Add … places**. Either every place is added or none is.

Places that already exist (same name at the same level, ignoring capitals and extra spaces) are reused, so you can import the same file again safely.

## When a place is no longer needed

- **Close place** hides it from new choices but keeps its records. First move its people elsewhere (or deactivate them) and close the places inside it. You can **Reopen place** later.
- **Delete place** works only for a place that was never used: no places inside it, nobody assigned to it and no forms from it. Otherwise close it instead.
- The organisation itself can be neither closed nor deleted.
