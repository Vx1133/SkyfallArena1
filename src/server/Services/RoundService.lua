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
	self.timeLeft = 0
	self.controller = nil
	self.aliveRunners = {}
	self.winner = nil
	self.roundNumber = 0
	self.lastController = nil
	self.running = false
	self.runnerSpawnIndex = 0

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.aliveRunners[player] = nil
		if self.controller == player then
			self.controller = nil
		end
		self:_broadcast()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(player)
	end

	return self
end

function RoundService:_bindPlayer(player)
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
	end
end

function RoundService:_onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)

	if self.phase == "Active" then
		if player == self.controller then
			self:_placePlayer(player, self.arena:GetControllerSpawnCFrame())
		elseif self.aliveRunners[player] then
			self.runnerSpawnIndex += 1
			self:_placePlayer(
				player,
				self.arena:GetRunnerSpawnCFrame(self.runnerSpawnIndex, math.max(self:_aliveRunnerCount(), 1))
			)
		else
			player:SetAttribute("SkyfallRole", "Spectator")
			self:_placePlayer(player, self.arena:GetLobbySpawnCFrame())
		end
	else
		self:_placePlayer(player, self.arena:GetLobbySpawnCFrame())
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

function RoundService:_broadcast()
	self.stateRemote:FireAllClients({
		phase = self.phase,
		timeLeft = self.timeLeft,
		aliveRunners = self:_aliveRunnerCount(),
		controllerName = self.controller and self.controller.Parent == Players and self.controller.DisplayName or "",
		winner = self.winner or "",
		playerCount = #Players:GetPlayers(),
		botCount = self.botService and self.botService:GetBotCount() or 0,
		roundNumber = self.roundNumber,
	})
end

function RoundService:IsActiveController(player)
	return self.phase == "Active" and self.controller == player and player.Parent == Players
end

function RoundService:IsActive()
	return self.phase == "Active"
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

function RoundService:HandleDeath(player)
	if self.phase ~= "Active" then
		return
	end

	if player == self.controller then
		self.controller = nil
		player:SetAttribute("SkyfallRole", "Spectator")
		self:_broadcast()
	elseif self.aliveRunners[player] then
		self:Eliminate(player)
	end
end

function RoundService:_eliminateFallenRunners()
	local fallen = {}

	for player in pairs(self.aliveRunners) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player.Parent or (root and root.Position.Y < Config.OUT_OF_BOUNDS_Y) then
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

function RoundService:_chooseController(playersInRound)
	local candidates = playersInRound
	if #playersInRound > 1 and self.lastController then
		candidates = {}
		for _, player in ipairs(playersInRound) do
			if player ~= self.lastController then
				table.insert(candidates, player)
			end
		end
	end

	local selected = candidates[Random.new():NextInteger(1, #candidates)]
	self.lastController = selected
	return selected
end

function RoundService:_runRound()
	local playersInRound = Players:GetPlayers()
	if #playersInRound < Config.MIN_PLAYERS then
		return
	end

	self.roundNumber += 1
	self.arena:ResetTiles()
	self.controller = self:_chooseController(playersInRound)
	self.aliveRunners = {}
	self.runnerSpawnIndex = 0
	self.winner = nil
	self.phase = "Active"

	local botCount = self.botService and self.botService:GetBotCount() or 0
	local totalRunnerCount = #playersInRound - 1 + botCount

	for _, player in ipairs(playersInRound) do
		if player == self.controller then
			player:SetAttribute("SkyfallRole", "Controller")
			self:_placePlayer(player, self.arena:GetControllerSpawnCFrame())
		else
			self.aliveRunners[player] = true
			player:SetAttribute("SkyfallRole", "Runner")
			self.runnerSpawnIndex += 1
			self:_placePlayer(
				player,
				self.arena:GetRunnerSpawnCFrame(self.runnerSpawnIndex, math.max(totalRunnerCount, 1))
			)
		end
	end

	local botSpawnCFrames = {}
	for index = 1, botCount do
		self.runnerSpawnIndex += 1
		botSpawnCFrames[index] = self.arena:GetRunnerSpawnCFrame(
			self.runnerSpawnIndex,
			math.max(totalRunnerCount, 1)
		)
	end

	if self.botService then
		self.botService:StartRound(botSpawnCFrames)
	end

	local remaining = Config.ROUND_SECONDS
	while remaining > 0 do
		self.timeLeft = remaining
		self:_eliminateFallenRunners()
		self:_broadcast()

		if not self.controller or self:_aliveRunnerCount() == 0 then
			break
		end

		task.wait(1)
		remaining -= 1
	end

	self.timeLeft = 0
	if self.controller and self.controller.Parent == Players and self:_aliveRunnerCount() == 0 then
		self.winner = "CONTROLLER"
	else
		self.winner = "RUNNERS"
	end

	self.phase = "Results"
	for seconds = Config.RESULTS_SECONDS, 1, -1 do
		self.timeLeft = seconds
		self:_broadcast()
		task.wait(1)
	end

	self.phase = "Waiting"
	self.timeLeft = 0
	self.controller = nil
	self.aliveRunners = {}
	self.winner = nil
	self.arena:ResetTiles()

	if self.botService then
		self.botService:SendToLobby()
	end

	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("SkyfallRole", "Waiting")
		self:_placePlayer(player, self.arena:GetLobbySpawnCFrame())
	end
end

function RoundService:_runLoop()
	while true do
		self.phase = "Waiting"
		self.timeLeft = 0
		self:_broadcast()

		while #Players:GetPlayers() < Config.MIN_PLAYERS do
			self:_broadcast()
			task.wait(1)
		end

		self.phase = "Intermission"
		local canceled = false
		for seconds = Config.INTERMISSION_SECONDS, 1, -1 do
			if #Players:GetPlayers() < Config.MIN_PLAYERS then
				canceled = true
				break
			end
			self.timeLeft = seconds
			self:_broadcast()
			task.wait(1)
		end

		if not canceled and #Players:GetPlayers() >= Config.MIN_PLAYERS then
			self:_runRound()
		end

		task.wait(1)
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
