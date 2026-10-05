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
local CosmeticsRemote = Remotes:WaitForChild("Cosmetics") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local S = Config.Shop

type Data = {
	revive: number,
	jumpscare: number,
	coins: number,
	owned: { [string]: boolean },
	flash: string,
	title: string,
	escapes: number,
	best: number, -- raskeste flukt i sekunder (0 = ingen ennå)
}

-- Finn en kosmetikk-ting i katalogen ("Flashlights" eller "Titles")
local function findItem(id: string): (any, string?)
	for _, kind in { "Flashlights", "Titles" } do
		for _, item in (Config.Cosmetics :: any)[kind] do
			if item.id == id then
				return item, kind
			end
		end
	end
	return nil, nil
end

local Shop = {}

local manager: any
local store: DataStore? = nil
local data: { [Player]: Data } = {}
local processed: { [string]: boolean } = {}

local function key(player: Player): string
	return "u" .. player.UserId
end

local function applyTitle(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("TitleTag")
	if old then
		old:Destroy()
	end
	local d = data[player]
	local item = d and findItem(d.title)
	if not item or item.text == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleTag"
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.SpecialElite
	label.Text = item.text
	label.TextColor3 = item.color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = head
end

local function sync(player: Player)
	local d = data[player]
	if d then
		player:SetAttribute("ReviveCredits", d.revive)
		player:SetAttribute("JumpscareCredits", d.jumpscare)
		player:SetAttribute("Coins", d.coins)
		local owned = {}
		for id in d.owned do
			table.insert(owned, id)
		end
		player:SetAttribute("Owned", table.concat(owned, ","))
		player:SetAttribute("FlashId", d.flash)
		local flash = findItem(d.flash)
		player:SetAttribute("FlashColor", flash and flash.color or Color3.fromRGB(255, 244, 220))
		player:SetAttribute("TitleId", d.title)
	end
end

local function save(player: Player): boolean
	local d = data[player]
	if not d or not store then
		return true
	end
	local owned = {}
	for id in d.owned do
		table.insert(owned, id)
	end
	local ok = pcall(function()
		(store :: DataStore):SetAsync(key(player), {
			revive = d.revive,
			jumpscare = d.jumpscare,
			coins = d.coins,
			owned = owned,
			flash = d.flash,
			title = d.title,
			escapes = d.escapes,
			best = d.best,
		})
	end)
	return ok
end

local function load(player: Player)
	local d: Data = { revive = 0, jumpscare = 0, coins = 0, owned = { warm = true, none = true }, flash = "warm", title = "none", escapes = 0, best = 0 }
	if store then
		local ok, value = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok and type(value) == "table" then
			d.revive = tonumber(value.revive) or 0
			d.jumpscare = tonumber(value.jumpscare) or 0
			d.coins = math.max(0, math.floor(tonumber(value.coins) or 0))
			d.escapes = math.max(0, math.floor(tonumber(value.escapes) or 0))
			d.best = math.max(0, math.floor(tonumber(value.best) or 0))
			if type(value.owned) == "table" then
				for _, id in value.owned do
					if type(id) == "string" and findItem(id) then
						d.owned[id] = true
					end
				end
			end
			if type(value.flash) == "string" and d.owned[value.flash] then
				d.flash = value.flash
			end
			if type(value.title) == "string" and d.owned[value.title] then
				d.title = value.title
			end
		end
	end
	data[player] = d
	sync(player)
	applyTitle(player)
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

-- Mynter for å spille (kalles fra rundene). Lagres når runden er over og når du går.
function Shop.addCoins(player: Player, amount: number)
	local d = data[player]
	if d and amount > 0 then
		d.coins += math.floor(amount)
		sync(player)
	end
end

-- En vellykket flukt (til topplista). Returnerer antall flukter og beste tid.
function Shop.recordEscape(player: Player, seconds: number): (number, number)
	local d = data[player]
	if not d then
		return 0, 0
	end
	d.escapes += 1
	local s = math.max(1, math.floor(seconds + 0.5))
	if d.best == 0 or s < d.best then
		d.best = s
	end
	return d.escapes, d.best
end

function Shop.getStats(player: Player): (number, number)
	local d = data[player]
	if not d then
		return 0, 0
	end
	return d.escapes, d.best
end

function Shop.save(player: Player)
	task.spawn(save, player)
end

local function onCosmetic(player: Player, action: any, id: any)
	local d = data[player]
	if not d or typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local item, kind = findItem(id)
	if not item then
		return
	end
	if action == "buy" and not d.owned[id] then
		if d.coins < item.price then
			notify(player, string.format("You need %d more coins.", item.price - d.coins), "bad")
			return
		end
		d.coins -= item.price
		d.owned[id] = true
		if not save(player) then
			-- lagringen feilet: gi tilbake myntene
			d.coins += item.price
			d.owned[id] = nil
			sync(player)
			notify(player, "Could not save the purchase. Try again.", "bad")
			return
		end
		notify(player, "Bought " .. item.name .. "!", "good")
		action = "equip"
	end
	if action == "equip" and d.owned[id] then
		if kind == "Flashlights" then
			d.flash = id
		else
			d.title = id
		end
		sync(player)
		applyTitle(player)
		task.spawn(save, player)
	end
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
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			applyTitle(player)
		end)
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
	CosmeticsRemote.OnServerEvent:Connect(onCosmetic)
end

return Shop
