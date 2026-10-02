-- Sjekker at alle skap vender inn i rommet (utgangspunktet må være gulv, ikke vegg).
local roblox = require("@lune/roblox")
local buildHospital = require("./hospital")

local folder = roblox.Instance.new("Folder")
local map, preview = buildHospital(folder)
local lines = string.split(preview, "\n")
local function cellAt(pos: any)
	local x, y = math.floor(pos.X / 4), math.floor(pos.Z / 4)
	local row = lines[y + 1]
	return row and string.sub(row, x + 1, x + 1) or "?", x, y
end
local bad = 0
for _, closet in map.Closets:GetChildren() do
	local out = closet:FindFirstChild("OutPoint")
	local hide = closet:FindFirstChild("HidePoint")
	local c, x, y = cellAt(out.CFrame.Position)
	local ch = cellAt(hide.CFrame.Position)
	local ok = (c == "." or c == "o") and (ch == "." or ch == "o")
	if not ok then
		bad += 1
	end
	print(string.format("closet hide=%s out=%s (%d,%d) %s", ch, c, x, y, ok and "OK" or "BAD"))
end
for _, sp in map.SpawnPoints:GetChildren() do
	print("spawn look", sp.CFrame.LookVector)
end
print(bad == 0 and "ALL CLOSETS OK" or (bad .. " BAD CLOSETS"))
