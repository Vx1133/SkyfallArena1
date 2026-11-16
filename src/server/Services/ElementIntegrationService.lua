--!strict

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldDesignProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldDesignProfile"))
local FloorAppearanceService = require(script.Parent:WaitForChild("FloorAppearanceService"))

local ElementIntegrationService = {}
local warnedMissingTargets = false

type ElementDefinition = {
	key: string,
	color: Color3,
}

type Candidate = {
	instance: Instance,
	definition: ElementDefinition,
	depth: number,
}

local ELEMENTS: {[string]: ElementDefinition} = {
	fire = { key = "Fire", color = Color3.fromRGB(237, 103, 66) },
	water = { key = "Water", color = Color3.fromRGB(62, 164, 224) },
	earth = {
		key = "Earth",
		color = Color3.fromRGB(
			WorldDesignProfile.Cyberpunk.Earth[1],
			WorldDesignProfile.Cyberpunk.Earth[2],
			WorldDesignProfile.Cyberpunk.Earth[3]
		),
	},
	air = { key = "Air", color = Color3.fromRGB(184, 219, 235) },
}

local NAME_TO_ELEMENT: {[string]: string} = {
	fire = "fire",
	fireelement = "fire",
	elementfire = "fire",
	firezone = "fire",
	firearea = "fire",
	water = "water",
	waterelement = "water",
	elementwater = "water",
	waterzone = "water",
	waterarea = "water",
	earth = "earth",
	earthelement = "earth",
	elementearth = "earth",
	earthzone = "earth",
	eartharea = "earth",
	air = "air",
	airelement = "air",
	elementair = "air",
	airzone = "air",
	airarea = "air",
}

local TAG_TO_ELEMENT: {[string]: string} = {
	SkyfallFireElement = "fire",
	SkyfallWaterElement = "water",
	SkyfallEarthElement = "earth",
	SkyfallAirElement = "air",
}

local function normalizeName(value: string): string
	return string.lower(string.gsub(value, "[^%w]", ""))
end

local function getDefinition(instance: Instance): ElementDefinition?
	local typeAttribute = instance:GetAttribute("SkyfallElementType") or instance:GetAttribute("ElementType")
	if typeof(typeAttribute) == "string" then
		local key = normalizeName(typeAttribute)
		if ELEMENTS[key] then
			return ELEMENTS[key]
		end
	end

	for tag, key in pairs(TAG_TO_ELEMENT) do
		if CollectionService:HasTag(instance, tag) then
			return ELEMENTS[key]
		end
	end

	if CollectionService:HasTag(instance, "SkyfallElement") then
		local key = NAME_TO_ELEMENT[normalizeName(instance.Name)]
		if key then
			return ELEMENTS[key]
		end
	end

	local key = NAME_TO_ELEMENT[normalizeName(instance.Name)]
	return key and ELEMENTS[key] or nil
end

local function getDepth(instance: Instance): number
	local depth = 0
	local current = instance.Parent
	while current and current ~= Workspace do
		depth += 1
		current = current.Parent
	end
	return depth
end

local function isSupportedRoot(instance: Instance): boolean
	return instance:IsA("Model") or instance:IsA("BasePart")
end

local function findElementRoots(targetFolder: Folder): {Candidate}
	local candidates: {Candidate} = {}
	local seen: {[Instance]: boolean} = {}

	local function addCandidate(instance: Instance)
		if seen[instance] or not isSupportedRoot(instance) then
			return
		end
		if not instance:IsDescendantOf(Workspace) or instance == targetFolder or instance:IsDescendantOf(targetFolder) then
			return
		end

		local definition = getDefinition(instance)
		if not definition then
			return
		end

		seen[instance] = true
		table.insert(candidates, {
			instance = instance,
			definition = definition,
			depth = getDepth(instance),
		})
	end

	for _, instance in ipairs(CollectionService:GetTagged("SkyfallElement")) do
		addCandidate(instance)
	end
	for tag in pairs(TAG_TO_ELEMENT) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			addCandidate(instance)
		end
	end
	for _, instance in ipairs(Workspace:GetDescendants()) do
		addCandidate(instance)
	end

	table.sort(candidates, function(left, right)
		return left.depth < right.depth
	end)

	local roots: {Candidate} = {}
	for _, candidate in ipairs(candidates) do
		local nested = false
		for _, root in ipairs(roots) do
			if candidate.instance:IsDescendantOf(root.instance) then
				nested = true
				break
			end
		end
		if not nested then
			table.insert(roots, candidate)
		end
	end

	return roots
end

local function getBounds(instance: Instance): (CFrame?, Vector3?)
	local success, frame, size = pcall(function()
		if instance:IsA("Model") then
			return instance:GetBoundingBox()
		end
		local part = instance :: BasePart
		return part.CFrame, part.Size
	end)
	if not success or typeof(frame) ~= "CFrame" or typeof(size) ~= "Vector3" then
		warn("Skyfall could not read element bounds for " .. instance:GetFullName() .. ": " .. tostring(frame))
		return nil, nil
	end
	return frame, size
end

local function createTransitionLayer(
	parent: Folder,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	profile: FloorAppearanceService.AppearanceProfile,
	transparency: number
): Part
	local layer = Instance.new("Part")
	layer.Name = name
	layer.Anchored = true
	layer.Size = size
	layer.Position = position
	layer.Transparency = transparency
	layer.CanCollide = false
	layer.CanTouch = false
	layer.CanQuery = false
	layer.CastShadow = false
	layer:SetAttribute("SkyfallGenerated", true)

	if not FloorAppearanceService.ApplySurface(layer, profile) then
		layer:Destroy()
		error("Skyfall could not apply the lobby surface profile to element transition " .. name)
	end
	layer.Color = color
	layer.Parent = parent
	return layer
end

function ElementIntegrationService.Build(
	targetFolder: Folder,
	lobbyFloor: BasePart?,
	mapBaseColor: Color3?
): number
	local transitionFolder = targetFolder:FindFirstChild("ElementTransitions")
	if transitionFolder then
		transitionFolder:Destroy()
	end
	transitionFolder = Instance.new("Folder")
	transitionFolder.Name = "ElementTransitions"
	transitionFolder:SetAttribute("SkyfallGenerated", true)
	transitionFolder.Parent = targetFolder

	local appearance = FloorAppearanceService.Capture(lobbyFloor)
	if not appearance then
		error("Skyfall element transitions require the live Lobby.WaitingPlatform profile")
	end
	local floorColor = mapBaseColor or appearance.Color
	local candidates = findElementRoots(transitionFolder)
	local builtCount = 0

	for _, candidate in ipairs(candidates) do
		local frame, bounds = getBounds(candidate.instance)
		if frame and bounds and bounds.X >= 2 and bounds.Z >= 2 then
			local baseX = math.clamp(bounds.X, 4, 152)
			local baseZ = math.clamp(bounds.Z, 4, 152)
			local baseY = frame.Position.Y - bounds.Y * 0.5
			local layers = {
				{ margin = 12, rise = 0.06, blend = 0.12, transparency = 0.2 },
				{ margin = 8, rise = 0.2, blend = 0.42, transparency = 0.12 },
				{ margin = 4, rise = 0.34, blend = 0.72, transparency = 0.06 },
			}

			local innerLayer: Part? = nil
			for index, layerData in ipairs(layers) do
				local color = floorColor:Lerp(candidate.definition.color, layerData.blend)
				local part = createTransitionLayer(
					transitionFolder,
					candidate.definition.key .. "TransitionLayer" .. tostring(index),
					Vector3.new(frame.Position.X, baseY + layerData.rise, frame.Position.Z),
					Vector3.new(
						math.min(baseX + layerData.margin * 2, 176),
						0.14,
						math.min(baseZ + layerData.margin * 2, 176)
					),
					color,
					appearance,
					layerData.transparency
				)
				if index == #layers then
					innerLayer = part
				end
			end

			if innerLayer then
				local light = Instance.new("PointLight")
				light.Name = candidate.definition.key .. "TransitionLight"
				light.Color = candidate.definition.color
				light.Brightness = 0.12
				light.Range = math.clamp(math.max(baseX, baseZ) * 0.12, 8, 16)
				light.Shadows = false
				light.Parent = innerLayer

				local pulse = TweenService:Create(
					light,
					TweenInfo.new(3.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Brightness = 0.22 }
				)
				pulse:Play()
			end

			builtCount += 1
		end
	end

	if builtCount == 0 and not warnedMissingTargets then
		warnedMissingTargets = true
		warn("Skyfall found no existing Fire, Water, Earth, or Air element model. Tag each existing Model/BasePart with SkyfallElement and set SkyfallElementType to Fire, Water, Earth, or Air. No replacement map was created.")
	end

	return builtCount
end

return ElementIntegrationService
