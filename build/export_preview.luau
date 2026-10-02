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
