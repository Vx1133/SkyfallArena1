--!strict
-- Centralized, engine-agnostic design tokens for the lobby and Cyberpunk map.
-- RGB values stay numeric so Lune can validate the palette without Roblox rendering.

local Profile = {
	Lobby = {
		PlatformSize = 120,
		PlayerSpawnRadius = 42,
		BotSpawnRadius = 52,
	},

	Cyberpunk = {
		PrimaryTile = { 233, 242, 252 },
		AlternateTile = { 215, 229, 246 },
		Structure = { 67, 114, 181 },
		Roof = { 242, 247, 253 },
		Accent = { 28, 194, 227 },
		Secondary = { 14, 30, 54 },
		Silver = { 207, 221, 238 },
		Navy = { 12, 24, 45 },
		-- Warm champagne stone replaces the conflicting green Earth accent.
		Earth = { 194, 163, 111 },
	},
}

return Profile
