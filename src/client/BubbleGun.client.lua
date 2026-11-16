local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local STARTUP_WAIT_SECONDS = 8

local function waitForChildOrWarn(parent: Instance, name: string): Instance?
	local child = parent:WaitForChild(name, STARTUP_WAIT_SECONDS)
	if not child then
		warn(string.format("[SkyfallStartup] Bubble client missing %s under %s after %.1fs", name, parent:GetFullName(), STARTUP_WAIT_SECONDS))
	end
	return child
end

local remotes = waitForChildOrWarn(ReplicatedStorage, "SkyfallRemotes")
local sharedFolder = waitForChildOrWarn(ReplicatedStorage, "Shared")
local playerGui = waitForChildOrWarn(player, "PlayerGui")
local backpack = waitForChildOrWarn(player, "Backpack")
if not remotes or not sharedFolder or not playerGui or not backpack then
	return
end

local remote = waitForChildOrWarn(remotes, "BubbleShot")
local configModule = waitForChildOrWarn(sharedFolder, "GameConfig")
if not remote or not remote:IsA("RemoteEvent")
	or not configModule or not configModule:IsA("ModuleScript")
then
	warn("[SkyfallStartup] Bubble client dependencies are incomplete; tool input disabled safely")
	return
end
local Config = require(configModule)
local reticleGui = Instance.new("ScreenGui")
reticleGui.Name = "SkyfallBubbleReticle"
reticleGui.ResetOnSpawn = false
reticleGui.IgnoreGuiInset = true
reticleGui.DisplayOrder = 25
reticleGui.Enabled = false
reticleGui.Parent = playerGui

local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(18, 18)
reticle.BackgroundTransparency = 1
reticle.BorderSizePixel = 0
reticle.Parent = reticleGui

local reticleCorner = Instance.new("UICorner")
reticleCorner.CornerRadius = UDim.new(1, 0)
reticleCorner.Parent = reticle

local reticleStroke = Instance.new("UIStroke")
reticleStroke.Color = Color3.fromRGB(225, 255, 250)
reticleStroke.Thickness = 1.5
reticleStroke.Transparency = 0.12
reticleStroke.Parent = reticle

local centerDot = Instance.new("Frame")
centerDot.Name = "CenterDot"
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.fromScale(0.5, 0.5)
centerDot.Size = UDim2.fromOffset(3, 3)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
centerDot.BorderSizePixel = 0
centerDot.Parent = reticle

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = centerDot

local boundTools = {}
local equippedTool = nil

local function setEquipped(tool, enabled)
	if enabled then
		equippedTool = tool
		reticleGui.Enabled = true
	elseif equippedTool == tool then
		equippedTool = nil
		reticleGui.Enabled = false
	end
end

local function bindTool(instance)
	if not instance:IsA("Tool")
		or instance.Name ~= Config.BUBBLE_GUN_TOOL_NAME
		or boundTools[instance]
	then
		return
	end
	boundTools[instance] = true

	instance.Equipped:Connect(function()
		setEquipped(instance, true)
	end)
	instance.Unequipped:Connect(function()
		setEquipped(instance, false)
	end)
	instance.Activated:Connect(function()
		if equippedTool ~= instance or instance.Parent ~= player.Character then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			remote:FireServer(camera.CFrame.LookVector)
		end
	end)
	instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			setEquipped(instance, false)
			boundTools[instance] = nil
		end
	end)
end

-- Backpack was resolved through the bounded startup dependency check above.
for _, child in ipairs(backpack:GetChildren()) do
	bindTool(child)
end
backpack.ChildAdded:Connect(bindTool)

local function bindCharacter(character)
	for _, child in ipairs(character:GetChildren()) do
		bindTool(child)
	end
	character.ChildAdded:Connect(bindTool)
end

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
