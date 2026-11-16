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
	self.pilotPriority = {}
	self.lastControllerRound = {}
	self.roundRewards = {}
	self.winnerCandidates = {}
	self.bubbleGunService = nil
	self.roundNumber = 0
	self.roundStartedAt = 0
	self.running = false
	self.stats = {}
	self.survivalTimes = {}
	self.roundRunners = {}
	self.roundRunnerCount = 0
	self.characterSerial = {}
	self.arenaStreamingFocusPlayers = {}
	self.debugControllerPlayer = nil
	self.debugPreviousController = nil
	self.debugAutoReady = {}
	self.random = Random.new()

	if self.botService then
		self.botService.onBotDied = function(diedBot)
			self:_recordSurvival({kind = "Bot", value = diedBot})
			self:_broadcast()
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
		if self.bubbleGunService then
			self.bubbleGunService:ReleaseTarget(player)
		end
		self:_setArenaStreamingFocus(player, false)
		self:_recordSurvival({kind = "Player", value = player})
		self.aliveRunners[player] = nil
		self.readyPlayers[player] = nil
		self.stats[player] = nil
		self.roundRunners[player] = nil
		self.survivalTimes[player] = nil
		self.characterSerial[player] = nil
		self.debugAutoReady[player] = nil
		self.pilotPriority[player] = nil
		self.lastControllerRound[player] = nil
		self.roundRewards[player] = nil
		if self.debugControllerPlayer == player then
			self.debugControllerPlayer = nil
			self.debugPreviousController = nil
		end
		if self.debugPreviousController
			and self.debugPreviousController.kind == "Player"
			and self.debugPreviousController.value == player
		then
			self.debugPreviousController = nil
		end
		player.ReplicationFocus = nil

		if self.controller
			and self.controller.kind == "Player"
			and self.controller.value == player
		then
			self.controller = nil
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

function RoundService:_setArenaStreamingFocus(player, enabled)
	if not player then
		return false
	end

	local currentFocus = self.arenaStreamingFocusPlayers[player]
	if enabled then
		local focusPart = self.arena:GetStreamingFocusPart()
		if not focusPart or not focusPart.Parent then
			return false
		end
		if currentFocus == focusPart then
			return true
		end
		if currentFocus then
			pcall(function()
				player:RemoveReplicationFocus(currentFocus)
			end)
			self.arenaStreamingFocusPlayers[player] = nil
		end

		local success, message = pcall(function()
			player:AddReplicationFocus(focusPart)
		end)
		if not success then
			warn("Skyfall could not add arena streaming focus for " .. player.Name .. ": " .. tostring(message))
			return false
		end

		self.arenaStreamingFocusPlayers[player] = focusPart
		return true
	end

	if currentFocus then
		pcall(function()
			player:RemoveReplicationFocus(currentFocus)
		end)
		self.arenaStreamingFocusPlayers[player] = nil
	end
	return true
end

function RoundService:_bindPlayer(player)
	self:_setupStats(player)
	self.pilotPriority[player] = 0
	self.lastControllerRound[player] = -1
	player:SetAttribute("SkyfallPilotPriority", 0)
	player:SetAttribute("SkyfallRole", "Waiting")
	player:SetAttribute("SkyfallReady", false)
	player:SetAttribute("SkyfallSurvivalTime", 0)
	self.characterSerial[player] = 0
	self:_setArenaStreamingFocus(player, true)

	player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(player, character)
	end)

	if player.Character then
		task.defer(self._onCharacterAdded, self, player, player.Character)
	else
		-- CharacterAutoLoads is disabled, so the first character is loaded only after
		-- the lobby placement handler is connected.
		task.spawn(function()
			if player.Parent ~= Players or player.Character then
				return
			end
			local success, message = pcall(function()
				player:LoadCharacterAsync()
			end)
			if not success then
				warn("Skyfall initial character load failed for " .. player.Name .. ": " .. tostring(message))
			end
		end)
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

function RoundService:SetBubbleGunService(service)
	self.bubbleGunService = service
end

function RoundService:IsHumanRunner(player)
	return self.phase == "Active"
		and player ~= nil
		and player.Parent == Players
		and self.aliveRunners[player] == true
		and player:GetAttribute("SkyfallRole") == "Runner"
end

function RoundService:GetPilotPriority(player)
	return math.clamp(self.pilotPriority[player] or 0, 0, Config.PILOT_PRIORITY_MAX)
end

function RoundService:_setPilotPriority(player, amount)
	if not player or player.Parent ~= Players then
		return 0
	end
	local current = self.pilotPriority[player] or 0
	local updated = math.clamp(current + amount, 0, Config.PILOT_PRIORITY_MAX)
	self.pilotPriority[player] = updated
	if updated ~= current then
		player:SetAttribute("SkyfallPilotPriority", updated)
	end
	return updated
end

function RoundService:_recordControllerSelection(player)
	self.lastControllerRound[player] = self.roundNumber
	self:_setPilotPriority(player, -(self.pilotPriority[player] or 0))
end

function RoundService:_awardEliminationPriority(player)
	if not player or self.roundRewards[player] ~= nil then
		return false
	end
	local elapsed = math.max(0, os.clock() - self.roundStartedAt)
	if elapsed >= Config.PILOT_PRIORITY_ELIMINATION_THRESHOLD_SECONDS
		and elapsed < Config.ROUND_SECONDS
	then
		self.roundRewards[player] = "Elimination"
		self:_setPilotPriority(player, Config.PILOT_PRIORITY_ELIMINATION_POINTS)
	else
		self.roundRewards[player] = "EarlyElimination"
	end
	return true
end

function RoundService:_awardWinnerPriority(player)
	if not player or self.roundRewards[player] ~= nil then
		return false
	end
	self.roundRewards[player] = "Winner"
	self:_setPilotPriority(player, Config.PILOT_PRIORITY_WIN_POINTS)
	return true
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

function RoundService:_queueDebugPlayer(player)
	if not self.readyPlayers[player] then
		self.readyPlayers[player] = true
		self.debugAutoReady[player] = true
		player:SetAttribute("SkyfallReady", true)
	end
end

function RoundService:_movePlayerToSpectator(player)
	self:_setPlayerControllerHidden(player, false)
	self:_setArenaStreamingFocus(player, true)
	player:SetAttribute("SkyfallRole", "Spectator")
	self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
end

function RoundService:_activateDebugController(player)
	if self.phase ~= "Active" or not player or player.Parent ~= Players then
		return false
	end
	if self.controller
		and self.controller.kind == "Player"
		and self.controller.value == player
	then
		self.debugPreviousController = {kind = "Player", value = player}
		return true
	end

	local previous = self.controller
	self.debugPreviousController = previous
	if previous and previous.kind == "Player" and previous.value.Parent == Players then
		self:_movePlayerToSpectator(previous.value)
	elseif previous and previous.kind == "Bot" and self.botService then
		self.botService:SetController(previous.value, false)
	end

	if self.aliveRunners[player] then
		self:_recordSurvival({kind = "Player", value = player})
		self.aliveRunners[player] = nil
		self.roundRunners[player] = nil
		self.survivalTimes[player] = nil
		self.roundRunnerCount = math.max(0, self.roundRunnerCount - 1)
	end

	if self.bubbleGunService then
		self.bubbleGunService:RevokeTool(player)
	end
	self:_recordControllerSelection(player)
	self:_setArenaStreamingFocus(player, false)
	player:SetAttribute("SkyfallRole", "Controller")
	self:_setPlayerControllerHidden(player, true)
	self.controller = {kind = "Player", value = player}
	self:_broadcast()
	return true
end

function RoundService:_restoreDebugController(player)
	if not self.controller
		or self.controller.kind ~= "Player"
		or self.controller.value ~= player
	then
		return false
	end

	local previous = self.debugPreviousController
	self.debugPreviousController = nil
	if previous and previous.kind == "Player" and previous.value == player then
		self:_setArenaStreamingFocus(player, false)
		player:SetAttribute("SkyfallRole", "Controller")
		self:_setPlayerControllerHidden(player, true)
		self.controller = previous
		self:_broadcast()
		return true
	end

	self:_movePlayerToSpectator(player)
	if self:_isCandidateValid(previous) then
		if previous.kind == "Player" then
			self:_setArenaStreamingFocus(previous.value, false)
			previous.value:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(previous.value, true)
		elseif previous.kind == "Bot" and self.botService then
			self.botService:SetController(previous.value, true)
		end
		self.controller = previous
	else
		self.controller = nil
	end
	self:_broadcast()
	return true
end

-- AdminFlightService calls this only after its server-side owner authorization check.
function RoundService:RequestDebugController(player, enabled)
	if not player or player.Parent ~= Players or typeof(enabled) ~= "boolean" then
		return false
	end

	if enabled then
		self.debugControllerPlayer = player
		player:SetAttribute("SkyfallDebugDroneEnabled", true)
		self:_queueDebugPlayer(player)
		if self.phase == "Active" then
			return self:_activateDebugController(player)
		end
		self:_broadcast()
		return true
	end

	player:SetAttribute("SkyfallDebugDroneEnabled", false)
	if self.debugControllerPlayer == player then
		self.debugControllerPlayer = nil
		if self.phase == "Active"
			and self.controller
			and self.controller.kind == "Player"
			and self.controller.value == player
		then
			self:_restoreDebugController(player)
		end
		if self.debugAutoReady[player] then
			self.readyPlayers[player] = nil
			self.debugAutoReady[player] = nil
			player:SetAttribute("SkyfallReady", false)
		end
	end
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

	-- Preserve an enabled owner debug request for the next round.
	local debugPlayer = self.debugControllerPlayer
	if debugPlayer and debugPlayer.Parent == Players then
		self.readyPlayers[debugPlayer] = true
		self.debugAutoReady[debugPlayer] = true
		debugPlayer:SetAttribute("SkyfallReady", true)
	end
end

function RoundService:_setPlayerControllerHidden(player, hidden, characterOverride)
	if hidden then
		local aircraft = self.arena and self.arena.aircraftModel
		local focusPart = aircraft and aircraft.PrimaryPart
		player.ReplicationFocus = focusPart and focusPart.Parent and focusPart or nil
	else
		player.ReplicationFocus = nil
	end

	local character = characterOverride or player.Character
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

function RoundService:_placePlayer(player, spawnCFrame, characterOverride)
	local character = characterOverride or player.Character
	if not character or not character.Parent then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end

	self:_setPlayerControllerHidden(player, false, character)
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	character:PivotTo(spawnCFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- Let the server finish placing the new model before handing simulation back to its owner.
	task.delay(0.2, function()
		if player.Parent == Players
			and player.Character == character
			and character.Parent
			and root.Parent
			and humanoid.Health > 0
		then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
	end)

	return true
end

function RoundService:_onCharacterAdded(player, character)
	local serial = (self.characterSerial[player] or 0) + 1
	self.characterSerial[player] = serial

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		warn("Skyfall could not place a character missing its Humanoid or HumanoidRootPart")
		return
	end

	-- CharacterAdded can fire before LoadCharacterAsync parents the model to Workspace.
	-- Wait for that final engine step before trying to pivot the character.
	local parentDeadline = os.clock() + 10
	while not character.Parent
		and player.Parent == Players
		and player.Character == character
		and self.characterSerial[player] == serial
		and os.clock() < parentDeadline
	do
		task.wait()
	end
	if not character.Parent then
		warn("Skyfall character did not enter Workspace before placement timed out")
		return
	end

	if player.Parent ~= Players
		or player.Character ~= character
		or self.characterSerial[player] ~= serial
	then
		return
	end

	if self.phase == "Active" then
		if self.controller
			and self.controller.kind == "Player"
			and self.controller.value == player
		then
			self:_setArenaStreamingFocus(player, false)
			player:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(player, true, character)
		elseif self.aliveRunners[player] then
			self:_setArenaStreamingFocus(player, false)
			player:SetAttribute("SkyfallRole", "Runner")
			self:_placePlayer(
				player,
				self.arena:GetRunnerSpawnCFrame(1, math.max(self:_aliveRunnerCount(), 1)),
				character
			)
		else
			self:_setArenaStreamingFocus(player, true)
			player:SetAttribute("SkyfallRole", "Spectator")
			self:_placePlayer(player, self:_lobbySpawnForPlayer(player), character)
		end
	else
		self:_setArenaStreamingFocus(player, true)
		player:SetAttribute("SkyfallRole", "Waiting")
		self:_placePlayer(player, self:_lobbySpawnForPlayer(player), character)
	end

	if player.Character == character and self.characterSerial[player] == serial then
		humanoid.Died:Connect(function()
			if self.characterSerial[player] == serial then
				self:HandleDeath(player, character)
			end
		end)
	end
end

function RoundService:_scheduleRespawnRecovery(player, deadCharacter)
	local serial = (self.characterSerial[player] or 0) + 1
	self.characterSerial[player] = serial

	task.delay(Config.RESPAWN_TIME, function()
		if player.Parent ~= Players or self.characterSerial[player] ~= serial then
			return
		end

		local currentCharacter = player.Character
		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		if not currentCharacter
			or currentCharacter == deadCharacter
			or not currentHumanoid
			or currentHumanoid.Health <= 0
		then
			local success, message = pcall(function()
				player:LoadCharacterAsync()
			end)
			if not success then
				warn("Skyfall respawn recovery failed for " .. player.Name .. ": " .. tostring(message))
			end
		end
	end)
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
	-- Preserve the explicit owner-only debug override used by the private test workflow.
	local debugPlayer = self.debugControllerPlayer
	if debugPlayer and debugPlayer.Parent == Players and self.readyPlayers[debugPlayer] then
		self:_recordControllerSelection(debugPlayer)
		return {kind = "Player", value = debugPlayer}
	end

	local readyPlayers = self:_getReadyPlayers()

	-- A single human gets one safe Runner round before the normal pilot rotation begins.
	if self.roundNumber == 1 and #readyPlayers == 1 then
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

	-- Ready humans always outrank bots. Priority score is the primary selection key.
	if #readyPlayers > 0 then
		local highestPriority = -1
		for _, player in ipairs(readyPlayers) do
			highestPriority = math.max(highestPriority, self:GetPilotPriority(player))
		end

		local highestPriorityPlayers = {}
		for _, player in ipairs(readyPlayers) do
			if self:GetPilotPriority(player) == highestPriority then
				table.insert(highestPriorityPlayers, player)
			end
		end

		-- The oldest previous controller round has waited the longest.
		local oldestControllerRound = math.huge
		for _, player in ipairs(highestPriorityPlayers) do
			oldestControllerRound = math.min(oldestControllerRound, self.lastControllerRound[player] or -1)
		end

		local tieCandidates = {}
		for _, player in ipairs(highestPriorityPlayers) do
			if (self.lastControllerRound[player] or -1) == oldestControllerRound then
				table.insert(tieCandidates, player)
			end
		end

		local selectedPlayer = tieCandidates[self.random:NextInteger(1, #tieCandidates)]
		self:_recordControllerSelection(selectedPlayer)
		return {kind = "Player", value = selectedPlayer}
	end

	-- A bot is only a fallback when no human is eligible.
	local botCandidates = {}
	for _, bot in ipairs(self.botService:GetBots()) do
		if self:_isCandidateValid({kind = "Bot", value = bot}) then
			table.insert(botCandidates, {kind = "Bot", value = bot})
		end
	end
	if #botCandidates == 0 then
		return nil
	end
	return botCandidates[self.random:NextInteger(1, #botCandidates)]
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

function RoundService:IsWaiting()
	return self.phase == "Waiting"
end

function RoundService:_broadcast()
	local botCount = self.botService and self.botService:GetBotCount() or 0
	local allHumanCount = #Players:GetPlayers()
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
		playerCount = self.phase == "Active" and remainingPlayers or allHumanCount + botCount,
		botCount = botCount,
		readyCount = self:_readyPlayerCount(),
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
	self:_setArenaStreamingFocus(player, true)
	player:SetAttribute("SkyfallRole", "Spectator")
	self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
end

function RoundService:HandleDeath(player, deadCharacter)
	if self.phase ~= "Active" then
		self:_scheduleRespawnRecovery(player, deadCharacter or player.Character)
		return
	end

	local wasController = self.controller
		and self.controller.kind == "Player"
		and self.controller.value == player
	local wasRunner = self.aliveRunners[player]
	if not wasController and not wasRunner then
		return
	end

	if self.bubbleGunService then
		self.bubbleGunService:ReleaseTarget(player)
	end
	if wasController then
		self.controller = nil
	else
		self:_awardEliminationPriority(player)
		self:_recordSurvival({kind = "Player", value = player})
		self.aliveRunners[player] = nil
	end

	self:_setArenaStreamingFocus(player, true)
	player:SetAttribute("SkyfallRole", "Spectator")
	player.ReplicationFocus = nil
	self:_scheduleRespawnRecovery(player, deadCharacter or player.Character)
	self:_broadcast()
end

function RoundService:Eliminate(player)
	if not self.aliveRunners[player] then
		return
	end

	if self.bubbleGunService then
		self.bubbleGunService:ReleaseTarget(player)
	end
	self:_awardEliminationPriority(player)
	self:_recordSurvival({kind = "Player", value = player})
	self.aliveRunners[player] = nil
	self:_setArenaStreamingFocus(player, true)
	player:SetAttribute("SkyfallRole", "Spectator")
	player.ReplicationFocus = nil

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	self:_scheduleRespawnRecovery(player, character)
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

function RoundService:_getAliveHumanRunnerCandidates()
	local survivors = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if self.aliveRunners[player] == true and player.Parent == Players then
			table.insert(survivors, {kind = "Player", value = player})
		end
	end
	return survivors
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

function RoundService:_resolveWinnerCandidates(timerExpired)
	if timerExpired then
		local humanWinners = self:_getAliveHumanRunnerCandidates()
		if #humanWinners > 0 then
			return humanWinners
		end
	end

	local aliveCount = self:_aliveRunnerCount()
	if aliveCount == 1 then
		local soleSurvivor = self:_getSoleSurvivor()
		return soleSurvivor and {soleSurvivor} or {}
	elseif aliveCount > 1 then
		local longestSurvivor = self:_getLongestSurvivor()
		return longestSurvivor and {longestSurvivor} or {}
	end
	return {}
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
		self:_awardWinnerPriority(player)
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
		self:_setArenaStreamingFocus(player, true)
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

function RoundService:_resetArenaAfterRound()
	self.arena:ResetTiles()
end

function RoundService:_runRound()
	local playersInRound = self:_getReadyPlayers()
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
	self.winnerCandidates = {}
	self.roundRewards = {}
	self.debugPreviousController = nil
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
	self.roundHumanCount = #playersInRound
	local totalContestants = #playersInRound + #botList
	local runnerCount = math.max(0, totalContestants - 1)
	self.roundRunnerCount = runnerCount
	local spawnIndex = 0

	for _, player in ipairs(playersInRound) do
		if player == controllerPlayer then
			if self.bubbleGunService then
				self.bubbleGunService:RevokeTool(player)
			end
			self:_setArenaStreamingFocus(player, false)
			player:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(player, true)
		else
			self:_setArenaStreamingFocus(player, false)
			spawnIndex += 1
			self.aliveRunners[player] = true
			self.roundRunners[player] = {kind = "Player", value = player}
			if self.bubbleGunService then
				self.bubbleGunService:GrantRunnerTool(player)
			end
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

	if self.bubbleGunService then
		self.bubbleGunService:ReleaseAll()
	end

	if not canceled then
		self:_updateSurvivalRecords()
		local timerExpired = self.elapsedSeconds >= Config.ROUND_SECONDS
		self.winnerCandidates = self:_resolveWinnerCandidates(timerExpired)
		if #self.winnerCandidates > 0 then
			local winnerNames = {}
			local hasHumanWinner = false
			for _, candidate in ipairs(self.winnerCandidates) do
				self:_awardWinner(candidate)
				table.insert(winnerNames, self:_candidateName(candidate))
				if candidate.kind == "Player" then
					hasHumanWinner = true
				end
			end
			if hasHumanWinner and self.botService then
				self.botService:SetWinner(nil)
			end
			self.winnerCandidate = self.winnerCandidates[1]
			self.winner = table.concat(winnerNames, ", ")
		elseif self.controller and self:_isCandidateValid(self.controller) then
			-- Keep the established controller-win fallback if every Runner is eliminated.
			self.winner = self:_candidateName(self.controller)
		else
			self.winner = "NO WINNER"
		end
	end

	self.phase = canceled and "Waiting" or "Results"
	self:_resetArenaAfterRound()
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
	self.winnerCandidates = {}
	self.controller = nil
	self:_placeAllPlayersInLobby()
	self:_clearReadyPlayers()
	self:_broadcast()
end

function RoundService:_runLoop()
	while self.running do
		self.phase = "Waiting"
		self.elapsedSeconds = 0
		self.countdownSeconds = 0
		self:_broadcast()

		while self.running and self:_readyPlayerCount() == 0 do
			self:_broadcast()
			task.wait(1)
		end

		if not self.running then
			break
		end

		self.phase = "Intermission"
		local canceled = false
		for seconds = Config.INTERMISSION_SECONDS, 1, -1 do
			if self:_readyPlayerCount() == 0 then
				canceled = true
				break
			end

			self.countdownSeconds = seconds
			self:_broadcast()
			task.wait(1)
		end

		if not canceled and self:_readyPlayerCount() >= Config.MIN_PLAYERS then
			self:_runRound()
		else
			self.phase = "Waiting"
			self.countdownSeconds = 0
			self:_broadcast()
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
