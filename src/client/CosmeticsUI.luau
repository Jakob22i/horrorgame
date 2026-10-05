-- Butikken i lobbyen (mynter -> lommelyktfarger og titler) og myntene øverst på skjermen.
-- Åpnes med E ved disken "FLASHLIGHTS & TITLES" i lobbyen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
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
local inviteButton: TextButton
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
-- Kortene i butikken
------------------------------------------------------------------
local function card(item: any, kind: string, owned: { [string]: boolean }, order: number)
	local equipped = (kind == "Flashlights" and attr("FlashId") == item.id) or (kind == "Titles" and attr("TitleId") == item.id)
	local isOwned = owned[item.id] == true or item.price == 0
	local coins = attr("Coins") or 0

	local c = make("Frame", {
		Name = item.id,
		BackgroundColor3 = Color3.fromRGB(26, 22, 18),
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, grid)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, c)
	make("UIStroke", { Color = if equipped then GOLD else Color3.fromRGB(70, 60, 48), Thickness = if equipped then 2 else 1 }, c)

	-- forhåndsvisning
	if kind == "Flashlights" then
		local glow = make("Frame", {
			Size = UDim2.fromOffset(46, 46),
			Position = UDim2.new(0.5, 0, 0, 30),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = item.color,
			BorderSizePixel = 0,
		}, c)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
		make("UIStroke", { Color = item.color, Thickness = 4, Transparency = 0.6 }, glow)
	else
		label(c, {
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.new(0.5, 0, 0, 30),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = if item.text == "" then "—" else item.text,
			TextColor3 = item.color,
		})
	end
	label(c, {
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.new(0.5, 0, 0, 62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = item.name,
		Font = MONO,
	})

	local button = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = not equipped,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	local buttonText = label(button, {
		Size = UDim2.new(1, -10, 0.7, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = MONO,
		TextStrokeTransparency = 1,
	})
	if equipped then
		button.BackgroundColor3 = Color3.fromRGB(70, 56, 24)
		buttonText.Text = "EQUIPPED"
		buttonText.TextColor3 = GOLD
	elseif isOwned then
		button.BackgroundColor3 = Color3.fromRGB(40, 70, 46)
		buttonText.Text = "EQUIP"
	else
		local canAfford = coins >= item.price
		button.BackgroundColor3 = if canAfford then Color3.fromRGB(110, 80, 24) else Color3.fromRGB(46, 42, 38)
		buttonText.Text = "      " .. tostring(item.price)
		buttonText.TextColor3 = if canAfford then Color3.fromRGB(255, 236, 190) else Color3.fromRGB(150, 140, 125)
		coin(button, 16, UDim2.new(0.5, -26, 0.5, 0))
	end
	button.Activated:Connect(function()
		if equipped then
			return
		end
		CosmeticsRemote:FireServer(if isOwned then "equip" else "buy", item.id)
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
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local owned = ownedSet()
	for i, item in (Config.Cosmetics :: any)[currentTab] do
		card(item, currentTab, owned, i)
	end
	for name, button in tabs do
		local active = name == currentTab
		button.BackgroundColor3 = if active then Color3.fromRGB(110, 80, 24) else Color3.fromRGB(34, 30, 26)
	end
end

function CosmeticsUI.open(prompt: ProximityPrompt?)
	openPrompt = prompt
	window.Visible = true
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
		Size = UDim2.fromOffset(620, 440),
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
		Size = UDim2.new(0.6, 0, 0, 40),
		Position = UDim2.new(0, 20, 0, 14),
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

	grid = make("ScrollingFrame", {
		Size = UDim2.new(1, -40, 1, -150),
		Position = UDim2.new(0, 20, 0, 108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(136, 118),
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
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(view.X / 680, view.Y / 500), 0.55, 1.2)
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
