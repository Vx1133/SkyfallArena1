# Skyfall Arena Update #23: unified lighting across maps

## Goal

Keep one stable global lighting and exposure baseline for the lobby, Classic Arena, Cyberpunk Arena, and future maps. Map colors and materials remain art-directed, but changing maps must no longer switch the global brightness, exposure, ambient fill, sky, or post-processing stack.

## Root cause confirmed in the repository

Before this update, Classic Arena used black Ambient/OutdoorAmbient, Brightness 2, ExposureCompensation 0, no atmosphere, and a FogEnd of 100000. Cyberpunk Arena used blue ambient values, Brightness 2.8, ExposureCompensation 0.08, FogEnd 2200, Atmosphere, SunRays, Bloom at intensity 0.3, and ColorCorrection. ArenaService applied those different global settings on every map selection.

## Central profile

The new shared profile is applied by `LightingProfileService` for every map:

- ClockTime: 14
- Brightness: 2.15
- ExposureCompensation: -0.05
- Ambient: RGB(78, 86, 100)
- OutdoorAmbient: RGB(122, 133, 149)
- EnvironmentDiffuseScale: 0.85
- EnvironmentSpecularScale: 0.72
- GlobalShadows: enabled, ShadowSoftness 0.28
- Shared Atmosphere: Density 0.07, Haze 0.42, Glare 0.035
- Restrained Bloom: Intensity 0.12, Size 16, Threshold 1.65
- Legacy or duplicate Atmosphere/Bloom/ColorCorrection/SunRays effects are removed before the single managed stack is applied
- Restrained SunRays: Intensity 0.012
- Neutral ColorCorrection: Brightness -0.005, Contrast 0.035, Saturation 0.02

A single default daylight Sky is retained across map changes, with stars and moon disabled. This avoids an older night/custom sky being left active on one map.

## Ambient occlusion and mobile

Roblox does not expose a normal script-controlled `AmbientOcclusionEffect` intensity setting. Ambient occlusion/contact shading is engine-generated through `LightingStyle.Realistic` where the client supports it. Roblox can automatically scale lighting quality down on lower-end devices. `PrioritizeLightingQuality = true` prioritizes lighting/shading quality and closer high-quality effects when rendering quality must scale down, rather than prioritizing distant view range. The implementation does not force the older `Lighting.Technology` property.

## Scope protection

- No map geometry, tile positions, tile counts, gameplay rules, or round logic are changed.
- Classic green/red/blue materials and Cyberpunk white/blue/cyan art-direction colors remain unchanged.
- The same global baseline is re-applied whenever ArenaService selects a map.
- The server remains the sole owner of the global lighting profile.

## Validation

CI adds a pure-Luau profile test and structural checks that reject map-specific Lighting assignments outside the central service. Selene and Rojo remain part of CI. A CI pass validates source and packaging, not final rendered appearance.

Roblox Studio visual comparison, mobile graphics-level checks, and a live server/client map-rotation test still require an actual Studio/runtime session. Those checks are not represented as completed by this source-only change.

## Official references

- https://create.roblox.com/docs/reference/engine/classes/Lighting
- https://create.roblox.com/docs/environment/lighting
- https://create.roblox.com/docs/environment/post-processing-effects
- https://create.roblox.com/docs/environment/atmosphere
- https://create.roblox.com/docs/onboarding/artists


## Round-start aircraft-control state fix

### Confirmed failure path
The owner-only `SkyfallDebugDroneEnabled` test override was intentionally preserved at the end of each round by `_clearReadyPlayers()`. When that toggle remained true, the owner was inserted into the next round's ready list automatically and `_chooseController()` selected the player before the normal bot fallback. This could make the same player appear to be forcibly locked into the aircraft every round.

### Changes
- Normal players get one compact `✈` icon in the lobby. The icon only changes the server-owned `SkyfallPilotOptIn` choice. Tapping it again cancels the choice. It stays available through the intermission countdown for players already queued.
- The visible `PILOT: OFF/ON` and `DRONE 0%` labels remain removed.
- Controller selection is resolved in one pure policy: manually opted-in ready humans first; otherwise valid bots. A sole human is never used as an automatic fallback.
- The owner-only debug drone remains a separate manual test override, but it is reset at the end of each round and never auto-readies the owner for the next round.
- A server-owned `SkyfallAircraftControlActive` attribute is initialized false and only becomes true when the server hides the player's character for an explicitly selected controller. The client switches to the overhead camera only when the round is active, the role is Controller, and this explicit server attribute is true.
- The round does not enter the Active state or alter any player's role until a valid controller has been resolved. If there is no eligible bot and no manually opted-in player, it fails closed and returns to Waiting.

### Bot independence
The configured roster remains 10 bots. BotService creates the bots before RoundService starts. At round start, one valid bot can be assigned as Controller, while the other nine bots are independently spawned as Runners alongside the human Runner. A human pilot is only removed from the runner roster after manual opt-in.

### Regression coverage
- Lune verifies one non-opted-in human plus ten valid bots resolves to a Bot controller.
- Lune verifies only a strict `true` manual opt-in resolves to a Player controller.
- Cloud smoke tests cover the one-human/ten-bot path, opt-in cancellation, and one-round-only debug override.
- Structural validation checks that server control state gates the custom aircraft camera.
