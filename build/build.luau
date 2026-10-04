-- Bygger spillfila: tar place/base.rbxl, legger til lobby, sykehus, monster,
-- nøkler og alle script fra src/, og lagrer resultatet som horrorgame.rbxl.
--
-- Kjør fra rotmappen:  lune run build/build.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local lib = require("./lib")
local buildLobby = require("./lobby")
local buildHospital = require("./hospital")
local buildPatient = require("./patient")
local buildKey = require("./key")

local Vector3, CFrame, Enum = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb

local INPUT = "place/base.rbxl"
local OUTPUT = "horrorgame.rbxl"

local game = roblox.deserializePlace(fs.readFile(INPUT))
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Fjern ting fra en tidligere bygging (så skriptet kan kjøres flere ganger på samme fil)
for _, item in {
	{ Workspace, "Lobby" },
	{ Workspace, "Matches" },
	{ ServerStorage, "HospitalTemplate" },
	{ ServerStorage, "Monster" },
	{ ServerStorage, "Key" },
	{ ReplicatedStorage, "Assets" },
	{ ReplicatedStorage, "Remotes" },
	{ ReplicatedStorage, "Shared" },
	{ ServerScriptService, "GameServer" },
} do
	local existing = item[1]:FindFirstChild(item[2])
	if existing then
		existing.Parent = nil
	end
end

------------------------------------------------------------------
-- Verden og innstillinger
------------------------------------------------------------------
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate.Parent = nil
end
Workspace.StreamingEnabled = false

Lighting.Technology = Enum.Technology.Future
Lighting.TimeOfDay = "00:00:00"
Lighting.Brightness = 0.6
Lighting.Ambient = rgb(46, 42, 34)
Lighting.OutdoorAmbient = rgb(34, 32, 30)
Lighting.EnvironmentDiffuseScale = 0.2
Lighting.EnvironmentSpecularScale = 0.3
Lighting.GlobalShadows = true
for _, name in { "SunRays", "DepthOfField" } do
	local effect = Lighting:FindFirstChild(name)
	if effect then
		effect.Parent = nil
	end
end
local bloom = Lighting:FindFirstChild("Bloom")
if bloom then
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.4
end
local atmosphere = Lighting:FindFirstChild("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.3
	atmosphere.Offset = 0
	atmosphere.Color = rgb(32, 30, 28)
	atmosphere.Decay = rgb(18, 16, 14)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6
end

StarterPlayer.CharacterWalkSpeed = 16
StarterPlayer.CharacterJumpHeight = 5
StarterPlayer.CameraMaxZoomDistance = 14
StarterPlayer.EnableMouseLockOption = false
Players.RespawnTime = 3
SoundService.AmbientReverb = Enum.ReverbType.Hallway

------------------------------------------------------------------
-- Lobby, sykehus og monster
------------------------------------------------------------------
buildLobby(Workspace, Workspace:FindFirstChild("SpawnLocation"))
lib.new("Folder", { Name = "Matches" }, Workspace)

local _, preview, stats = buildHospital(ServerStorage)
print(preview)
print(string.format("Sykehus: %d veggblokker, %d patruljepunkter", stats.walls, stats.patrol))

local monster = buildPatient(ServerStorage, "Monster")

local assets = lib.new("Folder", { Name = "Assets" }, ReplicatedStorage)
local jumpscareModel = monster:Clone()
jumpscareModel.Name = "MonsterJumpscare"
for _, d in jumpscareModel:GetDescendants() do
	if d.ClassName == "PointLight" then
		d.Parent = nil
	end
end
jumpscareModel.Parent = assets

------------------------------------------------------------------
-- Nøkkel
------------------------------------------------------------------
buildKey(ServerStorage)

------------------------------------------------------------------
-- RemoteEvents
------------------------------------------------------------------
local remotes = lib.new("Folder", { Name = "Remotes" }, ReplicatedStorage)
for _, name in { "Notify", "Jumpscare", "MatchState", "Transition", "ToggleFlashlight", "LeaveCloset", "GameOverChoice", "Shop", "Push", "Pushed", "Prank", "Cosmetics" } do
	lib.new("RemoteEvent", { Name = name }, remotes)
end

------------------------------------------------------------------
-- Script fra src/
------------------------------------------------------------------
local sourcemap = { name = "Game", className = "DataModel", children = {} }
local function smService(name: string, className: string)
	local node = { name = name, className = className, children = {} }
	table.insert(sourcemap.children, node)
	return node
end
local function smChild(parentNode: any, name: string, className: string, path: string?)
	local node = { name = name, className = className, children = {}, filePaths = path and { path } or nil }
	table.insert(parentNode.children, node)
	return node
end

local function script(className: string, name: string, path: string, parent: any, smParent: any)
	local s = lib.new(className, { Name = name, Source = fs.readFile(path) }, parent)
	return s, smChild(smParent, name, className, path)
end

-- Delt konfig
local smRS = smService("ReplicatedStorage", "ReplicatedStorage")
local shared = lib.new("Folder", { Name = "Shared" }, ReplicatedStorage)
local smShared = smChild(smRS, "Shared", "Folder")
script("ModuleScript", "Config", "src/shared/Config.luau", shared, smShared)
local smRemotes = smChild(smRS, "Remotes", "Folder")
for _, r in remotes:GetChildren() do
	smChild(smRemotes, r.Name, "RemoteEvent")
end
local smAssets = smChild(smRS, "Assets", "Folder")
smChild(smAssets, "MonsterJumpscare", "Model")

-- Server
local smSSS = smService("ServerScriptService", "ServerScriptService")
local server, smServer = script("Script", "GameServer", "src/server/GameServer.server.luau", ServerScriptService, smSSS)
for _, name in { "Util", "Monster", "Match", "Lobby", "Shop" } do
	script("ModuleScript", name, "src/server/" .. name .. ".luau", server, smServer)
end

-- Klient
local smSP = smService("StarterPlayer", "StarterPlayer")
local smSPS = smChild(smSP, "StarterPlayerScripts", "StarterPlayerScripts")
local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local oldClient = sps:FindFirstChild("ClientMain")
if oldClient then
	oldClient.Parent = nil
end
local client, smClient = script("LocalScript", "ClientMain", "src/client/ClientMain.client.luau", sps, smSPS)
for _, name in { "UI", "Effects", "Controls", "Jumpscare", "MonsterAnimator", "Ending", "Scares", "CosmeticsUI" } do
	script("ModuleScript", name, "src/client/" .. name .. ".luau", client, smClient)
end

-- Loading screen (vises før alt annet)
local smRF = smService("ReplicatedFirst", "ReplicatedFirst")
local oldLoading = ReplicatedFirst:FindFirstChild("LoadingScreen")
if oldLoading then
	oldLoading.Parent = nil
end
script("LocalScript", "LoadingScreen", "src/first/LoadingScreen.client.luau", ReplicatedFirst, smRF)

smService("Workspace", "Workspace")
smService("ServerStorage", "ServerStorage")
smService("Players", "Players")
smService("Lighting", "Lighting")
smService("SoundService", "SoundService")

fs.writeFile("sourcemap.json", serde.encode("json", sourcemap, true))
fs.writeFile(OUTPUT, roblox.serializePlace(game))
print("Lagret " .. OUTPUT)
