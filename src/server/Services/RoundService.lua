local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(arenaService, stateRemote, botService)
	local self = setmetatable({}, RoundService)
	self.arena = arenaService
	self.stateRemote = stateRemote
	self.botService = botService
	self.phase = "Waiting"
	self.elapsedSeconds = 0
	self.countdownSeconds = 0
	self.aliveRunners = {}
	self.winner = ""
	self.winnerPlayer = nil
	self.roundNumber = 0
	self.roundStartedAt = 0
	self.overtime = false
	self.running = false
	self.stats = {}

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.aliveRunners[player] = nil
		self.stats[player] = nil
		self:_broadcast()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(player)
	end

	return self
end

function RoundService:_setupStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local wins = leaderstats:FindFirstChild("Wins")
	if not wins then
		wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Value = 0
		wins.Parent = leaderstats
	end

	local bestTime = leaderstats:FindFirstChild("BestTime")
	if not bestTime then
		bestTime = Instance.new("IntValue")
		bestTime.Name = "BestTime"
		bestTime.Value = 0
		bestTime.Parent = leaderstats
	end

	self.stats[player] = {
		wins = wins,
		bestTime = bestTime,
	}
end

function RoundService:_lobbySpawnForPlayer(player)
	local playerList = Players:GetPlayers()
	local index = 1

	for currentIndex, currentPlayer in ipairs(playerList) do
		if currentPlayer == player then
			index = currentIndex
			break
		end
	end

	return self.arena:GetLobbySpawnCFrame(index, #playerList)
end

function RoundService:_bindPlayer(player)
	self:_setupStats(player)
	player:SetAttribute("SkyfallRole", "Waiting")

	player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(player, character)
	end)

	if player.Character then
		task.defer(self._onCharacterAdded, self, player, player.Character)
	end
end

function RoundService:_placePlayer(player, spawnCFrame)
	local character = player.Character
	if character then
		character:PivotTo(spawnCFrame)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function RoundService:_onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if self.phase == "Active" and self.aliveRunners[player] then
		player:SetAttribute("SkyfallRole", "Runner")
		self:_placePlayer(player, self.arena:GetRunnerSpawnCFrame(1, math.max(self:_aliveRunnerCount(), 1)))
	else
		if self.phase == "Active" then
			player:SetAttribute("SkyfallRole", "Spectator")
		else
			player:SetAttribute("SkyfallRole", "Waiting")
		end
		self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
	end

	if humanoid then
		humanoid.Died:Connect(function()
			self:HandleDeath(player)
		end)
	end
end

function RoundService:_aliveRunnerCount()
	local count = 0
	for player in pairs(self.aliveRunners) do
		if player.Parent == Players then
			count += 1
		end
	end

	if self.botService then
		count += self.botService:GetAliveCount()
	end

	return count
end

function RoundService:GetAlivePositions()
	local positions = {}
	for player in pairs(self.aliveRunners) do
		if player.Parent == Players then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				table.insert(positions, root.Position)
			end
		end
	end
	return positions
end

function RoundService:IsActive()
	return self.phase == "Active"
end

function RoundService:IsOvertime()
	return self.overtime
end

function RoundService:_broadcast()
	self.stateRemote:FireAllClients({
		phase = self.phase,
		elapsedSeconds = self.elapsedSeconds,
		countdownSeconds = self.countdownSeconds,
		aliveRunners = self:_aliveRunnerCount(),
		playerCount = #Players:GetPlayers(),
		botCount = self.botService and self.botService:GetBotCount() or 0,
		winner = self.winner,
		roundNumber = self.roundNumber,
		overtime = self.overtime,
	})
end

function RoundService:HandleDeath(player)
	if self.phase ~= "Active" or not self.aliveRunners[player] then
		return
	end

	self.aliveRunners[player] = nil
	player:SetAttribute("SkyfallRole", "Spectator")
	self:_broadcast()
end

function RoundService:Eliminate(player)
	if not self.aliveRunners[player] then
		return
	end

	self.aliveRunners[player] = nil
	player:SetAttribute("SkyfallRole", "Spectator")

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end

	self:_broadcast()
end

function RoundService:_eliminateFallenRunners()
	local fallen = {}

	for player in pairs(self.aliveRunners) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player.Parent or not root or root.Position.Y < Config.OUT_OF_BOUNDS_Y then
			table.insert(fallen, player)
		end
	end

	for _, player in ipairs(fallen) do
		self:Eliminate(player)
	end

	if self.botService then
		self.botService:EliminateFallenRunners(Config.OUT_OF_BOUNDS_Y)
	end
end

function RoundService:_getSoleSurvivor()
	local humanSurvivors = {}
	for player in pairs(self.aliveRunners) do
		if player.Parent == Players then
			table.insert(humanSurvivors, player)
		end
	end

	local botSurvivors = self.botService and self.botService:GetAliveBots() or {}
	if #humanSurvivors + #botSurvivors ~= 1 then
		return nil, nil
	end

	if #humanSurvivors == 1 then
		return humanSurvivors[1].DisplayName, humanSurvivors[1]
	end

	return botSurvivors[1].name, nil
end

function RoundService:_updateSurvivalRecords()
	local elapsed = math.floor(os.clock() - self.roundStartedAt)
	for player in pairs(self.aliveRunners) do
		local statSet = self.stats[player]
		if player.Parent == Players and statSet and statSet.bestTime then
			statSet.bestTime.Value = math.max(statSet.bestTime.Value, elapsed)
			player:SetAttribute("SkyfallSurvivalTime", elapsed)
		end
	end
end

function RoundService:_awardWinner(winnerPlayer)
	if not winnerPlayer then
		return
	end

	local statSet = self.stats[winnerPlayer]
	if statSet and statSet.wins then
		statSet.wins.Value += 1
	end
end

function RoundService:_placeAllPlayersInLobby()
	local playerList = Players:GetPlayers()
	for index, player in ipairs(playerList) do
		player:SetAttribute("SkyfallRole", "Waiting")
		self:_placePlayer(player, self.arena:GetLobbySpawnCFrame(index, #playerList))
	end

	if self.botService then
		self.botService:SendToLobby()
	end
end

function RoundService:_runRound()
	local playersInRound = Players:GetPlayers()
	if #playersInRound < Config.MIN_PLAYERS then
		return
	end

	self.roundNumber += 1
	self.arena:ResetTiles()
	self.aliveRunners = {}
	self.elapsedSeconds = 0
	self.countdownSeconds = 0
	self.overtime = false
	self.winner = ""
	self.winnerPlayer = nil
	self.roundStartedAt = os.clock()
	self.phase = "Active"

	local botCount = self.botService and self.botService:GetBotCount() or 0
	local totalContestants = #playersInRound + botCount

	for index, player in ipairs(playersInRound) do
		self.aliveRunners[player] = true
		player:SetAttribute("SkyfallRole", "Runner")
		player:SetAttribute("SkyfallSurvivalTime", 0)
		self:_placePlayer(
			player,
			self.arena:GetRunnerSpawnCFrame(index, math.max(totalContestants, 1))
		)
	end

	local botSpawnCFrames = {}
	for index = 1, botCount do
		local spawnIndex = #playersInRound + index
		botSpawnCFrames[index] = self.arena:GetRunnerSpawnCFrame(
			spawnIndex,
			math.max(totalContestants, 1)
		)
	end

	if self.botService then
		self.botService:StartRound(botSpawnCFrames)
	end

	self:_broadcast()
	local canceled = false

	while self.phase == "Active" do
		if #Players:GetPlayers() == 0 then
			canceled = true
			break
		end

		self.elapsedSeconds = math.floor(os.clock() - self.roundStartedAt)
		self.overtime = self.elapsedSeconds >= Config.OVERTIME_START_SECONDS
		self:_eliminateFallenRunners()
		self:_updateSurvivalRecords()
		self:_broadcast()

		if self:_aliveRunnerCount() <= 1 then
			self.winner, self.winnerPlayer = self:_getSoleSurvivor()
			if self:_aliveRunnerCount() == 0 then
				self.winner = "NO SURVIVORS"
			end
			self:_awardWinner(self.winnerPlayer)
			if self.winnerPlayer then
				self.winnerPlayer:SetAttribute("SkyfallRole", "Winner")
			elseif self.botService then
				self.botService:SetWinner(self.winner)
			end
			break
		end

		task.wait(1)
	end

	self.phase = canceled and "Waiting" or "Results"
	self.elapsedSeconds = math.floor(os.clock() - self.roundStartedAt)

	if not canceled then
		for seconds = Config.RESULTS_SECONDS, 1, -1 do
			self.countdownSeconds = seconds
			self:_broadcast()
			task.wait(1)
		end
	end

	self.phase = "Waiting"
	self.elapsedSeconds = 0
	self.countdownSeconds = 0
	self.overtime = false
	self.aliveRunners = {}
	self.arena:ResetTiles()
	self:_placeAllPlayersInLobby()
	self:_broadcast()
end

function RoundService:_runLoop()
	while self.running do
		self.phase = "Waiting"
		self.elapsedSeconds = 0
		self.countdownSeconds = 0
		self:_broadcast()

		while self.running and #Players:GetPlayers() < Config.MIN_PLAYERS do
			self:_broadcast()
			task.wait(1)
		end

		if not self.running then
			break
		end

		self.phase = "Intermission"
		local canceled = false
		for seconds = Config.INTERMISSION_SECONDS, 1, -1 do
			if #Players:GetPlayers() < Config.MIN_PLAYERS then
				canceled = true
				break
			end

			self.countdownSeconds = seconds
			self:_broadcast()
			task.wait(1)
		end

		if not canceled and #Players:GetPlayers() >= Config.MIN_PLAYERS then
			self:_runRound()
		end

		task.wait(0.5)
	end
end

function RoundService:Start()
	if self.running then
		return
	end

	self.running = true
	task.spawn(function()
		self:_runLoop()
	end)
end

return RoundService
