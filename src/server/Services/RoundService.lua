local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 8)
local Config = require(sharedFolder:WaitForChild("GameConfig", 8))
local MapRotation = require(sharedFolder:WaitForChild("MapRotation", 8))
local DebugControllerPolicy = require(sharedFolder:WaitForChild("DebugControllerPolicy", 8))
local PilotOptInPolicy = require(sharedFolder:WaitForChild("PilotOptInPolicy", 8))

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(arenaService, stateRemote, botService, playRemote, pilotPriority)
	local self = setmetatable({}, RoundService)
	self.arena = arenaService
	self.stateRemote = stateRemote
	self.botService = botService
	self.playRemote = playRemote
	self.pilotPriority = pilotPriority
	self.winnerCandidates = {}
	self.readyPlayers = {}
	self.roundHumanCount = 0
	self.phase = "Waiting"
	self.elapsedSeconds = 0
	self.countdownSeconds = 0
	self.aliveRunners = {}
	self.winner = ""
	self.winnerCandidate = nil
	self.controller = nil
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
			self:_recordSurvival({ kind = "Bot", value = diedBot })
			self:_broadcast()
		end
	end
	if self.playRemote then
		self.playRemote.OnServerEvent:Connect(function(player, action, enabled)
			if action == "PilotOptIn" then
				if typeof(enabled) == "boolean" then
					self:RequestPilotOptIn(player, enabled)
				end
				return
			end
			self:RequestPlay(player)
		end)
	end
	self.lastMapId = 0

	Players.RespawnTime = Config.RESPAWN_TIME

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if self.debugControllerPlayer == player then
			self:_restoreAfterDebugControllerLeaves(player)
		end
		self:_setArenaStreamingFocus(player, false)
		self:_recordSurvival({ kind = "Player", value = player }, false)
		self.aliveRunners[player] = nil
		if self.pilotPriority then
			self.pilotPriority:Remove(player)
		end
		self.readyPlayers[player] = nil
		self.stats[player] = nil
		self.roundRunners[player] = nil
		self.survivalTimes[player] = nil
		self.characterSerial[player] = nil
		self.debugAutoReady[player] = nil
		if
			self.debugPreviousController
			and self.debugPreviousController.kind == "Player"
			and self.debugPreviousController.value == player
		then
			self.debugPreviousController = nil
		end
		player.ReplicationFocus = nil

		if self.controller and self.controller.kind == "Player" and self.controller.value == player then
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
	if self.pilotPriority then
		self.pilotPriority:Initialize(player)
	end
	player:SetAttribute("SkyfallRole", "Waiting")
	player:SetAttribute("SkyfallReady", false)
	player:SetAttribute("SkyfallPilotOptIn", false)
	player:SetAttribute("SkyfallAircraftControlActive", false)
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

function RoundService:RequestPlay(player)
	if not player or player.Parent ~= Players or self.phase ~= "Waiting" then
		return false
	end
	if self.readyPlayers[player] then
		return true
	end
	-- Each newly queued round starts with the normal character choice.
	-- The aircraft icon can be activated after PLAY, before the intermission ends.
	player:SetAttribute("SkyfallPilotOptIn", false)
	player:SetAttribute("SkyfallAircraftControlActive", false)
	self.readyPlayers[player] = true
	player:SetAttribute("SkyfallReady", true)
	self:_broadcast()
	return true
end

function RoundService:RequestPilotOptIn(player, enabled)
	if not player or player.Parent ~= Players or typeof(enabled) ~= "boolean" then
		return false
	end

	local ready = self.readyPlayers[player] == true
	local waitingOrIntermission = self.phase == "Waiting" or self.phase == "Intermission"
	if not ready or not waitingOrIntermission then
		return false
	end

	player:SetAttribute("SkyfallPilotOptIn", enabled)
	return true
end

function RoundService:_isDebugControllerRequested(player)
	local enabledAttribute = (player and player:GetAttribute("SkyfallDebugDroneEnabled")) :: boolean?
	return DebugControllerPolicy.IsEnabled(self.debugControllerPlayer, player, enabledAttribute)
end

function RoundService:_clearStaleDebugControllerRequest(player)
	if not player or self.debugControllerPlayer ~= player or self:_isDebugControllerRequested(player) then
		return false
	end

	self.debugControllerPlayer = nil
	if self.debugAutoReady[player] then
		self.debugAutoReady[player] = nil
		self.readyPlayers[player] = nil
		if player.Parent == Players then
			player:SetAttribute("SkyfallReady", false)
		end
	end
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
	if self.controller and self.controller.kind == "Player" and self.controller.value == player then
		self.debugPreviousController = { kind = "Player", value = player }
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
		self:_recordSurvival({ kind = "Player", value = player }, false)
		self.aliveRunners[player] = nil
		self.roundRunners[player] = nil
		self.survivalTimes[player] = nil
		self.roundRunnerCount = math.max(0, self.roundRunnerCount - 1)
	end

	self:_setArenaStreamingFocus(player, false)
	player:SetAttribute("SkyfallRole", "Controller")
	self:_setPlayerControllerHidden(player, true)
	if self.pilotPriority then
		self.pilotPriority:RecordController(player)
	end
	if self.onControllerStarted then
		self.onControllerStarted(player)
	end
	self.controller = { kind = "Player", value = player }
	self:_broadcast()
	return true
end

function RoundService:_restoreDebugController(player)
	if not self.controller or self.controller.kind ~= "Player" or self.controller.value ~= player then
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
	if previous and self:_isCandidateValid(previous) then
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

function RoundService:_restoreAfterDebugControllerLeaves(player)
	if not player or self.debugControllerPlayer ~= player then
		return false
	end

	local wasActiveController = self.controller and self.controller.kind == "Player" and self.controller.value == player
	local previous = self.debugPreviousController

	self.debugControllerPlayer = nil
	self.debugPreviousController = nil
	self.debugAutoReady[player] = nil
	self.readyPlayers[player] = nil

	if not wasActiveController then
		return true
	end

	local previousIsDepartingPlayer = previous and previous.kind == "Player" and previous.value == player
	if previous and not previousIsDepartingPlayer and self:_isCandidateValid(previous) then
		if previous.kind == "Player" then
			self:_setArenaStreamingFocus(previous.value, false)
			previous.value:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(previous.value, true, nil)
		elseif previous.kind == "Bot" and self.botService then
			self.botService:SetController(previous.value, true)
		end
		self.controller = previous
	else
		self.controller = nil
	end

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
		if
			self.phase == "Active"
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
	local playersToReset = {}
	for _, player in ipairs(Players:GetPlayers()) do
		playersToReset[player] = true
	end
	-- Also include queued entries while keeping this method testable with mock
	-- Player objects in the cloud smoke harness.
	for player in pairs(self.readyPlayers) do
		if player.Parent == Players then
			playersToReset[player] = true
		end
	end

	for player in pairs(playersToReset) do
		if self.readyPlayers[player] then
			player:SetAttribute("SkyfallReady", false)
		end
		-- Clear stale aircraft selection/control on every human, including users
		-- who were in the lobby but did not join this round.
		player:SetAttribute("SkyfallPilotOptIn", false)
		player:SetAttribute("SkyfallAircraftControlActive", false)
	end
	self.readyPlayers = {}
	self.roundHumanCount = 0

	-- Owner debug control is a one-round manual test override, never a persistent
	-- auto-ready state. The owner must explicitly enable it again for another round.
	local debugPlayer = self.debugControllerPlayer
	if debugPlayer and debugPlayer.Parent == Players then
		debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", false)
	end
	self.debugControllerPlayer = nil
	self.debugPreviousController = nil
	self.debugAutoReady = {}
end

function RoundService:_setPlayerControllerHidden(player, hidden, characterOverride)
	player:SetAttribute("SkyfallAircraftControlActive", hidden == true)

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
		if
			player.Parent == Players
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
	while
		not character.Parent
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

	if player.Parent ~= Players or player.Character ~= character or self.characterSerial[player] ~= serial then
		return
	end

	local restoredStaleDebugController = false
	if
		self.phase == "Active"
		and self.controller
		and self.controller.kind == "Player"
		and self.controller.value == player
		and self.debugControllerPlayer == player
		and not self:_isDebugControllerRequested(player)
	then
		self:_clearStaleDebugControllerRequest(player)
		restoredStaleDebugController = self:_restoreDebugController(player)
	end

	if self.phase == "Active" then
		if self.controller and self.controller.kind == "Player" and self.controller.value == player then
			self:_setArenaStreamingFocus(player, false)
			player:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(player, true, character)
		elseif not restoredStaleDebugController then
			if self.aliveRunners[player] then
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
		if
			not currentCharacter
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
		return bot and bot.model and bot.model.Parent and bot.humanoid and bot.humanoid.Health > 0
	end

	return false
end

function RoundService:_chooseNextMapId()
	return MapRotation.GetMapId(self.roundNumber, Config.MAP_COUNT)
end

function RoundService:_chooseController(readyPlayerOverride)
	local readyPlayers = readyPlayerOverride or self:_getReadyPlayers()

	-- The owner-only debug request is an explicit manual override for this round.
	local debugPlayer = self.debugControllerPlayer
	if debugPlayer and self:_isDebugControllerRequested(debugPlayer) and self.readyPlayers[debugPlayer] then
		if self.pilotPriority then
			self.pilotPriority:RecordController(debugPlayer)
		end
		return { kind = "Player", value = debugPlayer }
	elseif debugPlayer then
		self:_clearStaleDebugControllerRequest(debugPlayer)
	end

	local controllerKind, candidates = PilotOptInPolicy.ResolveCandidates(
		readyPlayers,
		self.botService and self.botService:GetBots() or {},
		function(candidate)
			return candidate.Parent == Players
				and self.readyPlayers[candidate] == true
				and candidate:GetAttribute("SkyfallPilotOptIn") == true
		end,
		function(bot)
			return self:_isCandidateValid({ kind = "Bot", value = bot })
		end
	)

	if controllerKind == "Player" then
		local selectedPlayer = nil
		if self.pilotPriority then
			selectedPlayer = self.pilotPriority:ChooseController(candidates)
		end
		if not selectedPlayer then
			selectedPlayer = candidates[self.random:NextInteger(1, #candidates)]
		end
		return { kind = "Player", value = selectedPlayer }
	elseif controllerKind == "Bot" then
		return {
			kind = "Bot",
			value = candidates[self.random:NextInteger(1, #candidates)],
		}
	end

	-- No valid bot and no explicitly opted-in human: fail closed. Never convert
	-- the only human into the aircraft controller as a fallback.
	return nil
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

function RoundService:IsAliveRunner(player)
	return self.phase == "Active" and player ~= nil and player.Parent == Players and self.aliveRunners[player] == true
end

function RoundService:IsWaiting()
	return self.phase == "Waiting"
end

function RoundService:_broadcast()
	local botCount = self.botService and self.botService:GetBotCount() or 0
	local allHumanCount = #Players:GetPlayers()
	local remainingPlayers = self:_aliveRunnerCount()
	local remainingSeconds = self.phase == "Active" and math.max(0, Config.ROUND_SECONDS - self.elapsedSeconds)
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
		winners = self:_getWinnerDetails(),
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

	local wasController = self.controller and self.controller.kind == "Player" and self.controller.value == player
	local wasRunner = self.aliveRunners[player]
	if not wasController and not wasRunner then
		return
	end

	if wasController then
		self.controller = nil
	else
		self:_recordSurvival({ kind = "Player", value = player })
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

	self:_recordSurvival({ kind = "Player", value = player })
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

function RoundService:_getLivingHumanRunners()
	local survivors = {}
	for player in pairs(self.aliveRunners) do
		local isPresent = player.Parent == Players
		local isRunner = isPresent and player:GetAttribute("SkyfallRole") == "Runner"
		local character = isRunner and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local isAlive = isRunner and character ~= nil and humanoid ~= nil and humanoid.Health > 0
		if isAlive then
			table.insert(survivors, player)
		end
	end
	table.sort(survivors, function(left, right)
		return left.Name < right.Name
	end)
	return survivors
end

function RoundService:_getSoleSurvivor()
	local survivors = {}

	-- Human candidates must pass the same live-character and Runner-role checks
	-- used by timeout co-winner resolution.
	for _, player in ipairs(self:_getLivingHumanRunners()) do
		table.insert(survivors, {
			kind = "Player",
			value = player,
		})
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

	return humanoid and humanoid.Health > 0 and humanoid.FloorMaterial ~= Enum.Material.Air
end

function RoundService:_getLongestSurvivor()
	local bestTime = -1
	local bestCandidates = {}

	for value, candidate in pairs(self.roundRunners) do
		local isValid = false
		if candidate.kind == "Player" then
			local isPresent = self.aliveRunners[value] == true and value.Parent == Players
			local isRunner = isPresent and value:GetAttribute("SkyfallRole") == "Runner"
			local character = isRunner and value.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			isValid = isRunner and character ~= nil and humanoid ~= nil and humanoid.Health > 0
		elseif candidate.kind == "Bot" then
			isValid = value.alive == true
				and value.model
				and value.model.Parent
				and value.humanoid
				and value.humanoid.Health > 0
				and value.model:GetAttribute("SkyfallRole") == "Runner"
		end

		if isValid then
			local survivalTime = self.survivalTimes[value] or 0
			if survivalTime > bestTime then
				bestTime = survivalTime
				bestCandidates = { candidate }
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

function RoundService:_getTimeoutWinners()
	local humanWinners = {}
	for _, player in ipairs(self:_getLivingHumanRunners()) do
		table.insert(humanWinners, { kind = "Player", value = player })
	end
	if #humanWinners > 0 then
		return humanWinners
	end

	-- If no human Runner remains, only a currently living bot may be the fallback.
	local longestSurvivor = self:_getLongestSurvivor()
	return longestSurvivor and { longestSurvivor } or {}
end

function RoundService:_getWinnerDetails()
	local details = {}
	for _, candidate in ipairs(self.winnerCandidates or {}) do
		local isController = self.controller
			and self.controller.kind == candidate.kind
			and self.controller.value == candidate.value
		local role = candidate.winningRole
			or (isController and "Controller")
			or (candidate.kind == "Bot" and "Bot Runner" or "Runner")
		table.insert(details, {
			name = self:_candidateName(candidate),
			role = role,
		})
	end
	return details
end

function RoundService:_resolveWinners(aliveCount)
	local winners = {}
	if self.elapsedSeconds >= Config.ROUND_SECONDS then
		winners = self:_getTimeoutWinners()
	else
		local livingHumans = self:_getLivingHumanRunners()
		if #livingHumans == 1 then
			table.insert(winners, { kind = "Player", value = livingHumans[1] })
		elseif aliveCount == 1 then
			local soleSurvivor = self:_getSoleSurvivor()
			if soleSurvivor then
				table.insert(winners, soleSurvivor)
			end
		elseif aliveCount > 1 then
			local longestSurvivor = self:_getLongestSurvivor()
			if longestSurvivor then
				table.insert(winners, longestSurvivor)
			end
		end
	end

	-- The active Controller wins only when no eligible Runner remains.
	if #winners == 0 and self.controller and self:_isCandidateValid(self.controller) then
		table.insert(winners, self.controller)
	end

	self.winnerCandidates = winners
	self.winnerCandidate = winners[1]
	local winnerNames = {}
	for _, candidate in ipairs(winners) do
		local isController = self.controller
			and self.controller.kind == candidate.kind
			and self.controller.value == candidate.value
		candidate.winningRole = isController and "Controller" or (candidate.kind == "Bot" and "Bot Runner" or "Runner")
		table.insert(winnerNames, self:_candidateName(candidate))
	end

	if #winners > 0 then
		self.winner = table.concat(winnerNames, ", ")
		self:_awardWinners(winners)
	else
		self.winner = "NO WINNER"
	end
	return winners
end

function RoundService:_recordSurvival(candidate, awardPriority)
	if not candidate or not candidate.value or not self.roundRunners[candidate.value] then
		return
	end
	local elapsed = math.max(0, math.floor(os.clock() - self.roundStartedAt))
	self.survivalTimes[candidate.value] =
		math.max(self.survivalTimes[candidate.value] or 0, math.min(elapsed, Config.ROUND_SECONDS))
	if candidate.kind == "Player" and awardPriority ~= false and self.pilotPriority then
		self.pilotPriority:AwardElimination(candidate.value, self.roundNumber, elapsed)
	end
end

function RoundService:_updateSurvivalRecords()
	local elapsed = math.min(math.max(0, math.floor(os.clock() - self.roundStartedAt)), Config.ROUND_SECONDS)
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

function RoundService:_awardWinners(candidates)
	for _, candidate in ipairs(candidates) do
		if candidate.kind == "Player" then
			local player = candidate.value
			if player.Parent == Players then
				local isCurrentController = self.controller
					and self.controller.kind == "Player"
					and self.controller.value == player
				local statSet = self.stats[player]
				if statSet and statSet.wins then
					statSet.wins.Value += 1
				end
				player:SetAttribute("SkyfallRole", "Winner")
				if isCurrentController then
					self:_placePlayer(player, self:_lobbySpawnForPlayer(player))
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					root.Anchored = true
				end
				if self.pilotPriority then
					self.pilotPriority:AwardWinner(player, self.roundNumber)
				end
			end
		elseif candidate.kind == "Bot" then
			self.botService:SetWinner(candidate.value)
		end
	end
end

function RoundService:_placeAllPlayersInLobby()
	local playerList = Players:GetPlayers()
	for index, player in ipairs(playerList) do
		self:_setArenaStreamingFocus(player, true)
		player:SetAttribute("SkyfallRole", "Waiting")
		self:_placePlayer(player, self.arena:GetLobbySpawnCFrame(index, #playerList, false))
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

	-- Resolve the controller before entering Active or changing any human state.
	local selectedController = self:_chooseController(playersInRound)
	for _, player in ipairs(playersInRound) do
		player:SetAttribute("SkyfallPilotOptIn", false)
	end
	if not selectedController then
		self.phase = "Waiting"
		self.controller = nil
		self:_clearReadyPlayers()
		self:_broadcast()
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
	self.debugPreviousController = nil
	self.roundStartedAt = os.clock()
	self.controller = selectedController
	self.phase = "Active"
	
	local controllerPlayer = self.controller.kind == "Player" and self.controller.value or nil
	local controllerBot = self.controller.kind == "Bot" and self.controller.value or nil
	local botList = self.botService:GetBots()
	self.roundHumanCount = #playersInRound
	self.winnerCandidates = {}
	local totalContestants = #playersInRound + #botList
	local runnerCount = math.max(0, totalContestants - 1)
	self.roundRunnerCount = runnerCount
	local spawnIndex = 0

	for _, player in ipairs(playersInRound) do
		if player == controllerPlayer then
			self:_setArenaStreamingFocus(player, false)
			player:SetAttribute("SkyfallRole", "Controller")
			self:_setPlayerControllerHidden(player, true)
			if self.onControllerStarted then
				self.onControllerStarted(player)
			end
		else
			self:_setArenaStreamingFocus(player, false)
			spawnIndex += 1
			self.aliveRunners[player] = true
			self.roundRunners[player] = { kind = "Player", value = player }
			self.survivalTimes[player] = 0
			player:SetAttribute("SkyfallRole", "Runner")
			player:SetAttribute("SkyfallSurvivalTime", 0)
			if self.onRunnerStarted then
				self.onRunnerStarted(player)
			end
			self:_placePlayer(player, self.arena:GetRunnerSpawnCFrame(spawnIndex, math.max(runnerCount, 1)))
		end
	end

	local botSpawnCFrames = {}
	for index, bot in ipairs(botList) do
		if bot ~= controllerBot then
			spawnIndex += 1
			botSpawnCFrames[index] = self.arena:GetRunnerSpawnCFrame(spawnIndex, math.max(runnerCount, 1))
			self.roundRunners[bot] = { kind = "Bot", value = bot }
			self.survivalTimes[bot] = 0
		end
	end

	self.botService:StartRound(botSpawnCFrames, controllerBot)

	self:_broadcast()

	local canceled = false
	while self.phase == "Active" do
		if #Players:GetPlayers() == 0 then
			canceled = true
			break
		end

		self.elapsedSeconds = math.min(math.floor(os.clock() - self.roundStartedAt), Config.ROUND_SECONDS)
		self:_updateSurvivalRecords()
		self:_eliminateFallenRunners()

		if self.controller and not self:_isCandidateValid(self.controller) then
			self.controller = nil
		end

		self:_broadcast()

		local aliveCount = self:_aliveRunnerCount()
		local livingHumans = self:_getLivingHumanRunners()
		if self.elapsedSeconds >= Config.ROUND_SECONDS then
			break
		elseif aliveCount == 0 or not self.controller then
			break
		elseif #livingHumans == 1 then
			local soleHuman = { kind = "Player", value = livingHumans[1] }
			if self:_isGrounded(soleHuman) then
				break
			end
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
		self:_resolveWinners(self:_aliveRunnerCount())
	end

	if self.onRoundEnded then
		self.onRoundEnded()
	end
	self.phase = canceled and "Waiting" or "Results"
	self:_resetArenaAfterRound()
	self.elapsedSeconds = math.min(math.floor(os.clock() - self.roundStartedAt), Config.ROUND_SECONDS)

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

		-- A normal round needs one fully created bot controller. Avatar creation is
		-- now asynchronous, so keep the game responsive while the first rig loads.
		-- A human can still proceed by explicitly opting into aircraft control.
		local hasReadyBot = not self.botService
			or self.botService:GetReadyBotCount() > 0
		local hasManualPilot = false
		if not hasReadyBot then
			for _, readyPlayer in ipairs(self:_getReadyPlayers()) do
				if readyPlayer:GetAttribute("SkyfallPilotOptIn") == true then
					hasManualPilot = true
					break
				end
			end
		end

		if not hasReadyBot and not hasManualPilot then
			self.phase = "Waiting"
			self.countdownSeconds = 0
			self:_broadcast()
			task.wait(0.5)
		else
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
