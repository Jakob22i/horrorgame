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

local SLOT_SPACING = 1000
local LOCK_ON = Color3.fromRGB(40, 230, 90)

type PlayerState = {
	index: number,
	lives: number,
	keys: number,
	out: boolean,
	busy: boolean,
	protectedUntil: number,
	closet: Model?,
}

local Match = {}
Match.__index = Match

function Match.new(manager: any, id: number, slot: number, players: { Player })
	local self = setmetatable({}, Match)
	self.manager = manager
	self.id = id
	self.slot = slot
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
			lives = Config.Lives,
			keys = 0,
			out = false,
			busy = false,
			protectedUntil = 0,
			closet = nil,
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

	for player in self.players do
		self:_setPlayerAttributes(player)
		self:_spawnPlayer(player)
		MatchStateRemote:FireClient(player, "start", { matchId = self.id, players = self:GetPlayerCount() })
	end

	self.state = "playing"
	task.delay(Config.Monster.StartDelay, function()
		if self.state == "playing" then
			self.monster:Activate()
			self:Notify("Du hører noe i det fjerne...", "bad")
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
			local r = math.random()
			mode = r < 0.4 and "on" or (r < 0.68 and "flicker" or "off")
		end
		lamp:SetAttribute("Mode", mode)
		if mode == "off" then
			panel.Material = Enum.Material.SmoothPlastic
			panel.Color = Color3.fromRGB(60, 64, 62)
			if light then
				light.Enabled = false
			end
		elseif mode == "flicker" and Config.Sounds.LampBuzz ~= "" then
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
	for _, closet in self.map:WaitForChild("Closets"):GetChildren() do
		local promptPart = closet:FindFirstChild("PromptPart")
		local prompt = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			table.insert(self.connections, prompt.Triggered:Connect(function(player)
				self:Hide(player, closet :: Model)
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

function Match:_spawnKey(cframe: CFrame)
	local key = (ServerStorage:WaitForChild("Key") :: Model):Clone()
	key:PivotTo(cframe)
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
	NotifyRemote:FireClient(player, "Du fant en nøkkel! Ta den med til nødutgangen.", "good")
	self:Notify(player.DisplayName .. " fant en nøkkel.", "info", player)
end

-- Legger nøkler på gulvet der en spiller døde eller forsvant
function Match:_dropKeys(count: number, position: Vector3)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = count > 1 and Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.5 or Vector3.zero
		local pos = Vector3.new(position.X, self.floorY + 0.25, position.Z) + offset
		self:_spawnKey(CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
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
			prompt.ObjectText = "Utgang (" .. self.keysInserted .. "/" .. Config.KeysToEscape .. ")"
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
		NotifyRemote:FireClient(player, "Du har ingen nøkler. Let etter dem på sykehuset!", "bad")
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
	local word = count == 1 and "nøkkel" or "nøkler"
	self:Notify(player.DisplayName .. " satte inn " .. count .. " " .. word .. " (" .. self.keysInserted .. "/" .. Config.KeysToEscape .. ")", "good")
	if self.keysInserted >= Config.KeysToEscape then
		self:_openExit()
	end
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
	for _, name in { "DoorL", "DoorR" } do
		local door = exit:FindFirstChild(name) :: BasePart?
		if door then
			local dir = name == "DoorL" and -1 or 1
			TweenService:Create(door, info, { CFrame = door.CFrame * CFrame.new(dir * door.Size.X, 0, 0) }):Play()
		end
	end
	self:Notify("NØDUTGANGEN ER ÅPEN! LØP UT!", "good")
	if self.monster then
		self.monster:Enrage()
	end
end

------------------------------------------------------------------
-- Skap
------------------------------------------------------------------

function Match:Hide(player: Player, closet: Model)
	local st = self.players[player]
	if not st or st.out or st.busy or st.closet or self.state ~= "playing" then
		return
	end
	if self.closetOccupant[closet] then
		return
	end
	local hidePoint = closet:FindFirstChild("HidePoint") :: BasePart?
	local root = Util.getRoot(player)
	if not hidePoint or not root or (root.Position - hidePoint.Position).Magnitude > 12 then
		return
	end
	st.closet = closet
	self.closetOccupant[closet] = player
	local promptPart = closet:FindFirstChild("PromptPart")
	local prompt = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
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
	st.closet = nil
	self.closetOccupant[closet] = nil
	local promptPart = closet:FindFirstChild("PromptPart")
	local prompt = promptPart and promptPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
	player:SetAttribute("Hidden", false)
	local outPoint = closet:FindFirstChild("OutPoint") :: BasePart?
	if stepOut and outPoint then
		Util.placeCharacter(player, outPoint.CFrame, st.busy)
		Util.playSound(outPoint, Config.Sounds.Locker, 0.8, 45)
	end
	if self.monster then
		self.monster:OnPlayerLeftCloset(player)
	end
end

------------------------------------------------------------------
-- Monsteret tar noen
------------------------------------------------------------------

function Match:OnMonsterSpotted(player: Player)
	NotifyRemote:FireClient(player, "HUN HAR FUNNET DEG. LØP!", "bad")
end

function Match:OnCaught(player: Player)
	local st = self.players[player]
	if not st or st.out or st.busy or self.state ~= "playing" then
		return
	end
	st.busy = true
	local root = Util.getRoot(player)
	local dropPos = root and root.Position
	if st.closet then
		local outPoint = st.closet:FindFirstChild("OutPoint") :: BasePart?
		if outPoint then
			dropPos = outPoint.Position
		end
		self:Unhide(player, false)
	end
	if st.keys > 0 and dropPos then
		self:_dropKeys(st.keys, dropPos)
		st.keys = 0
		player:SetAttribute("Keys", 0)
	end
	st.lives -= 1
	player:SetAttribute("Lives", st.lives)
	Util.setAnchored(player, true)
	JumpscareRemote:FireClient(player, st.lives)
	if st.lives > 0 then
		self:Notify(player.DisplayName .. " ble tatt! (" .. st.lives .. " liv igjen)", "bad", player)
	else
		self:Notify(player.DisplayName .. " ble tatt og er ute av spillet.", "bad", player)
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
	if self.monster then
		self.monster:Stop()
	end
	for player, st in self.players do
		if st.closet then
			self:Unhide(player, true)
		end
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
	task.delay(Config.GameOverChoiceTime, function()
		self:_resolveChoices()
	end)
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
	self:Notify(player.DisplayName .. " forlot spillet.", "info")
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
