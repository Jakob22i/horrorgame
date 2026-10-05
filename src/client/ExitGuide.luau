-- Viser hvor nødutgangen er: en grønn markør (synlig gjennom vegger) med avstand.
-- Den dukker opp i noen sekunder hver gang du finner en nøkkel, og står fast når døra er åpen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Screen = require(script.Parent:WaitForChild("Screen"))

local player = Players.LocalPlayer

local ExitGuide = {}

local SHOW_TIME = 12 -- sekunder etter hver nøkkel
local GREEN = Color3.fromRGB(90, 255, 130)

local Effects: any
local isBlocked: () -> boolean = function()
	return false
end
local marker: BillboardGui
local title: TextLabel
local distance: TextLabel
local arrow: TextLabel
local showUntil = 0
local revealStart = 0
local lastKeys = 0

-- Et usynlig, lokalt punkt over døra som markøren henger på (døra selv er kanskje ikke
-- lastet inn hos deg når du er langt unna, på grunn av streaming)
local anchor: Part? = nil
local function exitPart(): BasePart?
	local folder = Effects.currentMatchFolder()
	local pos = folder and folder:GetAttribute("ExitPos")
	if typeof(pos) ~= "Vector3" then
		return nil
	end
	local part = anchor
	if not part or not part.Parent then
		local p = Instance.new("Part")
		p.Name = "ExitMarkerAnchor"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Parent = workspace
		anchor = p
		part = p
	end
	local target = pos + Vector3.new(0, 13, 0)
	if (part :: Part).Position ~= target then
		(part :: Part).CFrame = CFrame.new(target)
	end
	return part
end

local function exitOpen(): boolean
	local folder = Effects.currentMatchFolder()
	return folder ~= nil and folder:GetAttribute("ExitOpen") == true
end

-- Vis markøren en stund (kalles når du finner en nøkkel)
function ExitGuide.reveal(seconds: number?)
	if os.clock() >= showUntil then
		revealStart = os.clock()
	end
	showUntil = math.max(showUntil, os.clock() + (seconds or SHOW_TIME))
end

function ExitGuide.init(effects: any, blocked: (() -> boolean)?)
	Effects = effects
	if blocked then
		isBlocked = blocked
	end

	marker = Instance.new("BillboardGui")
	marker.Name = "ExitMarker"
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Size = UDim2.fromOffset(220, 92)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	marker.ResetOnSpawn = false
	marker.Enabled = false
	marker.Parent = player:WaitForChild("PlayerGui")

	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 30 / 92)
	title.Font = Enum.Font.SpecialElite
	title.TextScaled = true
	title.TextColor3 = GREEN
	title.TextStrokeTransparency = 0.3
	title.Text = "EMERGENCY EXIT"
	title.Parent = marker

	distance = Instance.new("TextLabel")
	distance.BackgroundTransparency = 1
	distance.Position = UDim2.fromScale(0, 30 / 92)
	distance.Size = UDim2.fromScale(1, 22 / 92)
	distance.Font = Enum.Font.RobotoMono
	distance.TextScaled = true
	distance.TextColor3 = Color3.fromRGB(220, 255, 225)
	distance.TextStrokeTransparency = 0.4
	distance.Text = ""
	distance.Parent = marker

	arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.fromScale(0, 52 / 92)
	arrow.Size = UDim2.fromScale(1, 40 / 92)
	arrow.Font = Enum.Font.GothamBold
	arrow.TextScaled = true
	arrow.TextColor3 = GREEN
	arrow.TextStrokeTransparency = 0.3
	arrow.Text = "▼"
	arrow.Parent = marker

	-- ny nøkkel = vis veien til utgangen
	player:GetAttributeChangedSignal("Keys"):Connect(function()
		local keys = player:GetAttribute("Keys") or 0
		if keys > lastKeys and player:GetAttribute("InMatch") == true then
			ExitGuide.reveal()
		end
		lastKeys = keys
	end)
	player:GetAttributeChangedSignal("InMatch"):Connect(function()
		showUntil = 0
		lastKeys = player:GetAttribute("Keys") or 0
	end)

	RunService.RenderStepped:Connect(function()
		local inMatch = player:GetAttribute("InMatch") == true
		local open = inMatch and exitOpen()
		local part = if inMatch then exitPart() else nil
		local visible = part ~= nil and (open or os.clock() < showUntil) and not isBlocked()
		marker.Enabled = visible
		if not visible or not part then
			return
		end
		marker.Adornee = part
		-- mindre på små skjermer (mobil)
		local s = Screen.area().scale
		marker.Size = UDim2.fromOffset(220 * s, 92 * s)
		local camera = workspace.CurrentCamera
		local dist = (camera.CFrame.Position - part.Position).Magnitude
		distance.Text = string.format("%d m", math.floor(dist * 0.28 + 0.5)) -- ca. 0,28 m per stud
		title.Text = if open then "EXIT — RUN!" else "EMERGENCY EXIT"
		-- pulser litt så den er lett å få øye på
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
		arrow.Position = UDim2.fromScale(0, (52 + pulse * 6) / 92)
		-- tones inn det første halve sekundet og ut de siste 1,5 sekundene
		local fade = 0
		if not open then
			local now = os.clock()
			local left = showUntil - now
			local fadeIn = math.clamp((now - revealStart) / 0.5, 0, 1)
			local fadeOut = if left < 1.5 then 1 - left / 1.5 else 0
			fade = math.max(1 - fadeIn, fadeOut)
		end
		title.TextTransparency = fade
		distance.TextTransparency = fade
		arrow.TextTransparency = fade
	end)
end

return ExitGuide
