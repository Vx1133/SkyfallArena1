--!strict
-- Pure Luau regression tests for Update #23 map identity and lobby sizing.

local Profile = require("../../src/shared/WorldDesignProfile")

local lobby = Profile.Lobby
assert(lobby.PlatformSize == 120, "The waiting lobby must be a 120-stud square")
assert(lobby.PlayerSpawnRadius == 42, "Human lobby spawns must fit the compact platform")
assert(lobby.BotSpawnRadius == 52, "Ten bot spawns must stay inside the compact platform")
assert(lobby.PlayerSpawnRadius < lobby.BotSpawnRadius, "Humans and bots should use separate spawn rings")
assert(lobby.BotSpawnRadius + 6 <= lobby.PlatformSize / 2, "The bot spawn ring must retain a platform-edge safety margin")

local classic = Profile.Classic
assert(classic.PrimaryTile[2] > classic.PrimaryTile[1], "Classic floor must retain its natural green identity")
assert(classic.CanopyDeep[2] > classic.CanopyDeep[1], "Classic canopy palette must be green-led")
assert(classic.CanopyMid[2] > classic.CanopyMid[1], "Classic mid-canopy must read as foliage")
assert(classic.Bark[1] > classic.Bark[3], "Classic tree bark must use warm wood tones")
assert(classic.Root[1] > classic.Root[3], "Classic exposed roots must remain in the natural bark family")
assert(classic.Stone[1] > classic.StoneShadow[1], "Natural floating-islet stone needs a lighter top and darker underside")

local cyberpunk = Profile.Cyberpunk
local function isCoolWhite(rgb)
    return rgb[3] > rgb[2] and rgb[2] > rgb[1]
end

assert(isCoolWhite(cyberpunk.PrimaryTile), "Cyberpunk primary tiles must use cool ice-white")
assert(isCoolWhite(cyberpunk.AlternateTile), "Cyberpunk alternate tiles must use blue-white")
assert(cyberpunk.PrimaryTile[1] >= 220, "Cyberpunk primary tile color must remain bright")
assert(cyberpunk.AlternateTile[1] >= 200, "Cyberpunk alternate tile color must remain bright")
assert(cyberpunk.Structure[3] > cyberpunk.Structure[2] and cyberpunk.Structure[2] > cyberpunk.Structure[1],
    "Cyberpunk structure must remain engineered steel blue")
assert(cyberpunk.Accent[2] > cyberpunk.Accent[1] and cyberpunk.Accent[3] > cyberpunk.Accent[1],
    "Cyberpunk accent must remain cyan rather than green")
assert(cyberpunk.Earth[1] > cyberpunk.Earth[2] and cyberpunk.Earth[2] > cyberpunk.Earth[3],
    "The Earth element must use champagne stone")
assert(cyberpunk.Navy[1] < 30 and cyberpunk.Navy[2] < 40 and cyberpunk.Navy[3] < 60,
    "The deep navy contrast tone must stay restrained")

assert(classic.PrimaryTile[2] > classic.PrimaryTile[3], "Classic base tiles must remain green-led")
assert(cyberpunk.PrimaryTile[3] > cyberpunk.PrimaryTile[2], "Cyberpunk base tiles must remain blue-led")
assert(
    classic.PrimaryTile[2] ~= cyberpunk.PrimaryTile[2]
        and classic.PrimaryTile[3] ~= cyberpunk.PrimaryTile[3],
    "The two map palettes must be numerically distinct, not simple color aliases"
)

print("UPDATE_023_WORLD_DESIGN_TESTS_OK")
