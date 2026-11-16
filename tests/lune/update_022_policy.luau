--!strict
-- Pure Luau regression tests for Update #22 explicit pilot selection.
local PilotOptInPolicy = require("../../src/shared/PilotOptInPolicy")

local first = { name = "first", optedIn = false }
local second = { name = "second", optedIn = true }
local third = { name = "third", optedIn = false }
local fourth = { name = "fourth", optedIn = true }

local selected = PilotOptInPolicy.Filter({ first, second, third, fourth }, function(candidate)
	return candidate.optedIn == true
end)

assert(#selected == 2, "Only explicitly opted-in players may be controller candidates")
assert(selected[1] == second and selected[2] == fourth, "Pilot opt-in filtering must preserve eligible player order")

local noneSelected = PilotOptInPolicy.Filter({ first, third }, function(candidate)
	return candidate.optedIn == true
end)
assert(#noneSelected == 0, "No human controller should be selected without explicit opt-in")

local strictBoolean = PilotOptInPolicy.Filter({ { optedIn = 1 }, { optedIn = true } }, function(candidate)
	return candidate.optedIn == true
end)
assert(#strictBoolean == 1 and strictBoolean[1].optedIn == true, "Pilot opt-in must require an explicit true boolean")

print("UPDATE_022_PILOT_OPT_IN_TESTS_OK")
