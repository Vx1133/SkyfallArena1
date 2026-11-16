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

print("UPDATE_024_STARTUP_GUARD_TESTS_OK")
