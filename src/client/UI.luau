-- Alt brukergrensesnitt: VHS-filter, HUD, beskjeder, overganger og menyer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local UI = {}

local UserInputService = game:GetService("UserInputService")

-- Mobil/nettbrett: berøringsskjerm uten tastatur
function UI.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local FONT_VHS = Enum.Font.RobotoMono
local FONT_TEXT = Enum.Font.SpecialElite

local gui: ScreenGui
local vhs: Frame
local noiseFrame: Frame
local noiseLines: { Frame } = {}
local noiseFlash: Frame
local leaveButton: TextButton
local leaveCallback: (() -> ())? = nil
local trackingBar: Frame
local recLabel: TextLabel
local channelLabel: TextLabel
local timeLabel: TextLabel
local hud: Frame
local livesLabel: TextLabel
local keysLabel: TextLabel
local exitLabel: TextLabel
local keyPips: { Frame } = {}
local staminaBack: Frame
local staminaFill: Frame
local breathBack: Frame
local breathFill: Frame
local breathLabel: TextLabel
local downedFrame: Frame
local downedLabel: TextLabel
local hintLabel: TextLabel
local spectateLabel: TextLabel
local finaleLabel: TextLabel
local captionLabel: TextLabel
local titleCard: Frame
local titleMain: TextLabel
local titleSub: TextLabel
local notifyList: Frame
local fadeFrame: Frame
local fadeLabel: TextLabel
local panelDim: Frame
local panel: Frame
local panelTitle: TextLabel
local panelText: TextLabel
local panelButtons: Frame
local panelTimer: TextLabel
local reviveButton: TextButton
local reviveCost: TextLabel
local reviveCallback: (() -> ())? = nil
local reviveCredits = 0
local revivePrice = 39

-- Knappene nederst (1 Flashlight, 2 Push, 3 Jumpscare)
local actionBar: Frame
local actionScale: UIScale
type Slot = {
	button: TextButton,
	icon: TextLabel,
	lock: TextLabel,
	price: Frame,
	priceText: TextLabel,
	cooldown: Frame,
	cooldownUntil: number,
	cooldownLength: number,
	callback: (() -> ())?,
}
local slots: { [string]: Slot } = {}
local ROBUX = utf8.char(0xE002)

UI.jumpscareLayer = nil :: Frame?

local noiseIntensity = 0
local noiseOverride = 0
local vhsMode = "lobby"
local recordStart = os.clock()
local panelToken = 0

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

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(235, 235, 230),
		Font = FONT_TEXT,
		TextScaled = true,
		TextStrokeTransparency = 0.5,
	}, parent)
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

local function buildVhs()
	vhs = make("Frame", {
		Name = "VHS",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, gui)

	-- Skannelinjer
	local lines = make("Frame", { Name = "Scanlines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, vhs)
	for i = 0, 119 do
		make("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, i / 120),
			Size = UDim2.new(1, 0, 0, 1),
		}, lines)
	end

	-- Vignett (mørke kanter)
	local function edge(pos: UDim2, size: UDim2, rotation: number)
		local f = make("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Position = pos,
			Size = size,
		}, vhs)
		make("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, f)
	end
	edge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90)
	edge(UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), -90)
	edge(UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0)
	edge(UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180)

	-- Analog støy når monsteret er nær: tynne, blinkende VHS-striper (dekker lite av bildet)
	noiseFrame = make("Frame", { Name = "Noise", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, vhs)
	noiseFlash = make("Frame", {
		Name = "Flash",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(200, 190, 150),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, noiseFrame)
	for _ = 1, 26 do
		table.insert(noiseLines, make("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 2),
		}, noiseFrame))
	end

	trackingBar = make("Frame", {
		Name = "Tracking",
		BackgroundColor3 = Color3.fromRGB(230, 230, 230),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.035),
		Position = UDim2.fromScale(0, -0.1),
	}, vhs)

	recLabel = text(vhs, {
		Name = "Rec",
		Font = FONT_VHS,
		Position = UDim2.new(0, 28, 0, 64),
		Size = UDim2.new(0, 200, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "▶ PLAY",
	})
	channelLabel = text(vhs, {
		Name = "Channel",
		Font = FONT_VHS,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 64),
		Size = UDim2.new(0, 200, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "CH 03",
	})
	timeLabel = text(vhs, {
		Name = "Time",
		Font = FONT_VHS,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -22),
		Size = UDim2.new(0, 360, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
end

local function buildHud()
	hud = make("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
	}, gui)

	local box = make("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 104),
		Size = UDim2.new(0, 230, 0, 132),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
	livesLabel = text(box, {
		Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(1, -24, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 40, 40),
		Font = Enum.Font.GothamBold,
		RichText = true,
		Text = "♥ ♥ ♥",
	})
	keysLabel = text(box, {
		Position = UDim2.new(0, 12, 0, 42),
		Size = UDim2.new(1, -24, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 214, 110),
		Text = "KEYS: 0",
	})
	-- én rute per nøkkelfarge: svak = ikke funnet, fylt med hvit kant = du bærer den,
	-- fylt med hake = låsen på nødutgangen er åpen
	for i, entry in Config.KeyColors do
		local pip = make("Frame", {
			Name = "Key" .. i,
			Position = UDim2.new(0, 12 + (i - 1) * 42, 0, 72),
			Size = UDim2.fromOffset(34, 22),
			BackgroundColor3 = entry.color,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}, box)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, pip)
		make("UIStroke", { Name = "Stroke", Color = entry.color, Thickness = 1.5, Transparency = 0.3 }, pip)
		text(pip, {
			Name = "Check",
			Size = UDim2.fromScale(1, 0.9),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "✓",
			Visible = false,
		})
		keyPips[i] = pip
	end
	exitLabel = text(box, {
		Position = UDim2.new(0, 12, 0, 100),
		Size = UDim2.new(1, -24, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 230, 160),
		Text = "EXIT: 0/5",
	})

	staminaBack = make("Frame", {
		Name = "Stamina",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -136),
		Size = UDim2.new(0, 260, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, staminaBack)
	staminaFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(220, 220, 210),
		BorderSizePixel = 0,
	}, staminaBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, staminaFill)

	-- rødt skjær og nedtelling mens du ligger nede
	downedFrame = make("Frame", {
		Name = "Downed",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, hud)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Rotation = 90,
	}, downedFrame)
	downedLabel = text(hud, {
		Name = "DownedText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(0.6, 0, 0, 64),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 120, 110),
		Visible = false,
		ZIndex = 2,
	})

	-- pusten mens du gjemmer deg i et skap
	breathBack = make("Frame", {
		Name = "Breath",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -186),
		Size = UDim2.new(0, 260, 0, 10),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, breathBack)
	breathFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 200, 235),
		BorderSizePixel = 0,
	}, breathBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, breathFill)
	breathLabel = text(breathBack, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.new(1, 60, 0, 22),
		Text = "",
		Font = FONT_VHS,
	})

	hintLabel = text(hud, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.new(0.6, 0, 0, 30),
		Text = "",
		Visible = false,
	})
	leaveButton = make("TextButton", {
		Name = "LeaveButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.new(0, 220, 0, 52),
		BackgroundColor3 = Color3.fromRGB(30, 30, 26),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "LEAVE LOCKER  [E]",
		TextColor3 = Color3.fromRGB(240, 232, 200),
		Font = FONT_TEXT,
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, leaveButton)
	make("UIStroke", { Color = Color3.fromRGB(150, 140, 100), Thickness = 1.5 }, leaveButton)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, leaveButton)
	leaveButton.Activated:Connect(function()
		if leaveCallback then
			leaveCallback()
		end
	end)

	spectateLabel = text(gui, {
		Name = "Spectate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.6, 0, 0, 34),
		Text = "",
		Visible = false,
		ZIndex = 3,
	})

	finaleLabel = text(gui, {
		Name = "Finale",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(0.6, 0, 0, 34),
		Text = "",
		Font = Enum.Font.RobotoMono,
		TextColor3 = Color3.fromRGB(255, 70, 60),
		Visible = false,
		ZIndex = 4,
	})

	notifyList = make("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.new(0.7, 0, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, gui)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
	}, notifyList)
end

local function makeSlot(name: string, key: string, iconText: string, labelText: string)
	local slot = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 66, 0, 92),
	}, actionBar)
	local button = make("TextButton", {
		Name = "Button",
		Size = UDim2.new(0, 66, 0, 66),
		BackgroundColor3 = Color3.fromRGB(14, 12, 8),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		ZIndex = 6,
	}, slot)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
	local stroke = make("UIStroke", { Name = "Stroke", Color = Color3.fromRGB(206, 190, 140), Transparency = 0.45, Thickness = 1.5 }, button)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local icon = make("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 9),
		Size = UDim2.new(0, 34, 0, 32),
		Text = iconText,
		TextScaled = true,
		Font = Enum.Font.BuilderSans,
		ZIndex = 7,
	}, button)
	make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -4, 0, 12),
		Text = labelText,
		TextScaled = true,
		Font = Enum.Font.BuilderSansBold,
		TextColor3 = Color3.fromRGB(232, 226, 204),
		ZIndex = 7,
	}, button)
	make("TextLabel", {
		Name = "Key",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 5, 0, 3),
		Size = UDim2.new(0, math.max(12, #key * 7), 0, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = key,
		TextScaled = true,
		Font = Enum.Font.RobotoMono,
		TextColor3 = Color3.fromRGB(189, 181, 156),
		ZIndex = 7,
	}, button)
	local lock = make("TextLabel", {
		Name = "Lock",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -14, 0, -8),
		Size = UDim2.new(0, 22, 0, 22),
		Text = "🔒",
		TextScaled = true,
		Visible = false,
		ZIndex = 8,
	}, button)
	local cooldown = make("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, button)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, cooldown)
	local price = make("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 71),
		Size = UDim2.new(0, 56, 0, 18),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, slot)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, price)
	local priceText = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextScaled = true,
		Font = Enum.Font.BuilderSansBold,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 7,
	}, price)
	make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, price)
	local s: Slot = {
		button = button,
		icon = icon,
		lock = lock,
		price = price,
		priceText = priceText,
		cooldown = cooldown,
		cooldownUntil = 0,
		cooldownLength = 1,
		callback = nil,
	}
	button.Activated:Connect(function()
		if s.callback then
			s.callback()
		end
	end)
	slots[name] = s
	return s
end

local function buildActionBar()
	actionBar = make("Frame", {
		Name = "ActionBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 300, 0, 92),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, hud)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, actionBar)
	actionScale = make("UIScale", { Scale = 1 }, actionBar)
	makeSlot("Flashlight", "1", "🔦", "FLASHLIGHT").button.Parent.LayoutOrder = 1
	makeSlot("Push", "2", "✋", "PUSH").button.Parent.LayoutOrder = 2
	makeSlot("Jumpscare", "3", "💀", "JUMPSCARE").button.Parent.LayoutOrder = 3
	-- Løp: hold SHIFT (eller hold inne knappen på mobil)
	makeSlot("Run", "SHIFT", "🏃", "RUN").button.Parent.LayoutOrder = 4
end

local function buildOverlays()
	UI.jumpscareLayer = make("Frame", {
		Name = "Jumpscare",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
	}, gui)

	fadeFrame = make("Frame", {
		Name = "Fade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, gui)
	fadeLabel = text(fadeFrame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.3),
		Text = "",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 31,
	})

	captionLabel = text(gui, {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.new(0.7, 0, 0, 36),
		Text = "",
		Font = FONT_VHS,
		Visible = false,
		ZIndex = 32,
	})
	titleCard = make("Frame", {
		Name = "TitleCard",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 35,
	}, gui)
	titleMain = text(titleCard, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.7, 0.2),
		Text = "",
		TextColor3 = Color3.fromRGB(220, 30, 30),
		Font = FONT_TEXT,
		ZIndex = 36,
	})
	titleSub = text(titleCard, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.5, 0.07),
		Text = "",
		TextColor3 = Color3.fromRGB(235, 235, 225),
		Font = FONT_VHS,
		ZIndex = 36,
	})

	panelDim = make("Frame", {
		Name = "PanelDim",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 39,
	}, gui)
	panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 470, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
	make("UIStroke", { Color = Color3.fromRGB(120, 20, 20), Thickness = 2 }, panel)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 26),
		PaddingRight = UDim.new(0, 26),
	}, panel)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
	}, panel)
	make("UIScale", { Name = "Scale" }, panel)
	-- En usynlig "Modal"-knapp gjør musa fri (også i førsteperson) så lenge panelet vises
	make("TextButton", {
		Name = "MouseUnlock",
		Modal = true,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(0, 1, 0, 1),
		LayoutOrder = 0,
		ZIndex = 41,
	}, panel)
	panelTitle = text(panel, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 52),
		TextColor3 = Color3.fromRGB(220, 40, 40),
		TextWrapped = true,
		ZIndex = 41,
	})
	panelText = text(panel, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = Color3.fromRGB(220, 220, 210),
		TextWrapped = true,
		ZIndex = 41,
	})
	reviveButton = make("TextButton", {
		Name = "Revive",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(28, 112, 52),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		ZIndex = 42,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, reviveButton)
	make("UIStroke", { Color = Color3.fromRGB(111, 210, 138), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, reviveButton)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 170)),
		Rotation = 90,
	}, reviveButton)
	local reviveRow = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 220, 0, 30),
		ZIndex = 43,
	}, reviveButton)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}, reviveRow)
	text(reviveRow, {
		Size = UDim2.new(0, 96, 0, 26),
		Text = "REVIVE",
		TextColor3 = Color3.fromRGB(240, 240, 235),
		ZIndex = 44,
	})
	local pill = make("Frame", {
		Size = UDim2.new(0, 76, 0, 26),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 44,
	}, reviveRow)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
	reviveCost = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = ROBUX .. " 39",
		TextScaled = true,
		Font = Enum.Font.BuilderSansBold,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 45,
	}, pill)
	make("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, pill)
	reviveButton.Activated:Connect(function()
		if reviveCallback then
			reviveCallback()
		end
	end)
	panelButtons = make("Frame", {
		LayoutOrder = 4,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 41,
	}, panel)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
	}, panelButtons)
	panelTimer = text(panel, {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = Color3.fromRGB(160, 160, 150),
		ZIndex = 41,
	})
end

function UI.init()
	gui = make("ScreenGui", {
		Name = "HorrorUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))
	buildVhs()
	buildHud()
	buildActionBar()
	buildOverlays()

	-- Animasjon av VHS-filteret
	local noiseTimer = 0
	local trackingY = -0.1
	RunService.RenderStepped:Connect(function(dt)
		UI.updateActionBar()
		local t = os.clock()
		-- Tidsstempel som på et gammelt videokamera
		local elapsed = math.floor(t - recordStart)
		local h = 3 + math.floor(elapsed / 3600)
		local m = 13 + math.floor(elapsed / 60) % 60
		local s = elapsed % 60
		if m >= 60 then
			m -= 60
			h += 1
		end
		timeLabel.Text = string.format("OCT. 02 1997   %02d:%02d:%02d", h, m, s)
		if vhsMode == "match" then
			recLabel.Text = (math.floor(t * 1.5) % 2 == 0) and "● REC" or "   REC"
			recLabel.TextColor3 = Color3.fromRGB(235, 40, 40)
		else
			recLabel.Text = "▶ PLAY"
			recLabel.TextColor3 = Color3.fromRGB(235, 235, 230)
		end

		-- Sporingsstripe som glir nedover skjermen
		trackingY += dt * 0.25
		if trackingY > 1.2 then
			trackingY = -0.1 - math.random() * 0.6
		end
		trackingBar.Position = UDim2.fromScale(0, trackingY)

		-- Støy
		local intensity = math.max(noiseIntensity, noiseOverride)
		noiseTimer += dt
		if intensity > 0.02 then
			noiseFrame.Visible = true
			if noiseTimer > 0.05 then
				noiseTimer = 0
				local active = math.floor(#noiseLines * intensity + 0.5)
				for i, line in noiseLines do
					if i <= active then
						local g = 0.55 + math.random() * 0.45
						line.BackgroundColor3 = Color3.new(g, g, g * 0.9)
						line.Position = UDim2.new(math.random() * 0.3 - 0.15, 0, math.random(), 0)
						line.Size = UDim2.new(0.6 + math.random() * 0.8, 0, 0, math.random(1, 3))
						line.BackgroundTransparency = 1 - (0.2 + math.random() * 0.5) * intensity
					else
						line.BackgroundTransparency = 1
					end
				end
				noiseFlash.BackgroundTransparency = 1 - intensity * 0.06 * math.random()
			end
		else
			noiseFrame.Visible = false
		end
	end)
end

function UI.setVhsMode(mode: string)
	vhsMode = mode
	recordStart = os.clock()
	channelLabel.Text = mode == "match" and "CAM 04" or "CH 03"
end

function UI.setNoise(intensity: number)
	noiseIntensity = math.clamp(intensity, 0, 1)
end

function UI.setNoiseOverride(intensity: number)
	noiseOverride = math.clamp(intensity, 0, 1)
end

function UI.setMatchHud(visible: boolean)
	hud.Visible = visible
	if not visible then
		hintLabel.Visible = false
		staminaBack.Visible = false
	end
end

function UI.setLives(lives: number, max: number)
	local parts = {}
	for i = 1, max do
		table.insert(parts, i <= lives and '<font color="#dc2828">♥</font>' or '<font color="#3c3c3c">♥</font>')
	end
	livesLabel.Text = table.concat(parts, " ")
end

function UI.setKeys(carried: { number }, unlocked: { [number]: boolean }, inserted: number)
	keysLabel.Text = "KEYS CARRIED: " .. #carried
	exitLabel.Text = "EXIT: " .. inserted .. "/" .. #Config.KeyColors
	local held = {}
	for _, n in carried do
		held[n] = true
	end
	for i, pip in keyPips do
		local stroke = pip:FindFirstChild("Stroke") :: UIStroke
		local check = pip:FindFirstChild("Check") :: TextLabel
		local color = Config.KeyColors[i].color
		if unlocked[i] then
			pip.BackgroundTransparency = 0.05
			stroke.Color = color
			stroke.Transparency = 0
			check.Visible = true
		elseif held[i] then
			pip.BackgroundTransparency = 0
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Transparency = 0
			check.Visible = false
		else
			pip.BackgroundTransparency = 0.85
			stroke.Color = color
			stroke.Transparency = 0.45
			check.Visible = false
		end
	end
end

function UI.setStamina(fraction: number, visible: boolean)
	staminaBack.Visible = visible
	staminaFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	staminaFill.BackgroundColor3 = fraction < 0.25 and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(220, 220, 210)
end

-- Mens du ligger nede (nil = skjul)
function UI.setDowned(secondsLeft: number?)
	downedFrame.Visible = secondsLeft ~= nil
	downedLabel.Visible = secondsLeft ~= nil
	if secondsLeft then
		downedLabel.Text = string.format("YOU'RE DOWN\nWait for a friend to help you up  %d", math.ceil(secondsLeft))
	end
end

-- Hvor mye pust du har igjen i skapet (nil = skjul)
function UI.setBreath(fraction: number?, secondsLeft: number?)
	breathBack.Visible = fraction ~= nil
	if fraction then
		breathFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		local low = (secondsLeft or 99) <= 5
		breathFill.BackgroundColor3 = if low then Color3.fromRGB(230, 70, 60) else Color3.fromRGB(150, 200, 235)
		breathLabel.Text = string.format("HOLDING YOUR BREATH  %d", math.ceil(secondsLeft or 0))
		breathLabel.TextColor3 = if low then Color3.fromRGB(240, 110, 100) else Color3.fromRGB(220, 225, 230)
	end
end

function UI.setHint(message: string?)
	hintLabel.Visible = message ~= nil
	hintLabel.Text = message or ""
end

function UI.setCaption(message: string?)
	captionLabel.Visible = message ~= nil
	captionLabel.Text = message or ""
end

-- Skriver tekst bokstav for bokstav på svart skjerm (uten å tone inn igjen etterpå)
function UI.typeOnBlack(lines: { string }, holdTime: number, color: Color3?)
	fadeFrame.BackgroundTransparency = 0
	fadeLabel.TextTransparency = 0
	fadeLabel.TextStrokeTransparency = 1
	fadeLabel.Font = FONT_VHS
	fadeLabel.TextColor3 = color or Color3.fromRGB(235, 235, 230)
	local full = table.concat(lines, "\n")
	local count = 0
	for position in utf8.codes(full) do
		count += 1
		local nextPos = utf8.offset(full, 2, position) or (#full + 1)
		fadeLabel.Text = string.sub(full, 1, nextPos - 1)
		if count % 2 == 0 then
			task.wait(0.03)
		end
	end
	task.wait(holdTime)
	fadeLabel.TextColor3 = Color3.fromRGB(235, 235, 230)
	fadeLabel.Font = FONT_TEXT
end

function UI.showTitleCard(title: string, subtitle: string)
	titleCard.Visible = true
	titleMain.Text = title
	titleSub.Text = subtitle
	-- litt glitch: tittelen blinker og hopper de første sekundene
	task.spawn(function()
		local start = os.clock()
		while titleCard.Visible and os.clock() - start < 4 do
			local glitch = math.random() < 0.25
			titleMain.Position = UDim2.fromScale(0.5 + (glitch and (math.random() - 0.5) * 0.02 or 0), 0.44)
			titleMain.TextTransparency = glitch and 0.5 or 0
			task.wait(0.06)
		end
		titleMain.Position = UDim2.fromScale(0.5, 0.44)
		titleMain.TextTransparency = 0
	end)
end

function UI.hideTitleCard()
	titleCard.Visible = false
end

function UI.setFinaleTimer(message: string?)
	finaleLabel.Visible = message ~= nil
	if message then
		finaleLabel.Text = message
		finaleLabel.TextTransparency = (math.floor(os.clock() * 2) % 2 == 0) and 0 or 0.25
	end
end

function UI.setLeaveButton(visible: boolean)
	leaveButton.Visible = visible
end

function UI.onLeaveClicked(callback: () -> ())
	leaveCallback = callback
end

function UI.setSpectate(message: string?)
	spectateLabel.Visible = message ~= nil
	spectateLabel.Text = message or ""
end

local KIND_COLORS = {
	good = Color3.fromRGB(150, 235, 160),
	bad = Color3.fromRGB(240, 80, 70),
	info = Color3.fromRGB(230, 230, 220),
}

function UI.notify(message: string, kind: string?)
	local label = text(notifyList, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = message,
		TextColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		LayoutOrder = math.floor(os.clock() * 100),
		ZIndex = 4,
	})
	local children = notifyList:GetChildren()
	local count = 0
	for _, c in children do
		if c:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 4 then
		for _, c in children do
			if c:IsA("TextLabel") and c ~= label then
				c:Destroy()
				break
			end
		end
	end
	task.delay(3.5, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(1)
			label:Destroy()
		end
	end)
end

function UI.fadeOut(message: string?, duration: number?)
	local d = duration or 0.8
	fadeLabel.Text = message or ""
	TweenService:Create(fadeFrame, TweenInfo.new(d), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(fadeLabel, TweenInfo.new(d), { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
end

function UI.fadeIn(duration: number?)
	local d = duration or 1
	TweenService:Create(fadeFrame, TweenInfo.new(d), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(fadeLabel, TweenInfo.new(d * 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

function UI.setFadeText(message: string)
	fadeLabel.Text = message
end

-- Introtekst i VHS-stil når runden starter
function UI.intro(lines: { string }, holdTime: number)
	fadeFrame.BackgroundTransparency = 0
	fadeLabel.TextTransparency = 0
	fadeLabel.TextStrokeTransparency = 1
	fadeLabel.Font = FONT_VHS
	local full = table.concat(lines, "\n")
	local count = 0
	for position in utf8.codes(full) do
		count += 1
		local nextPos = utf8.offset(full, 2, position) or (#full + 1)
		fadeLabel.Text = string.sub(full, 1, nextPos - 1)
		if count % 2 == 0 then
			task.wait(0.02)
		end
	end
	task.wait(holdTime)
	UI.fadeIn(1.2)
	task.delay(1.3, function()
		fadeLabel.Font = FONT_TEXT
	end)
end

local function clearButtons()
	for _, c in panelButtons:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
end

local function button(label: string, color: Color3, callback: () -> (), width: number?)
	local b = make("TextButton", {
		Size = UDim2.new(0, width or 150, 0, 50),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = Color3.fromRGB(240, 240, 235),
		Font = FONT_TEXT,
		TextScaled = true,
		AutoButtonColor = true,
		ZIndex = 42,
	}, panelButtons)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, b)
	b.Activated:Connect(callback)
	return b
end

local function countdown(seconds: number, format: string, onDone: (() -> ())?)
	panelToken += 1
	local token = panelToken
	task.spawn(function()
		local left = seconds
		while left >= 0 and token == panelToken and panel.Visible do
			panelTimer.Text = string.format(format, left)
			task.wait(1)
			left -= 1
		end
		if onDone and token == panelToken and panel.Visible then
			onDone()
		end
	end)
end

local function refreshRevive()
	if reviveCredits > 0 then
		reviveCost.Text = "FREE ×" .. reviveCredits
	else
		reviveCost.Text = ROBUX .. " " .. revivePrice
	end
end

local function showPanel(title: string, body: string, titleColor: Color3?)
	panelDim.Visible = true
	panel.Visible = true
	panelTitle.Text = title
	panelTitle.TextColor3 = titleColor or Color3.fromRGB(220, 40, 40)
	panelTitle.Size = UDim2.new(1, 0, 0, #title > 14 and 84 or 52)
	panelText.Text = body
	panelText.Size = UDim2.new(1, 0, 0, string.find(body, "\n") and 48 or 24)
	clearButtons()
	reviveButton.Visible = false
	reviveCallback = nil
end

function UI.setRevive(credits: number, price: number)
	reviveCredits = credits
	revivePrice = price
	refreshRevive()
end

-- Du har brukt opp alle livene, men andre spiller fortsatt
function UI.showDeath(seconds: number, onRevive: () -> (), onSpectate: () -> ())
	showPanel("YOU DIED", "You have no lives left.")
	reviveButton.Visible = true
	reviveCallback = onRevive
	refreshRevive()
	local done = false
	local function spectate()
		if done then
			return
		end
		done = true
		onSpectate()
	end
	button("SPECTATE", Color3.fromRGB(40, 40, 44), spectate, 418)
	countdown(seconds, "Spectating in %d seconds", spectate)
end

function UI.showGameOver(seconds: number, onChoice: (string) -> (), onRevive: () -> ())
	showPanel("EVERYONE WAS CAUGHT", "It found all of you.")
	reviveButton.Visible = true
	reviveCallback = onRevive
	refreshRevive()
	local chosen = false
	local function choose(choice: string)
		if chosen then
			return
		end
		chosen = true
		clearButtons()
		reviveButton.Visible = false
		panelText.Text = choice == "retry" and "Waiting for the others..." or "Returning to the lobby..."
		onChoice(choice)
	end
	button("TRY AGAIN", Color3.fromRGB(110, 24, 24), function()
		choose("retry")
	end)
	button("TO LOBBY", Color3.fromRGB(40, 40, 44), function()
		choose("lobby")
	end)
	countdown(seconds, "Lobby in %d seconds")
end

function UI.hidePanels()
	panelToken += 1
	panel.Visible = false
	panelDim.Visible = false
	reviveButton.Visible = false
	reviveCallback = nil
	clearButtons()
end

function UI.isPanelOpen(): boolean
	return panel.Visible
end

------------------------------------------------------------------
-- Knappene nederst
------------------------------------------------------------------

function UI.setActionBar(visible: boolean)
	actionBar.Visible = visible
end

function UI.onAction(name: string, callback: () -> ())
	slots[name].callback = callback
end

local function setLit(s: Slot, lit: boolean)
	local stroke = s.button:FindFirstChild("Stroke") :: UIStroke
	stroke.Color = lit and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(206, 190, 140)
	stroke.Transparency = lit and 0.05 or 0.45
end

-- Knapper som skal holdes inne (løp på mobil)
function UI.onActionHold(name: string, onDown: () -> (), onUp: () -> ())
	local button = slots[name].button
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onDown()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onUp()
		end
	end)
end

function UI.setRunning(on: boolean)
	setLit(slots.Run, on)
end

function UI.setFlashlightOn(on: boolean)
	setLit(slots.Flashlight, on)
end

function UI.setPush(owned: boolean, price: number)
	local s = slots.Push
	s.lock.Visible = not owned
	s.price.Visible = not owned
	s.priceText.Text = ROBUX .. " " .. price
	s.icon.TextTransparency = owned and 0 or 0.45
end

function UI.setJumpscare(credits: number, price: number)
	local s = slots.Jumpscare
	s.price.Visible = true
	s.priceText.Text = credits > 0 and ("FREE ×" .. credits) or (ROBUX .. " " .. price)
end

function UI.startCooldown(name: string, seconds: number)
	local s = slots[name]
	s.cooldownUntil = os.clock() + seconds
	s.cooldownLength = seconds
end

local touchLayout: boolean? = nil

-- Mobil: knappene nede til høyre, rett ved siden av Roblox sin hoppeknapp (der tommelen er),
-- litt større, og uten tastene (1, 2, 3, SHIFT) på knappene
local function applyTouchLayout(touch: boolean, view: Vector2)
	if touch then
		local minAxis = math.min(view.X, view.Y)
		local jumpSize = if minAxis <= 500 then 70 else 120
		local jumpLeft = jumpSize * 1.5 - 10 -- avstand fra høyre kant til venstre side av hoppeknappen
		actionBar.AnchorPoint = Vector2.new(1, 1)
		actionBar.Position = UDim2.new(1, -(jumpLeft + 14), 1, -10)
	else
		actionBar.AnchorPoint = Vector2.new(0.5, 1)
		actionBar.Position = UDim2.new(0.5, 0, 1, -24)
	end
	if touchLayout ~= touch then
		touchLayout = touch
		local layout = actionBar:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.HorizontalAlignment = if touch then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Center
		end
		for _, s in slots do
			local keyLabel = s.button:FindFirstChild("Key")
			if keyLabel and keyLabel:IsA("TextLabel") then
				keyLabel.Visible = not touch
			end
		end
		leaveButton.Text = if touch then "LEAVE LOCKER" else "LEAVE LOCKER  [E]"
	end
end

function UI.updateActionBar()
	local cam = workspace.CurrentCamera
	if cam then
		local view = cam.ViewportSize
		local touch = UI.isTouch()
		local minScale = if touch then 0.9 else 0.75
		actionScale.Scale = math.clamp(view.Y / 720, minScale, 1.25)
		applyTouchLayout(touch, view)
		-- menyene (YOU DIED osv.) krympes så de får plass på små mobilskjermer
		local panelScale = panel:FindFirstChild("Scale")
		if panelScale and panelScale:IsA("UIScale") then
			panelScale.Scale = math.clamp(math.min(view.X / 560, view.Y / 500), 0.6, 1.2)
		end
	end
	local now = os.clock()
	for _, s in slots do
		local left = s.cooldownUntil - now
		s.cooldown.Size = UDim2.fromScale(1, left > 0 and math.clamp(left / s.cooldownLength, 0, 1) or 0)
	end
end

return UI
