-- Lobbyen med fire heiser. Spillere som står i en heis blir med i den gruppa.
-- Når nedtellingen er ferdig lukkes dørene og gruppa sendes til sykehuset.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent:WaitForChild("Util"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local TransitionRemote = Remotes:WaitForChild("Transition") :: RemoteEvent

local TICK = 0.2
local GREEN = Color3.fromRGB(80, 220, 100)
local RED = Color3.fromRGB(230, 60, 50)
local YELLOW = Color3.fromRGB(255, 200, 80)

type Elevator = {
	index: number,
	model: Model,
	zone: BasePart,
	exitPoint: BasePart,
	doors: { { part: BasePart, open: CFrame, closed: CFrame } },
	status: TextLabel?,
	timer: TextLabel?,
	modeLabel: TextLabel?,
	panelLabel: TextLabel?,
	prompt: ProximityPrompt?,
	mode: string,
	indicator: BasePart?,
	doorSound: Sound?,
	order: { Player },
	countdown: number?,
	departing: boolean,
	waitingForRoom: boolean?,
	needle: BasePart?,
	needlePivot: CFrame,
	needleOffset: number,
	needleUp: number,
	needleDown: number,
	needleAngle: NumberValue?,
}

local Lobby = {}

local elevators: { Elevator } = {}

local function inZone(zone: BasePart, position: Vector3): boolean
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function setDoors(e: Elevator, open: boolean)
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	for _, d in e.doors do
		TweenService:Create(d.part, info, { CFrame = open and d.open or d.closed }):Play()
	end
	if e.doorSound and Config.Sounds.Elevator ~= "" then
		e.doorSound.SoundId = Config.Sounds.Elevator
		e.doorSound:Play()
	end
end

local NIGHTMARE = Color3.fromRGB(235, 50, 50)
local NORMAL = Color3.fromRGB(200, 220, 200)

-- Viseren over døra: peker på L (lobbyen) og går ned til B3 når heisen går
local function moveNeedle(e: Elevator, angle: number, seconds: number)
	local value = e.needleAngle
	if not value then
		return
	end
	TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = angle }):Play()
end

local function updateSign(e: Elevator)
	local count = #e.order
	local max = Config.MaxPlayersPerElevator
	local nightmare = e.mode == "Nightmare"
	if e.modeLabel then
		e.modeLabel.Text = if nightmare then "NIGHTMARE" else "NORMAL"
		e.modeLabel.TextColor3 = if nightmare then NIGHTMARE else NORMAL
	end
	if e.panelLabel then
		e.panelLabel.Text = if nightmare then "NIGHTMARE\n1 LIFE" else "NORMAL\n3 LIVES"
		e.panelLabel.TextColor3 = if nightmare then NIGHTMARE else NORMAL
	end
	if e.prompt then
		e.prompt.ObjectText = if nightmare then "Mode: Nightmare" else "Mode: Normal"
	end
	if e.status then
		e.status.Text = count .. "/" .. max .. " PLAYERS"
	end
	if e.timer then
		if e.departing then
			e.timer.Text = "DEPARTING..."
			e.timer.TextColor3 = RED
		elseif e.waitingForRoom then
			e.timer.Text = "ALL HOSPITALS BUSY"
			e.timer.TextColor3 = RED
		elseif e.countdown then
			e.timer.Text = "LEAVING IN " .. math.max(0, math.ceil(e.countdown))
			e.timer.TextColor3 = YELLOW
		else
			e.timer.Text = "STEP IN TO PLAY"
			e.timer.TextColor3 = GREEN
		end
	end
	if e.indicator then
		local color = (e.departing or count >= max) and RED or (count > 0 and YELLOW or GREEN)
		e.indicator.Color = color
		local light = e.indicator:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end
end

local function depart(e: Elevator, startMatch: ({ Player }, string) -> ())
	e.departing = true
	local mode = e.mode
	local group = table.clone(e.order)
	e.order = {}
	e.countdown = nil
	updateSign(e)
	setDoors(e, false)
	moveNeedle(e, e.needleDown, 3)
	for _, player in group do
		TransitionRemote:FireClient(player, "Going down...")
	end
	task.wait(2.2)
	local stillHere = {}
	for _, player in group do
		if player.Parent == Players and not player:GetAttribute("InMatch") then
			table.insert(stillHere, player)
		end
	end
	if #stillHere > 0 then
		startMatch(stillHere, mode)
	end
	task.wait(1.5)
	moveNeedle(e, e.needleUp, 2.2)
	task.wait(1)
	setDoors(e, true)
	task.wait(1.2)
	e.departing = false
	updateSign(e)
end

local canStart: () -> boolean = function()
	return true
end

local function step(e: Elevator, startMatch: ({ Player }, string) -> ())
	if e.departing then
		return
	end
	-- Finn hvem som står i heisen
	local inside: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") then
			continue
		end
		local root = Util.getRoot(player)
		if root and inZone(e.zone, root.Position) then
			inside[player] = true
		end
	end
	-- Behold rekkefølgen de gikk inn i
	local order = {}
	for _, player in e.order do
		if inside[player] then
			table.insert(order, player)
			inside[player] = nil
		end
	end
	for player in inside do
		table.insert(order, player)
	end
	-- Maks 4: de siste som kom inn blir dyttet ut
	while #order > Config.MaxPlayersPerElevator do
		local extra = table.remove(order) :: Player
		Util.placeCharacter(extra, e.exitPoint.CFrame, false)
		NotifyRemote:FireClient(extra, "Elevator " .. e.index .. " is full (" .. Config.MaxPlayersPerElevator .. "/" .. Config.MaxPlayersPerElevator .. "). Pick another elevator.", "bad")
	end
	e.order = order

	if #order == 0 then
		e.countdown = nil
		e.waitingForRoom = false
		e.mode = "Normal" -- tom heis går tilbake til vanlig modus
	else
		e.countdown = (e.countdown or Config.ElevatorCountdown) - TICK
		if #order >= Config.MaxPlayersPerElevator then
			e.countdown = math.min(e.countdown :: number, Config.ElevatorFullCountdown)
		end
		if (e.countdown :: number) <= 0 then
			-- alle sykehusene er i bruk: vent til en runde er ferdig
			if canStart() then
				e.waitingForRoom = false
				task.spawn(depart, e, startMatch)
			else
				if not e.waitingForRoom then
					for _, p in order do
						NotifyRemote:FireClient(p, "All hospitals are busy. You leave as soon as a round ends.", "info")
					end
				end
				e.waitingForRoom = true
				e.countdown = 0
			end
		end
	end
	updateSign(e)
end

function Lobby.init(startMatch: ({ Player }, string) -> (), canStartFn: (() -> boolean)?)
	if canStartFn then
		canStart = canStartFn
	end
	local lobby = workspace:WaitForChild("Lobby")
	local folder = lobby:WaitForChild("Elevators")
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local sign = model:FindFirstChild("Sign")
		local gui = sign and sign:FindFirstChild("SignGui")
		local doors = {}
		for _, name in { "DoorL", "DoorR" } do
			local part = model:FindFirstChild(name) :: BasePart?
			if part then
				local offset = part:GetAttribute("CloseOffset") or 0
				table.insert(doors, {
					part = part,
					open = part.CFrame,
					closed = part.CFrame * CFrame.new(offset, 0, 0),
				})
			end
		end
		local e: Elevator = {
			index = model:GetAttribute("Index") or (#elevators + 1),
			model = model,
			zone = model:WaitForChild("Zone") :: BasePart,
			exitPoint = model:WaitForChild("ExitPoint") :: BasePart,
			doors = doors,
			status = gui and gui:FindFirstChild("Status") :: TextLabel?,
			timer = gui and gui:FindFirstChild("Timer") :: TextLabel?,
			modeLabel = gui and gui:FindFirstChild("Mode") :: TextLabel?,
			panelLabel = nil,
			prompt = nil,
			mode = "Normal",
			indicator = model:FindFirstChild("Indicator") :: BasePart?,
			doorSound = sign and sign:FindFirstChild("DoorSound") :: Sound?,
			order = {},
			countdown = nil,
			departing = false,
			needle = nil,
			needlePivot = CFrame.identity,
			needleOffset = 0,
			needleUp = 0,
			needleDown = 0,
			needleAngle = nil,
		}
		-- viseren dreier rundt et punkt (Pivot) i flaten til uret
		local needle = model:FindFirstChild("Needle") :: BasePart?
		local pivot = needle and needle:GetAttribute("Pivot")
		if needle and typeof(pivot) == "Vector3" then
			local angle = needle:GetAttribute("Angle") or 0
			e.needle = needle
			e.needleUp = angle
			e.needleDown = needle:GetAttribute("Down") or angle
			e.needleOffset = needle:GetAttribute("Offset") or needle.Size.Y / 2
			e.needlePivot = CFrame.new(pivot) * needle.CFrame.Rotation * CFrame.Angles(0, 0, -math.rad(angle))
			local value = Instance.new("NumberValue")
			value.Value = angle
			value.Changed:Connect(function(deg)
				needle.CFrame = e.needlePivot * CFrame.Angles(0, 0, math.rad(deg)) * CFrame.new(0, e.needleOffset, 0)
			end)
			e.needleAngle = value
		end
		-- Bryter inne i heisen: Normal / Nightmare
		local panel = model:FindFirstChild("ModePanel")
		if panel then
			local panelGui = panel:FindFirstChild("SignGui")
			e.panelLabel = panelGui and panelGui:FindFirstChild("Text") :: TextLabel?
			local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
			e.prompt = prompt
			if prompt then
				prompt.Triggered:Connect(function(player)
					if e.departing or not table.find(e.order, player) then
						NotifyRemote:FireClient(player, "Step into the elevator to change the difficulty.", "info")
						return
					end
					e.mode = if e.mode == "Nightmare" then "Normal" else "Nightmare"
					for _, p in e.order do
						if e.mode == "Nightmare" then
							NotifyRemote:FireClient(p, "NIGHTMARE: 1 life, a faster monster, darker halls and fewer lockers. Double coins.", "bad")
						else
							NotifyRemote:FireClient(p, "Difficulty set to NORMAL.", "good")
						end
					end
					updateSign(e)
				end)
			end
		end
		table.insert(elevators, e)
		updateSign(e)
	end
	table.sort(elevators, function(a, b)
		return a.index < b.index
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, e in elevators do
				step(e, startMatch)
			end
		end
	end)
end

return Lobby
