--!strict
-- Centralized, engine-agnostic world design tokens.
-- Sky Garden owns the palette; WaitingPlatform supplies the shared surface finish.

local Profile = {
	Lobby = {
		PlatformSize = 120,
		PlayerSpawnRadius = 42,
		BotSpawnRadius = 52,
	},

	SkyGarden = {
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

	Elements = {
		Earth = { 194, 163, 111 },
	},
}

return Profile
