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
	playerCount = 0,
	remainingPlayers = 0,
	aliveRunners = 0,
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
panel.Position = UDim2.new(0.5, 0, 0, 4)
panel.Size = UDim2.new(0.96, 0, 0, Config.HUD_HEIGHT)
panel.BackgroundColor3 = Color3.fromRGB(25, 31, 34)
panel.BackgroundTransparency = 0.26
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(226, 215, 190)
stroke.Transparency = 0.72
stroke.Thickness = 1
stroke.Parent = panel

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(Config.HUD_MAX_WIDTH, Config.HUD_HEIGHT)
sizeConstraint.Parent = panel

local function makeLabel(name, position, size, initialText, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = initialText
	label.TextColor3 = color
	label.TextSize = 14
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(20, 24, 26)
	label.TextStrokeTransparency = 0.65
	label.Parent = panel

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 11
	constraint.MaxTextSize = 14
	constraint.Parent = label
	return label
end

local timeLabel = makeLabel(
	"TimeLabel",
	UDim2.new(0, 3, 0, 0),
	UDim2.new(0.34, -4, 1, 0),
	"TIME 00:00",
	Color3.fromRGB(255, 246, 222)
)

local playersLabel = makeLabel(
	"PlayersLabel",
	UDim2.new(0.34, 0, 0, 0),
	UDim2.new(0.33, 0, 1, 0),
	"PLAYERS 0",
	Color3.fromRGB(230, 239, 244)
)

local remainingLabel = makeLabel(
	"RemainingLabel",
	UDim2.new(0.67, 0, 0, 0),
	UDim2.new(0.33, -3, 1, 0),
	"LEFT 0",
	Color3.fromRGB(212, 238, 209)
)

local function formatTime(totalSeconds)
	local seconds = math.max(0, math.floor(totalSeconds or 0))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%02d:%02d", minutes, remainder)
end

local function getRole()
	return player:GetAttribute("SkyfallRole") or "Waiting"
end

local function updateHud()
	local phase = state.phase or "Waiting"
	local timeValue = state.elapsedSeconds or 0

	if phase == "Intermission" then
		timeValue = state.countdownSeconds or 0
	elseif phase == "Results" then
		timeValue = state.countdownSeconds or 0
	elseif phase == "Waiting" then
		timeValue = 0
	end

	local totalPlayers = state.playerCount
	if typeof(totalPlayers) ~= "number" then
		totalPlayers = #Players:GetPlayers()
	end

	local remainingPlayers = state.remainingPlayers
	if typeof(remainingPlayers) ~= "number" then
		remainingPlayers = state.aliveRunners or 0
	end

	timeLabel.Text = "TIME " .. formatTime(timeValue)
	playersLabel.Text = "PLAYERS " .. tostring(math.max(0, totalPlayers))
	remainingLabel.Text = "LEFT " .. tostring(math.max(0, remainingPlayers))
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

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 900, parameters)
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
		camera.FieldOfView = Config.CONTROLLER_CAMERA_FOV

		local cameraPosition = Config.ARENA_CENTER + Vector3.new(
			0,
			Config.CONTROLLER_CAMERA_HEIGHT,
			-Config.CONTROLLER_CAMERA_BACK
		)
		camera.CFrame = CFrame.lookAt(cameraPosition, Config.ARENA_CENTER)
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
