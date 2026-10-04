-- Blod som ser ekte ut: pytter, sprut, slepespor, fotavtrykk, renner og håndavtrykk.
-- Alt tegnes som avrundede Frames i en SurfaceGui på en usynlig, tynn del (et "lerret"),
-- så kantene blir myke og organiske i stedet for harde sylindre og kuler.
--
-- Koordinater på lerretet er i studs, med origo i midten, x mot høyre og y opp
-- (sett forfra på en vegg). Vinkler (a) er i radianer mot klokka, som i matte.

local lib = require("./lib")
local Vector3, Enum = lib.Vector3, lib.Enum
local rgb = lib.rgb

local Blood = {}

export type Palette = { rim: any, rimT: number, body: any, bodyT: number, core: any, coreT: number }

-- Ferskt blod: nesten svart der det er tykt, rødt og litt gjennomsiktig i de tynne kantene
Blood.FRESH = {
	rim = rgb(118, 10, 12),
	rimT = 0.4,
	body = rgb(62, 3, 5),
	bodyT = 0,
	core = rgb(28, 1, 2),
	coreT = 0.35,
} :: Palette
-- Gammelt, inntørket blod: brunt og gjennomsiktig, med mørkere kant (som en kaffering)
Blood.DRIED = {
	rim = rgb(48, 13, 9),
	rimT = 0.1,
	body = rgb(94, 34, 22),
	bodyT = 0.28,
	core = rgb(70, 22, 14),
	coreT = 0.6,
} :: Palette

local GLOSS = rgb(255, 222, 212)

local Canvas = {}
Canvas.__index = Canvas

-- GUI-rotasjon er i grader med klokka (y peker ned i GUI), vi bruker matte-vinkler
local function guiRot(a: number): number
	return -math.deg(a)
end

-- Lager et lerret. face = "Top" for gulv/bord, ellers en vegg der Front-siden (-Z) vender mot deg.
function Blood.canvas(parent: any, name: string, cf: any, w: number, h: number, face: string?, pps: number?)
	local isFloor = face == "Top"
	local size = if isFloor then Vector3.new(w, 0.02, h) else Vector3.new(w, h, 0.02)
	local part = lib.part(parent, name, size, cf, rgb(0, 0, 0), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local density = pps or 32
	local gui = lib.new("SurfaceGui", {
		Name = "Blood",
		Face = if isFloor then Enum.NormalId.Top else Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = density,
		LightInfluence = 1,
		Brightness = 1,
		MaxDistance = 110,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, part)
	local self = setmetatable({}, Canvas)
	self.part = part
	self.gui = gui
	self.w = w
	self.h = h
	self.pps = density
	self.ox = 0
	self.oy = 0
	self.count = 0
	return self
end

-- Flytter origo (nyttig når teksten ikke står midt på lerretet)
function Canvas:setOrigin(x: number, y: number)
	self.ox = x
	self.oy = y
end

-- Omregning fra lerret-studs til GUI-piksler
function Canvas:px(x: number, y: number): (number, number)
	return (x + self.ox + self.w / 2) * self.pps, (self.h / 2 - (y + self.oy)) * self.pps
end

-- En avrundet flekk (kapsel/sirkel). w langs retningen a, h på tvers.
function Canvas:blob(x: number, y: number, w: number, h: number, a: number, color: any, transparency: number?, z: number?)
	local px, py = self:px(x, y)
	local frame = lib.new("Frame", {
		AnchorPoint = lib.Vector2.new(0.5, 0.5),
		Position = lib.UDim2.new(0, px, 0, py),
		Size = lib.UDim2.new(0, math.max(1.5, w * self.pps), 0, math.max(1.5, h * self.pps)),
		Rotation = guiRot(a),
		BackgroundColor3 = color,
		BackgroundTransparency = math.clamp(transparency or 0, 0, 0.97),
		BorderSizePixel = 0,
		ZIndex = z or 2,
	}, self.gui)
	lib.new("UICorner", { CornerRadius = lib.UDim.new(0.5, 0) }, frame)
	self.count += 1
	return frame
end

-- Pytt: en uregelmessig "amøbe" av overlappende sirkler (laget med en tilfeldig vandring),
-- med renner som har flytt ut langs flisene og små dråper rundt.
-- Hver sirkel tegnes i tre lag: tynn kant, kropp og mørk midte der blodet er tykt.
function Canvas:pool(cx: number, cy: number, r: number, pal: Palette, rng: any, opts: { [string]: any }?)
	local o = opts or {}
	local circles = {}
	local x, y = cx, cy
	local heading = rng() * math.pi * 2
	for _ = 1, rng(7, 11) do
		local rad = r * (0.36 + rng() * 0.38)
		table.insert(circles, { x, y, rad * (1 + rng() * 0.25), rad, rng() * math.pi })
		heading += (rng() - 0.5) * 1.8
		local step = rad * (0.55 + rng() * 0.4)
		x = cx + (x + math.cos(heading) * step - cx) * 0.8
		y = cy + (y + math.sin(heading) * step - cy) * 0.8
	end
	-- renner: blodet har flytt ut i noen retninger og endt i en rund dråpe
	for _ = 1, o.runs or rng(1, 3) do
		local start = circles[rng(1, #circles)]
		local a = math.atan2(start[2] - cy, start[1] - cx) + (rng() - 0.5) * 0.8
		local rad = start[4] * 0.55
		local px, py = start[1], start[2]
		for _ = 1, rng(2, 3) do
			px += math.cos(a) * rad * 1.1
			py += math.sin(a) * rad * 1.1
			rad *= 0.72
			a += (rng() - 0.5) * 0.5
			table.insert(circles, { px, py, rad * 1.3, rad, a })
		end
		table.insert(circles, { px + math.cos(a) * rad, py + math.sin(a) * rad, rad * 1.5, rad * 1.4, a })
	end
	local edge = math.clamp(r * 0.05, 0.025, 0.07)
	for _, c in circles do
		-- kanten synes bare på sirkler som ligger ytterst (de innerste dekkes av kroppen)
		if math.sqrt((c[1] - cx) ^ 2 + (c[2] - cy) ^ 2) + c[3] > r * 0.75 then
			self:blob(c[1], c[2], c[3] * 2 + edge * 2, c[4] * 2 + edge * 2, c[5], pal.rim, pal.rimT, 1)
		end
	end
	for _, c in circles do
		self:blob(c[1], c[2], c[3] * 2, c[4] * 2, c[5], pal.body, pal.bodyT, 2)
	end
	for _, c in circles do
		if c[4] > r * 0.36 then
			self:blob(c[1], c[2], c[3] * 1.35, c[4] * 1.35, c[5], pal.core, pal.coreT, 3)
		end
	end
	-- svak glans der lyset treffer det våte blodet
	if o.gloss ~= false and pal.bodyT == 0 then
		self:blob(cx - r * 0.15, cy + r * 0.2, r * 0.7, r * 0.35, 0.4 + rng() * 0.3, GLOSS, 0.94, 4)
	end
	for _ = 1, o.drops or rng(5, 9) do
		local a = rng() * math.pi * 2
		local d = r * (1.05 + rng() * 0.9)
		local s = 0.03 + rng() * 0.07
		local long = if rng() < 0.4 then 1.6 + rng() * 2 else 1
		self:blob(cx + math.cos(a) * d, cy + math.sin(a) * d, s * long, s, a, pal.body, pal.bodyT + rng() * 0.25, 2)
	end
end

-- Slepespor: noe blødende er dratt bortover (langs +x fra x0). Lange, overlappende strøk
-- som blir kortere og smalere, så sporet blir svakere jo lenger unna pytten det kommer.
function Canvas:drag(x0: number, y0: number, len: number, width: number, pal: Palette, rng: any)
	local layers = 5
	for i = 1, layers do
		local l = len * (0.3 + 0.7 * i / layers)
		local w = width * (1.15 - 0.13 * i)
		local a = (rng() - 0.5) * 0.06
		local yo = (rng() - 0.5) * width * 0.3
		local start = x0 - width * 0.4
		self:blob(start + math.cos(a) * l / 2, y0 + yo + math.sin(a) * l / 2, l, w, a, pal.body, 0.5, 2)
	end
	-- striper i sporet (fingre og klær som er dratt gjennom blodet)
	for _ = 1, rng(5, 8) do
		local off = (rng() - 0.5) * width * 0.7
		local l = len * (0.35 + rng() * 0.6)
		local s = 0.03 + rng() * 0.05
		self:blob(x0 + l / 2, y0 + off, l, s, (rng() - 0.5) * 0.03, pal.core, 0.3 + rng() * 0.35, 3)
	end
	-- frynsete kanter og små klatter som har falt av
	for _ = 1, rng(8, 14) do
		local t = rng()
		local side = if rng() < 0.5 then -1 else 1
		local w = width * (1 - 0.5 * t)
		local s = 0.05 + rng() * 0.08
		self:blob(x0 + t * len, y0 + side * (w * 0.45 + rng() * 0.25), s * (1 + rng() * 1.5), s, (rng() - 0.5) * 0.6, pal.body, 0.15 + t * 0.5, 2)
	end
end

-- Ett bart fotavtrykk som peker langs vinkelen a. side = 1 for venstre fot, -1 for høyre.
function Canvas:foot(x: number, y: number, a: number, side: number, pal: Palette, transparency: number)
	local ca, sa = math.cos(a) * 1.12, math.sin(a) * 1.12
	local function b(lx: number, ly: number, w: number, h: number, extra: number?)
		self:blob(x + lx * ca - ly * sa, y + lx * sa + ly * ca, w * 1.12, h * 1.12, a, pal.body, transparency + (extra or 0), 2)
	end
	b(-0.3, 0.01 * side, 0.34, 0.28) -- hæl
	b(-0.04, 0.07 * side, 0.5, 0.17) -- yttersiden av foten (svangen løfter innsiden)
	b(0.22, -0.01 * side, 0.32, 0.33) -- tråputen
	-- tær: stortåa på innsiden (mot midten mellom føttene)
	for _, t in { { 0.46, -0.11, 0.16 }, { 0.49, -0.01, 0.11 }, { 0.475, 0.07, 0.1 }, { 0.44, 0.135, 0.09 }, { 0.39, 0.19, 0.08 } } do
		b(t[1], t[2] * side, t[3], t[3])
	end
end

-- Fotspor som går ut fra en pytt langs +x og blir svakere etter hvert
function Canvas:footprints(x0: number, y0: number, count: number, pal: Palette, rng: any)
	for i = 1, count do
		local side = if i % 2 == 0 then 1 else -1
		local t = (i - 1) / math.max(1, count - 1)
		local a = (rng() - 0.5) * 0.16 + side * 0.06
		self:foot(x0 + (i - 1) * 0.85, y0 + side * 0.26, a, side, pal, 0.03 + t * 0.6)
	end
end

-- Renne nedover en vegg, med en dråpe nederst
function Canvas:drip(x: number, y: number, len: number, w: number, pal: Palette)
	self:blob(x, y - len / 2, len, w, -math.pi / 2, pal.body, 0, 2)
	self:blob(x, y - len + w * 0.3, w * 2, w * 1.7, -math.pi / 2, pal.body, 0, 2)
end

-- Håndavtrykk. a = hvor mye hånda er vridd, smear = hvor langt den har sklidd ned.
-- Hånda er satt sammen av flere puter med glipper (som et ekte, ujevnt avtrykk).
function Canvas:hand(x: number, y: number, a: number, smear: number, pal: Palette, rng: any)
	local ca, sa = math.cos(a), math.sin(a)
	local up = a + math.pi / 2
	local function b(lx: number, ly: number, w: number, h: number, extraA: number, col: any, t: number, z: number?)
		self:blob(x + lx * ca - ly * sa, y + lx * sa + ly * ca, w, h, up + extraA, col, t, z)
	end
	-- håndflata: tommelballen, lillefingersiden og putene under fingrene. Midten treffer dårligere.
	b(-0.11, -0.13, 0.4, 0.38, 0.2, pal.body, 0.08)
	b(0.14, -0.1, 0.46, 0.34, -0.1, pal.body, 0.1)
	b(0.02, 0.2, 0.26, 0.68, 0, pal.body, 0.05)
	b(0.01, 0.03, 0.34, 0.42, 0, pal.body, 0.3)
	for _ = 1, 3 do
		b((rng() - 0.5) * 0.4, (rng() - 0.5) * 0.4, 0.08 + rng() * 0.1, 0.06 + rng() * 0.08, rng() * 3, pal.core, 0.4, 3)
	end
	-- fingre i to ledd: { x, y, bredde, lengde, ekstra vinkel }
	local fingers = {
		{ -0.26, 0.52, 0.14, 0.42, 0.3 },
		{ -0.09, 0.62, 0.145, 0.5, 0.08 },
		{ 0.08, 0.64, 0.145, 0.52, -0.04 },
		{ 0.24, 0.57, 0.135, 0.44, -0.18 },
		{ 0.41, 0.06, 0.15, 0.38, -0.95 },
	}
	for _, f in fingers do
		local fa = f[5]
		local dx, dy = -math.sin(fa), math.cos(fa) -- fingerens retning i hånd-rommet
		local l = f[4]
		b(f[1] - dx * l * 0.22, f[2] - dy * l * 0.22, l * 0.5, f[3], fa, pal.body, 0.12)
		b(f[1] + dx * l * 0.26, f[2] + dy * l * 0.26, l * 0.44, f[3] * 0.95, fa, pal.body, 0.05)
		-- fingertuppen trykker hardest
		b(f[1] + dx * l * 0.34, f[2] + dy * l * 0.34, f[3] * 0.9, f[3] * 0.8, fa, pal.core, 0.3, 3)
	end
	if smear > 0 then
		for k = 0, 3 do
			local lx = -0.26 + k * 0.165
			local px, py = x + lx * ca - (0.55 - smear / 2) * sa, y + lx * sa + (0.55 - smear / 2) * ca
			self:blob(px, py, smear, 0.07 + rng() * 0.03, a - math.pi / 2, pal.body, 0.4 + k * 0.1, 1)
		end
	end
end

-- Arteriesprut på en vegg: dråper i en bue som blir mindre utover, noen renner nedover
function Canvas:spray(x0: number, y0: number, a0: number, len: number, pal: Palette, rng: any)
	local bend = (rng() - 0.5) * 0.6
	for _ = 1, rng(18, 26) do
		local t = rng() ^ 0.8
		local a = a0 + bend * t
		local d = t * len
		local x = x0 + math.cos(a) * d + (rng() - 0.5) * 0.3 * t
		local y = y0 + math.sin(a) * d + (rng() - 0.5) * 0.3 * t
		local s = (0.22 - 0.16 * t) * (0.6 + rng() * 0.8)
		self:blob(x, y, s * (1.3 + rng() * 2 * t), s, a, pal.body, rng() * 0.2, 2)
		if s > 0.16 and rng() < 0.45 then
			self:drip(x, y, 0.3 + rng() * 1.3, s * 0.4, pal)
		end
	end
	self:pool(x0, y0, 0.35 + rng() * 0.2, pal, rng, { gloss = false, drops = 6, runs = 0 })
	self:drip(x0 + (rng() - 0.5) * 0.3, y0 - 0.2, 1.2 + rng() * 1.5, 0.09, pal)
end

return Blood
