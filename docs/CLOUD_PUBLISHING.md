# Private Roblox test upload

The project has two separate operations:

1. **Build and validate:** GitHub Actions checks the Luau source and creates `SkyfallArena.rbxlx`. This does not contact or change Roblox.
2. **Private test upload:** A separate manually triggered workflow uploads a new version to the selected Roblox place. It does not change the experience audience setting.

## Target IDs

The IDs copied from the Creator Dashboard are:

- Universe ID: `7975091208`
- Start Place ID: `104752078056182`

The Universe ID identifies the experience and is used when scoping the Roblox API key. The Start Place ID identifies the exact place that the upload workflow updates.

## Keep the experience private

Before the first upload, open the experience in Creator Dashboard and confirm its Audience / Access Settings are set to **Private**. Do not switch it to Public or release it to everyone.

The upload request must set `published: true` so Roblox updates the selected place to a playable new version. This publishes a place version to the experience; it does **not** change the audience setting or make a Private experience public. The owner can access their private experience.

**Important:** The workflow updates the contents of the configured Start Place. It does not create a separate test place. The owner has approved replacing this automatically created place with the Skyfall Arena test build. Roblox keeps place version history, which can be used to restore an earlier version.

## GitHub settings required

In the repository `Vx1133/SkyfallArena1`, add these repository variables under **Settings > Secrets and variables > Actions > Variables**:

| Name | Value |
|---|---|
| `ROBLOX_UNIVERSE_ID` | `7975091208` |
| `ROBLOX_PLACE_ID` | `104752078056182` |

Add this repository secret under **Settings > Secrets and variables > Actions > Secrets**:

| Name | Value |
|---|---|
| `ROBLOX_API_KEY` | Your Roblox Open Cloud API key |

Never paste the key into chat, commit it to the repository, or put it in a Luau file.

## Roblox API key permissions

Create a dedicated key in Creator Dashboard for this upload workflow:

- Name: `SkyfallArena-PrivateTest`
- Access permission: **Assets**
- Experience restriction: keep **Restrict by Experience** enabled and select only Universe ID `7975091208`
- Operations: **Read** and **Write**
- IP restriction: leave it off unless you have a fixed runner IP. GitHub-hosted runner IP addresses are not fixed.

These are the current permissions documented by Roblox for updating an existing place through the Assets API.

## Manual upload workflow

The workflow is `.github/workflows/upload-private-test.yml` and is now on the repository's default `main` branch.

To run it after the GitHub variables and secret are configured:

1. Open the repository's **Actions** tab.
2. Select **Upload Skyfall Arena private test**.
3. Click **Run workflow**.
4. Enter exactly `UPLOAD_PRIVATE_TEST` in the confirmation field and start the workflow.

The workflow:
- Only starts through a manual `workflow_dispatch` action.
- Requires the exact confirmation text `UPLOAD_PRIVATE_TEST`.
- Rebuilds the place and repeats the structural validation and Selene lint checks.
- Uploads the RBXLX file using the current Roblox Assets API endpoint:
  `PATCH https://apis.roblox.com/assets/v1/assets/{placeId}`
- Polls the returned operation until Roblox reports completion and `isPublished: true`.
- Does not run automatically when code is pushed, and does not change the experience's Audience setting.

## What has and has not been tested

The validation workflow successfully checked the project structure, Luau lint, and Rojo build, and uploaded a build artifact. The game has **not** yet been run in a live Roblox server. The private upload and in-app playtest are still pending.

Official Roblox guide: https://create.roblox.com/docs/cloud/guides/usage-place-publishing

Official API key guide: https://create.roblox.com/docs/cloud/auth/api-keys

GitHub secrets guide: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
