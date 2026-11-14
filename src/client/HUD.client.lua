local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("SkyfallRemotes")
local stateRemote = remotes:WaitForChild("RoundState")
local targetRemote = remotes:WaitForChild("TargetTile")
local speedBoostRemote = remotes:WaitForChild("SpeedBoost")
local tileFolder = Workspace:WaitForChild("SkyfallArena"):WaitForChild("Tiles")

local state = {
	phase = "Waiting",
	timeLeft = 0,
	aliveRunners = 0,
	playerCount = 0,
	winner = "",
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
panel.Position = UDim2.new(0.5, 0, 0, 14)
panel.Size = UDim2.new(1, -28, 0, 112)
panel.BackgroundColor3 = Color3.fromRGB(13, 19, 32)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(81, 111, 160)
stroke.Transparency = 0.25
stroke.Thickness = 1
stroke.Parent = panel

local function makeLabel(name, position, size, text, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel
	return label
end

makeLabel(
	"Title",
	UDim2.fromOffset(16, 8),
	UDim2.new(1, -32, 0, 28),
	"SKYFALL ARENA",
	20,
	Color3.fromRGB(232, 241, 255)
)

local statusLabel = makeLabel(
	"Status",
	UDim2.fromOffset(16, 38),
	UDim2.new(1, -32, 0, 26),
	"WAITING FOR PLAYERS",
	16,
	Color3.fromRGB(255, 205, 108)
)

local roleLabel = makeLabel(
	"Role",
	UDim2.fromOffset(16, 66),
	UDim2.new(1, -32, 0, 20),
	"ROLE: WAITING",
	13,
	Color3.fromRGB(155, 196, 255)
)

local hintLabel = makeLabel(
	"Hint",
	UDim2.fromOffset(16, 87),
	UDim2.new(1, -32, 0, 18),
	"Waiting for more players.",
	12,
	Color3.fromRGB(211, 219, 231)
)

local boostButton = Instance.new("TextButton")
boostButton.Name = "SpeedBoostButton"
boostButton.AnchorPoint = Vector2.new(1, 1)
boostButton.Position = UDim2.new(1, -24, 1, -155)
boostButton.Size = UDim2.fromOffset(92, 92)
boostButton.BackgroundColor3 = Color3.fromRGB(31, 76, 126)
boostButton.BorderSizePixel = 0
boostButton.AutoButtonColor = false
boostButton.Text = ""
boostButton.Parent = screenGui

local boostCorner = Instance.new("UICorner")
boostCorner.CornerRadius = UDim.new(0, 22)
boostCorner.Parent = boostButton

local boostStroke = Instance.new("UIStroke")
boostStroke.Color = Color3.fromRGB(105, 190, 255)
boostStroke.Thickness = 2
boostStroke.Transparency = 0.15
boostStroke.Parent = boostButton

local boostScale = Instance.new("UIScale")
boostScale.Scale = 1
boostScale.Parent = boostButton

local boostIcon = Instance.new("TextLabel")
boostIcon.Name = "AnimatedIcon"
boostIcon.AnchorPoint = Vector2.new(0.5, 0.5)
boostIcon.Position = UDim2.fromScale(0.5, 0.34)
boostIcon.Size = UDim2.fromOffset(52, 46)
boostIcon.BackgroundTransparency = 1
boostIcon.Font = Enum.Font.GothamBlack
boostIcon.Text = "⚡"
boostIcon.TextColor3 = Color3.fromRGB(255, 232, 135)
boostIcon.TextSize = 38
boostIcon.Rotation = -12
boostIcon.Parent = boostButton

local boostCaption = Instance.new("TextLabel")
boostCaption.Name = "Caption"
boostCaption.Position = UDim2.fromOffset(4, 54)
boostCaption.Size = UDim2.new(1, -8, 0, 16)
boostCaption.BackgroundTransparency = 1
boostCaption.Font = Enum.Font.GothamBold
boostCaption.Text = "SPEED"
boostCaption.TextColor3 = Color3.fromRGB(255, 255, 255)
boostCaption.TextSize = 13
boostCaption.Parent = boostButton

local boostStatus = Instance.new("TextLabel")
boostStatus.Name = "BoostStatus"
boostStatus.Position = UDim2.fromOffset(4, 70)
boostStatus.Size = UDim2.new(1, -8, 0, 14)
boostStatus.BackgroundTransparency = 1
boostStatus.Font = Enum.Font.GothamMedium
boostStatus.Text = "READY"
boostStatus.TextColor3 = Color3.fromRGB(192, 225, 255)
boostStatus.TextSize = 10
boostStatus.Parent = boostButton

local iconTween = TweenService:Create(
	boostIcon,
	TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{Rotation = 12}
)
iconTween:Play()

local pulseTween = TweenService:Create(
	boostScale,
	TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{Scale = 1.06}
)
pulseTween:Play()

local boostCooldownUntil = 0
local boostActiveUntil = 0
local boostRequestPending = false

local function updateBoostWidget()
	local now = os.clock()

	if boostRequestPending then
		boostStatus.Text = "WAIT..."
		boostButton.BackgroundColor3 = Color3.fromRGB(55, 65, 83)
	elseif boostActiveUntil > now then
		boostStatus.Text = tostring(math.ceil(boostActiveUntil - now)) .. "s LEFT"
		boostButton.BackgroundColor3 = Color3.fromRGB(23, 117, 101)
	elseif boostCooldownUntil > now then
		boostStatus.Text = tostring(math.ceil(boostCooldownUntil - now)) .. "s"
		boostButton.BackgroundColor3 = Color3.fromRGB(55, 65, 83)
	else
		boostStatus.Text = "READY"
		boostButton.BackgroundColor3 = Color3.fromRGB(31, 76, 126)
	end
end

boostButton.Activated:Connect(function()
	local now = os.clock()
	if boostRequestPending or boostActiveUntil > now or boostCooldownUntil > now then
		return
	end

	boostRequestPending = true
	updateBoostWidget()
	speedBoostRemote:FireServer()
end)

speedBoostRemote.OnClientEvent:Connect(function(result, firstValue, secondValue)
	local now = os.clock()
	boostRequestPending = false

	if result == "Activated" then
		boostActiveUntil = now + (tonumber(firstValue) or Config.SPEED_BOOST_DURATION)
		boostCooldownUntil = now + (tonumber(secondValue) or Config.SPEED_BOOST_COOLDOWN)
	elseif result == "Cooldown" then
		boostCooldownUntil = now + (tonumber(firstValue) or 0)
	elseif result == "Finished" then
		boostActiveUntil = 0
	elseif result == "Unavailable" then
		boostStatus.Text = "TRY AGAIN"
	end

	updateBoostWidget()
end)

local function getRole()
	return player:GetAttribute("SkyfallRole") or "Waiting"
end

local function updateHud()
	local seconds = math.max(0, math.floor(state.timeLeft or 0))
	local phase = state.phase or "Waiting"

	if phase == "Waiting" then
		statusLabel.Text = "WAITING FOR PLAYERS  (" .. tostring(state.playerCount or 0) .. "/" .. tostring(Config.MIN_PLAYERS) .. ")"
	elseif phase == "Intermission" then
		statusLabel.Text = "NEXT ROUND IN  " .. tostring(seconds)
	elseif phase == "Active" then
		statusLabel.Text = "ROUND  " .. tostring(state.roundNumber or 1) .. "  |  " .. tostring(seconds) .. "s  |  RUNNERS: " .. tostring(state.aliveRunners or 0)
	elseif phase == "Results" then
		statusLabel.Text = "ROUND OVER  |  " .. tostring(state.winner or "")
	else
		statusLabel.Text = string.upper(phase)
	end

	local role = getRole()
	roleLabel.Text = "ROLE: " .. string.upper(role)

	if role == "Controller" then
		hintLabel.Text = "Tap or click a floor tile to mark it for a laser strike."
	elseif role == "Runner" then
		hintLabel.Text = "Keep moving. A glowing tile is about to break."
	elseif role == "Spectator" then
		hintLabel.Text = "You are out. Watch the arena until the next round."
	else
		hintLabel.Text = "Try the speed button and the short parkour beside the lobby."
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

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
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

local usingControllerCamera = false
RunService.RenderStepped:Connect(function()
	updateBoostWidget()

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local shouldUseControllerCamera = getRole() == "Controller" and state.phase == "Active"
	if shouldUseControllerCamera then
		usingControllerCamera = true
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 58
		camera.CFrame = CFrame.lookAt(
			Vector3.new(0, 145, -45),
			Config.ARENA_CENTER
		)
	elseif usingControllerCamera then
		usingControllerCamera = false
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end)

player.CharacterAdded:Connect(function(character)
	if not usingControllerCamera then
		local camera = Workspace.CurrentCamera
		local humanoid = character:WaitForChild("Humanoid", 10)
		if camera and humanoid then
			camera.CameraSubject = humanoid
		end
	end
end)

updateHud()
updateBoostWidget()
