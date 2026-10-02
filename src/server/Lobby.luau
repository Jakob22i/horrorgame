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
	indicator: BasePart?,
	doorSound: Sound?,
	order: { Player },
	countdown: number?,
	departing: boolean,
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

local function updateSign(e: Elevator)
	local count = #e.order
	local max = Config.MaxPlayersPerElevator
	if e.status then
		e.status.Text = count .. "/" .. max .. " SPILLERE"
	end
	if e.timer then
		if e.departing then
			e.timer.Text = "AVGÅR..."
			e.timer.TextColor3 = RED
		elseif e.countdown then
			e.timer.Text = "STARTER OM " .. math.max(0, math.ceil(e.countdown))
			e.timer.TextColor3 = YELLOW
		else
			e.timer.Text = "GÅ INN FOR Å SPILLE"
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

local function depart(e: Elevator, startMatch: ({ Player }) -> ())
	e.departing = true
	local group = table.clone(e.order)
	e.order = {}
	e.countdown = nil
	updateSign(e)
	setDoors(e, false)
	for _, player in group do
		TransitionRemote:FireClient(player, "Heisen går ned...")
	end
	task.wait(2.2)
	local stillHere = {}
	for _, player in group do
		if player.Parent == Players and not player:GetAttribute("InMatch") then
			table.insert(stillHere, player)
		end
	end
	if #stillHere > 0 then
		startMatch(stillHere)
	end
	task.wait(1.5)
	setDoors(e, true)
	task.wait(1.2)
	e.departing = false
	updateSign(e)
end

local function step(e: Elevator, startMatch: ({ Player }) -> ())
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
		NotifyRemote:FireClient(extra, "Heis " .. e.index .. " er full (" .. Config.MaxPlayersPerElevator .. "/" .. Config.MaxPlayersPerElevator .. "). Velg en annen heis.", "bad")
	end
	e.order = order

	if #order == 0 then
		e.countdown = nil
	else
		e.countdown = (e.countdown or Config.ElevatorCountdown) - TICK
		if #order >= Config.MaxPlayersPerElevator then
			e.countdown = math.min(e.countdown :: number, Config.ElevatorFullCountdown)
		end
		if (e.countdown :: number) <= 0 then
			task.spawn(depart, e, startMatch)
		end
	end
	updateSign(e)
end

function Lobby.init(startMatch: ({ Player }) -> ())
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
			indicator = model:FindFirstChild("Indicator") :: BasePart?,
			doorSound = sign and sign:FindFirstChild("DoorSound") :: Sound?,
			order = {},
			countdown = nil,
			departing = false,
		}
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
