--!strict
-- Regression tests for manual aircraft opt-in and independent bot control.

local PilotOptInPolicy = require("../../src/shared/PilotOptInPolicy")

local mainPlayer = { name = "OnlyHuman", optedIn = false }
local bots = {}
for index = 1, 10 do
    table.insert(bots, { name = "Bot" .. tostring(index), valid = true })
end

local kind, candidates = PilotOptInPolicy.ResolveCandidates(
    { mainPlayer },
    bots,
    function(player)
        return player.optedIn == true
    end,
    function(bot)
        return bot.valid == true
    end
)

assert(kind == "Bot", "A single non-opted-in human must not be forced into aircraft control")
assert(#candidates == 10, "All ten valid bots must remain independent controller candidates")
for index, bot in ipairs(bots) do
    assert(candidates[index] == bot, "Bot candidate ordering must remain stable")
end

mainPlayer.optedIn = true
kind, candidates = PilotOptInPolicy.ResolveCandidates(
    { mainPlayer },
    bots,
    function(player)
        return player.optedIn == true
    end,
    function(bot)
        return bot.valid == true
    end
)
assert(kind == "Player", "A human must enter aircraft control only after explicit opt-in")
assert(#candidates == 1 and candidates[1] == mainPlayer, "Only explicitly opted-in humans may be selected")

mainPlayer.optedIn = false
for _, bot in ipairs(bots) do
    bot.valid = false
end
kind, candidates = PilotOptInPolicy.ResolveCandidates(
    { mainPlayer },
    bots,
    function(player)
        return player.optedIn == true
    end,
    function(bot)
        return bot.valid == true
    end
)
assert(kind == nil and #candidates == 0, "No valid bot and no manual opt-in must fail safely, never select a human")

local strictKinds, strictCandidates = PilotOptInPolicy.ResolveCandidates(
    { { optedIn = 1 }, { optedIn = true } },
    {},
    function(player)
        return player.optedIn == true
    end,
    function()
        return false
    end
)
assert(strictKinds == "Player", "Opt-in must require a strict true boolean")
assert(#strictCandidates == 1 and strictCandidates[1].optedIn == true, "Truth-like numbers must not opt in")

print("UPDATE_023_CONTROL_STATE_TESTS_OK")
