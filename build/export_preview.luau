-- Eksporterer modeller til JSON slik at de kan forhåndsvises (rendres) utenfor Roblox.
-- Bruk: lune run build/export_preview.luau <scene> <utfil.json>
--   scene = "monster" | "hospital"

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local lib = require("./lib")
local buildHospital = require("./hospital")
local buildMonster = require("./monster")
local buildPatient = require("./patient")

local scene = process.args[1] or "monster"
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

local container = roblox.Instance.new("Folder")
local extra = {}
if scene == "patient" then
	local m = buildPatient(container, "Monster")
	extra.monsterPivot = cfArray(m.PrimaryPart.CFrame)
elseif scene == "monster" then
	local m = buildMonster(container, "Monster")
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
end
collect(container)

fs.writeFile(outPath, serde.encode("json", { parts = parts, lights = lights, guis = guis, extra = extra }))
print(string.format("Eksporterte %d deler, %d lys, %d SurfaceGuis til %s", #parts, #lights, #guis, outPath))
local _ = lib
