local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SkyfallRemotes")
local flightRemote = remotes:WaitForChild("AdminFlight")
local stateRemote = remotes:WaitForChild("RoundState")

local state = {phase = "Waiting"}
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
	UDim2.new(0, 10, 0, 54),
	UDim2.fromOffset(68, 36),
	Color3.fromRGB(36, 93, 160)
)

local upButton = makeButton(
	"AdminFlightUp",
	"UP",
	UDim2.new(1, -72, 0.45, 0),
	UDim2.fromOffset(60, 40),
	Color3.fromRGB(43, 137, 76)
)

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
	local waiting = state.phase == "Waiting"
	local admin = isAdmin()
	flyButton.Visible = admin and waiting
	upButton.Visible = admin and waiting and isFlying()
	downButton.Visible = admin and waiting and isFlying()
	flyButton.Text = isFlying() and "STOP FLY" or "FLY"
	flyButton.BackgroundColor3 = isFlying()
		and Color3.fromRGB(158, 82, 43)
		or Color3.fromRGB(36, 93, 160)
end

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
	updateControls()
end)

updateControls()
