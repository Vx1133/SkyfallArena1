local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local StrikeService = {}
StrikeService.__index = StrikeService

function StrikeService.new(arenaService, roundService, botService)
	local self = setmetatable({}, StrikeService)
	self.arena = arenaService
	self.rounds = roundService
	self.botService = botService
	self.random = Random.new()
	self.lastTarget = nil
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

function StrikeService:_strikeTile(tile)
	if not self.rounds:IsActive() or not tile then
		return
	end

	local token = self.arena:MarkTile(tile)
	if not token then
		return
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

		task.delay(Config.TILE_REPAIR_SECONDS, function()
			self.arena:RepairTile(tile, token)
		end)
	end)
end

function StrikeService:_run()
	while self.running do
		if self.rounds:IsActive() then
			local strikeCount = Config.OVERTIME_STRIKES_PER_WAVE
			if not self.rounds:IsOvertime() then
				strikeCount = 1
			end

			for index = 1, strikeCount do
				if not self.rounds:IsActive() then
					break
				end

				local tile = self:_chooseTarget()
				if tile then
					self:_strikeTile(tile)
				end

				if strikeCount > 1 and index < strikeCount then
					task.wait(0.35)
				end
			end

			local interval = Config.STRIKE_INTERVAL_SECONDS
			if self.rounds:IsOvertime() then
				interval = Config.OVERTIME_STRIKE_INTERVAL_SECONDS
			end
			task.wait(interval)
		else
			self.lastTarget = nil
			task.wait(0.5)
		end
	end
end

function StrikeService:Start()
	if self.running then
		return
	end

	self.running = true
	task.spawn(function()
		self:_run()
	end)
end

return StrikeService
