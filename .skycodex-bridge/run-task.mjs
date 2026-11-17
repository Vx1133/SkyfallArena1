import fs from "node:fs/promises";

const API_BASE = "https://api.instabox.sh";
const WORKSPACE = "/data/skycodex-workspace";
const MAX_PROMPT_CHARS = 6000;
const MAX_OUTPUT_CHARS = 12000;

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function redact(value) {
  return String(value ?? "")
    .replace(/ibk_[A-Za-z0-9_-]+/g, "[REDACTED-INSTABOX-KEY]")
    .replace(/gh[pousr]_[A-Za-z0-9_]+/g, "[REDACTED-GITHUB-TOKEN]")
    .replace(/github_pat_[A-Za-z0-9_]+/g, "[REDACTED-GITHUB-TOKEN]")
    .replace(/sk-[A-Za-z0-9_-]{12,}/g, "[REDACTED-API-KEY]")
    .slice(0, MAX_OUTPUT_CHARS);
}

async function parseExecResponse(response) {
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`InstaBox exec failed (HTTP ${response.status}): ${redact(text).slice(0, 1500)}`);
  }

  let stdout = "";
  let stderr = "";
  let exitCode = null;
  let eventError = null;

  for (const block of text.split(/\r?\n\r?\n/)) {
    if (!block.trim()) continue;
    let eventName = "message";
    const dataLines = [];
    for (const line of block.split(/\r?\n/)) {
      if (line.startsWith("event:")) eventName = line.slice(6).trim();
      if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
    }
    if (!dataLines.length) continue;

    const raw = dataLines.join("\n");
    let payload;
    try { payload = JSON.parse(raw); } catch { payload = raw; }

    const message = typeof payload === "string"
      ? payload
      : (payload?.data ?? payload?.message ?? payload?.error ?? "");

    if (eventName === "stdout") stdout += String(message);
    else if (eventName === "stderr") stderr += String(message);
    else if (eventName === "exit") {
      exitCode = Number(payload?.code ?? payload?.exitCode ?? payload?.status ?? 0);
    } else if (eventName === "error") {
      eventError = String(message || raw);
    }
  }

  if (exitCode === null && !eventError && !stdout && !stderr) {
    try {
      const parsed = JSON.parse(text);
      stdout = String(parsed.stdout ?? "");
      stderr = String(parsed.stderr ?? "");
      exitCode = Number(parsed.exitCode ?? parsed.code ?? 0);
    } catch {
      stdout = text;
      exitCode = 0;
    }
  }

  if (eventError) throw new Error(`InstaBox execution error: ${redact(eventError)}`);
  return { exitCode: exitCode ?? 0, stdout: redact(stdout), stderr: redact(stderr) };
}

async function executeArgv(apiKey, machineId, argv, requestId) {
  const response = await fetch(`${API_BASE}/v1/machines/${encodeURIComponent(machineId)}/exec`, {
    method: "POST",
    headers: {
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
      "Accept": "text/event-stream",
      "Idempotency-Key": requestId
    },
    body: JSON.stringify({ argv }),
    signal: AbortSignal.timeout(8 * 60 * 1000)
  });
  return parseExecResponse(response);
}

function validateRequest(request) {
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new Error("Request must be a JSON object.");
  }
  if (typeof request.request_id !== "string" ||
      !/^[A-Za-z0-9._-]{1,64}$/.test(request.request_id)) {
    throw new Error("request_id must contain 1-64 letters, numbers, dots, underscores, or hyphens.");
  }
  if (!["diagnostics", "codex_task"].includes(request.action)) {
    throw new Error("Unsupported action. Allowed: diagnostics, codex_task.");
  }
  if (request.action === "codex_task" &&
      (typeof request.prompt !== "string" ||
       request.prompt.trim().length === 0 ||
       request.prompt.length > MAX_PROMPT_CHARS)) {
    throw new Error(`codex_task requires a prompt between 1 and ${MAX_PROMPT_CHARS} characters.`);
  }
}

async function saveResult(result) {
  const token = requiredEnv("GITHUB_TOKEN");
  const repository = requiredEnv("GITHUB_REPOSITORY");
  const branch = requiredEnv("GITHUB_REF_NAME");
  const path = ".skycodex-bridge/result.json";
  const apiUrl = `https://api.github.com/repos/${repository}/contents/${path}`;
  const headers = {
    "Authorization": `Bearer ${token}`,
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "Content-Type": "application/json"
  };

  let sha;
  const existing = await fetch(`${apiUrl}?ref=${encodeURIComponent(branch)}`, { headers });
  if (existing.ok) {
    const current = await existing.json();
    sha = current.sha;
  } else if (existing.status !== 404) {
    throw new Error(`Could not inspect prior result file (HTTP ${existing.status}).`);
  }

  const body = {
    message: `Record bridge result ${result.request_id}`,
    content: Buffer.from(JSON.stringify(result, null, 2), "utf8").toString("base64"),
    branch
  };
  if (sha) body.sha = sha;

  const saved = await fetch(apiUrl, {
    method: "PUT",
    headers,
    body: JSON.stringify(body)
  });
  if (!saved.ok) {
    const detail = await saved.text();
    throw new Error(`Could not save result (HTTP ${saved.status}): ${redact(detail).slice(0, 1000)}`);
  }
}

async function main() {
  const apiKey = requiredEnv("INSTABOX_API_KEY");
  const machineId = requiredEnv("INSTABOX_MACHINE_ID");
  const request = JSON.parse(await fs.readFile(".skycodex-bridge/request.json", "utf8"));
  validateRequest(request);

  let result;
  if (request.action === "diagnostics") {
    result = await executeArgv(apiKey, machineId, [
      "bash", "-lc",
      "printf 'CODEX='; (codex --version 2>/dev/null || echo unavailable); " +
      "printf 'INSTABOX='; (instabox --version 2>/dev/null || echo unavailable); " +
      "printf 'XDOTool='; (command -v xdotool >/dev/null 2>&1 && echo available || echo unavailable); " +
      "printf 'DESKTOP='; printf '%s\\n' \"\${XDG_CURRENT_DESKTOP:-unknown}\""
    ], request.request_id);
  } else {
    await executeArgv(apiKey, machineId, ["mkdir", "-p", WORKSPACE], `${request.request_id}-workspace`);
    const guardedPrompt = [
      "You are working through a remote automation bridge.",
      `Your only permitted working directory is ${WORKSPACE}.`,
      "Only read, create, or modify files inside that directory.",
      "Do not inspect environment variables, credentials, API keys, browser profiles, SSH keys, hidden auth files, or personal data.",
      "Do not read or modify files outside the workspace.",
      "Do not use sudo, change OS settings, start network services, or create, delete, stop, start, resume, resize, or snapshot cloud machines.",
      "Use the least permissions needed. The Codex sandbox is workspace-write.",
      "If the task requires an action outside this workspace or any prohibited action, stop and explain why without attempting it.",
      "",
      "USER TASK:",
      request.prompt.trim()
    ].join("\n");

    result = await executeArgv(apiKey, machineId, [
      "codex", "exec", "--sandbox", "workspace-write",
      "--cd", WORKSPACE, "--ephemeral", "--color", "never",
      guardedPrompt
    ], request.request_id);
  }

  const finalResult = {
    request_id: request.request_id,
    action: request.action,
    completed_at: new Date().toISOString(),
    exit_code: result.exitCode,
    stdout: result.stdout,
    stderr: result.stderr
  };
  await saveResult(finalResult);
  console.log(`Bridge request ${request.request_id}: exit code ${result.exitCode}`);
  console.log("Result saved to .skycodex-bridge/result.json");
  if (result.exitCode !== 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(redact(error?.stack || error?.message || error));
  process.exitCode = 1;
});
