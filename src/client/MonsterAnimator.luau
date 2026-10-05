-- Animerer monsteret lokalt på hver klient (serveren flytter bare Root).
-- Halting, rykk i hodet, kjeve som klaprer når den jakter, arm som dingler,
-- hodet som følger deg med blikket, og knirkende hjul på dryppstativet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local MonsterAnimator = {}

local JOINTS = { "Waist", "Spine", "Neck", "Jaw", "RShoulder", "RElbow", "LShoulder", "LElbow", "LHip", "LKnee", "RHip", "RKnee" }
local STRIDE = 5.5 -- studs per hele steg-syklus
local ANIM_DISTANCE = 160

type State = {
	model: Model,
	root: BasePart,
	welds: { [string]: Weld },
	base: { [string]: CFrame },
	lastPos: Vector3,
	phase: number,
	walk: number,
	chase: number,
	twitch: CFrame,
	twitchTarget: CFrame,
	twitchTimer: number,
	look: number,
	squeak: Sound?,
}

local states: { [Model]: State } = {}

local function setup(model: Model): State?
	local root = model:FindFirstChild("Root") :: BasePart?
	local jointFolder = model:FindFirstChild("Joints")
	if not root or not jointFolder then
		return nil
	end
	local welds, base = {}, {}
	for _, name in JOINTS do
		local w = jointFolder:FindFirstChild(name)
		if w and w:IsA("Weld") then
			welds[name] = w
			base[name] = w.C0
		end
	end
	local state: State = {
		model = model,
		root = root,
		welds = welds,
		base = base,
		lastPos = root.Position,
		phase = 0,
		walk = 0,
		chase = 0,
		twitch = CFrame.identity,
		twitchTarget = CFrame.identity,
		twitchTimer = 0,
		look = 0,
		squeak = root:FindFirstChild("Squeak") :: Sound?,
	}
	return state
end

local function crack(root: BasePart)
	if Config.Sounds.BoneCrack == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = Config.Sounds.BoneCrack
	s.Volume = 0.5
	s.PlaybackSpeed = 0.85 + math.random() * 0.3
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = 30
	s.Parent = root
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

local function set(st: State, name: string, cf: CFrame)
	local w = st.welds[name]
	local b = st.base[name]
	if w and b then
		w.C0 = b * cf
	end
end

local function animate(st: State, dt: number, t: number, camPos: Vector3)
	local root = st.root
	local pos = root.Position
	local moved = Vector3.new(pos.X - st.lastPos.X, 0, pos.Z - st.lastPos.Z).Magnitude
	st.lastPos = pos
	if moved > 8 then
		moved = 0 -- teleport, ikke gange
	end
	local speed = dt > 0 and moved / dt or 0
	local chasing = st.model:GetAttribute("Chasing") == true

	st.walk += (math.clamp(speed / 8, 0, 1) - st.walk) * math.min(1, dt * 6)
	st.chase += ((chasing and 1 or 0) - st.chase) * math.min(1, dt * 4)
	st.phase = (st.phase + moved * (2 * math.pi / STRIDE)) % (2 * math.pi)
	local w, ch, ph = st.walk, st.chase, st.phase

	-- Ben: venstre tar lange steg, høyre slepes etter (halting)
	local sinP, cosP = math.sin(ph), math.cos(ph)
	set(st, "LHip", CFrame.Angles(sinP * 0.42 * w, 0, 0))
	set(st, "LKnee", CFrame.Angles(-math.max(0, cosP) * 0.75 * w, 0, 0))
	set(st, "RHip", CFrame.Angles(-sinP * 0.22 * w, 0, math.rad(4) * w))
	set(st, "RKnee", CFrame.Angles(-math.max(0, -cosP) * 0.3 * w, 0, 0))

	-- Kropp: dupper ned på det dårlige benet, lener seg frem når den jakter
	local bob = -math.abs(sinP) * 0.18 * w - math.max(0, -sinP) * 0.12 * w
	set(st, "Waist", CFrame.new(0, bob, 0) * CFrame.Angles(0, sinP * 0.05 * w, math.sin(ph + 0.6) * 0.06 * w))
	local breathe = math.sin(t * 1.4) * 0.025
	set(st, "Spine", CFrame.Angles(-0.14 * ch + breathe, 0, math.sin(ph) * 0.03 * w))

	-- Høyre arm dingler, strekker seg frem mot deg når den jakter
	local sway = math.sin(t * 0.9) * 0.05
	set(st, "RShoulder", CFrame.Angles(-sinP * 0.28 * w + sway + 0.75 * ch, 0, math.rad(-4) * ch))
	set(st, "RElbow", CFrame.Angles(0.12 + 0.35 * ch + math.max(0, sinP) * 0.15 * w, 0, 0))
	set(st, "LShoulder", CFrame.Angles(breathe * 0.5, 0, 0))

	-- Hodet: følger deg med blikket og rykker brått
	local headPos = (root.CFrame * CFrame.new(0, 9.8, -2)).Position
	local toCam = root.CFrame:VectorToObjectSpace(camPos - headPos)
	local wantLook = 0
	if toCam.Magnitude < 45 then
		wantLook = math.clamp(math.atan2(-toCam.X, -toCam.Z), -0.9, 0.9)
	end
	st.look += (wantLook - st.look) * math.min(1, dt * 3)

	st.twitchTimer -= dt
	if st.twitchTimer <= 0 then
		local big = math.random() < (0.12 + 0.3 * ch)
		local amount = big and 0.75 or (0.08 + 0.18 * ch)
		st.twitchTarget = CFrame.Angles((math.random() - 0.5) * amount, (math.random() - 0.5) * amount * 1.4, (math.random() - 0.5) * amount * 2)
		st.twitchTimer = big and (0.08 + math.random() * 0.12) or (0.15 + math.random() * 0.6)
		if big and (camPos - headPos).Magnitude < 30 and math.random() < 0.5 then
			crack(root)
		end
	end
	-- brå rykk: nesten øyeblikkelig overgang
	st.twitch = st.twitch:Lerp(st.twitchTarget, math.min(1, dt * 22))
	set(st, "Neck", CFrame.Angles(0, st.look, 0) * st.twitch)

	-- Kjeven: hviler litt åpen, gaper og klaprer når den jakter
	local idleJaw = -0.04 - math.max(0, math.sin(t * 0.7)) * 0.06
	local chatter = -(0.2 + math.abs(math.sin(t * 26)) * 0.14)
	set(st, "Jaw", CFrame.Angles(idleJaw + (chatter - idleJaw) * ch, 0, 0))

	-- Knirkende hjul på dryppstativet
	local squeak = st.squeak
	if squeak then
		squeak.Volume = math.clamp(speed / 10, 0, 1) * 0.6
		squeak.PlaybackSpeed = 0.9 + math.clamp(speed / 16, 0, 1) * 0.35
	end
end

function MonsterAnimator.init()
	RunService.RenderStepped:Connect(function(dt)
		local matches = workspace:FindFirstChild("Matches")
		local myMatch = player:GetAttribute("MatchId")
		local folder = matches and myMatch and matches:FindFirstChild("Match_" .. tostring(myMatch))
		local monster = folder and folder:FindFirstChild("Monster")

		-- glem monstre som ikke finnes lenger
		for model in states do
			if model ~= monster or not model.Parent then
				states[model] = nil
			end
		end
		if not monster or not monster:IsA("Model") then
			return
		end
		local st = states[monster]
		if not st then
			local created = setup(monster)
			if not created then
				return
			end
			states[monster] = created
			st = created
		end
		local camPos = workspace.CurrentCamera.CFrame.Position
		if (camPos - st.root.Position).Magnitude > ANIM_DISTANCE then
			return
		end
		animate(st, dt, os.clock(), camPos)
	end)
end

return MonsterAnimator
