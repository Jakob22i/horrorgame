-- Kjøp med Robux: Revive (developer product), Push (game pass) og
-- "Jumpscare everyone" (developer product).
--
-- Kjøpte revives/jumpscares lagres som "credits" (i DataStore når det er tilgjengelig),
-- så et kjøp aldri går tapt selv om runden er over før kjøpet er ferdig.
-- Står en produkt-ID på 0 i Config, er kjøpet gratis i Studio slik at du kan teste.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopRemote = Remotes:WaitForChild("Shop") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local S = Config.Shop

type Data = { revive: number, jumpscare: number }

local Shop = {}

local manager: any
local store: DataStore? = nil
local data: { [Player]: Data } = {}
local processed: { [string]: boolean } = {}

local function key(player: Player): string
	return "u" .. player.UserId
end

local function sync(player: Player)
	local d = data[player]
	if d then
		player:SetAttribute("ReviveCredits", d.revive)
		player:SetAttribute("JumpscareCredits", d.jumpscare)
	end
end

local function save(player: Player): boolean
	local d = data[player]
	if not d or not store then
		return true
	end
	local ok = pcall(function()
		(store :: DataStore):SetAsync(key(player), { revive = d.revive, jumpscare = d.jumpscare })
	end)
	return ok
end

local function load(player: Player)
	local d: Data = { revive = 0, jumpscare = 0 }
	if store then
		local ok, value = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok and type(value) == "table" then
			d.revive = tonumber(value.revive) or 0
			d.jumpscare = tonumber(value.jumpscare) or 0
		end
	end
	data[player] = d
	sync(player)
end

local function checkPushPass(player: Player)
	if player:GetAttribute("HasPush") == true or S.PushGamePassId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, S.PushGamePassId)
	end)
	if ok and owns then
		player:SetAttribute("HasPush", true)
	end
end

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

-- Bruker en kjøpt revive hvis spilleren kan gjenopplives akkurat nå
local function useRevive(player: Player): boolean
	local d = data[player]
	if d and d.revive > 0 and manager:CanRevive(player) then
		d.revive -= 1
		sync(player)
		save(player)
		return manager:Revive(player)
	end
	return false
end

local function useJumpscare(player: Player): boolean
	local d = data[player]
	if d and d.jumpscare > 0 and manager:CanJumpscare(player) then
		d.jumpscare -= 1
		sync(player)
		save(player)
		manager:JumpscareAll(player)
		return true
	end
	return false
end

local function onRequest(player: Player, item: any)
	if typeof(item) ~= "string" then
		return
	end
	local testFree = RunService:IsStudio()
	if item == "revive" then
		if not manager:CanRevive(player) or useRevive(player) then
			return
		end
		if S.ReviveProductId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, S.ReviveProductId)
		elseif testFree then
			manager:Revive(player)
			notify(player, "Studio test: free revive (set ReviveProductId in Config).")
		else
			notify(player, "Revive is not available yet.", "bad")
		end
	elseif item == "jumpscare" then
		if not manager:CanJumpscare(player) then
			notify(player, "There is nobody else to scare right now.")
			return
		end
		if useJumpscare(player) then
			return
		end
		if S.JumpscareProductId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, S.JumpscareProductId)
		elseif testFree then
			manager:JumpscareAll(player)
			notify(player, "Studio test: free jumpscare (set JumpscareProductId in Config).")
		else
			notify(player, "Jumpscare everyone is not available yet.", "bad")
		end
	elseif item == "push" then
		if player:GetAttribute("HasPush") == true then
			return
		end
		if S.PushGamePassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, S.PushGamePassId)
		elseif testFree then
			player:SetAttribute("HasPush", true)
			notify(player, "Studio test: Push unlocked (set PushGamePassId in Config).", "good")
		else
			notify(player, "Push is not available yet.", "bad")
		end
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not data[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if processed[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local d = data[player]
	local field: string? = nil
	if S.ReviveProductId ~= 0 and info.ProductId == S.ReviveProductId then
		field = "revive"
	elseif S.JumpscareProductId ~= 0 and info.ProductId == S.JumpscareProductId then
		field = "jumpscare"
	end
	if not field then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	(d :: any)[field] += 1
	if not save(player) then
		(d :: any)[field] -= 1
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	processed[info.PurchaseId] = true
	sync(player)
	task.defer(function()
		if field == "revive" then
			if not useRevive(player) then
				notify(player, "Revive saved! It is free the next time you die.", "good")
			end
		else
			if not useJumpscare(player) then
				notify(player, "Jumpscare saved! Press 3 in a round to use it.", "good")
			end
		end
	end)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.init(mgr: any)
	manager = mgr
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("HorrorShop_v1")
	end)
	if ok then
		store = result
	end

	local function onPlayer(player: Player)
		player:SetAttribute("HasPush", false)
		task.spawn(load, player)
		task.spawn(checkPushPass, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		data[player] = nil
	end)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == S.PushGamePassId then
			player:SetAttribute("HasPush", true)
			notify(player, "Push unlocked! Press 2 to push.", "good")
		end
	end)
	ShopRemote.OnServerEvent:Connect(onRequest)
end

return Shop
