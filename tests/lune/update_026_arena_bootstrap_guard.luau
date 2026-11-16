--!strict
-- Update #26: visual decoration failures must not block the playable core arena.

local ArenaStartupPolicy = require("../../src/shared/ArenaStartupPolicy")

local normal = ArenaStartupPolicy.Resolve(true, true)
assert(normal.GameplayReady, "A complete lobby and tile grid must be gameplay-ready")
assert(normal.DecorationStatus == "Ready", "Successful map decoration must report Ready")

local decorationFailure = ArenaStartupPolicy.Resolve(true, false)
assert(
	decorationFailure.GameplayReady,
	"A failed optional map builder must not block the lobby, collision tiles, or player startup"
)
assert(
	decorationFailure.DecorationStatus == "Fallback",
	"A failed optional map builder must be reported as a visual fallback"
)

local coreFailure = ArenaStartupPolicy.Resolve(false, true)
assert(
	not coreFailure.GameplayReady,
	"A missing core lobby or tile grid must never be reported as gameplay-ready"
)
assert(
	coreFailure.DecorationStatus == "Ready",
	"Decoration status must remain independent from core arena readiness"
)

local bothFail = ArenaStartupPolicy.Resolve(false, false)
assert(not bothFail.GameplayReady, "A failed core arena must remain blocked")
assert(bothFail.DecorationStatus == "Fallback", "Failed decoration must report fallback")

print("UPDATE_026_ARENA_BOOTSTRAP_GUARD_TESTS_OK")
