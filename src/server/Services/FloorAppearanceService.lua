--!strict

local FloorAppearanceService = {}

export type SurfaceObjectProfile = {
	ClassName: string,
	Texture: string,
	Face: EnumItem,
	Transparency: number,
	StudsPerTileU: number?,
	StudsPerTileV: number?,
}

export type AppearanceProfile = {
	Color: Color3,
	Material: EnumItem,
	MaterialVariant: string,
	Reflectance: number,
	TopSurface: EnumItem,
	BottomSurface: EnumItem,
	SurfaceObjects: { SurfaceObjectProfile },
}

local function captureSurfaceObjects(source: BasePart): { SurfaceObjectProfile }
	local objects: { SurfaceObjectProfile } = {}
	for _, child in ipairs(source:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			local surface: SurfaceObjectProfile = {
				ClassName = child.ClassName,
				Texture = child.Texture,
				Face = child.Face,
				Transparency = child.Transparency,
			}
			if child:IsA("Texture") then
				surface.StudsPerTileU = child.StudsPerTileU
				surface.StudsPerTileV = child.StudsPerTileV
			end
			table.insert(objects, surface)
		end
	end
	return objects
end

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
		SurfaceObjects = captureSurfaceObjects(source),
	}
end

local function clearLobbySurfaceCopies(target: BasePart)
	for _, child in ipairs(target:GetChildren()) do
		if child:GetAttribute("SkyfallLobbySurfaceClone") == true then
			child:Destroy()
		end
	end
end

local function applySurfaceObjects(target: BasePart, profile: AppearanceProfile)
	clearLobbySurfaceCopies(target)
	for index, surfaceProfile in ipairs(profile.SurfaceObjects) do
		local surface = Instance.new(surfaceProfile.ClassName) :: Texture | Decal
		surface.Name = "SkyfallLobbySurface_" .. tostring(index)
		surface.Texture = surfaceProfile.Texture
		surface.Face = surfaceProfile.Face
		surface.Transparency = surfaceProfile.Transparency
		if surface:IsA("Texture") then
			surface.StudsPerTileU = surfaceProfile.StudsPerTileU or 1
			surface.StudsPerTileV = surfaceProfile.StudsPerTileV or 1
		end
		surface:SetAttribute("SkyfallLobbySurfaceClone", true)
		surface.Parent = target
	end
end

function FloorAppearanceService.ApplySurface(target: BasePart, profile: AppearanceProfile): boolean
	if not target or not target:IsA("BasePart") then
		return false
	end

	target.Material = profile.Material
	target.Reflectance = math.clamp(profile.Reflectance, 0, 1)
	target.TopSurface = profile.TopSurface
	target.BottomSurface = profile.BottomSurface

	local success, message = pcall(function()
		target.MaterialVariant = profile.MaterialVariant
	end)
	if not success then
		warn("Skyfall could not apply the lobby floor MaterialVariant to " .. target:GetFullName() .. ": " .. tostring(message))
		return false
	end

	applySurfaceObjects(target, profile)
	return true
end

function FloorAppearanceService.Apply(target: BasePart, profile: AppearanceProfile): boolean
	if not FloorAppearanceService.ApplySurface(target, profile) then
		return false
	end
	target.Color = profile.Color
	return true
end

local function auditPart(part: BasePart, profile: AppearanceProfile)
	local label = part:GetFullName()
	local function requireEqual(propertyName: string, actual: any, expected: any)
		if actual ~= expected then
			error(
				"Skyfall lobby surface audit failed at " .. label
					.. " property " .. propertyName
					.. " (actual=" .. tostring(actual) .. ", expected=" .. tostring(expected) .. ")"
			)
		end
	end

	requireEqual("Material", part.Material, profile.Material)
	requireEqual("MaterialVariant", part.MaterialVariant, profile.MaterialVariant)
	requireEqual("Reflectance", part.Reflectance, math.clamp(profile.Reflectance, 0, 1))
	requireEqual("TopSurface", part.TopSurface, profile.TopSurface)
	requireEqual("BottomSurface", part.BottomSurface, profile.BottomSurface)

	local copied = {}
	for _, child in ipairs(part:GetChildren()) do
		if child:GetAttribute("SkyfallLobbySurfaceClone") == true then
			table.insert(copied, child)
		end
	end
	requireEqual("SurfaceObjectCount", #copied, #profile.SurfaceObjects)
	for index, expected in ipairs(profile.SurfaceObjects) do
		local actual = copied[index]
		if not actual then
			error("Skyfall lobby surface audit failed at " .. label .. " missing texture/decal #" .. tostring(index))
		end
		requireEqual("SurfaceObject.ClassName", actual.ClassName, expected.ClassName)
		requireEqual("SurfaceObject.Texture", (actual :: Texture | Decal).Texture, expected.Texture)
		requireEqual("SurfaceObject.Face", (actual :: Texture | Decal).Face, expected.Face)
		requireEqual("SurfaceObject.Transparency", (actual :: Texture | Decal).Transparency, expected.Transparency)
		if actual:IsA("Texture") then
			requireEqual("Texture.StudsPerTileU", actual.StudsPerTileU, expected.StudsPerTileU or 1)
			requireEqual("Texture.StudsPerTileV", actual.StudsPerTileV, expected.StudsPerTileV or 1)
		end
	end
end

function FloorAppearanceService.Audit(root: Instance, profile: AppearanceProfile): number
	local count = 0
	if root:IsA("BasePart") then
		auditPart(root, profile)
		count += 1
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			auditPart(descendant, profile)
			count += 1
		end
	end
	return count
end

return FloorAppearanceService
