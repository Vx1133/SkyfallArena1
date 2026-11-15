local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local AdminFlightService = {}
AdminFlightService.__index = AdminFlightService

function AdminFlightService.IsAuthorizedUserId(userId, creatorType, creatorId)
	return creatorType == Enum.CreatorType.User
		and typeof(userId) == "number"
		and typeof(creatorId) == "number"
		and creatorId > 0
		and userId == creatorId
end

function AdminFlightService.new(remote, roundService)
	local self = setmetatable({}, AdminFlightService)
	self.remote = remote
	self.rounds = roundService
	self.creatorType = game.CreatorType
	self.creatorId = game.CreatorId
	self.active = {}
	self.running = false
	return self
end

function AdminFlightService:_isAuthorized(player)
	return player
		and player.Parent == Players
		and AdminFlightService.IsAuthorizedUserId(player.UserId, self.creatorType, self.creatorId)
end

function AdminFlightService:_setAdminAttribute(player)
	if player and player.Parent == Players then
		player:SetAttribute("SkyfallIsAdmin", self:_isAuthorized(player))
		player:SetAttribute("SkyfallFlightEnabled", self.active[player] ~= nil)
	end
end

function AdminFlightService:_disable(player)
	local state = self.active[player]
	if not state then
		if player and player.Parent == Players then
			player:SetAttribute("SkyfallFlightEnabled", false)
		end
		return
	end

	self.active[player] = nil
	if state.velocity then
		state.velocity:Destroy()
	end
	if state.orientation then
		state.orientation:Destroy()
	end
	if state.attachment then
		state.attachment:Destroy()
	end

	local humanoid = state.humanoid
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = state.walkSpeed
		humanoid.JumpPower = state.jumpPower
		humanoid.JumpHeight = state.jumpHeight
		humanoid.AutoRotate = state.autoRotate
		humanoid.PlatformStand = state.platformStand
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	if state.root and state.root.Parent then
		state.root.AssemblyLinearVelocity = Vector3.zero
		state.root.AssemblyAngularVelocity = Vector3.zero
		pcall(function()
			state.root:SetNetworkOwner(player)
		end)
	end

	if player and player.Parent == Players then
		player:SetAttribute("SkyfallFlightEnabled", false)
	end
end

function AdminFlightService:_enable(player)
	if not self:_isAuthorized(player) or not self.rounds:IsWaiting() or player:GetAttribute("SkyfallReady") == true then
		return false
	end
	if self.active[player] then
		return true
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "SkyfallAdminFlightAttachment"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SkyfallAdminFlightVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitsEnabled = false
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "SkyfallAdminFlightOrientation"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.RigidityEnabled = true
	orientation.CFrame = root.CFrame - root.Position
	orientation.Parent = root

	self.active[player] = {
		character = character,
		humanoid = humanoid,
		root = root,
		attachment = attachment,
		velocity = velocity,
		orientation = orientation,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		autoRotate = humanoid.AutoRotate,
		platformStand = humanoid.PlatformStand,
	}

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = Vector3.zero
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	player:SetAttribute("SkyfallFlightEnabled", true)
	return true
end

local function isFiniteVector(vector)
	return typeof(vector) == "Vector3"
		and vector.X == vector.X
		and vector.Y == vector.Y
		and vector.Z == vector.Z
		and math.abs(vector.X) < 10000
		and math.abs(vector.Y) < 10000
		and math.abs(vector.Z) < 10000
end

function AdminFlightService:_move(player, direction, lookVector)
	if not self:_isAuthorized(player) or not self.rounds:IsWaiting() or player:GetAttribute("SkyfallReady") == true then
		self:_disable(player)
		return
	end

	local state = self.active[player]
	if not state or not state.velocity or not state.velocity.Parent then
		return
	end
	if not isFiniteVector(direction) or not isFiniteVector(lookVector) then
		state.velocity.VectorVelocity = Vector3.zero
		return
	end

	local unitDirection = direction
	if unitDirection.Magnitude > 1 then
		unitDirection = unitDirection.Unit
	end
	state.velocity.VectorVelocity = unitDirection * Config.ADMIN_FLIGHT_SPEED

	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude > 0.001 then
		state.orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook.Unit)
	end
end

function AdminFlightService:_onCharacterAdded(player)
	self:_disable(player)
	self:_setAdminAttribute(player)
end

function AdminFlightService:Start()
	if self.running then
		return
	end
	self.running = true

	local function bindPlayer(player)
		self:_setAdminAttribute(player)
		player.CharacterAdded:Connect(function()
			self:_onCharacterAdded(player)
		end)
	end

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		self:_disable(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	self.remote.OnServerEvent:Connect(function(player, command, direction, lookVector)
		if not self:_isAuthorized(player) then
			self:_disable(player)
			return
		end
		if command == "Enable" then
			self:_enable(player)
		elseif command == "Disable" then
			self:_disable(player)
		elseif command == "Move" then
			self:_move(player, direction, lookVector)
		end
	end)

	RunService.Heartbeat:Connect(function()
		for player, state in pairs(self.active) do
			if not self:_isAuthorized(player)
				or not self.rounds:IsWaiting()
				or player:GetAttribute("SkyfallReady") == true
				or not player.Character
				or player.Character ~= state.character
				or not state.root.Parent
				or not state.humanoid.Parent
				or state.humanoid.Health <= 0
			then
				self:_disable(player)
			end
		end
	end)
end

return AdminFlightService
