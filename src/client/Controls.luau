-- Styring: løping med utholdenhet, lommelykt, gå ut av skap og tilskuermodus.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ToggleFlashlightRemote = Remotes:WaitForChild("ToggleFlashlight") :: RemoteEvent
local LeaveClosetRemote = Remotes:WaitForChild("LeaveCloset") :: RemoteEvent
local ShopRemote = Remotes:WaitForChild("Shop") :: RemoteEvent
local PushRemote = Remotes:WaitForChild("Push") :: RemoteEvent
local PushedRemote = Remotes:WaitForChild("Pushed") :: RemoteEvent

local player = Players.LocalPlayer

local Controls = {}

local UI: any
local inMatch = false
local frozen = false -- sluttscenen: ingen bevegelse
local sprintHeld = false
local stamina = Config.StaminaMax
local exhausted = false
local lastSprint = 0
local flashPart: Part
local flashLight: SpotLight
local fillLight: PointLight
local clickSound: Sound
local spectateIndex = 1
local spectating: Player? = nil

local LOBBY_SPEED = 16

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function attr(name: string): any
	return player:GetAttribute(name)
end

------------------------------------------------------------------
-- Lommelykt
------------------------------------------------------------------

local function buildFlashlight()
	flashPart = Instance.new("Part")
	flashPart.Name = "LocalFlashlight"
	flashPart.Size = Vector3.new(0.2, 0.2, 0.2)
	flashPart.Transparency = 1
	flashPart.Anchored = true
	flashPart.CanCollide = false
	flashPart.CanQuery = false
	flashPart.CanTouch = false
	flashPart.CastShadow = false
	flashPart.Parent = workspace

	flashLight = Instance.new("SpotLight")
	flashLight.Face = Enum.NormalId.Front
	flashLight.Angle = 60
	flashLight.Range = 60
	flashLight.Brightness = 3.1
	flashLight.Color = Color3.fromRGB(255, 244, 220)
	flashLight.Shadows = true
	flashLight.Enabled = false
	flashLight.Parent = flashPart

	fillLight = Instance.new("PointLight")
	fillLight.Range = 7
	fillLight.Brightness = 0.35
	fillLight.Color = Color3.fromRGB(255, 244, 220)
	fillLight.Shadows = false
	fillLight.Enabled = false
	fillLight.Parent = flashPart

	clickSound = Instance.new("Sound")
	clickSound.SoundId = Config.Sounds.Flashlight
	clickSound.Volume = 0.6
	clickSound.Parent = SoundService
end

local function flashlightOn(): boolean
	return inMatch and attr("Flashlight") == true and attr("Out") ~= true
end

-- Andre spilleres lommelykter (vises lokalt som et lys i hodet deres)
local function updateOtherFlashlights()
	local myMatch = attr("MatchId")
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			continue
		end
		local light = head:FindFirstChild("RemoteFlashlight") :: SpotLight?
		local shouldShow = inMatch
			and other:GetAttribute("MatchId") == myMatch
			and other:GetAttribute("Flashlight") == true
			and other:GetAttribute("Out") ~= true
		if shouldShow and not light then
			local l = Instance.new("SpotLight")
			l.Name = "RemoteFlashlight"
			l.Face = Enum.NormalId.Front
			l.Angle = 55
			l.Range = 52
			l.Brightness = 2.6
			l.Color = Color3.fromRGB(255, 244, 220)
			l.Shadows = true
			l.Parent = head
			light = l
		end
		if light then
			light.Enabled = shouldShow
		end
	end
end

-- Knappene nederst og tastene 1, 2 og 3 gjør det samme
function Controls.doAction(name: string)
	if not inMatch or frozen then
		return
	end
	if name == "flashlight" then
		if attr("Out") ~= true then
			ToggleFlashlightRemote:FireServer()
		end
	elseif name == "push" then
		if attr("Out") == true or attr("Hidden") == true then
			return
		end
		if attr("HasPush") == true then
			PushRemote:FireServer()
		else
			ShopRemote:FireServer("push")
		end
	elseif name == "jumpscare" then
		ShopRemote:FireServer("jumpscare")
	end
end

local function keyAction(actionName: string)
	return function(_name: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		Controls.doAction(actionName)
		return Enum.ContextActionResult.Sink
	end
end

-- Når noen dytter deg: du eier din egen karakter, så dyttet gjøres her på klienten
local function onPushed(dir: Vector3, byName: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or root.Anchored or typeof(dir) ~= "Vector3" then
		return
	end
	UI.notify(tostring(byName) .. " pushed you!", "bad")
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if t > 0.35 or not root.Parent or root.Anchored then
			conn:Disconnect()
			return
		end
		local v = Config.Push.Speed * (1 - t / 0.35)
		local y = root.AssemblyLinearVelocity.Y
		if t < 0.05 then
			y = math.max(y, 14)
		end
		root.AssemblyLinearVelocity = Vector3.new(flat.X * v, y, flat.Z * v)
	end)
end

------------------------------------------------------------------
-- Løping
------------------------------------------------------------------

local function onSprintAction(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		sprintHeld = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	return Enum.ContextActionResult.Pass
end

------------------------------------------------------------------
-- Skap
------------------------------------------------------------------

-- Skapets egen prompt brukes både for å gå inn og ut. Her endrer vi teksten lokalt:
-- "Leave" på skapet du står i, og skjuler prompten på skap som andre gjemmer seg i.
local function updateClosetPrompts()
	if not inMatch then
		return
	end
	local matches = workspace:FindFirstChild("Matches")
	local folder = matches and matches:FindFirstChild("Match_" .. tostring(attr("MatchId")))
	local map = folder and folder:FindFirstChild("Map")
	local closets = map and map:FindFirstChild("Closets")
	if not closets then
		return
	end
	for _, closet in closets:GetChildren() do
		local promptPart = closet:FindFirstChild("PromptPart")
		local prompt = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local occupant = closet:GetAttribute("Occupant") or 0
			local mine = occupant == player.UserId
			prompt.ActionText = mine and "Leave" or "Hide"
			prompt.Enabled = occupant == 0 or mine
		end
	end
end

local function refreshHidden()
	if attr("Hidden") == true then
		UI.setHint("You are hiding. Press E or click LEAVE to get out.")
		UI.setLeaveButton(true)
	else
		UI.setHint(nil)
		UI.setLeaveButton(false)
	end
	updateClosetPrompts()
end

------------------------------------------------------------------
-- Tilskuer (når du ikke har flere liv)
------------------------------------------------------------------

local function teammates(): { Player }
	local list = {}
	local myMatch = attr("MatchId")
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("MatchId") == myMatch and other:GetAttribute("Out") ~= true then
			table.insert(list, other)
		end
	end
	return list
end

local function updateSpectate()
	local camera = workspace.CurrentCamera
	if frozen then
		UI.setSpectate(nil)
		return
	end
	if inMatch and attr("Out") == true then
		local list = teammates()
		if #list == 0 then
			spectating = nil
			UI.setSpectate("You are out of the game.")
			return
		end
		spectateIndex = ((spectateIndex - 1) % #list) + 1
		local target = list[spectateIndex]
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if hum and camera.CameraSubject ~= hum then
			camera.CameraSubject = hum
		end
		if spectating ~= target then
			spectating = target
		end
		player.CameraMode = Enum.CameraMode.Classic
		UI.setSpectate("WATCHING: " .. target.DisplayName .. "   (click to switch)")
	else
		if spectating then
			spectating = nil
			local hum = getHumanoid()
			if hum then
				camera.CameraSubject = hum
			end
		end
		UI.setSpectate(nil)
	end
end

------------------------------------------------------------------

function Controls.init(ui: any)
	UI = ui
	buildFlashlight()

	ContextActionService:BindAction("Sprint", onSprintAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Run")
	ContextActionService:BindAction("Flashlight", keyAction("flashlight"), false, Enum.KeyCode.One, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("Push", keyAction("push"), false, Enum.KeyCode.Two)
	ContextActionService:BindAction("JumpscareAll", keyAction("jumpscare"), false, Enum.KeyCode.Three)
	UI.onAction("Flashlight", function()
		Controls.doAction("flashlight")
	end)
	UI.onAction("Push", function()
		Controls.doAction("push")
	end)
	UI.onAction("Jumpscare", function()
		Controls.doAction("jumpscare")
	end)
	PushedRemote.OnClientEvent:Connect(onPushed)
	PushRemote.OnClientEvent:Connect(function(kind, seconds)
		if kind == "cooldown" and typeof(seconds) == "number" then
			UI.startCooldown("Push", seconds)
		end
	end)

	player:GetAttributeChangedSignal("Hidden"):Connect(refreshHidden)
	UI.onLeaveClicked(function()
		if attr("Hidden") == true then
			LeaveClosetRemote:FireServer()
		end
	end)
	player:GetAttributeChangedSignal("Flashlight"):Connect(function()
		if inMatch then
			clickSound:Play()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if inMatch and attr("Out") == true then
				spectateIndex += 1
			end
		end
	end)

	local otherTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		-- Egen lommelykt følger kameraet
		local camera = workspace.CurrentCamera
		local on = flashlightOn()
		flashLight.Enabled = on
		fillLight.Enabled = on
		if on then
			flashPart.CFrame = camera.CFrame * CFrame.new(0.4, -0.4, -0.5)
		end

		otherTimer -= dt
		if otherTimer <= 0 then
			otherTimer = 0.3
			updateOtherFlashlights()
			updateSpectate()
			updateClosetPrompts()
		end

		-- Løping og utholdenhet
		local hum = getHumanoid()
		if not hum then
			return
		end
		if frozen then
			hum.WalkSpeed = 0
			UI.setStamina(1, false)
			return
		end
		if not inMatch then
			hum.WalkSpeed = LOBBY_SPEED
			UI.setStamina(1, false)
			return
		end
		local moving = hum.MoveDirection.Magnitude > 0.1
		local canSprint = sprintHeld and moving and not exhausted and attr("Hidden") ~= true and attr("Out") ~= true
		if canSprint then
			stamina = math.max(0, stamina - Config.StaminaDrain * dt)
			lastSprint = os.clock()
			hum.WalkSpeed = Config.SprintSpeed
			if stamina <= 0 then
				exhausted = true
			end
		else
			hum.WalkSpeed = Config.WalkSpeed
			if os.clock() - lastSprint > Config.StaminaRegenDelay then
				stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt)
			end
			if exhausted and stamina >= Config.StaminaMax * 0.35 then
				exhausted = false
			end
		end
		UI.setStamina(stamina / Config.StaminaMax, stamina < Config.StaminaMax)
	end)
end

function Controls.setMode(matchMode: boolean)
	inMatch = matchMode
	stamina = Config.StaminaMax
	exhausted = false
	if matchMode then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 14
		local hum = getHumanoid()
		if hum then
			workspace.CurrentCamera.CameraSubject = hum
		end
	end
	refreshHidden()
end

function Controls.setFrozen(on: boolean)
	frozen = on
	sprintHeld = false
end

-- Kalles når du får tilbake kontrollen etter å ha vært tilskuer
function Controls.onOutChanged()
	if inMatch and attr("Out") ~= true then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

return Controls
