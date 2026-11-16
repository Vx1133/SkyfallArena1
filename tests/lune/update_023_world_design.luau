--!strict
-- Pure Luau regression tests for Update #23 lobby scale and Cyberpunk palette.

local Profile = require("../../src/shared/WorldDesignProfile")

local lobby = Profile.Lobby
assert(lobby.PlatformSize == 120, "The waiting lobby must be reduced to a 120-stud square")
assert(lobby.PlayerSpawnRadius == 42, "Human lobby spawns must fit the compact platform")
assert(lobby.BotSpawnRadius == 52, "Ten bot spawns must stay inside the compact platform")
assert(lobby.PlayerSpawnRadius < lobby.BotSpawnRadius, "Humans and bots should use separate spawn rings")
assert(lobby.BotSpawnRadius + 6 <= lobby.PlatformSize / 2, "The bot spawn ring must retain a platform-edge safety margin")

local palette = Profile.Cyberpunk
local function isCoolWhite(rgb)
    return rgb[3] > rgb[2] and rgb[2] > rgb[1]
end

assert(isCoolWhite(palette.PrimaryTile), "Primary tiles must use a cool ice-white tint")
assert(isCoolWhite(palette.AlternateTile), "Alternate tiles must use a matching cool blue-white tint")
assert(palette.PrimaryTile[1] >= 220, "Primary tile color must remain bright")
assert(palette.AlternateTile[1] >= 200, "Alternate tile color must remain bright enough for the white/blue theme")
assert(palette.Structure[3] > palette.Structure[2] and palette.Structure[2] > palette.Structure[1],
    "Structural blue must remain a blue tone rather than green")
assert(palette.Accent[2] > palette.Accent[1] and palette.Accent[3] > palette.Accent[1],
    "The accent must stay cyan, not green")
assert(palette.Earth[1] > palette.Earth[2] and palette.Earth[2] > palette.Earth[3],
    "The Earth element must use warm champagne stone instead of green")
assert(palette.Navy[1] < 30 and palette.Navy[2] < 40 and palette.Navy[3] < 60,
    "The deep navy contrast tone must stay restrained")

print("UPDATE_023_WORLD_DESIGN_TESTS_OK")
