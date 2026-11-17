# SkyCodex Bridge (staging only)

This folder is a staging copy of the remote-computer bridge. It is intentionally isolated on the
`skycodex-bridge-isolated` branch. Do not merge this branch into `main`: `main` contains the SkyfallArena game.

## Intended flow

1. ChatGPT writes a small request file at `.skycodex-bridge/request.json` in a **dedicated private bridge repository**.
2. A GitHub Actions workflow receives that push.
3. The workflow uses a repository secret to call the InstaBox API for the already-existing machine.
4. InstaBox runs a constrained `codex exec` task in `/data/skycodex-workspace`.
5. The workflow saves a result file for ChatGPT to read.

This staging copy is in the public SkyfallArena repository only because its GitHub connection currently exposes
this repository. **Do not add InstaBox API keys or enable the runner in this public game repository.**
The private repository `skycodex-bridge1` must first be made visible to the GitHub connection, then these files
can be copied there.

## Safety and cost boundaries

- The runner only calls `POST /v1/machines/{id}/exec` on the configured existing machine.
- It never creates, deletes, starts, stops, resumes, resizes, or snapshots a machine.
- It does not use GPU resources or paid InstaBox plans.
- Codex is restricted to `workspace-write` in `/data/skycodex-workspace`; it is not given full-machine access.
- The request format does not accept a raw shell command.
- Keep API credentials only in GitHub Actions Secrets. Never put them in request files, commits, or chat.
- Do not use this staging copy for real machine requests because this repository is public.

## Setup in the private bridge repository

Add these Actions Secrets:

- `INSTABOX_API_KEY`: an InstaBox API key with only the machine read/exec scopes needed.
- `INSTABOX_MACHINE_ID`: the ID of the existing `skycodex` machine.

Add this Actions repository variable:

- `SKYCODEX_BRIDGE_ENABLED=true`

The workflow is currently filtered to `skycodex-bridge-isolated`. In the private repository, change that branch filter to the
private repository's working branch (normally `main`). Keep the repository private.

Then ChatGPT can update `.skycodex-bridge/request.json` to submit a request and read
`.skycodex-bridge/result.json` after the workflow completes.

## Request format

See `request.example.json`. Allowed actions are:

- `diagnostics`: read-only checks for Codex, InstaBox CLI, and desktop utilities.
- `codex_task`: ask Codex to work only inside `/data/skycodex-workspace`.

The action does not auto-wake a stopped or paused machine. The machine must already be running.
