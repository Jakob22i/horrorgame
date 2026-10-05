-- Pop-upen for communityet: trykk på plakaten ved spawn i lobbyen, bli med i Roblox-gruppa og få
-- 15 mynter (én gang). Den store knappen gjør neste steg: JOIN COMMUNITY åpner Roblox sin egen
-- "Join"-boks, og når du er med, hentes myntene av seg selv (serveren sjekker medlemskapet).
-- Har du fått myntene, får plakaten et grønt "CLAIMED ✓"-stempel hos deg.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Screen = require(script.Parent:WaitForChild("Screen"))
local CommunityRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Community") :: RemoteEvent

local player = Players.LocalPlayer

local CommunityUI = {}

local C = Config.Community
local FONT = Enum.Font.SpecialElite
local MONO = Enum.Font.RobotoMono
local GOLD = Color3.fromRGB(255, 205, 90)
local TEXT = Color3.fromRGB(235, 230, 215)
local DIM = Color3.fromRGB(150, 140, 125)
local OFF = Color3.fromRGB(34, 30, 26)
local GREEN = Color3.fromRGB(40, 110, 60)
local DONE = Color3.fromRGB(60, 170, 90)
local RED = Color3.fromRGB(235, 90, 70)
local WIDTH, HEIGHT = 360, 336

-- loading | join | joining | claim | claiming | pending | claimed | error
local state = "loading"
local message = ""

local gui: ScreenGui
local backdrop: TextButton
local window: Frame
local scale: UIScale
local closeButton: TextButton
local coinScale: UIScale
local floatLabel: TextLabel
local steps: { { badge: Frame, mark: TextLabel, label: TextLabel } } = {}
local mainButton: TextButton
local mainCaption: TextLabel
local statusLabel: TextLabel
local openPrompt: ProximityPrompt? = nil
local claimSound: Sound

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
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = TEXT,
		Font = MONO,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

-- Gullmynt (samme som i butikken)
local function coin(parent: Instance, size: number, position: UDim2): Frame
	local c = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	make("UIStroke", { Color = Color3.fromRGB(150, 100, 30), Thickness = math.max(1, size / 12) }, c)
	local inner = make("Frame", {
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 160, 50),
		BorderSizePixel = 0,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, inner)
	text(inner, {
		Size = UDim2.fromScale(0.8, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(110, 66, 16),
		Text = tostring(C.Reward),
	})
	return c
end

------------------------------------------------------------------
-- Visning
------------------------------------------------------------------
local BUTTON = {
	loading = { "CHECKING...", OFF, false },
	join = { "JOIN COMMUNITY", GREEN, true },
	joining = { "WAITING FOR ROBLOX...", OFF, false },
	claim = { "CLAIM " .. C.Reward .. " COINS", Color3.fromRGB(150, 108, 28), true },
	claiming = { "CHECKING...", OFF, false },
	pending = { "CHECK AGAIN", GREEN, true },
	claimed = { "CLAIMED ✓", Color3.fromRGB(30, 80, 44), false },
	error = { "TRY AGAIN", GREEN, true },
}

local function setStep(i: number, done: boolean)
	local step = steps[i]
	step.badge.BackgroundColor3 = if done then DONE else OFF
	step.mark.Text = if done then "✓" else tostring(i)
	step.mark.TextColor3 = if done then Color3.new(1, 1, 1) else DIM
	step.label.TextColor3 = if done then DIM else TEXT
end

local function render()
	local b = BUTTON[state] or BUTTON.loading
	mainCaption.Text = b[1]
	mainButton.BackgroundColor3 = b[2]
	mainButton.AutoButtonColor = b[3]
	mainCaption.TextColor3 = if b[3] or state == "claimed" then Color3.fromRGB(245, 245, 235) else DIM
	local member = state == "claim" or state == "claiming" or state == "claimed"
	setStep(1, member)
	setStep(2, state == "claimed")
	statusLabel.Text = message
	statusLabel.TextColor3 = if state == "error" then RED elseif state == "claimed" then DONE else DIM
end

local function setState(newState: string, newMessage: string?)
	state = newState
	message = newMessage or ""
	if window then
		render()
	end
end

-- Mynten spretter og "+15" flyter opp
local function celebrate()
	claimSound:Play()
	coinScale.Scale = 1
	TweenService:Create(coinScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.35 }):Play()
	task.delay(0.25, function()
		TweenService:Create(coinScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
	floatLabel.Position = UDim2.new(0, 46, 0, 8)
	floatLabel.TextTransparency = 0
	floatLabel.TextStrokeTransparency = 0.4
	floatLabel.Visible = true
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(floatLabel, info, { Position = UDim2.new(0, 46, 0, -34), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

------------------------------------------------------------------
-- Handlinger
------------------------------------------------------------------
local function claim()
	setState("claiming", "Checking your membership...")
	CommunityRemote:FireServer("claim")
end

local function join()
	setState("joining", "Accept in the Roblox window.")
	task.spawn(function()
		local ok, result = pcall(function()
			return GroupService:PromptJoinAsync(C.GroupId)
		end)
		if state ~= "joining" then
			return
		end
		if ok and (result == Enum.GroupMembershipStatus.Joined or result == Enum.GroupMembershipStatus.AlreadyMember) then
			claim()
		elseif ok and result == Enum.GroupMembershipStatus.JoinRequestPending then
			setState("pending", "Request sent. Waiting for approval.")
		elseif ok then
			setState("join", "No problem. The coins are waiting!")
		else
			setState("join", "Search \"" .. C.Name .. "\" on Roblox.")
		end
	end)
end

local function onMainButton()
	if state == "join" then
		join()
	elseif state == "claim" or state == "pending" then
		claim()
	elseif state == "error" then
		setState("loading")
		CommunityRemote:FireServer("check")
	end
end

-- Svar fra serveren (Community.luau)
local function onReply(action: any, status: any)
	if not window.Visible then
		return
	end
	if status == "claimed" then
		local fresh = action == "claim"
		setState("claimed", "Thanks for joining! Enjoy the coins.")
		if fresh then
			celebrate()
		end
	elseif status == "member" then
		setState("claim", "You are in! Claim your coins.")
	elseif status == "notMember" then
		setState("join", if action == "claim" then "Not in the community yet." else "")
	else
		setState("error", "Could not reach Roblox. Try again.")
	end
end

function CommunityUI.open(prompt: ProximityPrompt?)
	openPrompt = prompt
	backdrop.Visible = true
	window.Visible = true
	if player:GetAttribute("CommunityClaimed") == true then
		setState("claimed", "Thanks for joining! Enjoy the coins.")
	else
		setState("loading")
		CommunityRemote:FireServer("check")
	end
end

function CommunityUI.close()
	backdrop.Visible = false
	window.Visible = false
	openPrompt = nil
end

------------------------------------------------------------------
-- Bygging
------------------------------------------------------------------
local function build()
	gui = make("ScreenGui", {
		Name = "Community",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- mørk bakgrunn; trykk utenfor vinduet for å lukke
	backdrop = make("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
	}, gui)
	backdrop.Activated:Connect(CommunityUI.close)

	window = make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Color3.fromRGB(14, 12, 10),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true, -- trykk inne i vinduet lukker det ikke
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, window)
	make("UIStroke", { Color = Color3.fromRGB(120, 90, 40), Thickness = 2 }, window)
	scale = make("UIScale", {}, window)
	-- gjør musa fri mens vinduet er åpent
	make("TextButton", { Name = "MouseUnlock", Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(1, 1) }, window)

	text(window, {
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(20, 16),
		Font = FONT,
		TextColor3 = GOLD,
		Text = "JOIN THE COMMUNITY",
	})
	text(window, {
		Size = UDim2.new(1, -80, 0, 15),
		Position = UDim2.fromOffset(20, 50),
		TextColor3 = DIM,
		Text = string.upper(C.Name),
	})
	closeButton = make("TextButton", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(110, 30, 26),
		BorderSizePixel = 0,
		Text = "X",
		Font = MONO,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(240, 230, 220),
	}, window)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, closeButton)
	make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }, closeButton)
	closeButton.Activated:Connect(CommunityUI.close)
	make("Frame", {
		Size = UDim2.new(1, -40, 0, 1),
		Position = UDim2.fromOffset(20, 76),
		BackgroundColor3 = Color3.fromRGB(120, 90, 40),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, window)

	-- belønningen
	local card = make("Frame", {
		Size = UDim2.new(1, -40, 0, 78),
		Position = UDim2.fromOffset(20, 90),
		BackgroundColor3 = Color3.fromRGB(29, 25, 20),
		BorderSizePixel = 0,
	}, window)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
	make("UIStroke", { Color = Color3.fromRGB(70, 60, 48), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	local bigCoin = coin(card, 52, UDim2.fromOffset(42, 39))
	coinScale = make("UIScale", {}, bigCoin)
	text(card, {
		Size = UDim2.new(1, -96, 0, 30),
		Position = UDim2.fromOffset(80, 12),
		Font = FONT,
		TextColor3 = GOLD,
		Text = "+" .. C.Reward .. " COINS",
	})
	text(card, {
		Size = UDim2.new(1, -96, 0, 15),
		Position = UDim2.fromOffset(80, 49),
		TextColor3 = DIM,
		Text = "One time only per player",
	})
	floatLabel = text(card, {
		Size = UDim2.fromOffset(80, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		TextStrokeColor3 = Color3.fromRGB(60, 36, 8),
		Text = "+" .. C.Reward,
		Visible = false,
		ZIndex = 3,
	})

	-- stegene
	for i, caption in { "Join " .. C.Name .. " on Roblox", "Get your " .. C.Reward .. " coins" } do
		local y = 184 + (i - 1) * 32
		local badge = make("Frame", {
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(22, y),
			BackgroundColor3 = OFF,
			BorderSizePixel = 0,
		}, window)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
		make("UIStroke", { Color = Color3.fromRGB(90, 76, 56), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
		local mark = text(badge, {
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold,
			Text = tostring(i),
		})
		local label = text(window, {
			Size = UDim2.new(1, -78, 0, 17),
			Position = UDim2.fromOffset(58, y + 4),
			Text = caption,
		})
		steps[i] = { badge = badge, mark = mark, label = label }
	end

	-- den store knappen
	mainButton = make("TextButton", {
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 256),
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
	}, window)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, mainButton)
	make("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.85, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, mainButton)
	mainCaption = text(mainButton, {
		Size = UDim2.new(1, -20, 0.46, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		Text = "",
	})
	mainButton.Activated:Connect(onMainButton)

	statusLabel = text(window, {
		Size = UDim2.new(1, -40, 0, 15),
		Position = UDim2.fromOffset(20, 312),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = DIM,
		Text = "",
	})

	claimSound = make("Sound", { SoundId = Config.Sounds.KeyPickup, Volume = 0.8 }, gui)
	render()
end

------------------------------------------------------------------
-- Plakaten: stempel og tekst på knappen når du har fått myntene
------------------------------------------------------------------
local function updatePoster()
	local lobby = workspace:FindFirstChild("Lobby")
	local poster = lobby and lobby:FindFirstChild("CommunityPoster")
	if not poster then
		return
	end
	local claimed = player:GetAttribute("CommunityClaimed") == true
	local paper = poster:FindFirstChild("Paper")
	local signGui = paper and paper:FindFirstChild("SignGui")
	local stamp = signGui and signGui:FindFirstChild("Claimed")
	if stamp and stamp:IsA("GuiObject") then
		stamp.Visible = claimed
	end
	local promptPart = poster:FindFirstChild("PromptPart")
	local prompt = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ActionText = if claimed then "Open" else "Join"
		prompt.ObjectText = if claimed then "Community ✓" else "Community · +" .. C.Reward .. " coins"
	end
end

function CommunityUI.init()
	build()
	CommunityRemote.OnClientEvent:Connect(onReply)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "CommunityPrompt" then
			CommunityUI.open(prompt)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and window.Visible then
			CommunityUI.close()
		end
	end)
	player:GetAttributeChangedSignal("CommunityClaimed"):Connect(updatePoster)

	local posterTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		-- plakaten kan bli lastet inn og ut (streaming), så sjekk den av og til
		posterTimer += dt
		if posterTimer > 1 then
			posterTimer = 0
			updatePoster()
		end
		if not window.Visible then
			return
		end
		-- midt i det trygge området; på mobil så stor som det er plass til
		local area = Screen.area()
		local fit = math.min(area.width * 0.9 / WIDTH, (area.height - 16) / HEIGHT)
		local wanted = if area.touch then fit else math.min(area.view.X / 1100, area.view.Y / 620, fit)
		scale.Scale = math.clamp(wanted, 0.55, 1.15)
		window.Position = UDim2.fromOffset(area.left + area.width / 2, area.top + area.height / 2)
		closeButton.Size = if area.touch then UDim2.fromOffset(40, 40) else UDim2.fromOffset(32, 32)
		-- lukk hvis du går fra plakaten eller en runde starter
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local promptPart = openPrompt and openPrompt.Parent
		if player:GetAttribute("InMatch") == true then
			CommunityUI.close()
		elseif root and promptPart and promptPart:IsA("BasePart") and (root.Position - promptPart.Position).Magnitude > 18 then
			CommunityUI.close()
		end
	end)
end

return CommunityUI
