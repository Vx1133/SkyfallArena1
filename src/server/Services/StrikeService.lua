local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local StrikeService = {}
StrikeService.__index = StrikeService

function StrikeService.new(arenaService, roundService, targetRemote)
	local self = setmetatable({}, StrikeService)
	self.arena = arenaService
	self.rounds = roundService
	self.targetRemote = targetRemote
	self.cooldowns = {}
	return self
end

function StrikeService:_handleTarget(player, gridX, gridZ)
	if not self.rounds:IsActiveController(player) then
		return
	end

	if typeof(gridX) ~= "number" or typeof(gridZ) ~= "number" then
		return
	end

	if gridX % 1 ~= 0 or gridZ % 1 ~= 0 then
		return
	end

	if gridX < 1 or gridX > Config.GRID_SIZE or gridZ < 1 or gridZ > Config.GRID_SIZE then
		return
	end

	local now = os.clock()
	local nextAllowed = self.cooldowns[player.UserId] or 0
	if now < nextAllowed then
		return
	end

	local tile = self.arena:GetTile(gridX, gridZ)
	if not tile then
		return
	end

	local token = self.arena:MarkTile(tile)
	if not token then
		return
	end

	self.cooldowns[player.UserId] = now + Config.STRIKE_COOLDOWN_SECONDS

	task.delay(Config.WARNING_SECONDS, function()
		if not self.rounds:IsActiveController(player) then
			self.arena:ClearWarning(tile, token)
			return
		end

		if not self.arena:IsStrikeCurrent(tile, token) then
			return
		end

		self.arena:CreateStrikeBeam(tile)
		self.arena:BreakTile(tile, token)

		task.delay(Config.TILE_REPAIR_SECONDS, function()
			self.arena:RepairTile(tile, token)
		end)
	end)
end

function StrikeService:Start()
	self.targetRemote.OnServerEvent:Connect(function(player, gridX, gridZ)
		self:_handleTarget(player, gridX, gridZ)
	end)
end

return StrikeService
