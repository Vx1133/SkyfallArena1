-- Pure Luau regression tests for Update #19 map rotation and explicit drone opt-in.
local MapRotation = require("../../src/shared/MapRotation")
local DebugControllerPolicy = require("../../src/shared/DebugControllerPolicy")

local expected = { 1, 2, 1, 2, 1, 2 }
for roundNumber, expectedMapId in ipairs(expected) do
	assert(
		MapRotation.GetMapId(roundNumber, 2) == expectedMapId,
		`Round {roundNumber} should select map {expectedMapId}`
	)
end
assert(MapRotation.GetMapId(1, 1) == 1, "A single map installation must remain valid")
assert(MapRotation.GetMapId(0, 2) == 1, "Invalid round values must safely start from map 1")
assert(MapRotation.GetMapId(1, 0) == 1, "An empty map configuration must safely fall back to map 1")

local owner = {}
local other = {}
assert(
	DebugControllerPolicy.IsEnabled(owner, owner, true),
	"Matching identity and true toggle must enable debug takeover"
)
assert(not DebugControllerPolicy.IsEnabled(owner, owner, false), "A false toggle must reject debug takeover")
assert(not DebugControllerPolicy.IsEnabled(owner, owner, nil), "A missing toggle value must reject debug takeover")
assert(not DebugControllerPolicy.IsEnabled(owner, other, true), "A different player must not inherit debug takeover")
assert(not DebugControllerPolicy.IsEnabled(nil, owner, true), "A missing debug request must reject takeover")

print("UPDATE_019_POLICY_TESTS_OK")
