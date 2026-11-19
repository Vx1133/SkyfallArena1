--!strict
-- Pure Luau regression tests for the single Sky Garden palette and lobby sizing.
local Profile = require("../../src/shared/WorldDesignProfile")
local lobby = Profile.Lobby
assert(lobby.PlatformSize == 120, "The waiting lobby must be a 120-stud square")
assert(lobby.PlayerSpawnRadius == 42, "Human lobby spawns must fit the compact platform")
assert(lobby.BotSpawnRadius == 52, "Ten bot spawns must stay inside the compact platform")
assert(lobby.PlayerSpawnRadius < lobby.BotSpawnRadius, "Humans and bots should use separate spawn rings")
assert(lobby.BotSpawnRadius + 6 <= lobby.PlatformSize / 2, "The bot spawn ring must retain a platform-edge safety margin")
local garden = Profile.SkyGarden
assert(garden.PrimaryTile[2] > garden.PrimaryTile[1], "Sky Garden floor must retain its natural green identity")
assert(garden.CanopyDeep[2] > garden.CanopyDeep[1], "Sky Garden canopy palette must be green-led")
assert(garden.CanopyMid[2] > garden.CanopyMid[1], "Sky Garden mid-canopy must read as foliage")
assert(garden.Bark[1] > garden.Bark[3], "Sky Garden tree bark must use warm wood tones")
assert(garden.Root[1] > garden.Root[3], "Sky Garden exposed roots must remain in the natural bark family")
assert(garden.Stone[1] > garden.StoneShadow[1], "Floating-islet stone needs a lighter top and darker underside")
local earth = Profile.Elements.Earth
assert(earth[1] > earth[2] and earth[2] > earth[3], "Earth element accent must remain champagne stone")
assert(earth[1] >= 180 and earth[1] <= 210, "Earth element accent must remain muted, not bright yellow")
print("UPDATE_023_WORLD_DESIGN_TESTS_OK")
