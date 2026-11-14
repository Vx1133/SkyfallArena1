local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local BotService = {}
BotService.__index = BotService

local BOT_PROFILES = {
	{
		name = "Atlas",
		walkSpeed = 15,
		jumpPower = 48,
		reactionDelay = 0.7,
		caution = 6,
		preferredDistance = 24,
	},
	{
		name = "Nova",
		walkSpeed = 17,
		jumpPower = 54,
		reactionDelay = 0.4,
		caution = 3,
		preferredDistance = 31,
	},
	{
		name = "Rook",
		walkSpeed = 16,
		jumpPower = 51,
		reactionDelay = 0.55,
		caution = 4.5,
		preferredDistance = 28,
	},
}

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

function BotService.new(arenaService)
	local self = setmetatable({}, BotService)
	self.arena = arenaService
	self.folder = getOrCreateFolder(Workspace, "SkyfallBots")
	self.bots = {}
	self.random = Random.new()

	for _, profile in ipairs(BOT_PROFILES) do
		local bot = {
			name = profile.name,
			walkSpeed = profile.walkSpeed,
			jumpPower = profile.jumpPower,
			reactionDelay = profile.reactionDelay,
			caution = profile.caution,
			preferredDistance = profile.preferredDistance,
			alive = false,
			targetTile = nil,
			lastTarget = nil,
		}
		self:_buildRig(bot)
		table.insert(self.bots, bot)
		task.spawn(function()
			self:_runBot(bot)
		end)
	end

	self:SendToLobby()
	return self
end

function BotService:_buildRig(bot)
	if bot.model then
		bot.model:Destroy()
	end

	local description = Instance.new("HumanoidDescription")
	local success, modelOrError = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R15
		)
	end)
	description:Destroy()

	if not success then
		error("Could not create AI bot " .. bot.name .. ": " .. tostring(modelOrError))
	end

	local model = modelOrError
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		error("AI bot rig is missing its Humanoid or HumanoidRootPart: " .. bot.name)
	end

	model.Name = "SkyfallBot_" .. bot.name
	model:SetAttribute("IsSkyfallBot", true)
	model:SetAttribute("SkyfallRole", "Waiting")
	model.PrimaryPart = root
	humanoid.DisplayName = bot.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = bot.jumpPower
	model.Parent = self.folder

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "BotNameplate"
	nameplate.Size = UDim2.fromOffset(110, 24)
	nameplate.StudsOffset = Vector3.new(0, 3.2, 0)
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 90
	nameplate.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = bot.name .. "  •  AI"
	nameLabel.TextColor3 = Color3.fromRGB(215, 235, 255)
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.TextScaled = true
	nameLabel.Parent = nameplate

	bot.model = model
	bot.humanoid = humanoid
	bot.root = root

	humanoid.Died:Connect(function()
		bot.alive = false
		bot.targetTile = nil
		model:SetAttribute("SkyfallRole", "Spectator")
	end)
end

function BotService:GetBotCount()
	return #self.bots
end

function BotService:GetAliveBots()
	local aliveBots = {}
	for _, bot in ipairs(self.bots) do
		if bot.alive
			and bot.model
			and bot.model.Parent
			and bot.humanoid
			and bot.humanoid.Health > 0
		then
			table.insert(aliveBots, bot)
		end
	end
	return aliveBots
end

function BotService:GetAliveCount()
	return #self:GetAliveBots()
end

function BotService:GetAlivePositions()
	local positions = {}
	for _, bot in ipairs(self:GetAliveBots()) do
		if bot.root and bot.root.Parent then
			table.insert(positions, bot.root.Position)
		end
	end
	return positions
end

function BotService:_nearestTile(position)
	local nearest = nil
	local nearestDistance = math.huge

	for gridX = 1, Config.GRID_SIZE do
		for gridZ = 1, Config.GRID_SIZE do
			local tile = self.arena:GetTile(gridX, gridZ)
			if tile then
				local delta = Vector2.new(tile.Position.X - position.X, tile.Position.Z - position.Z)
				local distance = delta.Magnitude
				if distance < nearestDistance then
					nearest = tile
					nearestDistance = distance
				end
			end
		end
	end

	return nearest
end

function BotService:_isSafeTile(tile)
	return tile
		and tile.Parent
		and tile.CanCollide
		and not tile:GetAttribute("IsBroken")
		and not tile:GetAttribute("IsWarning")
end

function BotService:_warningDistance(gridX, gridZ)
	local nearestDistance = Config.GRID_SIZE * 2

	for x = 1, Config.GRID_SIZE do
		for z = 1, Config.GRID_SIZE do
			local tile = self.arena:GetTile(x, z)
			if tile and tile:GetAttribute("IsWarning") then
				local distance = math.abs(gridX - x) + math.abs(gridZ - z)
				nearestDistance = math.min(nearestDistance, distance)
			end
		end
	end

	return nearestDistance
end

function BotService:_isInDanger(bot)
	local currentTile = bot.root and self:_nearestTile(bot.root.Position)
	if not currentTile then
		return true
	end

	if currentTile:GetAttribute("IsWarning") or currentTile:GetAttribute("IsBroken") then
		return true
	end

	return false
end

function BotService:_chooseSafeTile(bot)
	local root = bot.root
	if not root then
		return nil
	end

	local currentTile = self:_nearestTile(root.Position)
	local bestTile = nil
	local bestScore = -math.huge

	for gridX = 1, Config.GRID_SIZE do
		for gridZ = 1, Config.GRID_SIZE do
			local tile = self.arena:GetTile(gridX, gridZ)
			if self:_isSafeTile(tile) then
				local distance = (tile.Position - root.Position).Magnitude
				local warningDistance = self:_warningDistance(gridX, gridZ)
				local edgeDistance = math.min(
					gridX - 1,
					gridZ - 1,
					Config.GRID_SIZE - gridX,
					Config.GRID_SIZE - gridZ
				)

				local score = math.min(warningDistance, 5) * bot.caution
				score -= math.abs(distance - bot.preferredDistance) * 0.35
				score += math.min(edgeDistance, 3) * 1.5
				score += self.random:NextNumber(0, 2)

				if tile == currentTile then
					score -= 18
				end
				if tile == bot.lastTarget then
					score -= 10
				end
				if distance > 105 then
					score -= 30
				end

				if score > bestScore then
					bestScore = score
					bestTile = tile
				end
			end
		end
	end

	return bestTile
end

function BotService:_followPath(bot, targetTile)
	if not bot.alive or not self:_isSafeTile(targetTile) then
		return
	end

	local root = bot.root
	local humanoid = bot.humanoid
	local destination = targetTile.Position + Vector3.new(0, 3, 0)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 5,
	})

	local computed = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)

	if not computed or path.Status ~= Enum.PathStatus.Success then
		humanoid.Jump = true
		humanoid:MoveTo(destination)
		task.wait(bot.reactionDelay)
		return
	end

	local startedInDanger = self:_isInDanger(bot)
	local currentWaypointIndex = 1
	local pathBlocked = false
	local blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
		if blockedWaypointIndex >= currentWaypointIndex then
			pathBlocked = true
		end
	end)

	for waypointIndex, waypoint in ipairs(path:GetWaypoints()) do
		currentWaypointIndex = waypointIndex
		if pathBlocked or not bot.alive or not self:_isSafeTile(targetTile) then
			break
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		humanoid:MoveTo(waypoint.Position)
		local startedAt = os.clock()
		local shouldAbort = false
		while bot.alive and (root.Position - waypoint.Position).Magnitude > 3.5 do
			if pathBlocked or (not startedInDanger and self:_isInDanger(bot)) then
				shouldAbort = true
				break
			end
			if not self:_isSafeTile(targetTile) then
				break
			end
			if os.clock() - startedAt > 2 then
				break
			end
			task.wait(0.1)
		end

		if pathBlocked or shouldAbort or not self:_isSafeTile(targetTile) then
			break
		end
	end

	blockedConnection:Disconnect()
end

function BotService:_runBot(bot)
	while true do
		if bot.alive
			and bot.model
			and bot.model.Parent
			and bot.humanoid
			and bot.humanoid.Parent
			and bot.humanoid.Health > 0
			and bot.root
			and bot.root.Parent
		then
			if not bot.targetTile
				or not self:_isSafeTile(bot.targetTile)
				or self:_isInDanger(bot)
				or (bot.root.Position - bot.targetTile.Position).Magnitude < 7
			then
				bot.targetTile = self:_chooseSafeTile(bot)
			end

			if bot.targetTile then
				bot.lastTarget = bot.targetTile
				self:_followPath(bot, bot.targetTile)
			end
		end

		task.wait(bot.reactionDelay)
	end
end

function BotService:StartRound(spawnCFrames)
	for index, bot in ipairs(self.bots) do
		if not bot.humanoid or bot.humanoid.Health <= 0 or not bot.model.Parent then
			self:_buildRig(bot)
		end

		local spawnCFrame = spawnCFrames[index]
		if spawnCFrame then
			bot.alive = true
			bot.targetTile = nil
			bot.lastTarget = nil
			bot.humanoid.Health = bot.humanoid.MaxHealth
			bot.humanoid.WalkSpeed = bot.walkSpeed
			bot.humanoid.JumpPower = bot.jumpPower
			bot.model:SetAttribute("SkyfallRole", "Runner")
			bot.model:PivotTo(spawnCFrame)
			bot.root.AssemblyLinearVelocity = Vector3.zero
			bot.root.AssemblyAngularVelocity = Vector3.zero
			pcall(function()
				bot.root:SetNetworkOwner(nil)
			end)
		end
	end
end

function BotService:EliminateFallenRunners(outOfBoundsY)
	for index, bot in ipairs(self.bots) do
		if bot.alive
			and (
				not bot.root
				or not bot.root.Parent
				or not bot.humanoid
				or bot.humanoid.Health <= 0
				or bot.root.Position.Y < outOfBoundsY
			)
		then
			bot.alive = false
			bot.targetTile = nil
			if bot.model and bot.model.Parent then
				bot.model:SetAttribute("SkyfallRole", "Spectator")
				bot.humanoid.WalkSpeed = 0
				local lobbySpawn = self.arena:GetLobbySpawnCFrame(index, #self.bots)
				bot.model:PivotTo(lobbySpawn)
				bot.root.AssemblyLinearVelocity = Vector3.zero
				bot.root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end

function BotService:SendToLobby()
	for index, bot in ipairs(self.bots) do
		bot.alive = false
		bot.targetTile = nil

		if not bot.humanoid or bot.humanoid.Health <= 0 or not bot.model or not bot.model.Parent then
			self:_buildRig(bot)
		end

		if bot.model and bot.model.Parent then
			bot.model:SetAttribute("SkyfallRole", "Waiting")
			bot.humanoid.WalkSpeed = 0
			bot.humanoid.JumpPower = 0
			bot.humanoid:MoveTo(bot.root.Position)

			bot.model:PivotTo(self.arena:GetLobbySpawnCFrame(index, #self.bots))
			bot.root.AssemblyLinearVelocity = Vector3.zero
			bot.root.AssemblyAngularVelocity = Vector3.zero
			pcall(function()
				bot.root:SetNetworkOwner(nil)
			end)
		end
	end
end

return BotService
