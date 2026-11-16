--!strict

local FloorAppearanceService = require(script.Parent:WaitForChild("FloorAppearanceService"))

local CyberpunkPillarService = {}

type AppearanceProfile = FloorAppearanceService.AppearanceProfile

type Theme = {
	structure: Color3,
	roof: Color3,
	accent: Color3,
	secondary: Color3,
}

local function createSurfacePart(
	parent: Folder,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	profile: AppearanceProfile?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = profile and profile.Material or Enum.Material.Metal
	part.Reflectance = profile and math.clamp(profile.Reflectance, 0, 1) or 0.04
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part:SetAttribute("SkyfallGenerated", true)

	if profile then
		FloorAppearanceService.ApplySurface(part, profile)
	end

	part.Parent = parent
	return part
end

local function createLightPart(
	parent: Folder,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("SkyfallGenerated", true)
	part.Parent = parent
	return part
end

function CyberpunkPillarService.Build(
	parent: Folder,
	theme: Theme,
	center: Vector3,
	halfWidth: number,
	profile: AppearanceProfile?
): number
	local previous = parent:FindFirstChild("CyberpunkCornerPillars")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "CyberpunkCornerPillars"
	folder:SetAttribute("SkyfallGenerated", true)
	folder.Parent = parent

	local silver = Color3.fromRGB(218, 230, 241)
	local pillarOffset = halfWidth + 7
	local pillarIndex = 0

	for sideX = -1, 1, 2 do
		for sideZ = -1, 1, 2 do
			pillarIndex += 1
			local key = tostring(sideX) .. "_" .. tostring(sideZ)
			local x = center.X + sideX * pillarOffset
			local z = center.Z + sideZ * pillarOffset
			local function at(y: number): Vector3
				return Vector3.new(x, center.Y + y, z)
			end

			-- The broad foot overlaps the two perimeter rails so the column reads
			-- as a structural corner of the arena, not a detached decoration.
			createSurfacePart(
				folder,
				"PylonFoundation_" .. key,
				Vector3.new(13, 1.8, 13),
				at(0.9),
				silver,
				profile
			)
			createSurfacePart(
				folder,
				"PylonFootBridgeX_" .. key,
				Vector3.new(12, 1.8, 3.2),
				Vector3.new(x - sideX * 3.8, center.Y + 0.9, z),
				silver,
				profile
			)
			createSurfacePart(
				folder,
				"PylonFootBridgeZ_" .. key,
				Vector3.new(3.2, 1.8, 12),
				Vector3.new(x, center.Y + 0.9, z - sideZ * 3.8),
				silver,
				profile
			)

			createSurfacePart(
				folder,
				"PylonBaseCollar_" .. key,
				Vector3.new(9.2, 1.2, 9.2),
				at(2.2),
				theme.roof,
				profile
			)
			createSurfacePart(
				folder,
				"PylonColumnCore_" .. key,
				Vector3.new(5.8, 25, 5.8),
				at(15.4),
				theme.structure,
				profile
			)

			-- This wide collar physically meets the existing elevated perimeter ribs.
			createSurfacePart(
				folder,
				"PylonPerimeterJoint_" .. key,
				Vector3.new(8.8, 1.5, 8.8),
				at(8),
				silver,
				profile
			)
			createSurfacePart(
				folder,
				"PylonUpperCollar_" .. key,
				Vector3.new(7.8, 1.1, 7.8),
				at(25.5),
				theme.roof,
				profile
			)
			createSurfacePart(
				folder,
				"PylonCrownBase_" .. key,
				Vector3.new(9, 1.5, 9),
				at(29),
				silver,
				profile
			)
			createSurfacePart(
				folder,
				"PylonCrownCap_" .. key,
				Vector3.new(7.2, 0.9, 7.2),
				at(30.2),
				theme.roof,
				profile
			)

			-- Four narrow inlaid light lines give each tower a clear vertical read.
			local finY = at(15.2)
			for fin = -1, 1, 2 do
				createSurfacePart(
					folder,
					"PylonInlayX_" .. key .. "_" .. tostring(fin),
					Vector3.new(0.42, 19, 0.56),
					finY + Vector3.new(fin * 2.72, 0, 0),
					theme.secondary,
					profile
				)
				createSurfacePart(
					folder,
					"PylonInlayZ_" .. key .. "_" .. tostring(fin),
					Vector3.new(0.56, 19, 0.42),
					finY + Vector3.new(0, 0, fin * 2.72),
					theme.secondary,
					profile
				)
			end

			createLightPart(
				folder,
				"PylonLightSpine_" .. key,
				Vector3.new(0.16, 18, 0.18),
				finY + Vector3.new(-sideX * 2.98, 0, -sideZ * 2.98),
				theme.accent
			)

			local pointLight = Instance.new("PointLight")
			pointLight.Name = "PylonAccentLight_" .. key
			pointLight.Color = theme.accent
			pointLight.Brightness = 0.32
			pointLight.Range = 15
			pointLight.Shadows = false
			pointLight.Parent = folder:FindFirstChild("PylonColumnCore_" .. key)
		end
	end

	return pillarIndex
end

return CyberpunkPillarService
