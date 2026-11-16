local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local STARTUP_WAIT_SECONDS = 8

local function waitForRequiredChild(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, STARTUP_WAIT_SECONDS)
	if not child then
		error(string.format(
			"[SkyfallStartup] Missing %s under %s after %.1f seconds",
			name,
			parent:GetFullName(),
			STARTUP_WAIT_SECONDS
		), 2)
	end
	return child
end

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function getOrCreateRemote(parent: Instance, name: string): RemoteEvent
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		remote:Destroy()
	end

	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = parent
	return created
end

local function requireService(servicesFolder: Instance, name: string): any
	local moduleScript = waitForRequiredChild(servicesFolder, name)
	if not moduleScript:IsA("ModuleScript") then
		error(string.format("[SkyfallStartup] %s is not a ModuleScript", moduleScript:GetFullName()), 2)
	end
	return require(moduleScript)
end

local function runStartupStage(name: string, callback: () -> any): any
	local startedAt = os.clock()
	print(string.format("[SkyfallStartup] BEGIN %s", name))

	local success, result = xpcall(callback, debug.traceback)
	local elapsed = os.clock() - startedAt
	if not success then
		warn(string.format("[SkyfallStartup] FAILED %s after %.2fs: %s", name, elapsed, tostring(result)))
		error(result, 0)
	end

	print(string.format("[SkyfallStartup] READY %s (%.2fs)", name, elapsed))
	return result
end

local servicesFolder = waitForRequiredChild(script.Parent, "Services")
if not servicesFolder:IsA("Folder") then
	error("[SkyfallStartup] Server Services container is not a Folder", 2)
end

local remotesFolder = getOrCreateFolder(ReplicatedStorage, "SkyfallRemotes")
local stateRemote = getOrCreateRemote(remotesFolder, "RoundState")
local targetRemote = getOrCreateRemote(remotesFolder, "TargetTile")
local playRemote = getOrCreateRemote(remotesFolder, "PlayRequest")
local adminFlightRemote = getOrCreateRemote(remotesFolder, "AdminFlight")
local bubbleShotRemote = getOrCreateRemote(remotesFolder, "BubbleShot")

local ArenaService = requireService(servicesFolder, "ArenaService")
local BotService = requireService(servicesFolder, "BotService")
local RoundService = requireService(servicesFolder, "RoundService")
local StrikeService = requireService(servicesFolder, "StrikeService")
local AdminFlightService = requireService(servicesFolder, "AdminFlightService")
local PilotPriorityService = requireService(servicesFolder, "PilotPriorityService")
local BubbleGunService = requireService(servicesFolder, "BubbleGunService")

local arena = ArenaService.new()
runStartupStage("ArenaBuild", function()
	arena:Build()
end)

-- Bot avatar generation uses a bounded background queue. It must never hold
-- server bootstrap or player character initialization while Roblox resolves assets.
local bots = BotService.new(arena)
local pilotPriority = PilotPriorityService.new()
local rounds = RoundService.new(arena, stateRemote, bots, playRemote, pilotPriority)
local laser = StrikeService.new(arena, rounds, bots, targetRemote)
local adminFlight = AdminFlightService.new(adminFlightRemote, rounds)
local bubbleGun = BubbleGunService.new(arena, rounds, bots, bubbleShotRemote)

rounds.onRunnerStarted = function(player)
	bubbleGun:GrantRunner(player)
end
rounds.onControllerStarted = function(player)
	bubbleGun:RemoveTool(player)
end
rounds.onRoundEnded = function()
	bubbleGun:ClearAll()
end

runStartupStage("StartGameServices", function()
	laser:Start()
	adminFlight:Start()
	bubbleGun:Start()
	rounds:Start()
end)
