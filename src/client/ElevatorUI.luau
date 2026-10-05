-- Menyen som dukker opp når du står i en heis i lobbyen:
--  * hvem som er med (den første som gikk inn er verten)
--  * modus: NORMAL / NIGHTMARE
--  * hvor mange som får bli med (1–4)
--  * START NOW og LEAVE
-- Bare verten kan endre innstillingene og starte. Serveren sjekker alt (Lobby.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ElevatorRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Elevator") :: RemoteEvent

local player = Players.LocalPlayer

local ElevatorUI = {}

local MONO = Enum.Font.RobotoMono
local TITLE = Enum.Font.SpecialElite
local GOLD = Color3.fromRGB(255, 205, 90)
local TEXT = Color3.fromRGB(235, 230, 215)
local DIM = Color3.fromRGB(150, 140, 125)
local OFF = Color3.fromRGB(34, 30, 26)
local RED = Color3.fromRGB(235, 60, 50)

local panel: Frame
local title: TextLabel
local countLabel: TextLabel
local rows: { TextLabel } = {}
local modeButtons: { [string]: TextButton } = {}
local modeDesc: TextLabel
local maxButtons: { TextButton } = {}
local statusLabel: TextLabel
local hostNote: TextLabel
local startButton: TextButton
local leaveButton: TextButton
local scale: UIScale

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

local function button(parent: Instance, props: { [string]: any }, caption: string): TextButton
	local b = make("TextButton", {
		BackgroundColor3 = OFF,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = true,
	}, parent)
	for k, v in props do
		(b :: any)[k] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	text(b, {
		Name = "Caption",
		Size = UDim2.new(1, -10, 0.56, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = caption,
	})
	return b
end

local function caption(b: TextButton): TextLabel
	return b:FindFirstChild("Caption") :: TextLabel
end

local function currentElevator(): Instance?
	local index = player:GetAttribute("Elevator")
	if typeof(index) ~= "number" or player:GetAttribute("InMatch") == true then
		return nil
	end
	local lobby = workspace:FindFirstChild("Lobby")
	local folder = lobby and lobby:FindFirstChild("Elevators")
	return folder and folder:FindFirstChild("Elevator" .. index)
end

local function build()
	local gui = make("ScreenGui", {
		Name = "ElevatorMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 352),
		BackgroundColor3 = Color3.fromRGB(14, 12, 10),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	make("UIStroke", { Color = Color3.fromRGB(120, 90, 40), Thickness = 2 }, panel)
	scale = make("UIScale", {}, panel)

	title = text(panel, {
		Size = UDim2.fromOffset(190, 30),
		Position = UDim2.fromOffset(16, 12),
		Font = TITLE,
		TextColor3 = GOLD,
		Text = "ELEVATOR 1",
	})
	countLabel = text(panel, {
		Size = UDim2.fromOffset(80, 22),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "1/4",
	})

	-- spillerne
	for i = 1, Config.MaxPlayersPerElevator do
		rows[i] = text(panel, {
			Size = UDim2.fromOffset(268, 17),
			Position = UDim2.fromOffset(16, 48 + (i - 1) * 21),
			Text = "",
		})
	end

	-- modus
	text(panel, { Size = UDim2.fromOffset(120, 14), Position = UDim2.fromOffset(16, 138), Text = "MODE", TextColor3 = DIM })
	for i, mode in { "Normal", "Nightmare" } do
		local b = button(panel, {
			Size = UDim2.fromOffset(130, 30),
			Position = UDim2.fromOffset(16 + (i - 1) * 138, 156),
		}, string.upper(mode))
		b.Activated:Connect(function()
			ElevatorRemote:FireServer("mode", mode)
		end)
		modeButtons[mode] = b
	end
	modeDesc = text(panel, {
		Size = UDim2.fromOffset(268, 14),
		Position = UDim2.fromOffset(16, 191),
		TextColor3 = DIM,
		Text = "",
	})

	-- antall plasser
	text(panel, { Size = UDim2.fromOffset(160, 14), Position = UDim2.fromOffset(16, 214), Text = "MAX PLAYERS", TextColor3 = DIM })
	for n = 1, Config.MaxPlayersPerElevator do
		local b = button(panel, {
			Size = UDim2.fromOffset(62, 30),
			Position = UDim2.fromOffset(16 + (n - 1) * 69, 232),
		}, tostring(n))
		b.Activated:Connect(function()
			ElevatorRemote:FireServer("max", n)
		end)
		maxButtons[n] = b
	end

	statusLabel = text(panel, {
		Size = UDim2.fromOffset(268, 18),
		Position = UDim2.fromOffset(16, 272),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		Text = "",
	})
	hostNote = text(panel, {
		Size = UDim2.fromOffset(268, 12),
		Position = UDim2.fromOffset(16, 292),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = DIM,
		Text = "",
	})
	startButton = button(panel, {
		Size = UDim2.fromOffset(170, 34),
		Position = UDim2.fromOffset(16, 308),
		BackgroundColor3 = Color3.fromRGB(40, 110, 60),
	}, "START NOW")
	startButton.Activated:Connect(function()
		ElevatorRemote:FireServer("start")
	end)
	leaveButton = button(panel, {
		Size = UDim2.fromOffset(90, 34),
		Position = UDim2.fromOffset(194, 308),
		BackgroundColor3 = Color3.fromRGB(110, 30, 26),
	}, "LEAVE")
	leaveButton.Activated:Connect(function()
		ElevatorRemote:FireServer("leave")
	end)
end

local function update()
	local model = currentElevator()
	panel.Visible = model ~= nil
	if not model then
		return
	end
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(view.X / 1100, view.Y / 620), 0.55, 1.1)

	local index = model:GetAttribute("Index") or 1
	local mode = model:GetAttribute("Mode") or "Normal"
	local max = model:GetAttribute("MaxPlayers") or Config.MaxPlayersPerElevator
	local names = string.split(model:GetAttribute("Players") or "", "\n")
	if names[1] == "" then
		names = {}
	end
	local isHost = model:GetAttribute("Host") == player.UserId
	local status = model:GetAttribute("Status") or "waiting"
	local countdown = model:GetAttribute("Countdown") or -1
	local nightmare = mode == "Nightmare"

	title.Text = "ELEVATOR " .. index
	countLabel.Text = #names .. "/" .. max .. " PLAYERS"
	for i, row in rows do
		local name = names[i]
		if name then
			row.Text = (if i == 1 then "★ " else "• ") .. name .. (if i == 1 then "  (host)" else "")
			row.TextColor3 = if i == 1 then GOLD else TEXT
		elseif i <= max then
			row.Text = "· free spot"
			row.TextColor3 = DIM
		else
			row.Text = "✕ closed"
			row.TextColor3 = Color3.fromRGB(90, 82, 72)
		end
	end
	for name, b in modeButtons do
		local active = name == mode
		b.BackgroundColor3 = if not active then OFF elseif name == "Nightmare" then Color3.fromRGB(120, 24, 22) else Color3.fromRGB(110, 80, 24)
		caption(b).TextColor3 = if active then Color3.fromRGB(255, 240, 220) else DIM
		b.AutoButtonColor = isHost
	end
	modeDesc.Text = if nightmare then "1 life · faster · darker · 2x coins" else string.format("%d lives · the normal hospital", Config.Lives)
	modeDesc.TextColor3 = if nightmare then RED else DIM
	for n, b in maxButtons do
		local active = n == max
		local allowed = n >= math.max(1, #names)
		b.BackgroundColor3 = if active then Color3.fromRGB(110, 80, 24) else OFF
		caption(b).TextColor3 = if active then Color3.fromRGB(255, 240, 220) elseif allowed and isHost then TEXT else Color3.fromRGB(90, 82, 72)
		b.AutoButtonColor = isHost and allowed
	end
	if status == "departing" then
		statusLabel.Text = "GOING DOWN..."
		statusLabel.TextColor3 = RED
	elseif status == "busy" then
		statusLabel.Text = "ALL HOSPITALS BUSY — WAITING"
		statusLabel.TextColor3 = RED
	elseif countdown >= 0 then
		statusLabel.Text = "LEAVING IN " .. countdown
		statusLabel.TextColor3 = GOLD
	else
		statusLabel.Text = ""
	end
	hostNote.Text = if isHost then "You are the host." else ("Only " .. (names[1] or "the host") .. " can change this.")
	startButton.BackgroundColor3 = if isHost then Color3.fromRGB(40, 110, 60) else OFF
	caption(startButton).TextColor3 = if isHost then Color3.fromRGB(235, 255, 238) else Color3.fromRGB(90, 82, 72)
	startButton.AutoButtonColor = isHost
end

function ElevatorUI.init(_ui: any)
	build()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		update()
	end)
end

return ElevatorUI
