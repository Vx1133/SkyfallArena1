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
local tileFolder = Workspace:WaitForChild("SkyfallArena"):WaitForChild("Tiles")

local state = {
	phase = "Waiting",
	timeLeft = 0,
	aliveRunners = 0,
	playerCount = 0,
	botCount = Config.BOT_COUNT,
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
panel.Position = UDim2.new(0.5, 0, 0, 8)
panel.Size = UDim2.new(0.94, 0, 0, 84)
panel.BackgroundColor3 = Color3.fromRGB(13, 19, 32)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(460, 84)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
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
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = panel

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = math.max(9, textSize - 1)
	textConstraint.MaxTextSize = textSize
	textConstraint.Parent = label

	return label
end

makeLabel(
	"Title",
	UDim2.fromOffset(12, 4),
	UDim2.new(1, -24, 0, 17),
	"SKYFALL ARENA",
	14,
	Color3.fromRGB(232, 241, 255)
)

local statusLabel = makeLabel(
	"Status",
	UDim2.fromOffset(12, 22),
	UDim2.new(1, -24, 0, 18),
	"WAITING FOR PLAYERS",
	12,
	Color3.fromRGB(255, 205, 108)
)

local roleLabel = makeLabel(
	"Role",
	UDim2.fromOffset(12, 42),
	UDim2.new(1, -24, 0, 15),
	"ROLE: WAITING",
	10,
	Color3.fromRGB(155, 196, 255)
)

local hintLabel = makeLabel(
	"Hint",
	UDim2.fromOffset(12, 59),
	UDim2.new(1, -24, 0, 17),
	"Waiting for a round to begin.",
	10,
	Color3.fromRGB(211, 219, 231)
)

local notice = Instance.new("TextLabel")
notice.Name = "TemporaryPlaytestNotice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 99)
notice.Size = UDim2.new(0.8, 0, 0, 23)
notice.BackgroundColor3 = Color3.fromRGB(21, 35, 54)
notice.BackgroundTransparency = 0.08
notice.BorderSizePixel = 0
notice.Font = Enum.Font.GothamBold
notice.Text = "PLAYTEST BUILD  •  3 AI RUNNERS"
notice.TextColor3 = Color3.fromRGB(196, 222, 255)
notice.TextSize = 10
notice.Parent = screenGui

local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 8)
noticeCorner.Parent = notice

local noticeConstraint = Instance.new("UISizeConstraint")
noticeConstraint.MaxSize = Vector2.new(300, 23)
noticeConstraint.Parent = notice

task.delay(7, function()
	if notice.Parent then
		local fade = TweenService:Create(
			notice,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}
		)
		fade:Play()
		fade.Completed:Wait()
		notice:Destroy()
	end
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
		statusLabel.Text = "ROUND " .. tostring(state.roundNumber or 1) .. "  |  " .. tostring(seconds) .. "s  |  RUNNERS: " .. tostring(state.aliveRunners or 0)
	elseif phase == "Results" then
		statusLabel.Text = "ROUND OVER  |  " .. tostring(state.winner or "")
	else
		statusLabel.Text = string.upper(phase)
	end

	local role = getRole()
	roleLabel.Text = "ROLE: " .. string.upper(role)

	if role == "Controller" then
		hintLabel.Text = "Tap a floor tile to aim a laser strike."
	elseif role == "Runner" then
		hintLabel.Text = "Keep moving. Escape glowing tiles."
	elseif role == "Spectator" then
		hintLabel.Text = "Watch the arena until the next round."
	else
		hintLabel.Text = "Round starts when you are ready."
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
