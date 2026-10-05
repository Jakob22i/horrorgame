-- Bygger lobbyen: sykehusets venterom slik det var før alt gikk galt. Rene fliser, varmt lys,
-- stolrader, resepsjon med "NOW SERVING"-skjerm, gavebutikk, toppliste og fire gamle
-- sykehusheiser med messingrammer og viserur over døra. Litt for rolig.
-- Hver heis tar maks 4 spillere og starter sitt eget skrekkspill.

local lib = require("./lib")
local Vector3, CFrame, Enum, UDim2 = lib.Vector3, lib.CFrame, lib.Enum, lib.UDim2
local rgb = lib.rgb

local CENTER_Z = -200
local HALF_X, HALF_Z = 48, 32
local HEIGHT = 20
local ELEVATOR_X = { -33, -11, 11, 33 }

-- Fargepalett
local FLOOR_A = rgb(226, 219, 199) -- krem
local FLOOR_B = rgb(184, 196, 178) -- blek salvie
local TEAL = rgb(58, 104, 98)
local TEAL_DARK = rgb(36, 70, 66)
local WAINSCOT = rgb(118, 160, 146)
local TRIM = rgb(238, 232, 214)
local WALL = rgb(232, 224, 203)
local CEIL = rgb(238, 236, 228)
local GRID = rgb(204, 202, 194)
local BRASS = rgb(214, 172, 90)
local BRASS_DARK = rgb(160, 120, 58)
local WALNUT = rgb(104, 70, 46)
local WALNUT_LIGHT = rgb(150, 106, 68)
local SEAT = rgb(196, 110, 58)
local CHROME = rgb(196, 200, 204)
local STEEL = rgb(170, 172, 174)
local GLASS_BLACK = rgb(16, 16, 18)
local LED_RED = rgb(255, 64, 44)
local CREAM_PAPER = rgb(240, 234, 216)
local INK = rgb(40, 36, 32)
local LEAF = rgb(64, 116, 60)
local LEAF_LIGHT = rgb(98, 150, 78)
local POT_WHITE = rgb(232, 228, 216)

local FLASHLIGHTS = {
	{ name = "WARM", color = rgb(255, 244, 220), price = 0 },
	{ name = "COLD WHITE", color = rgb(215, 232, 255), price = 100 },
	{ name = "NIGHT VISION", color = rgb(130, 255, 140), price = 250 },
	{ name = "BLOOD RED", color = rgb(255, 80, 66), price = 300 },
	{ name = "DEEP BLUE", color = rgb(110, 160, 255), price = 300 },
	{ name = "ULTRAVIOLET", color = rgb(190, 110, 255), price = 450 },
	{ name = "GOLDEN", color = rgb(255, 205, 90), price = 700 },
}
local TITLES = {
	{ text = "SURVIVOR", color = rgb(70, 150, 84) },
	{ text = "NIGHT SHIFT", color = rgb(70, 110, 190) },
	{ text = "PATIENT", color = rgb(90, 86, 76) },
	{ text = "GHOST", color = rgb(120, 120, 160) },
	{ text = "LATE VISITOR", color = rgb(200, 130, 40) },
	{ text = "#0413", color = rgb(200, 30, 30) },
}

-- Vinkler på viseren over heisdørene (grader, positivt = mot høyre sett fra rommet)
local DIAL = { L = -64, B1 = -22, B2 = 22, B3 = 64 }

return function(parent: any, spawnLocation: any)
	local rng = lib.rng(777)
	local lobby = lib.new("Model", { Name = "Lobby" }, parent)
	local walls = lib.new("Folder", { Name = "Walls" }, lobby)
	local lamps = lib.new("Folder", { Name = "Lamps" }, lobby)
	local props = lib.new("Folder", { Name = "Props" }, lobby)
	local elevators = lib.new("Folder", { Name = "Elevators" }, lobby)

	local z0, z1 = CENTER_Z - HALF_Z, CENTER_Z + HALF_Z -- -232, -168
	local x0, x1 = -HALF_X, HALF_X

	local NO_HIT = { CanQuery = false, CanTouch = false }
	local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

	local function box(parentObj: any, name: string, xa: number, ya: number, za: number, xb: number, yb: number, zb: number, color: any, material: any?, extra: any?)
		local size = Vector3.new(math.abs(xb - xa), math.abs(yb - ya), math.abs(zb - za))
		local c = Vector3.new((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2)
		return lib.part(parentObj, name, size, CFrame.new(c), color, material, extra)
	end

	-- Del som vender mot `dir` (fremsiden, der SurfaceGui havner)
	local function facing(parentObj: any, name: string, size: any, pos: any, dir: any, color: any, material: any?, extra: any?)
		return lib.part(parentObj, name, size, lib.lookAt(pos, pos + dir), color, material, extra)
	end

	-- Rund skive (sylinder) med flaten mot `normal`
	local function disc(parentObj: any, name: string, d: number, thick: number, pos: any, normal: any, color: any, material: any?, extra: any?)
		local cf = lib.lookAt(pos, pos + normal) * CFrame.Angles(0, math.pi / 2, 0)
		local e = { Shape = Enum.PartType.Cylinder }
		if extra then
			for k, v in extra do
				e[k] = v
			end
		end
		return lib.part(parentObj, name, Vector3.new(thick, d, d), cf, color, material, e)
	end

	local function ball(parentObj: any, name: string, d: number, pos: any, color: any, material: any?, extra: any?)
		local e = { Shape = Enum.PartType.Ball }
		if extra then
			for k, v in extra do
				e[k] = v
			end
		end
		return lib.part(parentObj, name, Vector3.new(d, d, d), CFrame.new(pos), color, material, e)
	end

	local function gui(part: any, face: any?, light: number?, brightness: number?)
		return lib.new("SurfaceGui", {
			Name = "SignGui",
			Face = face or Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = light or 0,
			Brightness = brightness or 1,
		}, part)
	end

	local function label(g: any, name: string, x: number, y: number, w: number, h: number, text: string, color: any, font: any, align: any?)
		return lib.new("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Text = text,
			TextScaled = true,
			TextColor3 = color,
			TextXAlignment = align or Enum.TextXAlignment.Center,
			FontFace = lib.Font.fromEnum(font),
		}, g)
	end

	local function frame(g: any, x: number, y: number, w: number, h: number, color: any, rot: number?)
		return lib.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			AnchorPoint = lib.Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rot or 0,
		}, g)
	end

	------------------------------------------------------------------
	-- Gulv: rutete fliser med en mørk kant langs veggene
	------------------------------------------------------------------
	box(walls, "Floor", x0 - 2, -1, z0 - 2, x1 + 2, 0, z1 + 2, FLOOR_A, Enum.Material.SmoothPlastic, { Reflectance = 0.03 })
	local tiles = lib.new("Model", { Name = "FloorTiles" }, walls)
	local TILE = 4
	for i = 0, (x1 - x0) / TILE - 1 do
		for j = 0, (z1 - z0) / TILE - 1 do
			if (i + j) % 2 == 1 then
				local tx, tz = x0 + i * TILE, z0 + j * TILE
				box(tiles, "Tile", tx, 0, tz, tx + TILE, 0.03, tz + TILE, FLOOR_B, Enum.Material.SmoothPlastic, { Reflectance = 0.03, CastShadow = false })
			end
		end
	end
	local B = 1.2
	box(tiles, "Border", x0, 0, z0, x1, 0.04, z0 + B, TEAL, Enum.Material.SmoothPlastic, { CastShadow = false })
	box(tiles, "Border", x0, 0, z1 - B, x1, 0.04, z1, TEAL, Enum.Material.SmoothPlastic, { CastShadow = false })
	box(tiles, "Border", x0, 0, z0, x0 + B, 0.04, z1, TEAL, Enum.Material.SmoothPlastic, { CastShadow = false })
	box(tiles, "Border", x1 - B, 0, z0, x1, 0.04, z1, TEAL, Enum.Material.SmoothPlastic, { CastShadow = false })

	------------------------------------------------------------------
	-- Tak: himling med rutenett
	------------------------------------------------------------------
	box(walls, "Ceiling", x0 - 2, HEIGHT, z0 - 2, x1 + 2, HEIGHT + 1, z1 + 2, CEIL, Enum.Material.SmoothPlastic)
	for x = x0 + 4, x1 - 4, 4 do
		box(walls, "CeilingGrid", x - 0.08, HEIGHT - 0.06, z0, x + 0.08, HEIGHT, z1, GRID, Enum.Material.SmoothPlastic, DECOR)
	end
	for z = z0 + 4, z1 - 4, 4 do
		box(walls, "CeilingGrid", x0, HEIGHT - 0.06, z - 0.08, x1, HEIGHT, z + 0.08, GRID, Enum.Material.SmoothPlastic, DECOR)
	end

	------------------------------------------------------------------
	-- Vegger: grønne fliser nederst, kremfarget over, lister
	------------------------------------------------------------------
	-- alongX: veggen går langs X (nord/sør). face = innsiden, dir = retning inn i rommet.
	local function slab(name: string, alongX: boolean, a: number, b: number, f1: number, f2: number, y1: number, y2: number, color: any, mat: any, extra: any?)
		if alongX then
			return box(walls, name, a, y1, f1, b, y2, f2, color, mat, extra)
		end
		return box(walls, name, f1, y1, a, f2, y2, b, color, mat, extra)
	end
	local function wallRun(alongX: boolean, a: number, b: number, face: number, dir: number, yBottom: number?)
		local bottom = yBottom or 0
		slab("Wall", alongX, a, b, face, face - 2 * dir, bottom, HEIGHT, WALL, Enum.Material.Plaster)
		if bottom < 4.5 then
			slab("Wainscot", alongX, a, b, face, face + 0.12 * dir, bottom, 4.5, WAINSCOT, Enum.Material.CeramicTiles, { CastShadow = false })
			slab("ChairRail", alongX, a, b, face, face + 0.26 * dir, 4.5, 4.9, TRIM, Enum.Material.Wood, { CastShadow = false })
		end
		if bottom < 0.7 then
			slab("Baseboard", alongX, a, b, face, face + 0.2 * dir, 0, 0.7, TEAL_DARK, Enum.Material.SmoothPlastic, { CastShadow = false })
		end
		slab("Crown", alongX, a, b, face, face + 0.22 * dir, HEIGHT - 0.5, HEIGHT, TRIM, Enum.Material.SmoothPlastic, { CastShadow = false })
	end

	-- sør (med åpning til inngangsdørene), vest, øst
	wallRun(true, x0 - 2, -6.6, z1, -1)
	wallRun(true, 6.6, x1 + 2, z1, -1)
	wallRun(true, -6.6, 6.6, z1, -1, 11)
	wallRun(false, z0 - 2, z1 + 2, x0, 1)
	wallRun(false, z0 - 2, z1 + 2, x1, -1)
	-- nord: åpninger til heisene (10 brede, 12 høye)
	local edges = { x0 - 2 }
	for _, cx in ELEVATOR_X do
		table.insert(edges, cx - 5)
		table.insert(edges, cx + 5)
	end
	table.insert(edges, x1 + 2)
	for i = 1, #edges, 2 do
		wallRun(true, edges[i], edges[i + 1], z0, 1)
	end
	for _, cx in ELEVATOR_X do
		wallRun(true, cx - 5, cx + 5, z0, 1, 12)
	end

	------------------------------------------------------------------
	-- Lysrør i himlingen (varme)
	------------------------------------------------------------------
	for _, z in { -222, -204, -186, -174 } do
		for _, x in { -36, -12, 12, 36 } do
			if z == -174 and math.abs(x) < 20 then
				continue -- over inngangen holder det med de andre
			end
			local m = lib.new("Model", { Name = "Lamp", Tags = { "Lamp" }, Attributes = { Mode = "on" } }, lamps)
			box(m, "Housing", x - 2.2, HEIGHT - 0.12, z - 1.1, x + 2.2, HEIGHT, z + 1.1, TRIM, Enum.Material.Metal, DECOR)
			local panel = box(m, "Panel", x - 2, HEIGHT - 0.2, z - 0.9, x + 2, HEIGHT - 0.1, z + 0.9, rgb(255, 242, 214), Enum.Material.Neon, DECOR)
			lib.new("PointLight", { Name = "Light", Range = 30, Brightness = 0.85, Color = rgb(255, 228, 186), Shadows = true }, panel)
		end
	end

	------------------------------------------------------------------
	-- Planter (friske, nesten for friske)
	------------------------------------------------------------------
	local function snakePlant(pos: any, scale: number?)
		local s = scale or 1
		local m = lib.new("Model", { Name = "Plant" }, props)
		lib.cylinderY(m, "Pot", 2.2 * s, 2.4 * s, CFrame.new(pos + Vector3.new(0, 1.2 * s, 0)), POT_WHITE, Enum.Material.SmoothPlastic)
		lib.cylinderY(m, "PotRim", 2.4 * s, 0.25 * s, CFrame.new(pos + Vector3.new(0, 2.3 * s, 0)), POT_WHITE, Enum.Material.SmoothPlastic)
		lib.cylinderY(m, "Soil", 2 * s, 0.1, CFrame.new(pos + Vector3.new(0, 2.38 * s, 0)), rgb(60, 44, 32), Enum.Material.Sand, DECOR)
		for i = 1, 9 do
			local a = (i / 9) * math.pi * 2 + rng() * 0.5
			local r = 0.35 * s + rng() * 0.3 * s
			local h = (3 + rng() * 2.2) * s
			local base = pos + Vector3.new(math.cos(a) * r, 2.4 * s, math.sin(a) * r)
			local cf = CFrame.new(base) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, (rng() - 0.5) * 0.25) * CFrame.Angles((rng() - 0.3) * 0.3, 0, 0)
			lib.part(m, "Leaf", Vector3.new(0.12, h, 0.55 * s), cf * CFrame.new(0, h / 2, 0), i % 2 == 0 and LEAF or LEAF_LIGHT, Enum.Material.SmoothPlastic, DECOR)
		end
		return m
	end
	local function ficus(pos: any)
		local m = lib.new("Model", { Name = "Ficus" }, props)
		lib.cylinderY(m, "Pot", 3, 2.6, CFrame.new(pos + Vector3.new(0, 1.3, 0)), rgb(176, 98, 64), Enum.Material.Concrete)
		lib.cylinderY(m, "Soil", 2.7, 0.1, CFrame.new(pos + Vector3.new(0, 2.62, 0)), rgb(60, 44, 32), Enum.Material.Sand, DECOR)
		lib.cylinderY(m, "Trunk", 0.35, 5, CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0.05, 0, 0.04), rgb(110, 84, 60), Enum.Material.Wood, DECOR)
		for i = 1, 9 do
			local a = i * 2.4
			local y = 6.2 + rng() * 3.2
			local r = 0.6 + rng() * 1.1
			local d = 2 + rng() * 1.4
			ball(m, "Leaves", d, pos + Vector3.new(math.cos(a) * r, y, math.sin(a) * r), i % 3 == 0 and LEAF_LIGHT or LEAF, Enum.Material.Grass, DECOR)
		end
		return m
	end

	------------------------------------------------------------------
	-- Heiser: gamle sykehusheiser med messingramme, viserur og lampe
	------------------------------------------------------------------
	local DIAL_Y = 17.3
	for index, cx in ELEVATOR_X do
		local m = lib.new("Model", { Name = "Elevator" .. index, Attributes = { Index = index } }, elevators)
		local back = z0 - 14 -- heisens bakvegg

		-- Heisvogna: valnøttpanel, messinggelender, lys i taket
		box(m, "CarFloor", cx - 7, -1, back - 1, cx + 7, 0, z0 - 2, rgb(60, 78, 70), Enum.Material.SmoothPlastic)
		box(m, "Sill", cx - 5, 0, z0 - 2.1, cx + 5, 0.06, z0, BRASS, Enum.Material.Metal, { CastShadow = false })
		box(m, "CarCeiling", cx - 7, 12, back - 1, cx + 7, 13, z0 - 2, TRIM, Enum.Material.SmoothPlastic)
		box(m, "CarBack", cx - 7, 0, back - 1, cx + 7, 12, back, WALNUT, Enum.Material.Wood)
		box(m, "CarLeft", cx - 7, 0, back, cx - 6, 12, z0 - 2, WALNUT, Enum.Material.Wood)
		box(m, "CarRight", cx + 6, 0, back, cx + 7, 12, z0 - 2, WALNUT, Enum.Material.Wood)
		box(m, "CarFront", cx - 7, 0, z0 - 2.2, cx - 5, 12, z0 - 2, WALNUT, Enum.Material.Wood)
		box(m, "CarFront", cx + 5, 0, z0 - 2.2, cx + 7, 12, z0 - 2, WALNUT, Enum.Material.Wood)
		-- lyse lister i panelene
		for _, zz in { back + 4, back + 8 } do
			box(m, "PanelLine", cx - 6, 0.6, zz - 0.06, cx - 5.94, 11.4, zz + 0.06, WALNUT_LIGHT, Enum.Material.Wood, DECOR)
			box(m, "PanelLine", cx + 5.94, 0.6, zz - 0.06, cx + 6, 11.4, zz + 0.06, WALNUT_LIGHT, Enum.Material.Wood, DECOR)
		end
		for _, xx in { cx - 3, cx + 3 } do
			box(m, "PanelLine", xx - 0.06, 0.6, back, xx + 0.06, 11.4, back + 0.06, WALNUT_LIGHT, Enum.Material.Wood, DECOR)
		end
		box(m, "Rail", cx - 5.6, 3.2, back + 0.3, cx + 5.6, 3.5, back + 0.6, BRASS, Enum.Material.Metal, NO_HIT)
		box(m, "Rail", cx - 5.9, 3.2, back + 0.6, cx - 5.6, 3.5, z0 - 3, BRASS, Enum.Material.Metal, NO_HIT)
		box(m, "Rail", cx + 5.6, 3.2, back + 0.6, cx + 5.9, 3.5, z0 - 3, BRASS, Enum.Material.Metal, NO_HIT)
		local carLight = box(m, "CarLight", cx - 2.5, 11.85, back + 3, cx + 2.5, 12, back + 9, rgb(255, 242, 214), Enum.Material.Neon, DECOR)
		lib.new("PointLight", { Range = 14, Brightness = 0.9, Color = rgb(255, 225, 180) }, carLight)
		-- inspeksjonsbevis på bakveggen (utløpt)
		local certPos = Vector3.new(cx + 3.6, 7.6, back + 0.08)
		local cert = facing(m, "Certificate", Vector3.new(1.8, 2.3, 0.06), certPos, Vector3.new(0, 0, 1), CREAM_PAPER, Enum.Material.SmoothPlastic, DECOR)
		local certGui = gui(cert, nil, 1)
		label(certGui, "Head", 0.08, 0.08, 0.84, 0.16, "INSPECTION", INK, Enum.Font.SpecialElite)
		label(certGui, "Body", 0.08, 0.3, 0.84, 0.36, "ELEVATOR " .. index .. "\nCAPACITY 4 PERSONS\nNEXT CHECK:", INK, Enum.Font.SpecialElite)
		label(certGui, "Date", 0.08, 0.7, 0.84, 0.16, "OCT 1997", rgb(170, 30, 30), Enum.Font.SpecialElite)
		box(m, "CertFrame", cx + 2.6, 6.35, back, cx + 4.6, 8.85, back + 0.05, BRASS_DARK, Enum.Material.Metal, DECOR)

		-- Knappepanel inne i heisen (B3 lyser allerede...)
		local bp = Vector3.new(cx + 5.94, 5.4, z0 - 4)
		facing(m, "ButtonPanel", Vector3.new(1.3, 3, 0.1), bp, Vector3.new(-1, 0, 0), BRASS, Enum.Material.Metal, NO_HIT)
		for i, name in { "L", "B1", "B2", "B3" } do
			local lit = name == "B3"
			local pos = Vector3.new(cx + 5.86, 6.6 - (i - 1) * 0.75, z0 - 4)
			local b = disc(m, "Button", 0.42, 0.08, pos, Vector3.new(-1, 0, 0), lit and rgb(255, 150, 70) or rgb(236, 224, 196), lit and Enum.Material.Neon or Enum.Material.SmoothPlastic, DECOR)
			if lit then
				lib.new("PointLight", { Range = 3, Brightness = 0.5, Color = rgb(255, 150, 70) }, b)
			end
		end
		-- Bryter for vanskelighetsgrad på den andre veggen
		local mp = Vector3.new(cx - 5.88, 5.2, z0 - 4.5)
		facing(m, "ModeFrame", Vector3.new(3, 2.4, 0.08), mp - Vector3.new(0.04, 0, 0), Vector3.new(1, 0, 0), BRASS, Enum.Material.Metal, DECOR)
		local modePanel = facing(m, "ModePanel", Vector3.new(2.6, 2, 0.12), mp + Vector3.new(0.03, 0, 0), Vector3.new(1, 0, 0), GLASS_BLACK, Enum.Material.SmoothPlastic)
		lib.sign(modePanel, "NORMAL\n3 LIVES", { Color = rgb(200, 220, 200), Font = Enum.Font.SpecialElite, Brightness = 1.6 })
		lib.new("ProximityPrompt", {
			Name = "ModePrompt",
			ActionText = "Change difficulty",
			ObjectText = "Mode: Normal",
			HoldDuration = 0,
			MaxActivationDistance = 8,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.E,
		}, modePanel)

		-- Dører i børstet stål (står åpne i fila; serveren lukker dem når heisen går)
		local doorL = box(m, "DoorL", cx - 10, 0, z0 - 1.25, cx - 5, 12, z0 - 0.75, STEEL, Enum.Material.Metal, { Reflectance = 0.06 })
		doorL:SetAttribute("CloseOffset", 5)
		local doorR = box(m, "DoorR", cx + 5, 0, z0 - 1.25, cx + 10, 12, z0 - 0.75, STEEL, Enum.Material.Metal, { Reflectance = 0.06 })
		doorR:SetAttribute("CloseOffset", -5)

		-- Messingramme rundt døra
		box(m, "Frame", cx - 6.2, 0, z0, cx - 5, 12, z0 + 0.4, BRASS, Enum.Material.Metal)
		box(m, "Frame", cx + 5, 0, z0, cx + 6.2, 12, z0 + 0.4, BRASS, Enum.Material.Metal)
		box(m, "Frame", cx - 6.2, 12, z0, cx + 6.2, 13, z0 + 0.4, BRASS, Enum.Material.Metal)
		box(m, "Moulding", cx - 6.55, 0, z0, cx - 6.2, 13.35, z0 + 0.25, BRASS_DARK, Enum.Material.Metal)
		box(m, "Moulding", cx + 6.2, 0, z0, cx + 6.55, 13.35, z0 + 0.25, BRASS_DARK, Enum.Material.Metal)
		box(m, "Moulding", cx - 6.55, 13, z0, cx + 6.55, 13.35, z0 + 0.25, BRASS_DARK, Enum.Material.Metal)
		box(m, "Plinth", cx - 6.6, 0, z0, cx - 4.95, 0.9, z0 + 0.5, BRASS_DARK, Enum.Material.Metal)
		box(m, "Plinth", cx + 4.95, 0, z0, cx + 6.6, 0.9, z0 + 0.5, BRASS_DARK, Enum.Material.Metal)

		-- Skilt med status (svart glass i messingramme)
		box(m, "SignFrame", cx - 4.9, 13.45, z0, cx + 4.9, DIAL_Y, z0 + 0.3, BRASS, Enum.Material.Metal)
		local signPos = Vector3.new(cx, 15.35, z0 + 0.38)
		local sign = facing(m, "Sign", Vector3.new(9.2, 3.4, 0.16), signPos, Vector3.new(0, 0, 1), GLASS_BLACK, Enum.Material.SmoothPlastic)
		local sg = lib.new("SurfaceGui", {
			Name = "SignGui",
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0,
			Brightness = 1.4,
		}, sign)
		label(sg, "Title", 0.05, 0.04, 0.9, 0.28, "ELEVATOR " .. index, rgb(236, 192, 110), Enum.Font.GothamBold)
		label(sg, "Mode", 0.05, 0.34, 0.9, 0.18, "NORMAL", rgb(200, 220, 200), Enum.Font.SpecialElite)
		label(sg, "Status", 0.05, 0.55, 0.9, 0.18, "0/4 PLAYERS", rgb(230, 226, 214), Enum.Font.Code)
		label(sg, "Timer", 0.05, 0.76, 0.9, 0.19, "STEP IN TO PLAY", rgb(120, 230, 130), Enum.Font.Code)
		lib.new("Sound", { Name = "DoorSound", RollOffMaxDistance = 60, Volume = 0.8 }, sign)

		-- Viserur over skiltet: L, B1, B2, B3 (nedre halvdel skjules bak skiltrammen)
		local dialCenter = Vector3.new(cx, DIAL_Y, z0)
		local toRoom = Vector3.new(0, 0, 1)
		disc(m, "DialRim", 4.9, 0.16, dialCenter + Vector3.new(0, 0, 0.1), toRoom, BRASS, Enum.Material.Metal)
		disc(m, "DialFace", 4.3, 0.06, dialCenter + Vector3.new(0, 0, 0.2), toRoom, rgb(242, 234, 212), Enum.Material.SmoothPlastic)
		local dialPlate = facing(m, "DialMarks", Vector3.new(4.3, 2.15, 0.02), dialCenter + Vector3.new(0, 1.075, 0.245), toRoom, rgb(0, 0, 0), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		local dg = gui(dialPlate, nil, 0.6)
		for _, name in { "L", "B1", "B2", "B3" } do
			local a = math.rad(DIAL[name])
			-- tekst langs en bue, og en liten strek ved hver etasje
			local tx = 0.5 + (math.sin(a) * 1.72) / 4.3
			local ty = 1 - (math.cos(a) * 1.72) / 2.15
			label(dg, "Mark" .. name, tx - 0.08, ty - 0.11, 0.16, 0.22, name, name == "B3" and rgb(170, 26, 26) or INK, Enum.Font.GothamBold)
			local kx = 0.5 + (math.sin(a) * 1.25) / 4.3
			local ky = 1 - (math.cos(a) * 1.25) / 2.15
			frame(dg, kx, ky, 0.012, 0.12, INK, DIAL[name])
		end
		local pivot = Vector3.new(cx, DIAL_Y, z0 + 0.3)
		local pivotCF = lib.lookAt(pivot, pivot + toRoom)
		local needleLen = 1.55
		local needle = lib.part(m, "Needle", Vector3.new(0.1, needleLen, 0.04), pivotCF * CFrame.Angles(0, 0, math.rad(DIAL.L)) * CFrame.new(0, needleLen / 2 - 0.15, 0), rgb(150, 30, 24), Enum.Material.SmoothPlastic, DECOR)
		needle:SetAttribute("Pivot", pivot)
		needle:SetAttribute("Angle", DIAL.L)
		needle:SetAttribute("Down", DIAL.B3)
		needle:SetAttribute("Offset", needleLen / 2 - 0.15)
		disc(m, "Hub", 0.5, 0.1, pivot + Vector3.new(0, 0, 0.04), toRoom, BRASS_DARK, Enum.Material.Metal, DECOR)

		-- Ringeknapp og lampe ved siden av døra. Lampa (Indicator) viser status:
		-- grønn = gå inn, gul = noen venter, rød = full / går
		local px = cx + 7.4
		box(m, "CallPanel", px - 0.55, 3.4, z0, px + 0.55, 6.4, z0 + 0.12, BRASS, Enum.Material.Metal, NO_HIT)
		disc(m, "CallButton", 0.5, 0.1, Vector3.new(px, 5.3, z0 + 0.16), toRoom, rgb(255, 196, 120), Enum.Material.Neon, DECOR)
		disc(m, "CallButton", 0.5, 0.1, Vector3.new(px, 4.4, z0 + 0.16), toRoom, rgb(236, 224, 196), Enum.Material.SmoothPlastic, DECOR)
		disc(m, "LanternRing", 1.45, 0.14, Vector3.new(px, 7.9, z0 + 0.07), toRoom, BRASS, Enum.Material.Metal, NO_HIT)
		local indicator = disc(m, "Indicator", 1.1, 0.12, Vector3.new(px, 7.9, z0 + 0.16), toRoom, rgb(80, 220, 100), Enum.Material.Neon, DECOR)
		lib.new("PointLight", { Range = 9, Brightness = 0.7, Color = rgb(80, 220, 100) }, indicator)

		-- Sone der spillere teller som "i heisen"
		lib.part(m, "Zone", Vector3.new(11, 10, 11), CFrame.new(cx, 5, z0 - 8), rgb(0, 200, 255), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		lib.marker(m, "ExitPoint", lib.lookAt(Vector3.new(cx, 3.2, z0 + 9), Vector3.new(cx, 3.2, z0 + 20)))
	end

	-- Mellom heisene: planter, vegglamper og en etasjeoversikt
	local function sconce(pos: any)
		local m = lib.new("Model", { Name = "Sconce" }, props)
		box(m, "Plate", pos.X - 0.5, pos.Y - 0.9, pos.Z, pos.X + 0.5, pos.Y + 0.9, pos.Z + 0.1, BRASS, Enum.Material.Metal, DECOR)
		local shade = box(m, "Shade", pos.X - 0.7, pos.Y - 0.6, pos.Z + 0.1, pos.X + 0.7, pos.Y + 0.6, pos.Z + 0.9, rgb(255, 238, 206), Enum.Material.Neon, DECOR)
		lib.new("PointLight", { Range = 12, Brightness = 0.6, Color = rgb(255, 214, 160) }, shade)
	end
	for _, x in { -22, 22 } do
		snakePlant(Vector3.new(x, 0, z0 + 2.2))
		sconce(Vector3.new(x, 10, z0))
	end
	snakePlant(Vector3.new(-44, 0, z0 + 2.6), 1.1)
	snakePlant(Vector3.new(44.6, 0, z0 + 2.6), 1.1)
	sconce(Vector3.new(0, 14.2, z0))
	do
		local pos = Vector3.new(0, 8.6, z0 + 0.16)
		box(props, "DirectoryFrame", -2.1, 5.3, z0, 2.1, 11.9, z0 + 0.12, BRASS, Enum.Material.Metal, NO_HIT)
		local board = facing(props, "Directory", Vector3.new(3.9, 6.2, 0.1), pos, Vector3.new(0, 0, 1), GLASS_BLACK, Enum.Material.SmoothPlastic, NO_HIT)
		local g = gui(board, nil, 0.2, 1.2)
		label(g, "Head", 0.08, 0.04, 0.84, 0.12, "DIRECTORY", rgb(236, 192, 110), Enum.Font.GothamBold)
		frame(g, 0.5, 0.18, 0.84, 0.006, rgb(236, 192, 110))
		local rows = {
			{ "L", "LOBBY  •  RECEPTION", rgb(230, 226, 214) },
			{ "B1", "RADIOLOGY", rgb(230, 226, 214) },
			{ "B2", "MEDICAL RECORDS", rgb(230, 226, 214) },
			{ "B3", "WARD 13  (CLOSED)", rgb(220, 70, 60) },
		}
		for i, r in rows do
			local y = 0.24 + (i - 1) * 0.17
			label(g, "Floor" .. i, 0.08, y, 0.16, 0.1, r[1], rgb(236, 192, 110), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
			label(g, "Name" .. i, 0.26, y + 0.012, 0.68, 0.075, r[2], r[3], Enum.Font.Gotham, Enum.TextXAlignment.Left)
		end
		label(g, "Foot", 0.08, 0.9, 0.84, 0.06, "VISITORS: PLEASE USE ELEVATORS 1–4", rgb(150, 148, 140), Enum.Font.Gotham)
	end

	------------------------------------------------------------------
	-- Hengende skilt over midtgangen
	------------------------------------------------------------------
	do
		local pos = Vector3.new(0, 15.6, -210)
		local sign = facing(props, "HangingSign", Vector3.new(24, 2.6, 0.3), pos, Vector3.new(0, 0, 1), TEAL_DARK, Enum.Material.SmoothPlastic, NO_HIT)
		box(props, "HangingSignTrim", -12.2, 14.2, -210.2, 12.2, 14.3, -209.8, BRASS, Enum.Material.Metal, DECOR)
		box(props, "HangingSignTrim", -12.2, 16.9, -210.2, 12.2, 17, -209.8, BRASS, Enum.Material.Metal, DECOR)
		for _, x in { -10, 10 } do
			box(props, "Rod", x - 0.06, 17, -210.06, x + 0.06, HEIGHT, -209.94, CHROME, Enum.Material.Metal, DECOR)
		end
		local front = gui(sign, Enum.NormalId.Front, 0.2, 1.2)
		label(front, "Text", 0.04, 0.16, 0.92, 0.68, "▲  ELEVATORS   •   1–4 PLAYERS EACH", rgb(244, 240, 228), Enum.Font.GothamBold)
		local back = gui(sign, Enum.NormalId.Back, 0.2, 1.2)
		label(back, "Left", 0.04, 0.2, 0.44, 0.6, "◀  GIFT SHOP", rgb(244, 240, 228), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		label(back, "Right", 0.52, 0.2, 0.44, 0.6, "RECEPTION  ▶", rgb(244, 240, 228), Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	end

	------------------------------------------------------------------
	-- Stolrader (rygg mot rygg, med en plantekasse imellom)
	------------------------------------------------------------------
	local function seatRow(cx: number, z: number, facingNorth: boolean, count: number)
		local m = lib.new("Model", { Name = "Seats" }, props)
		local dir = facingNorth and 1 or -1 -- ryggen ligger på +z-siden når stolene ser mot nord
		local width = count * 2.5
		local xa, xb = cx - width / 2, cx + width / 2
		box(m, "Beam", xa + 0.3, 1.0, z - 0.15, xb - 0.3, 1.3, z + 0.15, CHROME, Enum.Material.Metal)
		for _, lx in { xa + 0.8, cx, xb - 0.8 } do
			box(m, "Leg", lx - 0.12, 0, z - 0.12, lx + 0.12, 1.0, z + 0.12, CHROME, Enum.Material.Metal)
			box(m, "Foot", lx - 0.15, 0, z - 0.9, lx + 0.15, 0.15, z + 0.9, CHROME, Enum.Material.Metal)
		end
		for i = 0, count - 1 do
			local sx = xa + 1.25 + i * 2.5
			box(m, "Seat", sx - 1.05, 1.3, z - 0.95, sx + 1.05, 1.75, z + 0.95, SEAT, Enum.Material.Leather)
			local backCf = CFrame.new(sx, 3.0, z + dir * 1.0) * CFrame.Angles(dir * 0.12, 0, 0)
			lib.part(m, "Back", Vector3.new(2.1, 2.3, 0.35), backCf, SEAT, Enum.Material.Leather)
			lib.part(m, "BackShell", Vector3.new(2.1, 2.3, 0.08), backCf * CFrame.new(0, 0, dir * 0.21), CHROME, Enum.Material.Metal, DECOR)
		end
		for i = 0, count do
			local ax = xa + i * 2.5
			box(m, "Arm", ax - 0.1, 2.35, z - 0.7, ax + 0.1, 2.5, z + 0.8, CHROME, Enum.Material.Metal, NO_HIT)
			box(m, "ArmPost", ax - 0.06, 1.3, z - 0.1, ax + 0.06, 2.35, z + 0.1, CHROME, Enum.Material.Metal, NO_HIT)
		end
	end
	local function planterBox(cx: number, z: number, length: number)
		local m = lib.new("Model", { Name = "Planter" }, props)
		box(m, "Box", cx - length / 2, 0, z - 0.8, cx + length / 2, 2.6, z + 0.8, WALNUT, Enum.Material.Wood)
		box(m, "BoxTop", cx - length / 2 - 0.1, 2.6, z - 0.9, cx + length / 2 + 0.1, 2.75, z + 0.9, TRIM, Enum.Material.Wood)
		box(m, "Soil", cx - length / 2 + 0.1, 2.6, z - 0.7, cx + length / 2 - 0.1, 2.8, z + 0.7, rgb(60, 44, 32), Enum.Material.Sand, DECOR)
		for x = cx - length / 2 + 0.8, cx + length / 2 - 0.8, 1.1 do
			for k = 1, 3 do
				local h = 1.4 + rng() * 1.6
				local cf = CFrame.new(x + (rng() - 0.5) * 0.6, 2.8, z + (rng() - 0.5) * 0.8) * CFrame.Angles((rng() - 0.5) * 0.6, rng() * 3, (rng() - 0.5) * 0.6)
				lib.part(m, "Leaf", Vector3.new(0.1, h, 0.45), cf * CFrame.new(0, h / 2, 0), k == 2 and LEAF_LIGHT or LEAF, Enum.Material.SmoothPlastic, DECOR)
			end
		end
	end
	local function sideTable(x: number, z: number)
		local m = lib.new("Model", { Name = "SideTable" }, props)
		box(m, "Top", x - 1.1, 2.0, z - 1.1, x + 1.1, 2.2, z + 1.1, WALNUT_LIGHT, Enum.Material.Wood)
		box(m, "Base", x - 0.9, 0, z - 0.9, x + 0.9, 2.0, z + 0.9, WALNUT, Enum.Material.Wood)
		local colors = { rgb(190, 60, 50), rgb(60, 110, 160), rgb(230, 210, 120) }
		for i, c in colors do
			local cf = CFrame.new(x + (rng() - 0.5) * 0.4, 2.2 + i * 0.05, z + (rng() - 0.5) * 0.4) * CFrame.Angles(0, rng() * 1.2, 0)
			lib.part(m, "Magazine", Vector3.new(1.1, 0.05, 1.5), cf, c, Enum.Material.SmoothPlastic, DECOR)
		end
	end
	for _, bx in { -21, 21 } do
		local cz = -197
		seatRow(bx, cz - 2.4, true, 6)
		seatRow(bx, cz + 2.4, false, 6)
		planterBox(bx, cz, 14)
		sideTable(bx - 9.4, cz - 2.4)
		sideTable(bx + 9.4, cz + 2.4)
	end

	------------------------------------------------------------------
	-- Resepsjonen (vestveggen) med "NOW SERVING"-skjerm og kølappautomat
	------------------------------------------------------------------
	do
		local m = lib.new("Model", { Name = "Reception" }, props)
		local za, zb = -203, -185
		local fx = -38 -- forsiden av disken
		box(m, "Counter", fx - 2.2, 0, za, fx, 3.8, zb, WALNUT, Enum.Material.Wood)
		box(m, "CounterTop", fx - 2.5, 3.8, za - 0.3, fx + 0.35, 4.1, zb + 0.3, TRIM, Enum.Material.Wood)
		for z = za + 1.5, zb - 1.5, 3 do
			box(m, "Panel", fx, 0.8, z - 1.1, fx + 0.06, 3.2, z + 1.1, WALNUT_LIGHT, Enum.Material.Wood, DECOR)
		end
		box(m, "Kick", fx - 2.2, 0, za, fx + 0.1, 0.5, zb, TEAL_DARK, Enum.Material.SmoothPlastic, DECOR)
		-- endestykker tilbake mot veggen
		box(m, "CounterSide", x0, 0, za - 1.2, fx, 3.8, za, WALNUT, Enum.Material.Wood)
		box(m, "CounterSide", x0, 0, zb, fx, 3.8, zb + 1.2, WALNUT, Enum.Material.Wood)
		box(m, "CounterSideTop", x0, 3.8, za - 1.3, fx + 0.35, 4.1, za, TRIM, Enum.Material.Wood)
		box(m, "CounterSideTop", x0, 3.8, zb, fx + 0.35, 4.1, zb + 1.3, TRIM, Enum.Material.Wood)
		-- ting på disken
		local bell = Vector3.new(fx - 0.5, 4.1, -190)
		lib.cylinderY(m, "BellBase", 0.6, 0.1, CFrame.new(bell + Vector3.new(0, 0.05, 0)), rgb(40, 36, 34), Enum.Material.SmoothPlastic, DECOR)
		ball(m, "Bell", 0.5, bell + Vector3.new(0, 0.2, 0), BRASS, Enum.Material.Metal, DECOR)
		lib.part(m, "Clipboard", Vector3.new(1.1, 0.06, 1.5), CFrame.new(fx - 0.9, 4.13, -196) * CFrame.Angles(0, 0.2, 0), WALNUT_LIGHT, Enum.Material.Wood, DECOR)
		lib.part(m, "Paper", Vector3.new(0.95, 0.02, 1.2), CFrame.new(fx - 0.9, 4.17, -196.1) * CFrame.Angles(0, 0.2, 0), CREAM_PAPER, Enum.Material.SmoothPlastic, DECOR)
		local vase = Vector3.new(fx - 1.2, 4.1, -200.5)
		lib.cylinderY(m, "Vase", 0.6, 1.1, CFrame.new(vase + Vector3.new(0, 0.55, 0)), rgb(120, 170, 190), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false, CanQuery = false, CastShadow = false })
		for i = 1, 5 do
			local a = i * 1.26
			local top = vase + Vector3.new(math.cos(a) * 0.35, 1.6 + rng() * 0.4, math.sin(a) * 0.35)
			lib.part(m, "Stem", Vector3.new(0.05, 0.9, 0.05), CFrame.new((vase + Vector3.new(0, 1.1, 0) + top) / 2), LEAF, Enum.Material.SmoothPlastic, DECOR)
			ball(m, "Flower", 0.32, top, i % 2 == 0 and rgb(236, 236, 230) or rgb(240, 196, 80), Enum.Material.SmoothPlastic, DECOR)
		end
		local cardPos = Vector3.new(fx - 0.2, 4.45, -193)
		local card = facing(m, "Card", Vector3.new(1.6, 0.7, 0.04), cardPos, Vector3.new(1, 0, 0), CREAM_PAPER, Enum.Material.SmoothPlastic, DECOR)
		lib.sign(card, "PLEASE RING", { Color = INK, Font = Enum.Font.SpecialElite, LightInfluence = 1 })

		-- bak disken: skrivebord, PC, grønn bankerlampe, stol, arkivskap
		box(m, "BackDesk", x0, 0, -201, x0 + 2.4, 2.9, -187, WALNUT, Enum.Material.Wood)
		box(m, "BackDeskTop", x0, 2.9, -201.2, x0 + 2.6, 3.1, -186.8, TRIM, Enum.Material.Wood)
		box(m, "Computer", x0 + 0.3, 3.1, -197.4, x0 + 2.1, 4.9, -195.4, rgb(214, 206, 184), Enum.Material.SmoothPlastic)
		local screen = facing(m, "Screen", Vector3.new(1.5, 1.2, 0.04), Vector3.new(x0 + 2.12, 4.05, -196.4), Vector3.new(1, 0, 0), rgb(18, 40, 30), Enum.Material.Glass, DECOR)
		local sgui = gui(screen, nil, 0, 1.6)
		label(sgui, "Text", 0.08, 0.1, 0.84, 0.8, "> PATIENT 0413\n> STATUS: ???\n> _", rgb(110, 255, 140), Enum.Font.Code, Enum.TextXAlignment.Left)
		lib.new("PointLight", { Range = 5, Brightness = 0.6, Color = rgb(110, 255, 140) }, screen)
		local lampPos = Vector3.new(x0 + 1.4, 3.1, -191)
		box(m, "LampBase", lampPos.X - 0.4, 3.1, lampPos.Z - 0.3, lampPos.X + 0.4, 3.25, lampPos.Z + 0.3, BRASS, Enum.Material.Metal, DECOR)
		box(m, "LampStem", lampPos.X - 0.05, 3.25, lampPos.Z - 0.05, lampPos.X + 0.05, 4.2, lampPos.Z + 0.05, BRASS, Enum.Material.Metal, DECOR)
		local shade = lib.part(m, "LampShade", Vector3.new(1.4, 0.45, 0.7), CFrame.new(lampPos + Vector3.new(0, 1.35, 0)), rgb(40, 140, 80), Enum.Material.Glass, { Transparency = 0.15, CanCollide = false, CanQuery = false, CastShadow = false })
		lib.new("PointLight", { Range = 8, Brightness = 0.8, Color = rgb(255, 222, 160) }, shade)
		local chair = Vector3.new(-43, 0, -194)
		lib.cylinderY(m, "ChairBase", 1.6, 0.2, CFrame.new(chair + Vector3.new(0, 0.1, 0)), rgb(40, 40, 42), Enum.Material.Metal, DECOR)
		lib.cylinderY(m, "ChairPost", 0.25, 1.4, CFrame.new(chair + Vector3.new(0, 0.9, 0)), rgb(40, 40, 42), Enum.Material.Metal, DECOR)
		box(m, "ChairSeat", chair.X - 1, 1.6, chair.Z - 1, chair.X + 1, 2.0, chair.Z + 1, TEAL_DARK, Enum.Material.Fabric)
		box(m, "ChairBack", chair.X - 1.2, 2.0, chair.Z - 0.9, chair.X - 0.9, 4.2, chair.Z + 0.9, TEAL_DARK, Enum.Material.Fabric)
		box(m, "FileCabinet", x0, 0, -186.9, x0 + 2.2, 5, -185.1, rgb(150, 156, 150), Enum.Material.Metal)
		for i = 0, 2 do
			box(m, "Drawer", x0 + 2.2, 0.5 + i * 1.5, -186.7, x0 + 2.26, 1.7 + i * 1.5, -185.3, rgb(170, 176, 170), Enum.Material.Metal, DECOR)
		end

		-- skilt og "NOW SERVING" på veggen bak
		local wx = x0 + 0.06
		box(m, "SignBack", wx, 10.3, -201.5, wx + 0.12, 12.7, -186.5, BRASS, Enum.Material.Metal, NO_HIT)
		local rs = facing(m, "ReceptionSign", Vector3.new(14.6, 2.0, 0.1), Vector3.new(wx + 0.18, 11.5, -194), Vector3.new(1, 0, 0), TEAL_DARK, Enum.Material.SmoothPlastic, NO_HIT)
		lib.sign(rs, "RECEPTION", { Color = rgb(244, 240, 228), Font = Enum.Font.GothamBold, Brightness = 1.2, LightInfluence = 0.2 })
		box(m, "ServingBox", wx, 13.4, -198, wx + 0.6, 17.2, -190, rgb(26, 26, 28), Enum.Material.SmoothPlastic, NO_HIT)
		local serving = facing(m, "NowServing", Vector3.new(7.4, 3.2, 0.06), Vector3.new(wx + 0.64, 15.3, -194), Vector3.new(1, 0, 0), GLASS_BLACK, Enum.Material.SmoothPlastic, DECOR)
		local ng = gui(serving, nil, 0, 1.8)
		label(ng, "Head", 0.06, 0.06, 0.88, 0.2, "NOW SERVING", rgb(230, 226, 214), Enum.Font.GothamBold)
		label(ng, "Number", 0.06, 0.3, 0.88, 0.64, "0413", LED_RED, Enum.Font.Code)
		lib.new("PointLight", { Range = 9, Brightness = 0.5, Color = rgb(255, 80, 60) }, serving)

		-- kølappautomat på en stang foran disken
		local tp = Vector3.new(-35.5, 0, -183)
		lib.cylinderY(m, "TicketBase", 1.4, 0.2, CFrame.new(tp + Vector3.new(0, 0.1, 0)), rgb(40, 40, 42), Enum.Material.Metal)
		lib.cylinderY(m, "TicketPole", 0.25, 3.8, CFrame.new(tp + Vector3.new(0, 2.0, 0)), CHROME, Enum.Material.Metal)
		box(m, "Ticket", tp.X - 0.6, 3.9, tp.Z - 0.6, tp.X + 0.6, 5.3, tp.Z + 0.6, rgb(200, 40, 36), Enum.Material.SmoothPlastic)
		lib.part(m, "TicketStrip", Vector3.new(0.5, 0.6, 0.02), CFrame.new(tp.X, 3.85, tp.Z + 0.62) * CFrame.Angles(0.3, 0, 0), CREAM_PAPER, Enum.Material.SmoothPlastic, DECOR)
		local tsign = facing(m, "TicketSign", Vector3.new(1.6, 0.9, 0.05), Vector3.new(tp.X, 5.9, tp.Z), Vector3.new(0, 0, 1), rgb(244, 240, 228), Enum.Material.SmoothPlastic, DECOR)
		lib.sign(tsign, "TAKE A\nNUMBER", { Color = rgb(200, 40, 36), Font = Enum.Font.GothamBold, LightInfluence = 0.6 })
	end

	-- Regeltavle (vestveggen, mot heisene)
	do
		local wx = x0 + 0.1
		box(props, "RulesFrame", wx, 4.9, -228.4, wx + 0.15, 14.6, -211.6, WALNUT, Enum.Material.Wood, NO_HIT)
		local head = facing(props, "RulesHead", Vector3.new(16.4, 1.8, 0.08), Vector3.new(wx + 0.2, 13.55, -220), Vector3.new(1, 0, 0), TEAL_DARK, Enum.Material.SmoothPlastic, NO_HIT)
		lib.sign(head, "HOW TO PLAY", { Color = rgb(244, 240, 228), Font = Enum.Font.GothamBold, LightInfluence = 0.3, Brightness = 1.1 })
		local board = facing(props, "RulesBoard", Vector3.new(16.4, 7.5, 0.08), Vector3.new(wx + 0.2, 8.85, -220), Vector3.new(1, 0, 0), CREAM_PAPER, Enum.Material.SmoothPlastic, NO_HIT)
		local g = gui(board, nil, 0.5)
		local rules = {
			"1.  Step into an elevator (1–4 players each)",
			"2.  Find the 5 keys hidden in the hospital",
			"3.  Bring them to the EMERGENCY EXIT",
			"4.  Hide in a locker when it comes (20 s max)",
			"5.  3 lives. Friends can help you up when you are down",
			"6.  Panel inside the elevator: NIGHTMARE mode",
		}
		for i, text in rules do
			label(g, "Rule" .. i, 0.05, 0.06 + (i - 1) * 0.118, 0.9, 0.09, text, INK, Enum.Font.SpecialElite, Enum.TextXAlignment.Left)
		end
		frame(g, 0.5, 0.8, 0.9, 0.006, rgb(150, 140, 120))
		label(g, "Controls", 0.05, 0.84, 0.9, 0.1, "SHIFT / RUN = run     1 = flashlight     E = use / hide", TEAL_DARK, Enum.Font.GothamBold)
	end

	------------------------------------------------------------------
	-- Toppliste: "HALL OF SURVIVORS" (østveggen, mot heisene)
	------------------------------------------------------------------
	do
		local m = lib.new("Model", { Name = "Leaderboard" }, props)
		local wx = x1 - 0.1
		box(m, "BoardFrame", wx - 0.2, 4.6, -227.8, wx, 15.4, -208.8, WALNUT, Enum.Material.Wood, NO_HIT)
		box(m, "BoardTrim", wx - 0.26, 15.2, -228, wx, 15.5, -208.6, BRASS, Enum.Material.Metal, DECOR)
		box(m, "BoardTrim", wx - 0.26, 4.5, -228, wx, 4.8, -208.6, BRASS, Enum.Material.Metal, DECOR)
		local board = facing(m, "Board", Vector3.new(18.2, 10.2, 0.06), Vector3.new(wx - 0.24, 10, -218.3), Vector3.new(-1, 0, 0), rgb(24, 24, 26), Enum.Material.Fabric, NO_HIT)
		local g = lib.new("SurfaceGui", {
			Name = "BoardGui",
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0.25,
			Brightness = 1.2,
		}, board)
		local WHITE = rgb(238, 234, 222)
		local GREY = rgb(150, 148, 140)
		local RANK = { rgb(240, 196, 80), rgb(206, 210, 214), rgb(214, 140, 80) }
		for col, info in { { "Fast", "FASTEST ESCAPE" }, { "Most", "MOST ESCAPES" } } do
			local cx = if col == 1 then 0.03 else 0.53
			label(g, info[1] .. "Title", cx, 0.04, 0.44, 0.09, info[2], WHITE, Enum.Font.GothamBold)
			frame(g, cx + 0.22, 0.145, 0.44, 0.005, GREY)
			for i = 1, 10 do
				local y = 0.17 + (i - 1) * 0.077
				label(g, info[1] .. "Rank" .. i, cx, y, 0.05, 0.062, tostring(i), RANK[i] or GREY, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
				label(g, info[1] .. "Name" .. i, cx + 0.07, y + 0.004, 0.27, 0.056, "—", WHITE, Enum.Font.Gotham, Enum.TextXAlignment.Left)
				label(g, info[1] .. "Value" .. i, cx + 0.34, y + 0.004, 0.1, 0.056, "", WHITE, Enum.Font.Code, Enum.TextXAlignment.Right)
			end
		end
		frame(g, 0.5, 0.55, 0.003, 0.84, GREY)
		label(g, "Footer", 0.03, 0.955, 0.94, 0.035, "ALL SERVERS  •  UPDATED EVERY MINUTE", GREY, Enum.Font.Gotham)
		-- messingskilt over tavla
		local plate = facing(m, "Plate", Vector3.new(12, 1.9, 0.12), Vector3.new(wx - 0.1, 16.8, -218.3), Vector3.new(-1, 0, 0), BRASS, Enum.Material.Metal, NO_HIT)
		lib.sign(plate, "HALL OF SURVIVORS", { Color = rgb(44, 28, 10), Font = Enum.Font.GothamBold, LightInfluence = 0.8 })
		-- bildelampe over tavla
		box(m, "PictureLampArm", wx - 1.2, 18.1, -218.4, wx, 18.3, -218.2, BRASS, Enum.Material.Metal, DECOR)
		local pl = box(m, "PictureLamp", wx - 1.6, 17.9, -224.8, wx - 1.0, 18.3, -211.8, BRASS_DARK, Enum.Material.Metal, DECOR)
		lib.new("SpotLight", { Range = 16, Brightness = 1.4, Angle = 100, Face = Enum.NormalId.Bottom, Color = rgb(255, 230, 190) }, pl)
	end

	------------------------------------------------------------------
	-- Gavebutikken (østveggen): markise, hyller med lommelykter, glassdisk
	------------------------------------------------------------------
	do
		local m = lib.new("Model", { Name = "CosmeticsShop" }, props)
		local za, zb = -206, -176
		local front = 37 -- markisens forkant
		box(m, "ShopFloor", front + 0.5, 0, za + 1, x1, 0.05, zb - 1, rgb(150, 108, 70), Enum.Material.WoodPlanks, { CastShadow = false })
		-- sidevegger
		for _, z in { za, zb - 1 } do
			box(m, "Partition", front + 1, 0, z, x1, 12.5, z + 1, WALNUT, Enum.Material.Wood)
			box(m, "PartitionTop", front + 0.8, 12.5, z - 0.1, x1, 12.8, z + 1.1, BRASS, Enum.Material.Metal)
		end
		-- bakvegg i mørk teal med hyller
		box(m, "BackWall", x1 - 0.3, 0, za + 1, x1, 12.5, zb - 1, TEAL_DARK, Enum.Material.SmoothPlastic)
		for i, f in FLASHLIGHTS do
			local z = za + 3.3 + (i - 1) * 3.9
			-- lite hylleskap per lykt med lys i sin farge
			box(m, "Shelf", x1 - 1.6, 6.2, z - 1.6, x1 - 0.3, 6.4, z + 1.6, TRIM, Enum.Material.Wood)
			box(m, "Shelf", x1 - 1.6, 9.4, z - 1.6, x1 - 0.3, 9.6, z + 1.6, TRIM, Enum.Material.Wood)
			-- lommelykt som peker ut i rommet
			local p = Vector3.new(x1 - 1.0, 6.83, z)
			disc(m, "Torch", 0.55, 1.5, p, Vector3.new(-1, 0, 0), rgb(46, 46, 50), Enum.Material.Metal, NO_HIT)
			disc(m, "TorchHead", 0.85, 0.5, p + Vector3.new(-0.9, 0, 0), Vector3.new(-1, 0, 0), rgb(46, 46, 50), Enum.Material.Metal, NO_HIT)
			local lens = disc(m, "Lens", 0.7, 0.06, p + Vector3.new(-1.17, 0, 0), Vector3.new(-1, 0, 0), f.color, Enum.Material.Neon, DECOR)
			lib.new("PointLight", { Range = 6, Brightness = 1.1, Color = f.color }, lens)
			-- prislapp
			local tag = facing(m, "PriceTag", Vector3.new(2.6, 0.9, 0.04), Vector3.new(x1 - 1.62, 5.75, z), Vector3.new(-1, 0, 0), CREAM_PAPER, Enum.Material.SmoothPlastic, DECOR)
			local tg = gui(tag, nil, 0.4)
			label(tg, "Name", 0.04, 0.04, 0.92, 0.48, f.name, INK, Enum.Font.GothamBold)
			label(tg, "Price", 0.04, 0.52, 0.92, 0.44, if f.price == 0 then "FREE" else (f.price .. " COINS"), rgb(160, 110, 20), Enum.Font.Gotham)
			-- eske på hylla over
			box(m, "Box", x1 - 1.4, 9.6, z - 0.7, x1 - 0.4, 11.0, z + 0.7, f.color:Lerp(rgb(255, 255, 255), 0.35), Enum.Material.SmoothPlastic, DECOR)
		end
		-- navneskilt-tavle på den nordre sideveggen
		do
			local bp = Vector3.new(42.3, 8.5, za + 1.04)
			local board = facing(m, "TitleBoard", Vector3.new(7.4, 6.4, 0.06), bp, Vector3.new(0, 0, 1), CREAM_PAPER, Enum.Material.SmoothPlastic, NO_HIT)
			local g = gui(board, nil, 0.5)
			label(g, "Head", 0.06, 0.04, 0.88, 0.13, "NAME TAGS", TEAL_DARK, Enum.Font.GothamBold)
			label(g, "Sub", 0.06, 0.17, 0.88, 0.07, "WORN ABOVE YOUR HEAD", rgb(120, 116, 104), Enum.Font.Gotham)
			for i, t in TITLES do
				local col = (i - 1) % 2
				local row = math.floor((i - 1) / 2)
				local x = 0.06 + col * 0.46
				local y = 0.3 + row * 0.22
				frame(g, x + 0.21, y + 0.08, 0.42, 0.16, rgb(255, 252, 244))
				label(g, "Tag" .. i, x + 0.02, y + 0.025, 0.38, 0.11, t.text, t.color, Enum.Font.GothamBold)
			end
			box(m, "TitleBoardFrame", 38.2, 5.1, za + 1, 46.4, 11.9, za + 1.02, BRASS, Enum.Material.Metal, DECOR)
		end
		-- "OPEN"-skilt på den søndre sideveggen
		do
			local sp = Vector3.new(43, 8.5, zb - 1.04)
			box(m, "OpenBack", 41.4, 7.7, zb - 1.06, 44.6, 9.3, zb - 1, rgb(20, 18, 18), Enum.Material.SmoothPlastic, DECOR)
			local s = facing(m, "OpenSign", Vector3.new(3, 1.4, 0.04), sp - Vector3.new(0, 0, 0.04), Vector3.new(0, 0, -1), rgb(20, 18, 18), Enum.Material.SmoothPlastic, DECOR)
			lib.sign(s, "OPEN", { Color = rgb(255, 70, 90), Font = Enum.Font.GothamBold, Brightness = 2.4 })
			lib.new("PointLight", { Range = 6, Brightness = 0.6, Color = rgb(255, 70, 90) }, s)
		end

		-- markise med striper
		local stripeW = 2
		local n = 0
		for z = za, zb - stripeW, stripeW do
			n += 1
			local color = if n % 2 == 0 then TRIM else rgb(70, 132, 120)
			local topPos = Vector3.new(front + 5, 14.4, z + stripeW / 2)
			local lowPos = Vector3.new(front - 0.3, 12.6, z + stripeW / 2)
			local mid = (topPos + lowPos) / 2
			local len = (topPos - lowPos).Magnitude
			local cf = lib.lookAt(mid, topPos) -- -Z langs markisen
			lib.part(m, "Awning", Vector3.new(stripeW, 0.15, len), cf, color, Enum.Material.Fabric, { CanQuery = false })
			lib.part(m, "Valance", Vector3.new(0.12, 0.9, stripeW), CFrame.new(front - 0.35, 12.15, z + stripeW / 2), color, Enum.Material.Fabric, DECOR)
		end
		box(m, "AwningBack", front + 5, 14.2, za, x1, 14.6, zb, TRIM, Enum.Material.SmoothPlastic)
		-- skiltet "GIFT SHOP" over markisen
		local signPos = Vector3.new(front + 5.2, 16.4, (za + zb) / 2)
		box(m, "SignFrame", front + 5.3, 14.4, -199, front + 5.5, 18.4, -183, BRASS, Enum.Material.Metal, NO_HIT)
		local sign = facing(m, "ShopSign", Vector3.new(15, 3.6, 0.2), signPos, Vector3.new(-1, 0, 0), TEAL_DARK, Enum.Material.SmoothPlastic, NO_HIT)
		local sg = gui(sign, nil, 0.1, 1.3)
		label(sg, "Title", 0.05, 0.08, 0.9, 0.56, "GIFT SHOP", rgb(250, 236, 200), Enum.Font.GothamBold)
		label(sg, "Sub", 0.05, 0.66, 0.9, 0.24, "FLASHLIGHTS  •  NAME TAGS  •  COINS ONLY", rgb(236, 192, 110), Enum.Font.Gotham)
		for _, z in { -200.6, -181.4 } do
			disc(m, "Coin", 2.2, 0.25, Vector3.new(front + 5.1, 16.4, z), Vector3.new(-1, 0, 0), rgb(232, 182, 60), Enum.Material.Metal, DECOR)
			disc(m, "CoinInner", 1.6, 0.27, Vector3.new(front + 5.05, 16.4, z), Vector3.new(-1, 0, 0), rgb(250, 208, 96), Enum.Material.Metal, DECOR)
		end
		-- lys under markisen
		for _, z in { -201, -191, -181 } do
			local l = box(m, "AwningLight", front + 1.6, 12.9, z - 1.5, front + 2.2, 13.1, z + 1.5, rgb(255, 238, 206), Enum.Material.Neon, DECOR)
			lib.new("PointLight", { Range = 14, Brightness = 0.9, Color = rgb(255, 218, 170) }, l)
		end

		-- glassdisk med lommelykter og mynter
		local ca, cb = -199, -183
		local cx1, cx2 = front + 2, front + 4.6
		box(m, "Counter", cx1, 0, ca, cx2, 2.6, cb, WALNUT, Enum.Material.Wood)
		box(m, "CounterKick", cx1 - 0.05, 0, ca, cx1, 0.5, cb, TEAL_DARK, Enum.Material.SmoothPlastic, DECOR)
		for z = ca + 2, cb - 2, 4 do
			box(m, "CounterPanel", cx1 - 0.06, 0.8, z - 1.6, cx1, 2.2, z + 1.6, WALNUT_LIGHT, Enum.Material.Wood, DECOR)
		end
		box(m, "CaseFloor", cx1, 2.6, ca, cx2, 2.7, cb, rgb(240, 236, 226), Enum.Material.SmoothPlastic)
		box(m, "CaseGlass", cx1 + 0.05, 2.7, ca + 0.05, cx2 - 0.05, 3.9, cb - 0.05, rgb(200, 230, 235), Enum.Material.Glass, { Transparency = 0.75 })
		for _, z in { ca, cb } do
			box(m, "CaseEdge", cx1, 2.7, z - 0.06, cx2, 3.9, z + 0.06, BRASS, Enum.Material.Metal, DECOR)
		end
		box(m, "CaseEdge", cx1 - 0.06, 3.9, ca, cx1 + 0.06, 4.0, cb, BRASS, Enum.Material.Metal, DECOR)
		box(m, "CaseEdge", cx1 - 0.06, 2.6, ca, cx1 + 0.06, 2.7, cb, BRASS, Enum.Material.Metal, DECOR)
		for i, f in FLASHLIGHTS do
			local z = ca + 1.6 + (i - 1) * 2.1
			local p = Vector3.new(cx1 + 1.2, 2.95, z)
			lib.part(m, "CaseTorch", Vector3.new(1.3, 0.38, 0.38), CFrame.new(p) * CFrame.Angles(0, 0.5, 0), rgb(46, 46, 50), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, CastShadow = false })
			local tip = p + (CFrame.Angles(0, 0.5, 0) * CFrame.new(-0.67, 0, 0)).Position
			lib.part(m, "CaseLens", Vector3.new(0.04, 0.34, 0.34), CFrame.new(tip) * CFrame.Angles(0, 0.5, 0), f.color, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, CastShadow = false })
		end
		local caseLight = box(m, "CaseLight", cx1 + 0.4, 3.82, ca + 0.5, cx2 - 0.4, 3.88, cb - 0.5, rgb(255, 246, 224), Enum.Material.Neon, DECOR)
		lib.new("PointLight", { Range = 7, Brightness = 0.6, Color = rgb(255, 236, 200) }, caseLight)
		box(m, "CounterTop", cx1 - 0.1, 3.9, ca - 0.1, cx2 + 0.1, 4.0, cb + 0.1, rgb(210, 236, 240), Enum.Material.Glass, { Transparency = 0.55 })
		-- kasseapparat og myntkrukke
		local reg = Vector3.new(cx1 + 1.4, 4.0, cb - 1.6)
		box(m, "Register", reg.X - 0.9, reg.Y, reg.Z - 1, reg.X + 0.9, reg.Y + 1.0, reg.Z + 1, rgb(206, 196, 172), Enum.Material.SmoothPlastic)
		lib.part(m, "RegisterTop", Vector3.new(1.4, 0.7, 1.8), CFrame.new(reg + Vector3.new(0.2, 1.3, 0)) * CFrame.Angles(0, 0, 0.35), rgb(206, 196, 172), Enum.Material.SmoothPlastic, DECOR)
		local rd = facing(m, "RegisterDisplay", Vector3.new(1.2, 0.36, 0.04), reg + Vector3.new(-0.55, 1.75, 0), Vector3.new(-1, 0, 0), GLASS_BLACK, Enum.Material.SmoothPlastic, DECOR)
		lib.sign(rd, "0413", { Color = rgb(120, 255, 140), Font = Enum.Font.Code, Brightness = 2 })
		local jar = Vector3.new(cx1 + 1.0, 4.0, ca + 1.6)
		lib.cylinderY(m, "Jar", 0.9, 1.2, CFrame.new(jar + Vector3.new(0, 0.6, 0)), rgb(220, 236, 240), Enum.Material.Glass, { Transparency = 0.6, CanCollide = false, CanQuery = false, CastShadow = false })
		for i = 1, 8 do
			lib.part(m, "JarCoin", Vector3.new(0.08, 0.36, 0.36), CFrame.new(jar + Vector3.new((rng() - 0.5) * 0.4, 0.1 + i * 0.09, (rng() - 0.5) * 0.4)) * CFrame.Angles(rng() * 3, 0, rng() * 0.5 + 1.3), rgb(240, 196, 70), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, CastShadow = false })
		end
		-- ballonger ("GET WELL SOON") festet til disken, en av dem har mistet lufta
		local balloonColors = { rgb(236, 120, 140), rgb(130, 190, 230), rgb(250, 214, 110) }
		for i, c in balloonColors do
			local anchor = Vector3.new(cx1 + 0.6, 4.0, ca + 3.6 + i * 0.3)
			local top = anchor + Vector3.new(-0.4 + i * 0.35, 5.2 + (i % 2) * 0.8, (i - 2) * 0.9)
			lib.part(m, "String", Vector3.new(0.03, (top - anchor).Magnitude, 0.03), lib.lookAt((anchor + top) / 2, top) * CFrame.Angles(math.pi / 2, 0, 0), rgb(230, 230, 230), Enum.Material.SmoothPlastic, DECOR)
			lib.ellipsoid(m, "Balloon", Vector3.new(1.4, 1.7, 1.4), CFrame.new(top + Vector3.new(0, 0.8, 0)), c, Enum.Material.SmoothPlastic)
		end
		do
			local floorPos = Vector3.new(cx1 - 0.8, 0.25, ca + 4.3)
			lib.ellipsoid(m, "DeflatedBalloon", Vector3.new(1.1, 0.5, 1.0), CFrame.new(floorPos) * CFrame.Angles(0.2, 0.4, 0.1), rgb(200, 60, 60), Enum.Material.SmoothPlastic)
		end
		-- knappen som åpner butikken (midt på disken)
		local promptPart = lib.part(m, "PromptPart", Vector3.new(1, 1, 1), CFrame.new(cx1 - 0.6, 4.4, (ca + cb) / 2), rgb(0, 0, 0), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
		lib.new("ProximityPrompt", {
			Name = "CosmeticsPrompt",
			ActionText = "Open shop",
			ObjectText = "Gift Shop",
			HoldDuration = 0,
			MaxActivationDistance = 11,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.E,
		}, promptPart)
	end

	------------------------------------------------------------------
	-- Sørveggen: inngangsdører (låst, natt ute), klokke, automat, akvarium
	------------------------------------------------------------------
	do
		local m = lib.new("Model", { Name = "Entrance" }, props)
		-- utsiden: mørk forhall med en kald gatelykt
		box(m, "OutsideFloor", -8, -1, z1 + 2, 8, 0, z1 + 6.5, rgb(30, 32, 36), Enum.Material.Concrete)
		box(m, "OutsideBack", -8, 0, z1 + 6, 8, 12, z1 + 6.5, rgb(12, 14, 18), Enum.Material.SmoothPlastic)
		box(m, "OutsideTop", -8, 11, z1 + 2, 8, 12, z1 + 6, rgb(12, 14, 18), Enum.Material.SmoothPlastic)
		box(m, "OutsideSide", -8, 0, z1 + 2, -6.6, 11, z1 + 6, rgb(12, 14, 18), Enum.Material.SmoothPlastic)
		box(m, "OutsideSide", 6.6, 0, z1 + 2, 8, 11, z1 + 6, rgb(12, 14, 18), Enum.Material.SmoothPlastic)
		local street = lib.part(m, "StreetGlow", Vector3.new(1, 1, 1), CFrame.new(3, 9, z1 + 4), rgb(0, 0, 0), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
		lib.new("PointLight", { Range = 10, Brightness = 0.6, Color = rgb(150, 180, 230) }, street)
		-- dørene: messingramme og glass (veggen har et hull bak)
		for _, side in { -1, 1 } do
			local xa, xb = side * 0.1, side * 6
			local lo, hi = math.min(xa, xb), math.max(xa, xb)
			box(m, "DoorGlass", lo + 0.4, 0.6, z1 + 0.9, hi - 0.4, 9.6, z1 + 1.0, rgb(120, 140, 150), Enum.Material.Glass, { Transparency = 0.55 })
			box(m, "DoorFrame", lo, 0, z1 + 0.8, lo + 0.4, 10, z1 + 1.1, BRASS, Enum.Material.Metal)
			box(m, "DoorFrame", hi - 0.4, 0, z1 + 0.8, hi, 10, z1 + 1.1, BRASS, Enum.Material.Metal)
			box(m, "DoorFrame", lo, 9.6, z1 + 0.8, hi, 10, z1 + 1.1, BRASS, Enum.Material.Metal)
			box(m, "DoorFrame", lo, 0, z1 + 0.8, hi, 0.6, z1 + 1.1, BRASS, Enum.Material.Metal)
			box(m, "PushBar", lo + 0.8, 4.3, z1 + 0.6, hi - 0.8, 4.6, z1 + 0.8, CHROME, Enum.Material.Metal, NO_HIT)
		end
		box(m, "DoorHeader", -6.6, 10, z1, 6.6, 11, z1 + 1.1, BRASS_DARK, Enum.Material.Metal)
		local closed = facing(m, "ClosedSign", Vector3.new(2.4, 1.2, 0.04), Vector3.new(-3, 6.8, z1 + 0.86), Vector3.new(0, 0, -1), rgb(244, 240, 228), Enum.Material.SmoothPlastic, DECOR)
		local cg = gui(closed, nil, 0.6)
		label(cg, "Text", 0.06, 0.08, 0.88, 0.5, "CLOSED", rgb(190, 30, 30), Enum.Font.GothamBold)
		label(cg, "Sub", 0.06, 0.6, 0.88, 0.3, "VISITING HOURS 8–20", INK, Enum.Font.Gotham)
		-- klokke som har stoppet 03:13
		local clockPos = Vector3.new(0, 14.4, z1 - 0.1)
		disc(m, "ClockRim", 3.6, 0.3, clockPos, Vector3.new(0, 0, -1), rgb(40, 36, 34), Enum.Material.SmoothPlastic)
		disc(m, "ClockFace", 3.2, 0.32, clockPos, Vector3.new(0, 0, -1), rgb(244, 240, 230), Enum.Material.SmoothPlastic)
		local faceCF = lib.lookAt(clockPos + Vector3.new(0, 0, -0.18), clockPos + Vector3.new(0, 0, -5))
		-- positiv vinkel = med klokka sett fra rommet
		local function hand(name: string, len: number, width: number, deg: number, color: any, depth: number)
			lib.part(m, name, Vector3.new(width, len, 0.03), faceCF * CFrame.new(0, 0, -depth) * CFrame.Angles(0, 0, math.rad(deg)) * CFrame.new(0, len / 2 - 0.15, 0), color, Enum.Material.SmoothPlastic, DECOR)
		end
		for h = 0, 11 do
			lib.part(m, "Tick", Vector3.new(0.08, h % 3 == 0 and 0.36 or 0.2, 0.02), faceCF * CFrame.Angles(0, 0, math.rad(h * 30)) * CFrame.new(0, 1.35, 0), INK, Enum.Material.SmoothPlastic, DECOR)
		end
		hand("HourHand", 1.0, 0.14, 96.5, INK, 0.02)
		hand("MinuteHand", 1.4, 0.09, 78, INK, 0.04)
		hand("SecondHand", 1.45, 0.04, 200, rgb(190, 30, 30), 0.06)
		local mat = facing(m, "VisitorBoard", Vector3.new(6, 1.2, 0.05), Vector3.new(0, 11.8, z1 - 0.06), Vector3.new(0, 0, -1), TEAL_DARK, Enum.Material.SmoothPlastic, DECOR)
		lib.sign(mat, "MAIN ENTRANCE", { Color = rgb(244, 240, 228), Font = Enum.Font.GothamBold, LightInfluence = 0.3 })
	end
	-- brusautomat og vannkjøler i sørvest
	do
		local m = lib.new("Model", { Name = "Vending" }, props)
		local vx, vz = -38, z1 - 2
		box(m, "Body", vx - 2.6, 0, vz - 1.6, vx + 2.6, 9, vz + 1.6, rgb(150, 30, 36), Enum.Material.SmoothPlastic)
		local glass = facing(m, "Window", Vector3.new(3.4, 6, 0.04), Vector3.new(vx - 0.6, 5.2, vz - 1.62), Vector3.new(0, 0, -1), rgb(230, 240, 250), Enum.Material.Neon, DECOR)
		box(m, "WindowGlass", vx - 2.3, 2.2, vz - 1.8, vx + 1.1, 8.2, vz - 1.76, rgb(220, 236, 245), Enum.Material.Glass, { Transparency = 0.75, CastShadow = false })
		lib.new("PointLight", { Range = 10, Brightness = 0.7, Color = rgb(220, 236, 255) }, glass)
		local snack = { rgb(230, 60, 40), rgb(250, 200, 60), rgb(60, 130, 220), rgb(80, 180, 90), rgb(240, 130, 40) }
		for r = 0, 4 do
			for c = 0, 3 do
				box(m, "Snack", vx - 2.1 + c * 0.8, 2.7 + r * 1.15, vz - 1.72, vx - 1.5 + c * 0.8, 3.4 + r * 1.15, vz - 1.64, snack[(r + c) % #snack + 1], Enum.Material.SmoothPlastic, DECOR)
			end
		end
		box(m, "KeyPad", vx + 1.4, 4.5, vz - 1.66, vx + 2.2, 6.5, vz - 1.6, rgb(30, 30, 32), Enum.Material.SmoothPlastic, DECOR)
		box(m, "Slot", vx - 2.2, 0.8, vz - 1.66, vx + 1.0, 1.8, vz - 1.6, rgb(20, 20, 22), Enum.Material.SmoothPlastic, DECOR)
		local top = facing(m, "Brand", Vector3.new(4.8, 0.7, 0.04), Vector3.new(vx, 8.6, vz - 1.62), Vector3.new(0, 0, -1), rgb(150, 30, 36), Enum.Material.SmoothPlastic, DECOR)
		lib.sign(top, "COLD DRINKS", { Color = rgb(255, 240, 230), Font = Enum.Font.GothamBold, Brightness = 1.4 })

		local wx, wz = -31.5, z1 - 1.5
		box(m, "CoolerBody", wx - 0.9, 0, wz - 0.9, wx + 0.9, 3.6, wz + 0.9, POT_WHITE, Enum.Material.SmoothPlastic)
		box(m, "CoolerTap", wx - 0.2, 2.6, wz - 1.0, wx + 0.2, 2.9, wz - 0.9, rgb(70, 120, 200), Enum.Material.SmoothPlastic, DECOR)
		lib.cylinderY(m, "Bottle", 1.5, 2.2, CFrame.new(wx, 4.7, wz), rgb(140, 190, 230), Enum.Material.Glass, { Transparency = 0.35 })
		lib.cylinderY(m, "Cups", 0.4, 1.2, CFrame.new(wx + 1.2, 2.6, wz - 0.4), rgb(244, 244, 240), Enum.Material.SmoothPlastic, DECOR)
	end

	-- akvarium i sørøst (alle fiskene svømmer... nesten)
	do
		local m = lib.new("Model", { Name = "FishTank" }, props)
		local tx, tz = 27, z1 - 1.6
		box(m, "Cabinet", tx - 4, 0, tz - 1.4, tx + 4, 3.2, tz + 1.4, WALNUT, Enum.Material.Wood)
		box(m, "CabinetTop", tx - 4.1, 3.2, tz - 1.5, tx + 4.1, 3.4, tz + 1.5, TRIM, Enum.Material.Wood)
		box(m, "Gravel", tx - 3.7, 3.4, tz - 1.1, tx + 3.7, 3.8, tz + 1.1, rgb(196, 176, 140), Enum.Material.Sand, DECOR)
		local water = box(m, "Water", tx - 3.7, 3.8, tz - 1.1, tx + 3.7, 6.6, tz + 1.1, rgb(70, 150, 190), Enum.Material.Glass, { Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false })
		lib.new("PointLight", { Range = 9, Brightness = 0.8, Color = rgb(110, 190, 230) }, water)
		box(m, "Glass", tx - 3.8, 3.4, tz - 1.2, tx + 3.8, 7.0, tz + 1.2, rgb(220, 240, 245), Enum.Material.Glass, { Transparency = 0.85 })
		box(m, "Lid", tx - 3.9, 7.0, tz - 1.3, tx + 3.9, 7.25, tz + 1.3, rgb(30, 30, 32), Enum.Material.SmoothPlastic)
		for i = 1, 4 do
			local h = 1.2 + rng() * 1.4
			lib.part(m, "Weed", Vector3.new(0.12, h, 0.4), CFrame.new(tx - 3 + i * 1.4, 3.8 + h / 2, tz + 0.5) * CFrame.Angles(0, rng(), (rng() - 0.5) * 0.3), rgb(70, 150, 80), Enum.Material.SmoothPlastic, DECOR)
		end
		local fish = { Vector3.new(tx - 2, 5.2, tz - 0.3), Vector3.new(tx - 0.4, 4.6, tz + 0.2), Vector3.new(tx + 1.3, 5.6, tz - 0.4), Vector3.new(tx + 2.4, 4.9, tz) }
		for i, p in fish do
			local cf = CFrame.new(p) * CFrame.Angles(0, (i % 2) * math.pi, 0)
			lib.ellipsoid(m, "Fish", Vector3.new(0.5, 0.26, 0.14), cf, rgb(250, 140, 40), Enum.Material.SmoothPlastic)
			lib.part(m, "Tail", Vector3.new(0.18, 0.2, 0.04), cf * CFrame.new(0.3, 0, 0), rgb(250, 160, 60), Enum.Material.SmoothPlastic, DECOR)
		end
		-- og én som flyter med magen opp
		local deadCf = CFrame.new(tx + 0.6, 6.5, tz + 0.4) * CFrame.Angles(math.pi, 0.4, 0)
		lib.ellipsoid(m, "Fish", Vector3.new(0.5, 0.26, 0.14), deadCf, rgb(236, 200, 170), Enum.Material.SmoothPlastic)
	end

	-- stoler langs sørveggen, mellom døra og akvariet / automaten
	do
		local function wallChairs(cx: number, count: number)
			seatRow(cx, z1 - 1.9, true, count)
		end
		wallChairs(-19, 4)
		wallChairs(15, 4)
		ficus(Vector3.new(-26, 0, z1 - 2.5))
		snakePlant(Vector3.new(-9, 0, z1 - 2), 0.9)
		snakePlant(Vector3.new(9, 0, z1 - 2), 0.9)
		ficus(Vector3.new(-44.5, 0, z1 - 3))
	end

	------------------------------------------------------------------
	-- Rolige bilder på veggene (ett av dem henger litt skjevt)
	------------------------------------------------------------------
	local function painting(pos: any, normal: any, w: number, h: number, kind: string, tilt: number?)
		local m = lib.new("Model", { Name = "Painting" }, props)
		local base = lib.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, math.rad(tilt or 0))
		lib.part(m, "Frame", Vector3.new(w + 0.5, h + 0.5, 0.16), base * CFrame.new(0, 0, 0.08), WALNUT, Enum.Material.Wood, DECOR)
		local canvas = lib.part(m, "Canvas", Vector3.new(w, h, 0.04), base * CFrame.new(0, 0, -0.02), CREAM_PAPER, Enum.Material.SmoothPlastic, DECOR)
		local g = gui(canvas, nil, 1)
		if kind == "lake" then
			frame(g, 0.5, 0.2, 1, 0.4, rgb(244, 200, 150))
			frame(g, 0.5, 0.45, 1, 0.12, rgb(236, 170, 130))
			local sun = frame(g, 0.62, 0.42, 0.16, 0.16 * w / h, rgb(250, 236, 200))
			lib.new("UICorner", { CornerRadius = lib.UDim.new(0.5, 0) }, sun)
			frame(g, 0.5, 0.56, 1, 0.08, rgb(52, 82, 60))
			frame(g, 0.5, 0.8, 1, 0.4, rgb(96, 140, 160))
			frame(g, 0.62, 0.68, 0.1, 0.012, rgb(250, 236, 200))
			frame(g, 0.62, 0.73, 0.14, 0.012, rgb(240, 220, 190))
			frame(g, 0.62, 0.78, 0.08, 0.012, rgb(230, 210, 180))
		elseif kind == "fields" then
			frame(g, 0.5, 0.25, 1, 0.5, rgb(178, 210, 222))
			frame(g, 0.3, 0.62, 0.9, 0.3, rgb(128, 168, 96))
			frame(g, 0.75, 0.66, 0.7, 0.25, rgb(170, 186, 104))
			frame(g, 0.5, 0.88, 1, 0.24, rgb(206, 180, 100))
			local cloud = frame(g, 0.3, 0.2, 0.24, 0.08, rgb(248, 248, 244))
			lib.new("UICorner", { CornerRadius = lib.UDim.new(0.5, 0) }, cloud)
		else -- blokker i varme farger
			frame(g, 0.5, 0.5, 1, 1, rgb(232, 222, 196))
			frame(g, 0.3, 0.32, 0.36, 0.44, rgb(196, 110, 58))
			frame(g, 0.66, 0.6, 0.4, 0.5, TEAL)
			local dot = frame(g, 0.72, 0.28, 0.18, 0.18 * w / h, rgb(236, 192, 110))
			lib.new("UICorner", { CornerRadius = lib.UDim.new(0.5, 0) }, dot)
		end
		return m
	end
	painting(Vector3.new(-19, 9.6, z1 - 0.1), Vector3.new(0, 0, -1), 7, 4.4, "lake")
	painting(Vector3.new(15, 9.6, z1 - 0.1), Vector3.new(0, 0, -1), 7, 4.4, "fields", 2.5)
	painting(Vector3.new(x0 + 0.1, 9.4, -175.5), Vector3.new(1, 0, 0), 5, 6, "blocks")
	painting(Vector3.new(x1 - 0.1, 9.4, -172), Vector3.new(-1, 0, 0), 4.2, 5.2, "lake")

	------------------------------------------------------------------
	-- Spawn: dørmatte innenfor inngangen
	------------------------------------------------------------------
	if spawnLocation then
		for _, c in spawnLocation:GetChildren() do
			c.Parent = nil
		end
		spawnLocation.Size = Vector3.new(12, 0.2, 7)
		spawnLocation.CFrame = CFrame.new(0, 0.1, z1 - 6)
		spawnLocation.Color = TEAL_DARK
		spawnLocation.Material = Enum.Material.Fabric
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Duration = 0
		spawnLocation.Parent = lobby
	end

	return lobby
end
