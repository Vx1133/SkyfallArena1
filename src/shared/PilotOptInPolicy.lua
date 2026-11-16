--!strict

local PilotOptInPolicy = {}

function PilotOptInPolicy.Filter(candidates: {any}, isOptedIn: (any) -> boolean): {any}
	local selected = {}
	for _, candidate in ipairs(candidates) do
		if isOptedIn(candidate) == true then
			table.insert(selected, candidate)
		end
	end
	return selected
end

-- Resolve one controller source without ever treating a solo human as an
-- implicit aircraft opt-in. Humans must pass the explicit opt-in predicate;
-- otherwise only valid bot candidates are returned.
function PilotOptInPolicy.ResolveCandidates(
	readyPlayers: {any},
	bots: {any},
	isOptedIn: (any) -> boolean,
	isBotValid: (any) -> boolean
): (string?, {any})
	local optedInPlayers = PilotOptInPolicy.Filter(readyPlayers, isOptedIn)
	if #optedInPlayers > 0 then
		return "Player", optedInPlayers
	end

	local validBots = {}
	for _, bot in ipairs(bots) do
		if isBotValid(bot) == true then
			table.insert(validBots, bot)
		end
	end

	if #validBots > 0 then
		return "Bot", validBots
	end

	return nil, {}
end

return PilotOptInPolicy
