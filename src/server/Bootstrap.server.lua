local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function getOrCreateRemote(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local servicesFolder = script.Parent:WaitForChild("Services")
local remotesFolder = getOrCreateFolder(ReplicatedStorage, "SkyfallRemotes")
local stateRemote = getOrCreateRemote(remotesFolder, "RoundState")
local targetRemote = getOrCreateRemote(remotesFolder, "TargetTile")
local speedBoostRemote = getOrCreateRemote(remotesFolder, "SpeedBoost")

local ArenaService = require(servicesFolder:WaitForChild("ArenaService"))
local RoundService = require(servicesFolder:WaitForChild("RoundService"))
local StrikeService = require(servicesFolder:WaitForChild("StrikeService"))
local SpeedBoostService = require(servicesFolder:WaitForChild("SpeedBoostService"))

local arena = ArenaService.new()
arena:Build()

local rounds = RoundService.new(arena, stateRemote)
local strikes = StrikeService.new(arena, rounds, targetRemote)
local speedBoost = SpeedBoostService.new(speedBoostRemote)

strikes:Start()
rounds:Start()
