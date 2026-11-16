--!strict

local StartupReadinessPolicy = {}

function StartupReadinessPolicy.CanBeginIntermission(readyBotCount: number, hasManualPilot: boolean): boolean
	return readyBotCount > 0 or hasManualPilot == true
end

function StartupReadinessPolicy.CanStartPlay(gameReady: boolean, characterReady: boolean, phase: string, playerReady: boolean): boolean
	return gameReady == true and characterReady == true and phase == "Waiting" and playerReady ~= true
end

function StartupReadinessPolicy.ShouldRetryBotRig(state: string, elapsedSeconds: number, retrySeconds: number): boolean
	return (state == "TimedOut" or state == "Failed")
		and elapsedSeconds >= math.max(0, retrySeconds)
end

return StartupReadinessPolicy
