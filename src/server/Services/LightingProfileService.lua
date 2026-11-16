--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profile = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("LightingProfile", 8))

local LightingProfileService = {}

local MANAGED_EFFECT_NAMES = {
    Atmosphere = "SkyfallAtmosphere",
    BloomEffect = "SkyfallBloom",
    ColorCorrectionEffect = "SkyfallColorCorrection",
    SunRaysEffect = "SkyfallSunRays",
}

local function removeConflictingPostEffects()
    local keptByClass: { [string]: Instance } = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        local expectedName = MANAGED_EFFECT_NAMES[child.ClassName]
        if expectedName then
            if child.Name ~= expectedName or keptByClass[child.ClassName] then
                child:Destroy()
            else
                keptByClass[child.ClassName] = child
            end
        end
    end
end

local function colorFromRgb(rgb: { number }): Color3
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function getOrCreateManagedEffect(className: string, name: string): Instance
    local effect = Lighting:FindFirstChild(name)
    if effect and not effect:IsA(className) then
        effect:Destroy()
        effect = nil
    end

    if not effect then
        effect = Instance.new(className)
        effect.Name = name
        effect.Parent = Lighting
    end

    return effect
end

local function applySharedSky()
    local sky = getOrCreateManagedEffect("Sky", Profile.Sky.Name) :: Sky

    -- A single known daylight sky prevents a previous map's night/custom sky
    -- from leaking into the next map.
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") and child ~= sky then
            child:Destroy()
        end
    end

    sky.CelestialBodiesShown = Profile.Sky.CelestialBodiesShown
    sky.StarCount = Profile.Sky.StarCount
    sky.SunAngularSize = Profile.Sky.SunAngularSize
    sky.MoonAngularSize = Profile.Sky.MoonAngularSize
end

function LightingProfileService.Apply(): string
    -- Remove legacy/duplicate environment post-effects before applying one
    -- known stack, preventing effects from older maps from composing twice.
    removeConflictingPostEffects()

    Lighting.ClockTime = Profile.ClockTime
    Lighting.Brightness = Profile.Brightness
    Lighting.ExposureCompensation = Profile.ExposureCompensation
    Lighting.Ambient = colorFromRgb(Profile.Ambient)
    Lighting.OutdoorAmbient = colorFromRgb(Profile.OutdoorAmbient)
    Lighting.EnvironmentDiffuseScale = Profile.EnvironmentDiffuseScale
    Lighting.EnvironmentSpecularScale = Profile.EnvironmentSpecularScale
    Lighting.GlobalShadows = Profile.GlobalShadows
    Lighting.ShadowSoftness = Profile.ShadowSoftness
    Lighting.FogColor = colorFromRgb(Profile.FogColor)
    Lighting.FogStart = Profile.FogStart
    Lighting.FogEnd = Profile.FogEnd

    if Profile.LightingStyle == "Realistic" then
        Lighting.LightingStyle = Enum.LightingStyle.Realistic
    else
        Lighting.LightingStyle = Enum.LightingStyle.Soft
    end
    Lighting.PrioritizeLightingQuality = Profile.PrioritizeLightingQuality

    applySharedSky()

    local atmosphere = getOrCreateManagedEffect("Atmosphere", "SkyfallAtmosphere") :: Atmosphere
    atmosphere.Color = colorFromRgb(Profile.Atmosphere.Color)
    atmosphere.Decay = colorFromRgb(Profile.Atmosphere.Decay)
    atmosphere.Density = Profile.Atmosphere.Density
    atmosphere.Offset = Profile.Atmosphere.Offset
    atmosphere.Glare = Profile.Atmosphere.Glare
    atmosphere.Haze = Profile.Atmosphere.Haze

    local sunRays = getOrCreateManagedEffect("SunRaysEffect", "SkyfallSunRays") :: SunRaysEffect
    sunRays.Enabled = true
    sunRays.Intensity = Profile.SunRays.Intensity
    sunRays.Spread = Profile.SunRays.Spread

    local bloom = getOrCreateManagedEffect("BloomEffect", "SkyfallBloom") :: BloomEffect
    bloom.Enabled = true
    bloom.Intensity = Profile.Bloom.Intensity
    bloom.Size = Profile.Bloom.Size
    bloom.Threshold = Profile.Bloom.Threshold

    local colorCorrection =
        getOrCreateManagedEffect("ColorCorrectionEffect", "SkyfallColorCorrection") :: ColorCorrectionEffect
    colorCorrection.Enabled = true
    colorCorrection.Brightness = Profile.ColorCorrection.Brightness
    colorCorrection.Contrast = Profile.ColorCorrection.Contrast
    colorCorrection.Saturation = Profile.ColorCorrection.Saturation
    colorCorrection.TintColor = colorFromRgb(Profile.ColorCorrection.TintColor)

    return Profile.Name
end

return LightingProfileService
