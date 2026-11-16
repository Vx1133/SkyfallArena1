--!strict

local MapRotation = {}

function MapRotation.GetMapId(roundNumber: number, mapCount: number): number
	local safeRound = if roundNumber == roundNumber
			and roundNumber ~= math.huge
			and roundNumber ~= -math.huge
		then math.max(1, math.floor(roundNumber))
		else 1
	local safeMapCount = if mapCount == mapCount
			and mapCount ~= math.huge
			and mapCount ~= -math.huge
		then math.max(1, math.floor(mapCount))
		else 1

	return ((safeRound - 1) % safeMapCount) + 1
end

return MapRotation
