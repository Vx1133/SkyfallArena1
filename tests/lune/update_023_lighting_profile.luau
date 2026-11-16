--!strict
-- Pure Luau regression tests for the shared global lighting profile.

local Profile = require("../../src/shared/LightingProfile")

assert(Profile.Name == "SkyfallGlobalDaylightV1", "The shared lighting profile name must remain stable")
assert(Profile.Brightness >= 1.8 and Profile.Brightness <= 2.4, "Global brightness must stay in a moderate range")
assert(
    Profile.ExposureCompensation >= -0.15 and Profile.ExposureCompensation <= 0.1,
    "Exposure compensation must not overexpose or crush the scene"
)
assert(Profile.ClockTime >= 12 and Profile.ClockTime <= 16, "The shared profile must remain in daylight")

for channel = 1, 3 do
    assert(
        Profile.Ambient[channel] <= Profile.OutdoorAmbient[channel],
        "Ambient must not exceed OutdoorAmbient in any color channel"
    )
end

assert(Profile.FogStart < Profile.FogEnd, "Fog start must be closer than fog end")
assert(Profile.EnvironmentDiffuseScale >= 0 and Profile.EnvironmentDiffuseScale <= 1, "Diffuse scale is out of range")
assert(Profile.EnvironmentSpecularScale >= 0 and Profile.EnvironmentSpecularScale <= 1, "Specular scale is out of range")

assert(Profile.LightingStyle == "Realistic", "Use engine-managed realistic contact shading where supported")
assert(Profile.PrioritizeLightingQuality == true, "Prioritize close-range lighting quality for the compact arena when quality must scale down")

assert(Profile.Atmosphere.Density <= 0.1, "Atmosphere density must remain subtle")
assert(Profile.Atmosphere.Haze <= 0.6, "Atmosphere haze must not obscure gameplay")
assert(Profile.Atmosphere.Glare <= 0.06, "Atmosphere glare must remain restrained")

assert(Profile.SunRays.Intensity <= 0.02, "Sun rays must remain subtle")
assert(Profile.Bloom.Intensity <= 0.15, "Bloom intensity must not wash out bright surfaces")
assert(Profile.Bloom.Threshold >= 1.5, "Bloom threshold must protect ordinary bright surfaces")
assert(Profile.Bloom.Size <= 20, "Bloom radius must remain controlled")

assert(Profile.Sky.StarCount == 0, "The shared daylight sky must not show stars")
assert(Profile.Sky.MoonAngularSize == 0, "The shared daylight sky must not show the moon")

print("UPDATE_023_LIGHTING_PROFILE_TESTS_OK")
