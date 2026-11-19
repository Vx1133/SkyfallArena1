--!strict
-- Organic floating sanctuary for the Classic map. Geometry stays outside the playable grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldDesignProfile = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("WorldDesignProfile", 8))
local Factory = require(script.Parent:WaitForChild("MapDecorationFactory", 8))

local SkyGardenMapBuilder = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function buildTree(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3,
	index: number,
	baseOffset: Vector3,
	height: number,
	crownScale: number
): BasePart
	local palette = WorldDesignProfile.SkyGarden
	local base = center + baseOffset
	local top = base + Vector3.new(0, height, 0)
	local trunk = Factory.CylinderBetween(
		folder, profile, "SkyGarden", "SkyGardenTreeTrunk_" .. string.format("%02d", index),
		base, top, 3.2, color(palette.Bark), true
	)

	Factory.CylinderBetween(
		folder, profile, "SkyGarden", "SkyGardenBranch_" .. string.format("%02d", index) .. "_A",
		top + Vector3.new(0, -height * 0.42, 0),
		top + Vector3.new(-9 * crownScale, 1, -3 * crownScale),
		1.45, color(palette.Bark)
	)
	Factory.CylinderBetween(
		folder, profile, "SkyGarden", "SkyGardenBranch_" .. string.format("%02d", index) .. "_B",
		top + Vector3.new(0, -height * 0.54, 0),
		top + Vector3.new(8 * crownScale, 3, 4 * crownScale),
		1.25, color(palette.Root)
	)

	local crownOffsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(-7, -2, -5),
		Vector3.new(7, -1, 4),
		Vector3.new(-2, 5, 7),
		Vector3.new(4, 5, -7),
	}
	local crownColors = {
		color(palette.CanopyDeep),
		color(palette.CanopyMid),
		color(palette.CanopyLight),
		color(palette.CanopyMid),
		color(palette.CanopyDeep),
	}
	local crownParts: { Part } = {}
	for crownIndex, offset in ipairs(crownOffsets) do
		local scale = crownIndex == 1 and 1.18 or (crownIndex % 2 == 0 and 0.78 or 0.9)
		local canopy = Factory.CreatePart(
			folder, profile, "SkyGarden",
			"SkyGardenCanopy_" .. string.format("%02d", index) .. "_" .. tostring(crownIndex),
			Vector3.new(16, 12, 15) * (crownScale * scale),
			CFrame.new(top + offset * crownScale),
			crownColors[crownIndex],
			Enum.PartType.Ball,
			false
		)
		table.insert(crownParts, canopy)
	end

	local vineStart = Factory.CreateAttachment(trunk, "NatureVineAnchor", base + Vector3.new(0, height * 0.62, 0))
	local vineEnd = Factory.CreateAttachment(crownParts[2], "NatureVineCanopyAnchor", crownParts[2].Position + Vector3.new(0, -5 * crownScale, 0))
	Factory.CreateBeam(
		folder,
		"SkyGardenVine_" .. string.format("%02d", index),
		vineStart,
		vineEnd,
		color(palette.Vine),
		0.48,
		0.2,
		-5 * crownScale,
		7 * crownScale
	)

	return trunk
end

local function buildFloatingIslet(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3,
	index: number,
	offset: Vector3,
	size: Vector3,
	rotation: number
)
	local palette = WorldDesignProfile.SkyGarden
	local position = center + offset
	local mainRock = Factory.CreatePart(
		folder, profile, "SkyGarden", "SkyGardenFloatingIslet_" .. string.format("%02d", index),
		size,
		CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), math.rad(index % 2 == 0 and 7 or -5)),
		color(palette.Stone),
		Enum.PartType.Ball,
		true
	)
	Factory.CreatePart(
		folder, profile, "SkyGarden", "SkyGardenIsletUnderside_" .. string.format("%02d", index),
		Vector3.new(size.X * 0.72, size.Y * 0.66, size.Z * 0.7),
		CFrame.new(position + Vector3.new(2, -size.Y * 0.43, -1)) * CFrame.Angles(0, math.rad(rotation + 19), 0),
		color(palette.StoneShadow),
		Enum.PartType.Ball,
		false
	)
	Factory.CreatePart(
		folder, profile, "SkyGarden", "SkyGardenMossShelf_" .. string.format("%02d", index),
		Vector3.new(size.X * 0.66, 1.5, size.Z * 0.55),
		CFrame.new(position + Vector3.new(-1, size.Y * 0.43, 1)) * CFrame.Angles(0, math.rad(rotation - 12), 0),
		color(palette.CanopyDeep),
		Enum.PartType.Ball,
		false
	)
	return mainRock
end

local function buildRootArch(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3
)
	local palette = WorldDesignProfile.SkyGarden
	local startAngle = math.rad(203)
	local endAngle = math.rad(315)
	local radius = 115
	local segments = 7
	local previous = nil

	for index = 0, segments do
		local alpha = index / segments
		local angle = startAngle + (endAngle - startAngle) * alpha
		local height = 5 + math.sin(alpha * math.pi) * 18
		local point = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		if previous then
			Factory.CylinderBetween(
				folder, profile, "SkyGarden",
				"SkyGardenRootArch_" .. string.format("%02d", index),
				previous, point, 1.8 - alpha * 0.45, color(palette.Root), true
			)
		end
		previous = point
	end
end

local function buildExposedRoots(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3,
	index: number,
	baseOffset: Vector3
)
	local palette = WorldDesignProfile.SkyGarden
	local base = center + baseOffset
	local directions = {
		Vector3.new(-1, -0.1, -0.2),
		Vector3.new(0.25, -0.05, 1),
		Vector3.new(1, -0.08, -0.35),
	}
	for rootIndex, direction in ipairs(directions) do
		local endPosition = base + direction.Unit * (8 + rootIndex * 1.4)
		Factory.CylinderBetween(
			folder, profile, "SkyGarden",
			"SkyGardenExposedRoot_" .. tostring(index) .. "_" .. tostring(rootIndex),
			base, endPosition, 1.05, color(palette.Root), false
		)
	end
end

function SkyGardenMapBuilder.Build(
	parent: Folder,
	center: Vector3,
	halfWidth: number,
	profile: Factory.AppearanceProfile
): number
	local previous = parent:FindFirstChild("SkyfallNatureSanctuary")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "SkyfallNatureSanctuary"
	folder:SetAttribute("SkyfallGenerated", true)
	folder:SetAttribute("SkyfallMapIdentity", "SkyGarden")
	folder:SetAttribute("SkyfallGeometrySignature", "sky-garden-organic-floating-sanctuary-v1")
	folder.Parent = parent

	local treeLayouts = {
		{ offset = Vector3.new(-halfWidth - 24, 11, -20), height = 29, scale = 1.08 },
		{ offset = Vector3.new(halfWidth + 21, 8, -38), height = 21, scale = 0.84 },
		{ offset = Vector3.new(-22, 15, halfWidth + 24), height = 24, scale = 0.92 },
	}
	for index, layout in ipairs(treeLayouts) do
		local trunk = buildTree(folder, profile, center, index, layout.offset, layout.height, layout.scale)
		buildExposedRoots(folder, profile, center, index, layout.offset)
		if index == 2 then
			Factory.CreatePointLight(trunk, "SkyGardenCanopyLight", color(WorldDesignProfile.SkyGarden.CanopyMid), 0.18, 16)
		end
	end

	buildFloatingIslet(folder, profile, center, 1, Vector3.new(0, 13, -halfWidth - 35), Vector3.new(35, 9, 25), -18)
	buildFloatingIslet(folder, profile, center, 2, Vector3.new(halfWidth + 38, 5, 20), Vector3.new(28, 8, 22), 31)
	buildFloatingIslet(folder, profile, center, 3, Vector3.new(-20, 17, halfWidth + 38), Vector3.new(30, 10, 24), 12)

	buildRootArch(folder, profile, center)

	local count = 0
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	folder:SetAttribute("SkyfallGeometryPartCount", count)
	return count
end

return SkyGardenMapBuilder
