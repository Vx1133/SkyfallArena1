--!strict

local FloorAppearanceService = {}

export type AppearanceProfile = {
	Color: Color3,
	Material: EnumItem,
	MaterialVariant: string,
	Reflectance: number,
	TopSurface: EnumItem,
	BottomSurface: EnumItem,
}

function FloorAppearanceService.Capture(source: BasePart?): AppearanceProfile?
	if not source or not source:IsA("BasePart") then
		return nil
	end

	local materialVariant = ""
	local success, value = pcall(function()
		return source.MaterialVariant
	end)
	if success and typeof(value) == "string" then
		materialVariant = value
	elseif not success then
		warn("Skyfall could not read the lobby floor MaterialVariant: " .. tostring(value))
	end

	return {
		Color = source.Color,
		Material = source.Material,
		MaterialVariant = materialVariant,
		Reflectance = source.Reflectance,
		TopSurface = source.TopSurface,
		BottomSurface = source.BottomSurface,
	}
end

function FloorAppearanceService.ApplySurface(target: BasePart, profile: AppearanceProfile): boolean
	if not target or not target:IsA("BasePart") then
		return false
	end

	target.Material = profile.Material
	target.Reflectance = math.clamp(profile.Reflectance, 0, 1)

	local success, message = pcall(function()
		target.MaterialVariant = profile.MaterialVariant
	end)
	if not success then
		warn("Skyfall could not apply the lobby floor MaterialVariant to " .. target:GetFullName() .. ": " .. tostring(message))
	end

	return success
end

function FloorAppearanceService.Apply(target: BasePart, profile: AppearanceProfile): boolean
	if not target or not target:IsA("BasePart") then
		return false
	end

	FloorAppearanceService.ApplySurface(target, profile)
	target.Color = profile.Color
	target.TopSurface = profile.TopSurface
	target.BottomSurface = profile.BottomSurface
	return true
end

return FloorAppearanceService
