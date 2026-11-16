local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local BubbleGunService = {}
BubbleGunService.__index = BubbleGunService

local function isFiniteNumber(value)
	return typeof(value) == "number"
		and value == value
		and math.abs(value) < 100000
end

local function isFiniteVector(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function createPart(parent, name, size, cframe, color, material, shape, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = anchored
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Massless = not anchored
	part.Parent = parent
	return part
end

local function addWeldedPart(parent, handle, name, size, offset, color, material, shape)
	local part = createPart(
		parent,
		name,
		size,
		handle.CFrame * offset,
		color,
		material,
		shape,
		false
	)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = handle
	return part
end

local function buildToolModel(parent, anchored)
	local handle = createPart(
		parent,
		"Handle",
		Vector3.new(1.05, 0.56, 1.65),
		CFrame.new(),
		Color3.fromRGB(40, 190, 190),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Block,
		anchored
	)
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth

	local parts = {
		{
			name = "PearlGrip",
			size = Vector3.new(0.56, 0.62, 0.64),
			offset = CFrame.new(0, -0.43, 0.28),
			color = Color3.fromRGB(247, 246, 235),
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "Barrel",
			size = Vector3.new(0.34, 0.84, 0.84),
			offset = CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.pi / 2, 0),
			color = Color3.fromRGB(225, 246, 242),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "MuzzleGoldTrim",
			size = Vector3.new(0.16, 1.02, 1.02),
			offset = CFrame.new(0, 0, -1.08) * CFrame.Angles(0, math.pi / 2, 0),
			color = Color3.fromRGB(226, 184, 91),
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "MuzzlePearl",
			size = Vector3.new(0.12, 0.68, 0.68),
			offset = CFrame.new(0, 0, -1.19) * CFrame.Angles(0, math.pi / 2, 0),
			color = Color3.fromRGB(250, 255, 249),
			material = Enum.Material.Glass,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "GoldTopAccent",
			size = Vector3.new(0.76, 0.09, 0.18),
			offset = CFrame.new(0, 0.31, -0.12),
			color = Color3.fromRGB(231, 190, 91),
			material = Enum.Material.Metal,
		},
		{
			name = "PearlSight",
			size = Vector3.new(0.2, 0.18, 0.22),
			offset = CFrame.new(0, 0.34, -0.62),
			color = Color3.fromRGB(255, 255, 248),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Ball,
		},
	}

	for _, item in ipairs(parts) do
		if anchored then
			createPart(
				parent,
				item.name,
				item.size,
				handle.CFrame * item.offset,
				item.color,
				item.material,
				item.shape,
				true
			)
		else
			addWeldedPart(
				parent,
				handle,
				item.name,
				item.size,
				item.offset,
				item.color,
				item.material,
				item.shape
			)
		end
	end
	return handle
end

function BubbleGunService.new(arenaService, roundService, botService, shotRemote)
	local self = setmetatable({}, BubbleGunService)
	self.arena = arenaService
	self.rounds = roundService
	self.botService = botService
	self.shotRemote = shotRemote
	self.template = nil
	self.displayStand = nil
	self.trainingTarget = nil
	self.cooldowns = {}
	self.activeHolds = {}
	self.holdsByHumanoid = {}
	self.activeProjectiles = {}
	self.lifecycleToken = 0
	self.running = false
	return self
end

function BubbleGunService:_buildTemplate()
	local template = ServerStorage:FindFirstChild("SkyfallBubbleBlasterTemplate")
	if template then
		template:Destroy()
	end

	template = Instance.new("Tool")
	template.Name = Config.BUBBLE_GUN_TOOL_NAME
	template.RequiresHandle = true
	template.CanBeDropped = false
	template.ToolTip = "Bubble Blaster"
	template:SetAttribute("SkyfallBubbleTool", true)
	template.Grip = CFrame.new(0, -0.2, -0.45)
	buildToolModel(template, false)
	template.Parent = ServerStorage
	self.template = template
end

function BubbleGunService:_buildLobbyStation()
	local folder = self.arena.lobbyFolder
	local center = Config.LOBBY_CENTER
	-- Place the station beside the first lobby spawn, on the side of the view,
	-- so the proximity prompt is reachable without crossing the PLAY button.
	local standCenter = center + Vector3.new(Config.LOBBY_SPAWN_RADIUS - 7, 2.1, -8)

	local stand = Instance.new("Model")
	stand.Name = "BubbleBlasterTrialStand"
	stand.Parent = folder
	self.displayStand = stand

	local base = createPart(
		stand,
		"DisplayBase",
		Vector3.new(10, 0.8, 8),
		CFrame.new(standCenter),
		Color3.fromRGB(37, 117, 128),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Block,
		true
	)
	base.CanQuery = false

	local pedestal = createPart(
		stand,
		"DisplayPedestal",
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(standCenter + Vector3.new(0, 1.35, 0)),
		Color3.fromRGB(246, 244, 229),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Block,
		true
	)
	pedestal.CanQuery = false

	local displayGun = Instance.new("Model")
	displayGun.Name = "BubbleBlasterDisplay"
	displayGun.Parent = stand
	local displayHandle = buildToolModel(displayGun, true)
	displayGun.PrimaryPart = displayHandle
	displayGun:PivotTo(CFrame.new(standCenter + Vector3.new(0, 3.2, 0)))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BubbleBlasterTryPrompt"
	prompt.ActionText = "TRY FOR FREE"
	prompt.ObjectText = "Bubble Blaster"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = displayHandle
	prompt.Triggered:Connect(function(player)
		self:GrantTrial(player)
	end)

	local target = Instance.new("Model")
	target.Name = "BubbleTrainingTarget"
	target.Parent = folder
	local targetPart = createPart(
		target,
		"TargetCore",
		Vector3.new(3.2, 3.2, 3.2),
		CFrame.new(standCenter + Vector3.new(0, 4.5, -10)),
		Color3.fromRGB(244, 246, 237),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball,
		true
	)
	targetPart:SetAttribute("SkyfallTrainingTarget", true)
	target.PrimaryPart = targetPart
	self.trainingTarget = target
end

function BubbleGunService:_findOwnedTool(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local containers = {}
	if backpack then
		table.insert(containers, backpack)
	end
	if character then
		table.insert(containers, character)
	end
	for _, container in ipairs(containers) do
		if container then
			local tool = container:FindFirstChild(Config.BUBBLE_GUN_TOOL_NAME)
			if tool and tool:IsA("Tool") and tool:GetAttribute("SkyfallBubbleTool") == true then
				return tool
			end
		end
	end
	return nil
end

function BubbleGunService:_removeDuplicateTools(player, keep)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local containers = {}
	if backpack then
		table.insert(containers, backpack)
	end
	if character then
		table.insert(containers, character)
	end
	for _, container in ipairs(containers) do
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool")
					and child.Name == Config.BUBBLE_GUN_TOOL_NAME
					and child:GetAttribute("SkyfallBubbleTool") == true
					and child ~= keep
				then
					child:Destroy()
				end
			end
		end
	end
end

function BubbleGunService:_grant(player)
	if not player or player.Parent ~= Players or not self.template then
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end

	local existing = self:_findOwnedTool(player)
	if existing then
		self:_removeDuplicateTools(player, existing)
		return true
	end

	local tool = self.template:Clone()
	tool:SetAttribute("SkyfallBubbleTool", true)
	tool.Parent = backpack
	return true
end

function BubbleGunService:GrantTrial(player)
	if not player or player.Parent ~= Players
		or self.rounds:IsActive()
		or player:GetAttribute("SkyfallRole") ~= "Waiting"
	then
		return false
	end
	return self:_grant(player)
end

function BubbleGunService:GrantRunner(player)
	if not self.rounds:IsAliveRunner(player) then
		return false
	end
	return self:_grant(player)
end

function BubbleGunService:RemoveTool(player)
	if not player then
		return
	end
	self:_removeDuplicateTools(player, nil)
end

function BubbleGunService:_bindPlayer(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if self.rounds:IsAliveRunner(player) then
				self:GrantRunner(player)
			end
		end)
	end)
	player.CharacterRemoving:Connect(function(character)
		self:_cancelProjectilesForPlayer(player)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hold = humanoid and self.holdsByHumanoid[humanoid]
		if hold then
			self:_releaseHold(hold)
		end
	end)
end

function BubbleGunService:_findTarget(player, hitInstance)
	if self.rounds:IsActive() then
		local hitModel = hitInstance:FindFirstAncestorOfClass("Model")
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player
				and targetPlayer.Character == hitModel
				and targetPlayer:GetAttribute("SkyfallRole") == "Runner"
				and self.rounds:IsAliveRunner(targetPlayer)
			then
				local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
				return humanoid and humanoid.Health > 0 and {
					kind = "Player",
					player = targetPlayer,
					model = hitModel,
					humanoid = humanoid,
				} or nil
			end
		end

		for _, bot in ipairs(self.botService:GetAliveBots()) do
			if bot.model == hitModel
				and bot.alive
				and bot.humanoid
				and bot.humanoid.Health > 0
				and bot.model:GetAttribute("SkyfallRole") == "Runner"
			then
				return {
					kind = "Bot",
					bot = bot,
					model = bot.model,
					humanoid = bot.humanoid,
				}
			end
		end
		return nil
	end

	if player:GetAttribute("SkyfallRole") == "Waiting"
		and self.trainingTarget
		and hitInstance:IsDescendantOf(self.trainingTarget)
	then
		return {
			kind = "Training",
			model = self.trainingTarget,
			part = hitInstance,
		}
	end
	return nil
end

function BubbleGunService:_showBurst(position)
	local bubble = createPart(
		Workspace,
		"BubbleImpactBurst",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(position),
		Color3.fromRGB(104, 231, 235),
		Enum.Material.Glass,
		Enum.PartType.Ball,
		true
	)
	bubble.Transparency = 0.35
	bubble.CanQuery = false
	bubble.CanCollide = false
	local tween = TweenService:Create(
		bubble,
		TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(4.8, 4.8, 4.8), Transparency = 1}
	)
	tween:Play()
	Debris:AddItem(bubble, 0.4)
end

function BubbleGunService:_showTrainingHit(part)
	if part and part.Parent then
		self:_showBurst(part.Position)
	end
end

function BubbleGunService:_releaseHold(hold)
	if not hold or hold.released then
		return false
	end
	hold.released = true
	self.activeHolds[hold] = nil
	if hold.humanoid then
		self.holdsByHumanoid[hold.humanoid] = nil
	end

	if hold.root and hold.root.Parent then
		hold.root.Anchored = hold.rootAnchored
		hold.root.AssemblyLinearVelocity = hold.linearVelocity
		hold.root.AssemblyAngularVelocity = hold.angularVelocity
	end
	if hold.diedConnection then
		hold.diedConnection:Disconnect()
		hold.diedConnection = nil
	end
	if hold.humanoid and hold.humanoid.Parent then
		hold.humanoid.WalkSpeed = hold.walkSpeed
		hold.humanoid.JumpPower = hold.jumpPower
		hold.humanoid.JumpHeight = hold.jumpHeight
		hold.humanoid.AutoRotate = hold.autoRotate
		hold.humanoid.PlatformStand = hold.platformStand
		hold.humanoid.Sit = hold.sit
		if hold.humanoid.Health > 0 then
			hold.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	if hold.bubble and hold.bubble.Parent then
		local pop = TweenService:Create(
			hold.bubble,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(8.5, 8.5, 8.5), Transparency = 1}
		)
		pop:Play()
		Debris:AddItem(hold.bubble, 0.22)
	end
	return true
end

function BubbleGunService:_holdTarget(target, shooter)
	local humanoid = target and target.humanoid
	local model = target and target.model
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or self.holdsByHumanoid[humanoid] then
		return false
	end

	local hold = {
		humanoid = humanoid,
		root = root,
		player = target.player,
		shooter = shooter,
		rootAnchored = root.Anchored,
		linearVelocity = root.AssemblyLinearVelocity,
		angularVelocity = root.AssemblyAngularVelocity,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		autoRotate = humanoid.AutoRotate,
		platformStand = humanoid.PlatformStand,
		sit = humanoid.Sit,
	}
	self.activeHolds[hold] = true
	self.holdsByHumanoid[humanoid] = hold

	root.Anchored = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid.Sit = false

	local bubble = createPart(
		Workspace,
		"SkyfallBubbleHold",
		Vector3.new(6.5, 6.5, 6.5),
		CFrame.new(root.Position),
		Color3.fromRGB(112, 231, 239),
		Enum.Material.Glass,
		Enum.PartType.Ball,
		true
	)
	bubble.Transparency = 0.52
	bubble.Reflectance = 0.06
	bubble.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(153, 247, 255)
	light.Brightness = 1.2
	light.Range = 10
	light.Parent = bubble
	hold.bubble = bubble

	local appear = TweenService:Create(
		bubble,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = Vector3.new(7.2, 7.2, 7.2), Transparency = 0.48}
	)
	appear:Play()

	hold.diedConnection = humanoid.Died:Connect(function()
		self:_releaseHold(hold)
	end)
	task.delay(Config.BUBBLE_GUN_HOLD_SECONDS, function()
		self:_releaseHold(hold)
	end)
	return true
end

function BubbleGunService:_isValidShooter(player, tool, activeRound)
	if not player or player.Parent ~= Players or not tool or not tool:IsA("Tool") then
		return false
	end
	local character = player.Character
	if not character or tool.Parent ~= character then
		return false
	end
	if activeRound then
		return self.rounds:IsActive()
			and self.rounds:IsAliveRunner(player)
			and player:GetAttribute("SkyfallRole") == "Runner"
	end
	return not self.rounds:IsActive() and player:GetAttribute("SkyfallRole") == "Waiting"
end

function BubbleGunService:_fireProjectile(player, origin, direction, hit, target, tool, activeRound)
	local endPosition = hit and hit.Position or (origin + direction * Config.BUBBLE_GUN_RANGE)
	local distance = (endPosition - origin).Magnitude
	local duration = math.clamp(distance / 150, 0.08, 0.42)
	local projectile = createPart(
		Workspace,
		"SkyfallBubbleProjectile",
		Vector3.new(0.78, 0.78, 0.78),
		CFrame.new(origin),
		Color3.fromRGB(91, 231, 235),
		Enum.Material.Neon,
		Enum.PartType.Ball,
		true
	)
	projectile.Transparency = 0.08
	projectile.CanQuery = false
	projectile.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = projectile.Color
	light.Brightness = 1.4
	light.Range = 8
	light.Parent = projectile

	local tween = TweenService:Create(
		projectile,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{Position = endPosition}
	)
	self.activeProjectiles[projectile] = {
		shooter = player,
		tool = tool,
		activeRound = activeRound,
		token = self.lifecycleToken,
		tween = tween,
		origin = origin,
		direction = direction,
		hitPosition = hit and hit.Position or nil,
		target = target,
	}
	tween:Play()
	Debris:AddItem(projectile, duration + 0.2)

	task.delay(duration, function()
		local record = self.activeProjectiles[projectile]
		if not record then
			return
		end
		self.activeProjectiles[projectile] = nil
		if projectile.Parent then
			projectile:Destroy()
		end

		if record.token ~= self.lifecycleToken
			or not self:_isValidShooter(record.shooter, record.tool, record.activeRound)
		then
			return
		end

		if not record.target or not record.hitInstance then
			return
		end

		-- Recast the original server-approved ray at impact time. This catches targets
		-- that moved out of range/line-of-sight, died, left, or changed roles in flight.
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = {record.shooter.Character, self.displayStand}
		parameters.IgnoreWater = true
		local impactHit = Workspace:Raycast(
			record.origin,
			record.direction * Config.BUBBLE_GUN_RANGE,
			parameters
		)
		local currentTarget = impactHit and self:_findTarget(record.shooter, impactHit.Instance) or nil
		if not currentTarget
			or currentTarget.kind ~= record.target.kind
			or currentTarget.model ~= record.target.model
			or currentTarget.humanoid ~= record.target.humanoid
		then
			if record.hitPosition then
				self:_showBurst(record.hitPosition)
			end
			return
		end

		if currentTarget.kind == "Training" then
			self:_showTrainingHit(currentTarget.part)
		elseif not currentTarget.humanoid or currentTarget.humanoid.Health <= 0 then
			self:_showBurst(record.hitPosition or endPosition)
		elseif not self:_holdTarget(currentTarget, record.shooter) then
			self:_showBurst(impactHit.Position)
		end
	end)
end

function BubbleGunService:_cancelProjectilesForPlayer(player)
	local projectiles = {}
	for projectile, record in pairs(self.activeProjectiles) do
		if record.shooter == player then
			table.insert(projectiles, projectile)
		end
	end
	for _, projectile in ipairs(projectiles) do
		local record = self.activeProjectiles[projectile]
		self.activeProjectiles[projectile] = nil
		if record and record.tween then
			record.tween:Cancel()
		end
		if projectile.Parent then
			projectile:Destroy()
		end
	end
end

function BubbleGunService:_handleShot(player, direction)
	if not player or player.Parent ~= Players or not isFiniteVector(direction) then
		return false
	end
	local magnitude = direction.Magnitude
	if magnitude < 0.9 or magnitude > 1.1 then
		return false
	end

	local character = player.Character
	local tool = character and character:FindFirstChild(Config.BUBBLE_GUN_TOOL_NAME)
	local handle = tool and tool:FindFirstChild("Handle")
	if not tool or not tool:IsA("Tool")
		or tool:GetAttribute("SkyfallBubbleTool") ~= true
		or not handle or not handle:IsA("BasePart")
	then
		return false
	end

	local activeRound = self.rounds:IsActive()
	if activeRound then
		if not self.rounds:IsAliveRunner(player)
			or player:GetAttribute("SkyfallRole") ~= "Runner"
		then
			return false
		end
	elseif player:GetAttribute("SkyfallRole") ~= "Waiting" then
		return false
	end

	if not self:_isValidShooter(player, tool, activeRound) then
		return false
	end

	local now = os.clock()
	if now < (self.cooldowns[player] or 0) then
		return false
	end
	self.cooldowns[player] = now + Config.BUBBLE_GUN_COOLDOWN_SECONDS

	local unitDirection = direction.Unit
	local origin = handle.Position + unitDirection * 0.9
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = {character, self.displayStand}
	parameters.IgnoreWater = true
	local hit = Workspace:Raycast(origin, unitDirection * Config.BUBBLE_GUN_RANGE, parameters)
	if not hit then
		self:_fireProjectile(player, origin, unitDirection, nil, nil, tool, activeRound)
		return true
	end

	local target = self:_findTarget(player, hit.Instance)
	if not target then
		self:_fireProjectile(player, origin, unitDirection, hit, nil, tool, activeRound)
		return true
	end
	if target.humanoid and self.holdsByHumanoid[target.humanoid] then
		self:_fireProjectile(player, origin, unitDirection, hit, nil, tool, activeRound)
		return true
	end

	self:_fireProjectile(player, origin, unitDirection, hit, target, tool, activeRound)
	return true
end

function BubbleGunService:ClearAll()
	self.lifecycleToken += 1
	local pendingProjectiles = {}
	for projectile, record in pairs(self.activeProjectiles) do
		table.insert(pendingProjectiles, {projectile = projectile, tween = record.tween})
	end
	for _, pending in ipairs(pendingProjectiles) do
		self.activeProjectiles[pending.projectile] = nil
		if pending.tween then
			pending.tween:Cancel()
		end
		if pending.projectile.Parent then
			pending.projectile:Destroy()
		end
	end

	local holds = {}
	for hold in pairs(self.activeHolds) do
		table.insert(holds, hold)
	end
	for _, hold in ipairs(holds) do
		self:_releaseHold(hold)
	end
end

function BubbleGunService:Start()
	if self.running then
		return
	end
	self.running = true
	self:_buildTemplate()
	self:_buildLobbyStation()

	self.shotRemote.OnServerEvent:Connect(function(player, direction)
		self:_handleShot(player, direction)
	end)
	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.cooldowns[player] = nil
		local holdsToRelease = {}
		self:_cancelProjectilesForPlayer(player)
		for hold in pairs(self.activeHolds) do
			if hold.player == player or hold.shooter == player then
				table.insert(holdsToRelease, hold)
			end
		end
		for _, hold in ipairs(holdsToRelease) do
			self:_releaseHold(hold)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(player)
	end
end

return BubbleGunService
