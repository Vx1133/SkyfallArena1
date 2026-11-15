local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(arenaService, stateRemote, botService, playRemote)
	local self = setmetatable({}, RoundService)
	self.arena = arenaService
	self.stateRemote = stateRemote
	self.botService = botService
	self.playRemote = playRemote
	self.readyPlayers = {}
	self.roundHumanCount = 0
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
	self.running = false
	self.stats = {}
	self.survivalTimes = {}
	self.roundRunners = {}
	self.roundRunnerCount = 0
	self.random = Random.new()

	if self.botService then
		self.botService.onBotDied = function(diedBot)
			self:_recordSurvival({kind = "Bot", value = diedBot})
		end
	end
	if self.playRemote then
		self.playRemote.OnServerEvent:Connect(function(player)
			self:RequestPlay(player)
		end)
	end
	self.lastMapId = 0

	Players.RespawnTime = Config.RESPAWN_TIME

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_recordSurvival({kind = "Player", value = player})
		self.aliveRunners[player] = nil
		self.readyPlayers[player] = nil
		self.stats[player] = nil
		self.roundRunners[player] = nil
		self.survivalTimes[player] = nil

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
	player:SetAttribute("SkyfallReady", false)
	player:SetAttribute("SkyfallSurvivalTime", 0)

	player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(player, character)
	end)

	if player.Character then
		task.defer(self._onCharacterAdded, self, player, player.Character)
	end
end

function RoundService:_readyPlayerCount()
	local count = 0
	for player in pairs(self.readyPlayers) do
		if player.Parent == Players then
			count += 1
		end
	end
	return count
end

function RoundService:_getReadyPlayers()
	local ready = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if self.readyPlayers[player] and player.Parent == Players then
			table.insert(ready, player)
		end
	end
	return ready
end

function RoundService:RequestPlay(player)
	if not player or player.Parent ~= Players or self.phase ~= "Waiting" then
		return false
	end
	if self.readyPlayers[player] then
		return true
	end
	self.readyPlayers[player] = true
	player:SetAttribute("SkyfallReady", true)
	self:_broadcast()
	return true
end

function RoundService:_clearReadyPlayers()
	for player in pairs(self.readyPlayers) do
		if player.Parent == Players then
			player:SetAttribute("SkyfallReady", false)
		end
	end
	self.readyPlayers = {}
	self.roundHumanCount = 0
end

function RoundService:_setPlayerControllerHidden(player, hidden)
	local character = player.Character
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
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

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = hidden
	end
	if hidden then
		character:PivotTo(CFrame.new(Config.CONTROLLER_HIDDEN_POSITION))
	end
end

function RoundService:_placePlayer(player, spawnCFrame)
	self:_setPlayerControllerHidden(player, false)
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
			self:_setPlayerControllerHidden(player, true)
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
	return 1
end

function RoundService:_chooseController()
	-- Give a solo human a fair first test as a runner, with a bot piloting the drone.
	if self.roundNumber == 1 and #self:_getReadyPlayers() == 1 then
		local botCandidates = {}
		for _, bot in ipairs(self.botService:GetBots()) do
			if self:_isCandidateValid({kind = "Bot", value = bot}) then
				table.insert(botCandidates, {kind = "Bot", value = bot})
			end
		end
		if #botCandidates > 0 then
			return botCandidates[self.random:NextInteger(1, #botCandidates)]
		end
	end

	if self:_isCandidateValid(self.nextController) then
		local selected = self.nextController
		self.nextController = nil
		return selected
	end

	self.nextController = nil
	local candidates = {}

	for _, player in ipairs(self:_getReadyPlayers()) do
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

function RoundService:_broadcast()
	local botCount = self.botService and self.botService:GetBotCount() or 0
	local totalPlayers = #Players:GetPlayers() + botCount
	local remainingPlayers = self:_aliveRunnerCount()
	local remainingSeconds = self.phase == "Active"
		and math.max(0, Config.ROUND_SECONDS - self.elapsedSeconds)
		or self.countdownSeconds

	self.stateRemote:FireAllClients({
		phase = self.phase,
		elapsedSeconds = self.elapsedSeconds,
		remainingSeconds = remainingSeconds,
		countdownSeconds = self.countdownSeconds,
		aliveRunners = remainingPlayers,
		remainingPlayers = remainingPlayers,
		playerCount = totalPlayers,
		botCount = botCount,
		eliminatedPlayers = math.max(0, self.roundRunnerCount - remainingPlayers),
		winner = self.winner,
		controllerName = self:_candidateName(self.controller),
		controllerKind = self.controller and self.controller.kind or "",
		roundNumber = self.roundNumber,
		overtime = false,
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
		self:_recordSurvival({kind = "Player", value = player})
		self.aliveRunners[player] = nil
		self:_moveEliminatedPlayerToLobby(player)
		self:_broadcast()
	end
end

function RoundService:Eliminate(player)
	if not self.aliveRunners[player] then
		return
	end

	self:_recordSurvival({kind = "Player", value = player})
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
	local bestTime = -1
	local bestCandidates = {}

	for value, candidate in pairs(self.roundRunners) do
		local isValid = candidate.kind == "Player"
			and value.Parent == Players
			or candidate.kind == "Bot"
			and value.model
			and value.model.Parent

		if isValid then
			local survivalTime = self.survivalTimes[value] or 0
			if survivalTime > bestTime then
				bestTime = survivalTime
				bestCandidates = {candidate}
			elseif survivalTime == bestTime then
				table.insert(bestCandidates, candidate)
			end
		end
	end

	if #bestCandidates == 0 then
		return nil
	end
	return bestCandidates[self.random:NextInteger(1, #bestCandidates)]
end

function RoundService:_recordSurvival(candidate)
	if not candidate or not candidate.value or not self.roundRunners[candidate.value] then
		return
	end
	local elapsed = math.max(0, math.floor(os.clock() - self.roundStartedAt))
	self.survivalTimes[candidate.value] = math.max(
		self.survivalTimes[candidate.value] or 0,
		math.min(elapsed, Config.ROUND_SECONDS)
	)
end

function RoundService:_updateSurvivalRecords()
	local elapsed = math.min(
		math.max(0, math.floor(os.clock() - self.roundStartedAt)),
		Config.ROUND_SECONDS
	)
	for player in pairs(self.aliveRunners) do
		if player.Parent == Players then
			self.survivalTimes[player] = math.max(self.survivalTimes[player] or 0, elapsed)
			local statSet = self.stats[player]
			if statSet and statSet.bestTime then
				statSet.bestTime.Value = math.max(statSet.bestTime.Value, elapsed)
			end
			player:SetAttribute("SkyfallSurvivalTime", elapsed)
		end
	end

	for _, bot in ipairs(self.botService:GetAliveBots()) do
		self.survivalTimes[bot] = math.max(self.survivalTimes[bot] or 0, elapsed)
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
	self.arena:SetMap(self:_chooseNextMapId())
	self.aliveRunners = {}
	self.survivalTimes = {}
	self.roundRunners = {}
	self.roundRunnerCount = 0
	self.elapsedSeconds = 0
	self.countdownSeconds = 0
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
	local runnerCount = math.max(0, totalContestants - 1)
	self.roundRunnerCount = runnerCount
	local spawnIndex = 0

	for _, player in ipairs(playersInRound) do
		if player == controllerPlayer then
			player:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(player, true)
		else
			spawnIndex += 1
			self.aliveRunners[player] = true
			self.roundRunners[player] = {kind = "Player", value = player}
			self.survivalTimes[player] = 0
			player:SetAttribute("SkyfallRole", "Runner")
			player:SetAttribute("SkyfallSurvivalTime", 0)
			self:_placePlayer(
				player,
				self.arena:GetRunnerSpawnCFrame(spawnIndex, math.max(runnerCount, 1))
			)
		end
	end

	local botSpawnCFrames = {}
	for index, bot in ipairs(botList) do
		if bot ~= controllerBot then
			spawnIndex += 1
			botSpawnCFrames[index] = self.arena:GetRunnerSpawnCFrame(
				spawnIndex,
				math.max(runnerCount, 1)
			)
			self.roundRunners[bot] = {kind = "Bot", value = bot}
			self.survivalTimes[bot] = 0
		end
	end

	self.botService:StartRound(
		botSpawnCFrames,
		controllerBot
	)

	self:_broadcast()

	local canceled = false
	while self.phase == "Active" do
		if #Players:GetPlayers() == 0 then
			canceled = true
			break
		end

		self.elapsedSeconds = math.min(
			math.floor(os.clock() - self.roundStartedAt),
			Config.ROUND_SECONDS
		)
		self:_updateSurvivalRecords()
		self:_eliminateFallenRunners()

		if self.controller and not self:_isCandidateValid(self.controller) then
			self.controller = nil
		end

		self:_broadcast()

		local aliveCount = self:_aliveRunnerCount()
		if self.elapsedSeconds >= Config.ROUND_SECONDS then
			break
		elseif aliveCount == 0 or not self.controller then
			break
		elseif aliveCount == 1 then
			local soleSurvivor = self:_getSoleSurvivor()
			if self:_isGrounded(soleSurvivor) then
				break
			end
		end

		task.wait(1)
	end

	if not canceled then
		self:_updateSurvivalRecords()
		local aliveCount = self:_aliveRunnerCount()
		if aliveCount == 1 then
			self.winnerCandidate = self:_getSoleSurvivor()
		else
			self.winnerCandidate = self:_getLongestSurvivor()
		end

		if self.winnerCandidate then
			self.winner = self:_candidateName(self.winnerCandidate)
			self.nextController = self.winnerCandidate
			self:_awardWinner(self.winnerCandidate)
		elseif self.controller and self:_isCandidateValid(self.controller) then
			self.winner = self:_candidateName(self.controller)
			self.nextController = self.controller
		else
			self.winner = "NO WINNER"
			self.nextController = nil
		end
	end

	self.phase = canceled and "Waiting" or "Results"
	self.elapsedSeconds = math.min(
		math.floor(os.clock() - self.roundStartedAt),
		Config.ROUND_SECONDS
	)

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
	self.aliveRunners = {}
	self.roundRunners = {}
	self.survivalTimes = {}
	self.roundRunnerCount = 0
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
