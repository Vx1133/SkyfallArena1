local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local STARTUP_WAIT_SECONDS = 8

local function waitForChildOrWarn(parent: Instance, name: string): Instance?
	local child = parent:WaitForChild(name, STARTUP_WAIT_SECONDS)
	if not child then
		warn(string.format("[SkyfallStartup] Admin flight missing %s under %s after %.1fs", name, parent:GetFullName(), STARTUP_WAIT_SECONDS))
	end
	return child
end

local playerGui = waitForChildOrWarn(player, "PlayerGui")
local remotes = waitForChildOrWarn(ReplicatedStorage, "SkyfallRemotes")
if not playerGui or not remotes then
	return
end
local flightRemote = waitForChildOrWarn(remotes, "AdminFlight")
local stateRemote = waitForChildOrWarn(remotes, "RoundState")
if not flightRemote or not flightRemote:IsA("RemoteEvent")
	or not stateRemote or not stateRemote:IsA("RemoteEvent")
then
	warn("[SkyfallStartup] Admin flight remotes are incomplete; controls disabled safely")
	return
end

local state = { phase = "Waiting" }
local verticalUp = false
local verticalDown = false
local running = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkyfallAdminFlight"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 30
screenGui.Parent = playerGui

local function makeButton(name, text, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.28
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 13
	button.AutoButtonColor = true
	button.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.72
	stroke.Thickness = 1
	stroke.Parent = button
	return button
end

local flyButton = makeButton(
	"AdminFlightToggle",
	"FLY",
	UDim2.fromOffset(10, 54),
	UDim2.fromOffset(68, 36),
	Color3.fromRGB(36, 93, 160)
)

local debugButton = makeButton(
	"DebugDroneToggle",
	"DRONE",
	UDim2.fromOffset(10, 94),
	UDim2.fromOffset(68, 36),
	Color3.fromRGB(91, 77, 54)
)
debugButton.TextSize = 10

local debugRequestPending = false
local debugRequestSerial = 0

local upButton =
	makeButton("AdminFlightUp", "UP", UDim2.new(1, -72, 0.45, 0), UDim2.fromOffset(60, 40), Color3.fromRGB(43, 137, 76))

local downButton = makeButton(
	"AdminFlightDown",
	"DOWN",
	UDim2.new(1, -72, 0.55, 0),
	UDim2.fromOffset(60, 40),
	Color3.fromRGB(161, 91, 45)
)

local function isAdmin()
	return player:GetAttribute("SkyfallIsAdmin") == true
end

local function isFlying()
	return player:GetAttribute("SkyfallFlightEnabled") == true
end

local function updateControls()
	local waiting = state.phase == "Waiting" and player:GetAttribute("SkyfallReady") ~= true
	local admin = isAdmin()
	flyButton.Visible = admin and waiting
	debugButton.Visible = admin
	local debugRequested = player:GetAttribute("SkyfallDebugDroneEnabled") == true
	debugButton.Text = debugRequestPending and "SYNC..." or (debugRequested and "TEST ON" or "DRONE")
	debugButton.Active = not debugRequestPending
	debugButton.AutoButtonColor = not debugRequestPending
	debugButton.BackgroundColor3 = debugRequested and Color3.fromRGB(157, 112, 42) or Color3.fromRGB(91, 77, 54)
	upButton.Visible = admin and waiting and isFlying()
	downButton.Visible = admin and waiting and isFlying()
	flyButton.Text = isFlying() and "STOP FLY" or "FLY"
	flyButton.BackgroundColor3 = isFlying() and Color3.fromRGB(158, 82, 43) or Color3.fromRGB(36, 93, 160)
end

debugButton.Activated:Connect(function()
	if not isAdmin() or debugRequestPending then
		return
	end

	local desiredState = player:GetAttribute("SkyfallDebugDroneEnabled") ~= true
	debugRequestPending = true
	debugRequestSerial += 1
	local requestSerial = debugRequestSerial
	updateControls()
	flightRemote:FireServer("DebugController", desiredState)

	-- A rejected or interrupted RemoteEvent must not leave the button permanently locked.
	task.delay(3, function()
		if debugRequestPending and debugRequestSerial == requestSerial then
			debugRequestPending = false
			updateControls()
		end
	end)
end)

player:GetAttributeChangedSignal("SkyfallDebugDroneEnabled"):Connect(function()
	debugRequestPending = false
	debugRequestSerial += 1
	updateControls()
end)

flyButton.Activated:Connect(function()
	if not isAdmin() or state.phase ~= "Waiting" then
		return
	end
	if isFlying() then
		flightRemote:FireServer("Disable")
	else
		flightRemote:FireServer("Enable")
	end
end)

local activeUpInput = nil
local activeDownInput = nil

upButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		activeUpInput = input
		verticalUp = true
	end
end)

downButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		activeDownInput = input
		verticalDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeUpInput then
		activeUpInput = nil
		verticalUp = false
	end
	if input == activeDownInput then
		activeDownInput = nil
		verticalDown = false
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isFlying() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		verticalUp = true
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		verticalDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		verticalUp = false
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		verticalDown = false
	end
end)

stateRemote.OnClientEvent:Connect(function(newState)
	if typeof(newState) == "table" then
		state = newState
		updateControls()
	end
end)

player:GetAttributeChangedSignal("SkyfallIsAdmin"):Connect(updateControls)
player:GetAttributeChangedSignal("SkyfallFlightEnabled"):Connect(updateControls)
player:GetAttributeChangedSignal("SkyfallRole"):Connect(updateControls)
player:GetAttributeChangedSignal("SkyfallReady"):Connect(updateControls)

task.spawn(function()
	while running do
		if isAdmin() and isFlying() and state.phase == "Waiting" then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local camera = Workspace.CurrentCamera
			if humanoid and camera then
				local direction = humanoid.MoveDirection
				local vertical = (verticalUp and 1 or 0) - (verticalDown and 1 or 0)
				direction += Vector3.new(0, vertical, 0)
				if direction.Magnitude > 1 then
					direction = direction.Unit
				end
				flightRemote:FireServer("Move", direction, camera.CFrame.LookVector)
			end
		else
			verticalUp = false
			verticalDown = false
		end
		task.wait(0.1)
	end
end)

player.CharacterAdded:Connect(function()
	verticalUp = false
	verticalDown = false
	debugRequestPending = false
	debugRequestSerial += 1
	-- Re-read the authoritative attribute for every character; never infer drone mode from Spawn.
	updateControls()
end)

updateControls()
