local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("GameConfig", 8))

local LaserVFX = {}

local LAYER_COUNT = 24
local BEAM_LAYER_COUNT = 14
local FLOW_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FLOW_TEXTURE_SPEED = 3.2
local SHOT_SERIAL = 0

local EXTENSION_INFO = TweenInfo.new(
	Config.LASER_EXTENSION_SECONDS,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.Out
)
local FADE_INFO = TweenInfo.new(
	Config.LASER_FADE_SECONDS,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.In
)

local BEAM_LAYERS = {
	{
		name = "LaserOuterAtmosphere",
		width0 = 6.6,
		width1 = 5.0,
		color = Color3.fromRGB(25, 91, 255),
		transparency = 0.94,
		segments = 8,
	},
	{
		name = "LaserOuterGlow",
		width0 = 4.9,
		width1 = 3.8,
		color = Color3.fromRGB(38, 126, 255),
		transparency = 0.88,
		segments = 8,
	},
	{
		name = "LaserCyanEnvelope",
		width0 = 3.45,
		width1 = 2.7,
		color = Color3.fromRGB(41, 177, 255),
		transparency = 0.78,
		segments = 8,
	},
	{
		name = "LaserAzureShell",
		width0 = 2.55,
		width1 = 1.95,
		color = Color3.fromRGB(54, 165, 255),
		transparency = 0.58,
		segments = 8,
	},
	{
		name = "LaserIonLayer",
		width0 = 1.7,
		width1 = 1.3,
		color = Color3.fromRGB(105, 220, 255),
		transparency = 0.42,
		segments = 8,
	},
	{
		name = "LaserHotCore",
		width0 = 0.76,
		width1 = 0.54,
		color = Color3.fromRGB(239, 252, 255),
		transparency = 0.025,
		segments = 8,
	},
	{
		name = "LaserWhiteFilament",
		width0 = 0.23,
		width1 = 0.16,
		color = Color3.fromRGB(255, 255, 255),
		transparency = 0.08,
		segments = 8,
	},
	{
		name = "LaserGoldenFilament",
		width0 = 0.12,
		width1 = 0.085,
		color = Color3.fromRGB(255, 226, 157),
		transparency = 0.2,
		segments = 8,
	},
	{
		name = "LaserEnergyFlowPrimary",
		width0 = 1.05,
		width1 = 0.82,
		color = Color3.fromRGB(33, 147, 255),
		transparency = 0.28,
		texture = true,
		textureLength = 2.2,
		segments = 12,
	},
	{
		name = "LaserEnergyFlowSecondary",
		width0 = 0.72,
		width1 = 0.55,
		color = Color3.fromRGB(156, 241, 255),
		transparency = 0.57,
		texture = true,
		textureLength = 1.15,
		textureSpeed = 2.1,
		segments = 12,
	},
	{
		name = "LaserRefractionArcA",
		width0 = 0.2,
		width1 = 0.14,
		color = Color3.fromRGB(96, 213, 255),
		transparency = 0.72,
		curve0 = 6,
		curve1 = -3,
		segments = 16,
	},
	{
		name = "LaserRefractionArcB",
		width0 = 0.17,
		width1 = 0.12,
		color = Color3.fromRGB(47, 127, 255),
		transparency = 0.76,
		curve0 = -6,
		curve1 = 3,
		segments = 16,
	},
	{
		name = "LaserRefractionArcC",
		width0 = 0.12,
		width1 = 0.085,
		color = Color3.fromRGB(152, 236, 255),
		transparency = 0.82,
		curve0 = 3,
		curve1 = -7,
		segments = 16,
	},
	{
		name = "LaserRefractionArcD",
		width0 = 0.1,
		width1 = 0.07,
		color = Color3.fromRGB(69, 165, 255),
		transparency = 0.84,
		curve0 = -3,
		curve1 = 7,
		segments = 16,
	},
}

local function makeParticleEmitter(parent, name, color, lifetime, speed, sizeStart, sizePeak)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = FLOW_TEXTURE
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(lifetime[1], lifetime[2])
	emitter.Speed = NumberRange.new(speed[1], speed[2])
	emitter.Drag = 5
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.LightEmission = 0.95
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(color[1], color[2])
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sizeStart),
		NumberSequenceKeypoint.new(0.28, sizePeak),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.72, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

local function makePulse(parent, name, position, shape, color)
	local pulse = Instance.new("Part")
	pulse.Name = name
	pulse.Shape = shape
	pulse.Anchored = true
	pulse.Size = shape == Enum.PartType.Ball and Vector3.new(1.2, 1.2, 1.2) or Vector3.new(0.12, 1.4, 1.4)
	pulse.CFrame = shape == Enum.PartType.Ball
		and CFrame.new(position)
		or CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	pulse.Color = color
	pulse.Material = Enum.Material.Neon
	pulse.Transparency = 1
	pulse.Reflectance = 0
	pulse.CanCollide = false
	pulse.CanTouch = false
	pulse.CanQuery = false
	pulse.CastShadow = false
	pulse.Parent = parent
	return pulse
end

local function triggerPulse(pulse, initialSize, finalSize, initialTransparency, duration)
	pulse.Size = initialSize
	pulse.Transparency = initialTransparency
	local tween = TweenService:Create(
		pulse,
		TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = finalSize,
			Transparency = 1,
		}
	)
	tween:Play()
end

local function makePointLight(parent, name, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = name
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	return light
end

local function createImpactSound(tile)
	local sound = Instance.new("Sound")
	sound.Name = "LaserImpactSound"
	sound.SoundId = "rbxassetid://" .. Config.LASER_SOUND_ID
	sound.Volume = Config.AUDIO_LASER_VOLUME
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 180
	sound.EmitterSize = 8
	sound.Parent = tile
	sound:Play()
	Debris:AddItem(sound, 3)
end

function LaserVFX.Create(arena, tile)
	if not arena
		or not arena.laserOrigin
		or not arena.laserOrigin.Parent
		or not tile
		or not tile.Parent
	then
		return false
	end

	local source = arena.laserOrigin
	local sourcePart = source.Parent
	local startPosition = source.WorldPosition
	local targetPosition = tile.Position + Vector3.new(0, 0.65, 0)
	if (targetPosition - startPosition).Magnitude < 1 then
		return false
	end

	SHOT_SERIAL += 1
	local shotFolder = Instance.new("Folder")
	shotFolder.Name = "LaserVFXShot_" .. tostring(SHOT_SERIAL)
	shotFolder:SetAttribute("VisualLayerCount", LAYER_COUNT)
	shotFolder:SetAttribute("BeamLayerCount", BEAM_LAYER_COUNT)
	shotFolder:SetAttribute("ParticleLayerCount", 4)
	shotFolder:SetAttribute("LightLayerCount", 2)
	shotFolder:SetAttribute("PulseLayerCount", 4)
	shotFolder.Parent = arena.root

	local endpoint = Instance.new("Part")
	endpoint.Name = "LaserBeamEndpoint"
	endpoint.Size = Vector3.new(0.15, 0.15, 0.15)
	endpoint.CFrame = CFrame.lookAt(startPosition, targetPosition)
	endpoint.Transparency = 1
	endpoint.Anchored = true
	endpoint.CanCollide = false
	endpoint.CanTouch = false
	endpoint.CanQuery = false
	endpoint.CastShadow = false
	endpoint:SetAttribute("StartPosition", startPosition)
	endpoint:SetAttribute("TargetPosition", targetPosition)
	endpoint:SetAttribute("ExtensionDuration", Config.LASER_EXTENSION_SECONDS)
	endpoint.Parent = shotFolder

	local endpointAttachment = Instance.new("Attachment")
	endpointAttachment.Name = "LaserBeamEndpointAttachment"
	endpointAttachment.Parent = endpoint

	for _, layer in ipairs(BEAM_LAYERS) do
		local beam = Instance.new("Beam")
		beam.Name = layer.name
		beam.Attachment0 = source
		beam.Attachment1 = endpointAttachment
		beam.FaceCamera = true
		beam.Width0 = 0
		beam.Width1 = 0
		beam.Segments = layer.segments or 8
		beam.CurveSize0 = layer.curve0 or 0
		beam.CurveSize1 = layer.curve1 or 0
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(layer.color)
		beam.Transparency = NumberSequence.new(layer.transparency)
		beam.ZOffset = layer.zOffset or 0
		if layer.texture then
			beam.Texture = FLOW_TEXTURE
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = layer.textureLength
			beam.TextureSpeed = layer.textureSpeed or FLOW_TEXTURE_SPEED
		end
		beam.Parent = shotFolder

		local widthTween = TweenService:Create(
			beam,
			EXTENSION_INFO,
			{
				Width0 = layer.width0,
				Width1 = layer.width1,
			}
		)
		widthTween:Play()
	end

	local muzzleAttachment = Instance.new("Attachment")
	muzzleAttachment.Name = "LaserMuzzleAttachment"
	muzzleAttachment.Position = source.Position
	muzzleAttachment.Parent = sourcePart

	local muzzleSparks = makeParticleEmitter(
		muzzleAttachment,
		"LaserParticles_MuzzleSparks",
		{Color3.fromRGB(111, 209, 255), Color3.fromRGB(255, 255, 255)},
		{0.12, 0.3},
		{5, 12},
		0.34,
		0.18
	)
	local muzzleMist = makeParticleEmitter(
		muzzleAttachment,
		"LaserParticles_MuzzleMist",
		{Color3.fromRGB(35, 116, 255), Color3.fromRGB(113, 234, 255)},
		{0.16, 0.34},
		{1, 4},
		0.72,
		0.42
	)
	muzzleSparks:Emit(6)
	muzzleMist:Emit(3)

	local muzzleLight = makePointLight(
		muzzleAttachment,
		"LaserMuzzleLight",
		Color3.fromRGB(76, 190, 255),
		2.8,
		9
	)
	TweenService:Create(
		muzzleLight,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0, Range = 2}
	):Play()
	Debris:AddItem(muzzleAttachment, 1.1)

	local muzzlePulse = makePulse(
		shotFolder,
		"LaserPulse_Muzzle",
		startPosition,
		Enum.PartType.Ball,
		Color3.fromRGB(114, 211, 255)
	)
	local impactPulse = makePulse(
		shotFolder,
		"LaserPulse_Impact",
		targetPosition,
		Enum.PartType.Ball,
		Color3.fromRGB(221, 249, 255)
	)
	local wavePulseA = makePulse(
		shotFolder,
		"LaserPulse_WaveA",
		targetPosition + Vector3.new(0, 0.08, 0),
		Enum.PartType.Cylinder,
		Color3.fromRGB(37, 159, 255)
	)
	local wavePulseB = makePulse(
		shotFolder,
		"LaserPulse_WaveB",
		targetPosition + Vector3.new(0, 0.15, 0),
		Enum.PartType.Cylinder,
		Color3.fromRGB(122, 230, 255)
	)

	triggerPulse(
		muzzlePulse,
		Vector3.new(1.1, 1.1, 1.1),
		Vector3.new(3.8, 3.8, 3.8),
		0.22,
		0.3
	)

	local impactAttachment = Instance.new("Attachment")
	impactAttachment.Name = "LaserImpactAttachment"
	impactAttachment.Position = Vector3.new(0, 0.65, 0)
	impactAttachment.Parent = tile

	local impactSparks = makeParticleEmitter(
		impactAttachment,
		"LaserParticles_ImpactSparks",
		{Color3.fromRGB(90, 194, 255), Color3.fromRGB(255, 255, 255)},
		{0.18, 0.42},
		{12, 23},
		0.46,
		0.22
	)
	local impactFragments = makeParticleEmitter(
		impactAttachment,
		"LaserParticles_ImpactFragments",
		{Color3.fromRGB(255, 226, 164), Color3.fromRGB(153, 224, 255)},
		{0.22, 0.48},
		{8, 17},
		0.28,
		0.12
	)
	local impactLight = makePointLight(
		impactAttachment,
		"LaserImpactLight",
		Color3.fromRGB(132, 219, 255),
		4.2,
		18
	)
	Debris:AddItem(impactAttachment, 1.25)

	local extensionTween = TweenService:Create(
		endpoint,
		EXTENSION_INFO,
		{Position = targetPosition}
	)
	extensionTween:Play()

	task.spawn(function()
		local playbackState = extensionTween.Completed:Wait()
		if playbackState ~= Enum.PlaybackState.Completed or not shotFolder.Parent then
			return
		end

		impactSparks:Emit(16)
		impactFragments:Emit(8)
		triggerPulse(
			impactPulse,
			Vector3.new(1.6, 1.6, 1.6),
			Vector3.new(7.8, 7.8, 7.8),
			0.18,
			0.34
		)
		triggerPulse(
			wavePulseA,
			Vector3.new(0.12, 2.4, 2.4),
			Vector3.new(0.12, 15, 15),
			0.22,
			0.38
		)
		triggerPulse(
			wavePulseB,
			Vector3.new(0.12, 1.5, 1.5),
			Vector3.new(0.12, 9.5, 9.5),
			0.34,
			0.32
		)
		TweenService:Create(
			impactLight,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Brightness = 0, Range = 3}
		):Play()
		createImpactSound(tile)

		task.wait(Config.LASER_HOLD_SECONDS)
		if not shotFolder.Parent then
			return
		end

		for _, beam in ipairs(shotFolder:GetChildren()) do
			if beam:IsA("Beam") then
				TweenService:Create(
					beam,
					FADE_INFO,
					{Width0 = 0, Width1 = 0}
				):Play()
			end
		end
	end)

	Debris:AddItem(
		shotFolder,
		Config.LASER_EXTENSION_SECONDS
			+ Config.LASER_HOLD_SECONDS
			+ Config.LASER_FADE_SECONDS
			+ 0.4
	)
	return true
end

return LaserVFX
