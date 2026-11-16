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

return DebugControllerPolicy
