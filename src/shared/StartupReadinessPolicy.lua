--!strict

local StartupReadinessPolicy = {}

function StartupReadinessPolicy.CanBeginIntermission(readyBotCount: number, hasManualPilot: boolean): boolean
	return readyBotCount > 0 or hasManualPilot == true
end

return StartupReadinessPolicy
