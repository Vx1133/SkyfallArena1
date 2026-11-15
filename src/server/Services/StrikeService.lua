local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local StrikeService = {}
StrikeService.__index = StrikeService

function StrikeService.new(arenaService, roundService, botService, targetRemote)
	local self = setmetatable({}, StrikeService)
	self.arena = arenaService
	self.rounds = roundService
	self.botService = botService
	self.targetRemote = targetRemote
	self.random = Random.new()
	self.lastTarget = nil
	self.lastHumanStrikeAt = {}
	self.running = false
	return self
end

function StrikeService:_getNearRunnerTiles(safeTiles)
	local positions = self.rounds:GetAlivePositions()
	for _, position in ipairs(self.botService:GetAlivePositions()) do
		table.insert(positions, position)
	end

	if #positions == 0 then
		return {}
	end

	local candidates = {}
	local spacing = Config.TILE_SIZE + Config.TILE_GAP
	local centerOffset = (Config.GRID_SIZE + 1) / 2

	for _, tile in ipairs(safeTiles) do
		local gridX = tile:GetAttribute("GridX")
		local gridZ = tile:GetAttribute("GridZ")
		local nearRunner = false

		for _, position in ipairs(positions) do
			local runnerX = math.floor(
				(position.X - Config.ARENA_CENTER.X) / spacing + centerOffset + 0.5
			)
			local runnerZ = math.floor(
				(position.Z - Config.ARENA_CENTER.Z) / spacing + centerOffset + 0.5
			)

			if math.abs(gridX - runnerX) <= 2 and math.abs(gridZ - runnerZ) <= 2 then
				nearRunner = true
				break
			end
		end

		if nearRunner then
			table.insert(candidates, tile)
		end
	end

	return candidates
end

function StrikeService:_chooseTarget()
	local safeTiles = self.arena:GetSafeTiles()
	if #safeTiles == 0 then
		return nil
	end

	local nearRunnerTiles = self:_getNearRunnerTiles(safeTiles)
	local candidates = safeTiles

	if #nearRunnerTiles > 0 and self.random:NextNumber() < 0.72 then
		candidates = nearRunnerTiles
	end

	if #candidates > 1 and self.lastTarget then
		local freshCandidates = {}
		for _, tile in ipairs(candidates) do
			if tile ~= self.lastTarget then
				table.insert(freshCandidates, tile)
			end
		end
		if #freshCandidates > 0 then
			candidates = freshCandidates
		end
	end

	return candidates[self.random:NextInteger(1, #candidates)]
end

function StrikeService:_fireAtTile(tile)
	if not self.rounds:IsActive() or not tile then
		return false
	end

	local token = self.arena:MarkTile(tile)
	if not token then
		return false
	end

	self.lastTarget = tile

	task.delay(Config.WARNING_SECONDS, function()
		if not self.rounds:IsActive() then
			self.arena:ClearWarning(tile, token)
			return
		end

		if not self.arena:IsStrikeCurrent(tile, token) then
			return
		end

		self.arena:CreateStrikeBeam(tile)
		self.arena:BreakTile(tile, token)
	end)

	return true
end

function StrikeService:_handleHumanTarget(player, gridX, gridZ)
	if not self.rounds:IsHumanController(player) then
		return
	end

	if typeof(gridX) ~= "number" or typeof(gridZ) ~= "number" then
		return
	end

	if gridX % 1 ~= 0 or gridZ % 1 ~= 0 then
		return
	end

	if gridX < 1 or gridX > Config.GRID_SIZE
		or gridZ < 1 or gridZ > Config.GRID_SIZE
	then
		return
	end

	local now = os.clock()
	local nextAllowed = self.lastHumanStrikeAt[player.UserId] or 0
	if now - nextAllowed < Config.HUMAN_STRIKE_COOLDOWN_SECONDS then
		return
	end

	local tile = self.arena:GetTile(gridX, gridZ)
	if self:_fireAtTile(tile) then
		self.lastHumanStrikeAt[player.UserId] = now
	end
end

function StrikeService:_runBotController()
	while self.running do
		if self.rounds:IsBotController() then
			local tile = self:_chooseTarget()
			if tile then
				self:_fireAtTile(tile)
			end
			task.wait(Config.BOT_STRIKE_INTERVAL_SECONDS)
		else
			self.lastTarget = nil
			task.wait(0.25)
		end
	end
end

function StrikeService:Start()
	if self.running then
		return
	end

	self.running = true
	self.targetRemote.OnServerEvent:Connect(function(player, gridX, gridZ)
		self:_handleHumanTarget(player, gridX, gridZ)
	end)

	task.spawn(function()
		self:_runBotController()
	end)
end

return StrikeService
