local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local STARTUP_WAIT_SECONDS = 8

local function waitForChildOrWarn(parent: Instance, name: string): Instance?
	local child = parent:WaitForChild(name, STARTUP_WAIT_SECONDS)
	if not child then
		warn(string.format("[SkyfallStartup] Audio missing %s under %s after %.1fs", name, parent:GetFullName(), STARTUP_WAIT_SECONDS))
	end
	return child
end

local playerGui = waitForChildOrWarn(player, "PlayerGui")
local sharedFolder = waitForChildOrWarn(ReplicatedStorage, "Shared")
local remotes = waitForChildOrWarn(ReplicatedStorage, "SkyfallRemotes")
if not playerGui or not sharedFolder or not remotes then
	return
end

local configModule = waitForChildOrWarn(sharedFolder, "GameConfig")
local stateRemote = waitForChildOrWarn(remotes, "RoundState")
if not configModule or not configModule:IsA("ModuleScript")
	or not stateRemote or not stateRemote:IsA("RemoteEvent")
then
	warn("[SkyfallStartup] Audio dependencies are incomplete; audio initialization stopped safely")
	return
end

local Config = require(configModule)

local function createSound(name: string, assetId: string, volume: number, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. assetId
	sound.Volume = volume
	sound.Looped = looped
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

-- This connection is optional. A late or missing HUD must not hold the audio script.
task.spawn(function()
	local hud = waitForChildOrWarn(playerGui, "SkyfallHUD")
	local playButton = hud and waitForChildOrWarn(hud, "PlayButton")
	if playButton and playButton:IsA("GuiButton") then
		playButton.Activated:Connect(function()
			playClick:Play()
		end)
	end
end)
