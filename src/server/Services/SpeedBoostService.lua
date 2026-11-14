local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local SpeedBoostService = {}
SpeedBoostService.__index = SpeedBoostService

function SpeedBoostService.new(remote)
	local self = setmetatable({}, SpeedBoostService)
	self.remote = remote
	self.cooldownUntil = {}

	remote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		local availableAt = self.cooldownUntil[player] or 0
		if now < availableAt then
			remote:FireClient(player, "Cooldown", math.ceil(availableAt - now))
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			remote:FireClient(player, "Unavailable")
			return
		end

		self.cooldownUntil[player] = now + Config.SPEED_BOOST_COOLDOWN
		local originalSpeed = humanoid.WalkSpeed
		local token = (player:GetAttribute("SkyfallSpeedToken") or 0) + 1
		player:SetAttribute("SkyfallSpeedToken", token)
		humanoid.WalkSpeed = Config.SPEED_BOOST_WALK_SPEED

		remote:FireClient(
			player,
			"Activated",
			Config.SPEED_BOOST_DURATION,
			Config.SPEED_BOOST_COOLDOWN
		)

		task.delay(Config.SPEED_BOOST_DURATION, function()
			if player.Parent ~= Players then
				return
			end
			if player:GetAttribute("SkyfallSpeedToken") ~= token then
				return
			end

			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.WalkSpeed = originalSpeed
			end

			local remaining = math.max(0, (self.cooldownUntil[player] or 0) - os.clock())
			remote:FireClient(player, "Finished", remaining)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.cooldownUntil[player] = nil
	end)

	return self
end

return SpeedBoostService
