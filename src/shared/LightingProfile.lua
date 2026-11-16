--!strict

-- One shared daylight baseline for every playable map and the lobby.
-- Keep this module free of Roblox instances so Lune can test the values.
local Profile = {
    Name = "SkyfallGlobalDaylightV1",
    ClockTime = 14,
    Brightness = 2.15,
    ExposureCompensation = -0.05,

    -- Keep every Ambient channel at or below its OutdoorAmbient channel.
    Ambient = { 78, 86, 100 },
    OutdoorAmbient = { 122, 133, 149 },
    EnvironmentDiffuseScale = 0.85,
    EnvironmentSpecularScale = 0.72,
    GlobalShadows = true,
    ShadowSoftness = 0.28,

    -- Consistent fallback fog values. Atmosphere is the primary depth treatment.
    FogColor = { 186, 201, 220 },
    FogStart = 850,
    FogEnd = 6000,

    -- Realistic enables engine-generated contact shading/AO where supported.
    -- Roblox can scale lighting quality down on lower-end devices.
    LightingStyle = "Realistic",
    PrioritizeLightingQuality = false,

    Sky = {
        Name = "SkyfallGlobalDaySky",
        CelestialBodiesShown = true,
        StarCount = 0,
        SunAngularSize = 14,
        MoonAngularSize = 0,
    },

    Atmosphere = {
        Color = { 205, 222, 240 },
        Decay = { 126, 151, 178 },
        Density = 0.07,
        Offset = 0.22,
        Glare = 0.035,
        Haze = 0.42,
    },

    SunRays = {
        Intensity = 0.012,
        Spread = 0.2,
    },

    Bloom = {
        Intensity = 0.12,
        Size = 16,
        Threshold = 1.65,
    },

    ColorCorrection = {
        Brightness = -0.005,
        Contrast = 0.035,
        Saturation = 0.02,
        TintColor = { 247, 250, 255 },
    },
}

return Profile
