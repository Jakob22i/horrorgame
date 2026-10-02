-- Sluttscenen når noen kommer seg ut: "YOU GOT OUT", så står monsteret plutselig i
-- døråpningen bak dere og vinker... jumpscare, "IT FOLLOWED YOU HOME" og "PART 2 COMING SOON".
-- Alt skjer lokalt: monsteret her er en egen kopi (Assets/MonsterJumpscare), det ekte er gjemt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ending = {}

local UI: any
local Effects: any
local Controls: any
local token = 0
local playing = false
local clone: Model? = nil
local redLight: BasePart? = nil
local sounds: { Sound } = {}
local shotCF: CFrame? = nil

local RED = Color3.fromRGB(220, 30, 30)

local function sound(id: string, volume: number, parent: Instance?): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent or SoundService
	s:Play()
	table.insert(sounds, s)
	return s
end

local function stopSounds()
	for _, s in sounds do
		s:Destroy()
	end
	table.clear(sounds)
end

local function hideCharacters()
	for _, p in Players:GetPlayers() do
		local character = p.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Ending.init(ui: any, effects: any, controls: any)
	UI = ui
	Effects = effects
	Controls = controls
end

function Ending.isPlaying(): boolean
	return playing
end

-- Rydder opp (kalles når du sendes til lobbyen, eller hvis scenen avbrytes)
function Ending.cleanup()
	token += 1
	playing = false
	shotCF = nil
	pcall(RunService.UnbindFromRenderStep, RunService, "EndingCamera")
	pcall(RunService.UnbindFromRenderStep, RunService, "EndingHide")
	stopSounds()
	if clone then
		clone:Destroy()
		clone = nil
	end
	if redLight then
		redLight:Destroy()
		redLight = nil
	end
	Effects.fakeMonster = nil
	Effects.extraShake = 0
	UI.setNoiseOverride(0)
	UI.setCaption(nil)
	UI.hideTitleCard()
	Controls.setFrozen(false)
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- Teksten på svart skjerm til slutt, og "PART 2 COMING SOON"
local function outro(alive: () -> boolean)
	UI.fadeOut("", 0.01)
	task.wait(0.8)
	if not alive() then
		return
	end
	UI.typeOnBlack({ "PATIENT #0413", "", "STATUS: ESCAPED" }, 1.6, RED)
	if not alive() then
		return
	end
	UI.setFadeText("")
	task.wait(0.5)
	if not alive() then
		return
	end
	UI.typeOnBlack({ "IT FOLLOWED YOU HOME." }, 2)
	if not alive() then
		return
	end
	UI.setFadeText("")
	UI.showTitleCard("PART 2", "COMING SOON")
	-- et lite fnis i mørket under tittelen
	task.wait(2.5)
	if alive() then
		sound(Config.Sounds.Giggle, 0.35)
	end
end

function Ending.play(_data: any)
	Ending.cleanup()
	local my = token
	local function alive(): boolean
		return token == my
	end
	playing = true

	UI.hidePanels()
	UI.setMatchHud(false)
	UI.setActionBar(false)
	UI.setFinaleTimer(nil)
	UI.setSpectate(nil)
	Effects.stopAlarm()
	Controls.setFrozen(true)

	UI.fadeOut("", 0.6)
	task.wait(0.7)
	if not alive() then
		return
	end

	-- Finn nødutgangen i kartet til runden din
	local folder = Effects.currentMatchFolder()
	local map = folder and folder:FindFirstChild("Map")
	local exit = map and map:FindFirstChild("ExitDoor")
	local header = exit and exit:FindFirstChild("Header") :: BasePart?
	local outside = exit and exit:FindFirstChild("OutsideFloor") :: BasePart?

	UI.typeOnBlack({ "03:59 AM", "", "THE DOOR OPENED." }, 1.2)
	if not alive() then
		return
	end
	if not header or not outside then
		outro(alive)
		return
	end

	local hp = header.Position
	local floorY = outside.Position.Y + outside.Size.Y / 2
	local door = Vector3.new(hp.X, floorY, hp.Z)
	local d = outside.Position - hp
	local dir = Vector3.new(d.X, 0, d.Z).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local lookAt = door + Vector3.new(0, 6.5, 0)
	local camStart = door + dir * 14 + side * 3 + Vector3.new(0, 5.2, 0)
	local camEnd = door + dir * 10.5 + side * 2 + Vector3.new(0, 5.6, 0)

	-- Kameraet: fast utenfor døra, med litt håndholdt slingring
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	shotCF = CFrame.lookAt(camStart, lookAt)
	RunService:BindToRenderStep("EndingCamera", Enum.RenderPriority.Camera.Value, function()
		local cf = shotCF
		if cf then
			local t = os.clock()
			local sway = CFrame.Angles(math.sin(t * 0.7) * 0.006, math.sin(t * 0.53 + 1) * 0.008, math.sin(t * 0.41) * 0.004)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cf * sway
		end
	end)
	RunService:BindToRenderStep("EndingHide", Enum.RenderPriority.Camera.Value + 2, hideCharacters)

	-- Rolig: dere er ute
	UI.fadeIn(1.2)
	UI.setCaption("YOU GOT OUT.")
	local start = os.clock()
	while os.clock() - start < 3.4 do
		if not alive() then
			return
		end
		local k = smooth((os.clock() - start) / 3.4)
		shotCF = CFrame.lookAt(camStart:Lerp(camEnd, k * 0.6), lookAt)
		RunService.RenderStepped:Wait()
	end
	UI.setCaption(nil)

	-- Støy... og der står den
	UI.setNoiseOverride(0.9)
	sound(Config.Sounds.StaticBurst, 0.8)
	local model = (ReplicatedStorage:WaitForChild("Assets"):WaitForChild("MonsterJumpscare") :: Model):Clone()
	model.Name = "EndingMonster"
	local root = model:FindFirstChild("Root") :: BasePart
	local rootPos = door - dir * 1.2 + Vector3.new(0, 1, 0)
	root.Anchored = true
	model.Parent = workspace
	-- flytt etter at den er i workspace, så alle sveisede deler følger med
	root.CFrame = CFrame.lookAt(rootPos, rootPos + dir)
	clone = model
	Effects.fakeMonster = root

	local light = Instance.new("Part")
	light.Name = "EndingLight"
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.CanTouch = false
	light.Transparency = 1
	light.Size = Vector3.new(0.2, 0.2, 0.2)
	light.CFrame = CFrame.new(door - dir * 4 + Vector3.new(0, 2.5, 0))
	local point = Instance.new("PointLight")
	point.Color = Color3.fromRGB(255, 40, 25)
	point.Range = 18
	point.Brightness = 2
	point.Parent = light
	light.Parent = workspace
	redLight = light

	local joints = model:FindFirstChild("Joints")
	local base: { [string]: CFrame } = {}
	local welds: { [string]: Weld } = {}
	if joints then
		for _, name in { "Neck", "Jaw", "RShoulder", "RElbow", "Spine" } do
			local w = joints:FindFirstChild(name)
			if w and w:IsA("Weld") then
				welds[name] = w
				base[name] = w.C0
			end
		end
	end
	local function set(name: string, cf: CFrame)
		local w, b = welds[name], base[name]
		if w and b then
			w.C0 = b * cf
		end
	end
	local face = model:FindFirstChild("Face", true) :: BasePart?

	task.wait(0.35)
	if not alive() then
		return
	end
	UI.setNoiseOverride(0.15)
	sound(Config.Sounds.Giggle, 0.9, root)
	local musicBox = sound(Config.Sounds.MusicBox, 0.5, root)
	if musicBox then
		musicBox.Looped = true
	end

	-- Den hever armen sakte og vinker, med hodet på skakke
	local cracked = false
	start = os.clock()
	local WAVE_TIME = 5
	while os.clock() - start < WAVE_TIME do
		if not alive() then
			return
		end
		local t = os.clock() - start
		local raise = smooth(t / 2.2)
		local wave = t > 1.6 and math.sin((t - 1.6) * 3.4) * 0.25 or 0
		local twitch = CFrame.identity
		if t > 3.3 and t < 3.45 then
			twitch = CFrame.Angles(0.15, 0.25, -0.5)
			if not cracked then
				cracked = true
				sound(Config.Sounds.BoneCrack, 0.8, root)
			end
		end
		set("Neck", CFrame.Angles(0.12 * raise, 0, 0.55 * raise) * twitch)
		set("RShoulder", CFrame.Angles(1.2 * raise, 0, 0.5 * raise + wave))
		set("RElbow", CFrame.Angles(1.0 * raise, 0, 0))
		set("Jaw", CFrame.Angles(-0.1 * raise, 0, 0))
		set("Spine", CFrame.Angles(math.sin(t * 1.4) * 0.025, 0, 0))
		point.Brightness = math.random() < 0.15 and 0.2 or (1.6 + math.random() * 1.2)
		-- kameraet glir sakte nærmere
		local k = 0.6 + 0.4 * smooth(t / WAVE_TIME)
		shotCF = CFrame.lookAt(camStart:Lerp(camEnd, k), lookAt + Vector3.new(0, raise * 1.2, 0))
		RunService.RenderStepped:Wait()
	end

	-- Den kaster seg mot deg
	if musicBox then
		musicBox:Stop()
	end
	sound(Config.Sounds.JumpscareHit, 1.2)
	sound(Config.Sounds.Scream, 1)
	UI.setNoiseOverride(0.55)
	Effects.extraShake = 3
	local from = shotCF or CFrame.lookAt(camEnd, lookAt)
	start = os.clock()
	while os.clock() - start < 1.1 do
		if not alive() then
			return
		end
		local t = os.clock() - start
		local open = -math.clamp(t / 0.15, 0, 1) * 0.55 - math.abs(math.sin(t * 34)) * 0.08
		set("Jaw", CFrame.Angles(open, 0, 0))
		set("Neck", CFrame.Angles(-0.1, 0, 0.2 + math.sin(t * 40) * 0.05))
		set("RShoulder", CFrame.Angles(1.3, 0, 0.1))
		set("RElbow", CFrame.Angles(0.2, 0, 0))
		point.Brightness = 1 + math.random() * 3
		if face then
			local fp = face.Position
			local target = CFrame.lookAt(fp + face.CFrame.LookVector * 2.6 + Vector3.new(0, -0.3, 0), fp)
			shotCF = from:Lerp(target, smooth(t / 0.35))
		end
		RunService.RenderStepped:Wait()
	end

	-- Svart. Kopien fjernes, og teksten tar over.
	Effects.extraShake = 0
	UI.setNoiseOverride(0)
	stopSounds()
	if clone then
		clone:Destroy()
		clone = nil
	end
	if redLight then
		redLight:Destroy()
		redLight = nil
	end
	Effects.fakeMonster = nil
	outro(alive)
end

return Ending
