# Private Roblox test upload and cloud smoke tests

The project has two separate validation stages and one manually approved upload:

1. **Repository validation:** GitHub Actions checks project structure, Luau lint, and the Rojo build. This does not contact Roblox.
2. **Manual private upload:** A workflow uploads a new version to the existing Roblox Start Place. It does not change the experience audience setting.
3. **Headless cloud smoke tests:** After Roblox confirms the upload, the same workflow runs a Luau test script against that exact place version and collects the task logs.

## Target IDs

- Universe ID: `7975091208`
- Start Place ID: `104752078056182`

Every release must keep using this same Start Place. Do not create a replacement experience or Place for normal updates.

## Keep the experience private

Confirm the experience's Audience / Access Settings are set to **Private** in Creator Dashboard. The upload workflow updates the selected Place version but does not change its Audience setting.

The workflow requires a manual `workflow_dispatch` action and the exact confirmation text `UPLOAD_PRIVATE_TEST`. It does not run on pushes or pull requests.

## GitHub secret

Keep one repository secret:

| Name | Value |
|---|---|
| `ROBLOX_API_KEY` | Dedicated Roblox Open Cloud API key |

Never paste the key into chat or commit it to the repository.

## Roblox API key permissions

Keep **Restrict by Experience** enabled and select only Universe ID `7975091208`. The same key needs these permissions:

- **Assets:** Read and Write, for updating the existing Place.
- **Luau Execution:** Read and Write, for creating the cloud test task and reading its result and logs.

The Luau Execution API scopes are `universe.place.luau-execution-session:write` and `universe.place.luau-execution-session:read`. Roblox requires the write scope to create a task and both read/write scopes to retrieve its status and logs.

Do not grant unrelated permissions such as monetization, player bans, or public release management.

## What the cloud tests cover

The test script at `tests/cloud_smoke_tests.luau` is passed directly to Roblox Open Cloud and runs against the exact version number returned by the upload operation. It is not inserted into the published game.

Current checks:

- The arena builds 81 tiles and required lobby / aircraft structures.
- Four laser-damaged tiles remain broken while the cloud task waits, and the next map restores the full grid.
- Old laser tokens cannot damage tiles after a map reset.
- Controller selection returns a valid candidate and prioritizes the previous survivor when supplied.
- Sole-survivor and grounded-state helpers distinguish floor contact from being airborne.
- Human laser requests reject a non-controller, inactive round, invalid grid coordinates, and requests inside the cooldown. A valid request produces a delayed strike in the test harness.

The test runner destroys the temporary arena it creates. Roblox documents that Luau Execution task changes to the DataModel are local to the task and cannot be persisted.

## Important test limits

This is a **headless DataModel and module test**, not a full live-server play session:

- Physics simulation does not run.
- Server and LocalScripts in the place do not start automatically.
- It does not create real players or simulate actual phone touches, keyboard input, collisions, pathfinding movement, or animation playback.
- The laser request test uses mock player / remote-side collaborators while exercising the real `StrikeService` validation method.
- A successful cloud test therefore does not prove that the entire game plays correctly on a phone. A visual playtest in Roblox Studio is still required for that.

If the cloud test fails, GitHub Actions marks the upload workflow as failed and prints the Luau task logs. The place version has already been uploaded at that point, so the experience must remain Private while the cause is reviewed. This workflow does not silently roll back or make additional uploads.

## Run the workflow

1. Open the repository's **Actions** tab.
2. Select **Upload Skyfall Arena private test**.
3. Click **Run workflow** and choose `main`.
4. Enter `UPLOAD_PRIVATE_TEST` exactly.
5. Review both the Roblox upload result and the later **headless Roblox Luau smoke tests** section.

## Official references

- Roblox Luau Execution: https://create.roblox.com/docs/cloud/reference/features/luau-execution
- Roblox place publishing: https://create.roblox.com/docs/cloud/guides/usage-place-publishing
- Roblox API key guide: https://create.roblox.com/docs/cloud/auth/api-keys
- GitHub Actions secrets: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
