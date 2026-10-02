-- Bygger "Den bleke damen": høy, mager skikkelse i svart, lang svart hals,
-- blekt strukket ansikt med mørke øyne og langt krøllete svart hår.
-- Modellen ser mot -Z. Root står på bakken (y = 0 er gulvet).

local lib = require("./lib")
local Vector3, CFrame, Enum = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb

local BLACK = rgb(14, 12, 14)
local HAIR = rgb(10, 9, 10)
local SKIN = rgb(226, 220, 210)
local SKIN_DARK = rgb(205, 196, 186)

local function ghost(p: any)
	-- Monsteret er forankret via Root; alt annet sveises fast og kolliderer ikke.
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

local function weld(a: any, b: any)
	lib.new("WeldConstraint", { Part0 = a, Part1 = b }, b)
end

return function(parent: any, name: string?)
	local rng = lib.rng(1313)
	local model = lib.new("Model", { Name = name or "Monster" })

	local root = lib.part(model, "Root", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), BLACK, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	model.PrimaryPart = root

	local body = lib.new("Model", { Name = "Body" }, model)

	local function bodyPart(n: string, size: any, cf: any, color: any?, material: any?)
		local p = ghost(lib.part(body, n, size, cf, color or BLACK, material or Enum.Material.Fabric))
		weld(root, p)
		return p
	end

	-- Kjole/kropp: smalner av oppover
	bodyPart("Gown1", Vector3.new(3.8, 1.6, 2.6), CFrame.new(0, 0.8, 0))
	bodyPart("Gown2", Vector3.new(3.3, 1.8, 2.3), CFrame.new(0, 2.5, 0.05))
	bodyPart("Gown3", Vector3.new(2.9, 1.8, 2.0), CFrame.new(0, 4.3, 0.1))
	bodyPart("Chest", Vector3.new(2.5, 1.6, 1.6), CFrame.new(0, 6.0, 0.1))
	bodyPart("Shoulders", Vector3.new(3.3, 0.6, 1.3), CFrame.new(0, 7.0, 0.1))

	-- Lange, tynne armer som henger nesten til knærne
	for _, side in { -1, 1 } do
		local arm = bodyPart(
			side < 0 and "LeftArm" or "RightArm",
			Vector3.new(0.45, 5.2, 0.45),
			CFrame.new(side * 1.85, 4.5, 0.1) * CFrame.Angles(0, 0, side * math.rad(4))
		)
		arm.Name = side < 0 and "LeftArm" or "RightArm"
		-- Bleke, lange fingre
		for f = -1, 1 do
			bodyPart(
				"Finger",
				Vector3.new(0.12, 1.4, 0.12),
				CFrame.new(side * 2.05 + f * 0.12, 1.3, 0.1 + f * 0.1) * CFrame.Angles(math.rad(f * 6), 0, side * math.rad(3)),
				SKIN_DARK,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Lang svart hals
	local neck = ghost(lib.cylinderY(body, "Neck", 0.75, 2.8, CFrame.new(0, 8.6, 0.1), BLACK, Enum.Material.Fabric))
	weld(root, neck)

	-- Hodet henger på en egen Weld så serveren kan få det til å rykke.
	local headRoot = lib.part(model, "HeadRoot", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 9.9, 0.1), BLACK, nil, {
		Transparency = 1,
	})
	ghost(headRoot)
	lib.new("Weld", {
		Name = "NeckWeld",
		Part0 = root,
		Part1 = headRoot,
		C0 = CFrame.new(0, 8.9, 0.1),
		C1 = CFrame.new(),
	}, root)

	local head = lib.new("Model", { Name = "Head" }, model)
	local function headPart(p: any)
		p.Parent = head
		ghost(p)
		weld(headRoot, p)
		return p
	end
	local H = CFrame.new(0, 9.9, 0.1) -- hodets referansepunkt (halsen)

	-- Ansikt: avlangt og blekt
	local face = headPart(lib.ellipsoid(head, "Face", Vector3.new(2.0, 3.2, 1.7), H * CFrame.new(0, 1.6, 0), SKIN))
	-- Mørke, innsunkne øyne (litt skjeve)
	headPart(lib.ellipsoid(head, "EyeL", Vector3.new(0.44, 0.66, 0.26), H * CFrame.new(-0.42, 2.02, -0.76) * CFrame.Angles(0, 0, math.rad(8)), rgb(8, 6, 8)))
	headPart(lib.ellipsoid(head, "EyeR", Vector3.new(0.42, 0.6, 0.26), H * CFrame.new(0.43, 1.9, -0.77) * CFrame.Angles(0, 0, math.rad(-5)), rgb(8, 6, 8)))
	headPart(lib.ellipsoid(head, "PupilL", Vector3.new(0.09, 0.09, 0.05), H * CFrame.new(-0.4, 2.0, -0.9), rgb(235, 235, 230)))
	headPart(lib.ellipsoid(head, "PupilR", Vector3.new(0.09, 0.09, 0.05), H * CFrame.new(0.45, 1.88, -0.91), rgb(235, 235, 230)))
	-- Lang, smal nese
	headPart(lib.part(head, "Nose", Vector3.new(0.18, 0.85, 0.22), H * CFrame.new(0, 1.45, -0.85), SKIN_DARK))
	-- Mørkerøde lepper med svart munn
	headPart(lib.ellipsoid(head, "Lips", Vector3.new(0.8, 0.32, 0.2), H * CFrame.new(0.03, 0.72, -0.7) * CFrame.Angles(0, 0, math.rad(6)), rgb(92, 12, 18)))
	headPart(lib.ellipsoid(head, "Mouth", Vector3.new(0.55, 0.14, 0.1), H * CFrame.new(0.03, 0.72, -0.79) * CFrame.Angles(0, 0, math.rad(6)), rgb(5, 2, 3)))

	-- Hår: topp, sider og lange krøllete lokker
	headPart(lib.ellipsoid(head, "HairTop", Vector3.new(2.5, 2.4, 2.1), H * CFrame.new(0, 2.45, 0.3), HAIR, Enum.Material.Fabric))
	headPart(lib.ellipsoid(head, "HairLeft", Vector3.new(0.9, 3.1, 1.7), H * CFrame.new(-1.05, 1.2, 0.35), HAIR, Enum.Material.Fabric))
	headPart(lib.ellipsoid(head, "HairRight", Vector3.new(0.9, 3.1, 1.7), H * CFrame.new(1.05, 1.1, 0.35), HAIR, Enum.Material.Fabric))
	headPart(lib.ellipsoid(head, "HairBack", Vector3.new(2.4, 3.4, 1.2), H * CFrame.new(0, 1.0, 0.85), HAIR, Enum.Material.Fabric))

	local strands = 18
	for i = 1, strands do
		local a = math.rad(-115 + (i - 0.5) * (230 / strands)) -- vinkel rundt hodet, 0 = rett bak
		local x = math.sin(a) * 1.05
		local z = 0.3 + math.cos(a) * 0.85
		local len = 2.4 + rng() * 2.8
		local top = 1.2 + rng() * 0.8
		local dia = 0.2 + rng() * 0.14
		local tiltX = (rng() - 0.5) * 0.5 + math.cos(a) * 0.15
		local tiltZ = (rng() - 0.5) * 0.4 - math.sin(a) * 0.15
		local cf = H * CFrame.new(x, top, z) * CFrame.Angles(tiltX, 0, tiltZ) * CFrame.new(0, -len / 2, 0)
		headPart(lib.cylinderY(head, "Strand", dia, len, cf, HAIR, Enum.Material.Fabric))
		-- krøll på enden av lokken
		local tip = cf * CFrame.new(0, -len / 2, 0)
		headPart(lib.ellipsoid(head, "Curl", Vector3.new(0.55, 0.7, 0.55), tip * CFrame.Angles(rng() * 3, rng() * 3, 0), HAIR, Enum.Material.Fabric))
	end

	-- Plate foran ansiktet der en valgfri Decal kan legges (se Config.MonsterFaceDecal)
	headPart(lib.part(head, "FaceDecalPlate", Vector3.new(2.0, 3.2, 0.05), H * CFrame.new(0, 1.6, -0.9), SKIN, nil, {
		Transparency = 1,
		CastShadow = false,
	}))

	-- Svakt lys på ansiktet, så hun såvidt synes i mørket
	lib.new("PointLight", {
		Name = "FaceGlow",
		Range = 6,
		Brightness = 0.35,
		Color = rgb(220, 225, 235),
		Shadows = false,
	}, face)

	model.Parent = parent
	return model
end
