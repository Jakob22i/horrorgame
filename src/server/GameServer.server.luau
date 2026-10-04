-- Hovedscriptet på serveren. Starter lobbyen og holder styr på alle rundene.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Lobby = require(script:WaitForChild("Lobby"))
local Match = require(script:WaitForChild("Match"))
local Shop = require(script:WaitForChild("Shop"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStateRemote = Remotes:WaitForChild("MatchState") :: RemoteEvent
local TransitionRemote = Remotes:WaitForChild("Transition") :: RemoteEvent
local ToggleFlashlightRemote = Remotes:WaitForChild("ToggleFlashlight") :: RemoteEvent
local LeaveClosetRemote = Remotes:WaitForChild("LeaveCloset") :: RemoteEvent
local GameOverChoiceRemote = Remotes:WaitForChild("GameOverChoice") :: RemoteEvent
local PushRemote = Remotes:WaitForChild("Push") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local matches: { [number]: any } = {}
local playerMatch: { [Player]: any } = {}
local usedSlots: { [number]: boolean } = {}
local nextId = 0

local Manager = {}

local function resetAttributes(player: Player)
	player:SetAttribute("InMatch", false)
	player:SetAttribute("MatchId", 0)
	player:SetAttribute("Lives", 0)
	player:SetAttribute("Keys", 0)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("Out", false)
	player:SetAttribute("Flashlight", false)
	player:SetAttribute("Downed", false)
end

function Manager:StartMatch(group: { Player }, mode: string?)
	local players = {}
	for _, player in group do
		if player.Parent == Players and not playerMatch[player] then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	nextId += 1
	local match = Match.new(Manager, nextId, slot, players, mode)
	matches[match.id] = match
	for _, player in players do
		playerMatch[player] = match
	end
	match:Start()
end

function Manager:SendToLobby(player: Player)
	playerMatch[player] = nil
	resetAttributes(player)
	if player.Parent == Players then
		MatchStateRemote:FireClient(player, "lobby")
		player:LoadCharacter()
	end
end

-- Mynter (dobbelt i Nightmare). reason vises i beskjeden.
function Manager:AwardCoins(player: Player, amount: number, reason: string)
	local match = playerMatch[player]
	if match and match.nightmare then
		amount *= Config.Nightmare.CoinMultiplier
	end
	if amount <= 0 or player.Parent ~= Players then
		return
	end
	Shop.addCoins(player, amount)
	NotifyRemote:FireClient(player, string.format("+%d coins (%s)", amount, reason), "good")
end

function Manager:OnHelped(helper: Player)
	Manager:AwardCoins(helper, Config.Coins.HelpUp, "helped a friend")
end

-- Avslutter en runde. Spillere i `retry` starter en ny runde sammen, resten går til lobbyen.
function Manager:EndMatch(match: any, retry: { Player })
	if match.state == "ended" then
		return
	end
	-- litt mynter for å ha spilt (ikke for runder som var over med en gang)
	local played = os.clock() - (match.startedAt or os.clock()) >= 90
	for player in match.players do
		if played then
			Manager:AwardCoins(player, Config.Coins.Round, "round played")
		end
		Shop.save(player)
	end
	local retrySet = {}
	for _, p in retry do
		retrySet[p] = true
	end
	local everyone = {}
	for player in match.players do
		table.insert(everyone, player)
		-- Frys karakteren så den ikke faller når kartet fjernes
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = true
		end
	end
	match:Destroy()
	matches[match.id] = nil
	usedSlots[match.slot] = nil

	local again = {}
	for _, player in everyone do
		playerMatch[player] = nil
		if retrySet[player] and player.Parent == Players then
			table.insert(again, player)
			TransitionRemote:FireClient(player, "Rewinding the tape...")
		else
			Manager:SendToLobby(player)
		end
	end
	if #again > 0 then
		local mode = match.mode
		task.delay(2, function()
			Manager:StartMatch(again, mode)
		end)
	end
end

local function onPlayerAdded(player: Player)
	resetAttributes(player)
	player.CharacterAdded:Connect(function()
		local match = playerMatch[player]
		if match then
			match:OnCharacterAdded(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	local match = playerMatch[player]
	playerMatch[player] = nil
	if match then
		match:RemovePlayer(player)
	end
end)

ToggleFlashlightRemote.OnServerEvent:Connect(function(player)
	local match = playerMatch[player]
	if match and player:GetAttribute("Out") ~= true then
		player:SetAttribute("Flashlight", not player:GetAttribute("Flashlight"))
	end
end)

LeaveClosetRemote.OnServerEvent:Connect(function(player)
	local match = playerMatch[player]
	if match then
		match:Unhide(player, true)
	end
end)

-- Brukes av Shop
function Manager:CanRevive(player: Player): boolean
	local match = playerMatch[player]
	return match ~= nil and match:CanRevive(player)
end

function Manager:Revive(player: Player): boolean
	local match = playerMatch[player]
	return match ~= nil and match:Revive(player)
end

function Manager:CanJumpscare(player: Player): boolean
	local match = playerMatch[player]
	return match ~= nil and match.state == "playing" and match:CountPrankTargets(player) > 0
end

function Manager:JumpscareAll(player: Player)
	local match = playerMatch[player]
	if match then
		match:JumpscareAll(player)
	end
end

PushRemote.OnServerEvent:Connect(function(player)
	local match = playerMatch[player]
	if match then
		match:Push(player)
	end
end)

GameOverChoiceRemote.OnServerEvent:Connect(function(player, choice)
	local match = playerMatch[player]
	if match and typeof(choice) == "string" then
		match:OnChoice(player, choice)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, match in matches do
		match:Step(dt)
	end
end)

Shop.init(Manager)

Lobby.init(function(group, mode)
	Manager:StartMatch(group, mode)
end)
