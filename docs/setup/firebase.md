# Free cloud testing with Firebase: setup guide

Last checked: 4 November 2026. Time needed: about 40 minutes, once.

## What this gives you

- Every time the team merges to the main branch, a test copy of the field app is sent to your Android phone.
- Once a day, an automatic "Robo" test taps around the app on a low-end virtual Android phone in Google's data centre and tells you if it crashes.
- The apps contain no Firebase code and no `google-services.json` file. Firebase is used only by the automated checks (GitHub Actions), with made-up (synthetic) data.

## Words used in this guide

- **Repository variable**: a named setting stored in GitHub, which the automated checks read.
- **Cloud Shell**: a small command window that opens inside your web browser, run by Google. You paste text into it.
- **Workload Identity Federation**: a way for GitHub to prove who it is to Google without any password or key file being stored.

## How the automatic sign-in works (and why)

We use **keyless sign-in** (Workload Identity Federation). No password or key file is created, so there is nothing to leak. You set it up by pasting one script into Cloud Shell (step 7).

Google says new organisations (created on or after 3 May 2024) block the creation of service-account key files by default (source: Google Cloud documentation, "Restrict service accounts", checked 4 November 2026). That is a second reason to avoid key files.

## The steps

**1. Open Firebase.** Go to `https://console.firebase.google.com` and sign in with the Google account that will own this (the one you use for GRU953/Obhijatra).

**2. Create the project.** Click **Create a Firebase project**. Type the name `obhijatra-ci` and click **Continue**. When asked about Google Analytics, switch it **off** and click **Create project**. Click **Continue** when it says the project is ready. Do not add a payment card: a new project starts on the free Spark plan.
*UNVERIFIED – check before use: exact button names; the Firebase setup page could not be summarised on 4 November 2026.*

**3. Register the Android app.** On the project home page click the Android icon (the little robot). In **Android package name** type `io.github.obhijatra.field`. In **App nickname** type `Obhijatra Field`. Click **Register app**. When it offers **Download google-services.json**, do **not** download it. Click **Next** until the last button, then click **Continue to console**. (We deliberately do not use this file.)
*UNVERIFIED – check before use: button names.*

**4. Copy the app ID.** Click the cog beside **Project Overview**, then **Project settings**. Scroll to **Your apps**. Find **App ID**; it looks like `1:123456789:android:0a1b2c3d4e5f`. Copy it into a note; you need it in step 8. (The format matches Firebase's own example for the `--app` setting.)

**5. Add yourself as a tester.** In the left menu click **Release & Monitor**, then **App Distribution**. Click **Get started**. Open the **Testers & Groups** tab and click **Add group**. Type `core-testers` and click **Save**. Click the group, click **Add testers**, type your own email address and click **Add**.
*UNVERIFIED – check before use: menu names.*

**6. Open Cloud Shell.** Go to `https://console.cloud.google.com`. At the top, click the project picker and choose `obhijatra-ci`. Click the **Activate Cloud Shell** button at the top right (a small `>_` icon). Click **Continue** or **Authorize** if asked. Wait for a prompt to appear.

**7. Paste the script.** Copy the whole script in the box below, click once in the Cloud Shell window, paste (Ctrl+V; on Mac, Cmd+V) and press **Enter**. It takes about two minutes. At the end it prints four lines headed `COPY THESE FOUR VALUES`. Copy them into your note. It is safe to run again; it never duplicates anything.

```bash
#!/usr/bin/env bash
# Obhijatra: one-off Google Cloud setup for free Firebase testing from GitHub Actions.
# Safe to run more than once. Nothing here creates a password or key file.
set -euo pipefail

GITHUB_REPO="obhijatra/obhijatra"          # the only repository allowed to sign in
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SA_NAME="obhijatra-ci"
AUDIENCE="obhijatra-ci"                     # must match the text in .github/workflows/firebase.yml

# 1. Use the project that is selected in Cloud Shell.
PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
if [ -z "$PROJECT_ID" ]; then
  echo "No project is selected. Use the project picker at the top of the page, then run this again."
  exit 1
fi
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Using project: $PROJECT_ID"

# 2. Switch on the Google services we need.
#    Cloud Testing API, Cloud Tool Results API, Firebase App Distribution API,
#    plus the two that keyless sign-in needs (IAM Credentials and Security Token Service).
gcloud services enable \
  testing.googleapis.com \
  toolresults.googleapis.com \
  firebaseappdistribution.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  --project="$PROJECT_ID"

# 3. Create the robot account that GitHub will act as (skip if it already exists).
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="Obhijatra CI (GitHub Actions)" --project="$PROJECT_ID"
  sleep 15   # give Google a moment to register the new account
fi

# 4. Give the robot account only the permissions it needs (least privilege).
#    - App Distribution Admin: upload builds to testers.
#    - Test Lab Admin: start tests.
#    - Service Usage Consumer: allowed to call the services above.
#    UNVERIFIED – check before use: these role names were not confirmed against Google's pages.
for ROLE in roles/firebaseappdistro.admin roles/cloudtestservice.testAdmin roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" --role="$ROLE" --condition=None --quiet >/dev/null
done

# 5. Create the "pool" and the GitHub "provider" (skip if they already exist).
if ! gcloud iam workload-identity-pools describe "$POOL_ID" --location=global --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --location=global --display-name="GitHub Actions" --project="$PROJECT_ID"
fi
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
     --workload-identity-pool="$POOL_ID" --location=global --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --workload-identity-pool="$POOL_ID" --location=global --project="$PROJECT_ID" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --allowed-audiences="$AUDIENCE" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'"
fi
PROVIDER_NAME="$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --workload-identity-pool="$POOL_ID" --location=global --project="$PROJECT_ID" --format='value(name)')"

# 6. Allow ONLY our repository to act as the robot account.
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_REPO}" \
  --quiet >/dev/null

# 7. Print the four values to copy into GitHub.
echo
echo "================ COPY THESE FOUR VALUES ================"
echo "GCP_PROJECT_ID                 = ${PROJECT_ID}"
echo "GCP_WORKLOAD_IDENTITY_PROVIDER = ${PROVIDER_NAME}"
echo "GCP_SERVICE_ACCOUNT            = ${SA_EMAIL}"
echo "FIREBASE_ANDROID_APP_ID        = (the App ID from step 4; not printed here)"
echo "========================================================"
```

**8. Add the four settings in GitHub.** Open `https://github.com/obhijatra/obhijatra`. Click **Settings**, then in the left menu **Secrets and variables**, then **Actions**. Click the **Variables** tab, then **New repository variable**. Add these four, one at a time (type the name, paste the value, click **Add variable**):

| Name | Value |
|---|---|
| `GCP_PROJECT_ID` | printed by the script |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | printed by the script |
| `GCP_SERVICE_ACCOUNT` | printed by the script |
| `FIREBASE_ANDROID_APP_ID` | the App ID you copied in step 4 |

They are variables, not secrets, because none of them is a password. Without them, the workflow skips itself with a notice and does no harm.

**9. Run it for the first time.** In the repository click **Actions**. In the left list click **Firebase (distribute and test)**. Click **Run workflow**, keep **main**, click the green **Run workflow** button. Wait about 15 minutes. A green tick means success.

**10. Install the tester app on your phone.** On your Android phone, open the invitation email from Firebase App Distribution (check Spam), tap **Get started**, and follow the prompts to install **Firebase App Tester**. Open it and install **Obhijatra Field** from the list. After this, each new build appears there.
*UNVERIFIED – check before use: the exact wording of the invitation email.*

**11. See the results.** In GitHub click **Actions**, click the latest run, then click **Summary** (top left). It shows whether the build was sent, which virtual phone was chosen, whether the Robo test passed, and links to the Test Lab report with screenshots and a video.

## When things run

| Trigger | Sends to your phone | Robo test |
|---|---|---|
| Merge to main | Yes | No |
| Every day at about 03:17 UTC (09:17 in Dhaka) | No | Yes |
| You press **Run workflow** | Yes | Yes |

## If something fails

- **"Permission denied" on the test step.** Google's own command help says the free results storage needs the editor role. Fix: in Cloud Shell run the command below (this project holds nothing but test data), then re-run the workflow.
  `gcloud projects add-iam-policy-binding $(gcloud config get-value project) --member="serviceAccount:obhijatra-ci@$(gcloud config get-value project).iam.gserviceaccount.com" --role=roles/editor --condition=None`
- **Sign-in fails.** UNVERIFIED – check before use: the workflow's hand-made keyless sign-in and the Firebase tool's acceptance of it were not confirmed against Google's pages. Tell the engineer; the fallback is the standard Google sign-in action.

## What this costs

Free within quotas: the Spark plan allows 10 virtual and 5 physical runs a day (Firebase quota page, checked 4 November 2026). We run at most about 2 virtual runs a day. App Distribution has no charge listed in the pages checked; UNVERIFIED – check before use. Never add a payment card unless you decide to.

## What happens in September 2027

Firebase Test Lab is deprecated and will be fully shut down on 30 September 2027 (Firebase page "Migrate", updated 3 November 2026). Google names its "Developer Device Platform" (currently in preview) as the replacement. App Distribution is not mentioned in that notice. Before the end of August 2027 we will move the test step to the replacement; only `.github/workflows/firebase.yml` changes.

## Real phones

- Use your own Android phone through App Distribution for daily checking.
- Before the Phase 1 gate, also test on a phone costing under US$100. The virtual phone shows crashes, not how slow a cheap handset feels.
- iOS is not sent anywhere yet (it needs a paid Apple account). For now the iOS build in GitHub Actions (`ci.yml`) is the iOS test.
