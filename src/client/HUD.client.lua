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
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "RoundStatusBar"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 6)
panel.Size = UDim2.new(0.72, 0, 0, Config.HUD_HEIGHT)
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
sizeConstraint.MinSize = Vector2.new(176, Config.HUD_HEIGHT)
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
	label.TextSize = 9
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(10, 18, 24)
	label.TextStrokeTransparency = 0.78
	label.Parent = panel
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 8
	textConstraint.MaxTextSize = 9
	textConstraint.Parent = label
	cellLabels[style.name] = label

	if index < #cellStyles then
		local divider = Instance.new("Frame")
		divider.Name = "CellDivider_" .. tostring(index)
		divider.AnchorPoint = Vector2.new(0.5, 0.5)
		divider.Position = UDim2.fromScale(index * 0.5, 0.5)
		divider.Size = UDim2.fromOffset(1, 18)
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

-- A separate safe-area ScreenGui keeps the priority indicator independent from
-- the existing full-screen controller camera and top round HUD.
local pilotGui = Instance.new("ScreenGui")
pilotGui.Name = "SkyfallPilotPriorityHUD"
pilotGui.ResetOnSpawn = false
pilotGui.IgnoreGuiInset = false
pilotGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
pilotGui.DisplayOrder = 21
pilotGui.Enabled = false
pilotGui.Parent = playerGui

local pilotPanel = Instance.new("Frame")
pilotPanel.Name = "PilotPriorityPanel"
pilotPanel.AnchorPoint = Vector2.new(0, 1)
pilotPanel.Position = UDim2.new(0, 12, 1, -8)
pilotPanel.Size = UDim2.fromOffset(108, 20)
pilotPanel.BackgroundColor3 = Color3.fromRGB(13, 25, 34)
pilotPanel.BackgroundTransparency = 0.62
pilotPanel.BorderSizePixel = 0
pilotPanel.Parent = pilotGui

local pilotCorner = Instance.new("UICorner")
pilotCorner.CornerRadius = UDim.new(0, 6)
pilotCorner.Parent = pilotPanel

local pilotLabel = Instance.new("TextLabel")
pilotLabel.Name = "PilotPriorityLabel"
pilotLabel.Position = UDim2.fromOffset(5, 0)
pilotLabel.Size = UDim2.new(1, -10, 1, 0)
pilotLabel.BackgroundTransparency = 1
pilotLabel.Font = Enum.Font.GothamBold
pilotLabel.Text = "DRONE 0%"
pilotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
pilotLabel.TextSize = 11
pilotLabel.TextXAlignment = Enum.TextXAlignment.Left
pilotLabel.TextYAlignment = Enum.TextYAlignment.Center
pilotLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
pilotLabel.TextStrokeTransparency = 0.58
pilotLabel.Parent = pilotPanel

local pilotTextConstraint = Instance.new("UITextSizeConstraint")
pilotTextConstraint.MinTextSize = 10
pilotTextConstraint.MaxTextSize = 12
pilotTextConstraint.Parent = pilotLabel

local function updatePilotPriority()
	local score = tonumber(player:GetAttribute("SkyfallPilotPriority")) or 0
	local priority = math.clamp(math.floor(score), 0, 100)
	local newText = "DRONE " .. tostring(priority) .. "%"
	if pilotLabel.Text ~= newText then
		pilotLabel.Text = newText
	end
end

local function updatePilotPriorityVisibility()
	local role = getRole()
	pilotGui.Enabled = role == "Waiting" or role == "Runner"
end

-- The cooldown meter is shown only to the human who currently controls the drone.
local cooldownPanel = Instance.new("Frame")
cooldownPanel.Name = "LaserCooldownPanel"
cooldownPanel.AnchorPoint = Vector2.new(0.5, 1)
cooldownPanel.Position = UDim2.new(0.5, 0, 1, -18)
cooldownPanel.Size = UDim2.fromOffset(214, 42)
cooldownPanel.BackgroundColor3 = Color3.fromRGB(16, 27, 39)
cooldownPanel.BackgroundTransparency = 0.24
cooldownPanel.BorderSizePixel = 0
cooldownPanel.Visible = false
cooldownPanel.Parent = screenGui

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 10)
cooldownCorner.Parent = cooldownPanel

local cooldownStroke = Instance.new("UIStroke")
cooldownStroke.Color = Color3.fromRGB(83, 179, 241)
cooldownStroke.Transparency = 0.52
cooldownStroke.Thickness = 1
cooldownStroke.Parent = cooldownPanel

local cooldownLabel = Instance.new("TextLabel")
cooldownLabel.Name = "LaserCooldownLabel"
cooldownLabel.Position = UDim2.fromOffset(8, 3)
cooldownLabel.Size = UDim2.new(1, -16, 0, 20)
cooldownLabel.BackgroundTransparency = 1
cooldownLabel.Font = Enum.Font.GothamBold
cooldownLabel.Text = "LASER READY"
cooldownLabel.TextColor3 = Color3.fromRGB(167, 245, 255)
cooldownLabel.TextSize = 10
cooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
cooldownLabel.Parent = cooldownPanel

local cooldownTrack = Instance.new("Frame")
cooldownTrack.Name = "LaserCooldownTrack"
cooldownTrack.Position = UDim2.fromOffset(8, 29)
cooldownTrack.Size = UDim2.new(1, -16, 0, 5)
cooldownTrack.BackgroundColor3 = Color3.fromRGB(39, 55, 70)
cooldownTrack.BorderSizePixel = 0
cooldownTrack.Parent = cooldownPanel

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = cooldownTrack

local cooldownFill = Instance.new("Frame")
cooldownFill.Name = "LaserCooldownFill"
cooldownFill.Size = UDim2.fromScale(1, 1)
cooldownFill.BackgroundColor3 = Color3.fromRGB(80, 218, 197)
cooldownFill.BorderSizePixel = 0
cooldownFill.Parent = cooldownTrack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = cooldownFill

local function updateLaserStatus()
	local isActiveController = state.phase == "Active" and getRole() == "Controller"
	cooldownPanel.Visible = isActiveController
	if not isActiveController then
		return
	end

	local readyAt = tonumber(player:GetAttribute("SkyfallLaserReadyAt")) or 0
	local remaining = math.max(0, readyAt - Workspace:GetServerTimeNow())
	local cooldown = Config.HUMAN_STRIKE_COOLDOWN_SECONDS
	local progress = 1 - math.clamp(remaining / cooldown, 0, 1)
	cooldownFill.Size = UDim2.fromScale(progress, 1)

	if remaining > 0.01 then
		cooldownLabel.Text = string.format("LASER RECHARGING  %.1fs", remaining)
		cooldownLabel.TextColor3 = Color3.fromRGB(128, 206, 255)
		cooldownFill.BackgroundColor3 = Color3.fromRGB(66, 151, 243)
	else
		cooldownLabel.Text = "LASER READY"
		cooldownLabel.TextColor3 = Color3.fromRGB(167, 245, 255)
		cooldownFill.BackgroundColor3 = Color3.fromRGB(80, 218, 197)
	end
end

task.spawn(function()
	while screenGui.Parent do
		updateLaserStatus()
		task.wait(0.1)
	end
end)

local function updateHud()
	local active = state.phase == "Active"
	panel.Visible = active
	updatePlayButton()
	updateLaserStatus()
	if not active then
		return
	end

	local totalPlayers = typeof(state.remainingPlayers) == "number"
		and state.remainingPlayers
		or typeof(state.aliveRunners) == "number"
		and state.aliveRunners
		or typeof(state.playerCount) == "number"
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

player:GetAttributeChangedSignal("SkyfallRole"):Connect(function()
	updateHud()
	updatePilotPriorityVisibility()
end)
player:GetAttributeChangedSignal("SkyfallReady"):Connect(updateHud)
player:GetAttributeChangedSignal("SkyfallPilotPriority"):Connect(updatePilotPriority)
player:GetAttributeChangedSignal("SkyfallLaserReadyAt"):Connect(updateLaserStatus)

updatePilotPriority()
updatePilotPriorityVisibility()

local controllerCameraActive = false
local previousFieldOfView = nil
local previousFieldOfViewMode = nil
local cachedControllerCameraHeight = nil
local cachedControllerViewport = Vector2.zero
local controllerCameraCFrame = nil
local controllerCameraInstance = nil

local function getControllerDronePosition()
	local arenaRoot = Workspace:FindFirstChild("SkyfallArena")
	local environment = arenaRoot and arenaRoot:FindFirstChild("Environment")
	local aircraftFolder = environment and environment:FindFirstChild("Aircraft")
	local drone = aircraftFolder and aircraftFolder:FindFirstChild("SkyfallLaserAircraft")
	local primaryPart = drone and (drone.PrimaryPart or drone:FindFirstChild("AircraftFuselage"))
	if primaryPart and primaryPart:IsA("BasePart") then
		return primaryPart.Position
	end
	return Config.CONTROL_CENTER
end

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

local function updateControllerCamera(deltaTime)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local shouldUseControllerCamera = getRole() == "Controller" and state.phase == "Active"
	if shouldUseControllerCamera then
		if not controllerCameraActive or controllerCameraInstance ~= camera then
			controllerCameraActive = true
			controllerCameraInstance = camera
			previousFieldOfView = camera.FieldOfView
			previousFieldOfViewMode = camera.FieldOfViewMode
			controllerCameraCFrame = nil
			cachedControllerCameraHeight = nil
			cachedControllerViewport = Vector2.zero
			setControllerDroneHidden(true)
		end

		camera.CameraType = Enum.CameraType.Scriptable
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

		-- Follow the aircraft assembly while retaining a stable overhead view of the arena.
		local dronePosition = getControllerDronePosition()
		local droneToArenaOffset = Config.ARENA_CENTER - Config.CONTROL_CENTER
		local cameraOffset = cachedControllerCameraHeight - (Config.CONTROL_CENTER.Y - Config.ARENA_CENTER.Y)
		local cameraPosition = dronePosition + Vector3.new(0, cameraOffset, 0)
		local lookPosition = dronePosition + droneToArenaOffset
		local desiredCFrame = CFrame.lookAt(
			cameraPosition,
			lookPosition,
			Vector3.new(0, 0, -1)
		)

		if not controllerCameraCFrame
			or (controllerCameraCFrame.Position - desiredCFrame.Position).Magnitude > 100
		then
			-- Avoid sweeping the camera from the hidden character's old location.
			controllerCameraCFrame = desiredCFrame
		else
			local smoothRate = math.max(Config.CONTROLLER_CAMERA_SMOOTHING, 1)
			local alpha = 1 - math.exp(-smoothRate * math.max(deltaTime, 0))
			controllerCameraCFrame = controllerCameraCFrame:Lerp(desiredCFrame, alpha)
		end
		camera.CFrame = controllerCameraCFrame
		camera.Focus = CFrame.new(dronePosition)
		return
	end

	if controllerCameraActive then
		controllerCameraActive = false
		controllerCameraInstance = nil
		setControllerDroneHidden(false)
		cachedControllerCameraHeight = nil
		cachedControllerViewport = Vector2.zero
		controllerCameraCFrame = nil
		camera.CameraType = Enum.CameraType.Custom
		if previousFieldOfViewMode then
			camera.FieldOfViewMode = previousFieldOfViewMode
			previousFieldOfViewMode = nil
		end
		if previousFieldOfView then
			camera.FieldOfView = previousFieldOfView
			previousFieldOfView = nil
		end
	end

	-- Keep the normal player camera attached to the current living character.
	-- This also repairs the camera after respawns and role changes.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		if camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

RunService:BindToRenderStep(
	"SkyfallDroneCamera",
	Enum.RenderPriority.Camera.Value + 1,
	updateControllerCamera
)

player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	task.defer(function()
		local camera = Workspace.CurrentCamera
		local controllerActive = getRole() == "Controller" and state.phase == "Active"
		if camera and not controllerActive then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end)
end)

updateHud()
