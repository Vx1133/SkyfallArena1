--!strict
-- Centralized, engine-agnostic world design tokens.
-- Map palettes are intentionally distinct; the lobby contributes only the surface finish.

local Profile = {
	Lobby = {
		PlatformSize = 120,
		PlayerSpawnRadius = 42,
		BotSpawnRadius = 52,
	},

	Classic = {
		PrimaryTile = { 79, 170, 66 },
		AlternateTile = { 91, 178, 72 },
		Bark = { 103, 72, 48 },
		Root = { 126, 88, 55 },
		CanopyDeep = { 31, 101, 49 },
		CanopyMid = { 48, 137, 61 },
		CanopyLight = { 80, 161, 73 },
		Stone = { 112, 111, 91 },
		StoneShadow = { 78, 84, 72 },
		Vine = { 69, 121, 54 },
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
		Earth = { 194, 163, 111 },
	},
}

return Profile
