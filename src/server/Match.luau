-- Én runde i sykehuset for en gruppe på 1-4 spillere.
-- Holder styr på liv, nøkler, skap, utgangen og monsteret.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent:WaitForChild("Util"))
local Monster = require(script.Parent:WaitForChild("Monster"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local JumpscareRemote = Remotes:WaitForChild("Jumpscare") :: RemoteEvent
local MatchStateRemote = Remotes:WaitForChild("MatchState") :: RemoteEvent
local PushedRemote = Remotes:WaitForChild("Pushed") :: RemoteEvent
local PushRemote = Remotes:WaitForChild("Push") :: RemoteEvent
local PrankRemote = Remotes:WaitForChild("Prank") :: RemoteEvent

local SLOT_SPACING = 1600 -- langt nok unna hverandre til at streaming aldri laster en annen runde
local LOCK_ON = Color3.fromRGB(40, 230, 90)

type PlayerState = {
	index: number,
	lives: number,
	keys: number,
	out: boolean,
	busy: boolean,
	protectedUntil: number,
	closet: Model?,
	closetChanged: number?,
	hiddenSince: number?,
	closetLeftAt: number?,
	downed: boolean?,
	downedUntil: number?,
	revivePrompt: ProximityPrompt?,
	downedGui: BillboardGui?,
	lastPush: number?,
}

local Match = {}
Match.__index = Match

function Match.new(manager: any, id: number, slot: number, players: { Player }, mode: string?)
	local self = setmetatable({}, Match)
	self.manager = manager
	self.id = id
	self.slot = slot
	self.mode = if mode == "Nightmare" then "Nightmare" else "Normal"
	self.nightmare = self.mode == "Nightmare"
	self.speedMultiplier = if self.nightmare then Config.Nightmare.MonsterSpeed else 1
	local startLives = if self.nightmare then Config.Nightmare.Lives else Config.Lives
	self.state = "starting" -- starting | playing | won | over | ended
	self.players = {} :: { [Player]: PlayerState }
	self.keysInserted = 0
	self.exitOpen = false
	self.closetOccupant = {} :: { [Model]: Player }
	self.connections = {} :: { RBXScriptConnection }
	self.choices = {} :: { [Player]: string }
	self.resolved = false
	self.origin = Vector3.new(SLOT_SPACING * slot, 0, 0)

	self.folder = Instance.new("Folder")
	self.folder.Name = "Match_" .. id
	self.folder:SetAttribute("Mode", self.mode)
	self.folder:SetAttribute("KeysInserted", 0)
	self.folder:SetAttribute("KeysTotal", Config.KeysToEscape)

	local template = ServerStorage:WaitForChild("HospitalTemplate") :: Model
	self.map = template:Clone()
	self.map.Name = "Map"
	self.map:PivotTo(CFrame.new(self.origin))
	self.map.Parent = self.folder
	-- Gulvhøyden leses fra selve gulvet, så kartet kan flyttes/redigeres i Studio
	local floor = self.map:WaitForChild("Floors"):WaitForChild("Floor") :: BasePart
	self.floorY = floor.Position.Y + floor.Size.Y / 2
	-- Hvor nødutgangen er (klientene bruker dette selv om døra ikke er lastet inn hos dem)
	local exitDoor = self.map:WaitForChild("ExitDoor")
	local header = exitDoor:WaitForChild("Header") :: BasePart
	local outside = exitDoor:WaitForChild("OutsideFloor") :: BasePart
	local out = outside.Position - header.Position
	self.folder:SetAttribute("ExitPos", Vector3.new(header.Position.X, self.floorY, header.Position.Z))
	self.folder:SetAttribute("ExitDir", Vector3.new(out.X, 0, out.Z).Unit)

	self.keysFolder = Instance.new("Folder")
	self.keysFolder.Name = "Keys"
	self.keysFolder.Parent = self.folder

	self.patrolPoints = {} :: { Vector3 }
	for _, p in self.map:WaitForChild("PatrolPoints"):GetChildren() do
		if p:IsA("BasePart") then
			table.insert(self.patrolPoints, p.Position)
		end
	end

	self.spawnPoints = {} :: { BasePart }
	for _, p in self.map:WaitForChild("SpawnPoints"):GetChildren() do
		table.insert(self.spawnPoints, p :: BasePart)
	end
	table.sort(self.spawnPoints, function(a, b)
		return a.Name < b.Name
	end)

	for i, player in players do
		self.players[player] = {
			index = i,
			lives = startLives,
			keys = 0,
			out = false,
			busy = false,
			protectedUntil = 0,
			closet = nil,
			closetChanged = 0,
		}
	end

	self.folder.Parent = workspace:WaitForChild("Matches")
	return self
end

------------------------------------------------------------------
-- Hjelpere
------------------------------------------------------------------

function Match:GetPlayerCount(): number
	local n = 0
	for _ in self.players do
		n += 1
	end
	return n
end

function Match:Notify(text: string, kind: string?, except: Player?)
	for player in self.players do
		if player ~= except then
			NotifyRemote:FireClient(player, text, kind)
		end
	end
end

function Match:CanBeHunted(player: Player): boolean
	local st = self.players[player]
	if not st or st.out or st.busy then
		return false
	end
	if os.clock() < st.protectedUntil then
		return false
	end
	return self.state == "playing"
end

function Match:GetFarPatrolPoint(): Vector3?
	local best, bestScore = nil, -1
	for _ = 1, 25 do
		local p = self.patrolPoints[math.random(1, #self.patrolPoints)]
		local nearest = math.huge
		for player in self.players do
			local root = Util.getRoot(player)
			if root then
				nearest = math.min(nearest, (root.Position - p).Magnitude)
			end
		end
		if nearest > bestScore then
			best, bestScore = p, nearest
		end
	end
	return best
end

function Match:_setPlayerAttributes(player: Player)
	local st = self.players[player]
	player:SetAttribute("InMatch", true)
	player:SetAttribute("MatchId", self.id)
	player:SetAttribute("Lives", st.lives)
	player:SetAttribute("Keys", st.keys)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("Out", st.out)
	player:SetAttribute("Flashlight", true)
	player:SetAttribute("Downed", false)
end

function Match:_spawnPlayer(player: Player)
	local st = self.players[player]
	if not st then
		return
	end
	local point = self.spawnPoints[((st.index - 1) % #self.spawnPoints) + 1]
	Util.placeCharacter(player, point.CFrame, false)
end

function Match:_toSpectator(player: Player)
	local box = self.map:FindFirstChild("SpectatorBox")
	local point = box and box:FindFirstChild("SpectatorPoint") :: BasePart?
	if point then
		Util.placeCharacter(player, point.CFrame, true)
	end
end

------------------------------------------------------------------
-- Oppstart
------------------------------------------------------------------

function Match:Start()
	self:_setupLamps()
	self:_setupClosets()
	self:_setupKeys()
	self:_setupExit()

	self.monster = Monster.new(self, ServerStorage:WaitForChild("Monster") :: Model, self.folder)
	-- Start så langt unna resepsjonen som mulig
	local spawnPos = self.spawnPoints[1].Position
	local farthest, farDist = self.patrolPoints[1], -1
	for _, p in self.patrolPoints do
		local d = (p - spawnPos).Magnitude
		if d > farDist then
			farthest, farDist = p, d
		end
	end
	self.monster:Teleport(farthest)

	-- Be klientene laste inn resepsjonen før vi flytter dem dit (streaming), maks 3 sekunder
	local pending = 0
	for player in self.players do
		pending += 1
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(spawnPos, 3)
			end)
			pending -= 1
		end)
	end
	local waitStart = os.clock()
	while pending > 0 and os.clock() - waitStart < 3 do
		task.wait(0.1)
	end

	for player in self.players do
		self:_setPlayerAttributes(player)
		self:_spawnPlayer(player)
		MatchStateRemote:FireClient(player, "start", { matchId = self.id, players = self:GetPlayerCount(), mode = self.mode, lives = self.players[player].lives })
	end

	self.state = "playing"
	self.startedAt = os.clock()
	task.delay(Config.Monster.StartDelay, function()
		if self.state == "playing" then
			self.monster:Activate()
			self:Notify("You hear something shuffling in the distance...", "bad")
		end
	end)
end

function Match:_setupLamps()
	local nearSpawn = self.spawnPoints[1].Position
	for _, lamp in self.map:WaitForChild("Lamps"):GetChildren() do
		local panel = lamp:FindFirstChild("Panel") :: BasePart?
		if not panel then
			continue
		end
		local light = panel:FindFirstChildOfClass("PointLight")
		local mode
		if (panel.Position - nearSpawn).Magnitude < 28 then
			mode = "on"
		else
			-- "dim" = en svak, summende lampe (ingen blinking; klienten styrer lysnivået)
			local r = math.random()
			local off = if self.nightmare then Config.Nightmare.LampsOff else 0.22
			mode = if r < off then "off" elseif r < off + 0.23 then "dim" else "on"
		end
		lamp:SetAttribute("Mode", mode)
		if mode == "off" then
			panel.Material = Enum.Material.SmoothPlastic
			panel.Color = Color3.fromRGB(60, 64, 62)
			if light then
				light.Enabled = false
			end
		elseif mode == "dim" and Config.Sounds.LampBuzz ~= "" then
			local buzz = Instance.new("Sound")
			buzz.Name = "Buzz"
			buzz.SoundId = Config.Sounds.LampBuzz
			buzz.Looped = true
			buzz.Volume = 0.18
			buzz.RollOffMinDistance = 4
			buzz.RollOffMaxDistance = 28
			buzz.Parent = panel
			buzz:Play()
		end
	end
end

function Match:_setupClosets()
	local closetFolder = self.map:WaitForChild("Closets")
	if self.nightmare then
		-- Nightmare: mange av skapene er borte
		local list = Util.shuffle(closetFolder:GetChildren())
		local keep = math.floor(#list * Config.Nightmare.ClosetsKept + 0.5)
		for i = keep + 1, #list do
			list[i]:Destroy()
		end
	end
	for _, closet in closetFolder:GetChildren() do
		local promptPart = closet:FindFirstChild("PromptPart")
		local prompt = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			closet:SetAttribute("Occupant", 0)
			table.insert(self.connections, prompt.Triggered:Connect(function(player)
				local st = self.players[player]
				if st and st.closet == closet then
					self:Unhide(player, true)
				elseif self.closetOccupant[closet] then
					NotifyRemote:FireClient(player, "Someone is already hiding in there.", "info")
				else
					self:Hide(player, closet :: Model)
				end
			end))
		end
	end
end

function Match:_setupKeys()
	local byRoom: { [string]: { BasePart } } = {}
	local rooms: { string } = {}
	for _, spot in self.map:WaitForChild("KeySpots"):GetChildren() do
		local room = spot:GetAttribute("Room") or "?"
		if not byRoom[room] then
			byRoom[room] = {}
			table.insert(rooms, room)
		end
		table.insert(byRoom[room], spot :: BasePart)
	end
	Util.shuffle(rooms)
	for i = 1, math.min(Config.KeysToEscape, #rooms) do
		local spots = byRoom[rooms[i]]
		self:_spawnKey(spots[math.random(1, #spots)].CFrame)
	end
end

function Match:_spawnKey(cframe: CFrame, dropped: boolean?)
	local key = (ServerStorage:WaitForChild("Key") :: Model):Clone()
	key:PivotTo(cframe)
	key:SetAttribute("Dropped", dropped == true)
	key.Parent = self.keysFolder
	local prompt = key:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			self:_pickupKey(player, key)
		end))
	end
end

function Match:_pickupKey(player: Player, key: Model)
	local st = self.players[player]
	if not st or st.out or st.busy or st.closet or self.state ~= "playing" or not key.Parent then
		return
	end
	local root = Util.getRoot(player)
	if not root or (root.Position - key:GetPivot().Position).Magnitude > 12 then
		return
	end
	key:Destroy()
	st.keys += 1
	player:SetAttribute("Keys", st.keys)
	Util.playSound(root, Config.Sounds.KeyPickup, 0.9, 40)
	NotifyRemote:FireClient(player, "You found a key! Follow the green EXIT marker to the emergency exit.", "good")
	if key:GetAttribute("Dropped") ~= true then
		self.manager:AwardCoins(player, Config.Coins.KeyFound, "key found")
	end
	self:Notify(player.DisplayName .. " found a key.", "info", player)
end

-- Legger nøkler på gulvet der en spiller døde eller forsvant
function Match:_dropKeys(count: number, position: Vector3)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = count > 1 and Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.5 or Vector3.zero
		local pos = Vector3.new(position.X, self.floorY + 0.25, position.Z) + offset
		self:_spawnKey(CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0), true)
	end
end

function Match:_setupExit()
	local exit = self.map:WaitForChild("ExitDoor")
	self.exit = exit
	local panel = exit:WaitForChild("LockPanel")
	local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			self:_insertKeys(player)
		end))
	end
	local zone = exit:WaitForChild("ExitZone") :: BasePart
	table.insert(self.connections, zone.Touched:Connect(function(hit)
		if not self.exitOpen or self.state ~= "playing" then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
		local st = player and self.players[player]
		if player and st and not st.out then
			self:Win(player)
		end
	end))
end

function Match:_updateExitVisuals()
	local exit = self.exit
	for i = 1, Config.KeysToEscape do
		local lock = exit:FindFirstChild("Lock" .. i) :: BasePart?
		if lock and i <= self.keysInserted then
			lock.Color = LOCK_ON
		end
	end
	local panel = exit:FindFirstChild("LockPanel")
	if panel then
		local counter = panel:FindFirstChild("Counter", true) :: TextLabel?
		if counter then
			counter.Text = self.keysInserted .. "/" .. Config.KeysToEscape
			counter.TextColor3 = self.keysInserted >= Config.KeysToEscape and LOCK_ON or Color3.fromRGB(255, 80, 70)
		end
		local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ObjectText = "Exit (" .. self.keysInserted .. "/" .. Config.KeysToEscape .. ")"
		end
	end
	self.folder:SetAttribute("KeysInserted", self.keysInserted)
end

function Match:_insertKeys(player: Player)
	local st = self.players[player]
	if not st or st.out or st.busy or self.state ~= "playing" or self.exitOpen then
		return
	end
	if st.keys <= 0 then
		NotifyRemote:FireClient(player, "You have no keys. Search the hospital!", "bad")
		return
	end
	local count = st.keys
	st.keys = 0
	player:SetAttribute("Keys", 0)
	self.keysInserted = math.min(Config.KeysToEscape, self.keysInserted + count)
	self:_updateExitVisuals()
	local panel = self.exit:FindFirstChild("LockPanel")
	if panel then
		Util.playSound(panel, Config.Sounds.KeyInsert, 1, 60)
	end
	local word = count == 1 and "key" or "keys"
	self:Notify(player.DisplayName .. " inserted " .. count .. " " .. word .. " (" .. self.keysInserted .. "/" .. Config.KeysToEscape .. ")", "good")
	self.manager:AwardCoins(player, Config.Coins.KeyInserted * count, "keys inserted")
	if self.keysInserted >= Config.Blackout.AfterKeys then
		self:_startBlackouts()
	end
	if self.keysInserted >= Config.KeysToEscape then
		self:_startFinale()
	end
end

-- Etter noen nøkler begynner strømmen å svikte: lyset går av og på med jevne mellomrom
function Match:_startBlackouts()
	if self.blackoutsStarted then
		return
	end
	self.blackoutsStarted = true
	local B = Config.Blackout
	task.spawn(function()
		task.wait(8)
		while self.state ~= "ended" do
			if self.state == "playing" and not self.finale then
				self.folder:SetAttribute("Blackout", true)
				self:Notify("The power is failing...", "bad")
				task.wait(math.random(B.Length[1], B.Length[2]))
				if (self.state :: string) == "ended" then
					break
				end
				self.folder:SetAttribute("Blackout", false)
			end
			task.wait(math.random(B.Every[1], B.Every[2]))
		end
	end)
end

-- Alle nøklene er inne: alarmen går, monsteret jakter, og døra åpner seg etter en stund
function Match:_startFinale()
	if self.finale then
		return
	end
	self.finale = true
	self.folder:SetAttribute("Blackout", false)
	self.folder:SetAttribute("FinaleEnd", workspace:GetServerTimeNow() + Config.FinaleTime)
	self:Notify("LOCKDOWN OVERRIDE. SURVIVE UNTIL THE DOOR OPENS!", "bad")
	if self.monster then
		self.monster:Enrage()
	end
	task.delay(Config.FinaleTime, function()
		if self.state == "playing" and self.finale then
			self:_openExit()
		end
	end)
end

function Match:_openExit()
	self.exitOpen = true
	local exit = self.exit
	local chain = exit:FindFirstChild("Chain")
	if chain then
		chain:Destroy()
	end
	local panel = exit:FindFirstChild("LockPanel")
	local prompt = panel and panel:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	-- hvitt lys strømmer inn gjennom døra
	local outsideLight = exit:FindFirstChild("OutsideLight")
	local glow = outsideLight and outsideLight:FindFirstChild("Glow")
	if glow and glow:IsA("PointLight") then
		glow.Enabled = true
		glow.Brightness = 0
		TweenService:Create(glow, info, { Brightness = 5 }):Play()
	end
	for _, name in { "DoorL", "DoorR" } do
		local door = exit:FindFirstChild(name) :: BasePart?
		if door then
			local dir = name == "DoorL" and -1 or 1
			TweenService:Create(door, info, { CFrame = door.CFrame * CFrame.new(dir * door.Size.X, 0, 0) }):Play()
		end
	end
	self.folder:SetAttribute("ExitOpen", true)
	self:Notify("THE DOOR IS OPEN! RUN!", "good")
end

------------------------------------------------------------------
-- Skap
------------------------------------------------------------------

function Match:Hide(player: Player, closet: Model)
	local st = self.players[player]
	if not st or st.out or st.busy or st.closet or self.state ~= "playing" then
		return
	end
	-- hindrer at samme tastetrykk både går ut og inn igjen
	if os.clock() - (st.closetChanged or 0) < 0.4 then
		return
	end
	if self.closetOccupant[closet] then
		return
	end
	-- litt pause mellom hver gang du gjemmer deg
	local wait = Config.Closet.Cooldown - (os.clock() - (st.closetLeftAt or -100))
	if wait > 0 then
		NotifyRemote:FireClient(player, string.format("You need to catch your breath first (%d s).", math.ceil(wait)), "bad")
		return
	end
	local hidePoint = closet:FindFirstChild("HidePoint") :: BasePart?
	local root = Util.getRoot(player)
	if not hidePoint or not root or (root.Position - hidePoint.Position).Magnitude > 12 then
		return
	end
	st.closet = closet
	st.closetChanged = os.clock()
	st.hiddenSince = os.clock()
	self.closetOccupant[closet] = player
	closet:SetAttribute("Occupant", player.UserId)
	player:SetAttribute("HiddenUntil", workspace:GetServerTimeNow() + Config.Closet.MaxTime)
	Util.placeCharacter(player, hidePoint.CFrame, true)
	player:SetAttribute("Hidden", true)
	Util.playSound(hidePoint, Config.Sounds.Locker, 0.8, 45)
	if self.monster then
		self.monster:OnPlayerHid(player)
	end
end

function Match:Unhide(player: Player, stepOut: boolean)
	local st = self.players[player]
	local closet = st and st.closet
	if not st or not closet then
		return
	end
	if stepOut and os.clock() - (st.closetChanged or 0) < 0.4 then
		return
	end
	st.closet = nil
	st.closetChanged = os.clock()
	st.closetLeftAt = os.clock()
	self.closetOccupant[closet] = nil
	closet:SetAttribute("Occupant", 0)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("ClosetCooldownUntil", workspace:GetServerTimeNow() + Config.Closet.Cooldown)
	local outPoint = closet:FindFirstChild("OutPoint") :: BasePart?
	local hidePoint = closet:FindFirstChild("HidePoint") :: BasePart?
	if stepOut and outPoint then
		Util.placeCharacter(player, outPoint.CFrame, st.busy)
		Util.playSound(outPoint, Config.Sounds.Locker, 0.8, 45)
		-- sikkerhetsnett: står spilleren fortsatt inne i skapet, flytt ut igjen
		task.delay(0.25, function()
			local root = Util.getRoot(player)
			if root and hidePoint and st.closet == nil and not st.busy and (root.Position - hidePoint.Position).Magnitude < 2 then
				Util.placeCharacter(player, outPoint.CFrame, false)
			end
		end)
	end
	if self.monster then
		self.monster:OnPlayerLeftCloset(player)
	end
end

------------------------------------------------------------------
-- Monsteret tar noen
------------------------------------------------------------------

function Match:OnMonsterSpotted(player: Player)
	NotifyRemote:FireClient(player, "IT FOUND YOU. RUN!", "bad")
end

-- Kan noen andre i runden hjelpe deg opp akkurat nå?
function Match:_hasRescuer(except: Player): boolean
	for other, ost in self.players do
		if other ~= except and not ost.out and not ost.busy and other.Parent ~= nil then
			return true
		end
	end
	return false
end

function Match:OnCaught(player: Player)
	local st = self.players[player]
	if not st or st.out or st.busy or self.state ~= "playing" then
		return
	end
	st.busy = true
	local root = Util.getRoot(player)
	local pos = root and root.Position
	if st.closet then
		local outPoint = st.closet:FindFirstChild("OutPoint") :: BasePart?
		if outPoint then
			pos = outPoint.Position
		end
		self:Unhide(player, false)
	end
	if Config.Downed.Time > 0 and pos and self:_hasRescuer(player) then
		self:_goDown(player, pos)
	else
		self:_loseLife(player, pos, true)
	end
end

-- Du ligger nede: en venn kan holde E på deg for å hjelpe deg opp
function Match:_goDown(player: Player, pos: Vector3)
	local st = self.players[player]
	st.downed = true
	st.downedUntil = os.clock() + Config.Downed.Time
	player:SetAttribute("Downed", true)
	player:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + Config.Downed.Time)
	JumpscareRemote:FireClient(player, st.lives, "downed")

	-- legg karakteren på ryggen på gulvet
	local root = Util.getRoot(player)
	local yaw = 0
	if root then
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
	end
	local floorPos = Vector3.new(pos.X, self.floorY + 0.9, pos.Z)
	Util.placeCharacter(player, CFrame.new(floorPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.pi / 2, 0, 0), true)

	root = Util.getRoot(player)
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Help up"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.Downed.HelpTime
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = root
		st.revivePrompt = prompt
		table.insert(self.connections, prompt.Triggered:Connect(function(helper)
			self:_helpUp(helper, player)
		end))

		-- rød markør over den som ligger nede (synlig gjennom vegger, så vennene finner deg)
		local gui = Instance.new("BillboardGui")
		gui.Name = "DownedMarker"
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(170, 46)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
		gui.MaxDistance = 300
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.SpecialElite
		label.TextColor3 = Color3.fromRGB(255, 70, 60)
		label.TextStrokeTransparency = 0.3
		label.Text = player.DisplayName .. " is DOWN"
		label.Parent = gui
		gui.Parent = root
		st.downedGui = gui
	end
	self:Notify(player.DisplayName .. " is down! Find them and hold E to help them up.", "bad", player)
end

function Match:_clearDowned(player: Player)
	local st = self.players[player]
	if not st then
		return
	end
	st.downed = false
	if st.revivePrompt then
		st.revivePrompt:Destroy()
		st.revivePrompt = nil
	end
	if st.downedGui then
		st.downedGui:Destroy()
		st.downedGui = nil
	end
	player:SetAttribute("Downed", false)
end

function Match:_helpUp(helper: Player, player: Player)
	local st, hs = self.players[player], self.players[helper]
	if not st or not st.downed or not hs or helper == player then
		return
	end
	if hs.out or hs.busy or hs.closet or self.state ~= "playing" then
		return
	end
	local hr, pr = Util.getRoot(helper), Util.getRoot(player)
	if not hr or not pr or (hr.Position - pr.Position).Magnitude > 12 then
		return
	end
	self:_clearDowned(player)
	st.busy = false
	st.protectedUntil = os.clock() + Config.Downed.Protection
	local p = pr.Position
	local look = hr.Position - p
	Util.placeCharacter(player, CFrame.lookAt(Vector3.new(p.X, self.floorY + 3, p.Z), Vector3.new(hr.Position.X, self.floorY + 3, hr.Position.Z) + (if look.Magnitude < 0.1 then Vector3.new(0, 0, -1) else Vector3.zero)), false)
	MatchStateRemote:FireClient(player, "helpedUp", { by = helper.DisplayName })
	self:Notify(helper.DisplayName .. " helped " .. player.DisplayName .. " up!", "good")
	if self.manager.OnHelped then
		self.manager:OnHelped(helper)
	end
end

-- Du mister et liv: nøklene faller der du var, og du starter i resepsjonen (eller er ute)
function Match:_loseLife(player: Player, pos: Vector3?, withScare: boolean)
	local st = self.players[player]
	if not st then
		return
	end
	st.busy = true
	if st.keys > 0 and pos then
		self:_dropKeys(st.keys, pos)
		st.keys = 0
		player:SetAttribute("Keys", 0)
	end
	st.lives -= 1
	player:SetAttribute("Lives", st.lives)
	Util.setAnchored(player, true)
	if withScare then
		JumpscareRemote:FireClient(player, st.lives)
	else
		MatchStateRemote:FireClient(player, "lostLife", { lives = st.lives })
	end
	if st.lives > 0 then
		self:Notify(player.DisplayName .. " was caught! (" .. st.lives .. (st.lives == 1 and " life" or " lives") .. " left)", "bad", player)
	else
		self:Notify(player.DisplayName .. " was caught and is out of the game.", "bad", player)
	end

	task.delay(Config.RespawnDelay, function()
		if self.state ~= "playing" or self.players[player] ~= st then
			return
		end
		st.busy = false
		if st.lives > 0 then
			self:_spawnPlayer(player)
			st.protectedUntil = os.clock() + Config.RespawnProtection
		else
			st.out = true
			player:SetAttribute("Out", true)
			player:SetAttribute("Flashlight", false)
			self:_toSpectator(player)
			self:_checkGameOver()
			if self.state == "playing" then
				MatchStateRemote:FireClient(player, "dead", { seconds = Config.DeathChoiceTime })
			end
		end
	end)
end

function Match:OnCharacterAdded(player: Player)
	local st = self.players[player]
	if not st then
		return
	end
	task.defer(function()
		local character = player.Character
		if not character then
			return
		end
		character:WaitForChild("HumanoidRootPart", 5)
		if self.players[player] ~= st or self.state == "ended" then
			return
		end
		if st.out then
			self:_toSpectator(player)
		else
			if st.closet then
				self:Unhide(player, false)
			end
			self:_spawnPlayer(player)
			if st.busy then
				Util.setAnchored(player, true)
			end
		end
	end)
end

------------------------------------------------------------------
-- Slutt på runden
------------------------------------------------------------------

function Match:_checkGameOver()
	if self.state ~= "playing" then
		return
	end
	for _, st in self.players do
		if not st.out then
			return
		end
	end
	self:GameOver()
end

function Match:Win(escaper: Player)
	if self.state ~= "playing" then
		return
	end
	self.state = "won"
	-- alarmen og strømbruddene stopper; klientene spiller sluttscenen
	self.folder:SetAttribute("FinaleEnd", nil)
	self.folder:SetAttribute("Blackout", false)
	if self.monster then
		self.monster:Stop()
		-- gjem det ekte monsteret; sluttscenen bruker sin egen kopi
		self.monster.root.CFrame = self.monster.root.CFrame + Vector3.new(0, -150, 0)
	end
	-- sluttscenen filmes ved nødutgangen: sørg for at den er lastet inn hos alle (streaming)
	local header = self.exit and self.exit:FindFirstChild("Header") :: BasePart?
	for player in self.players do
		if header then
			player.ReplicationFocus = header
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(header.Position, 3)
				end)
			end)
		end
	end
	for player, st in self.players do
		if st.closet then
			self:Unhide(player, true)
		end
		self.manager:AwardCoins(player, Config.Coins.Escape, "escaped")
		MatchStateRemote:FireClient(player, "won", {
			escaper = escaper.DisplayName,
			seconds = Config.WinReturnTime,
		})
	end
	task.delay(Config.WinReturnTime, function()
		self.manager:EndMatch(self, {})
	end)
end

function Match:GameOver()
	self.state = "over"
	if self.monster then
		self.monster:Stop()
	end
	for player in self.players do
		MatchStateRemote:FireClient(player, "gameover", { seconds = Config.GameOverChoiceTime })
	end
	self.overToken = (self.overToken or 0) + 1
	local token = self.overToken
	task.delay(Config.GameOverChoiceTime, function()
		if self.overToken == token and self.state == "over" then
			self:_resolveChoices()
		end
	end)
end

------------------------------------------------------------------
-- Revive (kjøpt for Robux)
------------------------------------------------------------------

function Match:CanRevive(player: Player): boolean
	local st = self.players[player]
	if not st or not st.out or self.resolved then
		return false
	end
	return self.state == "playing" or self.state == "over"
end

function Match:Revive(player: Player): boolean
	if not self:CanRevive(player) then
		return false
	end
	local st = self.players[player]
	local wasOver = self.state == "over"
	st.out = false
	st.busy = false
	st.closet = nil
	st.lives = 1
	st.keys = 0
	st.protectedUntil = os.clock() + Config.ReviveProtection
	self:_setPlayerAttributes(player)
	self:_spawnPlayer(player)
	if wasOver then
		-- runden fortsetter: avbryt game over-nedtellingen og vekk monsteret igjen
		self.state = "playing"
		self.overToken = (self.overToken or 0) + 1
		self.choices = {}
		if self.monster then
			local far = self:GetFarPatrolPoint()
			if far then
				self.monster:Teleport(far)
			end
			self.monster:Activate()
		end
		for p in self.players do
			MatchStateRemote:FireClient(p, "resume")
		end
	else
		MatchStateRemote:FireClient(player, "revived")
	end
	self:Notify(player.DisplayName .. " was revived!", "good")
	return true
end

------------------------------------------------------------------
-- Push (game pass) og "Jumpscare everyone" (developer product)
------------------------------------------------------------------

function Match:Push(player: Player): boolean
	local st = self.players[player]
	if not st or st.out or st.busy or st.closet or self.state ~= "playing" then
		return false
	end
	if player:GetAttribute("HasPush") ~= true then
		return false
	end
	local now = os.clock()
	if now - (st.lastPush or 0) < Config.Push.Cooldown then
		return false
	end
	local root = Util.getRoot(player)
	if not root then
		return false
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local best, bestDist = nil, Config.Push.Range
	for other, ost in self.players do
		if other == player or ost.out or ost.busy or ost.closet then
			continue
		end
		local oroot = Util.getRoot(other)
		if oroot then
			local offset = Vector3.new(oroot.Position.X - root.Position.X, 0, oroot.Position.Z - root.Position.Z)
			local dist = offset.Magnitude
			if dist <= bestDist and (dist < 1.5 or look:Dot(offset.Unit) > 0.35) then
				best, bestDist = other, dist
			end
		end
	end
	if not best then
		NotifyRemote:FireClient(player, "Nobody close enough to push.", "info")
		return false
	end
	st.lastPush = now
	PushRemote:FireClient(player, "cooldown", Config.Push.Cooldown)
	PushedRemote:FireClient(best, look, player.DisplayName)
	local broot = Util.getRoot(best)
	if broot then
		Util.playSound(broot, Config.Sounds.Push, 1, 50)
	end
	return true
end

function Match:CountPrankTargets(player: Player): number
	local n = 0
	for other in self.players do
		if other ~= player then
			n += 1
		end
	end
	return n
end

function Match:JumpscareAll(player: Player): number
	local n = 0
	for other in self.players do
		if other ~= player then
			PrankRemote:FireClient(other, player.DisplayName)
			n += 1
		end
	end
	if n > 0 then
		NotifyRemote:FireClient(player, "You jumpscared everyone!", "good")
	end
	return n
end

function Match:OnChoice(player: Player, choice: string)
	if self.state ~= "over" or not self.players[player] then
		return
	end
	if choice ~= "retry" and choice ~= "lobby" then
		return
	end
	self.choices[player] = choice
	for p in self.players do
		if not self.choices[p] then
			return
		end
	end
	self:_resolveChoices()
end

function Match:_resolveChoices()
	if self.resolved or self.state == "ended" then
		return
	end
	self.resolved = true
	local retry = {}
	for player in self.players do
		if self.choices[player] == "retry" then
			table.insert(retry, player)
		end
	end
	self.manager:EndMatch(self, retry)
end

-- En spiller forlot spillet
function Match:RemovePlayer(player: Player)
	local st = self.players[player]
	if not st then
		return
	end
	if st.closet then
		self:Unhide(player, false)
	end
	local root = Util.getRoot(player)
	if st.keys > 0 and root and self.state == "playing" then
		self:_dropKeys(st.keys, root.Position)
	end
	self.players[player] = nil
	self.choices[player] = nil
	if self.monster then
		self.monster:ForgetPlayer(player)
	end
	if self:GetPlayerCount() == 0 then
		self.manager:EndMatch(self, {})
		return
	end
	self:Notify(player.DisplayName .. " left the game.", "info")
	if self.state == "playing" then
		self:_checkGameOver()
	elseif self.state == "over" then
		local allChosen = true
		for p in self.players do
			if not self.choices[p] then
				allChosen = false
			end
		end
		if allChosen then
			self:_resolveChoices()
		end
	end
end

function Match:Step(dt: number)
	if self.monster and (self.state == "playing") then
		self.monster:Step(dt)
	end
	-- ingen kan holde pusten for alltid: etter Closet.MaxTime sekunder må du ut av skapet
	if self.state == "playing" then
		for player, st in self.players do
			-- de som ligger nede: tiden går ut, eller det er ingen igjen som kan hjelpe
			if st.downed then
				local left = (st.downedUntil or 0) - os.clock()
				if left <= 0 or not self:_hasRescuer(player) then
					local root = Util.getRoot(player)
					self:_clearDowned(player)
					self:_loseLife(player, root and root.Position, false)
				elseif st.downedGui then
					local label = st.downedGui:FindFirstChild("Text") :: TextLabel?
					if label then
						label.Text = string.format("%s is DOWN  %d", player.DisplayName, math.ceil(left))
					end
				end
				continue
			end
			if st.closet and not st.busy and os.clock() - (st.hiddenSince or os.clock()) >= Config.Closet.MaxTime then
				self:Unhide(player, true)
				NotifyRemote:FireClient(player, "You couldn't hold your breath any longer!", "bad")
			end
		end
	end
end

function Match:Destroy()
	self.state = "ended"
	for _, c in self.connections do
		c:Disconnect()
	end
	self.connections = {}
	if self.monster then
		self.monster:Destroy()
		self.monster = nil
	end
	self.folder:Destroy()
end

return Match
