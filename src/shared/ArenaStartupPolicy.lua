--!strict

local ArenaStartupPolicy = {}

export type Readiness = {
	GameplayReady: boolean,
	DecorationStatus: string,
}

-- The lobby and destructible tile grid are required for gameplay. Decoration
-- is optional so a visual asset error cannot prevent player startup.
function ArenaStartupPolicy.Resolve(coreArenaReady: boolean, mapDecorationSucceeded: boolean): Readiness
	return {
		GameplayReady = coreArenaReady == true,
		DecorationStatus = mapDecorationSucceeded == true and "Ready" or "Fallback",
	}
end

return ArenaStartupPolicy
