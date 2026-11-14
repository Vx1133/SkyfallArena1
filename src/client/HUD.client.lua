local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local stateRemote = ReplicatedStorage:WaitForChild("SkyfallRemotes"):WaitForChild("RoundState")

local state = {
	phase = "Waiting",
	elapsedSeconds = 0,
	aliveRunners = 0,
	botCount = Config.BOT_COUNT,
	winner = "",
	roundNumber = 0,
	overtime = false,
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
panel.Size = UDim2.new(0.94, 0, 0, Config.HUD_HEIGHT)
panel.BackgroundColor3 = Color3.fromRGB(11, 18, 32)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(Config.HUD_MAX_WIDTH, Config.HUD_HEIGHT)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(56, 159, 194)
stroke.Transparency = 0.2
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

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = math.max(9, textSize - 1)
	constraint.MaxTextSize = textSize
	constraint.Parent = label

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
	"LOBBY  •  NEXT ROUND SOON",
	12,
	Color3.fromRGB(255, 207, 115)
)

local roleLabel = makeLabel(
	"Role",
	UDim2.fromOffset(12, 42),
	UDim2.new(1, -24, 0, 15),
	"STATUS: WAITING",
	10,
	Color3.fromRGB(128, 213, 255)
)

local hintLabel = makeLabel(
	"Hint",
	UDim2.fromOffset(12, 59),
	UDim2.new(1, -24, 0, 17),
	"Red tiles are dangerous. Keep moving.",
	10,
	Color3.fromRGB(214, 224, 239)
)

local notice = Instance.new("TextLabel")
notice.Name = "TemporaryPlaytestNotice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, Config.HUD_HEIGHT + 17)
notice.Size = UDim2.new(0.86, 0, 0, 23)
notice.BackgroundColor3 = Color3.fromRGB(21, 35, 54)
notice.BackgroundTransparency = 0.08
notice.BorderSizePixel = 0
notice.Font = Enum.Font.GothamBold
notice.Text = "AUTOMATIC LASER  •  LAST SURVIVOR WINS"
notice.TextColor3 = Color3.fromRGB(196, 226, 255)
notice.TextSize = 10
notice.Parent = screenGui

local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 8)
noticeCorner.Parent = notice

local noticeConstraint = Instance.new("UISizeConstraint")
noticeConstraint.MaxSize = Vector2.new(320, 23)
noticeConstraint.Parent = notice

task.delay(7, function()
	if not notice.Parent then
		return
	end

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
	if notice.Parent then
		notice:Destroy()
	end
end)

local function formatTime(totalSeconds)
	local seconds = math.max(0, math.floor(totalSeconds or 0))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

local function updateHud()
	local phase = state.phase or "Waiting"
	local role = player:GetAttribute("SkyfallRole") or "Waiting"

	if phase == "Waiting" then
		statusLabel.Text = "LOBBY  •  NEXT ROUND SOON"
	elseif phase == "Intermission" then
		statusLabel.Text = "ROUND STARTS IN  " .. tostring(math.max(0, math.floor(state.countdownSeconds or 0)))
	elseif phase == "Active" then
		statusLabel.Text = "ROUND " .. tostring(state.roundNumber or 1)
			.. "  •  ALIVE " .. tostring(state.aliveRunners or 0)
			.. "  •  " .. formatTime(state.elapsedSeconds)
	elseif phase == "Results" then
		statusLabel.Text = "WINNER  •  " .. tostring(state.winner or "NO SURVIVORS")
			.. "  •  NEXT IN " .. tostring(state.countdownSeconds or 0)
	else
		statusLabel.Text = string.upper(phase)
	end

	roleLabel.Text = "STATUS: " .. string.upper(role)

	if phase == "Active" and state.overtime then
		hintLabel.Text = "OVERTIME: the laser is attacking faster!"
	elseif phase == "Active" then
		hintLabel.Text = "Watch glowing tiles. Move before the laser hits."
	elseif role == "Winner" then
		hintLabel.Text = "Victory! The next round will start soon."
	elseif role == "Spectator" then
		hintLabel.Text = "You are out. Watch until the next round."
	elseif phase == "Intermission" then
		hintLabel.Text = "All contestants are waiting in the lobby."
	else
		hintLabel.Text = "Avoid the laser. Be the last one standing."
	end
end

stateRemote.OnClientEvent:Connect(function(newState)
	if typeof(newState) ~= "table" then
		return
	end

	state = newState
	updateHud()
end)

player:GetAttributeChangedSignal("SkyfallRole"):Connect(updateHud)
updateHud()
