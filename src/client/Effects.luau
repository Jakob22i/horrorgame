-- Stemning: lys, lyd, blinkende lamper og analog-skrekk-effekter når hun er nær.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local Effects = {}

local UI: any
local mode = "lobby"
local colorCorrection: ColorCorrectionEffect
local blur: BlurEffect
local sounds: { [string]: Sound } = {}
-- Lampene blinker ikke lenger. De har et lysnivå (level, 0-1) og et rødskjær (red, 0-1)
-- som glir mykt mot et mål: svakere og rødere når monsteret nærmer seg, ned i mørke ved
-- strømbrudd, og en langsom rød puls under lockdown.
type Lamp = {
	model: Model,
	panel: BasePart,
	light: Light?,
	color: Color3,
	lightColor: Color3,
	brightness: number,
	emergency: boolean,
	level: number,
	red: number,
	shownLevel: number,
	shownRed: number,
	offStart: number,
	offEnd: number,
	clunked: boolean,
}
local lamps: { [BasePart]: Lamp } = {}
local lastBlackout = false
local RED_PANEL = Color3.fromRGB(255, 40, 30)
local RED_LIGHT = Color3.fromRGB(255, 30, 20)
local MODE_LEVEL = { on = 1, dim = 0.4, flicker = 0.4, off = 0 }
local lampRefresh = 0
local monsterRoot: BasePart? = nil
local monsterRefresh = 0
local shake = 0
local danger = 0
Effects.extraShake = 0
Effects.fakeMonster = nil :: BasePart? -- monsteret i sluttscenen (lokal kopi)

local function newSound(name: string, id: string, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.Parent = SoundService
	sounds[name] = s
	return s
end

local PRESETS = {
	lobby = {
		Ambient = Color3.fromRGB(52, 46, 30),
		OutdoorAmbient = Color3.fromRGB(38, 34, 24),
		Brightness = 0.6,
		ExposureCompensation = 0,
		EnvironmentDiffuseScale = 0.2,
		EnvironmentSpecularScale = 0.3,
		Atmosphere = { Density = 0.3, Haze = 0.7, Color = Color3.fromRGB(40, 34, 20), Decay = Color3.fromRGB(22, 18, 10) },
		CC = { Saturation = -0.15, Contrast = 0.08, Brightness = 0, TintColor = Color3.fromRGB(255, 236, 186) },
	},
	match = {
		Ambient = Color3.fromRGB(12, 10, 6),
		OutdoorAmbient = Color3.fromRGB(6, 5, 3),
		Brightness = 0,
		ExposureCompensation = 0.25,
		EnvironmentDiffuseScale = 0,
		EnvironmentSpecularScale = 0.15,
		Atmosphere = { Density = 0.45, Haze = 1.1, Color = Color3.fromRGB(22, 18, 9), Decay = Color3.fromRGB(10, 8, 4) },
		CC = { Saturation = -0.22, Contrast = 0.16, Brightness = 0, TintColor = Color3.fromRGB(255, 234, 178) },
	},
}

local nightmareApplied = false

local function applyPreset(name: string)
	nightmareApplied = false
	local p = PRESETS[name]
	Lighting.Ambient = p.Ambient
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	Lighting.Brightness = p.Brightness
	Lighting.ExposureCompensation = p.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = p.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = p.EnvironmentSpecularScale
	Lighting.ClockTime = 0
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		for k, v in p.Atmosphere do
			(atmosphere :: any)[k] = v
		end
	end
end

local function currentMatchFolder(): Instance?
	local id = player:GetAttribute("MatchId")
	if not id or id == 0 then
		return nil
	end
	local matches = workspace:FindFirstChild("Matches")
	return matches and matches:FindFirstChild("Match_" .. tostring(id))
end

Effects.currentMatchFolder = currentMatchFolder

local function refreshLamps()
	local scope: Instance? = if mode == "match" then currentMatchFolder() else workspace:FindFirstChild("Lobby")
	local seen: { [BasePart]: boolean } = {}
	if scope then
		for _, model in CollectionService:GetTagged("Lamp") do
			if model:IsDescendantOf(scope) then
				local panel = model:FindFirstChild("Panel") :: BasePart?
				if panel then
					seen[panel] = true
					if not lamps[panel] then
						local light = panel:FindFirstChildWhichIsA("Light")
						-- mobil: ingen skygger fra taklampene (mye raskere)
						if light and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
							light.Shadows = false
						end
						-- husk de opprinnelige verdiene første gang vi ser lampa (vi endrer dem selv senere)
						if panel:GetAttribute("BaseColor") == nil then
							panel:SetAttribute("BaseColor", panel.Color)
							panel:SetAttribute("BaseLight", light and light.Color or Color3.new(1, 1, 1))
							panel:SetAttribute("BaseBrightness", light and light.Brightness or 1)
						end
						local start = MODE_LEVEL[model:GetAttribute("Mode") or "on"] or 1
						local p = panel.Position
						lamps[panel] = {
							model = model :: Model,
							panel = panel,
							light = light,
							color = panel:GetAttribute("BaseColor"),
							lightColor = panel:GetAttribute("BaseLight"),
							brightness = panel:GetAttribute("BaseBrightness") or 1,
							-- noen få lamper blir svake, røde nødlys når strømmen går
							emergency = (math.floor(p.X / 4) * 7 + math.floor(p.Z / 4) * 13) % 6 == 0,
							level = start,
							red = 0,
							shownLevel = -1,
							shownRed = -1,
							offStart = 0,
							offEnd = 0,
							clunked = true,
						}
					end
				end
			end
		end
	end
	for panel in lamps do
		if not seen[panel] then
			lamps[panel] = nil
		end
	end
end

local OFF_COLOR = Color3.fromRGB(60, 64, 62)
local DARK_NEON = Color3.fromRGB(26, 22, 18)

local function applyLamp(lamp: Lamp)
	local k, r = lamp.level, lamp.red
	if math.abs(k - lamp.shownLevel) < 0.008 and math.abs(r - lamp.shownRed) < 0.015 then
		return
	end
	lamp.shownLevel, lamp.shownRed = k, r
	local light = lamp.light
	if light then
		light.Enabled = k > 0.02
		light.Brightness = lamp.brightness * k
		light.Color = lamp.lightColor:Lerp(RED_LIGHT, r)
	end
	if k > 0.04 then
		lamp.panel.Material = Enum.Material.Neon
		lamp.panel.Color = DARK_NEON:Lerp(lamp.color:Lerp(RED_PANEL, r), math.clamp(k, 0, 1))
	else
		lamp.panel.Material = Enum.Material.SmoothPlastic
		lamp.panel.Color = OFF_COLOR
	end
end

-- "klonk" fra en lampe som slukner (relé i taket)
local function clunk(panel: BasePart)
	if Config.Sounds.Flashlight == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.Flashlight
	s.Volume = 0.9
	s.PlaybackSpeed = 0.45 + math.random() * 0.1
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 60
	s.Parent = panel
	s:Play()
	task.delay(2, function()
		s:Destroy()
	end)
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function updateLamps(dt: number, monsterPos: Vector3?)
	local folder = mode == "match" and currentMatchFolder() or nil
	local finale = folder ~= nil and folder:GetAttribute("FinaleEnd") ~= nil
	local blackout = folder ~= nil and folder:GetAttribute("Blackout") == true
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.4)
	for _, lamp in lamps do
		local target = MODE_LEVEL[lamp.model:GetAttribute("Mode") or "on"] or 1
		local red = 0
		local rate = 2.2
		-- monsteret "drenerer" lyset: lampene rundt det blir svake og røde
		if monsterPos then
			local d = (lamp.panel.Position - monsterPos).Magnitude
			if d < 36 then
				local far = smoothstep((d - 8) / 28)
				target *= 0.1 + 0.9 * far
				red = (1 - far) * 0.85
			end
		end
		-- mørkebølge: lampene slukner én etter én mot deg, og kommer tilbake litt etterpå
		local now = os.clock()
		if now >= lamp.offStart and now < lamp.offEnd then
			if not lamp.clunked then
				lamp.clunked = true
				if lamp.level > 0.15 then
					clunk(lamp.panel)
				end
			end
			target = 0
			rate = 14
		end
		if finale then
			target = 0.25 + 0.6 * pulse
			red = 1
			rate = 5
		elseif blackout then
			target = if lamp.emergency then 0.2 else 0
			red = if lamp.emergency then 1 else red
			rate = 1.3
		end
		lamp.level += (target - lamp.level) * math.min(1, dt * rate)
		lamp.red += (red - lamp.red) * math.min(1, dt * 2)
		applyLamp(lamp)
	end
end

local function findMonster(): BasePart?
	local folder = currentMatchFolder()
	local monster = folder and folder:FindFirstChild("Monster")
	return monster and monster:FindFirstChild("Root") :: BasePart?
end

function Effects.init(ui: any)
	UI = ui
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "HorrorColor"
	colorCorrection.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "HorrorBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local S = Config.Sounds
	newSound("Music", S.LobbyMusic, 0.35, true)
	newSound("Ambience", S.Ambience, 0.5, true)
	newSound("Static", S.Static, 0, true)
	newSound("Heartbeat", S.Heartbeat, 0, true)
	newSound("Alarm", S.Alarm, 0.5, true)
	newSound("PowerDown", S.PowerDown, 0.9, false)
	newSound("PowerUp", S.PowerUp, 0.6, false)

	CollectionService:GetInstanceAddedSignal("Lamp"):Connect(function()
		lampRefresh = 0
	end)

	RunService.RenderStepped:Connect(function(dt)
		Effects._step(dt)
	end)
	-- Kameraristing: fjern forrige rist før kameraet oppdateres, legg på ny etterpå
	local lastShake = CFrame.identity
	RunService:BindToRenderStep("HorrorShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
		if lastShake ~= CFrame.identity then
			local camera = workspace.CurrentCamera
			camera.CFrame = camera.CFrame * lastShake:Inverse()
			lastShake = CFrame.identity
		end
	end)
	RunService:BindToRenderStep("HorrorShake", Enum.RenderPriority.Camera.Value + 1, function()
		local amount = shake + Effects.extraShake
		if amount > 0.001 then
			local camera = workspace.CurrentCamera
			local t = os.clock()
			lastShake = CFrame.Angles(math.sin(t * 23) * amount * 0.02, math.sin(t * 17 + 1) * amount * 0.02, math.sin(t * 11 + 2) * amount * 0.012)
			camera.CFrame = camera.CFrame * lastShake
		end
	end)
end

function Effects.setMode(newMode: string)
	mode = newMode
	applyPreset(newMode)
	lampRefresh = 0
	monsterRoot = nil
	if newMode == "match" then
		sounds.Music:Stop()
		sounds.Ambience:Play()
		sounds.Static:Play()
		sounds.Heartbeat:Play()
	else
		sounds.Ambience:Stop()
		sounds.Static:Stop()
		sounds.Heartbeat:Stop()
		sounds.Alarm:Stop()
		lastBlackout = false
		if UI then
			UI.setFinaleTimer(nil)
		end
		if not sounds.Music.IsPlaying then
			sounds.Music:Play()
		end
	end
	if UI then
		UI.setVhsMode(newMode)
	end
end

function Effects.getDanger(): number
	return danger
end

-- Strømbrudd og finale: lyd og nedtelling
local function updateMatchEvents()
	local folder = currentMatchFolder()
	if mode ~= "match" or not folder then
		return
	end
	local blackout = folder:GetAttribute("Blackout") == true
	if blackout ~= lastBlackout then
		lastBlackout = blackout
		if blackout then
			sounds.PowerDown:Play()
		else
			sounds.PowerUp:Play()
		end
	end
	local finaleEnd = folder:GetAttribute("FinaleEnd")
	if typeof(finaleEnd) == "number" then
		if not sounds.Alarm.IsPlaying then
			sounds.Alarm:Play()
		end
		if folder:GetAttribute("ExitOpen") == true then
			UI.setFinaleTimer("THE DOOR IS OPEN — RUN!")
		else
			local left = math.max(0, math.ceil(finaleEnd - workspace:GetServerTimeNow()))
			UI.setFinaleTimer(string.format("LOCKDOWN — DOOR OPENS IN %d:%02d", left // 60, left % 60))
		end
	else
		if sounds.Alarm.IsPlaying then
			sounds.Alarm:Stop()
		end
		UI.setFinaleTimer(nil)
	end
end

function Effects.stopAlarm()
	sounds.Alarm:Stop()
end

-- Lampene slukner i en bølge som starter ved `from` og går utover (ca. 14 studs i sekundet)
function Effects.darkWave(from: Vector3, radius: number)
	local now = os.clock()
	for _, lamp in lamps do
		local d = (lamp.panel.Position - from).Magnitude
		if d < radius then
			lamp.offStart = now + d / 14
			lamp.offEnd = lamp.offStart + 3.2 + math.random() * 1.2
			lamp.clunked = false
		end
	end
end

-- Nøklene svever, snurrer sakte og pulserer i lyset, så de er lette å få øye på
local keyBase: { [Model]: CFrame } = {}
local function updateKeys()
	local folder = mode == "match" and currentMatchFolder() or nil
	local keys = folder and folder:FindFirstChild("Keys")
	for model in keyBase do
		if not model.Parent then
			keyBase[model] = nil
		end
	end
	if not keys then
		return
	end
	local t = os.clock()
	for _, model in keys:GetChildren() do
		if model:IsA("Model") then
			local base = keyBase[model]
			if not base then
				base = model:GetPivot()
				keyBase[model] = base
				local shimmer = model:FindFirstChild("Shimmer", true)
				if shimmer and shimmer:IsA("Sound") and not shimmer.IsPlaying then
					shimmer:Play()
				end
			end
			local phase = (base.Position.X + base.Position.Z) * 0.37
			local bob = math.sin(t * 2 + phase) * 0.18
			-- stående nøkkel (kammen opp) som svever litt over der den ligger
			model:PivotTo(CFrame.new(base.Position + Vector3.new(0, 1.55 + bob, 0)) * CFrame.Angles(0, t * 1.3 + phase, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
			local glow = model:FindFirstChild("Glow", true)
			if glow and glow:IsA("PointLight") then
				glow.Brightness = 1.9 + math.sin(t * 3 + phase) * 0.5
			end
		end
	end
end

-- Varsellampene ved nødutgangen spinner under nedtellingen og til døra er passert
local beaconBase: { [BasePart]: CFrame } = {}
local beaconAngle = 0
local function updateBeacons(dt: number)
	local folder = currentMatchFolder()
	local active = mode == "match" and folder ~= nil and typeof(folder:GetAttribute("FinaleEnd")) == "number"
	if active then
		beaconAngle = (beaconAngle + dt * 7) % (math.pi * 2)
	end
	for _, part in CollectionService:GetTagged("ExitBeacon") do
		if not part:IsA("BasePart") then
			continue
		end
		local mine = folder ~= nil and part:IsDescendantOf(folder)
		local base = beaconBase[part]
		if not base then
			base = part.CFrame
			beaconBase[part] = base
		end
		local beam = part:FindFirstChildOfClass("SpotLight")
		local on = active and mine
		if beam then
			beam.Enabled = on
		end
		if on then
			part.CFrame = base * CFrame.Angles(0, beaconAngle, 0)
		elseif part.CFrame ~= base then
			part.CFrame = base
		end
	end
	for part in beaconBase do
		if not part.Parent then
			beaconBase[part] = nil
		end
	end
end

function Effects._step(dt: number)
	lampRefresh -= dt
	if lampRefresh <= 0 then
		lampRefresh = 3
		refreshLamps()
	end
	updateMatchEvents()

	local monsterPos: Vector3? = nil
	if mode == "match" then
		monsterRefresh -= dt
		if not monsterRoot or not monsterRoot.Parent or monsterRefresh <= 0 then
			monsterRefresh = 1
			monsterRoot = findMonster()
		end
		if monsterRoot then
			monsterPos = monsterRoot.Position
		end
		local fake = Effects.fakeMonster
		if fake and fake.Parent then
			monsterPos = fake.Position
		end
	end

	-- Hvor nær er hun?
	local target = 0
	if monsterPos then
		local camera = workspace.CurrentCamera
		local dist = (camera.CFrame.Position - monsterPos).Magnitude
		target = math.clamp(1 - (dist - 8) / 52, 0, 1)
	end
	danger += (target - danger) * math.min(1, dt * 4)

	updateLamps(dt, monsterPos)
	updateKeys()
	updateBeacons(dt)

	-- Nightmare: mørkere og tettere tåke
	if mode == "match" then
		local folder = currentMatchFolder()
		local nightmare = folder ~= nil and folder:GetAttribute("Mode") == "Nightmare"
		if nightmare ~= nightmareApplied then
			nightmareApplied = nightmare
			local p = PRESETS.match
			Lighting.ExposureCompensation = p.ExposureCompensation + (if nightmare then -0.45 else 0)
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Density = p.Atmosphere.Density + (if nightmare then 0.15 else 0)
			end
		end
	end

	local base = PRESETS[mode].CC
	colorCorrection.Saturation = base.Saturation - danger * 0.25
	colorCorrection.Contrast = base.Contrast + danger * 0.1
	colorCorrection.Brightness = base.Brightness
	colorCorrection.TintColor = base.TintColor:Lerp(Color3.fromRGB(255, 190, 170), danger * 0.35)
	blur.Size = 0
	shake = danger * danger * 0.35

	if mode == "match" then
		sounds.Static.Volume = danger * danger * 0.55
		sounds.Heartbeat.Volume = danger * 1.1
		sounds.Heartbeat.PlaybackSpeed = 1 + danger * 0.5
		sounds.Ambience.Volume = 0.5 * (1 - danger * 0.6)
		if UI then
			UI.setNoise(danger * danger * 0.8)
		end
	elseif UI then
		UI.setNoise(0)
	end
end

return Effects
