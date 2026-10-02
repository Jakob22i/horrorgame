-- Hovedscriptet på klienten. Kobler sammen UI, effekter, styring og jumpscare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local JumpscareRemote = Remotes:WaitForChild("Jumpscare") :: RemoteEvent
local TransitionRemote = Remotes:WaitForChild("Transition") :: RemoteEvent
local MatchStateRemote = Remotes:WaitForChild("MatchState") :: RemoteEvent
local GameOverChoiceRemote = Remotes:WaitForChild("GameOverChoice") :: RemoteEvent

local UI = require(script:WaitForChild("UI"))
local Effects = require(script:WaitForChild("Effects"))
local Controls = require(script:WaitForChild("Controls"))
local Jumpscare = require(script:WaitForChild("Jumpscare"))

local player = Players.LocalPlayer

UI.init()
Effects.init(UI)
Controls.init(UI)
Jumpscare.init(UI, Effects)

-- Ingen "Reset character" i et skrekkspill
task.spawn(function()
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

------------------------------------------------------------------
-- HUD-verdier
------------------------------------------------------------------

local insertedConn: RBXScriptConnection? = nil

local function insertedKeys(): number
	local folder = Effects.currentMatchFolder()
	return folder and folder:GetAttribute("KeysInserted") or 0
end

local function refreshHud()
	UI.setLives(player:GetAttribute("Lives") or 0, Config.Lives)
	UI.setKeys(player:GetAttribute("Keys") or 0, insertedKeys(), Config.KeysToEscape)
end

local function watchMatchFolder()
	if insertedConn then
		insertedConn:Disconnect()
		insertedConn = nil
	end
	task.spawn(function()
		local folder
		for _ = 1, 20 do
			folder = Effects.currentMatchFolder()
			if folder then
				break
			end
			task.wait(0.25)
		end
		if folder then
			insertedConn = folder:GetAttributeChangedSignal("KeysInserted"):Connect(refreshHud)
		end
		refreshHud()
	end)
end

local function refreshMode()
	local inMatch = player:GetAttribute("InMatch") == true
	Effects.setMode(inMatch and "match" or "lobby")
	Controls.setMode(inMatch)
	UI.setMatchHud(inMatch)
	if inMatch then
		watchMatchFolder()
	else
		UI.setSpectate(nil)
	end
	refreshHud()
end

player:GetAttributeChangedSignal("InMatch"):Connect(refreshMode)
player:GetAttributeChangedSignal("MatchId"):Connect(watchMatchFolder)
player:GetAttributeChangedSignal("Lives"):Connect(refreshHud)
player:GetAttributeChangedSignal("Keys"):Connect(refreshHud)
player:GetAttributeChangedSignal("Out"):Connect(Controls.onOutChanged)
refreshMode()

------------------------------------------------------------------
-- Beskjeder fra serveren
------------------------------------------------------------------

NotifyRemote.OnClientEvent:Connect(function(message, kind)
	UI.notify(message, kind)
end)

JumpscareRemote.OnClientEvent:Connect(function(livesLeft)
	Jumpscare.play(livesLeft)
end)

TransitionRemote.OnClientEvent:Connect(function(message)
	UI.hidePanels()
	UI.fadeOut(message, 0.9)
end)

MatchStateRemote.OnClientEvent:Connect(function(state, data)
	if state == "start" then
		UI.hidePanels()
		local players = data and data.players or 1
		task.spawn(UI.intro, {
			"TAPE #" .. tostring(data and data.matchId or 1) .. "  —  ST. AGATHE HOSPITAL",
			"10/02/1997   03:13 AM",
			"",
			"Find 5 keys. Bring them to the emergency exit.",
			"Hide in the lockers. Do not let it see you.",
			"",
			players == 1 and "You are alone." or ("There are " .. players .. " of you."),
		}, 2.2)
	elseif state == "won" then
		UI.showWin(data and data.escaper or "Someone", data and data.seconds or 10)
		if Config.Sounds.Win ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = Config.Sounds.Win
			s.Volume = 0.8
			s.Parent = game:GetService("SoundService")
			s:Play()
			task.delay(10, function()
				s:Destroy()
			end)
		end
	elseif state == "gameover" then
		if Config.Sounds.GameOver ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = Config.Sounds.GameOver
			s.Volume = 0.8
			s.Parent = game:GetService("SoundService")
			s:Play()
			task.delay(12, function()
				s:Destroy()
			end)
		end
		UI.fadeIn(0.5)
		UI.showGameOver(data and data.seconds or 20, function(choice)
			GameOverChoiceRemote:FireServer(choice)
		end)
	elseif state == "lobby" then
		UI.hidePanels()
		UI.fadeOut("", 0.01)
		task.wait(0.6)
		UI.fadeIn(1)
	end
end)
