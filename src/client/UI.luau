-- Alt brukergrensesnitt: VHS-filter, HUD, beskjeder, overganger og menyer.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local UI = {}

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
local staminaBack: Frame
local staminaFill: Frame
local hintLabel: TextLabel
local spectateLabel: TextLabel
local notifyList: Frame
local fadeFrame: Frame
local fadeLabel: TextLabel
local panel: Frame
local panelTitle: TextLabel
local panelText: TextLabel
local panelButtons: Frame
local panelTimer: TextLabel

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
		Size = UDim2.new(0, 230, 0, 104),
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
	exitLabel = text(box, {
		Position = UDim2.new(0, 12, 0, 70),
		Size = UDim2.new(1, -24, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 230, 160),
		Text = "EXIT: 0/5",
	})

	staminaBack = make("Frame", {
		Name = "Stamina",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
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

	hintLabel = text(hud, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.new(0.6, 0, 0, 30),
		Text = "",
		Visible = false,
	})
	leaveButton = make("TextButton", {
		Name = "LeaveButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
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

	notifyList = make("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
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

	panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 520, 0, 300),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
	make("UIStroke", { Color = Color3.fromRGB(120, 20, 20), Thickness = 2 }, panel)
	make("UISizeConstraint", { MaxSize = Vector2.new(520, 300) }, panel)
	panelTitle = text(panel, {
		Position = UDim2.new(0, 20, 0, 18),
		Size = UDim2.new(1, -40, 0, 56),
		TextColor3 = Color3.fromRGB(220, 40, 40),
		ZIndex = 41,
	})
	panelText = text(panel, {
		Position = UDim2.new(0, 30, 0, 82),
		Size = UDim2.new(1, -60, 0, 70),
		TextColor3 = Color3.fromRGB(220, 220, 210),
		ZIndex = 41,
	})
	panelButtons = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 172),
		Size = UDim2.new(1, -40, 0, 64),
		ZIndex = 41,
	}, panel)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 16),
	}, panelButtons)
	panelTimer = text(panel, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -40, 0, 26),
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
	buildOverlays()

	-- Animasjon av VHS-filteret
	local noiseTimer = 0
	local trackingY = -0.1
	RunService.RenderStepped:Connect(function(dt)
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

function UI.setKeys(carried: number, inserted: number, total: number)
	keysLabel.Text = "KEYS CARRIED: " .. carried
	exitLabel.Text = "EXIT: " .. inserted .. "/" .. total
end

function UI.setStamina(fraction: number, visible: boolean)
	staminaBack.Visible = visible
	staminaFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	staminaFill.BackgroundColor3 = fraction < 0.25 and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(220, 220, 210)
end

function UI.setHint(message: string?)
	hintLabel.Visible = message ~= nil
	hintLabel.Text = message or ""
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

local function button(label: string, color: Color3, callback: () -> ())
	local b = make("TextButton", {
		Size = UDim2.new(0, 200, 0, 56),
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
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, b)
	b.Activated:Connect(callback)
	return b
end

local function countdown(seconds: number, format: string)
	panelToken += 1
	local token = panelToken
	task.spawn(function()
		local left = seconds
		while left >= 0 and token == panelToken and panel.Visible do
			panelTimer.Text = string.format(format, left)
			task.wait(1)
			left -= 1
		end
	end)
end

function UI.showGameOver(seconds: number, onChoice: (string) -> ())
	panel.Visible = true
	panelTitle.Text = "EVERYONE WAS CAUGHT"
	panelText.Text = "It found all of you.\nDo you want to try again from the start?"
	clearButtons()
	local chosen = false
	local function choose(choice: string)
		if chosen then
			return
		end
		chosen = true
		clearButtons()
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

function UI.showWin(escaper: string, seconds: number)
	panel.Visible = true
	panelTitle.Text = "YOU ESCAPED!"
	panelTitle.TextColor3 = Color3.fromRGB(150, 235, 160)
	panelText.Text = escaper .. " ran out the emergency exit.\nThe tape ends here... for now."
	clearButtons()
	countdown(seconds, "Back to the lobby in %d")
end

function UI.hidePanels()
	panelToken += 1
	panel.Visible = false
	panelTitle.TextColor3 = Color3.fromRGB(220, 40, 40)
	clearButtons()
end

return UI
