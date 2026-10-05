-- Butikken i lobbyen (mynter -> lommelyktfarger og titler) og myntene øverst på skjermen.
-- Åpnes med E ved disken i gavebutikken i lobbyen. Lommelyktene vises i 3D med lyset de sender ut.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Screen = require(script.Parent:WaitForChild("Screen"))
local CosmeticsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cosmetics") :: RemoteEvent

local player = Players.LocalPlayer

local CosmeticsUI = {}

local FONT = Enum.Font.SpecialElite
local MONO = Enum.Font.RobotoMono
local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(14, 12, 10)

local gui: ScreenGui
local coinHud: Frame
local coinHudLabel: TextLabel
local coinScale: UIScale
local inviteButton: TextButton
local inviteScale: UIScale
local closeButton: TextButton
local window: Frame
local windowCoins: TextLabel
local grid: ScrollingFrame
local scale: UIScale
local tabs: { [string]: TextButton } = {}
local currentTab = "Flashlights"
local openPrompt: ProximityPrompt? = nil

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(235, 230, 215),
		Font = FONT,
		TextScaled = true,
		TextStrokeTransparency = 0.6,
	}, parent)
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

-- Liten gullmynt
local function coin(parent: Instance, size: number, position: UDim2, anchor: Vector2?)
	local c = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = anchor or Vector2.new(0, 0.5),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	make("UIStroke", { Color = Color3.fromRGB(150, 100, 30), Thickness = math.max(1, size / 10) }, c)
	local inner = make("Frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 160, 50),
		BorderSizePixel = 0,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, inner)
	return c
end

local function attr(name: string): any
	return player:GetAttribute(name)
end

local function ownedSet(): { [string]: boolean }
	local set = {}
	for _, id in string.split(attr("Owned") or "", ",") do
		if id ~= "" then
			set[id] = true
		end
	end
	return set
end

------------------------------------------------------------------
-- 3D-lommelykt (lavpoly, åttekantet) som vises i butikken
------------------------------------------------------------------
local BODY = Color3.fromRGB(104, 72, 92)
local BODY_DARK = Color3.fromRGB(62, 42, 56)
local SWITCH = Color3.fromRGB(180, 170, 204)
-- { fra x, til x, apotem (halv bredde), farge }; lykta peker langs +X
local SEGMENTS = {
	{ -2.25, -2.0, 0.53, BODY_DARK },
	{ -2.0, 1.2, 0.5, BODY },
	{ 1.2, 1.5, 0.6, BODY_DARK },
	{ 1.5, 1.8, 0.78, BODY },
	{ 1.8, 2.7, 0.98, BODY },
}
local LENS_X = 2.76
-- retningen lykta peker på skjermen (opp til høyre og litt mot deg)
local AIM = Vector3.new(0.78, 0.5, 0.38).Unit

local function part(model: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, wedge: boolean?): BasePart
	local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Åttekantet prisme langs X: to kryssende blokker og fire kiler i hjørnene
local function octagon(model: Instance, base: CFrame, x0: number, x1: number, a: number, color: Color3, material: Enum.Material?)
	local len = x1 - x0
	local side = 2 * a * math.tan(math.pi / 8)
	local d = a - side / 2
	local center = base * CFrame.new((x0 + x1) / 2, 0, 0)
	part(model, Vector3.new(len, 2 * a, side), center, color, material)
	part(model, Vector3.new(len, side, 2 * a), center, color, material)
	for k = 0, 3 do
		local cf = center * CFrame.Angles(k * math.pi / 2, 0, 0) * CFrame.new(0, side / 2 + d / 2, side / 2 + d / 2) * CFrame.Angles(0, math.pi, 0)
		part(model, Vector3.new(len, d, d), cf, color, material, true)
	end
end

local function flashlightModel(color: Color3): (Model, CFrame)
	local model = Instance.new("Model")
	local axis = Vector3.xAxis:Cross(AIM)
	local base = CFrame.new(-AIM * 0.25) * CFrame.fromAxisAngle(axis.Unit, math.acos(Vector3.xAxis:Dot(AIM)))
	for _, s in SEGMENTS do
		octagon(model, base, s[1], s[2], s[3], s[4])
	end
	octagon(model, base, 2.7, LENS_X, 0.84, color, Enum.Material.Neon)
	part(model, Vector3.new(2.3, 0.04, 0.42), base * CFrame.new(-0.45, 0.52, 0), BODY_DARK)
	part(model, Vector3.new(0.35, 0.18, 0.28), base * CFrame.new(0.72, 0.58, 0), SWITCH)
	return model, base
end

-- Fra 3D-punkt til piksel i en ViewportFrame (samme matte som kameraet bruker)
local function project(cam: CFrame, fov: number, w: number, h: number, point: Vector3): Vector2
	local rel = cam:PointToObjectSpace(point)
	local f = 1 / math.tan(math.rad(fov) / 2)
	local x = (rel.X / -rel.Z) * f / (w / h)
	local y = (rel.Y / -rel.Z) * f
	return Vector2.new((x + 1) / 2 * w, (1 - y) / 2 * h)
end

local function circle(parent: Instance, center: Vector2, size: number, color: Color3, alpha: number, z: number)
	local c = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - alpha,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
end

-- Lykta med lyset den sender ut: en vifte av lysstråler som blekner, glød rundt glasset
-- og en lysflekk der strålen treffer "veggen" bak.
local function flashlightView(parent: Instance, color: Color3, w: number, h: number, look: Vector3, distance: number, beamLen: number, beamWidth: number, glowSize: number)
	local holder = make("Frame", {
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, parent)
	local fov = 34
	local camCF = CFrame.lookAt(look + Vector3.new(0, 0, distance), look)
	local model, base = flashlightModel(color)
	local lens = (base * CFrame.new(LENS_X, 0, 0)).Position
	local lensPx = project(camCF, fov, w, h, lens)
	local farPx = project(camCF, fov, w, h, lens + AIM * 4)
	local angle = math.atan2(farPx.Y - lensPx.Y, farPx.X - lensPx.X)

	-- lysflekken
	local spot = lensPx + Vector2.new(math.cos(angle), math.sin(angle)) * beamLen * 0.85
	circle(holder, spot, beamLen * 0.9, color, 0.07, 1)
	circle(holder, spot, beamLen * 0.6, color, 0.08, 1)
	circle(holder, spot, beamLen * 0.35, color, 0.08, 1)
	-- strålene
	local rays = 9
	local spread = math.rad(26)
	for i = 0, rays - 1 do
		local t = i / (rays - 1) - 0.5
		local a = angle + spread * t
		local thick = beamWidth * (0.5 + 0.5 * (1 - math.abs(t) * 2))
		local center = lensPx + Vector2.new(math.cos(a), math.sin(a)) * beamLen / 2
		local ray = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(beamLen, thick),
			Rotation = math.deg(a),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, holder)
		make("UIGradient", { Transparency = NumberSequence.new(0.8, 1) }, ray)
	end
	-- glød bak glasset
	circle(holder, lensPx, glowSize * 4.2, color, 0.08, 3)
	circle(holder, lensPx, glowSize * 2.8, color, 0.14, 3)
	circle(holder, lensPx, glowSize * 1.9, color, 0.22, 3)

	local vpf = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 150),
		LightColor = Color3.fromRGB(255, 236, 216),
		LightDirection = Vector3.new(-0.6, -1.2, -1),
		ZIndex = 4,
	}, holder)
	local camera = make("Camera", { FieldOfView = fov, CFrame = camCF }, vpf)
	vpf.CurrentCamera = camera
	model.Parent = vpf
	-- glasset lyser: lys kjerne oppå
	circle(holder, lensPx, glowSize, color, 0.3, 5)
	circle(holder, lensPx, glowSize * 0.55, Color3.new(1, 1, 1), 0.35, 5)
	return holder
end

-- En figur med tittelen over hodet (til navneskiltene)
local function titleView(parent: Instance, item: any, w: number, h: number)
	local holder = make("Frame", { Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ClipsDescendants = true }, parent)
	local vpf = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(120, 116, 112),
		LightColor = Color3.fromRGB(255, 236, 216),
		LightDirection = Vector3.new(-0.5, -1, -1),
		ZIndex = 2,
	}, holder)
	local model = Instance.new("Model")
	local skin = Color3.fromRGB(70, 66, 64)
	local head = part(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), skin)
	make("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25) }, head)
	part(model, Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), Color3.fromRGB(46, 50, 56))
	part(model, Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0), skin)
	part(model, Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0), skin)
	model.Parent = vpf
	local camera = make("Camera", { FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(0, 1.4, 8.5), Vector3.new(0, 1.9, 0)) }, vpf)
	vpf.CurrentCamera = camera
	local text = if item.text == "" then "—" else item.text
	if item.text ~= "" then
		circle(holder, Vector2.new(w / 2, h * 0.2), w * 0.8, item.color, 0.07, 1)
	end
	label(holder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.new(0.9, 0, 0.16, 0),
		Text = text,
		TextColor3 = if item.text == "" then Color3.fromRGB(150, 140, 125) else item.color,
		TextStrokeTransparency = 0.35,
		ZIndex = 3,
	})
	return holder
end

------------------------------------------------------------------
-- Kortene og utstillingsvinduet
------------------------------------------------------------------
local selected: { [string]: string } = {}
local showcase: Frame

local function equippedId(kind: string): string?
	return if kind == "Flashlights" then attr("FlashId") else attr("TitleId")
end

local function state(item: any, kind: string, owned: { [string]: boolean }): string
	if equippedId(kind) == item.id then
		return "equipped"
	elseif owned[item.id] == true or item.price == 0 then
		return "owned"
	end
	return "locked"
end

local function card(item: any, kind: string, owned: { [string]: boolean }, order: number)
	local st = state(item, kind, owned)
	local coins = attr("Coins") or 0
	local isSelected = selected[kind] == item.id
	local c = make("TextButton", {
		Name = item.id,
		BackgroundColor3 = Color3.fromRGB(22, 19, 16),
		BorderSizePixel = 0,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
	}, grid)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, c)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 110, 100)) }, c)
	make("UIStroke", { Color = if isSelected then GOLD else Color3.fromRGB(70, 60, 48), Thickness = if isSelected then 2 else 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, c)

	if kind == "Flashlights" then
		flashlightView(c, item.color, 108, 104, Vector3.new(1.2, 0.9, 0), 10, 70, 7, 11)
	else
		titleView(c, item, 108, 104)
	end
	label(c, {
		Size = UDim2.new(1, -8, 0, 15),
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = item.name,
		Font = MONO,
		ZIndex = 6,
	})
	local chip = make("Frame", {
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, chip)
	local chipText = label(chip, {
		Size = UDim2.new(1, -8, 0.66, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = MONO,
		TextStrokeTransparency = 1,
		ZIndex = 7,
	})
	if st == "equipped" then
		chip.BackgroundColor3 = Color3.fromRGB(70, 56, 24)
		chipText.Text = "EQUIPPED"
		chipText.TextColor3 = GOLD
	elseif st == "owned" then
		chip.BackgroundColor3 = Color3.fromRGB(40, 70, 46)
		chipText.Text = "OWNED"
	else
		local canAfford = coins >= item.price
		chip.BackgroundColor3 = if canAfford then Color3.fromRGB(110, 80, 24) else Color3.fromRGB(46, 42, 38)
		chipText.Text = "     " .. tostring(item.price)
		chipText.TextColor3 = if canAfford then Color3.fromRGB(255, 236, 190) else Color3.fromRGB(150, 140, 125)
		local ic = coin(chip, 14, UDim2.new(0.5, -22, 0.5, 0))
		ic.ZIndex = 7
	end
	c.Activated:Connect(function()
		selected[kind] = item.id
		CosmeticsUI.refresh()
	end)
end

local function fillShowcase(item: any, kind: string, owned: { [string]: boolean })
	for _, child in showcase:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	if kind == "Flashlights" then
		flashlightView(showcase, item.color, 298, 222, Vector3.new(1.75, 1.15, 0), 11, 200, 15, 22)
	else
		titleView(showcase, item, 298, 222)
	end
	label(showcase, {
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.new(0.5, 0, 0, 236),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = item.name,
		TextColor3 = if kind == "Flashlights" then item.color else Color3.fromRGB(235, 230, 215),
		ZIndex = 6,
	})
	label(showcase, {
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.new(0.5, 0, 0, 264),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = if kind == "Flashlights" then (item.desc or "") else "Shown above your head in the lobby and in rounds.",
		Font = MONO,
		TextColor3 = Color3.fromRGB(160, 150, 130),
		TextStrokeTransparency = 1,
		ZIndex = 6,
	})
	local st = state(item, kind, owned)
	local coins = attr("Coins") or 0
	local button = make("TextButton", {
		Size = UDim2.new(1, -28, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = st ~= "equipped",
		ZIndex = 6,
	}, showcase)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	local text = label(button, {
		Size = UDim2.new(1, -16, 0.6, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Enum.Font.RobotoMono,
		TextStrokeTransparency = 1,
		ZIndex = 7,
	})
	if st == "equipped" then
		button.BackgroundColor3 = Color3.fromRGB(70, 56, 24)
		text.Text = "EQUIPPED"
		text.TextColor3 = GOLD
	elseif st == "owned" then
		button.BackgroundColor3 = Color3.fromRGB(40, 90, 52)
		text.Text = "EQUIP"
	else
		local canAfford = coins >= item.price
		button.BackgroundColor3 = if canAfford then Color3.fromRGB(110, 80, 24) else Color3.fromRGB(46, 42, 38)
		text.Text = "BUY      " .. tostring(item.price)
		text.TextColor3 = if canAfford then Color3.fromRGB(255, 236, 190) else Color3.fromRGB(150, 140, 125)
		local ic = coin(button, 20, UDim2.new(0.5, -14, 0.5, 0))
		ic.ZIndex = 7
	end
	button.Activated:Connect(function()
		if st == "equipped" then
			return
		end
		CosmeticsRemote:FireServer(if st == "owned" then "equip" else "buy", item.id)
	end)
end

local function refresh()
	local coins = attr("Coins") or 0
	coinHudLabel.Text = tostring(coins)
	windowCoins.Text = tostring(coins) .. " COINS"
	coinHud.Visible = attr("InMatch") ~= true and not window.Visible
	inviteButton.Visible = attr("InMatch") ~= true and not window.Visible
	if not window.Visible then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local owned = ownedSet()
	local list = (Config.Cosmetics :: any)[currentTab]
	if not selected[currentTab] then
		selected[currentTab] = equippedId(currentTab) or list[1].id
	end
	local chosen = list[1]
	for i, item in list do
		card(item, currentTab, owned, i)
		if item.id == selected[currentTab] then
			chosen = item
		end
	end
	fillShowcase(chosen, currentTab, owned)
	for name, button in tabs do
		local active = name == currentTab
		button.BackgroundColor3 = if active then Color3.fromRGB(110, 80, 24) else Color3.fromRGB(34, 30, 26)
	end
end
CosmeticsUI.refresh = refresh

function CosmeticsUI.open(prompt: ProximityPrompt?)
	openPrompt = prompt
	window.Visible = true
	selected = {}
	refresh()
end

function CosmeticsUI.close()
	window.Visible = false
	openPrompt = nil
	refresh()
end

------------------------------------------------------------------

local function build()
	gui = make("ScreenGui", {
		Name = "Cosmetics",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- myntene øverst til høyre (bare i lobbyen)
	coinHud = make("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 76),
		Size = UDim2.fromOffset(130, 34),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, coinHud)
	coinScale = make("UIScale", {}, coinHud)
	coin(coinHud, 20, UDim2.new(0, 10, 0.5, 0))
	coinHudLabel = label(coinHud, {
		Size = UDim2.new(1, -44, 0.75, 0),
		Position = UDim2.new(0, 38, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = MONO,
		Text = "0",
	})

	-- Inviter venner (Roblox sin egen invitasjonsmeny)
	inviteButton = make("TextButton", {
		Name = "Invite",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 118),
		Size = UDim2.fromOffset(170, 38),
		BackgroundColor3 = Color3.fromRGB(40, 110, 60),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, inviteButton)
	inviteScale = make("UIScale", {}, inviteButton)
	make("UIStroke", { Color = Color3.fromRGB(140, 230, 160), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inviteButton)
	label(inviteButton, {
		Size = UDim2.new(1, -16, 0.62, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = MONO,
		Text = "INVITE FRIENDS",
		TextColor3 = Color3.fromRGB(235, 255, 238),
	})
	inviteButton.Activated:Connect(function()
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end
	end)

	-- selve butikken
	window = make("Frame", {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 500),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, window)
	make("UIStroke", { Color = Color3.fromRGB(120, 90, 40), Thickness = 2 }, window)
	scale = make("UIScale", {}, window)
	-- gjør musa fri mens butikken er åpen
	make("TextButton", { Name = "MouseUnlock", Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(1, 1) }, window)

	label(window, {
		Size = UDim2.new(0.5, 0, 0, 40),
		Position = UDim2.new(0, 22, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "GIFT SHOP",
		TextColor3 = GOLD,
	})
	coin(window, 22, UDim2.new(1, -212, 0, 34))
	windowCoins = label(window, {
		Size = UDim2.new(0, 128, 0, 26),
		Position = UDim2.new(1, -182, 0, 34),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = MONO,
		Text = "0 COINS",
	})
	local close = make("TextButton", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -10, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(110, 30, 26),
		BorderSizePixel = 0,
		Text = "X",
		Font = MONO,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(240, 230, 220),
	}, window)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
	close.Activated:Connect(CosmeticsUI.close)
	closeButton = close

	for i, name in { "Flashlights", "Titles" } do
		local tab = make("TextButton", {
			Size = UDim2.fromOffset(150, 32),
			Position = UDim2.new(0, 20 + (i - 1) * 160, 0, 64),
			BackgroundColor3 = Color3.fromRGB(34, 30, 26),
			BorderSizePixel = 0,
			Text = string.upper(name),
			Font = MONO,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(240, 230, 210),
		}, window)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, tab)
		make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, tab)
		tab.Activated:Connect(function()
			currentTab = name
			refresh()
		end)
		tabs[name] = tab
	end
	label(window, {
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.new(0, 20, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		Font = MONO,
		TextColor3 = Color3.fromRGB(160, 150, 130),
		Text = "Earn coins by finding keys, helping friends and escaping. Nightmare gives double.",
	})

	-- utstillingsvinduet til venstre (den valgte tingen, stor)
	showcase = make("Frame", {
		Name = "Showcase",
		Size = UDim2.fromOffset(300, 334),
		Position = UDim2.new(0, 20, 0, 108),
		BackgroundColor3 = Color3.fromRGB(29, 27, 23),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, window)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, showcase)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(100, 96, 90)) }, showcase)
	make("UIStroke", { Color = Color3.fromRGB(70, 60, 48), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, showcase)

	grid = make("ScrollingFrame", {
		Size = UDim2.fromOffset(470, 340),
		Position = UDim2.new(0, 336, 0, 108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(108, 162),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
end

function CosmeticsUI.init()
	build()
	for _, name in { "Coins", "Owned", "FlashId", "TitleId", "InMatch" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "CosmeticsPrompt" then
			CosmeticsUI.open(prompt)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and window.Visible then
			CosmeticsUI.close()
		end
	end)
	-- lukk butikken hvis du går bort fra disken eller en runde starter
	RunService.Heartbeat:Connect(function()
		-- butikken midt i det trygge området (under topplinja), så stor som det er plass til
		local area = Screen.area()
		local s = area.scale
		local fit = math.min(area.width * 0.96 / 820, (area.height - 12) / 500)
		scale.Scale = math.clamp(math.min(area.view.X / 880, area.view.Y / 560, fit), 0.45, 1.2)
		window.Position = UDim2.fromOffset(area.left + area.width / 2, area.top + area.height / 2)
		-- større lukkeknapp på mobil
		closeButton.Size = if area.touch then UDim2.fromOffset(40, 40) else UDim2.fromOffset(32, 32)
		-- myntene og INVITE FRIENDS øverst til høyre, under CH-teksten (litt større på mobil,
		-- så knappen er lett å trykke på)
		local hudScale = if area.touch then math.max(s, 0.8) else s
		local top = area.top + 6 + 40 * s
		coinScale.Scale = hudScale
		coinHud.Position = UDim2.new(1, -(area.right + 24 * s), 0, top)
		inviteScale.Scale = hudScale
		inviteButton.Position = UDim2.new(1, -(area.right + 24 * s), 0, top + 42 * hudScale)
		if not window.Visible then
			return
		end
		local prompt = openPrompt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local promptPart = prompt and prompt.Parent
		if attr("InMatch") == true then
			CosmeticsUI.close()
		elseif root and promptPart and promptPart:IsA("BasePart") and (root.Position - promptPart.Position).Magnitude > 18 then
			CosmeticsUI.close()
		end
	end)
	refresh()
end

return CosmeticsUI
