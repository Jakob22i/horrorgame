-- Eksporterer modeller til JSON slik at de kan forhåndsvises (rendres) utenfor Roblox.
-- Bruk: lune run build/export_preview.luau <scene> <utfil.json>
--   scene = "patient" | "hospital"

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local lib = require("./lib")
local buildHospital = require("./hospital")
local buildPatient = require("./patient")
local buildKey = require("./key")
local KEY_COLORS = { lib.rgb(235, 64, 58), lib.rgb(70, 140, 255), lib.rgb(70, 215, 110), lib.rgb(255, 208, 60), lib.rgb(185, 100, 255) }
-- farger en nøkkel slik serveren gjør det (Match.paintKey)
local function paintKey(key: any, i: number)
	local c = KEY_COLORS[i]
	for _, d in key:GetDescendants() do
		if d.ClassName == "Part" and (d.Name == "Bow" or d.Name == "Shaft" or d.Name == "Tooth1" or d.Name == "Tooth2") then
			d.Color = c
		elseif d.ClassName == "PointLight" then
			d.Color = c:Lerp(lib.rgb(255, 255, 255), 0.3)
		end
	end
end
local buildLobby = require("./lobby")

local scene = process.args[1] or "patient"
local outPath = process.args[2] or "preview.json"

local parts = {}
local lights = {}
local guis = {}

local function round(n: number): number
	return math.floor(n * 10000 + 0.5) / 10000
end

local function cfArray(cf: any)
	local c = { cf:GetComponents() }
	for i, v in c do
		c[i] = round(v)
	end
	return c
end

local function colorArray(c: any)
	return { round(c.R), round(c.G), round(c.B) }
end

local function udim2(u: any)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end

local function exportPart(p: any)
	local entry = {
		n = p.Name,
		s = { round(p.Size.X), round(p.Size.Y), round(p.Size.Z) },
		cf = cfArray(p.CFrame),
		c = colorArray(p.Color),
		m = p.Material.Name,
		t = round(p.Transparency),
		r = round(p.Reflectance),
		shape = p.ClassName == "WedgePart" and "Wedge" or (p.ClassName == "Part" and p.Shape.Name or "Block"),
		shadow = p.CastShadow,
	}
	-- Highlight (hvit kant) på modellen delen ligger i
	local model = p:FindFirstAncestorOfClass("Model")
	local hl = model and model:FindFirstChildOfClass("Highlight")
	if hl and hl.OutlineTransparency < 1 then
		entry.hl = colorArray(hl.OutlineColor)
	end
	local mesh = p:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		entry.mesh = mesh.MeshType.Name
		entry.ms = { mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z }
	end
	table.insert(parts, entry)
	local index = #parts - 1

	for _, child in p:GetChildren() do
		if child.ClassName == "PointLight" or child.ClassName == "SpotLight" or child.ClassName == "SurfaceLight" then
			table.insert(lights, {
				type = child.ClassName,
				part = index,
				color = colorArray(child.Color),
				range = child.Range,
				brightness = child.Brightness,
				enabled = child.Enabled,
				shadows = child.Shadows,
				face = child.ClassName ~= "PointLight" and child.Face.Name or nil,
				angle = child.ClassName ~= "PointLight" and child.Angle or nil,
			})
		elseif child.ClassName == "SurfaceGui" then
			local labels = {}
			for _, l in child:GetDescendants() do
				if l.ClassName == "Frame" then
					table.insert(labels, {
						kind = "frame",
						pos = udim2(l.Position),
						size = udim2(l.Size),
						anchor = { l.AnchorPoint.X, l.AnchorPoint.Y },
						rot = l.Rotation,
						bg = colorArray(l.BackgroundColor3),
						bt = l.BackgroundTransparency,
						z = l.ZIndex,
						round = l:FindFirstChildOfClass("UICorner") ~= nil,
					})
				elseif l.ClassName == "TextLabel" then
					table.insert(labels, {
						z = l.ZIndex,
						text = l.Text,
						pos = udim2(l.Position),
						size = udim2(l.Size),
						anchor = { l.AnchorPoint.X, l.AnchorPoint.Y },
						rot = l.Rotation,
						color = colorArray(l.TextColor3),
						tt = l.TextTransparency,
						stroke = colorArray(l.TextStrokeColor3),
						st = l.TextStrokeTransparency,
						bg = colorArray(l.BackgroundColor3),
						bt = l.BackgroundTransparency,
						font = l.FontFace.Family,
						weight = l.FontFace.Weight.Name,
						scaled = l.TextScaled,
						textSize = l.TextSize,
						xa = l.TextXAlignment.Name,
						ya = l.TextYAlignment.Name,
						rich = l.RichText,
					})
				end
			end
			table.insert(guis, {
				part = index,
				face = child.Face.Name,
				pps = child.PixelsPerStud,
				light = child.LightInfluence,
				brightness = child.Brightness,
				labels = labels,
			})
		end
	end
end

local function collect(root: any)
	for _, d in root:GetDescendants() do
		if d.ClassName == "Part" or d.ClassName == "WedgePart" or d.ClassName == "SpawnLocation" then
			exportPart(d)
		end
	end
end

-- Setter monsteret i en positur (samme formler som MonsterAnimator på klienten) og
-- flytter alle delene etter sveisene, siden Lune ikke har fysikk.
local function pose(m: any, walk: number, chase: number, ph: number, look: number, jawT: number)
	local CF = roblox.CFrame
	local function set(name: string, cf: any)
		local w = m.Joints:FindFirstChild(name)
		w.C0 = w.C0 * cf
	end
	local sinP, cosP = math.sin(ph), math.cos(ph)
	set("LHip", CF.Angles(sinP * 0.42 * walk, 0, 0))
	set("LKnee", CF.Angles(-math.max(0, cosP) * 0.75 * walk, 0, 0))
	set("RHip", CF.Angles(-sinP * 0.22 * walk, 0, math.rad(4) * walk))
	set("RKnee", CF.Angles(-math.max(0, -cosP) * 0.3 * walk, 0, 0))
	local bob = -math.abs(sinP) * 0.18 * walk - math.max(0, -sinP) * 0.12 * walk
	set("Waist", CF.new(0, bob, 0) * CF.Angles(0, sinP * 0.05 * walk, math.sin(ph + 0.6) * 0.06 * walk))
	set("Spine", CF.Angles(-0.14 * chase, 0, math.sin(ph) * 0.03 * walk))
	set("RShoulder", CF.Angles(-sinP * 0.28 * walk + 0.75 * chase, 0, math.rad(-4) * chase))
	set("RElbow", CF.Angles(0.12 + 0.35 * chase + math.max(0, sinP) * 0.15 * walk, 0, 0))
	set("Neck", CF.Angles(0, look, 0) * CF.Angles(0.15, -0.2, 0.35))
	set("Jaw", CF.Angles(-(0.2 + 0.14 * jawT) * chase - 0.05, 0, 0))
	-- løs sveisene fra Root og utover
	local byPart0 = {}
	for _, d in m:GetDescendants() do
		if d.ClassName == "Weld" then
			byPart0[d.Part0] = byPart0[d.Part0] or {}
			table.insert(byPart0[d.Part0], d)
		end
	end
	local queue = { m.Root }
	while #queue > 0 do
		local p0 = table.remove(queue, 1)
		for _, w in byPart0[p0] or {} do
			w.Part1.CFrame = p0.CFrame * w.C0 * w.C1:Inverse()
			table.insert(queue, w.Part1)
		end
	end
end

local container = roblox.Instance.new("Folder")
local extra = {}
if scene == "patient" or scene == "patient-chase" then
	local m = buildPatient(container, "Monster")
	if scene == "patient-chase" then
		pose(m, 1, 1, math.pi * 0.45, -0.3, 1)
	end
	extra.monsterPivot = cfArray(m.PrimaryPart.CFrame)
elseif scene == "hospital" then
	buildHospital(container)
	-- åpne noen av fargelåsene på nødutgangen (som Match:_updateExitVisuals), f.eks. "1,3"
	local exit = container:FindFirstChild("ExitDoor", true)
	local opened = string.split(process.args[4] or "", ",")
	if exit and #opened >= 5 then
		local counter = exit:FindFirstChild("Counter", true)
		if counter then
			counter.Text = "5/5"
			counter.TextColor3 = lib.rgb(40, 230, 90)
		end
	end
	for _, n in opened do
		local i = tonumber(n)
		if i and exit then
			local lamp = exit:FindFirstChild("Lock" .. i)
			if lamp then
				lamp.Color = KEY_COLORS[i]
				lamp.Material = roblox.Enum.Material.Neon
			end
			local pad = exit:FindFirstChild("Padlock" .. i, true)
			if pad then
				for _, d in pad:GetDescendants() do
					if d.Name == "Body" then
						d.Material = roblox.Enum.Material.Neon
						d:FindFirstChildOfClass("PointLight").Enabled = true
					elseif d.Name == "Shackle" then
						d.CFrame = d.CFrame + roblox.Vector3.new(0, 0.45, 0)
					end
				end
			end
		end
	end
	local m = buildPatient(container, "Monster")
	-- plassering: "x,z,yawGrader"
	local px, pz, yaw = 0, 0, 0
	if process.args[3] then
		local parts3 = string.split(process.args[3], ",")
		px, pz, yaw = tonumber(parts3[1]) or 0, tonumber(parts3[2]) or 0, tonumber(parts3[3]) or 0
	end
	local T = roblox.CFrame.new(px, 0, pz) * roblox.CFrame.Angles(0, math.rad(yaw), 0)
	for _, d in m:GetDescendants() do
		if d.ClassName == "Part" then
			d.CFrame = T * d.CFrame
		end
	end
	extra.monsterPivot = cfArray(m.PrimaryPart.CFrame)
elseif scene == "blood" then
	-- utstilling av blodet: pytter, slepespor og fotspor på gulvet, sprut og håndavtrykk på veggen
	local Blood = require("./blood")
	local rng = lib.rng(31)
	local V3, CF = roblox.Vector3, roblox.CFrame
	lib.part(container, "Floor", V3.new(80, 1, 30), CF.new(0, -0.5, 0), lib.rgb(140, 146, 136), roblox.Enum.Material.CeramicTiles)
	lib.part(container, "Wall", V3.new(80, 14, 1), CF.new(0, 7, -10.5), lib.rgb(186, 174, 132), roblox.Enum.Material.Plaster)
	lib.part(container, "WallLow", V3.new(80, 4, 1.1), CF.new(0, 2, -10.5), lib.rgb(84, 110, 96), roblox.Enum.Material.Plaster)
	local function fc(x: number, z: number, yaw: number, w: number, h: number)
		return Blood.canvas(container, "Blood", CF.new(x, 0.03, z) * CF.Angles(0, -yaw, 0), w, h, "Top", 32)
	end
	fc(-30, 0, 0.3, 7, 7):pool(0, 0, 1.5, Blood.FRESH, rng)
	fc(-18, 0, 1.0, 6, 6):pool(0, 0, 1.2, Blood.DRIED, rng)
	local drag = fc(-3, 0, 0.2, 9.6, 3)
	drag:pool(-3.5, 0, 1, Blood.FRESH, rng, { drops = 7 })
	drag:drag(-2.9, 0, 6, 1.2, Blood.FRESH, rng)
	local steps = fc(14, 0, -0.15, 10.2, 2.6)
	steps:pool(-4.2, 0, 0.7, Blood.FRESH, rng, { drops = 6 })
	steps:footprints(-3.1, 0, 9, Blood.FRESH, rng)
	local function wc(x: number, y: number, w: number, h: number)
		local pos = V3.new(x, y, -9.965)
		return Blood.canvas(container, "Wall", lib.lookAt(pos, pos + V3.new(0, 0, 1)), w, h, "Front", 40)
	end
	wc(-24, 4.2, 7, 6.5):spray(-0.5, 0, 0.25, 3, Blood.FRESH, rng)
	local hands = wc(-8, 5, 5, 5)
	hands:hand(-1, 0.5, math.rad(12), 1.4, Blood.FRESH, rng)
	hands:hand(0.9, -0.6, math.rad(-18), 0, Blood.FRESH, rng)
	hands:drip(-0.2, 1.4, 1.6, 0.08, Blood.FRESH)
	hands:drip(1.4, 0.3, 0.9, 0.06, Blood.FRESH)
elseif scene == "keyset" then
	-- alle fem nøklene på et langbord (som et produktbilde)
	local V3, CF = roblox.Vector3, roblox.CFrame
	local rgb = lib.rgb
	lib.part(container, "Floor", V3.new(40, 1, 30), CF.new(0, -0.5, 0), rgb(140, 146, 136), roblox.Enum.Material.CeramicTiles)
	lib.part(container, "Wall", V3.new(40, 14, 1), CF.new(0, 7, -6.5), rgb(186, 174, 132), roblox.Enum.Material.Plaster)
	lib.part(container, "WallLow", V3.new(40, 4, 1.1), CF.new(0, 2, -6.5), rgb(84, 110, 96), roblox.Enum.Material.CeramicTiles)
	lib.part(container, "Table", V3.new(14, 0.3, 3.4), CF.new(0, 3.05, 0), rgb(92, 70, 52), roblox.Enum.Material.Wood)
	for _, lx in { -6.6, 6.6 } do
		for _, lz in { -1.5, 1.5 } do
			lib.part(container, "Leg", V3.new(0.3, 2.9, 0.3), CF.new(lx, 1.45, lz), rgb(60, 46, 34), roblox.Enum.Material.Wood)
		end
	end
	for i = 1, 5 do
		local key = buildKey(container)
		paintKey(key, i)
		local T = CF.new((i - 3) * 2.4, 3.3, 0.2) * CF.Angles(0, math.rad(-10 + (i % 2) * 20), 0)
		for _, d in key:GetDescendants() do
			if d.ClassName == "Part" then
				d.CFrame = T * d.CFrame
			end
		end
	end
elseif scene == "keyroom" then
	-- en nøkkel som ligger på et skap i et mørkt pasientrom (lampene der er av)
	buildHospital(container)
	local map = container:FindFirstChild("HospitalTemplate") or container
	local spot
	for _, m in map:FindFirstChild("KeySpots", true):GetChildren() do
		if m:GetAttribute("Room") == (process.args[3] or "R101") then
			spot = m
		end
	end
	local base = spot.CFrame.Position
	local key = buildKey(container)
	paintKey(key, tonumber(process.args[4]) or 1)
	local T = spot.CFrame
	for _, d in key:GetDescendants() do
		if d.ClassName == "Part" then
			d.CFrame = T * d.CFrame
		end
	end
	for _, lamp in map:FindFirstChild("Lamps", true):GetChildren() do
		local panel = lamp:FindFirstChild("Panel")
		if panel and (panel.CFrame.Position - base).Magnitude < 26 then
			panel.Material = roblox.Enum.Material.SmoothPlastic
			panel.Color = lib.rgb(60, 64, 62)
			panel:FindFirstChildOfClass("PointLight").Enabled = false
		end
	end
	extra.key = { base.X, base.Y, base.Z }
elseif scene == "thumb" then
	-- Thumbnails: monsteret i en positur, enten fritt (x,z,yaw) eller foran et skap (closet=N)
	-- Bruk: lune run build/export_preview.luau thumb out.json <positur> <x,z,yaw | closet=N> [med-kart 0/1]
	local CF = roblox.CFrame
	local V3 = roblox.Vector3
	local preset = process.args[3] or "stare"
	local where = process.args[4] or "0,0,0"
	local withMap = process.args[5] ~= "0"
	local map
	if withMap then
		buildHospital(container)
		map = container:FindFirstChild("HospitalTemplate")
	end
	local m = buildPatient(container, "Monster")
	local poses = {
		stare = { Neck = CF.Angles(0.1, 0, 0.45), Jaw = CF.Angles(-0.3, 0, 0), RShoulder = CF.Angles(0.15, 0, 0), RElbow = CF.Angles(0.2, 0, 0) },
		lean = {
			Spine = CF.Angles(-1.05, 0, 0.1),
			Neck = CF.Angles(0.9, 0, 0.5),
			Jaw = CF.Angles(-0.4, 0, 0),
			RShoulder = CF.Angles(1.5, 0, 0.15),
			RElbow = CF.Angles(0.5, 0, 0),
			LShoulder = CF.Angles(0.7, 0, -0.1),
		},
		peek = {
			Spine = CF.Angles(-1.45, 0, 0.1),
			Neck = CF.Angles(1.6, 0.12, 0.42),
			LHip = CF.Angles(0.25, 0, 0),
			RHip = CF.Angles(0.25, 0, 0),
			LKnee = CF.Angles(-0.5, 0, 0),
			RKnee = CF.Angles(-0.5, 0, 0),
			Jaw = CF.Angles(-0.45, 0, 0),
			RShoulder = CF.Angles(1.0, 0, 0.35),
			RElbow = CF.Angles(1.1, 0, 0),
			LShoulder = CF.Angles(0.9, 0, -0.3),
			LElbow = CF.Angles(1.0, 0, 0),
		},
		reach = {
			Spine = CF.Angles(-0.2, 0, 0),
			Neck = CF.Angles(0.2, 0.15, 0.35),
			Jaw = CF.Angles(-0.42, 0, 0),
			RShoulder = CF.Angles(1.25, 0, -0.08),
			RElbow = CF.Angles(0.3, 0, 0),
			LShoulder = CF.Angles(0.35, 0, 0),
			LHip = CF.Angles(0.35, 0, 0),
			LKnee = CF.Angles(-0.5, 0, 0),
			RHip = CF.Angles(-0.2, 0, 0.07),
		},
		wave = { Neck = CF.Angles(0.12, 0, 0.55), RShoulder = CF.Angles(1.2, 0, 0.6), RElbow = CF.Angles(1.0, 0, 0), Jaw = CF.Angles(-0.15, 0, 0) },
	}
	for name, cf in poses[preset] or {} do
		local w = m.Joints:FindFirstChild(name)
		if w then
			w.C0 = w.C0 * cf
		end
	end
	-- plassering
	local rootCF
	if string.sub(where, 1, 7) == "closet=" then
		local index = tonumber(string.sub(where, 8)) or 1
		local closet = map.Closets:GetChildren()[index]
		local hide = closet:FindFirstChild("HidePoint").CFrame
		local outp = closet:FindFirstChild("OutPoint").CFrame
		local toward = (hide.Position - outp.Position)
		local flat = V3.new(toward.X, 0, toward.Z).Unit
		local base = V3.new(outp.Position.X, 1, outp.Position.Z) + flat * (tonumber(process.args[6]) or 0.6)
		rootCF = lib.lookAt(base, base + flat)
		extra.hide = { hide.Position.X, hide.Position.Y, hide.Position.Z }
		extra.flat = { flat.X, flat.Y, flat.Z }
	else
		local a = string.split(where, ",")
		rootCF = CF.new(tonumber(a[1]) or 0, 1, tonumber(a[2]) or 0) * CF.Angles(0, math.rad(tonumber(a[3]) or 0), 0)
	end
	local T = rootCF * m.Root.CFrame:Inverse()
	m.Root.CFrame = rootCF
	-- løs sveisene fra Root og utover
	local byPart0 = {}
	for _, d in m:GetDescendants() do
		if d.ClassName == "Weld" then
			byPart0[d.Part0] = byPart0[d.Part0] or {}
			table.insert(byPart0[d.Part0], d)
		end
	end
	local queue = { m.Root }
	while #queue > 0 do
		local p0 = table.remove(queue, 1)
		for _, w in byPart0[p0] or {} do
			w.Part1.CFrame = p0.CFrame * w.C0 * w.C1:Inverse()
			table.insert(queue, w.Part1)
		end
	end
	local _ = T
	local face = m:FindFirstChild("Face", true)
	extra.face = { face.CFrame.Position.X, face.CFrame.Position.Y, face.CFrame.Position.Z }
	local lv = face.CFrame.LookVector
	extra.faceLook = { lv.X, lv.Y, lv.Z }
	extra.monsterPivot = cfArray(m.Root.CFrame)
elseif scene == "lobby" then
	buildLobby(container, nil)
elseif scene == "monsterpose" then
	-- bare monsteret, i en positur (til traileren): "walk,<fase>,<jakt>,<kjeve>" eller en ferdig positur
	local m = buildPatient(container, "Monster")
	local arg = process.args[3] or "walk,0,1,0"
	local a = string.split(arg, ",")
	if a[1] == "walk" then
		pose(m, 1, tonumber(a[3]) or 1, tonumber(a[2]) or 0, tonumber(a[5]) or 0, tonumber(a[4]) or 0)
	else
		local CF = roblox.CFrame
		local presets = {
			stare = { Neck = CF.Angles(0.1, 0, 0.45), Jaw = CF.Angles(-0.3, 0, 0), RShoulder = CF.Angles(0.15, 0, 0), RElbow = CF.Angles(0.2, 0, 0) },
			scream = { Neck = CF.Angles(-0.15, 0, 0.2), Jaw = CF.Angles(-0.62, 0, 0), RShoulder = CF.Angles(1.3, 0, 0.1), RElbow = CF.Angles(0.2, 0, 0), Spine = CF.Angles(-0.25, 0, 0) },
			peek = {
				Spine = CF.Angles(-1.45, 0, 0.1),
				Neck = CF.Angles(1.6, 0.12, 0.42),
				LHip = CF.Angles(0.25, 0, 0),
				RHip = CF.Angles(0.25, 0, 0),
				LKnee = CF.Angles(-0.5, 0, 0),
				RKnee = CF.Angles(-0.5, 0, 0),
				Jaw = CF.Angles(-0.45, 0, 0),
				RShoulder = CF.Angles(1.0, 0, 0.35),
				RElbow = CF.Angles(1.1, 0, 0),
				LShoulder = CF.Angles(0.9, 0, -0.3),
				LElbow = CF.Angles(1.0, 0, 0),
			},
			wave = { Neck = CF.Angles(0.12, 0, 0.55), RShoulder = CF.Angles(1.2, 0, 0.6), RElbow = CF.Angles(1.0, 0, 0), Jaw = CF.Angles(-0.15, 0, 0) },
		}
		for name, cf in presets[a[1]] or {} do
			local w = m.Joints:FindFirstChild(name)
			if w then
				w.C0 = w.C0 * cf
			end
		end
		pose(m, 0, 0, 0, 0, 0)
	end
	extra.monsterPivot = cfArray(m.Root.CFrame)
	local face = m:FindFirstChild("Face", true)
	extra.face = { face.CFrame.Position.X, face.CFrame.Position.Y, face.CFrame.Position.Z }
elseif scene == "ending" then
	-- sluttscenen: monsteret står i nødutgangen og vinker (samme formler som Ending.luau)
	buildHospital(container)
	local m = buildPatient(container, "Monster")
	local a = string.split(process.args[3] or "", ",")
	local function arg(i: number, default: number): number
		return tonumber(a[i]) or default
	end
	local CF = roblox.CFrame
	local Vector3 = roblox.Vector3
	local function set(name: string, cf: any)
		local w = m.Joints:FindFirstChild(name)
		w.C0 = w.C0 * cf
	end
	set("Neck", CF.Angles(0.12, 0, arg(4, 0.55)))
	set("RShoulder", CF.Angles(arg(1, 1.2), 0, arg(2, 0.5)))
	set("RElbow", CF.Angles(arg(3, 1.0), 0, 0))
	set("Jaw", CF.Angles(-0.12, 0, 0))
	local byPart0 = {}
	for _, d in m:GetDescendants() do
		if d.ClassName == "Weld" then
			byPart0[d.Part0] = byPart0[d.Part0] or {}
			table.insert(byPart0[d.Part0], d)
		end
	end
	local map = container:FindFirstChild("HospitalTemplate") or container
	local exit = map:FindFirstChild("ExitDoor", true)
	local header = exit:FindFirstChild("Header")
	local outside = exit:FindFirstChild("OutsideFloor")
	for _, name in { "DoorL", "DoorR", "Chain" } do
		local door = exit:FindFirstChild(name)
		if door then
			door.Parent = nil
		end
	end
	local floorY = outside.CFrame.Position.Y + outside.Size.Y / 2
	local hp = header.CFrame.Position
	local door = Vector3.new(hp.X, floorY, hp.Z)
	local d = outside.CFrame.Position - hp
	local dir = Vector3.new(d.X, 0, d.Z).Unit
	local rootPos = door - dir * 1.2 + Vector3.new(0, 1, 0)
	m.Root.CFrame = lib.lookAt(rootPos, rootPos + dir)
	local queue = { m.Root }
	while #queue > 0 do
		local p0 = table.remove(queue, 1)
		for _, w in byPart0[p0] or {} do
			w.Part1.CFrame = p0.CFrame * w.C0 * w.C1:Inverse()
			table.insert(queue, w.Part1)
		end
	end
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local camPos = door + dir * 14 + side * 3 + Vector3.new(0, 5.2, 0)
	extra.camera = { camPos.X, camPos.Y, camPos.Z }
	extra.target = { door.X, door.Y + 6.5, door.Z }
	extra.monsterPivot = cfArray(m.Root.CFrame)
end
collect(container)

fs.writeFile(outPath, serde.encode("json", { parts = parts, lights = lights, guis = guis, extra = extra }))
print(string.format("Eksporterte %d deler, %d lys, %d SurfaceGuis til %s", #parts, #lights, #guis, outPath))
local _ = lib
