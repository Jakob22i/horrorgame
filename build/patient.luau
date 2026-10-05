-- "THE PATIENT" (Patient #0413)
-- En høy, utmagret pasient i en gulnet, blodflekket sykehuskjortel. Den er krumbøyd,
-- har lang hals, svarte øyehuler med lysende knappenålspupiller og et altfor bredt glis
-- med sydde kutt ut mot ørene. Den drar et rustent dryppstativ med en blodpose etter seg.
--
-- Modellen ser mot -Z og står med føttene på y = 0. Root (forankret) er på y = 1.
-- Alle synlige deler er sveiset (Weld med C0) til "bein" i Rig-mappen, slik at klienten
-- kan animere leddene i Joints-mappen (Waist, Spine, Neck, Jaw, skuldre, albuer, hofter, knær).

local lib = require("./lib")
local Vector3, CFrame, Enum = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb

local C = {
	skin = rgb(170, 170, 164),
	skinDark = rgb(132, 126, 118),
	face = rgb(206, 204, 196),
	faceShade = rgb(168, 164, 158),
	bruise = rgb(132, 116, 122),
	hollow = rgb(6, 4, 5),
	gown = rgb(132, 152, 154),
	gownDark = rgb(110, 128, 130),
	gownTrim = rgb(92, 108, 112),
	stain = rgb(128, 116, 70),
	blood = rgb(104, 12, 16),
	bloodDry = rgb(64, 16, 14),
	teeth = rgb(226, 216, 182),
	teethOld = rgb(184, 166, 108),
	gum = rgb(84, 22, 28),
	lip = rgb(158, 134, 130),
	nail = rgb(54, 42, 34),
	hair = rgb(28, 24, 20),
	gauze = rgb(216, 208, 178),
	vein = rgb(96, 102, 122),
	metal = rgb(178, 180, 178),
	rust = rgb(112, 74, 48),
	bag = rgb(120, 10, 18),
	band = rgb(234, 232, 222),
	tag = rgb(212, 190, 136),
}

local M = Enum.Material
local UP = Vector3.new(0, 1, 0)

local function lerp(a: any, b: any, t: number)
	return a + (b - a) * t
end

-- Punkt på en kvadratisk/kubisk Bezier-kurve
local function bezier(points: { any }, t: number)
	local pts = table.clone(points)
	while #pts > 1 do
		local nxt = {}
		for i = 1, #pts - 1 do
			table.insert(nxt, lerp(pts[i], pts[i + 1], t))
		end
		pts = nxt
	end
	return pts[1]
end

-- Enkel to-ledds IK: finner albue/kne mellom a og c med lengdene l1 og l2
local function ik(a: any, c: any, l1: number, l2: number, hint: any)
	local ac = c - a
	local d = math.min(ac.Magnitude, l1 + l2 - 0.01)
	local dir = ac.Unit
	local x = (d * d + l1 * l1 - l2 * l2) / (2 * d)
	local h = math.sqrt(math.max(0, l1 * l1 - x * x))
	local perp = (hint - dir * hint:Dot(dir)).Unit
	return a + dir * x + perp * h
end

-- Punkt og normal på en ellipsoide (cf = senter, size = full størrelse) i lokal retning d
local function ellPoint(cf: any, size: any, d: any)
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	local k = 1 / math.sqrt((d.X / a) ^ 2 + (d.Y / b) ^ 2 + (d.Z / c) ^ 2)
	local p = d * k
	local n = Vector3.new(p.X / (a * a), p.Y / (b * b), p.Z / (c * c)).Unit
	return cf:PointToWorldSpace(p), cf:VectorToWorldSpace(n)
end

-- CFrame som ser i retning n (lokal -Z = n) med en "opp"-retning
local function facing(pos: any, n: any, up: any?)
	local u = up or UP
	if math.abs(n.Unit:Dot(u.Unit)) > 0.98 then
		u = Vector3.new(0, 0, 1)
	end
	return lib.lookAt(pos, pos + n, u)
end

return function(parent: any, name: string?)
	local rng = lib.rng(413)
	local function rr(a: number, b: number): number
		return a + (b - a) * rng()
	end

	local model = lib.new("Model", { Name = name or "Monster", Attributes = { Rig = "Patient" } })
	local rig = lib.new("Folder", { Name = "Rig" }, model)
	local joints = lib.new("Folder", { Name = "Joints" }, model)

	local root = lib.part(model, "Root", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), C.skin, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	model.PrimaryPart = root

	------------------------------------------------------------------
	-- Bein og sveising
	------------------------------------------------------------------
	local cur = { bone = root, group = model }

	local function bone(boneName: string, cf: any, parentBone: any)
		local b = lib.part(rig, boneName, Vector3.new(0.2, 0.2, 0.2), cf, C.skin, nil, {
			Anchored = false,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			CastShadow = false,
		})
		lib.new("Weld", {
			Name = boneName,
			Part0 = parentBone,
			Part1 = b,
			C0 = parentBone.CFrame:Inverse() * cf,
			C1 = CFrame.new(),
		}, joints)
		return b
	end

	local function use(b: any, group: any)
		cur.bone = b
		cur.group = group
	end

	local function attach(p: any)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		lib.new("Weld", { Part0 = cur.bone, Part1 = p, C0 = cur.bone.CFrame:Inverse() * p.CFrame, C1 = CFrame.new() }, p)
		return p
	end

	local function blk(n: string, size: any, cf: any, color: any, mat: any?)
		return attach(lib.part(cur.group, n, size, cf, color, mat or M.SmoothPlastic))
	end

	local function ell(n: string, size: any, cf: any, color: any, mat: any?)
		return attach(lib.ellipsoid(cur.group, n, size, cf, color, mat or M.SmoothPlastic))
	end

	local function ball(n: string, pos: any, d: number, color: any, mat: any?)
		return ell(n, Vector3.new(d, d, d), CFrame.new(pos), color, mat)
	end

	-- Sylinder fra a til b
	local function seg(n: string, a: any, b: any, d: number, color: any, mat: any?)
		local len = (b - a).Magnitude
		if len < 0.01 then
			return nil
		end
		local mid = (a + b) / 2
		local dir = (b - a).Unit
		local up = math.abs(dir.Y) > 0.97 and Vector3.new(0, 0, 1) or UP
		local cf = lib.lookAt(mid, b, up) * CFrame.Angles(0, math.pi / 2, 0)
		return attach(lib.part(cur.group, n, Vector3.new(len, d, d), cf, color, mat or M.SmoothPlastic, { Shape = Enum.PartType.Cylinder }))
	end

	-- Ellipsoide strukket fra a til b (lokal Y langs lemmen)
	local function spindle(n: string, a: any, b: any, w: number, depth: number?, color: any, mat: any?)
		local dir = (b - a).Unit
		local side = math.abs(dir.X) > 0.9 and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
		local xAxis = (side - dir * side:Dot(dir)).Unit
		local cf = CFrame.fromMatrix((a + b) / 2, xAxis, dir)
		return ell(n, Vector3.new(w, (b - a).Magnitude, depth or w), cf, color, mat)
	end

	-- Organisk, benete lem: smal kjerne + muskelbuer som smalner av
	local function limb(n: string, a: any, b: any, d1: number, d2: number, color: any, mat: any?)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		seg(n, a + dir * 0.1, b - dir * 0.1, d2 * 0.8, color, mat)
		spindle(n .. "Muscle", a + dir * (len * -0.02), a + dir * (len * 0.7), d1 * 1.12, d1 * 1.05, color, mat)
		spindle(n .. "Lower", a + dir * (len * 0.45), b + dir * 0.05, d2 * 1.05, d2, color, mat)
	end

	-- Merke/flekk på en buet overflate: en ellipsoide som er senket inn slik at bare
	-- en tynn, buet kalott stikker ut (flate skiver ville stått ut fra kantene)
	local function flat(n: string, pos: any, normal: any, w: number, h: number, thick: number, color: any, roll: number?, mat: any?, up: any?)
		local D = math.max(thick, 0.45 * math.max(w, h))
		local center = pos - normal * (D / 2 - thick / 2)
		local cf = facing(center, normal, up) * CFrame.Angles(0, 0, roll or 0)
		return ell(n, Vector3.new(w, h, D), cf, color, mat)
	end

	-- Kurve av sylindere gjennom punkter
	local function curve(n: string, pts: { any }, d1: number, d2: number, color: any, mat: any?)
		for i = 1, #pts - 1 do
			local t = (i - 1) / math.max(1, #pts - 2)
			local d = d1 + (d2 - d1) * t
			seg(n, pts[i], pts[i + 1], d, color, mat)
			if i > 1 then
				ball(n, pts[i], d, color, mat)
			end
		end
	end

	-- Uregelmessig flekk: flere overlappende flater + renner nedover
	local function stain(n: string, pos: any, normal: any, size: number, color: any, drips: number?, mat: any?)
		for k = 1, 4 do
			local off = Vector3.new(rr(-0.5, 0.5), rr(-0.5, 0.5), rr(-0.5, 0.5)) * size * 0.5
			off -= normal * off:Dot(normal)
			flat(n, pos + off + normal * (0.004 * k), normal, size * rr(0.45, 0.9), size * rr(0.4, 0.8), 0.03, color, rr(0, 3), mat)
		end
		for k = 1, drips or 0 do
			local x = Vector3.new(rr(-0.3, 0.3) * size, 0, 0)
			local len = rr(0.3, 0.9) * size + 0.2
			local down = Vector3.new(0, -1, 0)
			down = (down - normal * down:Dot(normal)).Unit
			local p0 = pos + x + down * (size * 0.25)
			flat(n .. "Drip", p0 + down * (len / 2) + normal * 0.012, normal, 0.05 + rr(0, 0.03), len, 0.03, color, 0, mat)
			ell(n .. "Drop", Vector3.new(0.09, 0.11, 0.05), facing(p0 + down * len + normal * 0.012, normal), color, mat)
		end
	end

	------------------------------------------------------------------
	-- Skjelett (posisjoner i hvilestilling)
	------------------------------------------------------------------
	local HIP_L, HIP_R = Vector3.new(-0.7, 5.35, 0.28), Vector3.new(0.7, 5.35, 0.28)
	local ANKLE_L, ANKLE_R = Vector3.new(-0.88, 0.5, 0.02), Vector3.new(0.92, 0.5, 0.2)
	local KNEE_L = ik(HIP_L, ANKLE_L, 2.6, 2.45, Vector3.new(-0.1, 0, -1))
	local KNEE_R = ik(HIP_R, ANKLE_R, 2.6, 2.45, Vector3.new(0.15, 0, -1))

	local SPINE = {
		Vector3.new(0, 5.55, 0.3),
		Vector3.new(0, 6.6, 0.55),
		Vector3.new(0, 7.6, 0.3),
		Vector3.new(0, 8.35, -0.15),
		Vector3.new(0, 8.8, -0.6),
	}
	local NECK_TOP = Vector3.new(0, 9.78, -1.66)

	local SH_R, SH_L = Vector3.new(1.32, 8.36, -0.4), Vector3.new(-1.32, 8.36, -0.4)
	local WRIST_R = Vector3.new(1.66, 3.15, -1.05)
	local ELBOW_R = ik(SH_R, WRIST_R, 2.62, 2.66, Vector3.new(0.3, 0, 1))

	local POLE = Vector3.new(-2.42, 0, -1.6)
	local GRIP_Y = 4.85
	local sideDir = Vector3.new(1, 0, 0.35).Unit -- fra stangen mot kroppen
	local wrapDir = Vector3.new(-0.33, 0, 0.944) -- tangent: mot albuen
	local HAND_L = Vector3.new(POLE.X, GRIP_Y, POLE.Z) + sideDir * 0.27
	local WRIST_L = HAND_L + wrapDir * 0.48 + Vector3.new(0, 0.05, 0)
	local ELBOW_L = ik(SH_L, WRIST_L, 2.62, 2.66, Vector3.new(-0.6, -0.1, 0.8))

	------------------------------------------------------------------
	-- Bein (rigg)
	------------------------------------------------------------------
	local pelvis = bone("Waist", CFrame.new(0, 5.45, 0.25), root)
	local chest = bone("Spine", CFrame.new(0, 6.3, 0.4), pelvis)
	local headRot = CFrame.Angles(math.rad(-4), math.rad(6), math.rad(-17))
	local headBone = bone("Neck", CFrame.new(NECK_TOP) * headRot, chest)
	local headCF = headBone.CFrame * CFrame.new(0, 1.02, -0.42)
	local jawBone = bone("Jaw", headCF * CFrame.new(0, -0.32, 0.2), headBone)
	local uArmR = bone("RShoulder", CFrame.new(SH_R), chest)
	local fArmR = bone("RElbow", CFrame.new(ELBOW_R), uArmR)
	local uArmL = bone("LShoulder", CFrame.new(SH_L), chest)
	local fArmL = bone("LElbow", CFrame.new(ELBOW_L), uArmL)
	local thighL = bone("LHip", CFrame.new(HIP_L), pelvis)
	local shinL = bone("LKnee", CFrame.new(KNEE_L), thighL)
	local thighR = bone("RHip", CFrame.new(HIP_R), pelvis)
	local shinR = bone("RKnee", CFrame.new(KNEE_R), thighR)

	local bodyG = lib.new("Model", { Name = "Body" }, model)
	local headG = lib.new("Model", { Name = "Head" }, model)
	local jawG = lib.new("Model", { Name = "Jaw" }, headG)
	local poleG = lib.new("Model", { Name = "IVPole" }, model)

	------------------------------------------------------------------
	-- Ben og føtter
	------------------------------------------------------------------
	local function leg(side: number, hip: any, knee: any, ankle: any, thighB: any, shinB: any)
		use(thighB, bodyG)
		limb("Thigh", hip, knee, 0.6, 0.46, C.skin)
		ball("Knee", knee, 0.5, C.skin)
		local fwd = Vector3.new(0, 0, -1)
		use(shinB, bodyG)
		ell("Kneecap", Vector3.new(0.42, 0.48, 0.24), facing(knee + fwd * 0.22 + Vector3.new(0, 0.05, 0), fwd), C.skin)
		limb("Shin", knee, ankle, 0.42, 0.33, C.skin)
		-- leggmuskel og skinneben
		local shinDir = (ankle - knee).Unit
		ell("Calf", Vector3.new(0.46, 1.25, 0.5), lib.lookAt(knee + shinDir * 0.85 + Vector3.new(0, 0, 0.12), knee + shinDir * 0.85 + Vector3.new(0, 0, 0.12) + Vector3.new(0, 0, -1), -shinDir), C.skin)
		ball("Ankle", ankle, 0.4, C.skinDark)
		ball("AnkleBone", ankle + Vector3.new(side * 0.2, 0.02, 0), 0.18, C.skinDark)
		ball("AnkleBone", ankle + Vector3.new(-side * 0.18, -0.02, 0), 0.16, C.skinDark)

		-- fot
		local f = Vector3.new(side * 0.16, 0, -1).Unit
		local w = f:Cross(UP).Unit -- peker mot høyre side av foten
		local footC = Vector3.new(ankle.X, 0.2, ankle.Z) + f * 0.58
		ell("Foot", Vector3.new(0.6, 0.32, 1.5), lib.lookAt(footC, footC + f), C.skinDark)
		ball("Heel", Vector3.new(ankle.X, 0.22, ankle.Z) - f * 0.08, 0.44, C.skinDark)
		ell("Sole", Vector3.new(0.56, 0.06, 1.55), lib.lookAt(footC - Vector3.new(0, 0.14, 0), footC - Vector3.new(0, 0.14, 0) + f), rgb(60, 52, 44))
		-- tær: stortå innerst
		local toes = {
			{ off = -0.22, d = 0.2, len = 0.44 },
			{ off = -0.06, d = 0.15, len = 0.38 },
			{ off = 0.07, d = 0.14, len = 0.34 },
			{ off = 0.18, d = 0.13, len = 0.3 },
			{ off = 0.28, d = 0.11, len = 0.25 },
		}
		local tips = {}
		for i, t in toes do
			local o = t.off * side * -1 -- stortåa skal være på innsiden
			local base = footC + f * 0.62 + w * (o * -1) + Vector3.new(0, -0.02, 0)
			local splay = (Vector3.new(f.X, 0, f.Z) + w * (-o * 0.35)).Unit
			local mid = base + splay * (t.len * 0.55) + Vector3.new(0, -0.02, 0)
			local tip = mid + splay * (t.len * 0.45) + Vector3.new(0, -0.05, 0)
			tip = Vector3.new(tip.X, math.max(tip.Y, 0.07), tip.Z)
			seg("Toe", base, mid, t.d, C.skinDark)
			ball("ToeJ", mid, t.d * 1.05, C.skinDark)
			seg("Toe", mid, tip, t.d * 0.9, C.skinDark)
			ell("ToeNail", Vector3.new(t.d * 0.75, 0.04, t.d * 0.9), lib.lookAt(tip + Vector3.new(0, t.d * 0.4, 0), tip + Vector3.new(0, t.d * 0.4, 0) + splay), rgb(120, 98, 60))
			tips[i] = tip
		end
		return tips, f, w
	end

	local tipsL = leg(-1, HIP_L, KNEE_L, ANKLE_L, thighL, shinL)
	leg(1, HIP_R, KNEE_R, ANKLE_R, thighR, shinR)

	-- Lapp på stortåa (som i et likhus)
	use(shinL, bodyG)
	do
		local toe = tipsL[1]
		local tagPos = toe + Vector3.new(-0.42, -0.04, -0.3)
		tagPos = Vector3.new(tagPos.X, 0.035, tagPos.Z)
		seg("TagString", toe + Vector3.new(0, 0.06, 0), tagPos + Vector3.new(0.12, 0.01, 0.15), 0.025, rgb(200, 196, 186))
		blk("ToeTag", Vector3.new(0.36, 0.02, 0.56), CFrame.new(tagPos) * CFrame.Angles(0, math.rad(32), math.rad(-4)), C.tag, M.Cardboard)
		blk("ToeTagHole", Vector3.new(0.07, 0.025, 0.07), CFrame.new(tagPos) * CFrame.Angles(0, math.rad(32), 0) * CFrame.new(0, 0.002, 0.2), rgb(150, 130, 90))
		blk("ToeTagLine", Vector3.new(0.24, 0.025, 0.025), CFrame.new(tagPos) * CFrame.Angles(0, math.rad(32), 0) * CFrame.new(0, 0.003, -0.05), rgb(60, 50, 40))
		blk("ToeTagLine", Vector3.new(0.18, 0.025, 0.025), CFrame.new(tagPos) * CFrame.Angles(0, math.rad(32), 0) * CFrame.new(-0.03, 0.003, -0.14), rgb(60, 50, 40))
	end

	------------------------------------------------------------------
	-- Hofter og skjørt (kjortelen nedentil)
	------------------------------------------------------------------
	use(pelvis, bodyG)
	ell("Hips", Vector3.new(1.85, 1.15, 1.3), CFrame.new(0, 5.55, 0.28), C.skin)
	ell("Buttocks", Vector3.new(1.5, 0.9, 0.9), CFrame.new(0, 5.25, 0.62), C.skinDark)
	local hemTopY = 6.05
	for i = 0, 15 do
		local phi = math.rad(i * 22.5 + rr(-4, 4))
		if i == 8 then
			continue -- åpen bak
		end
		local ring = Vector3.new(math.sin(phi) * 1.0, hemTopY, 0.28 - math.cos(phi) * 0.82)
		local L = rr(2.2, 2.9)
		local cf = CFrame.new(ring) * CFrame.Angles(0, -phi, 0) * CFrame.Angles(math.rad(rr(5, 9)), 0, math.rad(rr(-3, 3))) * CFrame.new(0, -L / 2, 0)
		local col = (i % 3 == 0) and C.gownDark or C.gown
		blk("Skirt", Vector3.new(0.58, L, 0.06), cf, col, M.Fabric)
		-- frynsete kant
		for k = 1, rng(1, 3) do
			local tl = rr(0.25, 0.75)
			blk("Fray", Vector3.new(rr(0.05, 0.1), tl, 0.05), cf * CFrame.new(rr(-0.24, 0.24), -L / 2 - tl / 2 + 0.05, 0.01) * CFrame.Angles(0, 0, math.rad(rr(-8, 8))), col, M.Fabric)
		end
	end
	-- belte/linning
	for i = 0, 15 do
		local phi = math.rad(i * 22.5)
		local p = Vector3.new(math.sin(phi) * 0.98, hemTopY + 0.02, 0.28 - math.cos(phi) * 0.8)
		if i >= 7 and i <= 9 then
			continue
		end
		blk("Waistband", Vector3.new(0.42, 0.14, 0.09), CFrame.new(p) * CFrame.Angles(0, -phi, 0), C.gownTrim, M.Fabric)
	end
	-- flekker på skjørtet (blod som har rent nedover)
	stain("SkirtBlood", Vector3.new(0.3, 5.3, -0.62), Vector3.new(0, 0, -1), 0.55, C.bloodDry, 3, M.Fabric)
	stain("SkirtStain", Vector3.new(-0.5, 4.6, -0.55), Vector3.new(-0.4, 0, -1).Unit, 0.55, C.stain, 1, M.Fabric)

	------------------------------------------------------------------
	-- Overkropp og kjortel
	------------------------------------------------------------------
	use(chest, bodyG)
	local gWaistCF = CFrame.new(0, 6.4, 0.32)
	local gWaistS = Vector3.new(1.8, 1.6, 1.36)
	local gChestCF = CFrame.new(0, 7.55, 0.1) * CFrame.Angles(math.rad(-22), 0, 0)
	local gChestS = Vector3.new(2.2, 2.5, 1.5)
	ell("GownWaist", gWaistS, gWaistCF, C.gown, M.Fabric)
	ell("GownChest", gChestS, gChestCF, C.gown, M.Fabric)
	-- skrå, magre skuldre
	for _, sx in { -1, 1 } do
		ell("GownShoulder", Vector3.new(1.05, 0.5, 0.95), CFrame.new(sx * 0.8, 8.5, -0.34) * CFrame.Angles(math.rad(-30), 0, math.rad(-sx * 24)), C.gown, M.Fabric)
		ell("ShoulderBone", Vector3.new(0.5, 0.42, 0.6), CFrame.new(sx * 1.22, 8.42, -0.38), C.gown, M.Fabric)
	end
	-- skulderblader som stikker ut under stoffet
	for _, sx in { -1, 1 } do
		local p, n = ellPoint(gChestCF, gChestS, Vector3.new(sx * 0.5, 0.45, 1))
		ell("ShoulderBlade", Vector3.new(0.7, 0.9, 0.24), facing(p, n), C.gown, M.Fabric)
	end

	-- Åpen rygg: bar hud med ribbein og ryggvirvler
	local backPts = {}
	for i = 0, 7 do
		local t = i / 7
		local p, n = ellPoint(gChestCF, gChestS, Vector3.new(0, lerp(-0.75, 0.7, t), 1))
		table.insert(backPts, { p, n })
	end
	for i = 0, 3 do
		local t = i / 3
		local p, n = ellPoint(gWaistCF, gWaistS, Vector3.new(0, lerp(-0.6, 0.3, t), 1))
		table.insert(backPts, 1, { p, n })
	end
	for i, pn in backPts do
		local p, n = pn[1], pn[2]
		local width = 0.62 + 0.18 * math.sin(math.pi * i / #backPts)
		flat("BackSkin", p + n * 0.012, n, width, 0.5, 0.06, C.skin)
		ell("Vertebra", Vector3.new(0.16, 0.12, 0.1), facing(p + n * 0.045, n), C.face)
		if i >= 5 and i <= 10 then
			for _, sx in { -1, 1 } do
				flat("Rib", p + n * 0.035 + Vector3.new(sx * 0.2, -0.04, 0), n, 0.26, 0.055, 0.035, C.faceShade, math.rad(sx * -14))
			end
		end
		for _, sx in { -1, 1 } do
			flat("GownEdge", p + n * 0.025 + Vector3.new(sx * (width / 2 + 0.02), 0, 0), n, 0.07, 0.52, 0.05, C.gownTrim, 0, M.Fabric)
		end
		if i == 5 or i == 9 then
			-- knuter som (nesten ikke) holder kjortelen sammen
			seg("Tie", p + n * 0.06 + Vector3.new(-width / 2, 0, 0), p + n * 0.07 + Vector3.new(-0.05, 0.02, 0), 0.045, C.gownTrim, M.Fabric)
			ball("TieKnot", p + n * 0.08 + Vector3.new(-0.05, 0.02, 0), 0.1, C.gownTrim, M.Fabric)
			seg("TieEnd", p + n * 0.08 + Vector3.new(-0.05, 0.02, 0), p + n * 0.1 + Vector3.new(0.05, -0.5, 0), 0.04, C.gownTrim, M.Fabric)
			seg("TieLoose", p + n * 0.06 + Vector3.new(width / 2, 0, 0), p + n * 0.08 + Vector3.new(width / 2 + 0.05, -0.42, 0), 0.04, C.gownTrim, M.Fabric)
		end
	end

	-- V-hals med kragebein og brystben
	do
		local p, n = ellPoint(gChestCF, gChestS, Vector3.new(0, 0.62, -1))
		flat("Sternum", p, n, 0.62, 0.95, 0.05, C.skin)
		for _, sx in { -1, 1 } do
			local pts = {}
			for k = 0, 4 do
				local t = k / 4
				local cp, cn = ellPoint(gChestCF, gChestS, Vector3.new(sx * lerp(0.3, 0.02, t), lerp(0.85, 0.4, t), -1).Unit)
				table.insert(pts, cp + cn * 0.03)
			end
			curve("Collar", pts, 0.09, 0.09, C.gownTrim, M.Fabric)
		end
	end

	-- Flekker og blod på brystet
	for _, st in {
		{ Vector3.new(0.32, -0.25, -1), 0.8, C.bloodDry, 3 },
		{ Vector3.new(0.4, -0.4, -1), 0.45, C.blood, 2 },
		{ Vector3.new(-0.55, 0.05, -1), 0.5, C.stain, 1 },
		{ Vector3.new(-0.15, -0.8, -1), 0.45, C.stain, 0 },
	} do
		local p, n = ellPoint(gChestCF, gChestS, st[1].Unit)
		stain("ChestStain", p, n, st[2], st[3], st[4], M.Fabric)
	end
	-- Lomme med navnelapp
	do
		local p, n = ellPoint(gChestCF, gChestS, Vector3.new(-0.42, 0.2, -1).Unit)
		blk("Pocket", Vector3.new(0.5, 0.5, 0.04), facing(p + n * 0.01, n), C.gownDark, M.Fabric)
		blk("PocketTrim", Vector3.new(0.5, 0.07, 0.05), facing(p + n * 0.02, n) * CFrame.new(0, 0.22, 0), C.gownTrim, M.Fabric)
	end

	------------------------------------------------------------------
	-- Hals
	------------------------------------------------------------------
	local neckBase = SPINE[5]
	local neckMid = lerp(neckBase, NECK_TOP, 0.5) + Vector3.new(0, 0.12, 0.05)
	spindle("Neck", neckBase + Vector3.new(0, -0.35, 0.3), neckMid + Vector3.new(0, 0.1, -0.1), 0.72, 0.66, C.skin)
	spindle("Neck", neckMid - Vector3.new(0, 0.25, -0.2), NECK_TOP + Vector3.new(0, 0.25, -0.15), 0.56, 0.54, C.skin)
	do
		local fwd = (NECK_TOP - neckBase).Unit
		local front = fwd:Cross(Vector3.new(1, 0, 0)).Unit
		if front.Z > 0 then
			front = -front
		end
		ell("AdamsApple", Vector3.new(0.16, 0.24, 0.14), facing(neckMid + front * 0.24, front), C.skin)
	end

	------------------------------------------------------------------
	-- Armer
	------------------------------------------------------------------
	local function sleeve(sh: any, el: any)
		local d = (el - sh).Unit
		spindle("Sleeve", sh - d * 0.25, sh + d * 0.95, 0.66, 0.62, C.gown, M.Fabric)
		seg("SleeveHem", sh + d * 0.66, sh + d * 0.74, 0.62, C.gownTrim, M.Fabric)
	end

	-- Høyre arm (henger nesten ned til gulvet)
	use(uArmR, bodyG)
	sleeve(SH_R, ELBOW_R)
	limb("UpperArm", SH_R, ELBOW_R, 0.42, 0.36, C.skin)
	ball("Elbow", ELBOW_R, 0.44, C.skin)
	use(fArmR, bodyG)
	do
		local d = (WRIST_R - ELBOW_R).Unit
		ell("ElbowBone", Vector3.new(0.3, 0.38, 0.3), CFrame.new(ELBOW_R + Vector3.new(0.02, 0, 0.18)), C.skin)
		limb("Forearm", ELBOW_R, WRIST_R, 0.38, 0.29, C.skin)
		ball("Wrist", WRIST_R, 0.31, C.skin)
		flat("Bruise", ELBOW_R + d * 1.2 + Vector3.new(0.17, 0, -0.05), Vector3.new(1, 0, -0.3).Unit, 0.32, 0.4, 0.04, C.bruise)
		-- pasientarmbånd
		seg("Wristband", WRIST_R - d * 0.18, WRIST_R - d * 0.05, 0.4, C.band)
		blk("WristTag", Vector3.new(0.05, 0.24, 0.16), facing(WRIST_R - d * 0.12 + Vector3.new(0.2, 0, -0.02), Vector3.new(1, 0, 0)), C.band)
		blk("WristTagText", Vector3.new(0.02, 0.04, 0.12), facing(WRIST_R - d * 0.12 + Vector3.new(0.226, 0.04, -0.02), Vector3.new(1, 0, 0)), rgb(170, 30, 30))

		-- hånd: lokal Y mot albuen, X fremover, håndflaten mot -Z (inn mot låret)
		local yAxis = -d
		local xAxis = (Vector3.new(0, 0, -1) - yAxis * Vector3.new(0, 0, -1):Dot(yAxis)).Unit
		local handCF = CFrame.fromMatrix(WRIST_R, xAxis, yAxis)
		ell("Palm", Vector3.new(0.8, 1.05, 0.32), handCF * CFrame.new(0, -0.52, 0), C.skinDark)
		local fingers = {
			{ x = 0.25, l = { 0.6, 0.46, 0.36 }, d = 0.15 },
			{ x = 0.085, l = { 0.68, 0.5, 0.4 }, d = 0.15 },
			{ x = -0.085, l = { 0.64, 0.48, 0.38 }, d = 0.145 },
			{ x = -0.24, l = { 0.5, 0.38, 0.3 }, d = 0.13 },
		}
		for _, fg in fingers do
			local pos = (handCF * CFrame.new(fg.x, -0.98, 0.0)).Position
			ball("Knuckle", pos, fg.d * 1.2, C.skinDark)
			local ang = 0
			for si, len in fg.l do
				ang += math.rad(({ 6, 14, 22 })[si] + rr(-3, 3))
				local localDir = Vector3.new(fg.x * 0.12, -math.cos(ang), -math.sin(ang)).Unit
				local dir = handCF:VectorToWorldSpace(localDir)
				local nxt = pos + dir * len
				local dia = fg.d * (1 - (si - 1) * 0.08)
				seg("Finger", pos, nxt, dia, C.skinDark)
				ball("FingerJ", nxt, dia * 1.06, si == 3 and rgb(96, 40, 38) or C.skinDark)
				if si == 3 then
					local back = handCF:VectorToWorldSpace(Vector3.new(0, -math.sin(ang), math.cos(ang)))
					ell("Nail", Vector3.new(dia * 0.8, 0.04, 0.2), lib.lookAt(nxt - dir * 0.04 + back * dia * 0.4, nxt + dir * 0.2 + back * dia * 0.4, back), C.nail)
				end
				pos = nxt
			end
		end
		-- tommel
		local tb = (handCF * CFrame.new(0.34, -0.32, -0.06)).Position
		local t1 = tb + handCF:VectorToWorldSpace(Vector3.new(0.3, -0.75, -0.3).Unit) * 0.46
		local t2 = t1 + handCF:VectorToWorldSpace(Vector3.new(0.05, -0.8, -0.55).Unit) * 0.36
		seg("Thumb", tb, t1, 0.16, C.skinDark)
		ball("ThumbJ", t1, 0.16, C.skinDark)
		seg("Thumb", t1, t2, 0.14, rgb(110, 72, 62))
		ball("ThumbJ", t2, 0.14, rgb(110, 72, 62))
	end

	-- Venstre arm (holder dryppstativet)
	use(uArmL, bodyG)
	sleeve(SH_L, ELBOW_L)
	limb("UpperArm", SH_L, ELBOW_L, 0.42, 0.36, C.skin)
	ball("Elbow", ELBOW_L, 0.44, C.skin)
	use(fArmL, bodyG)
	do
		local d = (WRIST_L - ELBOW_L).Unit
		limb("Forearm", ELBOW_L, WRIST_L, 0.38, 0.29, C.skin)
		ball("Wrist", WRIST_L, 0.31, C.skin)
		-- sprøytestikk i albuegropen
		for k = 1, 5 do
			ball("NeedleMark", ELBOW_L + d * rr(0.15, 0.5) + Vector3.new(rr(-0.06, 0.06), rr(-0.05, 0.05), -0.19), 0.06, rgb(70, 30, 34))
		end
		flat("Bruise", ELBOW_L + d * 0.35 + Vector3.new(0, 0, -0.17), Vector3.new(0, 0, -1), 0.36, 0.3, 0.04, C.bruise)
		-- bandasje rundt underarmen
		for k = 0, 4 do
			local t = 0.35 + k * 0.1
			local p = lerp(ELBOW_L, WRIST_L, t)
			seg("ArmBandage", p - d * 0.06, p + d * 0.06, lerp(0.42, 0.36, t), C.gauze, M.Fabric)
		end
		flat("BandageBlood", lerp(ELBOW_L, WRIST_L, 0.55) + Vector3.new(0.05, 0, -0.2), Vector3.new(0.2, 0, -1).Unit, 0.2, 0.26, 0.04, C.blood)

		-- grep rundt stangen
		local pc = Vector3.new(POLE.X, GRIP_Y, POLE.Z)
		local palmCF = lib.lookAt(HAND_L, HAND_L - sideDir, UP)
		ell("Palm", Vector3.new(0.8, 0.72, 0.26), palmCF, C.skinDark)
		seg("Wrist", WRIST_L, HAND_L + wrapDir * 0.18, 0.3, C.skinDark)
		blk("IVTape", Vector3.new(0.3, 0.3, 0.03), facing(HAND_L + wrapDir * 0.12 + Vector3.new(0, 0.2, 0) + sideDir * 0.13, (sideDir + UP * 0.6).Unit), rgb(236, 236, 228), M.Fabric)
		local rf = 0.17
		local knuckleBase = HAND_L - wrapDir * 0.36
		for k, yo in { 0.24, 0.08, -0.08, -0.24 } do
			local y = GRIP_Y + yo
			local kb = Vector3.new(knuckleBase.X, y, knuckleBase.Z)
			ball("Knuckle", kb, 0.17, C.skinDark)
			local pts = { kb }
			for _, a in { -80, -150, -215, -262 } do
				local ar = math.rad(a + (k - 2) * 4)
				table.insert(pts, Vector3.new(pc.X + math.cos(ar) * rf, y, pc.Z + math.sin(ar) * rf))
			end
			local dia = k == 4 and 0.11 or 0.13
			for i = 1, #pts - 1 do
				local col = i >= #pts - 1 and rgb(110, 72, 62) or C.skinDark
				seg("Finger", pts[i], pts[i + 1], dia, col)
				ball("FingerJ", pts[i + 1], dia * 1.05, col)
			end
		end
		-- tommel over fingrene
		local tb = HAND_L + wrapDir * 0.05 + Vector3.new(0, 0.34, 0)
		local t1 = Vector3.new(pc.X, GRIP_Y + 0.4, pc.Z) + Vector3.new(0.05, 0, -0.2)
		local t2 = Vector3.new(pc.X, GRIP_Y + 0.3, pc.Z) + Vector3.new(-0.17, 0, -0.12)
		seg("Thumb", tb, t1, 0.16, C.skinDark)
		ball("ThumbJ", t1, 0.16, C.skinDark)
		seg("Thumb", t1, t2, 0.14, C.skinDark)
		ball("ThumbJ", t2, 0.14, C.skinDark)
	end

	------------------------------------------------------------------
	-- Dryppstativ med blodpose
	------------------------------------------------------------------
	use(root, poleG)
	do
		local px, pz = POLE.X, POLE.Z
		local hub = Vector3.new(px, 0.42, pz)
		seg("PoleHub", hub - Vector3.new(0, 0.12, 0), hub + Vector3.new(0, 0.12, 0), 0.3, C.metal, M.Metal)
		for k = 0, 4 do
			local a = math.rad(k * 72 + 18)
			local foot = Vector3.new(px + math.cos(a) * 1.0, 0.3, pz + math.sin(a) * 1.0)
			seg("PoleLeg", hub, foot, 0.1, C.metal, M.Metal)
			seg("Caster", foot, foot - Vector3.new(0, 0.1, 0), 0.08, rgb(60, 60, 60), M.Metal)
			attach(lib.part(cur.group, "Wheel", Vector3.new(0.09, 0.2, 0.2), CFrame.new(foot - Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, -a, 0), rgb(30, 30, 30), M.Rubber, { Shape = Enum.PartType.Cylinder }))
		end
		local top = Vector3.new(px, 9.55, pz)
		seg("Pole", hub, top, 0.14, C.metal, M.Metal)
		for _, y in { 1.6, 3.4, 6.2, 7.7 } do
			seg("Rust", Vector3.new(px, y, pz), Vector3.new(px, y + rr(0.15, 0.4), pz), 0.15, C.rust, M.CorrodedMetal)
		end
		seg("PoleClamp", Vector3.new(px, 7.0, pz), Vector3.new(px, 7.25, pz), 0.22, rgb(90, 92, 92), M.Metal)
		local barL = top + Vector3.new(-0.55, 0, 0)
		local barR = top + Vector3.new(0.6, 0, 0)
		seg("PoleBar", barL, barR, 0.08, C.metal, M.Metal)
		for _, h in { barL, barR } do
			seg("Hook", h, h + Vector3.new(0, 0.22, 0), 0.06, C.metal, M.Metal)
		end
		-- blodpose
		local bagC = Vector3.new(px + 0.6, 8.55, pz)
		seg("BagHanger", barR + Vector3.new(0, 0.05, 0), bagC + Vector3.new(0, 0.62, 0), 0.04, rgb(220, 220, 220))
		ell("Bag", Vector3.new(0.78, 1.25, 0.3), CFrame.new(bagC), C.bag, M.Glass).Transparency = 0.12
		ell("BagEdge", Vector3.new(0.84, 1.3, 0.12), CFrame.new(bagC), rgb(200, 190, 190), M.Glass).Transparency = 0.55
		blk("BagLabel", Vector3.new(0.42, 0.46, 0.02), CFrame.new(bagC + Vector3.new(0, 0.12, -0.155)), rgb(236, 236, 228))
		blk("BagLabelStripe", Vector3.new(0.42, 0.08, 0.025), CFrame.new(bagC + Vector3.new(0, 0.26, -0.16)), rgb(170, 30, 30))
		blk("BagLabelText", Vector3.new(0.3, 0.04, 0.025), CFrame.new(bagC + Vector3.new(0, 0.1, -0.16)), rgb(40, 40, 40))
		blk("BagLabelText", Vector3.new(0.22, 0.04, 0.025), CFrame.new(bagC + Vector3.new(-0.04, 0.02, -0.16)), rgb(40, 40, 40))
		local port = bagC - Vector3.new(0, 0.7, 0)
		seg("BagPort", bagC - Vector3.new(0, 0.6, 0), port, 0.1, rgb(230, 230, 225))
		local drip = port - Vector3.new(0, 0.3, 0)
		seg("DripChamber", port, drip, 0.17, rgb(210, 200, 200), M.Glass).Transparency = 0.4
		-- slangen henger i en bue ned til hånden
		local tubeEnd = HAND_L + wrapDir * 0.12 + Vector3.new(0, 0.22, 0) + sideDir * 0.16
		local pts = {}
		for i = 0, 20 do
			table.insert(pts, bezier({ drip, drip + Vector3.new(0.6, -1.4, -0.4), tubeEnd + Vector3.new(0.9, -0.8, -0.3), tubeEnd }, i / 20))
		end
		curve("Tube", pts, 0.07, 0.07, rgb(120, 22, 26))
		blk("RollerClamp", Vector3.new(0.14, 0.24, 0.12), CFrame.new(pts[6]), rgb(70, 120, 170))
	end

	------------------------------------------------------------------
	-- Hode
	------------------------------------------------------------------
	use(headBone, headG)
	local skullS = Vector3.new(1.6, 2.6, 1.92)
	local a, b, c = skullS.X / 2, skullS.Y / 2, skullS.Z / 2
	ell("Face", skullS, headCF, C.face)
	ell("Cranium", Vector3.new(1.5, 1.9, 1.7), headCF * CFrame.new(0, 0.32, 0.16), C.face)
	-- innsunkne tinninger og markert pannebein


	-- punkt på ansiktet: theta = vinkel rundt (0 = rett frem), y = høyde (lokal)
	local function facePoint(theta: number, y: number, push: number?)
		local k = math.sqrt(math.max(0.02, 1 - (y / b) ^ 2))
		local p = Vector3.new(a * k * math.sin(theta), y, -c * k * math.cos(theta))
		local n = Vector3.new(p.X / (a * a), p.Y / (b * b), p.Z / (c * c)).Unit
		p += n * (push or 0)
		return headCF:PointToWorldSpace(p), headCF:VectorToWorldSpace(n)
	end
	local headUp = headCF:VectorToWorldSpace(UP)

	local function onFace(n: string, theta: number, y: number, push: number, size: any, color: any, roll: number?, mat: any?)
		local p, nn = facePoint(theta, y, push)
		return ell(n, size, facing(p, nn, headUp) * CFrame.Angles(0, 0, roll or 0), color, mat)
	end

	-- Øyne: svarte huler med lysende knappenålspupiller
	local eyes = {
		{ theta = math.rad(-24), y = 0.16, w = 0.54, h = 0.46, px = -0.06, py = 0.05, roll = math.rad(12) },
		{ theta = math.rad(24), y = 0.24, w = 0.48, h = 0.4, px = 0.05, py = -0.02, roll = math.rad(-9) },
	}
	for _, e in eyes do
		local function mark(n: string, dy: number, w: number, h: number, thick: number, color: any, roll: number)
			local p, nn = facePoint(e.theta, e.y + dy, 0)
			flat(n, p, nn, w, h, thick, color, roll, nil, headUp)
		end
		mark("EyeRim", -0.03, e.w + 0.16, e.h + 0.16, 0.05, rgb(34, 24, 28), e.roll)
		local sp, sn = facePoint(e.theta, e.y, 0)
		flat("EyeSocket", sp, sn, e.w, e.h, 0.08, C.hollow, e.roll, M.Fabric, headUp)
		local p, n = facePoint(e.theta, e.y + e.py, 0.05)
		local right = n:Cross(headUp).Unit
		attach(lib.ellipsoid(cur.group, "Pupil", Vector3.new(0.055, 0.055, 0.02), facing(p - right * e.px, n, headUp), rgb(255, 252, 240), M.Neon))
	end
	-- Ingen nese, bare to spalter
	for _, sx in { -1, 1 } do
		onFace("NoseSlit", math.rad(sx * 4), -0.14, 0.0, Vector3.new(0.06, 0.2, 0.08), C.hollow, math.rad(sx * 16))
	end
	-- Kinnben og innsunkne kinn
	for _, sx in { -1, 1 } do
		local _ = sx
	end

	-- Gliset
	local MOUTH_MAX = math.rad(64)
	local function mouthY(u: number)
		return -0.52 + 0.3 * u * u
	end
	local function mouthH(u: number)
		return 0.17 * (1 - u * u) ^ 0.7 + 0.035
	end
	local STEPS = 24
	local stepAng = (2 * MOUTH_MAX) / STEPS
	local arcW = stepAng * a
	for i = 0, STEPS do
		local u = -1 + 2 * i / STEPS
		local th = u * MOUTH_MAX
		local y = mouthY(u)
		local h = mouthH(u)
		onFace("MouthCavity", th, y - 0.06, -0.035, Vector3.new(arcW * 2.1, h * 2 + 0.28, 0.2), C.hollow, 0, M.Fabric)
		if math.abs(u) < 0.97 then
			onFace("Gum", th, y + h + 0.02, 0.015, Vector3.new(arcW * 1.5, 0.07, 0.06), C.gum)
			onFace("Lip", th, y + h + 0.075, 0.012, Vector3.new(arcW * 1.5, 0.045, 0.05), C.lip)
		end
	end
	local TEETH = 20
	for i = 0, TEETH - 1 do
		local u = -0.9 + 1.8 * i / (TEETH - 1)
		if i ~= 4 and i ~= 14 then
			local th = u * MOUTH_MAX
			local y = mouthY(u)
			local h = mouthH(u)
			local tH = 0.14 - 0.05 * u * u
			local col = (i == 9) and rgb(96, 74, 50) or ((i % 3 == 0) and C.teethOld or C.teeth)
			onFace("ToothUpper", th, y + h - tH / 2 + 0.02, 0.03, Vector3.new(arcW * 0.8, tH, 0.07), col, math.rad(rr(-7, 7)))
		end
	end
	-- Sydde kutt fra munnvikene opp mot ørene
	for _, sx in { -1, 1 } do
		local prev = nil
		for k = 0, 6 do
			local t = k / 6
			local th = sx * (MOUTH_MAX + t * math.rad(30))
			local y = -0.22 + t * 0.24
			local p, n = facePoint(th, y, 0.012)
			if prev then
				local mid = (p + prev) / 2
				local dir = (p - prev).Unit
				attach(lib.ellipsoid(cur.group, "Cut", Vector3.new((p - prev).Magnitude + 0.04, 0.06, 0.04), CFrame.fromMatrix(mid, dir, n:Cross(dir)), C.bloodDry))
				if k % 2 == 0 then
					local across = n:Cross(dir).Unit
					blk("Stitch", Vector3.new(0.025, 0.2, 0.025), CFrame.fromMatrix(mid + n * 0.015, dir, across), rgb(14, 12, 12))
				end
			end
			prev = p
		end
		-- blod som renner fra munnviken
		local pts = {}
		for k = 0, 4 do
			local p = facePoint(sx * (MOUTH_MAX - math.rad(4 + k)), -0.24 - k * 0.16, 0.02)
			table.insert(pts, p)
		end
		curve("BloodDrip", pts, 0.05, 0.035, C.blood)
	end
	-- Arr med sting fra venstre øye ned mot kinnet
	do
		local prev = nil
		for k = 0, 5 do
			local p, n = facePoint(math.rad(-30 - k * 3), -0.1 - k * 0.12, 0.01)
			if prev then
				local mid = (p + prev) / 2
				local dir = (p - prev).Unit
				attach(lib.ellipsoid(cur.group, "Scar", Vector3.new((p - prev).Magnitude + 0.03, 0.045, 0.03), CFrame.fromMatrix(mid, dir, n:Cross(dir)), rgb(120, 70, 70)))
				blk("Stitch", Vector3.new(0.022, 0.16, 0.022), CFrame.fromMatrix(mid + n * 0.012, dir, n:Cross(dir).Unit), rgb(14, 12, 12))
			end
			prev = p
		end
	end
	-- Lave, små ører
	for _, sx in { -1, 1 } do
		local p, n = ellPoint(headCF, skullS, Vector3.new(sx, -0.12, 0.12))
		local earCF = lib.lookAt(p, p + n, headUp) * CFrame.Angles(0, 0, math.rad(sx * 12))
		ell("Ear", Vector3.new(0.26, 0.44, 0.08), earCF, C.faceShade)
		ell("EarInner", Vector3.new(0.12, 0.24, 0.04), earCF * CFrame.new(0.01, 0.02, -0.035), rgb(120, 96, 96))
	end
	-- Blodårer ved tinningene og flekkete hud
	for _, sx in { -1, 1 } do
		local pts = {}
		for k = 0, 3 do
			table.insert(pts, (facePoint(sx * math.rad(62 + k * 4), 0.55 - k * 0.18 + (k % 2) * 0.04, 0.005)))
		end
		curve("TempleVein", pts, 0.035, 0.03, C.vein)
	end

	-- Bandasje rundt pannen
	do
		local tilt = CFrame.Angles(math.rad(-10), 0, math.rad(9))
		local pts = {}
		for k = 0, 20 do
			local phi = math.rad(k * 18)
			local r = tilt:VectorToWorldSpace(Vector3.new(math.cos(phi), 0, math.sin(phi)))
			local theta = math.atan2(r.X, -r.Z)
			local p, n = facePoint(theta, 0.66 + r.Y * 0.9, 0.035)
			table.insert(pts, { p, n })
		end
		for k = 1, #pts - 1 do
			if k == 6 then
				continue -- løs ende bak
			end
			local p1, p2 = pts[k][1], pts[k + 1][1]
			local n = (pts[k][2] + pts[k + 1][2]).Unit
			local dir = (p2 - p1).Unit
			local col = (k % 4 == 0) and rgb(198, 188, 156) or C.gauze
			blk("Bandage", Vector3.new((p2 - p1).Magnitude + 0.05, 0.27, 0.05), CFrame.fromMatrix((p1 + p2) / 2, dir, n:Cross(dir) * -1), col, M.Fabric)
			if k % 2 == 0 then
				blk("BandageLayer", Vector3.new((p2 - p1).Magnitude * 0.7, 0.2, 0.04), CFrame.fromMatrix((p1 + p2) / 2 + n * 0.025, dir, n:Cross(dir) * -1) * CFrame.Angles(0, 0, math.rad(rr(-8, 8))), rgb(226, 220, 196), M.Fabric)
			end
		end
		-- blod som har trengt gjennom ved tinningen
		local bp, bn = pts[19][1], pts[19][2]
		stain("BandageBlood", bp + bn * 0.05, bn, 0.3, C.blood, 0, M.Fabric)
		-- løs ende som henger ned bak
		local tail = pts[6][1]
		local hang = { tail, tail + Vector3.new(0.05, -0.45, 0.12), tail + Vector3.new(0.12, -0.95, 0.18), tail + Vector3.new(0.08, -1.4, 0.2) }
		for k = 1, #hang - 1 do
			local dir = (hang[k + 1] - hang[k]).Unit
			blk("BandageTail", Vector3.new(0.05, (hang[k + 1] - hang[k]).Magnitude + 0.04, 0.3), CFrame.fromMatrix((hang[k] + hang[k + 1]) / 2, Vector3.new(1, 0, 0):Cross(dir).Unit:Cross(dir), dir), C.gauze, M.Fabric)
		end
	end

	-- Skallet hode med et sydd operasjonsarr over issen
	do
		local prev = nil
		for k = 0, 12 do
			local t = math.rad(15 + k * 12.5)
			local d = Vector3.new(math.cos(t) * 0.95, math.sin(t) * 1.0 + 0.2, 0.32)
			local p, n = ellPoint(headCF, skullS, d.Unit)
			if prev then
				local mid = (p + prev) / 2
				local dir = (p - prev).Unit
				attach(lib.ellipsoid(cur.group, "Incision", Vector3.new((p - prev).Magnitude + 0.05, 0.07, 0.04), CFrame.fromMatrix(mid + n * 0.01, dir, n:Cross(dir)), rgb(110, 40, 40)))
				blk("Staple", Vector3.new(0.03, 0.22, 0.03), CFrame.fromMatrix(mid + n * 0.025, dir, n:Cross(dir).Unit), rgb(150, 150, 150), M.Metal)
			end
			prev = p
		end
		for k = 1, 3 do
			local p, n = ellPoint(headCF, skullS, Vector3.new(rr(-0.6, 0.6), rr(0.7, 1), rr(0.1, 0.8)).Unit)
			flat("ScalpSpot", p + n * 0.004, n, rr(0.14, 0.24), rr(0.12, 0.2), 0.02, rgb(190, 176, 164), rr(0, 3))
		end
		-- noen få tynne hårstrå
		for k = 1, 5 do
			local p, n = ellPoint(headCF, skullS, Vector3.new(rr(-0.9, 0.9), rr(-0.1, 0.5), rr(0.4, 1)).Unit)
			local pts = { p }
			for i = 1, 4 do
				table.insert(pts, p + n * (0.06 * i) + Vector3.new(rr(-0.04, 0.04), -0.35 * i, rr(-0.04, 0.04)))
			end
			curve("Hair", pts, 0.035, 0.02, C.hair)
		end
	end

	-- Svakt lys foran ansiktet så det synes i mørket
	do
		local lp = headCF * CFrame.new(0, -0.1, -2.6)
		local holder = attach(lib.part(cur.group, "FaceLight", Vector3.new(0.2, 0.2, 0.2), lp, rgb(255, 255, 255), nil, {
			Transparency = 1,
			CastShadow = false,
		}))
		lib.new("PointLight", { Name = "FaceGlow", Range = 9, Brightness = 0.55, Color = rgb(255, 236, 205), Shadows = false }, holder)
	end

	------------------------------------------------------------------
	-- Kjeve (animeres: åpner seg og klaprer når den jakter)
	------------------------------------------------------------------
	use(jawBone, jawG)
	for i = 0, STEPS do
		local u = -1 + 2 * i / STEPS
		if math.abs(u) < 0.97 then
			local th = u * MOUTH_MAX
			local y = mouthY(u)
			local h = mouthH(u)
			onFace("GumLower", th, y - h - 0.02, 0.015, Vector3.new(arcW * 1.5, 0.07, 0.06), C.gum)
			onFace("LipLower", th, y - h - 0.075, 0.012, Vector3.new(arcW * 1.5, 0.045, 0.05), C.lip)
		end
	end
	for i = 0, TEETH - 1 do
		local u = -0.88 + 1.76 * i / (TEETH - 1)
		if i ~= 7 then
			local th = u * MOUTH_MAX
			local y = mouthY(u)
			local h = mouthH(u)
			local tH = 0.14 - 0.05 * u * u
			local col = (i % 4 == 1) and C.teethOld or C.teeth
			onFace("ToothLower", th, y - h + tH / 2 - 0.02, 0.03, Vector3.new(arcW * 0.78, tH, 0.07), col, math.rad(rr(-8, 8)))
		end
	end
	do
		local p, n = facePoint(0, -0.98, -0.08)
		ell("Chin", Vector3.new(0.8, 0.42, 0.36), facing(p - n * 0.06, n, headUp), C.face)
		flat("ChinBlood", p + n * 0.2 + headUp * 0.12, n, 0.3, 0.22, 0.04, C.blood, 0.2)
	end

	model.WorldPivotData = CFrame.new(0, 0, 0)
	model.Parent = parent
	return model
end
