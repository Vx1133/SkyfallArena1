--!strict
-- Shared low-level construction helpers. Geometry identity stays in the map builders.

local FloorAppearanceService = require(script.Parent:WaitForChild("FloorAppearanceService"))

local MapDecorationFactory = {}

export type AppearanceProfile = FloorAppearanceService.AppearanceProfile

local function applySharedSurface(part: BasePart, profile: AppearanceProfile)
	if not FloorAppearanceService.ApplySurface(part, profile) then
		part:Destroy()
		error("Skyfall could not apply the lobby surface profile to " .. part.Name)
	end
end

function MapDecorationFactory.CreatePart(
	parent: Folder,
	profile: AppearanceProfile,
	mapIdentity: string,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	castShadow: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = castShadow == true
	part:SetAttribute("SkyfallGenerated", true)
	part:SetAttribute("SkyfallMapIdentity", mapIdentity)
	applySharedSurface(part, profile)
	-- Color is applied after the lobby finish, and remains map-specific.
	part.Color = color
	part.Parent = parent
	return part
end

function MapDecorationFactory.CylinderBetween(
	parent: Folder,
	profile: AppearanceProfile,
	mapIdentity: string,
	name: string,
	startPosition: Vector3,
	endPosition: Vector3,
	diameter: number,
	color: Color3,
	castShadow: boolean?
): Part
	local axis = endPosition - startPosition
	if axis.Magnitude < 0.05 then
		error("Cannot create a zero-length map cylinder: " .. name)
	end

	local right = axis.Unit
	local referenceUp = math.abs(right:Dot(Vector3.yAxis)) > 0.94 and Vector3.zAxis or Vector3.yAxis
	local up = (referenceUp - right * right:Dot(referenceUp)).Unit
	local back = right:Cross(up).Unit
	local frame = CFrame.fromMatrix((startPosition + endPosition) * 0.5, right, up, back)

	return MapDecorationFactory.CreatePart(
		parent,
		profile,
		mapIdentity,
		name,
		Vector3.new(axis.Magnitude, diameter, diameter),
		frame,
		color,
		Enum.PartType.Cylinder,
		castShadow
	)
end

function MapDecorationFactory.CreateAttachment(part: BasePart, name: string, worldPosition: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = part.CFrame:PointToObjectSpace(worldPosition)
	attachment.Parent = part
	return attachment
end

function MapDecorationFactory.CreateBeam(
	parent: Folder,
	name: string,
	attachment0: Attachment,
	attachment1: Attachment,
	color: Color3,
	width0: number,
	width1: number,
	curveSize0: number?,
	curveSize1: number?
): Beam
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = width0
	beam.Width1 = width1
	beam.CurveSize0 = curveSize0 or 0
	beam.CurveSize1 = curveSize1 or 0
	beam.Segments = 12
	beam.FaceCamera = true
	beam.LightEmission = 0.35
	beam.LightInfluence = 0.15
	beam.Transparency = NumberSequence.new(0.12)
	beam.Parent = parent
	return beam
end

function MapDecorationFactory.CreatePointLight(
	parent: Instance,
	name: string,
	color: Color3,
	brightness: number,
	range: number
): PointLight
	local light = Instance.new("PointLight")
	light.Name = name
	light.Color = color
	light.Brightness = math.clamp(brightness, 0, 0.4)
	light.Range = math.clamp(range, 4, 18)
	light.Shadows = false
	light.Parent = parent
	return light
end

return MapDecorationFactory
