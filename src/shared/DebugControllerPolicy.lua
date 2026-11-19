--!strict

local DebugControllerPolicy = {}

function DebugControllerPolicy.IsEnabled(
	debugControllerPlayer: unknown,
	player: unknown,
	enabledAttribute: boolean?
): boolean
	return debugControllerPlayer ~= nil
		and player ~= nil
		and debugControllerPlayer == player
		and enabledAttribute == true
end

function DebugControllerPolicy.CanUseTestOverride(isStudio: boolean): boolean
	return isStudio == true
end

return DebugControllerPolicy
