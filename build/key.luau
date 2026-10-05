-- Nøkkelen spillerne skal finne. Den ligger flatt på bordet (eller gulvet) og skinner:
-- varmt lys som pulserer, glitter, en gyllen glød rundt kanten og en klingende lyd.

local roblox = require("@lune/roblox")
local lib = require("./lib")
local Vector3, CFrame, Enum = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb

return function(parent: any)
	local GOLD = rgb(236, 190, 72)
	local key = lib.new("Model", { Name = "Key", Tags = { "Key" }, ModelStreamingMode = Enum.ModelStreamingMode.Atomic })
	local function keyPart(name: string, size: any, cf: any, color: any?)
		return lib.part(key, name, size, cf, color or GOLD, Enum.Material.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.15 })
	end
	local bow = lib.cylinderY(key, "Bow", 1.1, 0.18, CFrame.new(0, 0, 0.8), GOLD, Enum.Material.Metal)
	bow.CanCollide = false
	bow.Reflectance = 0.15
	lib.cylinderY(key, "BowHole", 0.5, 0.2, CFrame.new(0, 0, 0.8), rgb(40, 30, 12), Enum.Material.Metal).CanCollide = false
	keyPart("Shaft", Vector3.new(0.22, 0.18, 1.7), CFrame.new(0, 0, -0.45))
	keyPart("Tooth1", Vector3.new(0.45, 0.18, 0.22), CFrame.new(0.3, 0, -1.1))
	keyPart("Tooth2", Vector3.new(0.35, 0.18, 0.2), CFrame.new(0.25, 0, -0.65))
	-- Nøkkelen skinner: varmt lys rundt seg, glitter og en svak, klingende lyd (hjelper deg å finne den)
	lib.new("PointLight", { Name = "Glow", Range = 15, Brightness = 2.8, Color = rgb(255, 200, 100), Shadows = false }, bow)
	-- gyllen kant og fyll, så nøkkelen synes godt på bordet (bare når du har den i synsfeltet)
	lib.new("Highlight", {
		Name = "Shine",
		FillColor = rgb(255, 210, 110),
		FillTransparency = 0.6,
		OutlineColor = rgb(255, 236, 170),
		OutlineTransparency = 0.25,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	}, key)
	lib.new("ParticleEmitter", {
		Name = "Sparkles",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 11,
		Lifetime = roblox.NumberRange.new(0.8, 1.6),
		Speed = roblox.NumberRange.new(0.2, 0.7),
		SpreadAngle = lib.Vector2.new(180, 180),
		Size = roblox.NumberSequence.new({
			roblox.NumberSequenceKeypoint.new(0, 0),
			roblox.NumberSequenceKeypoint.new(0.2, 0.32),
			roblox.NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = roblox.NumberSequence.new({
			roblox.NumberSequenceKeypoint.new(0, 0.1),
			roblox.NumberSequenceKeypoint.new(1, 1),
		}),
		Color = roblox.ColorSequence.new(rgb(255, 225, 140)),
		LightEmission = 1,
		LightInfluence = 0,
		RotSpeed = roblox.NumberRange.new(-90, 90),
		Rotation = roblox.NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, 0.6, 0),
	}, bow)
	lib.new("Sound", {
		Name = "Shimmer",
		SoundId = "rbxassetid://9125986205", -- Sparkle Tone Constant High End Shimmer (samme som Config.Sounds.KeyShimmer)
		Volume = 0.6,
		Looped = true,
		Playing = true,
		RollOffMode = Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = 6,
		RollOffMaxDistance = 48,
	}, bow)
	lib.new("ProximityPrompt", {
		Name = "PickupPrompt",
		ActionText = "Pick up",
		ObjectText = "Key",
		HoldDuration = 0.25,
		MaxActivationDistance = 8,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
	}, bow)
	key.WorldPivotData = CFrame.new(0, 0, 0)
	key.Parent = parent
	return key
end
