--!strict

-- Skyfall Arena's projected arcane activation sigil.
-- Built from native Roblox UI, Beams, and a few small 3D accents so it
-- stays editable, does not depend on third-party asset IDs, and can be
-- cleaned up by its owner or by Debris after its configured lifetime.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local MagicCircleVFX = {}

local FOLDER_NAME = "SkyfallMagicCircleVFX"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local COLORS = {
	Cyan = Color3.fromRGB(101, 225, 255),
	Ice = Color3.fromRGB(211, 249, 255),
	Gold = Color3.fromRGB(255, 216, 145),
	DeepBlue = Color3.fromRGB(66, 160, 255),
}

local FADE_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local UI_PULSE = TweenInfo.new(0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local ORB_PULSE = TweenInfo.new(0.48, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function createCircleStroke(
	parent: Frame,
	name: string,
	thickness: number,
	color: Color3,
	transparency: number
): UIStroke
	local circle = Instance.new("Frame")
	circle.Name = name .. "Disc"
	circle.Size = UDim2.fromScale(1, 1)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.BackgroundTransparency = 1
	circle.BorderSizePixel = 0
	circle.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	local stroke = Instance.new("UIStroke")
	stroke.Name = name .. "Stroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 1
	stroke.Parent = circle

	TweenService:Create(stroke, FADE_IN, { Transparency = transparency }):Play()
	TweenService:Create(stroke, UI_PULSE, {
		Thickness = thickness * 1.35,
	}):Play()

	return stroke
end

local function createUiBar(
	parent: Instance,
	name: string,
	center: Vector2,
	direction: Vector2,
	length: number,
	width: number,
	color: Color3,
	transparency: number
)
	local unit = direction.Unit
	local midpoint = center
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(midpoint.X, midpoint.Y)
	bar.Size = UDim2.fromScale(width, length)
	bar.Rotation = math.deg(math.atan2(unit.Y, unit.X)) + 90
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.Parent = parent

	bar.BackgroundTransparency = transparency
end

local function createUiLine(
	parent: Instance,
	name: string,
	pointA: Vector2,
	pointB: Vector2,
	width: number,
	color: Color3,
	transparency: number
)
	local delta = pointB - pointA
	local length = delta.Magnitude
	if length <= 0.001 then
		return
	end

	local midpoint = (pointA + pointB) * 0.5
	createUiBar(parent, name, midpoint, delta.Unit, length, width, color, transparency)
end

local function createUiDot(
	parent: Instance,
	name: string,
	position: Vector2,
	diameter: number,
	color: Color3,
	transparency: number,
	rotation: number?
)
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(position.X, position.Y)
	dot.Size = UDim2.fromScale(diameter, diameter)
	dot.Rotation = rotation or 0
	dot.BackgroundColor3 = color
	dot.BackgroundTransparency = 1
	dot.BorderSizePixel = 0
	dot.Parent = parent

	dot.BackgroundTransparency = transparency
end

local function createRotatingLayer(
	parent: SurfaceGui,
	name: string,
	diameter: number,
	rotationSeconds: number,
	direction: number
): Frame
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Position = UDim2.fromScale(0.5, 0.5)
	layer.Size = UDim2.fromScale(diameter, diameter)
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Parent = parent

	local rotationTween = TweenService:Create(
		layer,
		TweenInfo.new(rotationSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ Rotation = direction * 360 }
	)
	rotationTween:Play()

	return layer
end

local function buildOuterRuneLayer(parent: SurfaceGui)
	local layer = createRotatingLayer(parent, "OuterRunicCrown", 0.94, 6.2, 1)
	createCircleStroke(layer, "OuterCyanRing", 9, COLORS.Cyan, 0.12)

	local center = Vector2.new(0.5, 0.5)

	-- Alternating long and short index marks create a calibrated, astrolabe-like rim.
	for index = 1, 24 do
		local angle = (index / 24) * math.pi * 2
		local radial = Vector2.new(math.cos(angle), math.sin(angle))
		local innerRadius = 0.405
		local outerRadius = if index % 2 == 0 then 0.468 else 0.448
		createUiLine(
			layer,
			"OuterIndex_" .. tostring(index),
			center + radial * innerRadius,
			center + radial * outerRadius,
			if index % 2 == 0 then 0.009 else 0.006,
			if index % 3 == 0 then COLORS.Gold else COLORS.Cyan,
			0.12
		)
	end

	-- Eight original geometric glyphs, each made from three clean strokes.
	for index = 1, 8 do
		local angle = ((index - 1) / 8) * math.pi * 2
		local radial = Vector2.new(math.cos(angle), math.sin(angle))
		local tangent = Vector2.new(-math.sin(angle), math.cos(angle))
		local glyphCenter = center + radial * 0.345
		local stemA = glyphCenter - radial * 0.052
		local stemB = glyphCenter + radial * 0.052
		local branchRoot = glyphCenter + radial * 0.012

		createUiLine(layer, "RuneStem_" .. tostring(index), stemA, stemB, 0.013, COLORS.Gold, 0.06)
		createUiLine(
			layer,
			"RuneWingA_" .. tostring(index),
			branchRoot,
			glyphCenter + radial * 0.075 + tangent * 0.045,
			0.011,
			COLORS.Ice,
			0.08
		)
		createUiLine(
			layer,
			"RuneWingB_" .. tostring(index),
			branchRoot,
			glyphCenter + radial * 0.075 - tangent * 0.045,
			0.011,
			COLORS.Ice,
			0.08
		)
	end

	return layer
end

local function buildMiddleRing(parent: SurfaceGui)
	local layer = createRotatingLayer(parent, "CounterRotatingGlyphTrack", 0.69, 4.8, -1)
	createCircleStroke(layer, "MiddleGoldRing", 7.5, COLORS.Gold, 0.1)

	local center = Vector2.new(0.5, 0.5)
	for index = 1, 16 do
		local angle = (index / 16) * math.pi * 2
		local radial = Vector2.new(math.cos(angle), math.sin(angle))
		local markerPosition = center + radial * 0.435
		createUiDot(
			layer,
			"MiddleGlyphNode_" .. tostring(index),
			markerPosition,
			if index % 4 == 0 then 0.035 else 0.022,
			if index % 4 == 0 then COLORS.Ice else COLORS.Gold,
			0.08,
			45
		)
	end

	-- Small inner hash marks make the middle track read as engraved geometry.
	for index = 1, 8 do
		local angle = ((index - 1) / 8) * math.pi * 2
		local radial = Vector2.new(math.cos(angle), math.sin(angle))
		local tangent = Vector2.new(-math.sin(angle), math.cos(angle))
		local point = center + radial * 0.31
		createUiLine(
			layer,
			"MiddleHash_" .. tostring(index),
			point - tangent * 0.035,
			point + tangent * 0.035,
			0.012,
			COLORS.Cyan,
			0.1
		)
	end

	return layer
end

local function buildInnerSigil(parent: SurfaceGui)
	local layer = createRotatingLayer(parent, "InnerTriuneSigil", 0.43, 3.4, 1)
	createCircleStroke(layer, "InnerIceRing", 6.5, COLORS.Ice, 0.08)

	local center = Vector2.new(0.5, 0.5)
	local points = table.create(6) :: { Vector2 }
	for index = 1, 6 do
		local angle = ((index - 1) / 6) * math.pi * 2 - math.pi / 2
		points[index] = center + Vector2.new(math.cos(angle), math.sin(angle)) * 0.31
	end

	-- Two interlocked triangles form the central star without a bitmap decal.
	local triangleEdges = {
		{ 1, 3 }, { 3, 5 }, { 5, 1 },
		{ 2, 4 }, { 4, 6 }, { 6, 2 },
	}
	for index, edge in ipairs(triangleEdges) do
		createUiLine(
			layer,
			"InnerStarEdge_" .. tostring(index),
			points[edge[1]],
			points[edge[2]],
			0.018,
			if index <= 3 then COLORS.Cyan else COLORS.Gold,
			0.04
		)
	end
	createUiDot(layer, "SigilCore", center, 0.09, COLORS.Ice, 0.02, 45)
	return layer
end

local function createAdornmentPart(
	parent: Folder,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.14
	part.Reflectance = 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function createThreeDimensionalAccents(
	parent: Folder,
	anchor: Part,
	center: Vector3,
	surfaceY: number
)
	-- Four small elevated nodes create parallax and make the projection feel volumetric.
	for index = 1, 4 do
		local angle = ((index - 1) / 4) * math.pi * 2 + math.pi / 4
		local offset = Vector3.new(math.cos(angle) * 4.72, 0.31, math.sin(angle) * 4.72)
		local node = createAdornmentPart(
			parent,
			"FloatingSigilNode_" .. tostring(index),
			Vector3.new(0.18, 0.18, 0.18),
			CFrame.new(center + offset),
			if index % 2 == 0 then COLORS.Gold else COLORS.Ice,
			Enum.PartType.Ball
		)
		TweenService:Create(node, ORB_PULSE, {
			Size = Vector3.new(0.25, 0.25, 0.25),
			Transparency = 0.34,
		}):Play()
	end

	-- A compact rotating crystal sits above the center, safely away from player collision.
	local crystal = createAdornmentPart(
		parent,
		"FloatingSigilCore",
		Vector3.new(0.28, 0.42, 0.28),
		CFrame.new(center + Vector3.new(0, 0.46, 0))
			* CFrame.Angles(math.rad(45), math.rad(45), math.rad(45)),
		COLORS.Ice,
		Enum.PartType.Block
	)
	TweenService:Create(
		crystal,
		TweenInfo.new(2.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ CFrame = crystal.CFrame * CFrame.Angles(0, math.rad(359), 0) }
	):Play()

	local centerAttachment = Instance.new("Attachment")
	centerAttachment.Name = "SigilCoreAttachment"
	centerAttachment.Position = Vector3.new(0, 0.3, 0)
	centerAttachment.Parent = anchor

	for index = 1, 4 do
		local angle = ((index - 1) / 4) * math.pi * 2
		local spokeEndAttachment = Instance.new("Attachment")
		spokeEndAttachment.Name = "SigilSpokeAttachment_" .. tostring(index)
		spokeEndAttachment.Position = Vector3.new(math.cos(angle) * 1.55, 0.23, math.sin(angle) * 1.55)
		spokeEndAttachment.Parent = anchor

		local spoke = Instance.new("Beam")
		spoke.Name = "SigilEnergySpoke_" .. tostring(index)
		spoke.Attachment0 = centerAttachment
		spoke.Attachment1 = spokeEndAttachment
		spoke.FaceCamera = true
		spoke.Segments = 4
		spoke.Width0 = 0.045
		spoke.Width1 = 0.025
		spoke.Color = ColorSequence.new(COLORS.DeepBlue, COLORS.Cyan)
		spoke.Transparency = NumberSequence.new(0.42)
		spoke.LightEmission = 1
		spoke.LightInfluence = 0
		spoke.Parent = anchor
	end

	local light = Instance.new("PointLight")
	light.Name = "MagicCircleGlow"
	light.Color = COLORS.Cyan
	light.Brightness = 0.65
	light.Range = 8
	light.Shadows = false
	light.Parent = anchor
	TweenService:Create(
		light,
		TweenInfo.new(1.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0.08, Range = 3 }
	):Play()

	local particleAttachment = Instance.new("Attachment")
	particleAttachment.Name = "SigilSparkOrigin"
	particleAttachment.Position = Vector3.new(0, 0.34, 0)
	particleAttachment.Parent = anchor

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "SigilSparkBurst"
	sparks.Texture = SPARK_TEXTURE
	sparks.Enabled = false
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.22, 0.42)
	sparks.Speed = NumberRange.new(0.7, 1.8)
	sparks.Drag = 3
	sparks.Acceleration = Vector3.new(0, 0.7, 0)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-45, 45)
	sparks.LightEmission = 0.95
	sparks.LightInfluence = 0
	sparks.Color = ColorSequence.new(COLORS.Cyan, COLORS.Gold)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.11),
		NumberSequenceKeypoint.new(0.55, 0.07),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Parent = particleAttachment
	sparks:Emit(9)

	-- Keep the projected plane slightly above the floor to prevent surface z-fighting.
	anchor.CFrame = CFrame.new(center.X, surfaceY + 0.075, center.Z)
end

local NEXT_EFFECT_ID = 0

function MagicCircleVFX.Destroy(effect: Folder?)
	if not effect or not effect.Parent then
		return
	end
	effect:Destroy()
end

function MagicCircleVFX.Create(
	parent: Instance,
	surfacePosition: Vector3,
	diameter: number,
	lifetime: number?
): Folder?
	if typeof(parent) ~= "Instance"
		or typeof(surfacePosition) ~= "Vector3"
		or typeof(diameter) ~= "number"
	then
		return nil
	end

	local effectDiameter = math.clamp(diameter, 6, 40)
	local effectLifetime = math.clamp(lifetime or 2.8, 0.5, 8)
	NEXT_EFFECT_ID += 1

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME .. "_" .. tostring(NEXT_EFFECT_ID)
	folder:SetAttribute("VisualRole", "ArenaActivationSigil")
	folder.Parent = parent

	local success, message = pcall(function()
		local center = surfacePosition
		local floorY = surfacePosition.Y

		local anchor = Instance.new("Part")
		anchor.Name = "MagicCircleProjectionPlane"
		anchor.Size = Vector3.new(effectDiameter, 0.06, effectDiameter)
		anchor.CFrame = CFrame.new(center.X, floorY + 0.075, center.Z)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.CastShadow = false
		anchor.Parent = folder

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "ProjectedRunicDiagram"
		surfaceGui.Face = Enum.NormalId.Top
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 72
		surfaceGui.LightInfluence = 0
		surfaceGui.AlwaysOnTop = false
		surfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		surfaceGui.Parent = anchor

		buildOuterRuneLayer(surfaceGui)
		buildMiddleRing(surfaceGui)
		buildInnerSigil(surfaceGui)
		createThreeDimensionalAccents(folder, anchor, center, floorY)

		folder:SetAttribute("SurfacePixelsPerStud", 72)
		folder:SetAttribute("RingLayerCount", 3)
		folder:SetAttribute("GlyphCount", 8)
		folder:SetAttribute("UsesThirdPartyAssets", false)
	end)

	if not success then
		folder:Destroy()
		warn("[SkyfallMagicCircleVFX] Optional sigil build failed: " .. tostring(message))
		return nil
	end

	Debris:AddItem(folder, effectLifetime)
	return folder
end

return MagicCircleVFX
