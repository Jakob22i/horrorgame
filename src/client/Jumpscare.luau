-- Jumpscare: ansiktet hennes fyller skjermen med støy, skrik og risting.

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
local faceCenter = Vector3.new(0, 11.5, 0.1)
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
	if Config.MonsterFaceDecal ~= "" then
		local head = model:FindFirstChild("Head")
		local plate = head and head:FindFirstChild("FaceDecalPlate")
		if head and plate then
			local decal = Instance.new("Decal")
			decal.Texture = Config.MonsterFaceDecal
			decal.Face = Enum.NormalId.Front
			decal.Parent = plate
			for _, name in { "EyeL", "EyeR", "PupilL", "PupilR", "Nose", "Lips", "Mouth" } do
				local p = head:FindFirstChild(name)
				if p and p:IsA("BasePart") then
					p.Transparency = 1
				end
			end
		end
	end
	local face = model:FindFirstChild("Face", true)
	if face and face:IsA("BasePart") then
		faceCenter = face.Position
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

function Jumpscare.play(livesLeft: number)
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
		local dist = 6 - zoom * 4.2 + math.sin(t * 40) * 0.08
		local jitter = Vector3.new((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.25, 0)
		local camPos = faceCenter + Vector3.new(0, -0.1, -dist) + jitter
		camera.CFrame = CFrame.lookAt(camPos, faceCenter + jitter * 0.5) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.12)
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

	local message
	if livesLeft > 1 then
		message = "IT GOT YOU\n\n" .. livesLeft .. " lives left"
	elseif livesLeft == 1 then
		message = "IT GOT YOU\n\n1 life left"
	else
		message = "IT GOT YOU\n\nNo lives left..."
	end
	UI.fadeOut(message, 0.05)
	task.delay(1.2, function()
		if scream then
			scream:Stop()
		end
	end)
	task.wait(math.max(0.5, Config.RespawnDelay - duration - 0.2))
	UI.fadeIn(0.8)
	playing = false
end

return Jumpscare
