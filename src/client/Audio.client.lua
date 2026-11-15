local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("SkyfallRemotes")
local stateRemote = remotes:WaitForChild("RoundState")

local function createSound(name, assetId, volume, looped)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. assetId
	sound.Volume = volume
	sound.Looped = looped or false
	sound.Parent = SoundService
	return sound
end

local music = createSound("SkyfallBackgroundMusic", Config.BACKGROUND_MUSIC_ID, Config.AUDIO_MUSIC_VOLUME, true)
music:Play()

local roundStart = createSound("SkyfallRoundStart", Config.ROUND_START_SOUND_ID, Config.AUDIO_UI_VOLUME, false)
local playClick = createSound("SkyfallPlayClick", Config.ROUND_START_SOUND_ID, Config.AUDIO_UI_VOLUME * 0.65, false)

local lastPhase = "Waiting"
stateRemote.OnClientEvent:Connect(function(newState)
	if typeof(newState) ~= "table" then
		return
	end
	if newState.phase == "Active" and lastPhase ~= "Active" then
		roundStart:Play()
	end
	lastPhase = newState.phase or lastPhase
end)

local hud = playerGui:WaitForChild("SkyfallHUD")
local playButton = hud:WaitForChild("PlayButton")
playButton.Activated:Connect(function()
	playClick:Play()
end)
