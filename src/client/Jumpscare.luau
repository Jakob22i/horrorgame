-- Jumpscare: ansiktet til monsteret fyller skjermen, kjeven gaper, støy, skrik og risting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Jumpscare = {}

local UI: any
local Effects: any
local viewport: ViewportFrame
local camera: Camera
local redFlash: Frame
local faceCF = CFrame.new(0, 11, -2)
local jawHinge: CFrame? = nil
local jawParts: { { part: BasePart, base: CFrame } } = {}
local playing = false

local function sound(id: string, volume: number): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
	return s
end

function Jumpscare.init(ui: any, effects: any)
	UI = ui
	Effects = effects
	local layer = UI.jumpscareLayer :: Frame

	viewport = Instance.new("ViewportFrame")
	viewport.Name = "Face"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(170, 160, 160)
	viewport.LightColor = Color3.fromRGB(255, 230, 230)
	viewport.LightDirection = Vector3.new(0, -0.3, 1)
	viewport.ZIndex = 21
	viewport.Parent = layer

	camera = Instance.new("Camera")
	camera.FieldOfView = 70
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local model = (assets:WaitForChild("MonsterJumpscare") :: Model):Clone()
	-- bare hodet trengs i nærbildet
	for _, name in { "Body", "IVPole" } do
		local child = model:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	local face = model:FindFirstChild("Face", true)
	if face and face:IsA("BasePart") then
		faceCF = face.CFrame
	end
	-- kjeven: delene roteres rundt hengselet (ViewportFrame har ikke fysikk, så vi flytter dem selv)
	local rig = model:FindFirstChild("Rig")
	local hinge = rig and rig:FindFirstChild("Jaw")
	local head = model:FindFirstChild("Head")
	local jaw = head and head:FindFirstChild("Jaw")
	if hinge and hinge:IsA("BasePart") and jaw then
		jawHinge = hinge.CFrame
		for _, p in jaw:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(jawParts, { part = p, base = p.CFrame })
			end
		end
	end
	model.Parent = viewport

	redFlash = Instance.new("Frame")
	redFlash.Size = UDim2.fromScale(1, 1)
	redFlash.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
	redFlash.BackgroundTransparency = 1
	redFlash.BorderSizePixel = 0
	redFlash.ZIndex = 22
	redFlash.Parent = layer
end

-- Teksten etter at du har mistet et liv
local function lifeMessage(livesLeft: number): string
	if livesLeft > 1 then
		return "IT GOT YOU\n\n" .. livesLeft .. " lives left"
	elseif livesLeft == 1 then
		return "IT GOT YOU\n\n1 life left"
	end
	return "IT GOT YOU\n\nNo lives left..."
end

-- mode = "downed": du ligger nede og kan bli hjulpet opp (ingen liv mistet ennå)
function Jumpscare.play(livesLeft: number, mode: string?)
	if playing then
		return
	end
	playing = true
	local layer = UI.jumpscareLayer :: Frame
	layer.Visible = true
	UI.setNoiseOverride(0.5)
	Effects.extraShake = 3
	sound(Config.Sounds.JumpscareHit, 1.2)
	local scream = sound(Config.Sounds.Scream, 1)

	local start = os.clock()
	local duration = 1.6
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local zoom = math.clamp(t / 0.18, 0, 1)
		local dist = 6.5 - zoom * 4.3 + math.sin(t * 40) * 0.08
		local jitter = Vector3.new((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.25, 0)
		local target = (faceCF * CFrame.new(0, -0.25, 0)).Position
		local camPos = (faceCF * CFrame.new(0, -0.3, -dist)).Position + jitter
		camera.CFrame = CFrame.lookAt(camPos, target + jitter * 0.5) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.12)
		-- kjeven gaper og klaprer
		if jawHinge then
			local open = -math.clamp(t / 0.15, 0, 1) * 0.5 - math.abs(math.sin(t * 34)) * 0.08
			local move = jawHinge * CFrame.Angles(open, 0, 0) * jawHinge:Inverse()
			for _, jp in jawParts do
				jp.part.CFrame = move * jp.base
			end
		end
		-- glitch: bildet blinker og rødt lys pulserer
		viewport.Visible = math.random() > 0.12
		redFlash.BackgroundTransparency = 0.55 + math.random() * 0.45
	end)

	task.wait(duration)
	conn:Disconnect()
	layer.Visible = false
	redFlash.BackgroundTransparency = 1
	UI.setNoiseOverride(0)
	Effects.extraShake = 0

	if mode == "downed" then
		UI.fadeOut("YOU'RE DOWN\n\nA friend can still help you up", 0.05)
		task.delay(1.2, function()
			if scream then
				scream:Stop()
			end
		end)
		task.wait(1.6)
		UI.fadeIn(0.7)
		playing = false
		return
	end
	UI.fadeOut(lifeMessage(livesLeft), 0.05)
	task.delay(1.2, function()
		if scream then
			scream:Stop()
		end
	end)
	task.wait(math.max(0.5, Config.RespawnDelay - duration - 0.2))
	UI.fadeIn(0.8)
	playing = false
end

-- Du lå nede og ingen rakk å hjelpe deg: et liv er borte (ingen ny jumpscare)
function Jumpscare.lostLife(livesLeft: number)
	if playing then
		return
	end
	playing = true
	UI.fadeOut(lifeMessage(livesLeft), 0.6)
	task.wait(math.max(0.5, Config.RespawnDelay - 0.4))
	UI.fadeIn(0.8)
	playing = false
end

-- "Jumpscare everyone": en annen spiller har kjøpt en skremsel. Ingen liv mistes.
function Jumpscare.prank(byName: string)
	if playing then
		return
	end
	playing = true
	local layer = UI.jumpscareLayer :: Frame
	layer.Visible = true
	UI.setNoiseOverride(0.5)
	Effects.extraShake = 3
	sound(Config.Sounds.JumpscareHit, 1.2)
	local scream = sound(Config.Sounds.Scream, 1)
	local start = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local zoom = math.clamp(t / 0.15, 0, 1)
		local dist = 6.5 - zoom * 4.3
		local jitter = Vector3.new((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.25, 0)
		local target = (faceCF * CFrame.new(0, -0.25, 0)).Position
		local camPos = (faceCF * CFrame.new(0, -0.3, -dist)).Position + jitter
		camera.CFrame = CFrame.lookAt(camPos, target + jitter * 0.5) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.12)
		if jawHinge then
			local open = -math.clamp(t / 0.15, 0, 1) * 0.5 - math.abs(math.sin(t * 34)) * 0.08
			local move = jawHinge * CFrame.Angles(open, 0, 0) * jawHinge:Inverse()
			for _, jp in jawParts do
				jp.part.CFrame = move * jp.base
			end
		end
		viewport.Visible = math.random() > 0.12
		redFlash.BackgroundTransparency = 0.55 + math.random() * 0.45
	end)
	task.wait(1.2)
	conn:Disconnect()
	layer.Visible = false
	redFlash.BackgroundTransparency = 1
	UI.setNoiseOverride(0)
	Effects.extraShake = 0
	if scream then
		scream:Stop()
	end
	UI.notify(byName .. " jumpscared everyone!", "bad")
	playing = false
end

return Jumpscare
