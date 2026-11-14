local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
		hintLabel.Text = "Join the arena. A round starts when enough players are here."
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
