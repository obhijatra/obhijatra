# GitHub: what is set up, and how to see test results

Last checked: 4 November 2026.

## For the record: what already exists

- GitHub organisation: `obhijatra` (open source).
- Repository: `obhijatra/obhijatra`, at `https://github.com/obhijatra/obhijatra`.
- Automatic checks live in `.github/workflows/`:
  - `ci.yml` builds and tests the apps on every push to main and every pull request.
  - `firebase.yml` sends test builds to your phone and runs the daily Robo test (see `docs/setup/firebase.md`).
- Other details of how the organisation was created (members, two-step sign-in, branch rules) were not given to the person writing this page. Owner: please add them here. UNVERIFIED.

## How to see CI results

1. Open `https://github.com/obhijatra/obhijatra`.
2. Click **Actions** (top menu).
3. In the left list, click **CI** (build and tests) or **Firebase (distribute and test)**.
4. Click the newest run at the top.
5. A green tick means it passed. A red cross means it failed. A yellow circle means it is still running.
6. Click **Summary** (top left) for the short report. For Firebase runs it shows whether the build was sent, the virtual phone used, the Robo result and report links.
7. To see why something failed, click the red job name, then the step with the red cross.
8. The built field app (a `.apk` file) is under **Artifacts** at the bottom of a **CI** run's Summary page.

## If the Firebase workflow says "skipped"

The four repository variables are not set. Follow step 8 in `docs/setup/firebase.md`.
