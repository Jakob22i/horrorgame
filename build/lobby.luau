-- Bygger lobbyen: et dunkelt venterom med fire heiser langs nordveggen.
-- Hver heis tar maks 4 spillere og starter sitt eget skrekkspill.

local lib = require("./lib")
local Vector3, CFrame, Enum, UDim2 = lib.Vector3, lib.CFrame, lib.Enum, lib.UDim2
local rgb = lib.rgb

local CENTER_Z = -200
local HALF_X, HALF_Z = 48, 32
local HEIGHT = 20
local ELEVATOR_X = { -33, -11, 11, 33 }

local WALL = rgb(168, 152, 102)
local WALL_LOW = rgb(120, 98, 70)
local CARPET = rgb(104, 90, 66)
local CEIL = rgb(186, 180, 156)
local STEEL = rgb(132, 134, 138)
local DARK = rgb(52, 52, 56)

return function(parent: any, spawnLocation: any)
	local rng = lib.rng(777)
	local lobby = lib.new("Model", { Name = "Lobby" }, parent)
	local walls = lib.new("Folder", { Name = "Walls" }, lobby)
	local lamps = lib.new("Folder", { Name = "Lamps" }, lobby)
	local props = lib.new("Folder", { Name = "Props" }, lobby)
	local elevators = lib.new("Folder", { Name = "Elevators" }, lobby)

	local z0, z1 = CENTER_Z - HALF_Z, CENTER_Z + HALF_Z -- -232, -168
	local function box(parentObj: any, name: string, x1: number, y1: number, zA: number, x2: number, y2: number, zB: number, color: any, material: any?, extra: any?)
		local size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(zB - zA))
		local c = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (zA + zB) / 2)
		return lib.part(parentObj, name, size, CFrame.new(c), color, material, extra)
	end

	-- Gulv og tak
	box(walls, "Floor", -HALF_X - 2, -1, z0 - 2, HALF_X + 2, 0, z1 + 2, CARPET, Enum.Material.Carpet)
	box(walls, "Ceiling", -HALF_X - 2, HEIGHT, z0 - 2, HALF_X + 2, HEIGHT + 1, z1 + 2, CEIL, Enum.Material.Plaster)

	-- Vegger (to-farget: mørk nederst, gul tapet over)
	local function wall(x1: number, zA: number, x2: number, zB: number, yTop: number?, yBottom: number?)
		local top = yTop or HEIGHT
		local bottom = yBottom or 0
		if bottom < 3 then
			box(walls, "WallLow", x1, bottom, zA, x2, math.min(3, top), zB, WALL_LOW, Enum.Material.WoodPlanks)
			if top > 3 then
				box(walls, "Wall", x1, 3, zA, x2, top, zB, WALL, Enum.Material.Plaster)
			end
		else
			box(walls, "Wall", x1, bottom, zA, x2, top, zB, WALL, Enum.Material.Plaster)
		end
	end
	wall(-HALF_X - 2, z1, HALF_X + 2, z1 + 2) -- sør
	wall(-HALF_X - 2, z0 - 2, -HALF_X, z1) -- vest
	wall(HALF_X, z0 - 2, HALF_X + 2, z1) -- øst
	-- Nordveggen har åpninger til heisene
	local edges = { -HALF_X - 2 }
	for _, cx in ELEVATOR_X do
		table.insert(edges, cx - 5)
		table.insert(edges, cx + 5)
	end
	table.insert(edges, HALF_X + 2)
	for i = 1, #edges, 2 do
		wall(edges[i], z0 - 2, edges[i + 1], z0)
	end
	for _, cx in ELEVATOR_X do
		wall(cx - 5, z0 - 2, cx + 5, z0, HEIGHT, 12)
	end

	-- Stort skilt over heisene
	local bannerPos = Vector3.new(0, 17.8, z0 + 0.15)
	local banner = lib.part(walls, "Banner", Vector3.new(64, 2.6, 0.2), lib.lookAt(bannerPos, bannerPos + Vector3.new(0, 0, 1)), rgb(30, 26, 20), Enum.Material.SmoothPlastic)
	lib.sign(banner, "CHOOSE AN ELEVATOR  •  1–4 PLAYERS EACH", { Color = rgb(235, 220, 170), Font = Enum.Font.SpecialElite, LightInfluence = 0.4 })

	-- Heiser
	for index, cx in ELEVATOR_X do
		local m = lib.new("Model", { Name = "Elevator" .. index, Attributes = { Index = index } }, elevators)
		local back = z0 - 14 -- heisens bakvegg
		-- Heisvogna
		box(m, "CarFloor", cx - 7, -1, back - 1, cx + 7, 0, z0 - 2, DARK, Enum.Material.DiamondPlate)
		box(m, "CarCeiling", cx - 7, 12, back - 1, cx + 7, 13, z0 - 2, STEEL, Enum.Material.Metal)
		box(m, "CarBack", cx - 7, 0, back - 1, cx + 7, 12, back, STEEL, Enum.Material.Metal)
		box(m, "CarLeft", cx - 7, 0, back, cx - 6, 12, z0 - 2, STEEL, Enum.Material.Metal)
		box(m, "CarRight", cx + 6, 0, back, cx + 7, 12, z0 - 2, STEEL, Enum.Material.Metal)
		box(m, "Rail", cx - 5, 3.2, back, cx + 5, 3.5, back + 0.4, rgb(170, 160, 120), Enum.Material.Metal)
		local carLight = box(m, "CarLight", cx - 2, 11.8, back + 4, cx + 2, 12, back + 8, rgb(255, 240, 210), Enum.Material.Neon, { CanQuery = false })
		lib.new("PointLight", { Range = 14, Brightness = 0.9, Color = rgb(255, 225, 180) }, carLight)
		-- Knappepanel inne i heisen
		local bp = Vector3.new(cx + 5.85, 4.5, z0 - 4)
		local buttons = lib.part(m, "ButtonPanel", Vector3.new(1.2, 2.4, 0.1), lib.lookAt(bp, bp + Vector3.new(-1, 0, 0)), rgb(40, 40, 44), Enum.Material.Metal)
		lib.sign(buttons, "B\nB2\nB3", { Color = rgb(255, 120, 90), Font = Enum.Font.Code, Brightness = 2 })
		-- Bryter for vanskelighetsgrad på den andre veggen
		local mp = Vector3.new(cx - 5.85, 5, z0 - 4.5)
		local modePanel = lib.part(m, "ModePanel", Vector3.new(2.6, 2, 0.15), lib.lookAt(mp, mp + Vector3.new(1, 0, 0)), rgb(30, 28, 26), Enum.Material.Metal)
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

		-- Dører (står åpne i fila; serveren lukker dem når heisen går)
		local doorL = box(m, "DoorL", cx - 10, 0, z0 - 1.25, cx - 5, 12, z0 - 0.75, rgb(150, 152, 156), Enum.Material.Metal)
		doorL:SetAttribute("CloseOffset", 5)
		local doorR = box(m, "DoorR", cx + 5, 0, z0 - 1.25, cx + 10, 12, z0 - 0.75, rgb(150, 152, 156), Enum.Material.Metal)
		doorR:SetAttribute("CloseOffset", -5)

		-- Ramme
		box(m, "FrameL", cx - 5.6, 0, z0, cx - 5, 12.6, z0 + 0.3, rgb(170, 160, 120), Enum.Material.Metal)
		box(m, "FrameR", cx + 5, 0, z0, cx + 5.6, 12.6, z0 + 0.3, rgb(170, 160, 120), Enum.Material.Metal)
		box(m, "FrameTop", cx - 5.6, 12, z0, cx + 5.6, 12.6, z0 + 0.3, rgb(170, 160, 120), Enum.Material.Metal)

		-- Skilt med status
		local signPos = Vector3.new(cx, 14.5, z0 + 0.2)
		local sign = lib.part(m, "Sign", Vector3.new(9, 3.4, 0.25), lib.lookAt(signPos, signPos + Vector3.new(0, 0, 1)), rgb(18, 16, 14), Enum.Material.SmoothPlastic)
		local gui = lib.new("SurfaceGui", {
			Name = "SignGui",
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0,
			Brightness = 1.4,
		}, sign)
		local function label(name: string, y: number, h: number, text: string, color: any, font: any)
			return lib.new("TextLabel", {
				Name = name,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, y),
				Size = UDim2.fromScale(1, h),
				Text = text,
				TextScaled = true,
				TextColor3 = color,
				FontFace = lib.Font.fromEnum(font),
			}, gui)
		end
		label("Title", 0.03, 0.3, "ELEVATOR " .. index, rgb(255, 214, 120), Enum.Font.SpecialElite)
		label("Mode", 0.33, 0.2, "NORMAL", rgb(200, 220, 200), Enum.Font.SpecialElite)
		label("Status", 0.55, 0.2, "0/4 PLAYERS", rgb(220, 220, 210), Enum.Font.Code)
		label("Timer", 0.77, 0.2, "WAITING...", rgb(150, 230, 150), Enum.Font.Code)
		local indicator = lib.part(m, "Indicator", Vector3.new(0.8, 0.8, 0.2), CFrame.new(cx, 16.7, z0 + 0.2), rgb(80, 220, 100), Enum.Material.Neon, { CanQuery = false })
		lib.new("PointLight", { Range = 6, Brightness = 0.6, Color = rgb(80, 220, 100) }, indicator)

		-- Sone der spillere teller som "i heisen"
		lib.part(m, "Zone", Vector3.new(11, 10, 11), CFrame.new(cx, 5, z0 - 8), rgb(0, 200, 255), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		lib.marker(m, "ExitPoint", lib.lookAt(Vector3.new(cx, 3.2, z0 + 9), Vector3.new(cx, 3.2, z0 + 20)))
		lib.new("Sound", { Name = "DoorSound", RollOffMaxDistance = 60, Volume = 0.8 }, sign)
	end

	-- Lysrør i taket (noen blinker)
	local flickerIndex = { [2] = true, [9] = true }
	local n = 0
	for _, z in { -222, -204, -186 } do
		for _, x in { -36, -12, 12, 36 } do
			n += 1
			local m = lib.new("Model", { Name = "Lamp", Tags = { "Lamp" }, Attributes = { Mode = flickerIndex[n] and "dim" or "on" } }, lamps)
			box(m, "Housing", x - 2.2, HEIGHT - 0.2, z - 1, x + 2.2, HEIGHT, z + 1, DARK, Enum.Material.Metal, { CanQuery = false, CastShadow = false })
			local panel = box(m, "Panel", x - 2, HEIGHT - 0.35, z - 0.8, x + 2, HEIGHT - 0.2, z + 0.8, rgb(255, 244, 212), Enum.Material.Neon, { CanQuery = false, CastShadow = false })
			lib.new("PointLight", { Name = "Light", Range = 26, Brightness = 0.9, Color = rgb(255, 230, 180), Shadows = true }, panel)
		end
	end

	-- Stoler langs øst- og vestveggen
	local function chair(pos: any, yaw: number)
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		local m = lib.new("Model", { Name = "Chair" }, props)
		lib.part(m, "Seat", Vector3.new(2.2, 0.3, 2.2), cf * CFrame.new(0, 1.9, 0), rgb(110, 60, 50), Enum.Material.Leather)
		lib.part(m, "Back", Vector3.new(2.2, 2.2, 0.3), cf * CFrame.new(0, 3.1, 1.0), rgb(110, 60, 50), Enum.Material.Leather)
		lib.part(m, "Base", Vector3.new(1.8, 1.75, 1.8), cf * CFrame.new(0, 0.9, 0), DARK, Enum.Material.Metal)
	end
	for z = -222, -186, 3 do
		chair(Vector3.new(HALF_X - 2, 0, z), math.pi / 2)
		chair(Vector3.new(-HALF_X + 2, 0, z + 1.5), -math.pi / 2)
	end

	-- Visne planter i hjørnene
	for _, p in { Vector3.new(-44, 0, -228), Vector3.new(44, 0, -228), Vector3.new(-44, 0, -172), Vector3.new(44, 0, -172) } do
		local m = lib.new("Model", { Name = "DeadPlant" }, props)
		lib.cylinderY(m, "Pot", 2.4, 2.4, CFrame.new(p + Vector3.new(0, 1.2, 0)), rgb(90, 60, 45), Enum.Material.Concrete)
		for i = 1, 5 do
			lib.part(m, "Stick", Vector3.new(0.15, 3 + rng() * 2, 0.15), CFrame.new(p + Vector3.new(0, 3.6, 0)) * CFrame.Angles((rng() - 0.5) * 0.8, 0, (rng() - 0.5) * 0.8), rgb(70, 52, 38), Enum.Material.Wood)
		end
	end

	-- Resepsjonsdisk med TV som viser "INGEN SIGNAL"
	local deskCf = CFrame.new(-30, 0, -176)
	lib.part(props, "Desk", Vector3.new(12, 3.6, 3), deskCf * CFrame.new(0, 1.8, 0), rgb(84, 64, 48), Enum.Material.Wood)
	lib.part(props, "TV", Vector3.new(3, 2.6, 2.4), deskCf * CFrame.new(-3, 4.9, 0.2), rgb(46, 44, 42), Enum.Material.SmoothPlastic)
	local screen = lib.part(props, "TVScreen", Vector3.new(2.4, 1.9, 0.05), lib.lookAt((deskCf * CFrame.new(-3, 4.95, -1.03)).Position, (deskCf * CFrame.new(-3, 4.95, -5)).Position), rgb(20, 24, 40), Enum.Material.Glass)
	local _, tvLabel = lib.sign(screen, "NO\nSIGNAL", { Color = rgb(230, 230, 230), Font = Enum.Font.Code, Brightness = 2 })
	tvLabel.BackgroundTransparency = 0
	tvLabel.BackgroundColor3 = rgb(30, 40, 160)
	lib.new("PointLight", { Range = 8, Brightness = 0.7, Color = rgb(120, 140, 255) }, screen)

	-- Butikk for kosmetikk (mynter): lommelyktfarger og titler
	do
		local bx, bz = 22, z1 - 3.2
		local booth = lib.new("Model", { Name = "CosmeticsShop" }, props)
		box(booth, "Counter", bx - 7, 0, bz - 1.6, bx + 7, 3.8, bz + 1.6, rgb(60, 44, 34), Enum.Material.Wood)
		box(booth, "CounterTop", bx - 7.3, 3.8, bz - 1.9, bx + 7.3, 4.1, bz + 1.9, rgb(150, 120, 80), Enum.Material.Wood)
		box(booth, "BackWall", bx - 8, 0, z1 - 0.6, bx + 8, 13, z1, rgb(40, 30, 26), Enum.Material.WoodPlanks)
		-- lommelykter i ulike farger på hylla bak disken
		local colors = { rgb(255, 244, 220), rgb(215, 232, 255), rgb(130, 255, 140), rgb(255, 80, 66), rgb(110, 160, 255), rgb(190, 110, 255), rgb(255, 205, 90) }
		for i, c in colors do
			local x = bx - 6 + (i - 1) * 2
			box(booth, "Shelf", x - 0.9, 6.4, z1 - 1.6, x + 0.9, 6.6, z1 - 0.6, rgb(90, 70, 50), Enum.Material.Wood)
			lib.cylinderY(booth, "Torch", 0.45, 1.3, CFrame.new(x, 7.25, z1 - 1.1), rgb(40, 40, 44), Enum.Material.Metal)
			local lens = lib.cylinderY(booth, "Lens", 0.5, 0.1, CFrame.new(x, 7.95, z1 - 1.1), c, Enum.Material.Neon, { CanQuery = false })
			lib.new("PointLight", { Range = 5, Brightness = 0.8, Color = c }, lens)
		end
		local signPos = Vector3.new(bx, 10.8, z1 - 0.7)
		local sign = lib.part(booth, "ShopSign", Vector3.new(13, 2.4, 0.2), lib.lookAt(signPos, signPos - Vector3.new(0, 0, 1)), rgb(24, 20, 16), Enum.Material.SmoothPlastic)
		lib.sign(sign, "FLASHLIGHTS & TITLES", { Color = rgb(255, 214, 120), Font = Enum.Font.SpecialElite, Brightness = 1.4 })
		local light = lib.part(booth, "ShopLight", Vector3.new(1, 1, 1), CFrame.new(bx, 9, bz - 3), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
		lib.new("PointLight", { Range = 16, Brightness = 1.1, Color = rgb(255, 214, 150) }, light)
		local promptPart = lib.part(booth, "PromptPart", Vector3.new(1, 1, 1), CFrame.new(bx, 4.6, bz - 1.4), rgb(0, 0, 0), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
		lib.new("ProximityPrompt", {
			Name = "CosmeticsPrompt",
			ActionText = "Open shop",
			ObjectText = "Coins",
			HoldDuration = 0,
			MaxActivationDistance = 10,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.E,
		}, promptPart)
	end

	-- Klokke som har stoppet
	local clockPos = Vector3.new(0, 13, z1 - 0.15)
	local clock = lib.part(props, "Clock", Vector3.new(3, 3, 0.2), lib.lookAt(clockPos, clockPos - Vector3.new(0, 0, 1)), rgb(230, 226, 210), Enum.Material.SmoothPlastic)
	lib.sign(clock, "03:13", { Color = rgb(30, 20, 20), Font = Enum.Font.Code, LightInfluence = 1 })

	-- Regeltavle på vestveggen
	local boardPos = Vector3.new(-HALF_X + 0.15, 9.2, -197)
	local board = lib.part(props, "RulesBoard", Vector3.new(16, 9, 0.2), lib.lookAt(boardPos, boardPos + Vector3.new(1, 0, 0)), rgb(26, 30, 24), Enum.Material.SmoothPlastic)
	local boardGui = lib.new("SurfaceGui", {
		Name = "SignGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0.3,
	}, board)
	lib.new("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.06),
		Size = UDim2.fromScale(0.88, 0.88),
		Text = "HOW TO PLAY\n\n• Step into an elevator (max 4 per elevator)\n• Find 5 keys hidden in the hospital\n• Bring them to the EMERGENCY EXIT\n• Hide in the lockers when it comes\n• You have 3 lives. If you die, you drop your keys\n• Friends can help you up when you are down\n• Press E on the panel in the elevator for NIGHTMARE\n\nHOLD SHIFT TO RUN (watch your stamina)\n1 = flashlight    E = use / hide",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rgb(225, 225, 205),
		FontFace = lib.Font.fromEnum(Enum.Font.SpecialElite),
	}, boardGui)

	-- Spawn-matte foran heisene
	if spawnLocation then
		for _, c in spawnLocation:GetChildren() do
			c.Parent = nil
		end
		spawnLocation.Size = Vector3.new(12, 0.2, 8)
		spawnLocation.CFrame = CFrame.new(0, 0.1, z1 - 8)
		spawnLocation.Color = rgb(60, 48, 40)
		spawnLocation.Material = Enum.Material.Fabric
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Duration = 0
		spawnLocation.Parent = lobby
	end

	return lobby
end
