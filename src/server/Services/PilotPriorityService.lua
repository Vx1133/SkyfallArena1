local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("GameConfig", 8))

local PilotPriorityService = {}
PilotPriorityService.__index = PilotPriorityService

function PilotPriorityService.new(random)
	local self = setmetatable({}, PilotPriorityService)
	self.random = random or Random.new()
	self.scores = {}
	self.lastControllerAt = {}
	self.rewardedRound = {}
	return self
end

function PilotPriorityService:_publish(player)
	if player and player.Parent == Players then
		player:SetAttribute("SkyfallPilotPriority", self.scores[player] or 0)
	end
end

function PilotPriorityService:Initialize(player)
	if not player or player.Parent ~= Players then
		return 0
	end
	if self.scores[player] == nil then
		self.scores[player] = 0
	end
	self:_publish(player)
	return self.scores[player]
end

function PilotPriorityService:GetScore(player)
	return self.scores[player] or 0
end

function PilotPriorityService:_award(player, roundNumber, amount)
	if not player
		or player.Parent ~= Players
		or typeof(roundNumber) ~= "number"
		or self.rewardedRound[player] == roundNumber
	then
		return false
	end

	self.rewardedRound[player] = roundNumber
	if amount <= 0 then
		return true
	end

	self.scores[player] = math.clamp((self.scores[player] or 0) + amount, 0, 100)
	self:_publish(player)
	return true
end

function PilotPriorityService:AwardElimination(player, roundNumber, elapsedSeconds)
	local reward = elapsedSeconds >= Config.PILOT_PRIORITY_ELIMINATION_THRESHOLD_SECONDS and 5 or 0
	return self:_award(player, roundNumber, reward)
end

function PilotPriorityService:AwardWinner(player, roundNumber)
	return self:_award(player, roundNumber, 10)
end

function PilotPriorityService:RecordController(player)
	if not player or player.Parent ~= Players then
		return false
	end
	self.scores[player] = 0
	self.lastControllerAt[player] = os.clock()
	self:_publish(player)
	return true
end

function PilotPriorityService:ChooseController(readyPlayers)
	local highestScore = -1
	local longestWait = math.huge
	local tied = {}

	for _, player in ipairs(readyPlayers) do
		if player and player.Parent == Players then
			local score = self.scores[player] or 0
			local lastControlledAt = self.lastControllerAt[player] or 0
			if score > highestScore or (score == highestScore and lastControlledAt < longestWait) then
				highestScore = score
				longestWait = lastControlledAt
				tied = {player}
			elseif score == highestScore and lastControlledAt == longestWait then
				table.insert(tied, player)
			end
		end
	end

	if #tied == 0 then
		return nil
	end

	local selected = tied[self.random:NextInteger(1, #tied)]
	self:RecordController(selected)
	return selected
end

function PilotPriorityService:Remove(player)
	self.scores[player] = nil
	self.lastControllerAt[player] = nil
	self.rewardedRound[player] = nil
end

return PilotPriorityService
