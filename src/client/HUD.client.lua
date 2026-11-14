local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("SkyfallRemotes")
local stateRemote = remotes:WaitForChild("RoundState")
local targetRemote = remotes:WaitForChild("TargetTile")
local tileFolder = Workspace:WaitForChild("SkyfallArena"):WaitForChild("Tiles")

local state = {
	phase = "Waiting",
	elapsedSeconds = 0,
	countdownSeconds = 0,
	aliveRunners = 0,
	winner = "",
	controllerName = "",
	controllerKind = "",
	roundNumber = 0,
	overtime = false,
	mapName = "NEXUS SKYGRID",
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkyfallHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "StatusPanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 2)
panel.Size = UDim2.new(0.94, 0, 0, Config.HUD_HEIGHT)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(Config.HUD_MAX_WIDTH, Config.HUD_HEIGHT)
sizeConstraint.Parent = panel

local function makeLabel(name, position, size, text, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(7, 12, 22)
	label.TextStrokeTransparency = 0.28
	label.Parent = panel

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = math.max(9, textSize - 1)
	constraint.MaxTextSize = textSize
	constraint.Parent = label

	return label
end

makeLabel(
	"Title",
	UDim2.fromOffset(0, 0),
	UDim2.new(1, 0, 0, 16),
	"SKYFALL ARENA",
	13,
	Color3.fromRGB(244, 248, 255),
	Enum.Font.GothamBlack
)

local statusLabel = makeLabel(
	"Status",
	UDim2.fromOffset(0, 17),
	UDim2.new(1, 0, 0, 18),
	"WAITING BAY",
	12,
	Color3.fromRGB(255, 218, 147)
)

local roleLabel = makeLabel(
	"Role",
	UDim2.fromOffset(0, 35),
	UDim2.new(1, 0, 0, 15),
	"WAITING  •  NEXUS SKYGRID",
	10,
	Color3.fromRGB(142, 220, 255)
)

local hintLabel = makeLabel(
	"Hint",
	UDim2.fromOffset(0, 50),
	UDim2.new(1, 0, 0, 16),
	"Be the last runner standing.",
	10,
	Color3.fromRGB(237, 242, 250),
	Enum.Font.GothamMedium
)

local function formatTime(totalSeconds)
	local seconds = math.max(0, math.floor(totalSeconds or 0))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

local function getRole()
	return player:GetAttribute("SkyfallRole") or "Waiting"
end

local function updateHud()
	local phase = state.phase or "Waiting"
	local role = getRole()
	local mapName = state.mapName or "SKYFALL ARENA"

	if phase == "Waiting" then
		statusLabel.Text = "WAITING BAY"
	elseif phase == "Intermission" then
		statusLabel.Text = "NEXT ROUND IN  " .. tostring(math.max(0, math.floor(state.countdownSeconds or 0)))
	elseif phase == "Active" then
		statusLabel.Text = "ROUND " .. tostring(state.roundNumber or 1)
			.. "   •   ALIVE " .. tostring(state.aliveRunners or 0)
			.. "   •   " .. formatTime(state.elapsedSeconds)
	elseif phase == "Results" then
		statusLabel.Text = "WINNER  •  " .. tostring(state.winner or "NO SURVIVORS")
			.. "   •   NEXT " .. tostring(state.countdownSeconds or 0)
	else
		statusLabel.Text = string.upper(phase)
	end

	roleLabel.Text = string.upper(role) .. "  •  " .. string.upper(mapName)

	if phase == "Active" and role == "Controller" then
		hintLabel.Text = "PILOT: TAP A FLOOR TILE TO FIRE THE LASER"
	elseif phase == "Active" and state.overtime then
		hintLabel.Text = "OVERTIME: LASER STRIKES ARE FASTER"
	elseif phase == "Active" then
		hintLabel.Text = "PILOT: " .. string.upper(state.controllerName or "LASER")
			.. "  •  MOVE FROM GLOWING TILES"
	elseif role == "Winner" then
		hintLabel.Text = "VICTORY. YOU CONTROL THE LASER NEXT ROUND."
	elseif role == "Spectator" then
		hintLabel.Text = "YOU ARE OUT. WATCH FROM THE WAITING BAY."
	elseif phase == "Intermission" then
		hintLabel.Text = "THE NEXT ROUND IS ABOUT TO BEGIN"
	else
		hintLabel.Text = "AVOID THE LASER. BE THE LAST SURVIVOR."
	end
end

local function targetAt(screenPosition)
	if getRole() ~= "Controller" or state.phase ~= "Active" then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = {tileFolder}
	parameters.IgnoreWater = true

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 600, parameters)
	if not result then
		return
	end

	local gridX = result.Instance:GetAttribute("GridX")
	local gridZ = result.Instance:GetAttribute("GridZ")
	if typeof(gridX) == "number" and typeof(gridZ) == "number" then
		targetRemote:FireServer(gridX, gridZ)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
		targetAt(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

stateRemote.OnClientEvent:Connect(function(newState)
	if typeof(newState) ~= "table" then
		return
	end

	state = newState
	updateHud()
end)

player:GetAttributeChangedSignal("SkyfallRole"):Connect(updateHud)

local controllerCameraActive = false
RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local shouldUseControllerCamera = getRole() == "Controller" and state.phase == "Active"
	if shouldUseControllerCamera then
		controllerCameraActive = true
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 76
		camera.CFrame = CFrame.lookAt(
			Vector3.new(0, 190, -55),
			Config.ARENA_CENTER
		)
	elseif controllerCameraActive then
		controllerCameraActive = false
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end)

player.CharacterAdded:Connect(function(character)
	if not controllerCameraActive then
		local humanoid = character:WaitForChild("Humanoid", 10)
		local camera = Workspace.CurrentCamera
		if camera and humanoid then
			camera.CameraSubject = humanoid
		end
	end
end)

updateHud()
