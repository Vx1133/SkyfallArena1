--!strict
-- Angular orbital sky-station. No nature geometry or corner-pillar template is used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldDesignProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldDesignProfile"))
local Factory = require(script.Parent:WaitForChild("MapDecorationFactory"))

local CyberpunkMapBuilder = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function horizontalPoint(center: Vector3, radius: number, angleDegrees: number, y: number): Vector3
	local angle = math.rad(angleDegrees)
	return center + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function buildGateSpire(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3,
	index: number,
	angle: number,
	radius: number,
	height: number
): (BasePart, Attachment)
	local palette = WorldDesignProfile.Cyberpunk
	local basePosition = horizontalPoint(center, radius, angle, 1)
	local yaw = math.rad(angle + 90)

	local deck = Factory.CreatePart(
		folder, profile, "Cyberpunk", "CyberpunkGateSpireBase_" .. string.format("%02d", index),
		Vector3.new(13, 1.8, 10),
		CFrame.new(basePosition) * CFrame.Angles(0, yaw, math.rad(index == 1 and -4 or 6)),
		color(palette.Silver),
		Enum.PartType.Block,
		true
	)
	local core = Factory.CreatePart(
		folder, profile, "Cyberpunk", "CyberpunkGateSpire_" .. string.format("%02d", index),
		Vector3.new(4.2, height, 4.2),
		CFrame.new(basePosition + Vector3.new(0, height * 0.5, 0)) * CFrame.Angles(0, yaw, 0),
		color(palette.Structure),
		Enum.PartType.Block,
		true
	)
	Factory.CreatePart(
		folder, profile, "Cyberpunk", "CyberpunkGateSpireCrown_" .. string.format("%02d", index),
		Vector3.new(9, 1.8, 7),
		CFrame.new(basePosition + Vector3.new(0, height + 0.6, 0)) * CFrame.Angles(0, yaw + math.rad(13), 0),
		color(palette.Roof),
		Enum.PartType.Block,
		false
	)
	local braceStart = basePosition + Vector3.new(0, 3, 0) + Vector3.new(0, 0, -5)
	local braceEnd = basePosition + Vector3.new(0, height * 0.78, 0) + Vector3.new(6, 0, 0)
	Factory.CylinderBetween(
		folder, profile, "Cyberpunk", "CyberpunkGateSpireBrace_" .. string.format("%02d", index),
		braceStart, braceEnd, 1.2, color(palette.Silver), false
	)

	Factory.CreatePointLight(core, "CyberpunkSpireLight_" .. tostring(index), color(palette.Accent), 0.3, 16)
	local topAttachment = Factory.CreateAttachment(
		core, "CyberpunkEnergyNode_" .. tostring(index),
		basePosition + Vector3.new(0, height + 0.2, 0)
	)
	return core, topAttachment
end

local function buildOrbitalFrame(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3,
	halfWidth: number
): { Part }
	local palette = WorldDesignProfile.Cyberpunk
	local radii = { 118, 125, 114, 123, 116, 127, 119 }
	local angles = { -12, 39, 92, 145, 199, 252, 306 }
	local vertices = {}
	for index, angle in ipairs(angles) do
		vertices[index] = horizontalPoint(center, math.max(radii[index], halfWidth + 22), angle, 5 + (index % 3) * 2)
	end

	local segments: { Part } = {}
	for index = 1, #vertices do
		local nextIndex = index % #vertices + 1
		-- Three intentional gaps break the loop into an orbital frame rather than a closed perimeter fence.
		if index ~= 2 and index ~= 5 then
			local segment = Factory.CylinderBetween(
				folder, profile, "Cyberpunk",
				"CyberpunkOrbitalFrame_" .. string.format("%02d", index),
				vertices[index], vertices[nextIndex], 2.8,
				color(palette.Silver), true
			)
			table.insert(segments, segment)
		end
	end
	return segments
end

local function buildAngularDeck(
	folder: Folder,
	profile: Factory.AppearanceProfile,
	center: Vector3,
	index: number,
	offset: Vector3,
	yawDegrees: number,
	size: Vector3
): Part
	local palette = WorldDesignProfile.Cyberpunk
	return Factory.CreatePart(
		folder, profile, "Cyberpunk", "CyberpunkAngularDeck_" .. string.format("%02d", index),
		size,
		CFrame.new(center + offset) * CFrame.Angles(0, math.rad(yawDegrees), math.rad(index % 2 == 0 and 5 or -4)),
		color(index == 2 and palette.Structure or palette.Roof),
		Enum.PartType.Block,
		true
	)
end

function CyberpunkMapBuilder.Build(
	parent: Folder,
	center: Vector3,
	halfWidth: number,
	profile: Factory.AppearanceProfile
): number
	local previous = parent:FindFirstChild("CyberpunkOrbitalStation")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "CyberpunkOrbitalStation"
	folder:SetAttribute("SkyfallGenerated", true)
	folder:SetAttribute("SkyfallMapIdentity", "Cyberpunk")
	folder:SetAttribute("SkyfallGeometrySignature", "offset-angular-orbital-sky-station")
	folder.Parent = parent

	local palette = WorldDesignProfile.Cyberpunk
	local orbitalSegments = buildOrbitalFrame(folder, profile, center, halfWidth)

	local _, spireA = buildGateSpire(folder, profile, center, 1, 36, halfWidth + 36, 34)
	local _, spireB = buildGateSpire(folder, profile, center, 2, 214, halfWidth + 39, 27)

	Factory.CreateBeam(
		folder, "CyberpunkEnergyBridge_Primary",
		spireA, spireB, color(palette.Accent), 1.25, 0.72, 10, -8
	)

	local energyAnchorA = Factory.CreateAttachment(orbitalSegments[1], "CircuitNode_A", orbitalSegments[1].Position + Vector3.new(0, 2, 0))
	local energyAnchorB = Factory.CreateAttachment(orbitalSegments[3], "CircuitNode_B", orbitalSegments[3].Position + Vector3.new(0, 2, 0))
	Factory.CreateBeam(
		folder, "CyberpunkCircuitBeam_01",
		energyAnchorA, energyAnchorB, color(palette.Accent), 0.7, 0.45, -6, 9
	)

	local deckA = buildAngularDeck(
		folder, profile, center, 1,
		Vector3.new(halfWidth + 29, 12, 28), 28,
		Vector3.new(22, 1.8, 13)
	)
	local deckB = buildAngularDeck(
		folder, profile, center, 2,
		Vector3.new(-18, 17, -halfWidth - 36), -21,
		Vector3.new(26, 2, 12)
	)
	local deckC = buildAngularDeck(
		folder, profile, center, 3,
		Vector3.new(-halfWidth - 35, 8, 44), 63,
		Vector3.new(18, 1.6, 11)
	)

	local deckA0 = Factory.CreateAttachment(deckA, "EnergyPort_A0", deckA.Position + Vector3.new(-8, 1.2, 0))
	local deckA1 = Factory.CreateAttachment(deckA, "EnergyPort_A1", deckA.Position + Vector3.new(8, 1.2, 0))
	local deckB0 = Factory.CreateAttachment(deckB, "EnergyPort_B0", deckB.Position + Vector3.new(-9, 1.2, 0))
	local deckB1 = Factory.CreateAttachment(deckB, "EnergyPort_B1", deckB.Position + Vector3.new(9, 1.2, 0))
	Factory.CreateBeam(folder, "CyberpunkCircuitBeam_02", deckA0, deckB0, color(palette.Accent), 0.48, 0.48, 6, -6)
	Factory.CreateBeam(folder, "CyberpunkCircuitBeam_03", deckA1, deckB1, color(palette.Accent), 0.28, 0.28, -5, 5)

	local strutPairs = {
		{ a = deckA.Position + Vector3.new(0, 0, -5), b = spireA.WorldPosition + Vector3.new(0, -7, 0) },
		{ a = deckC.Position + Vector3.new(0, 0, 4), b = spireB.WorldPosition + Vector3.new(0, -5, 0) },
	}
	for index, pair in ipairs(strutPairs) do
		Factory.CylinderBetween(
			folder, profile, "Cyberpunk", "CyberpunkAngularSupportStrut_" .. tostring(index),
			pair.a, pair.b, 1.55, color(palette.Structure), false
		)
	end

	local count = 0
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	folder:SetAttribute("SkyfallGeometryPartCount", count)
	return count
end

return CyberpunkMapBuilder
