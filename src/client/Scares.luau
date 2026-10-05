-- Skumle ting som skjer av og til, bare på din skjerm (i stedet for blinkende lys):
--  * lyder i det fjerne: banking, dører som smeller, hvisking, en båre som ruller...
--  * en mørk skikkelse som står langt borte og ser på deg, og forsvinner når du ser på den
--  * lampene slukner én etter én bortover gangen mot deg, og kommer tilbake etterpå
-- Ingenting skjer mens monsteret er i nærheten, så det aldri blir forvirrende når det gjelder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local Scares = {}

local UI: any
local Effects: any
local isBlocked: () -> boolean = function()
	return false
end

local FIRST_DELAY = 30
local INTERVAL = { 24, 42 }

-- { lydnavn i Config.Sounds, volum, hvor ofte (vekt) }
local DISTANT = {
	{ "Knock", 1, 3 },
	{ "FranticKnock", 0.8, 1 },
	{ "DoorSlam", 1, 2 },
	{ "DoorCreak", 0.9, 2 },
	{ "Whisper", 0.9, 2 },
	{ "GurneyRoll", 1, 2 },
	{ "MetalScrape", 0.8, 2 },
	{ "DistantScream", 0.55, 1 },
}

local nextEvent = math.huge
local busy = false
local shadow: Model? = nil
local wasInMatch = false

local function attr(name: string): any
	return player:GetAttribute(name)
end

local function pickWeighted(list: { { any } }): { any }
	local total = 0
	for _, item in list do
		total += item[3]
	end
	local r = math.random() * total
	for _, item in list do
		r -= item[3]
		if r <= 0 then
			return item
		end
	end
	return list[1]
end

local function soundAt(position: Vector3, id: string, volume: number, minDist: number?, maxDist: number?)
	if id == nil or id == "" then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = 0.9 + math.random() * 0.15
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = minDist or 12
	s.RollOffMaxDistance = maxDist or 90
	s.Parent = holder
	s:Play()
	task.delay(20, function()
		holder:Destroy()
	end)
end

local function playerParts(): { Instance }
	local list: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	if shadow then
		table.insert(list, shadow)
	end
	return list
end

------------------------------------------------------------------
-- 1. Lyder i det fjerne
------------------------------------------------------------------
local function distantSound()
	local camera = workspace.CurrentCamera
	local item = pickWeighted(DISTANT)
	local angle = math.random() * math.pi * 2
	local dist = 22 + math.random() * 20
	local pos = camera.CFrame.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
	soundAt(pos, (Config.Sounds :: any)[item[1]], item[2])
end

------------------------------------------------------------------
-- 2. Skikkelsen i det fjerne
------------------------------------------------------------------
local function buildShadow(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("MonsterJumpscare")
	if not source or not source:IsA("Model") then
		return nil
	end
	local model = source:Clone()
	model.Name = "Shadow"
	local face = model:FindFirstChild("Face", true) :: BasePart?
	local sockets: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = Color3.fromRGB(7, 5, 5)
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0
			d.CastShadow = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d.Name == "EyeSocket" then
				table.insert(sockets, d)
			end
		elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceGui") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	-- to små, lysende prikker der øynene skulle vært
	if face then
		for _, socket in sockets do
			local out = socket.Position - face.Position
			local glint = Instance.new("Part")
			glint.Name = "Glint"
			glint.Shape = Enum.PartType.Ball
			glint.Size = Vector3.new(0.14, 0.14, 0.14)
			glint.Material = Enum.Material.Neon
			glint.Color = Color3.fromRGB(255, 236, 220)
			glint.CanCollide = false
			glint.CanQuery = false
			glint.CanTouch = false
			glint.CastShadow = false
			glint.Massless = true
			glint.CFrame = CFrame.new(socket.Position + (if out.Magnitude > 0 then out.Unit * 0.06 else Vector3.zero))
			local weld = Instance.new("Weld")
			weld.Part0 = face
			weld.Part1 = glint
			weld.C0 = face.CFrame:Inverse() * glint.CFrame
			weld.Parent = glint
			glint.Parent = model
		end
	end
	return model
end

-- Finner et sted et stykke foran deg (litt til siden, så du ser den i øyekroken)
local function findShadowSpot(): (Vector3?, Vector3?)
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.2 then
		return nil, nil
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = playerParts()
	for _ = 1, 6 do
		local side = if math.random() < 0.5 then -1 else 1
		local yaw = math.rad(16 + math.random() * 20) * side
		local dir = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(flat)
		local hit = workspace:Raycast(origin, dir * 70, params)
		local dist = if hit then hit.Distance else 70
		if dist > 28 then
			local d = math.min(dist - 3, 55)
			local above = origin + dir * d
			local down = workspace:Raycast(above, Vector3.new(0, -14, 0), params)
			if down then
				return down.Position, dir
			end
		end
	end
	return nil, nil
end

local function shadowFigure(): boolean
	if not shadow then
		shadow = buildShadow()
	end
	local model = shadow
	if not model then
		return false
	end
	local floorPos, dir = findShadowSpot()
	if not floorPos or not dir then
		return false
	end
	local root = model:FindFirstChild("Root") :: BasePart?
	if not root then
		return false
	end
	local rootPos = floorPos + Vector3.new(0, 1, 0)
	root.Anchored = true
	model.Parent = workspace
	root.CFrame = CFrame.lookAt(rootPos, rootPos - Vector3.new(dir.X, 0, dir.Z))

	-- den står der til du ser rett på den, kommer for nær, eller det har gått noen sekunder
	local start = os.clock()
	local lookedAt: number? = nil
	while model.Parent and os.clock() - start < 5 do
		RunService.RenderStepped:Wait()
		if isBlocked() then
			break
		end
		local camera = workspace.CurrentCamera
		local toIt = (root.Position + Vector3.new(0, 7, 0)) - camera.CFrame.Position
		if toIt.Magnitude < 20 then
			break
		end
		local angle = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(toIt.Unit), -1, 1)))
		if angle < 9 and os.clock() - start > 0.4 then
			local since = lookedAt or os.clock()
			lookedAt = since
			if os.clock() - since > 0.18 then
				break
			end
		end
	end
	model.Parent = nil
	-- et lite støyglimt når den forsvinner
	UI.setNoiseOverride(0.4)
	if Config.Sounds.StaticBurst ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = Config.Sounds.StaticBurst
		s.Volume = 0.3
		s.Parent = SoundService
		s:Play()
		task.delay(3, function()
			s:Destroy()
		end)
	end
	task.delay(0.12, function()
		UI.setNoiseOverride(0)
	end)
	-- av og til hvisker noe rett bak deg etterpå
	if math.random() < 0.35 then
		task.wait(0.8)
		local camera = workspace.CurrentCamera
		soundAt(camera.CFrame.Position - camera.CFrame.LookVector * 3, Config.Sounds.WhisperClose, 0.6, 2, 20)
	end
	return true
end

------------------------------------------------------------------
-- 3. Mørket som kommer mot deg
------------------------------------------------------------------
local function darkWave()
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.2 then
		return
	end
	-- bølgen starter et stykke foran deg og ruller forbi
	local from = camera.CFrame.Position + flat.Unit * 40
	Effects.darkWave(from, 75)
	if Config.Sounds.PowerHum ~= "" then
		soundAt(from, Config.Sounds.PowerHum, 0.8, 10, 80)
	end
end

------------------------------------------------------------------

local function canScare(): boolean
	if attr("InMatch") ~= true or attr("Out") == true or isBlocked() then
		return false
	end
	if Effects.getDanger() > 0.2 then
		return false
	end
	local folder = Effects.currentMatchFolder()
	if not folder or folder:GetAttribute("FinaleEnd") ~= nil then
		return false
	end
	return true
end

local function runEvent()
	busy = true
	local folder = Effects.currentMatchFolder()
	local blackout = folder and folder:GetAttribute("Blackout") == true
	local r = math.random()
	if r < 0.35 and attr("Hidden") ~= true then
		if not shadowFigure() then
			distantSound()
		end
	elseif r < 0.55 and not blackout then
		darkWave()
	else
		distantSound()
	end
	busy = false
end

function Scares.init(ui: any, effects: any, blocked: (() -> boolean)?)
	UI = ui
	Effects = effects
	if blocked then
		isBlocked = blocked
	end
	RunService.Heartbeat:Connect(function()
		local inMatch = attr("InMatch") == true
		if inMatch ~= wasInMatch then
			wasInMatch = inMatch
			nextEvent = if inMatch then os.clock() + FIRST_DELAY else math.huge
			if shadow then
				shadow.Parent = nil
			end
		end
		if busy or os.clock() < nextEvent then
			return
		end
		if canScare() then
			nextEvent = os.clock() + INTERVAL[1] + math.random() * (INTERVAL[2] - INTERVAL[1])
			task.spawn(runEvent)
		else
			-- prøv igjen om litt
			nextEvent = os.clock() + 4
		end
	end)
end

return Scares
