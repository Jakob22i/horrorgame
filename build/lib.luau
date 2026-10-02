-- Små hjelpefunksjoner for å bygge Roblox-objekter med Lune.

local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local lib = {}

lib.Instance = Instance
lib.Vector3 = Vector3
lib.CFrame = CFrame
lib.Color3 = Color3
lib.Enum = Enum
lib.UDim2 = roblox.UDim2
lib.Font = roblox.Font

function lib.rgb(r: number, g: number, b: number)
	return Color3.fromRGB(r, g, b)
end

-- Lager en instans med egenskaper. Spesielle nøkler: Attributes, Tags.
function lib.new(className: string, props: { [string]: any }?, parent: any?)
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			if key == "Attributes" then
				for name, v in value do
					inst:SetAttribute(name, v)
				end
			elseif key == "Tags" then
				for _, tag in value do
					inst:AddTag(tag)
				end
			else
				inst[key] = value
			end
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Forankret del med glatte overflater.
function lib.part(parent: any, name: string, size: any, cframe: any, color: any, material: any?, extra: { [string]: any }?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for key, value in extra do
			if key == "Attributes" then
				for n, v in value do
					p:SetAttribute(n, v)
				end
			elseif key == "Tags" then
				for _, tag in value do
					p:AddTag(tag)
				end
			else
				p[key] = value
			end
		end
	end
	p.Parent = parent
	return p
end

-- Usynlig hjelpedel (markør) som ikke kolliderer og ikke treffes av raycast.
function lib.marker(parent: any, name: string, cframe: any, size: any?)
	return lib.part(parent, name, size or Vector3.new(1, 1, 1), cframe, Color3.fromRGB(255, 0, 255), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
end

-- Ellipsoide (del med kule-mesh), brukes til ansikt, øyne og hår.
function lib.ellipsoid(parent: any, name: string, size: any, cframe: any, color: any, material: any?)
	local p = lib.part(parent, name, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Sylinder langs Y-aksen (Roblox-sylindre ligger langs X, så vi roterer).
function lib.cylinderY(parent: any, name: string, diameter: number, height: number, cframe: any, color: any, material: any?)
	return lib.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		{ Shape = Enum.PartType.Cylinder }
	)
end

-- SurfaceGui med én tekst på forsiden av en del.
function lib.sign(part: any, text: string, opts: { [string]: any }?)
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = o.Face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.PixelsPerStud or 40
	gui.LightInfluence = o.LightInfluence or 0
	gui.Brightness = o.Brightness or 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = o.LabelName or "Text"
	label.Size = lib.UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = o.Color or Color3.fromRGB(230, 230, 230)
	label.FontFace = lib.Font.fromEnum(o.Font or Enum.Font.GothamBold)
	label.TextTransparency = o.TextTransparency or 0
	label.Parent = gui
	return gui, label
end

-- Enkel deterministisk tilfeldighetsgenerator (så kartet blir likt hver gang vi bygger).
function lib.rng(seed: number)
	local state = seed
	return function(a: number?, b: number?): number
		state = (state * 1103515245 + 12345) % 2147483648
		local r = state / 2147483648
		if a and b then
			return a + math.floor(r * (b - a + 1))
		end
		return r
	end
end

return lib
