--!strict
-- Regression tests for the bounded startup gate before a round begins.

local StartupReadinessPolicy = require("../../src/shared/StartupReadinessPolicy")

assert(
	not StartupReadinessPolicy.CanBeginIntermission(0, false),
	"Round intermission must wait while no bot controller is ready and no human opted in"
)
assert(
	StartupReadinessPolicy.CanBeginIntermission(1, false),
	"One ready bot is enough to release the normal startup gate"
)
assert(
	StartupReadinessPolicy.CanBeginIntermission(10, false),
	"All ready bots must allow normal startup"
)
assert(
	StartupReadinessPolicy.CanBeginIntermission(0, true),
	"Explicit human aircraft opt-in must allow startup if bot rig generation fails"
)
assert(
	not StartupReadinessPolicy.CanBeginIntermission(-1, false),
	"Invalid negative ready-bot counts must not release startup"
)

assert(
	not StartupReadinessPolicy.CanStartPlay(false, true, "Waiting", false),
	"Play must remain disabled until server services are ready"
)
assert(
	not StartupReadinessPolicy.CanStartPlay(true, false, "Waiting", false),
	"Play must remain disabled until the player's character is loaded and placed"
)
assert(
	StartupReadinessPolicy.CanStartPlay(true, true, "Waiting", false),
	"Play must become available after server and character readiness"
)
assert(
	not StartupReadinessPolicy.CanStartPlay(true, true, "Intermission", false),
	"Play must not send a new request during intermission"
)
assert(
	not StartupReadinessPolicy.CanStartPlay(true, true, "Waiting", true),
	"Ready players must not be able to submit duplicate Play requests"
)
assert(
	not StartupReadinessPolicy.ShouldRetryBotRig("Failed", 29, 30),
	"Failed bot rigs must respect the retry cooldown"
)
assert(
	StartupReadinessPolicy.ShouldRetryBotRig("Failed", 30, 30),
	"Failed bot rigs must be retried when the cooldown expires"
)
assert(
	StartupReadinessPolicy.ShouldRetryBotRig("TimedOut", 60, 30),
	"Timed-out bot rigs must be eligible for a later retry"
)
assert(
	not StartupReadinessPolicy.ShouldRetryBotRig("Ready", 60, 30),
	"Ready bot rigs must never be queued for retry"
)

print("UPDATE_025_STARTUP_GUARD_TESTS_OK")
