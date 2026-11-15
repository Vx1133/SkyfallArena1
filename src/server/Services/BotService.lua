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
		bodyColor = Color3.fromRGB(84, 166, 255),
		walkSpeed = 15,
		jumpPower = 48,
		reactionDelay = 0.7,
		caution = 6,
		preferredDistance = 24,
		animations = {
			idle = 910004836,
			walk = 910034870,
			run = 910025107,
			jump = 910016857,
			fall = 910001910,
		},
	},
	{
		name = "Nova",
		bodyColor = Color3.fromRGB(67, 224, 192),
		walkSpeed = 17,
		jumpPower = 54,
		reactionDelay = 0.4,
		caution = 3,
		preferredDistance = 31,
		animations = {
			idle = 656117400,
			walk = 656121766,
			run = 656118852,
			jump = 656117878,
			fall = 656115606,
		},
	},
	{
		name = "Rook",
		bodyColor = Color3.fromRGB(255, 172, 84),
		walkSpeed = 16,
		jumpPower = 51,
		reactionDelay = 0.55,
		caution = 4.5,
		preferredDistance = 28,
		animations = {
			idle = 742637544,
			walk = 742640026,
			run = 742638842,
			jump = 742637942,
			fall = 742637151,
		},
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

	for botIndex = 1, Config.BOT_COUNT do
		local profile = BOT_PROFILES[((botIndex - 1) % #BOT_PROFILES) + 1]
		local bot = {
			name = botIndex <= #BOT_PROFILES
				and profile.name
				or profile.name .. " " .. string.format("%02d", botIndex),
			bodyColor = profile.bodyColor,
			walkSpeed = profile.walkSpeed,
			jumpPower = profile.jumpPower,
			reactionDelay = profile.reactionDelay,
			caution = profile.caution,
			preferredDistance = profile.preferredDistance,
			animations = profile.animations,
			tracks = {},
			currentAnimation = nil,
			alive = false,
			isController = false,
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

function BotService:_playAnimation(bot, action, fadeTime)
	local track = bot.tracks[action]
	if not track then
		return
	end
	if bot.currentAnimation == action and track.IsPlaying then
		return
	end

	for name, otherTrack in pairs(bot.tracks) do
		if name ~= action and otherTrack.IsPlaying then
			otherTrack:Stop(fadeTime or 0.18)
		end
	end

	bot.currentAnimation = action
	if not track.IsPlaying then
		track:Play(fadeTime or 0.18)
	end
end

function BotService:_loadAnimations(bot, model, humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	bot.tracks = {}
	bot.currentAnimation = nil

	local actions = {
		{"idle", Enum.AnimationPriority.Idle, true},
		{"walk", Enum.AnimationPriority.Movement, true},
		{"run", Enum.AnimationPriority.Movement, true},
		{"jump", Enum.AnimationPriority.Action, false},
		{"fall", Enum.AnimationPriority.Action, true},
	}

	for _, item in ipairs(actions) do
		local action = item[1]
		local animation = Instance.new("Animation")
		animation.Name = bot.name .. "_" .. action
		animation.AnimationId = "rbxassetid://" .. tostring(bot.animations[action])
		animation.Parent = model

		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if success and track then
			track.Priority = item[2]
			track.Looped = item[3]
			bot.tracks[action] = track
		else
			animation:Destroy()
		end
	end

	bot.inAir = false
	humanoid.Running:Connect(function(speed)
		if not bot.model or not bot.model.Parent or humanoid.Health <= 0 or bot.inAir then
			return
		end

		if speed < 1 then
			self:_playAnimation(bot, "idle")
		elseif speed >= bot.walkSpeed * 0.82 then
			self:_playAnimation(bot, "run")
		else
			self:_playAnimation(bot, "walk")
		end
	end)

	humanoid.StateChanged:Connect(function(_, newState)
		if not bot.model or not bot.model.Parent or humanoid.Health <= 0 then
			return
		end

		if newState == Enum.HumanoidStateType.Jumping then
			bot.inAir = true
			self:_playAnimation(bot, "jump", 0.08)
		elseif newState == Enum.HumanoidStateType.Freefall then
			bot.inAir = true
			self:_playAnimation(bot, "fall", 0.12)
		elseif newState == Enum.HumanoidStateType.Landed then
			bot.inAir = false
			self:_playAnimation(bot, "idle", 0.14)
		end
	end)

	self:_playAnimation(bot, "idle", 0)
end

function BotService:_buildRig(bot)
	if bot.model then
		bot.model:Destroy()
	end

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = bot.bodyColor
	description.TorsoColor = bot.bodyColor
	description.LeftArmColor = bot.bodyColor
	description.RightArmColor = bot.bodyColor
	description.LeftLegColor = bot.bodyColor
	description.RightLegColor = bot.bodyColor
	description.HairAccessory = ""
	description.HeightScale = bot.name == "Rook" and 1.04 or 1
	description.WidthScale = bot.name == "Nova" and 0.92 or 1
	description.BodyTypeScale = 0.15

	local success, modelOrError = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R15
		)
	end)

	if not success then
		description.HairAccessory = ""
		success, modelOrError = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(
				description,
				Enum.HumanoidRigType.R15
			)
		end)
	end
	description:Destroy()

	if not success then
		warn("Could not create AI bot " .. bot.name .. ": " .. tostring(modelOrError))
		return false
	end

	local model = modelOrError
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		warn("AI bot rig is missing its Humanoid or HumanoidRootPart: " .. bot.name)
		return false
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

	bot.model = model
	bot.humanoid = humanoid
	bot.root = root
	bot.alive = false
	bot.isController = false

	self:_loadAnimations(bot, model, humanoid)

	humanoid.Died:Connect(function()
		bot.alive = false
		bot.isController = false
		bot.targetTile = nil
		model:SetAttribute("SkyfallRole", "Spectator")

		if self.onBotDied then
			self.onBotDied(bot)
		end

		task.defer(function()
			for index, candidate in ipairs(self.bots) do
				if candidate == bot
					and bot.model
					and bot.model.Parent
					and bot.root
					and bot.root.Parent
				then
					bot.model:PivotTo(
						self.arena:GetLobbySpawnCFrame(index, #self.bots, true)
					)
					bot.root.AssemblyLinearVelocity = Vector3.zero
					bot.root.AssemblyAngularVelocity = Vector3.zero
					break
				end
			end
		end)
	end)

	return true
end

function BotService:GetBots()
	return self.bots
end

function BotService:GetBotCount()
	return #self.bots
end

function BotService:GetAliveBots()
	local aliveBots = {}
	for _, bot in ipairs(self.bots) do
		if bot.alive
			and not bot.isController
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

function BotService:SetWinner(winnerBot)
	for _, bot in ipairs(self.bots) do
		bot.alive = false
		bot.targetTile = nil
		bot.isController = false

		if bot.model and bot.model.Parent then
			if bot == winnerBot then
				bot.model:SetAttribute("SkyfallRole", "Winner")
			elseif bot.model:GetAttribute("SkyfallRole") ~= "Spectator" then
				bot.model:SetAttribute("SkyfallRole", "Spectator")
			end

			if bot.humanoid then
				bot.humanoid.WalkSpeed = 0
				bot.humanoid.JumpPower = 0
			end
			if bot.root then
				bot.root.Anchored = true
			end
			self:_playAnimation(bot, "idle")
		end
	end
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

	return currentTile:GetAttribute("IsWarning") or currentTile:GetAttribute("IsBroken")
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
			and not bot.isController
			and bot.model
			and bot.model.Parent
			and bot.humanoid
			and bot.humanoid.Parent
			and bot.humanoid.Health > 0
			and bot.root
			and bot.root.Parent
			and not bot.root.Anchored
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

function BotService:_setBotHidden(bot, hidden)
	if not bot.model or not bot.model.Parent then
		return
	end

	for _, descendant in ipairs(bot.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if hidden then
				if descendant:GetAttribute("SkyfallStoredTransparency") == nil then
					descendant:SetAttribute("SkyfallStoredTransparency", descendant.Transparency)
					descendant:SetAttribute("SkyfallStoredCanCollide", descendant.CanCollide)
					descendant:SetAttribute("SkyfallStoredCanTouch", descendant.CanTouch)
					descendant:SetAttribute("SkyfallStoredCanQuery", descendant.CanQuery)
					descendant:SetAttribute("SkyfallStoredCastShadow", descendant.CastShadow)
				end
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.CastShadow = false
			else
				local transparency = descendant:GetAttribute("SkyfallStoredTransparency")
				if transparency ~= nil then
					descendant.Transparency = transparency
					descendant.CanCollide = descendant:GetAttribute("SkyfallStoredCanCollide")
					descendant.CanTouch = descendant:GetAttribute("SkyfallStoredCanTouch")
					descendant.CanQuery = descendant:GetAttribute("SkyfallStoredCanQuery")
					descendant.CastShadow = descendant:GetAttribute("SkyfallStoredCastShadow")
					descendant:SetAttribute("SkyfallStoredTransparency", nil)
					descendant:SetAttribute("SkyfallStoredCanCollide", nil)
					descendant:SetAttribute("SkyfallStoredCanTouch", nil)
					descendant:SetAttribute("SkyfallStoredCanQuery", nil)
					descendant:SetAttribute("SkyfallStoredCastShadow", nil)
				end
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if hidden then
				if descendant:GetAttribute("SkyfallStoredTransparency") == nil then
					descendant:SetAttribute("SkyfallStoredTransparency", descendant.Transparency)
				end
				descendant.Transparency = 1
			else
				local transparency = descendant:GetAttribute("SkyfallStoredTransparency")
				if transparency ~= nil then
					descendant.Transparency = transparency
					descendant:SetAttribute("SkyfallStoredTransparency", nil)
				end
			end
		end
	end

	if bot.root and bot.root.Parent then
		bot.root.Anchored = hidden
	end
	if hidden then
		bot.model:PivotTo(CFrame.new(Config.CONTROLLER_HIDDEN_POSITION))
	end
end

function BotService:StartRound(spawnCFrames, controllerBot)
	for index, bot in ipairs(self.bots) do
		if not bot.humanoid
			or bot.humanoid.Health <= 0
			or not bot.model
			or not bot.model.Parent
		then
			self:_buildRig(bot)
		end

		if bot.model and bot.model.Parent and bot.humanoid and bot.root then
			bot.targetTile = nil
			bot.lastTarget = nil
			bot.humanoid.Health = bot.humanoid.MaxHealth
			bot.root.Anchored = false
			bot.humanoid.PlatformStand = false

			if bot == controllerBot then
				bot.alive = false
				bot.isController = true
				bot.model:SetAttribute("SkyfallRole", "Controller")
				bot.humanoid.WalkSpeed = 0
				bot.humanoid.JumpPower = 0
				self:_setBotHidden(bot, true)
				self:_playAnimation(bot, "idle")
			else
				local spawnCFrame = spawnCFrames[index]
				bot.isController = false
				self:_setBotHidden(bot, false)
				if spawnCFrame then
					bot.alive = true
					bot.model:SetAttribute("SkyfallRole", "Runner")
					bot.humanoid.WalkSpeed = bot.walkSpeed
					bot.humanoid.JumpPower = bot.jumpPower
					bot.model:PivotTo(spawnCFrame)
					bot.root.AssemblyLinearVelocity = Vector3.zero
					bot.root.AssemblyAngularVelocity = Vector3.zero
					pcall(function()
						bot.root:SetNetworkOwner(nil)
					end)
					self:_playAnimation(bot, "idle")
				else
					bot.alive = false
					bot.model:SetAttribute("SkyfallRole", "Waiting")
					bot.humanoid.WalkSpeed = 0
					bot.humanoid.JumpPower = 0
				end
			end
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
			if self.onBotDied then
				self.onBotDied(bot)
			end
			bot.alive = false
			bot.targetTile = nil

			if not bot.humanoid or bot.humanoid.Health <= 0 or not bot.model or not bot.model.Parent then
				self:_buildRig(bot)
			end

			if bot.model and bot.humanoid and bot.root then
				bot.isController = false
				bot.model:SetAttribute("SkyfallRole", "Spectator")
				bot.humanoid.WalkSpeed = 0
				bot.humanoid.JumpPower = 0
				bot.root.Anchored = false
				bot.model:PivotTo(self.arena:GetLobbySpawnCFrame(index, #self.bots, true))
				bot.root.AssemblyLinearVelocity = Vector3.zero
				bot.root.AssemblyAngularVelocity = Vector3.zero
				self:_playAnimation(bot, "idle")
			end
		end
	end
end

function BotService:SendToLobby()
	for index, bot in ipairs(self.bots) do
		bot.alive = false
		bot.isController = false
		bot.targetTile = nil

		if not bot.humanoid
			or bot.humanoid.Health <= 0
			or not bot.model
			or not bot.model.Parent
		then
			self:_buildRig(bot)
		end

		if bot.model and bot.model.Parent and bot.humanoid and bot.root then
			self:_setBotHidden(bot, false)
			bot.model:SetAttribute("SkyfallRole", "Waiting")
			bot.humanoid.Health = bot.humanoid.MaxHealth
			bot.humanoid.PlatformStand = false
			bot.humanoid.WalkSpeed = 0
			bot.humanoid.JumpPower = 0
			bot.root.Anchored = false
			bot.model:PivotTo(self.arena:GetLobbySpawnCFrame(index, #self.bots, true))
			bot.root.AssemblyLinearVelocity = Vector3.zero
			bot.root.AssemblyAngularVelocity = Vector3.zero
			pcall(function()
				bot.root:SetNetworkOwner(nil)
			end)
			self:_playAnimation(bot, "idle")
		end
	end
end

return BotService
