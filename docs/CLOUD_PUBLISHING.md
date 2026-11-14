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

**Important:** The workflow updates the contents of the configured Start Place. It does not create a separate test place. Confirm that this automatically created place is okay to replace with the Skyfall Arena test build before running the upload. Roblox keeps place version history, which can be used to restore an earlier version.

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

Never paste the key into chat, commit it to GitHub, or put it in a Luau file.

## Roblox API key permissions

Create the key in Creator Dashboard and scope it to the experience with Universe ID `7975091208`:

- Access permission: **Assets**
- Operations: **Read** and **Write**
- Select only the intended experience, not unrelated experiences.

These are the current permissions documented by Roblox for updating an existing place through the Assets API.

## Manual upload workflow

The workflow is `.github/workflows/upload-private-test.yml`.

- It only starts through a manual `workflow_dispatch` action.
- It requires the exact confirmation text `UPLOAD_PRIVATE_TEST`.
- It rebuilds the place and repeats the structural validation and Selene lint checks.
- It uploads the RBXLX file using the current Roblox Assets API endpoint:
  `PATCH https://apis.roblox.com/assets/v1/assets/{placeId}`
- It polls the returned operation until Roblox reports completion and `isPublished: true`.
- It does not run automatically when code is pushed, and it does not change the experience's Audience setting.

GitHub only allows the manual Run workflow control when the workflow file is present on the repository's default branch. This workflow is currently on the feature branch and draft PR, so it becomes manually runnable after the PR is reviewed and merged.

## What has and has not been tested

The validation workflow has successfully checked the project structure, Luau lint, and Rojo build, and uploaded a build artifact. The game has **not** yet been run in a live Roblox server. The private upload and in-app playtest are still pending.

Official Roblox guide: https://create.roblox.com/docs/cloud/guides/usage-place-publishing

GitHub manual workflow guide: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow
