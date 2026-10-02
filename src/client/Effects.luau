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
local lamps: { { model: Model, panel: BasePart, light: Light?, color: Color3, on: boolean } } = {}
local lampRefresh = 0
local lampTick = 0
local monsterRoot: BasePart? = nil
local monsterRefresh = 0
local shake = 0
local danger = 0
Effects.extraShake = 0

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
		Ambient = Color3.fromRGB(46, 42, 34),
		OutdoorAmbient = Color3.fromRGB(34, 32, 30),
		Brightness = 0.6,
		ExposureCompensation = 0,
		EnvironmentDiffuseScale = 0.2,
		EnvironmentSpecularScale = 0.3,
		Atmosphere = { Density = 0.3, Haze = 0.6, Color = Color3.fromRGB(32, 30, 28), Decay = Color3.fromRGB(18, 16, 14) },
		CC = { Saturation = -0.25, Contrast = 0.08, Brightness = 0, TintColor = Color3.fromRGB(255, 244, 222) },
	},
	match = {
		Ambient = Color3.fromRGB(7, 8, 9),
		OutdoorAmbient = Color3.fromRGB(4, 4, 5),
		Brightness = 0,
		ExposureCompensation = 0.15,
		EnvironmentDiffuseScale = 0,
		EnvironmentSpecularScale = 0.15,
		Atmosphere = { Density = 0.5, Haze = 1.2, Color = Color3.fromRGB(8, 10, 10), Decay = Color3.fromRGB(4, 5, 5) },
		CC = { Saturation = -0.4, Contrast = 0.18, Brightness = -0.02, TintColor = Color3.fromRGB(222, 255, 232) },
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
				table.insert(lamps, {
					model = model :: Model,
					panel = panel,
					light = panel:FindFirstChildWhichIsA("Light"),
					color = panel.Color,
					on = true,
				})
			end
		end
	end
end

local OFF_COLOR = Color3.fromRGB(60, 64, 62)

local function setLamp(lamp, on: boolean)
	if lamp.on == on then
		return
	end
	lamp.on = on
	if lamp.light then
		lamp.light.Enabled = on
	end
	lamp.panel.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	lamp.panel.Color = on and lamp.color or OFF_COLOR
end

local function updateLamps(monsterPos: Vector3?)
	for _, lamp in lamps do
		local lampMode = lamp.model:GetAttribute("Mode")
		if lampMode == "off" then
			setLamp(lamp, false)
			continue
		end
		local near = monsterPos and (lamp.panel.Position - monsterPos).Magnitude < 30
		if near then
			setLamp(lamp, math.random() < 0.35)
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
			lastShake = CFrame.Angles((math.random() - 0.5) * amount * 0.05, (math.random() - 0.5) * amount * 0.05, (math.random() - 0.5) * amount * 0.03)
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

function Effects._step(dt: number)
	lampRefresh -= dt
	if lampRefresh <= 0 then
		lampRefresh = 3
		refreshLamps()
	end

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
	colorCorrection.Saturation = base.Saturation - danger * 0.55
	colorCorrection.Contrast = base.Contrast + danger * 0.25
	colorCorrection.Brightness = base.Brightness
	colorCorrection.TintColor = base.TintColor:Lerp(Color3.fromRGB(255, 150, 150), danger * 0.6)
	blur.Size = danger * 3
	shake = danger * danger * 1.2

	if mode == "match" then
		sounds.Static.Volume = danger * danger * 0.55
		sounds.Heartbeat.Volume = danger * 1.1
		sounds.Heartbeat.PlaybackSpeed = 1 + danger * 0.5
		sounds.Ambience.Volume = 0.5 * (1 - danger * 0.6)
		if UI then
			UI.setNoise(danger * danger * 0.55)
		end
	elseif UI then
		UI.setNoise(0)
	end
end

return Effects
