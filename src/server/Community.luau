-- Communityet: plakaten ved spawn i lobbyen. Bli med i Roblox-gruppa og få mynter, én gang per
-- spiller. Klienten åpner Roblox sin egen "Join"-boks (CommunityUI); serveren sjekker selv at
-- spilleren faktisk er med i gruppa før myntene gis og lagres (Shop).
--
-- Klienten sender "check" (er jeg med?) eller "claim" (gi meg myntene), og får svar på samme
-- remote: "member", "notMember", "claimed" eller "error".

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CommunityRemote = Remotes:WaitForChild("Community") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local Community = {}

local shop: any
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}

-- true/false, eller nil hvis vi ikke fikk svar fra Roblox
local function isMember(player: Player): boolean?
	local groupId = Config.Community.GroupId
	local ok, member = pcall(function()
		return player:IsInGroupAsync(groupId)
	end)
	if ok and member then
		return true
	end
	-- svaret over kan være husket fra før du ble med, så spør Roblox på nytt
	local listOk, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if listOk and type(groups) == "table" then
		for _, group in groups do
			if type(group) == "table" and group.Id == groupId then
				return true
			end
		end
		return false
	end
	return if ok then false else nil
end

local function handle(player: Player, action: string): string
	if not shop.isLoaded(player) then
		return "error"
	end
	if shop.hasCommunityReward(player) then
		return "claimed"
	end
	local member = isMember(player)
	if action == "claim" then
		-- rett etter at du har blitt med kan det ta litt tid før Roblox vet det
		local tries = 1
		while member == false and tries < 4 and player.Parent == Players do
			task.wait(1.5)
			member = isMember(player)
			tries += 1
		end
	end
	if member == nil then
		return "error"
	elseif not member then
		return "notMember"
	elseif action == "check" then
		return "member"
	end
	local reward = Config.Community.Reward
	if shop.grantCommunityReward(player, reward) then
		NotifyRemote:FireClient(player, string.format("+%d coins! Thanks for joining the community.", reward), "good")
		return "claimed"
	end
	return "error"
end

local function onRequest(player: Player, action: any)
	if action ~= "check" and action ~= "claim" then
		return
	end
	local now = os.clock()
	if busy[player] or now - (lastRequest[player] or 0) < 0.5 then
		return
	end
	lastRequest[player] = now
	busy[player] = true
	local ok, status = pcall(handle, player, action)
	busy[player] = nil
	if player.Parent == Players then
		CommunityRemote:FireClient(player, action, if ok then status else "error")
	end
end

function Community.init(shopModule: any)
	shop = shopModule
	CommunityRemote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastRequest[player] = nil
	end)
end

return Community
