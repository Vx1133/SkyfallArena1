--!strict
-- Regression coverage for explicit debug identity and Studio-only test access.
local DebugControllerPolicy = require("../../src/shared/DebugControllerPolicy")
local owner = {}
local other = {}
assert(DebugControllerPolicy.IsEnabled(owner, owner, true), "Matching identity and true toggle must enable debug takeover")
assert(not DebugControllerPolicy.IsEnabled(owner, owner, false), "A false toggle must reject debug control")
assert(not DebugControllerPolicy.IsEnabled(owner, owner, nil), "A missing toggle must reject debug control")
assert(not DebugControllerPolicy.IsEnabled(owner, other, true), "Another player must not inherit debug control")
assert(not DebugControllerPolicy.IsEnabled(nil, owner, true), "A missing owner request must reject debug control")
assert(DebugControllerPolicy.CanUseTestOverride(true), "Studio must retain the manual test override")
assert(not DebugControllerPolicy.CanUseTestOverride(false), "A live game must never allow the Debug Drone override")
print("UPDATE_019_POLICY_TESTS_OK")
