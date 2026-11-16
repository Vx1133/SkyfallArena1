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

return PilotOptInPolicy
