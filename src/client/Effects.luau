-- Stemning: lys, lyd, blinkende lamper og analog-skrekk-effekter når hun er nær.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local Effects = {}

local UI: any
local mode = "lobby"
local colorCorrection: ColorCorrectionEffect
local blur: BlurEffect
local sounds: { [string]: Sound } = {}
type Lamp = { model: Model, panel: BasePart, light: Light?, color: Color3, lightColor: Color3, on: boolean, red: boolean }
local lamps: { Lamp } = {}
local lastBlackout = false
local blackoutChanged = -10
local RED_PANEL = Color3.fromRGB(255, 40, 30)
local RED_LIGHT = Color3.fromRGB(255, 30, 20)
local lampRefresh = 0
local lampTick = 0
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

local function applyPreset(name: string)
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
	lamps = {}
	local scope: Instance? = if mode == "match" then currentMatchFolder() else workspace:FindFirstChild("Lobby")
	if not scope then
		return
	end
	for _, model in CollectionService:GetTagged("Lamp") do
		if model:IsDescendantOf(scope) then
			local panel = model:FindFirstChild("Panel") :: BasePart?
			if panel then
				local light = panel:FindFirstChildWhichIsA("Light")
				-- husk de opprinnelige fargene første gang vi ser lampa (vi endrer dem selv senere)
				if panel:GetAttribute("BaseColor") == nil then
					panel:SetAttribute("BaseColor", panel.Color)
					panel:SetAttribute("BaseLight", light and light.Color or Color3.new(1, 1, 1))
				end
				table.insert(lamps, {
					model = model :: Model,
					panel = panel,
					light = light,
					color = panel:GetAttribute("BaseColor"),
					lightColor = panel:GetAttribute("BaseLight"),
					on = panel.Material == Enum.Material.Neon,
					red = false,
				})
			end
		end
	end
end

local OFF_COLOR = Color3.fromRGB(60, 64, 62)

local function setLamp(lamp: Lamp, on: boolean, red: boolean?)
	local isRed = red == true
	if lamp.on == on and lamp.red == isRed then
		return
	end
	lamp.on = on
	lamp.red = isRed
	if lamp.light then
		lamp.light.Enabled = on
		lamp.light.Color = isRed and RED_LIGHT or lamp.lightColor
	end
	lamp.panel.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	lamp.panel.Color = on and (isRed and RED_PANEL or lamp.color) or OFF_COLOR
end

local function updateLamps(monsterPos: Vector3?)
	local folder = mode == "match" and currentMatchFolder() or nil
	local now = os.clock()
	local finale = folder ~= nil and folder:GetAttribute("FinaleEnd") ~= nil
	local blackout = folder ~= nil and folder:GetAttribute("Blackout") == true
	local transition = now - blackoutChanged < 0.9
	for _, lamp in lamps do
		local lampMode = lamp.model:GetAttribute("Mode")
		if finale then
			-- alarm: alle lamper blinker rødt
			setLamp(lamp, math.floor(now * 2) % 2 == 0, true)
			continue
		end
		if blackout then
			setLamp(lamp, transition and math.random() < 0.4)
			continue
		end
		if transition then
			setLamp(lamp, lampMode ~= "off" and math.random() < 0.6)
			continue
		end
		if lampMode == "off" then
			setLamp(lamp, false)
			continue
		end
		local near = monsterPos and (lamp.panel.Position - monsterPos).Magnitude < 30
		if near then
			setLamp(lamp, math.random() < 0.72)
		elseif lampMode == "flicker" then
			if lamp.on then
				setLamp(lamp, math.random() > 0.08)
			else
				setLamp(lamp, math.random() < 0.3)
			end
		else
			setLamp(lamp, true)
		end
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
		blackoutChanged = os.clock()
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

	lampTick -= dt
	if lampTick <= 0 then
		lampTick = 0.07
		updateLamps(monsterPos)
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
