local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

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
local playRemote = getOrCreateRemote(remotesFolder, "PlayRequest")
local adminFlightRemote = getOrCreateRemote(remotesFolder, "AdminFlight")

local ArenaService = require(servicesFolder:WaitForChild("ArenaService"))
local BotService = require(servicesFolder:WaitForChild("BotService"))
local RoundService = require(servicesFolder:WaitForChild("RoundService"))
local StrikeService = require(servicesFolder:WaitForChild("StrikeService"))
local AdminFlightService = require(servicesFolder:WaitForChild("AdminFlightService"))

local arena = ArenaService.new()
arena:Build()

local bots = BotService.new(arena)
local rounds = RoundService.new(arena, stateRemote, bots, playRemote)
local laser = StrikeService.new(arena, rounds, bots, targetRemote)
local adminFlight = AdminFlightService.new(adminFlightRemote, rounds)

laser:Start()
adminFlight:Start()
rounds:Start()
