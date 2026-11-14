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
	self.winnerCandidate = nil
	self.controller = nil
	self.nextController = nil
	self.roundNumber = 0
	self.roundStartedAt = 0
	self.overtime = false
	self.running = false
	self.stats = {}
	self.random = Random.new()
	self.lastMapId = 0

	Players.RespawnTime = Config.RESPAWN_TIME

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.aliveRunners[player] = nil
		self.stats[player] = nil

		if self.controller
			and self.controller.kind == "Player"
			and self.controller.value == player
		then
			self.controller = nil
		end

		if self.nextController
			and self.nextController.kind == "Player"
			and self.nextController.value == player
		then
			self.nextController = nil
		end

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

	return self.arena:GetLobbySpawnCFrame(index, #playerList, false)
end

function RoundService:_bindPlayer(player)
	self:_setupStats(player)
	player:SetAttribute("SkyfallRole", "Waiting")
	player:SetAttribute("SkyfallSurvivalTime", 0)

	player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(player, character)
	end)

	if player.Character then
		task.defer(self._onCharacterAdded, self, player, player.Character)
	end
end

function RoundService:_placePlayer(player, spawnCFrame)
	local character = player.Character
	if not character then
		return
	end

	character:PivotTo(spawnCFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function RoundService:_onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	character:WaitForChild("HumanoidRootPart", 10)

	if self.phase == "Active" then
		if self.controller
			and self.controller.kind == "Player"
			and self.controller.value == player
		then
			player:SetAttribute("SkyfallRole", "Controller")
			self:_placePlayer(player, self.arena:GetControllerSpawnCFrame())
		elseif self.aliveRunners[player] then
			player:SetAttribute("SkyfallRole", "Runner")
			self:_placePlayer(
				player,
				self.arena:GetRunnerSpawnCFrame(1, math.max(self:_aliveRunnerCount(), 1))
			)
		else
			player:SetAttribute("SkyfallRole", "Spectator")
			self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
		end
	else
		player:SetAttribute("SkyfallRole", "Waiting")
		self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
	end

	if humanoid then
		humanoid.Died:Connect(function()
			self:HandleDeath(player)
		end)
	end
end

function RoundService:_candidateName(candidate)
	if not candidate then
		return ""
	end

	if candidate.kind == "Player" then
		return candidate.value.DisplayName
	end

	return candidate.value.name
end

function RoundService:_isCandidateValid(candidate)
	if not candidate then
		return false
	end

	if candidate.kind == "Player" then
		return candidate.value and candidate.value.Parent == Players
	end

	if candidate.kind == "Bot" then
		local bot = candidate.value
		return bot
			and bot.model
			and bot.model.Parent
			and bot.humanoid
			and bot.humanoid.Health > 0
	end

	return false
end

function RoundService:_chooseNextMapId()
	if Config.MAP_COUNT <= 1 then
		return 1
	end

	if self.lastMapId < 1 or self.lastMapId > Config.MAP_COUNT then
		return self.random:NextInteger(1, Config.MAP_COUNT)
	end

	local offset = self.random:NextInteger(1, Config.MAP_COUNT - 1)
	return ((self.lastMapId - 1 + offset) % Config.MAP_COUNT) + 1
end

function RoundService:_chooseController()
	if self:_isCandidateValid(self.nextController) then
		local selected = self.nextController
		self.nextController = nil
		return selected
	end

	self.nextController = nil
	local candidates = {}

	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(candidates, {
			kind = "Player",
			value = player,
		})
	end

	for _, bot in ipairs(self.botService:GetBots()) do
		if self:_isCandidateValid({kind = "Bot", value = bot}) then
			table.insert(candidates, {
				kind = "Bot",
				value = bot,
			})
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[self.random:NextInteger(1, #candidates)]
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

function RoundService:GetController()
	return self.controller
end

function RoundService:IsHumanController(player)
	return self.phase == "Active"
		and self.controller ~= nil
		and self.controller.kind == "Player"
		and self.controller.value == player
		and player.Parent == Players
end

function RoundService:IsBotController()
	return self.phase == "Active"
		and self.controller ~= nil
		and self.controller.kind == "Bot"
		and self:_isCandidateValid(self.controller)
end

function RoundService:IsActive()
	return self.phase == "Active"
end

function RoundService:IsOvertime()
	return self.overtime
end

function RoundService:_broadcast()
	local botCount = self.botService and self.botService:GetBotCount() or 0
	local remainingPlayers = self:_aliveRunnerCount()

	self.stateRemote:FireAllClients({
		phase = self.phase,
		elapsedSeconds = self.elapsedSeconds,
		countdownSeconds = self.countdownSeconds,
		aliveRunners = remainingPlayers,
		remainingPlayers = remainingPlayers,
		playerCount = #Players:GetPlayers() + botCount,
		botCount = botCount,
		winner = self.winner,
		controllerName = self:_candidateName(self.controller),
		controllerKind = self.controller and self.controller.kind or "",
		roundNumber = self.roundNumber,
		overtime = self.overtime,
		mapName = self.arena:GetMapName(),
	})
end

function RoundService:_moveEliminatedPlayerToLobby(player)
	player:SetAttribute("SkyfallRole", "Spectator")
	self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
end

function RoundService:HandleDeath(player)
	if self.phase ~= "Active" then
		return
	end

	if self.controller
		and self.controller.kind == "Player"
		and self.controller.value == player
	then
		self.controller = nil
		self:_moveEliminatedPlayerToLobby(player)
		self:_broadcast()
		return
	end

	if self.aliveRunners[player] then
		self.aliveRunners[player] = nil
		self:_moveEliminatedPlayerToLobby(player)
		self:_broadcast()
	end
end

function RoundService:Eliminate(player)
	if not self.aliveRunners[player] then
		return
	end

	self.aliveRunners[player] = nil
	self:_moveEliminatedPlayerToLobby(player)

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

	if self.controller and self.controller.kind == "Player" then
		local controllerPlayer = self.controller.value
		local character = controllerPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or root.Position.Y < Config.OUT_OF_BOUNDS_Y then
			self.controller = nil
			self:_moveEliminatedPlayerToLobby(controllerPlayer)
		end
	end
end

function RoundService:_getSoleSurvivor()
	local survivors = {}

	for player in pairs(self.aliveRunners) do
		if player.Parent == Players then
			table.insert(survivors, {
				kind = "Player",
				value = player,
			})
		end
	end

	for _, bot in ipairs(self.botService:GetAliveBots()) do
		table.insert(survivors, {
			kind = "Bot",
			value = bot,
		})
	end

	if #survivors == 1 then
		return survivors[1]
	end

	return nil
end

function RoundService:_isGrounded(candidate)
	if not candidate then
		return false
	end

	local humanoid
	if candidate.kind == "Player" then
		local character = candidate.value.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
	elseif candidate.kind == "Bot" then
		humanoid = candidate.value.humanoid
	end

	return humanoid
		and humanoid.Health > 0
		and humanoid.FloorMaterial ~= Enum.Material.Air
end

function RoundService:_getLongestSurvivor()
	local survivors = {}

	for player in pairs(self.aliveRunners) do
		if player.Parent == Players then
			table.insert(survivors, {
				kind = "Player",
				value = player,
			})
		end
	end

	for _, bot in ipairs(self.botService:GetAliveBots()) do
		table.insert(survivors, {
			kind = "Bot",
			value = bot,
		})
	end

	if #survivors == 0 then
		return nil
	end

	return survivors[self.random:NextInteger(1, #survivors)]
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

function RoundService:_awardWinner(candidate)
	if not candidate then
		return
	end

	if candidate.kind == "Player" then
		local player = candidate.value
		local statSet = self.stats[player]
		if statSet and statSet.wins then
			statSet.wins.Value += 1
		end
		player:SetAttribute("SkyfallRole", "Winner")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
		end
	elseif candidate.kind == "Bot" then
		self.botService:SetWinner(candidate.value)
	end
end

function RoundService:_placeAllPlayersInLobby()
	local playerList = Players:GetPlayers()
	for index, player in ipairs(playerList) do
		player:SetAttribute("SkyfallRole", "Waiting")
		self:_placePlayer(
			player,
			self.arena:GetLobbySpawnCFrame(index, #playerList, false)
		)
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
	local nextMapId = self:_chooseNextMapId()
	self.lastMapId = nextMapId
	self.arena:SetMap(nextMapId)

	self.aliveRunners = {}
	self.elapsedSeconds = 0
	self.countdownSeconds = 0
	self.overtime = false
	self.winner = ""
	self.winnerCandidate = nil
	self.roundStartedAt = os.clock()
	self.phase = "Active"

	self.controller = self:_chooseController()
	if not self.controller then
		self.phase = "Waiting"
		return
	end

	local controllerPlayer = self.controller.kind == "Player" and self.controller.value or nil
	local controllerBot = self.controller.kind == "Bot" and self.controller.value or nil
	local botList = self.botService:GetBots()
	local totalContestants = #playersInRound + #botList
	local spawnIndex = 0

	for _, player in ipairs(playersInRound) do
		if player == controllerPlayer then
			player:SetAttribute("SkyfallRole", "Controller")
			self:_placePlayer(player, self.arena:GetControllerSpawnCFrame())
		else
			spawnIndex += 1
			self.aliveRunners[player] = true
			player:SetAttribute("SkyfallRole", "Runner")
			player:SetAttribute("SkyfallSurvivalTime", 0)
			self:_placePlayer(
				player,
				self.arena:GetRunnerSpawnCFrame(spawnIndex, math.max(totalContestants - 1, 1))
			)
		end
	end

	local botSpawnCFrames = {}
	for index, bot in ipairs(botList) do
		if bot ~= controllerBot then
			spawnIndex += 1
			botSpawnCFrames[index] = self.arena:GetRunnerSpawnCFrame(
				spawnIndex,
				math.max(totalContestants - 1, 1)
			)
		end
	end

	self.botService:StartRound(
		botSpawnCFrames,
		controllerBot,
		self.arena:GetControllerSpawnCFrame()
	)

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

		if self.controller and not self:_isCandidateValid(self.controller) then
			self.controller = nil
		end

		self:_updateSurvivalRecords()
		self:_broadcast()

		local aliveCount = self:_aliveRunnerCount()
		if aliveCount == 1 then
			local soleSurvivor = self:_getSoleSurvivor()
			if self:_isGrounded(soleSurvivor) then
				break
			end
		elseif aliveCount == 0 or not self.controller then
			break
		end

		task.wait(1)
	end

	if not canceled then
		local aliveCount = self:_aliveRunnerCount()
		if aliveCount == 1 then
			self.winnerCandidate = self:_getSoleSurvivor()
		elseif aliveCount == 0 and self.controller and self:_isCandidateValid(self.controller) then
			self.winnerCandidate = self.controller
		elseif aliveCount > 0 then
			self.winnerCandidate = self:_getLongestSurvivor()
		end

		if self.winnerCandidate then
			self.winner = self:_candidateName(self.winnerCandidate)
			self.nextController = self.winnerCandidate
			self:_awardWinner(self.winnerCandidate)
		else
			self.winner = "NO SURVIVORS"
			self.nextController = self.controller
		end
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
	self.controller = nil
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
