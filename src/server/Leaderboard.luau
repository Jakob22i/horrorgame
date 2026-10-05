-- Topplista i lobbyen ("HALL OF SURVIVORS"): raskeste flukt og flest flukter.
-- Lagres i OrderedDataStores så den gjelder alle servere. Uten DataStore (f.eks. Studio
-- uten API-tilgang) viser den bare spillerne på denne serveren.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboard = {}

local ROWS = 10
local REFRESH = 60

type Entry = { userId: number, value: number }

local fastestStore: OrderedDataStore? = nil
local escapesStore: OrderedDataStore? = nil
local gui: SurfaceGui? = nil
local statsOf: (Player) -> (number, number) = function()
	return 0, 0
end

-- Resultater fra denne serveren (så de vises med en gang, før DataStore har oppdatert seg)
local localFast: { [number]: number } = {}
local localMost: { [number]: number } = {}
local names: { [number]: string } = {}
local refreshing = false
local lastFast: { Entry }? = nil
local lastMost: { Entry }? = nil

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else ("Player " .. userId)
	names[userId] = result
	return result
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function fetch(store: OrderedDataStore?, ascending: boolean): { Entry }?
	if not store then
		return nil
	end
	local ok, result = pcall(function()
		local pages = (store :: OrderedDataStore):GetSortedAsync(ascending, ROWS, if ascending then 1 else nil)
		local list: { Entry } = {}
		for _, item in pages:GetCurrentPage() do
			local id = tonumber(item.key)
			if id then
				table.insert(list, { userId = id, value = item.value })
			end
		end
		return list
	end)
	return if ok then result else nil
end

-- Slår sammen lista fra DataStore med resultatene på denne serveren
local function merge(remote: { Entry }?, extra: { [number]: number }, better: (number, number) -> boolean): { Entry }
	local best: { [number]: number } = {}
	if remote then
		for _, e in remote do
			best[e.userId] = e.value
		end
	end
	for id, value in extra do
		local old = best[id]
		if not old or better(value, old) then
			best[id] = value
		end
	end
	local list: { Entry } = {}
	for id, value in best do
		table.insert(list, { userId = id, value = value })
	end
	table.sort(list, function(a, b)
		if a.value == b.value then
			return a.userId < b.userId
		end
		return better(a.value, b.value)
	end)
	return list
end

local function setRow(prefix: string, i: number, name: string, value: string)
	local g = gui
	if not g then
		return
	end
	local nameLabel = g:FindFirstChild(prefix .. "Name" .. i) :: TextLabel?
	local valueLabel = g:FindFirstChild(prefix .. "Value" .. i) :: TextLabel?
	if nameLabel then
		nameLabel.Text = name
	end
	if valueLabel then
		valueLabel.Text = value
	end
end

local function render()
	local fast = merge(lastFast, localFast, function(a, b)
		return a < b
	end)
	local most = merge(lastMost, localMost, function(a, b)
		return a > b
	end)
	for i = 1, ROWS do
		local f = fast[i]
		if f then
			setRow("Fast", i, string.sub(nameOf(f.userId), 1, 18), formatTime(f.value))
		else
			setRow("Fast", i, "—", "")
		end
		local m = most[i]
		if m then
			setRow("Most", i, string.sub(nameOf(m.userId), 1, 18), tostring(m.value))
		else
			setRow("Most", i, "—", "")
		end
	end
end

local function refresh()
	if refreshing then
		return
	end
	refreshing = true
	-- spillerne som er her nå teller alltid med (også i Studio uten DataStore)
	for _, player in Players:GetPlayers() do
		local escapes, best = statsOf(player)
		if escapes > 0 then
			localMost[player.UserId] = math.max(localMost[player.UserId] or 0, escapes)
		end
		if best > 0 then
			localFast[player.UserId] = math.min(localFast[player.UserId] or math.huge, best)
		end
	end
	local fast = fetch(fastestStore, true)
	if fast then
		lastFast = fast
	end
	local most = fetch(escapesStore, false)
	if most then
		lastMost = most
	end
	render()
	refreshing = false
end

-- Kalles når noen kommer seg ut
function Leaderboard.submit(player: Player, escapes: number, best: number)
	local id = player.UserId
	if escapes > 0 then
		localMost[id] = math.max(localMost[id] or 0, escapes)
	end
	if best > 0 then
		localFast[id] = math.min(localFast[id] or math.huge, best)
	end
	task.spawn(render)
	if id <= 0 then
		return -- testspillere i Studio har negative ID-er
	end
	task.spawn(function()
		if escapesStore then
			pcall(function()
				(escapesStore :: OrderedDataStore):SetAsync(tostring(id), escapes)
			end)
		end
		if fastestStore and best > 0 then
			pcall(function()
				(fastestStore :: OrderedDataStore):UpdateAsync(tostring(id), function(old)
					if type(old) == "number" and old > 0 and old <= best then
						return nil
					end
					return best
				end)
			end)
		end
	end)
end

function Leaderboard.init(getStats: ((Player) -> (number, number))?)
	if getStats then
		statsOf = getStats
	end
	local ok1, fastest = pcall(function()
		return DataStoreService:GetOrderedDataStore("HorrorFastest_v1")
	end)
	if ok1 then
		fastestStore = fastest
	end
	local ok2, escapes = pcall(function()
		return DataStoreService:GetOrderedDataStore("HorrorEscapes_v1")
	end)
	if ok2 then
		escapesStore = escapes
	end
	local lobby = workspace:WaitForChild("Lobby")
	local board = lobby:FindFirstChild("Leaderboard", true)
	local part = board and board:FindFirstChild("Board")
	gui = part and part:FindFirstChild("BoardGui") :: SurfaceGui?
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
	Players.PlayerAdded:Connect(function()
		-- dataene lastes litt etter at spilleren kommer inn
		task.delay(8, refresh)
	end)
end

return Leaderboard
