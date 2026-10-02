-- Bygger sykehuskartet (malen som klones for hver runde).
-- Kartet er et rutenett der hver rute er 4x4 studs. '#' = vegg, '.' = gulv.
-- Origo (0, 0, 0) er nordvestre hjørne, gulvet ligger på y = 0.

local lib = require("./lib")
local Vector3, CFrame, Enum = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb

local CELL = 4
local W, H = 88, 56
local WALL_H = 14
local DOOR_H = 12

local COLORS = {
	floor = rgb(140, 146, 136),
	wallLow = rgb(84, 110, 96),
	wallHigh = rgb(186, 174, 132),
	ceiling = rgb(112, 106, 86),
	metal = rgb(150, 152, 150),
	darkMetal = rgb(80, 84, 84),
	locker = rgb(70, 86, 82),
	wood = rgb(92, 70, 52),
	sheet = rgb(214, 214, 204),
	blood = rgb(70, 8, 10),
}

return function(parent: any)
	local rng = lib.rng(4242)
	local map = lib.new("Model", { Name = "HospitalTemplate" })
	map.WorldPivotData = CFrame.new(0, 0, 0)

	local folders = {}
	for _, n in { "Walls", "Floors", "Props", "Closets", "Lamps", "KeySpots", "SpawnPoints", "PatrolPoints", "Signs", "Decor" } do
		folders[n] = lib.new("Folder", { Name = n }, map)
	end

	------------------------------------------------------------------
	-- Rutenett
	------------------------------------------------------------------
	local grid = {}
	for y = 0, H - 1 do
		grid[y] = {}
		for x = 0, W - 1 do
			grid[y][x] = "#"
		end
	end
	local occupied = {} -- ruter med møbler (ingen patruljepunkter der)
	local function key(x: number, y: number)
		return y * 1000 + x
	end

	local function carve(x1: number, y1: number, x2: number, y2: number)
		for y = y1, y2 do
			for x = x1, x2 do
				grid[y][x] = "."
			end
		end
	end

	local function cellCenter(x: number, y: number, height: number?)
		return Vector3.new(x * CELL + CELL / 2, height or 0, y * CELL + CELL / 2)
	end

	-- Rom: id, navn, x1, y1, x2, y2, gulvfarge, gulvmateriale
	local rooms = {
		{ "R101", "PATIENT ROOM 101", 1, 1, 9, 10 },
		{ "R102", "PATIENT ROOM 102", 11, 1, 19, 10 },
		{ "STORAGE", "STORAGE", 21, 1, 28, 10, rgb(110, 108, 100), Enum.Material.Concrete },
		{ "R103", "PATIENT ROOM 103", 30, 1, 37, 10 },
		{ "CHILD", "PEDIATRICS", 39, 1, 47, 10, rgb(150, 120, 120), Enum.Material.CeramicTiles },
		{ "XRAY", "X-RAY", 49, 1, 58, 10, rgb(120, 126, 132), Enum.Material.CeramicTiles },
		{ "OR", "SURGERY", 5, 16, 17, 23, rgb(170, 182, 178), Enum.Material.CeramicTiles },
		{ "OFFICE", "OFFICE", 19, 16, 26, 23, rgb(78, 70, 62), Enum.Material.Carpet },
		{ "WARD", "WARD", 32, 16, 44, 23 },
		{ "MORGUE", "MORGUE", 46, 16, 54, 23, rgb(105, 110, 112), Enum.Material.Concrete },
		{ "BATH", "RESTROOM", 1, 29, 9, 38, rgb(176, 180, 176), Enum.Material.CeramicTiles },
		{ "R104", "PATIENT ROOM 104", 11, 29, 19, 38 },
		{ "RECEPTION", "RECEPTION", 21, 29, 38, 38, rgb(120, 118, 108), Enum.Material.Marble },
		{ "WAITING", "WAITING ROOM", 40, 29, 48, 38, rgb(90, 78, 64), Enum.Material.Carpet },
		{ "STAFF", "STAFF ROOM", 50, 29, 58, 38, rgb(118, 100, 80), Enum.Material.WoodPlanks },
		-- Østfløyen
		{ "ICU", "ICU", 64, 1, 74, 10, rgb(150, 168, 168), Enum.Material.CeramicTiles },
		{ "PHARMACY", "PHARMACY", 76, 1, 86, 10, rgb(132, 132, 120), Enum.Material.Marble },
		{ "ISO1", "ISOLATION 1", 64, 16, 68, 23, rgb(196, 190, 170), Enum.Material.Fabric },
		{ "ISO2", "ISOLATION 2", 70, 16, 74, 23, rgb(196, 190, 170), Enum.Material.Fabric },
		{ "ISO3", "ISOLATION 3", 76, 16, 80, 23, rgb(196, 190, 170), Enum.Material.Fabric },
		{ "ISO4", "ISOLATION 4", 82, 16, 86, 23, rgb(196, 190, 170), Enum.Material.Fabric },
		{ "CAFETERIA", "CAFETERIA", 64, 29, 77, 38, rgb(128, 116, 92), Enum.Material.CeramicTiles },
		{ "KITCHEN", "KITCHEN", 79, 29, 86, 38, rgb(150, 150, 146), Enum.Material.DiamondPlate },
		-- Sørfløyen
		{ "LAUNDRY", "LAUNDRY", 1, 44, 12, 54, rgb(150, 150, 140), Enum.Material.Concrete },
		{ "CHAPEL", "CHAPEL", 14, 44, 26, 54, rgb(96, 40, 40), Enum.Material.Carpet },
		{ "MAINT", "MAINTENANCE", 28, 44, 37, 54, rgb(96, 96, 92), Enum.Material.Concrete },
		{ "LAB", "LABORATORY", 39, 44, 51, 54, rgb(170, 180, 178), Enum.Material.CeramicTiles },
		{ "RECORDS", "RECORDS", 53, 44, 64, 54, rgb(110, 92, 74), Enum.Material.WoodPlanks },
		{ "DOCK", "LOADING DOCK", 66, 44, 86, 54, rgb(90, 90, 88), Enum.Material.Concrete },
	}
	local corridors = {
		{ 1, 12, 58, 14 }, -- nordre korridor
		{ 1, 25, 58, 27 }, -- søndre korridor
		{ 1, 15, 3, 24 }, -- vestre korridor
		{ 56, 15, 58, 24 }, -- østre korridor
		{ 28, 15, 30, 24 }, -- midtkorridor
		{ 59, 12, 86, 14 }, -- nordre korridor, østfløyen
		{ 59, 25, 86, 27 }, -- søndre korridor, østfløyen
		{ 60, 15, 62, 24 }, -- østre korridor, nord
		{ 60, 28, 62, 42 }, -- østre korridor, sør
		{ 1, 40, 86, 42 }, -- sørfløyens korridor
	}
	for _, c in corridors do
		carve(c[1], c[2], c[3], c[4])
	end
	for _, r in rooms do
		carve(r[3], r[4], r[5], r[6])
	end

	-- Døråpninger: x1, y1, x2, y2, skilttekst, retning mot korridoren (for skiltet)
	local doors = {
		{ 4, 11, 5, 11, "101", "S" },
		{ 14, 11, 15, 11, "102", "S" },
		{ 24, 11, 25, 11, "STORAGE", "S" },
		{ 33, 11, 34, 11, "103", "S" },
		{ 42, 11, 43, 11, "PEDIATRICS", "S" },
		{ 53, 11, 54, 11, "X-RAY", "S" },
		{ 20, 4, 20, 5 },
		{ 48, 6, 48, 7 },
		{ 10, 15, 11, 15, "SURGERY", "N" },
		{ 4, 19, 4, 20 },
		{ 27, 18, 27, 19, "OFFICE", "E" },
		{ 22, 24, 23, 24 },
		{ 37, 15, 38, 15, "WARD B", "N" },
		{ 31, 20, 31, 21 },
		{ 55, 19, 55, 20, "MORGUE", "E" },
		{ 49, 24, 50, 24, "MORGUE", "S" },
		{ 4, 28, 5, 28, "RESTROOM", "N" },
		{ 14, 28, 15, 28, "104", "N" },
		{ 27, 28, 32, 28, "RECEPTION", "N" },
		{ 43, 28, 44, 28, "WAITING", "N" },
		{ 39, 33, 39, 34 },
		{ 53, 28, 54, 28, "STAFF ONLY", "N" },
		-- Østfløyen
		{ 68, 11, 69, 11, "ICU", "S" },
		{ 80, 11, 81, 11, "PHARMACY", "S" },
		{ 75, 5, 75, 5 },
		{ 66, 15, 66, 15, "ISO 1", "N" },
		{ 72, 15, 72, 15, "ISO 2", "N" },
		{ 78, 15, 78, 15, "ISO 3", "N" },
		{ 84, 15, 84, 15, "ISO 4", "N" },
		{ 70, 28, 71, 28, "CAFETERIA", "N" },
		{ 63, 33, 63, 34, "CAFETERIA", "W" },
		{ 82, 28, 82, 28, "KITCHEN", "N" },
		{ 78, 33, 78, 33 },
		-- Sørfløyen (den gamle utgangen er nå gangen dit)
		{ 28, 39, 31, 39, "SOUTH WING", "S" },
		{ 6, 43, 7, 43, "LAUNDRY", "N" },
		{ 19, 43, 21, 43, "CHAPEL", "N" },
		{ 32, 43, 32, 43, "MAINT.", "N" },
		{ 44, 43, 45, 43, "LAB", "N" },
		{ 52, 49, 52, 49 },
		{ 58, 43, 59, 43, "RECORDS", "N" },
		{ 70, 43, 72, 43, "LOADING DOCK", "N" },
	}
	for _, d in doors do
		carve(d[1], d[2], d[3], d[4])
	end

	-- Utgangen (spesialbygd dør i ytterveggen)
	local EXIT_X1, EXIT_X2, EXIT_Y = 77, 80, 55
	for x = EXIT_X1, EXIT_X2 do
		grid[EXIT_Y][x] = "E"
	end

	local function isWall(x: number, y: number)
		if x < 0 or y < 0 or x >= W or y >= H then
			return true
		end
		return grid[y][x] == "#" or grid[y][x] == "E"
	end

	-- Finn nærmeste vegg rundt en rute (for skap, hyller osv.)
	local DIRS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
	local function wallDir(x: number, y: number, prefer: string?)
		local order = DIRS
		if prefer == "N" then
			order = { { 0, -1 } }
		elseif prefer == "S" then
			order = { { 0, 1 } }
		elseif prefer == "W" then
			order = { { -1, 0 } }
		elseif prefer == "E" then
			order = { { 1, 0 } }
		end
		for _, d in order do
			if isWall(x + d[1], y + d[2]) then
				return Vector3.new(d[1], 0, d[2])
			end
		end
		return nil
	end

	-- CFrame for noe som står med ryggen mot veggen i retning d (ser bort fra veggen)
	local function againstWall(x: number, y: number, depth: number, prefer: string?)
		local d = wallDir(x, y, prefer) or Vector3.new(0, 0, -1)
		local c = cellCenter(x, y) + d * (CELL / 2 - depth / 2)
		return lib.lookAt(c, c - d), d
	end

	------------------------------------------------------------------
	-- Gulv, tak og vegger
	------------------------------------------------------------------
	lib.part(folders.Floors, "Floor", Vector3.new(W * CELL, 1, H * CELL), CFrame.new(W * CELL / 2, -0.5, H * CELL / 2), COLORS.floor, Enum.Material.CeramicTiles)
	lib.part(folders.Floors, "Ceiling", Vector3.new(W * CELL, 1, H * CELL), CFrame.new(W * CELL / 2, WALL_H + 0.5, H * CELL / 2), COLORS.ceiling, Enum.Material.Plaster)

	for _, r in rooms do
		if r[7] then
			local x1, y1, x2, y2 = r[3], r[4], r[5], r[6]
			local sx, sz = (x2 - x1 + 1) * CELL, (y2 - y1 + 1) * CELL
			lib.part(folders.Floors, r[1] .. "_Floor", Vector3.new(sx, 0.1, sz), CFrame.new(x1 * CELL + sx / 2, 0.05, y1 * CELL + sz / 2), r[7], r[8])
		end
	end

	-- Slå sammen veggruter til store rektangler (færre deler)
	local used = {}
	local wallCount = 0
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if grid[y][x] == "#" and not used[key(x, y)] then
				local w = 1
				while x + w < W and grid[y][x + w] == "#" and not used[key(x + w, y)] do
					w += 1
				end
				local h = 1
				while y + h < H do
					local ok = true
					for xx = x, x + w - 1 do
						if grid[y + h][xx] ~= "#" or used[key(xx, y + h)] then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					h += 1
				end
				for yy = y, y + h - 1 do
					for xx = x, x + w - 1 do
						used[key(xx, yy)] = true
					end
				end
				local sx, sz = w * CELL, h * CELL
				local cx, cz = x * CELL + sx / 2, y * CELL + sz / 2
				lib.part(folders.Walls, "WallLow", Vector3.new(sx, 4, sz), CFrame.new(cx, 2, cz), COLORS.wallLow, Enum.Material.CeramicTiles)
				lib.part(folders.Walls, "WallHigh", Vector3.new(sx, WALL_H - 4, sz), CFrame.new(cx, 4 + (WALL_H - 4) / 2, cz), COLORS.wallHigh, Enum.Material.Plaster)
				wallCount += 1
			end
		end
	end

	-- Overligger over dørene + skilt
	for _, d in doors do
		local x1, y1, x2, y2 = d[1], d[2], d[3], d[4]
		local sx, sz = (x2 - x1 + 1) * CELL, (y2 - y1 + 1) * CELL
		local cx, cz = x1 * CELL + sx / 2, y1 * CELL + sz / 2
		lib.part(folders.Walls, "Header", Vector3.new(sx, WALL_H - DOOR_H, sz), CFrame.new(cx, DOOR_H + (WALL_H - DOOR_H) / 2, cz), COLORS.wallHigh, Enum.Material.Plaster)
		if d[5] then
			local dir = ({ N = Vector3.new(0, 0, -1), S = Vector3.new(0, 0, 1), W = Vector3.new(-1, 0, 0), E = Vector3.new(1, 0, 0) })[d[6]]
			local depth = (dir.X ~= 0) and sx or sz
			local pos = Vector3.new(cx, DOOR_H + 1, cz) + dir * (depth / 2 + 0.06)
			local signWidth = math.min(7, ((dir.X ~= 0) and sz or sx) - 0.6)
			local plate = lib.part(folders.Signs, "DoorSign", Vector3.new(signWidth, 1.5, 0.1), lib.lookAt(pos, pos + dir), rgb(28, 40, 34), Enum.Material.SmoothPlastic)
			lib.sign(plate, d[5], { Color = rgb(200, 215, 200), Font = Enum.Font.SpecialElite, Brightness = 0.6, LightInfluence = 0.6 })
		end
	end

	------------------------------------------------------------------
	-- Møbler
	------------------------------------------------------------------
	local function occupy(x: number, y: number)
		occupied[key(x, y)] = true
	end

	local function bed(x: number, y: number, horizontal: boolean, gurney: boolean?)
		occupy(x, y)
		local cx, cy = x, y
		if horizontal then
			occupy(x + 1, y)
		else
			occupy(x, y + 1)
		end
		local c = cellCenter(cx, cy) + (horizontal and Vector3.new(CELL / 2, 0, 0) or Vector3.new(0, 0, CELL / 2))
		local cf = CFrame.new(c) * (horizontal and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new())
		local m = lib.new("Model", { Name = gurney and "Gurney" or "Bed" }, folders.Props)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				lib.part(m, "Leg", Vector3.new(0.25, 2, 0.25), cf * CFrame.new(sx * 1.45, 1, sz * 3.2), COLORS.metal, Enum.Material.Metal)
			end
		end
		lib.part(m, "Frame", Vector3.new(3.4, 0.3, 7.2), cf * CFrame.new(0, 2.1, 0), COLORS.metal, Enum.Material.Metal)
		if gurney then
			lib.part(m, "Sheet", Vector3.new(3.3, 0.3, 7.0), cf * CFrame.new(0, 2.4, 0), COLORS.sheet, Enum.Material.Fabric)
			-- noe ligger under lakenet...
			lib.ellipsoid(m, "Body", Vector3.new(2.2, 1.1, 5.6), cf * CFrame.new(0, 2.85, 0.2), COLORS.sheet, Enum.Material.Fabric)
			lib.ellipsoid(m, "BodyHead", Vector3.new(1.3, 1.1, 1.4), cf * CFrame.new(0, 2.95, 3.0), COLORS.sheet, Enum.Material.Fabric)
		else
			lib.part(m, "Mattress", Vector3.new(3.2, 0.7, 6.8), cf * CFrame.new(0, 2.6, 0), rgb(205, 205, 195), Enum.Material.Fabric)
			lib.part(m, "Pillow", Vector3.new(2.4, 0.45, 1.2), cf * CFrame.new(0, 3.15, 2.8), rgb(230, 230, 224), Enum.Material.Fabric)
			lib.part(m, "Blanket", Vector3.new(3.3, 0.25, 4.0), cf * CFrame.new(0, 3.0, -1.2), rgb(120, 140, 150), Enum.Material.Fabric)
			lib.part(m, "Headboard", Vector3.new(3.4, 2.4, 0.2), cf * CFrame.new(0, 3.2, 3.55), COLORS.metal, Enum.Material.Metal)
			lib.part(m, "Footboard", Vector3.new(3.4, 1.4, 0.2), cf * CFrame.new(0, 2.7, -3.55), COLORS.metal, Enum.Material.Metal)
		end
	end

	local function shelf(x: number, y: number, prefer: string?)
		occupy(x, y)
		local cf = againstWall(x, y, 1.6, prefer)
		local m = lib.new("Model", { Name = "Shelf" }, folders.Props)
		for _, sx in { -1, 1 } do
			lib.part(m, "Post", Vector3.new(0.2, 9, 1.6), cf * CFrame.new(sx * 1.7, 4.5, 0), COLORS.darkMetal, Enum.Material.Metal)
		end
		for i = 0, 3 do
			local h = 0.4 + i * 2.6
			lib.part(m, "Board", Vector3.new(3.4, 0.15, 1.5), cf * CFrame.new(0, h, 0), COLORS.darkMetal, Enum.Material.Metal)
			-- tilfeldige esker og flasker
			local n = rng(0, 3)
			for j = 1, n do
				local bw = 0.6 + rng() * 0.6
				local bh = 0.5 + rng() * 1.0
				lib.part(m, "Box", Vector3.new(bw, bh, 0.8 + rng() * 0.5), cf * CFrame.new(-1.3 + j * 0.8, h + bh / 2 + 0.08, 0) * CFrame.Angles(0, (rng() - 0.5) * 0.6, 0), rgb(150 + rng(0, 40), 130 + rng(0, 30), 100 + rng(0, 30)), Enum.Material.Cardboard, { CanQuery = false })
			end
		end
	end

	local function cabinet(x: number, y: number)
		-- Nattbord der nøkler kan ligge
		occupy(x, y)
		local cf = againstWall(x, y, 2.0)
		local m = lib.new("Model", { Name = "Cabinet" }, folders.Props)
		lib.part(m, "Body", Vector3.new(2.4, 2.8, 2.0), cf * CFrame.new(0, 1.4, 0), rgb(120, 112, 100), Enum.Material.Wood)
		lib.part(m, "Drawer", Vector3.new(2.0, 0.8, 0.1), cf * CFrame.new(0, 2.0, -1.03), rgb(100, 92, 82), Enum.Material.Wood)
		lib.part(m, "Knob", Vector3.new(0.3, 0.2, 0.15), cf * CFrame.new(0, 2.0, -1.12), COLORS.metal, Enum.Material.Metal)
		return cf * CFrame.new(0, 2.95, -0.1)
	end

	local function desk(x: number, y: number, withMonitor: boolean?, prefer: string?)
		occupy(x, y)
		local cf = againstWall(x, y, 2.4, prefer)
		local m = lib.new("Model", { Name = "Desk" }, folders.Props)
		lib.part(m, "Top", Vector3.new(3.8, 0.25, 2.4), cf * CFrame.new(0, 3.0, 0), COLORS.wood, Enum.Material.Wood)
		for _, sx in { -1, 1 } do
			lib.part(m, "Side", Vector3.new(0.2, 2.9, 2.3), cf * CFrame.new(sx * 1.75, 1.45, 0), COLORS.wood, Enum.Material.Wood)
		end
		if withMonitor then
			lib.part(m, "Monitor", Vector3.new(1.8, 1.5, 1.6), cf * CFrame.new(0, 3.9, 0.2), rgb(190, 184, 166), Enum.Material.SmoothPlastic)
			local screen = lib.part(m, "Screen", Vector3.new(1.4, 1.1, 0.05), cf * CFrame.new(0, 3.95, -0.62), rgb(20, 40, 30), Enum.Material.Glass)
			lib.sign(screen, "> _", { Color = rgb(90, 200, 120), Font = Enum.Font.Code, Brightness = 1.5 })
		end
		for i = 1, rng(1, 3) do
			lib.part(m, "Paper", Vector3.new(0.9, 0.03, 1.2), cf * CFrame.new(-1.2 + i * 0.6, 3.14, (rng() - 0.5) * 1.2) * CFrame.Angles(0, rng() * 3, 0), rgb(225, 222, 205), Enum.Material.SmoothPlastic, { CanQuery = false })
		end
	end

	local function chair(x: number, y: number, yaw: number)
		occupy(x, y)
		local cf = CFrame.new(cellCenter(x, y)) * CFrame.Angles(0, yaw, 0)
		local m = lib.new("Model", { Name = "Chair" }, folders.Props)
		lib.part(m, "Seat", Vector3.new(1.8, 0.25, 1.8), cf * CFrame.new(0, 1.9, 0), rgb(60, 70, 78), Enum.Material.Fabric)
		lib.part(m, "Back", Vector3.new(1.8, 1.8, 0.2), cf * CFrame.new(0, 2.9, 0.85), rgb(60, 70, 78), Enum.Material.Fabric)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				lib.part(m, "Leg", Vector3.new(0.15, 1.8, 0.15), cf * CFrame.new(sx * 0.75, 0.9, sz * 0.75), COLORS.darkMetal, Enum.Material.Metal)
			end
		end
	end

	local function sink(x: number, y: number, prefer: string?)
		occupy(x, y)
		local cf = againstWall(x, y, 1.8, prefer)
		local m = lib.new("Model", { Name = "Sink" }, folders.Props)
		lib.part(m, "Basin", Vector3.new(2.6, 0.8, 1.8), cf * CFrame.new(0, 3.2, 0), rgb(220, 222, 218), Enum.Material.Marble)
		lib.part(m, "Pipe", Vector3.new(0.3, 2.8, 0.3), cf * CFrame.new(0, 1.4, 0.4), COLORS.metal, Enum.Material.Metal)
		lib.part(m, "Mirror", Vector3.new(2.6, 3.2, 0.1), cf * CFrame.new(0, 6.0, 0.85), rgb(160, 170, 170), Enum.Material.Glass, { Reflectance = 0.35 })
	end

	local function morgueDrawers(x: number, y: number, prefer: string?)
		occupy(x, y)
		local cf = againstWall(x, y, 2.2, prefer)
		local m = lib.new("Model", { Name = "MorgueDrawers" }, folders.Props)
		lib.part(m, "Body", Vector3.new(3.9, 8, 2.2), cf * CFrame.new(0, 4, 0), rgb(130, 134, 136), Enum.Material.Metal)
		for row = 0, 2 do
			for col = -1, 1, 2 do
				local p = cf * CFrame.new(col * 0.95, 1.5 + row * 2.4, -1.12)
				lib.part(m, "DrawerFront", Vector3.new(1.7, 2.0, 0.1), p, rgb(160, 164, 166), Enum.Material.Metal)
				lib.part(m, "Handle", Vector3.new(0.8, 0.15, 0.15), p * CFrame.new(0, 0.5, -0.1), COLORS.darkMetal, Enum.Material.Metal)
			end
		end
	end

	local function opTable(x: number, y: number)
		occupy(x, y)
		occupy(x + 1, y)
		local c = cellCenter(x, y) + Vector3.new(CELL / 2, 0, 0)
		local cf = CFrame.new(c) * CFrame.Angles(0, math.pi / 2, 0)
		local m = lib.new("Model", { Name = "OperatingTable" }, folders.Props)
		lib.part(m, "Pillar", Vector3.new(1.2, 2.6, 1.2), cf * CFrame.new(0, 1.3, 0), COLORS.metal, Enum.Material.Metal)
		lib.part(m, "Top", Vector3.new(2.8, 0.45, 7.2), cf * CFrame.new(0, 2.85, 0), rgb(70, 90, 92), Enum.Material.Leather)
		lib.part(m, "Stain", Vector3.new(1.6, 0.05, 2.2), cf * CFrame.new(0.2, 3.1, 0.6), COLORS.blood, Enum.Material.SmoothPlastic, { CanQuery = false })
		-- stor operasjonslampe i taket
		lib.cylinderY(m, "LampArm", 0.3, 3, CFrame.new(c + Vector3.new(0, WALL_H - 1.5, 0)), COLORS.metal, Enum.Material.Metal)
		lib.cylinderY(m, "LampDisc", 3.2, 0.6, CFrame.new(c + Vector3.new(0, WALL_H - 3.2, 0)), rgb(200, 200, 196), Enum.Material.Metal)
	end

	local function wheelchair(x: number, y: number, yaw: number)
		occupy(x, y)
		local cf = CFrame.new(cellCenter(x, y)) * CFrame.Angles(0, yaw, 0)
		local m = lib.new("Model", { Name = "Wheelchair" }, folders.Props)
		lib.part(m, "Seat", Vector3.new(1.8, 0.2, 1.8), cf * CFrame.new(0, 1.8, 0), rgb(40, 40, 44), Enum.Material.Leather)
		lib.part(m, "Back", Vector3.new(1.8, 1.8, 0.15), cf * CFrame.new(0, 2.8, 0.9), rgb(40, 40, 44), Enum.Material.Leather)
		for _, sx in { -1, 1 } do
			lib.part(m, "Wheel", Vector3.new(0.15, 2.4, 2.4), cf * CFrame.new(sx * 1.05, 1.2, 0.3), COLORS.darkMetal, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.4, 2.4) })
		end
	end

	local function tv(x: number, y: number, prefer: string?, text: string)
		occupy(x, y)
		local cf = againstWall(x, y, 2.4, prefer)
		local m = lib.new("Model", { Name = "TV" }, folders.Props)
		lib.part(m, "Stand", Vector3.new(3.2, 3.0, 2.2), cf * CFrame.new(0, 1.5, 0), COLORS.wood, Enum.Material.Wood)
		lib.part(m, "Box", Vector3.new(3.0, 2.6, 2.2), cf * CFrame.new(0, 4.3, 0), rgb(50, 48, 46), Enum.Material.SmoothPlastic)
		local screen = lib.part(m, "Screen", Vector3.new(2.4, 1.9, 0.05), cf * CFrame.new(0, 4.35, -1.12), rgb(30, 34, 36), Enum.Material.Glass)
		local gui, label = lib.sign(screen, text, { Color = rgb(225, 225, 225), Font = Enum.Font.Code, Brightness = 2 })
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = rgb(20, 22, 30)
		gui.Name = "TVScreen"
		lib.new("PointLight", { Range = 7, Brightness = 0.6, Color = rgb(170, 190, 255) }, screen)
	end

	-- Kirkebenk som spenner over flere ruter langs X, vendt mot sør (alteret)
	local function pew(x: number, y: number, len: number)
		for i = 0, len - 1 do
			occupy(x + i, y)
		end
		local c = cellCenter(x, y) + Vector3.new((len - 1) * CELL / 2, 0, 0)
		local cf = CFrame.new(c)
		local m = lib.new("Model", { Name = "Pew" }, folders.Props)
		local L = len * CELL - 0.6
		lib.part(m, "Seat", Vector3.new(L, 0.3, 1.6), cf * CFrame.new(0, 1.8, 0.2), COLORS.wood, Enum.Material.Wood)
		lib.part(m, "Back", Vector3.new(L, 2.2, 0.25), cf * CFrame.new(0, 3.0, -0.75), COLORS.wood, Enum.Material.Wood)
		for _, sx in { -1, 1 } do
			lib.part(m, "Side", Vector3.new(0.25, 2.8, 2.0), cf * CFrame.new(sx * L / 2, 1.4, 0), COLORS.wood, Enum.Material.Wood)
		end
	end

	-- Kafeteriabord over to ruter med fire krakker
	local function cafTable(x: number, y: number)
		occupy(x, y)
		occupy(x + 1, y)
		local c = cellCenter(x, y) + Vector3.new(CELL / 2, 0, 0)
		local cf = CFrame.new(c)
		local m = lib.new("Model", { Name = "CafeteriaTable" }, folders.Props)
		lib.part(m, "Top", Vector3.new(6.4, 0.25, 2.8), cf * CFrame.new(0, 3.0, 0), rgb(150, 140, 118), Enum.Material.SmoothPlastic)
		for _, sx in { -1, 1 } do
			lib.part(m, "Leg", Vector3.new(0.3, 2.9, 2.2), cf * CFrame.new(sx * 2.7, 1.45, 0), COLORS.darkMetal, Enum.Material.Metal)
			for _, sz in { -1, 1 } do
				local stool = cf * CFrame.new(sx * 1.6, 0, sz * 2.4)
				lib.cylinderY(m, "Stool", 1.2, 0.25, stool * CFrame.new(0, 1.9, 0), rgb(120, 40, 36), Enum.Material.SmoothPlastic)
				lib.cylinderY(m, "StoolLeg", 0.25, 1.8, stool * CFrame.new(0, 0.9, 0), COLORS.darkMetal, Enum.Material.Metal)
			end
		end
		-- skitne brett og kopper
		if rng() < 0.7 then
			lib.part(m, "Tray", Vector3.new(1.8, 0.1, 1.2), cf * CFrame.new((rng() - 0.5) * 3, 3.17, (rng() - 0.5) * 1), rgb(90, 110, 120), Enum.Material.SmoothPlastic, { CanQuery = false })
		end
	end

	-- Vaskemaskin mot veggen
	local function machine(x: number, y: number, prefer: string?)
		occupy(x, y)
		local cf = againstWall(x, y, 2.8, prefer)
		local m = lib.new("Model", { Name = "WashingMachine" }, folders.Props)
		lib.part(m, "Body", Vector3.new(3.2, 3.6, 2.8), cf * CFrame.new(0, 1.8, 0), rgb(210, 208, 198), Enum.Material.SmoothPlastic)
		lib.part(m, "Window", Vector3.new(0.12, 1.8, 1.8), cf * CFrame.new(0, 1.7, -1.42) * CFrame.Angles(0, math.pi / 2, 0), rgb(30, 34, 38), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder })
		lib.part(m, "Panel", Vector3.new(3.0, 0.5, 0.1), cf * CFrame.new(0, 3.3, -1.42), rgb(120, 120, 116), Enum.Material.SmoothPlastic)
	end

	-- Trekasser (en eller to i høyden)
	local function crate(x: number, y: number)
		occupy(x, y)
		local c = cellCenter(x, y)
		local m = lib.new("Model", { Name = "Crates" }, folders.Props)
		local h = 0
		for i = 1, rng(1, 2) do
			local size = 2.6 + rng() * 0.8
			lib.part(m, "Crate", Vector3.new(size, size, size), CFrame.new(c + Vector3.new((rng() - 0.5) * 0.4, h + size / 2, (rng() - 0.5) * 0.4)) * CFrame.Angles(0, rng() * 0.6, 0), rgb(124, 96, 62), Enum.Material.WoodPlanks)
			h += size
			local _ = i
		end
	end

	------------------------------------------------------------------
	-- Skap (gjemmesteder)
	------------------------------------------------------------------
	local function closet(x: number, y: number, prefer: string?)
		occupy(x, y)
		local cf = againstWall(x, y, 2.8, prefer)
		local m = lib.new("Model", { Name = "Closet", Tags = { "Closet" } }, folders.Closets)
		local col = COLORS.locker
		lib.part(m, "Back", Vector3.new(3.6, 8, 0.2), cf * CFrame.new(0, 4, 1.3), col, Enum.Material.Metal)
		for _, sx in { -1, 1 } do
			lib.part(m, "Side", Vector3.new(0.2, 8, 2.8), cf * CFrame.new(sx * 1.7, 4, 0), col, Enum.Material.Metal)
			lib.part(m, "Stile", Vector3.new(0.2, 8, 0.15), cf * CFrame.new(sx * 1.6, 4, -1.34), col, Enum.Material.Metal)
		end
		lib.part(m, "Top", Vector3.new(3.6, 0.2, 2.8), cf * CFrame.new(0, 8.1, 0), col, Enum.Material.Metal)
		lib.part(m, "Bottom", Vector3.new(3.6, 0.3, 2.8), cf * CFrame.new(0, 0.15, 0), col, Enum.Material.Metal)
		lib.part(m, "DoorTop", Vector3.new(3.2, 0.5, 0.15), cf * CFrame.new(0, 7.75, -1.34), col, Enum.Material.Metal)
		-- Spiler med mellomrom så man kan kikke ut
		for i = 0, 7 do
			lib.part(m, "Slat", Vector3.new(3.0, 0.5, 0.12), cf * CFrame.new(0, 0.6 + i * 0.92, -1.34), col, Enum.Material.Metal)
		end
		lib.part(m, "Handle", Vector3.new(0.15, 0.7, 0.15), cf * CFrame.new(1.15, 4, -1.48), COLORS.metal, Enum.Material.Metal)
		lib.marker(m, "HidePoint", cf * CFrame.new(0, 3.3, 0.15))
		lib.marker(m, "OutPoint", cf * CFrame.new(0, 3.2, -3.6))
		local promptPart = lib.marker(m, "PromptPart", cf * CFrame.new(0, 4, -1.5))
		lib.new("ProximityPrompt", {
			Name = "HidePrompt",
			ActionText = "Hide",
			ObjectText = "Locker",
			HoldDuration = 0,
			MaxActivationDistance = 7,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.E,
		}, promptPart)
	end

	------------------------------------------------------------------
	-- Nøkkelplasser (5 av disse velges tilfeldig hver runde)
	------------------------------------------------------------------
	local function keySpot(x: number, y: number, room: string)
		local top = cabinet(x, y)
		lib.marker(folders.KeySpots, "KeySpot", top * CFrame.Angles(0, rng() * math.pi * 2, 0), Vector3.new(0.4, 0.4, 0.4)):SetAttribute("Room", room)
	end

	------------------------------------------------------------------
	-- Lys i taket
	------------------------------------------------------------------
	local function lamp(x: number, y: number, offset: any?)
		local c = cellCenter(x, y, WALL_H) + (offset or Vector3.new(0, 0, 0))
		local m = lib.new("Model", { Name = "Lamp", Tags = { "Lamp" }, Attributes = { Mode = "on" } }, folders.Lamps)
		lib.part(m, "Housing", Vector3.new(3.6, 0.2, 1.6), CFrame.new(c - Vector3.new(0, 0.1, 0)), COLORS.darkMetal, Enum.Material.Metal, { CanQuery = false, CastShadow = false })
		local panel = lib.part(m, "Panel", Vector3.new(3.2, 0.12, 1.2), CFrame.new(c - Vector3.new(0, 0.26, 0)), rgb(255, 238, 190), Enum.Material.Neon, { CanQuery = false, CastShadow = false })
		-- bare noen lamper kaster skygge (mye raskere med et stort kart)
		lib.new("PointLight", { Name = "Light", Range = 18, Brightness = 1.15, Color = rgb(255, 226, 160), Shadows = rng() < 0.2 }, panel)
	end

	for _, r in rooms do
		local x1, y1, x2, y2 = r[3], r[4], r[5], r[6]
		local w, h = x2 - x1 + 1, y2 - y1 + 1
		if w >= 12 then
			lamp(x1 + math.floor(w / 4), y1 + math.floor(h / 2))
			lamp(x2 - math.floor(w / 4), y1 + math.floor(h / 2))
		elseif h >= 9 then
			lamp(x1 + math.floor(w / 2), y1 + math.floor(h / 4))
			lamp(x1 + math.floor(w / 2), y2 - math.floor(h / 4))
		else
			lamp(x1 + math.floor(w / 2), y1 + math.floor(h / 2))
		end
	end
	for _, c in corridors do
		local x1, y1, x2, y2 = c[1], c[2], c[3], c[4]
		if x2 - x1 > y2 - y1 then
			for x = x1 + 2, x2 - 1, 7 do
				lamp(x, y1 + 1)
			end
		else
			for y = y1 + 2, y2 - 1, 5 do
				lamp(x1 + 1, y)
			end
		end
	end

	------------------------------------------------------------------
	-- Plassering av møbler, skap og nøkkelplasser
	------------------------------------------------------------------
	-- Pasientrom 101
	bed(2, 1, false)
	bed(5, 1, false)
	bed(8, 1, false)
	keySpot(9, 6, "R101")
	closet(1, 9, "W")
	chair(6, 7, math.pi)
	-- Pasientrom 102
	bed(12, 1, false)
	bed(15, 1, false)
	bed(18, 1, false)
	keySpot(17, 8, "R102")
	closet(11, 9, "W")
	wheelchair(13, 7, 0.6)
	-- Lager
	for x = 21, 28, 2 do
		shelf(x, 1, "N")
	end
	shelf(21, 6, "W")
	shelf(21, 8, "W")
	shelf(28, 5, "E")
	keySpot(28, 9, "STORAGE")
	closet(28, 7, "E")
	-- Pasientrom 103
	bed(31, 1, false)
	bed(34, 1, false)
	keySpot(37, 9, "R103")
	closet(37, 1, "E")
	chair(32, 7, 0.3)
	-- Barneavdeling
	bed(40, 4, true)
	bed(44, 4, true)
	bed(40, 8, true)
	keySpot(41, 1, "CHILD")
	closet(47, 1, "E")
	tv(47, 9, "E", "WHERE IS\nMOMMY?")
	-- Røntgen
	desk(50, 1, true, "N")
	desk(52, 1, false, "N")
	shelf(58, 2, "E")
	shelf(58, 4, "E")
	keySpot(57, 10, "XRAY")
	closet(58, 7, "E")
	opTable(52, 6)
	-- Operasjon
	opTable(10, 19)
	shelf(5, 16, "W")
	shelf(17, 16, "E")
	keySpot(16, 23, "OR")
	closet(5, 23, "W")
	sink(7, 23, "S")
	-- Kontor
	desk(19, 17, true, "W")
	desk(19, 21, false, "W")
	shelf(26, 16, "E")
	shelf(26, 22, "E")
	keySpot(20, 23, "OFFICE")
	chair(21, 17, -math.pi / 2)
	-- Sengepost
	bed(33, 16, false)
	bed(36, 16, false)
	bed(40, 16, false)
	bed(33, 22, true)
	bed(40, 22, true)
	keySpot(43, 16, "WARD")
	closet(44, 19, "E")
	-- Likhus
	for x = 47, 53, 2 do
		morgueDrawers(x, 16, "N")
	end
	bed(48, 19, true, true)
	bed(51, 21, true, true)
	keySpot(46, 23, "MORGUE")
	closet(54, 23, "E")
	-- Toalett
	for _, x in { 2, 7, 9 } do
		sink(x, 29, "N")
	end
	keySpot(1, 37, "BATH")
	closet(9, 38, "E")
	closet(5, 38, "S")
	-- Pasientrom 104
	bed(12, 37, true)
	bed(17, 31, false)
	keySpot(19, 37, "R104")
	closet(11, 30, "W")
	-- Resepsjon (ingen nøkkel her, her starter dere)
	for x = 22, 26 do
		desk(x, 32, x == 24, "S")
	end
	tv(21, 29, "W", "ARE YOU\nSTILL\nTHERE?")
	closet(38, 29, "E")
	closet(21, 37, "W")
	-- Venterom
	for x = 41, 47, 2 do
		chair(x, 31, 0)
		chair(x, 35, 0)
	end
	keySpot(48, 38, "WAITING")
	closet(40, 38, "W")
	-- Personalrom
	desk(55, 33, false, "S")
	chair(55, 32, math.pi)
	sink(58, 31, "E")
	keySpot(51, 38, "STAFF")
	closet(58, 37, "E")
	-- Korridorer
	closet(8, 12, "N")
	closet(22, 14, "S")
	closet(46, 12, "N")
	closet(58, 17, "E")
	closet(1, 22, "W")
	closet(12, 27, "S")
	closet(36, 25, "N")
	closet(57, 27, "S")
	keySpot(58, 22, "EASTHALL")
	keySpot(1, 13, "WESTHALL")
	bed(18, 12, true, true)
	wheelchair(40, 26, 2.2)
	bed(2, 16, false)

	-- ÖSTFLØYEN ---------------------------------------------------
	-- Intensiv
	bed(65, 1, false)
	bed(68, 1, false)
	bed(71, 1, false)
	desk(67, 1, true, "N")
	keySpot(74, 9, "ICU")
	closet(64, 9, "W")
	wheelchair(72, 7, 1.0)
	-- Apotek
	for _, x in { 77, 79, 81, 83, 85 } do
		shelf(x, 1, "N")
	end
	shelf(86, 4, "E")
	shelf(86, 6, "E")
	desk(76, 7, true, "W")
	keySpot(86, 9, "PHARMACY")
	closet(77, 10, "S")
	-- Isolasjonsceller
	bed(64, 22, true)
	keySpot(68, 23, "ISO1")
	bed(73, 22, true)
	keySpot(70, 23, "ISO2")
	bed(76, 22, true)
	closet(80, 17, "E")
	bed(85, 22, true)
	keySpot(82, 23, "ISO4")
	-- Korridorer i østfløyen
	closet(62, 20, "E")
	closet(86, 13, "E")
	closet(86, 26, "E")
	keySpot(60, 35, "EASTHALL2")
	bed(74, 12, true, true)
	wheelchair(70, 26, 0.4)
	-- Kafeteria
	for _, row in { 31, 35 } do
		for _, x in { 65, 69, 73 } do
			cafTable(x, row)
		end
	end
	keySpot(77, 38, "CAFETERIA")
	closet(64, 38, "S")
	tv(77, 29, "E", "LUNCH IS\nSERVED")
	-- Kjøkken
	desk(79, 30, false, "W")
	desk(86, 31, false, "E")
	sink(86, 33, "E")
	sink(86, 35, "E")
	shelf(80, 38, "S")
	shelf(82, 38, "S")
	keySpot(85, 38, "KITCHEN")
	closet(86, 29, "N")

	-- SØRFLØYEN ---------------------------------------------------
	closet(10, 40, "N")
	closet(48, 40, "N")
	closet(86, 41, "E")
	closet(40, 42, "S")
	keySpot(1, 41, "SOUTHHALL")
	bed(20, 41, true, true)
	wheelchair(56, 40, 0.5)
	-- Vaskeri
	for _, yy in { 46, 48, 50 } do
		machine(1, yy, "W")
	end
	machine(12, 46, "E")
	machine(12, 48, "E")
	shelf(4, 54, "S")
	shelf(9, 54, "S")
	keySpot(12, 53, "LAUNDRY")
	closet(1, 53, "W")
	-- Kapell
	for _, yy in { 46, 48, 50 } do
		pew(15, yy, 4)
		pew(22, yy, 4)
	end
	desk(20, 54, false, "S")
	keySpot(26, 53, "CHAPEL")
	closet(14, 45, "W")
	-- Vedlikehold
	shelf(28, 46, "W")
	shelf(28, 48, "W")
	shelf(37, 46, "E")
	shelf(37, 50, "E")
	desk(30, 54, false, "S")
	crate(34, 52)
	crate(33, 48)
	keySpot(28, 53, "MAINT")
	closet(37, 53, "E")
	-- Laboratorium
	desk(39, 46, true, "W")
	desk(39, 50, true, "W")
	opTable(42, 48)
	opTable(46, 51)
	sink(51, 46, "E")
	shelf(51, 52, "E")
	keySpot(48, 54, "LAB")
	closet(51, 44, "N")
	-- Arkiv
	for _, yy in { 45, 47, 51 } do
		shelf(53, yy, "W")
	end
	for _, yy in { 45, 47, 49, 51 } do
		shelf(64, yy, "E")
	end
	for _, x in { 55, 57, 61 } do
		shelf(x, 54, "S")
	end
	keySpot(63, 54, "RECORDS")
	closet(53, 53, "W")
	-- Lasterampe (utgangen er i sørveggen her)
	for _, c in { { 68, 47 }, { 68, 48 }, { 74, 47 }, { 75, 47 }, { 83, 47 }, { 84, 50 }, { 70, 52 }, { 71, 52 }, { 85, 53 } } do
		crate(c[1], c[2])
	end
	for _, x in { 75, 77, 79 } do
		shelf(x, 44, "N")
	end
	keySpot(86, 45, "DOCK")
	closet(66, 53, "W")
	closet(86, 51, "E")

	------------------------------------------------------------------
	-- Startpunkter (resepsjonen) og utgangsdør
	------------------------------------------------------------------
	for i, x in { 28, 29, 30, 31 } do
		local c = cellCenter(x, 35, 3.2)
		lib.marker(folders.SpawnPoints, "Spawn" .. i, lib.lookAt(c, c + Vector3.new(0, 0, -1)))
	end

	local exitModel = lib.new("Model", { Name = "ExitDoor" }, map)
	local doorZ = EXIT_Y * CELL + CELL / 2
	local doorX1, doorX2 = EXIT_X1 * CELL, (EXIT_X2 + 1) * CELL
	local doorW = (doorX2 - doorX1) / 2
	local doorCX = (doorX1 + doorX2) / 2
	lib.part(exitModel, "Header", Vector3.new(doorX2 - doorX1, WALL_H - DOOR_H, CELL), CFrame.new(doorCX, DOOR_H + (WALL_H - DOOR_H) / 2, doorZ), COLORS.wallHigh, Enum.Material.Plaster)
	lib.part(exitModel, "DoorL", Vector3.new(doorW, DOOR_H, 1), CFrame.new(doorX1 + doorW / 2, DOOR_H / 2, doorZ), rgb(70, 74, 78), Enum.Material.DiamondPlate)
	lib.part(exitModel, "DoorR", Vector3.new(doorW, DOOR_H, 1), CFrame.new(doorX2 - doorW / 2, DOOR_H / 2, doorZ), rgb(70, 74, 78), Enum.Material.DiamondPlate)
	lib.part(exitModel, "Chain", Vector3.new(2.5, 3, 0.4), CFrame.new(doorCX, 5, doorZ - 0.7), rgb(60, 58, 55), Enum.Material.CorrodedMetal)
	-- 5 låselys over døra
	for i = 1, 5 do
		local lx = doorCX + (i - 3) * 2.2
		lib.part(exitModel, "Lock" .. i, Vector3.new(1.2, 1.2, 0.2), CFrame.new(lx, DOOR_H + 0.9, doorZ - CELL / 2 - 0.1), rgb(170, 20, 20), Enum.Material.Neon, { CanQuery = false })
	end
	local signPos = Vector3.new(doorCX, WALL_H - 0.8, doorZ - 6)
	lib.part(exitModel, "SignRod", Vector3.new(0.15, 0.6, 0.15), CFrame.new(signPos + Vector3.new(0, 0.55, 0)), COLORS.darkMetal, Enum.Material.Metal, { CanQuery = false })
	local exitSign = lib.part(exitModel, "ExitSign", Vector3.new(6, 1.2, 0.3), lib.lookAt(signPos, signPos - Vector3.new(0, 0, 1)), rgb(20, 110, 50), Enum.Material.Neon, { CanQuery = false })
	lib.sign(exitSign, "EXIT", { Color = rgb(235, 255, 235), Font = Enum.Font.GothamBold, Brightness = 1 })
	lib.new("PointLight", { Range = 10, Brightness = 0.7, Color = rgb(60, 255, 110) }, exitSign)
	-- Låsepanel ved siden av døra
	local panelPos = Vector3.new(doorX1 - 1.6, 4.2, doorZ - CELL / 2 - 0.35)
	local panel = lib.part(exitModel, "LockPanel", Vector3.new(2.2, 2.8, 0.5), lib.lookAt(panelPos, panelPos - Vector3.new(0, 0, 1)), rgb(40, 42, 44), Enum.Material.Metal)
	local _, panelLabel = lib.sign(panel, "0/5", { Color = rgb(255, 80, 70), Font = Enum.Font.Code, Brightness = 2 })
	panelLabel.Name = "Counter"
	lib.new("ProximityPrompt", {
		Name = "InsertPrompt",
		ActionText = "Insert keys",
		ObjectText = "Exit (0/5)",
		HoldDuration = 0.4,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
	}, panel)

	-- Utsiden (synlig når døra åpnes)
	local outZ1 = (EXIT_Y + 1) * CELL
	lib.part(exitModel, "OutsideFloor", Vector3.new(32, 1, 16), CFrame.new(doorCX, -0.5, outZ1 + 8), rgb(40, 40, 42), Enum.Material.Asphalt)
	for _, sx in { -1, 1 } do
		lib.part(exitModel, "OutsideWall", Vector3.new(1, 14, 16), CFrame.new(doorCX + sx * 16.5, 7, outZ1 + 8), rgb(60, 58, 55), Enum.Material.Brick)
	end
	local light = lib.part(exitModel, "OutsideLight", Vector3.new(1, 1, 1), CFrame.new(doorCX, 10, outZ1 + 10), rgb(255, 255, 255), Enum.Material.Neon, { Transparency = 1, CanCollide = false, CanQuery = false })
	lib.new("PointLight", { Range = 30, Brightness = 3, Color = rgb(200, 220, 255) }, light)
	lib.part(exitModel, "ExitZone", Vector3.new(16, 12, 12), CFrame.new(doorCX, 6, outZ1 + 8), rgb(0, 255, 0), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = true,
	})

	------------------------------------------------------------------
	-- Tilskuerboks for spillere uten liv igjen
	------------------------------------------------------------------
	local spec = lib.new("Model", { Name = "SpectatorBox" }, map)
	local sb = Vector3.new(W * CELL / 2, -60, H * CELL / 2)
	lib.part(spec, "Floor", Vector3.new(14, 1, 14), CFrame.new(sb + Vector3.new(0, -0.5, 0)), rgb(0, 0, 0))
	lib.part(spec, "Roof", Vector3.new(14, 1, 14), CFrame.new(sb + Vector3.new(0, 10.5, 0)), rgb(0, 0, 0))
	for _, d in { Vector3.new(7.5, 5, 0), Vector3.new(-7.5, 5, 0), Vector3.new(0, 5, 7.5), Vector3.new(0, 5, -7.5) } do
		local size = d.X ~= 0 and Vector3.new(1, 10, 14) or Vector3.new(14, 10, 1)
		lib.part(spec, "Wall", size, CFrame.new(sb + d), rgb(0, 0, 0))
	end
	lib.marker(spec, "SpectatorPoint", CFrame.new(sb + Vector3.new(0, 3.2, 0)))

	------------------------------------------------------------------
	-- Blodskrift på veggene: hver bokstav er litt skjev, med renner, sprut og håndavtrykk
	------------------------------------------------------------------
	local BLOOD = { rgb(92, 4, 6), rgb(80, 6, 6), rgb(106, 10, 10), rgb(68, 8, 6), rgb(60, 10, 8) }
	local PPS = 40
	local function bloodColor()
		return BLOOD[rng(1, #BLOOD)]
	end

	-- Et flatt merke rett på veggen (lokale koordinater i "plate"-rommet, x mot høyre, y opp)
	local function wallMark(plateCF: any, name: string, lx: number, ly: number, w: number, h: number, color: any, rot: number?, transparency: number?)
		local cf = plateCF * CFrame.new(-lx, ly, 0.012) * CFrame.Angles(0, 0, rot or 0)
		local p = lib.ellipsoid(folders.Decor, name, Vector3.new(w, h, 0.02), cf, color, Enum.Material.SmoothPlastic)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = transparency or 0
		p.Reflectance = 0.04
		return p
	end

	local function drip(plateCF: any, lx: number, ly: number)
		local len = rng() < 0.3 and (1.2 + rng() * 1.6) or (0.25 + rng() * 0.9)
		local w = 0.05 + rng() * 0.06
		local col = bloodColor()
		wallMark(plateCF, "Drip", lx, ly - len / 2, w, len, col)
		wallMark(plateCF, "Drop", lx, ly - len, w * 1.9, w * 2.3, col)
	end

	local function handprint(plateCF: any, lx: number, ly: number, angle: number, smearLen: number)
		local col = bloodColor()
		local rot = CFrame.Angles(0, 0, angle)
		local function at(x: number, y: number)
			local v = rot:PointToWorldSpace(Vector3.new(x, y, 0))
			return lx + v.X, ly + v.Y
		end
		local px, py = at(0, 0)
		wallMark(plateCF, "Hand", px, py, 0.62, 0.7, col, angle, 0.1)
		local fingers = { { -0.27, 0.48, 0.12, 0.42, 0.35 }, { -0.1, 0.6, 0.12, 0.5, 0.1 }, { 0.07, 0.62, 0.12, 0.52, -0.05 }, { 0.23, 0.55, 0.11, 0.44, -0.2 }, { 0.38, 0.05, 0.12, 0.36, -0.9 } }
		for _, f in fingers do
			local fx, fy = at(f[1], f[2])
			wallMark(plateCF, "Finger", fx, fy, f[3], f[4], col, angle + f[5], 0.15)
		end
		-- handen har sklidd nedover veggen
		if smearLen > 0 then
			for k = 1, 4 do
				local sx, sy = at(-0.25 + k * 0.12, -smearLen / 2)
				wallMark(plateCF, "Smear", sx, sy, 0.07, smearLen, col, angle, 0.45 + k * 0.08)
			end
		end
	end

	local function bloodWriting(x: number, y: number, dirName: string, text: string, height: number?, letterH: number?)
		local d = ({ N = Vector3.new(0, 0, -1), S = Vector3.new(0, 0, 1), W = Vector3.new(-1, 0, 0), E = Vector3.new(1, 0, 0) })[dirName]
		local lines = string.split(text, "\n")
		local LH = letterH or (#lines > 1 and 1.15 or 1.5)
		local longest = 0
		for _, line in lines do
			longest = math.max(longest, #line)
		end
		local W = math.max(6, longest * LH * 0.72 + 1.4)
		local Hh = #lines * LH * 1.3 + 1.2
		local pos = cellCenter(x, y, height or 6.2) + d * (CELL / 2 - 0.03)
		local plateCF = lib.lookAt(pos, pos - d)
		local plate = lib.part(folders.Decor, "Writing", Vector3.new(W, Hh, 0.02), plateCF, rgb(0, 0, 0), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		local gui = lib.new("SurfaceGui", {
			Name = "BloodText",
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = PPS,
			LightInfluence = 1,
			Brightness = 1,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, plate)
		local px = LH * PPS
		local Wpx, Hpx = W * PPS, Hh * PPS

		-- utsmurte strøk bak teksten
		for _ = 1, rng(2, 4) do
			local smear = lib.new("Frame", {
				Name = "Smear",
				AnchorPoint = lib.Vector2.new(0.5, 0.5),
				Position = lib.UDim2.new(0, Wpx * (0.2 + rng() * 0.6), 0, Hpx * (0.25 + rng() * 0.5)),
				Size = lib.UDim2.new(0, px * (1.5 + rng() * 3), 0, px * (0.12 + rng() * 0.18)),
				Rotation = rng() * 40 - 20,
				BackgroundColor3 = bloodColor(),
				BackgroundTransparency = 0.72 + rng() * 0.15,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, gui)
			lib.new("UICorner", { CornerRadius = lib.UDim.new(0.5, 0) }, smear)
		end

		for li, line in lines do
			local lineW = 0
			for i = 1, #line do
				lineW += (string.sub(line, i, i) == " " and 0.42 or 0.7) * px
			end
			local cx = (Wpx - lineW) / 2
			local cy = Hpx / 2 + (li - (#lines + 1) / 2) * px * 1.3
			local slope = (rng() - 0.5) * 0.08 -- hele linja heller litt
			for i = 1, #line do
				local ch = string.sub(line, i, i)
				local adv = (ch == " " and 0.42 or 0.7) * px
				if ch ~= " " then
					local lx = cx + adv / 2 + (rng() - 0.5) * px * 0.08
					local ly = cy + (lx - Wpx / 2) * slope + (rng() - 0.5) * px * 0.14
					local size = math.floor(px * (0.9 + rng() * 0.28))
					local col = bloodColor()
					local rot = (rng() - 0.5) * 18
					local transp = 0.04 + rng() * 0.2
					lib.new("TextLabel", {
						Name = "Letter",
						AnchorPoint = lib.Vector2.new(0.5, 0.5),
						Position = lib.UDim2.new(0, lx, 0, ly),
						Size = lib.UDim2.new(0, size * 1.2, 0, size * 1.3),
						Rotation = rot,
						BackgroundTransparency = 1,
						Text = ch,
						TextScaled = false,
						TextSize = size,
						TextColor3 = col,
						TextTransparency = transp,
						TextStrokeColor3 = rgb(30, 0, 0),
						TextStrokeTransparency = 0.45,
						FontFace = lib.Font.fromEnum(Enum.Font.PermanentMarker),
						ZIndex = 2,
					}, gui)
					-- dobbelt strøk på noen bokstaver (som om fingeren gikk over to ganger)
					if rng() < 0.3 then
						lib.new("TextLabel", {
							Name = "LetterSmear",
							AnchorPoint = lib.Vector2.new(0.5, 0.5),
							Position = lib.UDim2.new(0, lx + (rng() - 0.5) * 6, 0, ly + 3 + rng() * 5),
							Size = lib.UDim2.new(0, size * 1.2, 0, size * 1.3),
							Rotation = rot + (rng() - 0.5) * 8,
							BackgroundTransparency = 1,
							Text = ch,
							TextScaled = false,
							TextSize = size,
							TextColor3 = col,
							TextTransparency = 0.7,
							FontFace = lib.Font.fromEnum(Enum.Font.PermanentMarker),
							ZIndex = 1,
						}, gui)
					end
					-- renner fra bunnen av bokstaven
					local wx = W / 2 - lx / PPS
					local wy = Hh / 2 - (ly + size * 0.42) / PPS
					if rng() < 0.5 then
						drip(plateCF, -wx + (rng() - 0.5) * 0.25, wy)
					end
					if rng() < 0.15 then
						drip(plateCF, -wx + (rng() - 0.5) * 0.3, wy + 0.1)
					end
				end
				cx += adv
			end
		end
		-- sprut rundt teksten
		for _ = 1, rng(8, 16) do
			local r = 0.04 + rng() * 0.12
			wallMark(plateCF, "Splatter", (rng() - 0.5) * W * 1.1, (rng() - 0.5) * Hh * 1.1, r, r * (1 + rng() * 0.6), bloodColor(), rng() * 3)
		end
		return plateCF, W, Hh
	end

	local writings = {
		{ 27, 12, "N", "IT SEES YOU" },
		{ 52, 23, "S", "DON'T LOOK\nAT ITS FACE" },
		{ 35, 23, "S", "HIDE IN THE\nLOCKERS" },
		{ 20, 25, "N", "HOW MANY\nKEYS LEFT?" },
		{ 45, 1, "N", "MOMMY?" },
		{ 7, 38, "S", "BEHIND YOU" },
		{ 58, 13, "E", "DON'T RUN\nIT HEARS YOU" },
		{ 14, 16, "N", "IT ALWAYS\nCOMES BACK" },
		{ 34, 27, "S", "VISITING HOURS\nARE OVER" },
		{ 50, 16, "N", "SMILE :)", 9.8 },
		{ 66, 23, "S", "LET ME OUT" },
		{ 84, 23, "S", "I CAN HEAR\nIT SMILING" },
		{ 71, 38, "S", "EAT YOUR\nMEDICINE" },
		{ 24, 54, "S", "IT DOESN'T\nPRAY" },
		{ 47, 44, "N", "PROJECT\n#0413" },
		{ 82, 44, "N", "ALMOST\nOUT :)" },
		{ 30, 42, "S", "DON'T GO TO\nTHE DOCK" },
	}
	for i, wr in writings do
		local plateCF, W, Hh = bloodWriting(wr[1], wr[2], wr[3], wr[4], wr[5])
		if i == 1 or i == 6 or i == 9 then
			handprint(plateCF, W / 2 + 0.6, -Hh * 0.1, math.rad(rng(-25, 25)), 0.8 + rng() * 1.2)
		end
		if i == 3 then
			handprint(plateCF, -W / 2 - 0.4, 0.4, math.rad(-15), 0)
		end
	end

	------------------------------------------------------------------
	-- Blodflekker og papirer på gulvet
	------------------------------------------------------------------
	local floorCells = {}
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if grid[y][x] == "." and not occupied[key(x, y)] then
				table.insert(floorCells, { x, y })
			end
		end
	end
	for i = 1, 28 do
		local c = floorCells[rng(1, #floorCells)]
		local p = cellCenter(c[1], c[2], 0.12) + Vector3.new((rng() - 0.5) * 2, 0, (rng() - 0.5) * 2)
		local size = 1.2 + rng() * 2.5
		lib.part(folders.Decor, "Stain", Vector3.new(0.02, size, size * (0.6 + rng() * 0.6)), CFrame.new(p) * CFrame.Angles(0, rng() * 3, math.pi / 2), COLORS.blood, Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 0.15,
		})
	end
	for i = 1, 40 do
		local c = floorCells[rng(1, #floorCells)]
		local p = cellCenter(c[1], c[2], 0.13) + Vector3.new((rng() - 0.5) * 3, 0, (rng() - 0.5) * 3)
		lib.part(folders.Decor, "Paper", Vector3.new(0.9, 0.02, 1.2), CFrame.new(p) * CFrame.Angles(0, rng() * 6, 0), rgb(215, 212, 196), Enum.Material.SmoothPlastic, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
	end

	------------------------------------------------------------------
	-- Patruljepunkter for monsteret
	------------------------------------------------------------------
	local patrolCount = 0
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if grid[y][x] == "." and x % 3 == 1 and y % 3 == 1 and not occupied[key(x, y)] then
				lib.marker(folders.PatrolPoints, "Point", CFrame.new(cellCenter(x, y, 1)))
				patrolCount += 1
			end
		end
	end

	------------------------------------------------------------------
	-- Forhåndsvisning i terminalen
	------------------------------------------------------------------
	local lines = {}
	for y = 0, H - 1 do
		local row = {}
		for x = 0, W - 1 do
			local ch = grid[y][x]
			if ch == "." and occupied[key(x, y)] then
				ch = "o"
			end
			table.insert(row, ch)
		end
		table.insert(lines, table.concat(row))
	end
	map:SetAttribute("Cells", W .. "x" .. H)
	map.Parent = parent
	return map, table.concat(lines, "\n"), { walls = wallCount, patrol = patrolCount }
end
