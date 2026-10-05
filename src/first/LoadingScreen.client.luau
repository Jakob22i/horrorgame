-- Loading screen i VHS-stil: fargestriper, støy og "PLEASE STAND BY" mens spillet lastes.
-- Ligger i ReplicatedFirst, så den vises før alt annet.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MIN_TIME = 3 -- sekunder skjermen vises minst
local MAX_TIME = 20 -- gir opp å vente på lyder etter så lang tid

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local startTime = os.clock()

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local gui = make("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local root = make("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
}, gui)

ReplicatedFirst:RemoveDefaultLoadingScreen()

------------------------------------------------------------------
-- Fargestriper (SMPTE)
------------------------------------------------------------------
local function bar(x: number, y: number, w: number, h: number, color: Color3)
	make("Frame", {
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, root)
end

local TOP = {
	Color3.fromRGB(192, 192, 192),
	Color3.fromRGB(192, 192, 0),
	Color3.fromRGB(0, 192, 192),
	Color3.fromRGB(0, 192, 0),
	Color3.fromRGB(192, 0, 192),
	Color3.fromRGB(192, 0, 0),
	Color3.fromRGB(0, 0, 192),
}
local MID = {
	Color3.fromRGB(0, 0, 192),
	Color3.fromRGB(19, 19, 19),
	Color3.fromRGB(192, 0, 192),
	Color3.fromRGB(19, 19, 19),
	Color3.fromRGB(0, 192, 192),
	Color3.fromRGB(19, 19, 19),
	Color3.fromRGB(192, 192, 192),
}
for i = 1, 7 do
	bar((i - 1) / 7, 0, 1 / 7 + 0.002, 0.67, TOP[i])
	bar((i - 1) / 7, 0.67, 1 / 7 + 0.002, 0.08, MID[i])
end
local w = 1 / 7 * 5 / 4
bar(0, 0.75, w, 0.25, Color3.fromRGB(0, 33, 76))
bar(w, 0.75, w, 0.25, Color3.fromRGB(255, 255, 255))
bar(w * 2, 0.75, w, 0.25, Color3.fromRGB(50, 0, 106))
bar(w * 3, 0.75, 1 - w * 3, 0.25, Color3.fromRGB(19, 19, 19))
bar(5 / 7, 0.75, 1 / 21, 0.25, Color3.fromRGB(9, 9, 9))
bar(5 / 7 + 2 / 21, 0.75, 1 / 21, 0.25, Color3.fromRGB(29, 29, 29))

-- litt mørkere, slik at teksten synes
make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 2,
}, root)

------------------------------------------------------------------
-- Støy og sporingsstripe
------------------------------------------------------------------
local noise: { Frame } = {}
for _ = 1, 26 do
	table.insert(
		noise,
		make("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
		}, root)
	)
end
local tracking = make("Frame", {
	Size = UDim2.new(1, 0, 0.07, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	ZIndex = 3,
}, root)

------------------------------------------------------------------
-- Tekst og fremdrift
------------------------------------------------------------------
local function label(props: { [string]: any }, parent: Instance): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = MONO,
		TextColor3 = Color3.fromRGB(240, 240, 235),
		TextScaled = true,
		TextStrokeTransparency = 0.6,
		ZIndex = 5,
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

local box = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.3),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ZIndex = 4,
}, root)
make("UIStroke", { Color = Color3.fromRGB(235, 235, 230), Thickness = 2 }, box)
make("UISizeConstraint", { MinSize = Vector2.new(300, 150) }, box)

local title = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.12),
	Size = UDim2.fromScale(0.86, 0.32),
	Text = "PLEASE STAND BY",
}, box)
label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromScale(0.8, 0.12),
	Text = "ST. AGATHE HOSPITAL  —  TAPE LOADING",
	TextColor3 = Color3.fromRGB(190, 190, 180),
}, box)

-- blokkete fremdriftslinje
local SEGMENTS = 20
local segments: { Frame } = {}
local barHolder = make("Frame", {
	Position = UDim2.fromScale(0.07, 0.68),
	Size = UDim2.fromScale(0.68, 0.12),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, box)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0.01, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, barHolder)
for i = 1, SEGMENTS do
	table.insert(
		segments,
		make("Frame", {
			Size = UDim2.fromScale(0.04, 1),
			BackgroundColor3 = Color3.fromRGB(235, 235, 230),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 6,
		}, barHolder)
	)
end
local percent = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(0.93, 0.68),
	Size = UDim2.fromScale(0.14, 0.12),
	Text = "000%",
	TextXAlignment = Enum.TextXAlignment.Right,
}, box)

local osdPlay = label({
	Position = UDim2.new(0, 28, 0, 22),
	Size = UDim2.new(0.25, 0, 0, 30),
	Text = "▶ PLAY",
	TextXAlignment = Enum.TextXAlignment.Left,
}, root)
label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -28, 0, 22),
	Size = UDim2.new(0.25, 0, 0, 30),
	Text = "CH 03",
	TextXAlignment = Enum.TextXAlignment.Right,
}, root)
local counter = label({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 28, 1, -22),
	Size = UDim2.new(0.3, 0, 0, 28),
	Text = "SP  0:00:00",
	TextXAlignment = Enum.TextXAlignment.Left,
}, root)

------------------------------------------------------------------
-- Animasjon
------------------------------------------------------------------
local target = 0
local shown = 0
local burst = 0
local conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - startTime
	shown += (target - shown) * math.min(1, dt * 4)
	local filled = math.floor(shown * SEGMENTS + 0.5)
	for i, seg in segments do
		seg.BackgroundTransparency = i <= filled and 0 or 0.85
	end
	percent.Text = string.format("%03d%%", math.floor(shown * 100 + 0.5))
	counter.Text = string.format("SP  0:%02d:%02d", math.floor(t / 60), math.floor(t) % 60)
	osdPlay.TextTransparency = (math.floor(t * 1.5) % 2 == 0) and 0 or 0.4
	title.TextTransparency = math.random() < 0.04 and 0.6 or 0

	local amount = 0.35 + burst
	for _, line in noise do
		if math.random() < amount then
			line.Visible = true
			line.Position = UDim2.fromScale(math.random() * 0.2 - 0.1, math.random())
			line.Size = UDim2.new(0.3 + math.random() * 0.9, 0, 0, math.random(1, 3))
			line.BackgroundTransparency = 0.55 + math.random() * 0.4
		else
			line.Visible = false
		end
	end
	tracking.Position = UDim2.fromScale(0, ((t * 0.18) % 1.2) - 0.1)
end)

------------------------------------------------------------------
-- Lasting
------------------------------------------------------------------
if not game:IsLoaded() then
	task.spawn(function()
		-- kryp sakte fremover mens selve spillet lastes
		while not game:IsLoaded() do
			target = math.min(0.3, target + 0.01)
			task.wait(0.1)
		end
	end)
	game.Loaded:Wait()
end
target = math.max(target, 0.3)

-- Forhåndslast lyder og monsteret, så de er klare når runden starter
local toLoad: { any } = {}
local shared = ReplicatedStorage:WaitForChild("Shared", 10)
local configModule = shared and shared:WaitForChild("Config", 10)
if configModule and configModule:IsA("ModuleScript") then
	local ok, config = pcall(require, configModule)
	if ok and type(config) == "table" and type(config.Sounds) == "table" then
		for _, id in config.Sounds do
			if typeof(id) == "string" and id ~= "" then
				table.insert(toLoad, id)
			end
		end
	end
end
local assets = ReplicatedStorage:WaitForChild("Assets", 10)
if assets then
	table.insert(toLoad, assets)
end

local done = 0
local finished = false
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(toLoad, function()
			done += 1
			target = 0.3 + 0.65 * math.min(1, done / math.max(1, #toLoad))
		end)
	end)
	finished = true
end)
while not finished and os.clock() - startTime < MAX_TIME do
	task.wait(0.1)
end

-- vent på karakteren i lobbyen, så den er klar når bildet kommer
local waited = 0
while not player.Character and waited < 5 do
	waited += task.wait(0.1)
end
target = 1
while os.clock() - startTime < MIN_TIME or shown < 0.98 do
	task.wait(0.05)
end

-- Ferdig: kort støyburst, så toner skjermen ut
title.Text = "▶ PLAY"
burst = 0.6
task.wait(0.35)
burst = 0
local tween = TweenService:Create(root, TweenInfo.new(1, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
tween:Play()
tween.Completed:Wait()
conn:Disconnect()
gui:Destroy()
