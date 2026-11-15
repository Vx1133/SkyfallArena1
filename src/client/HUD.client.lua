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
local playRemote = remotes:WaitForChild("PlayRequest")
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
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "RoundStatusBar"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 0)
panel.Size = UDim2.new(0.96, 0, 0, Config.HUD_HEIGHT)
panel.BackgroundColor3 = Color3.fromRGB(22, 35, 45)
panel.BackgroundTransparency = 0.46
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(218, 183, 113)
stroke.Transparency = 0.72
stroke.Thickness = 1
stroke.Parent = panel

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 42, 52)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 58, 65)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 39, 48)),
})
gradient.Rotation = 0
gradient.Parent = panel

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(Config.HUD_MAX_WIDTH, Config.HUD_HEIGHT)
sizeConstraint.MinSize = Vector2.new(240, Config.HUD_HEIGHT)
sizeConstraint.Parent = panel

local cellLabels = {}
local cellStyles = {
	{name = "TimeLabel", title = "ROUND", value = "03:00", color = Color3.fromRGB(255, 236, 196)},
	{name = "PlayersLabel", title = "PLAYERS", value = "11", color = Color3.fromRGB(220, 237, 245)},
}

for index, style in ipairs(cellStyles) do
	local label = Instance.new("TextLabel")
	label.Name = style.name
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromScale((index - 1) * 0.5, 0)
	label.Size = UDim2.fromScale(0.5, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = style.title .. "\n" .. style.value
	label.TextColor3 = style.color
	label.TextSize = 11
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(10, 18, 24)
	label.TextStrokeTransparency = 0.78
	label.Parent = panel
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 9
	textConstraint.MaxTextSize = 11
	textConstraint.Parent = label
	cellLabels[style.name] = label

	if index < #cellStyles then
		local divider = Instance.new("Frame")
		divider.Name = "CellDivider_" .. tostring(index)
		divider.AnchorPoint = Vector2.new(0.5, 0.5)
		divider.Position = UDim2.fromScale(index * 0.5, 0.5)
		divider.Size = UDim2.fromOffset(1, 22)
		divider.BackgroundColor3 = Color3.fromRGB(226, 214, 190)
		divider.BackgroundTransparency = 0.76
		divider.BorderSizePixel = 0
		divider.Parent = panel
	end
end

local playButton = Instance.new("TextButton")
playButton.Name = "PlayButton"
playButton.AnchorPoint = Vector2.new(0.5, 0)
playButton.Position = UDim2.new(0.5, 0, 0, 53)
playButton.Size = UDim2.fromOffset(154, 38)
playButton.BackgroundColor3 = Color3.fromRGB(56, 150, 69)
playButton.BackgroundTransparency = 0.18
playButton.BorderSizePixel = 0
playButton.Font = Enum.Font.GothamBold
playButton.Text = "PLAY"
playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playButton.TextSize = 15
playButton.AutoButtonColor = true
playButton.Visible = true
playButton.Parent = screenGui

local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 10)
playCorner.Parent = playButton

local playStroke = Instance.new("UIStroke")
playStroke.Color = Color3.fromRGB(224, 238, 208)
playStroke.Transparency = 0.58
playStroke.Thickness = 1
playStroke.Parent = playButton

local function updatePlayButton()
	local waiting = state.phase == "Waiting"
	playButton.Visible = waiting
	if player:GetAttribute("SkyfallReady") == true then
		playButton.Text = "READY"
		playButton.BackgroundColor3 = Color3.fromRGB(53, 111, 161)
	else
		playButton.Text = "PLAY"
		playButton.BackgroundColor3 = Color3.fromRGB(56, 150, 69)
	end
end

playButton.Activated:Connect(function()
	if state.phase == "Waiting" and player:GetAttribute("SkyfallReady") ~= true then
		playButton.Text = "JOINING..."
		playRemote:FireServer()
	end
end)

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
	local active = state.phase == "Active"
	panel.Visible = active
	updatePlayButton()
	if not active then
		return
	end

	local totalPlayers = typeof(state.playerCount) == "number"
		and state.playerCount
		or #Players:GetPlayers()
	local remainingSeconds = typeof(state.remainingSeconds) == "number"
		and state.remainingSeconds
		or Config.ROUND_SECONDS

	cellLabels.TimeLabel.Text = "ROUND\n" .. formatTime(remainingSeconds)
	cellLabels.PlayersLabel.Text = "PLAYERS\n" .. tostring(math.max(0, totalPlayers))
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
player:GetAttributeChangedSignal("SkyfallReady"):Connect(updateHud)

local controllerCameraActive = false
local previousFieldOfView = nil
local previousFieldOfViewMode = nil
local cachedControllerCameraHeight = nil
local cachedControllerViewport = Vector2.zero

local function setControllerDroneHidden(hidden)
	local arenaRoot = Workspace:FindFirstChild("SkyfallArena")
	local environment = arenaRoot and arenaRoot:FindFirstChild("Environment")
	local aircraftFolder = environment and environment:FindFirstChild("Aircraft")
	local drone = aircraftFolder and aircraftFolder:FindFirstChild("SkyfallLaserAircraft")
	if not drone then
		return
	end

	for _, descendant in ipairs(drone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if controllerCameraActive and descendant:IsA("BasePart") then
		local drone = descendant:FindFirstAncestor("SkyfallLaserAircraft")
		if drone then
			descendant.LocalTransparencyModifier = 1
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local shouldUseControllerCamera = getRole() == "Controller" and state.phase == "Active"
	if shouldUseControllerCamera then
		if not controllerCameraActive then
			previousFieldOfView = camera.FieldOfView
			previousFieldOfViewMode = camera.FieldOfViewMode
			setControllerDroneHidden(true)
		end

		controllerCameraActive = true
		camera.CameraType = Enum.CameraType.Scriptable

		-- True vertical overhead view. Recalculate fit only when the viewport changes.
		if camera.FieldOfViewMode ~= Enum.FieldOfViewMode.Vertical then
			camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
		end
		if camera.FieldOfView ~= Config.CONTROLLER_CAMERA_FOV then
			camera.FieldOfView = Config.CONTROLLER_CAMERA_FOV
		end
		local viewport = camera.ViewportSize
		if cachedControllerCameraHeight == nil
			or viewport.X ~= cachedControllerViewport.X
			or viewport.Y ~= cachedControllerViewport.Y
		then
			local aspect = math.max(viewport.X, 1) / math.max(viewport.Y, 1)
			local verticalHalfFov = math.rad(Config.CONTROLLER_CAMERA_FOV * 0.5)
			local horizontalHalfFov = math.atan(math.tan(verticalHalfFov) * aspect)
			local limitingHalfFov = math.min(verticalHalfFov, horizontalHalfFov)
			local halfExtent = Config.ARENA_WIDTH * 0.5 + Config.CONTROLLER_CAMERA_MARGIN
			cachedControllerCameraHeight = math.max(
				halfExtent / math.tan(limitingHalfFov),
				Config.CONTROLLER_CAMERA_MIN_HEIGHT
			)
			cachedControllerViewport = viewport
		end
		local cameraPosition = Config.ARENA_CENTER + Vector3.new(0, cachedControllerCameraHeight, 0)
		camera.CFrame = CFrame.lookAt(
			cameraPosition,
			Config.ARENA_CENTER,
			Vector3.new(0, 0, -1)
		)
		camera.Focus = CFrame.new(Config.ARENA_CENTER)
	elseif controllerCameraActive then
		controllerCameraActive = false
		setControllerDroneHidden(false)
		cachedControllerCameraHeight = nil
		cachedControllerViewport = Vector2.zero
		camera.CameraType = Enum.CameraType.Custom
		if previousFieldOfViewMode then
			camera.FieldOfViewMode = previousFieldOfViewMode
			previousFieldOfViewMode = nil
		end
		if previousFieldOfView then
			camera.FieldOfView = previousFieldOfView
			previousFieldOfView = nil
		end

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
