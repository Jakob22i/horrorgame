-- Skjermen: hvor stor HUD-en skal være, og hvor mye plass Roblox-topplinja, hakket (notch) og
-- hjem-streken på mobil tar, så knapper og tekst ikke havner under dem.
--
-- HUD-skalaen er 1 på vanlige PC-skjermer og krymper på små skjermer (telefon ca. 0,62).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Screen = {}

export type Area = {
	view: Vector2, -- hele skjermen
	origin: Vector2, -- AbsolutePosition til øverste venstre hjørne av skjermen
	left: number, -- trygge kanter i piksler
	top: number,
	right: number,
	bottom: number,
	width: number, -- størrelsen på det trygge området
	height: number,
	scale: number, -- HUD-skala
	touch: boolean,
}

local MIN_SCALE = 0.62

local fullFrame: Frame? = nil
local safeFrame: Frame? = nil

-- To usynlige rammer: én over hele skjermen og én i det trygge området (samme regler som
-- Roblox bruker for sine egne knapper). Forskjellen mellom dem er kantene.
local function probe(name: string, insets: Enum.ScreenInsets): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = insets
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	return frame
end

-- Mobil/nettbrett: berøringsskjerm uten tastatur
function Screen.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Screen.area(): Area
	if not fullFrame then
		fullFrame = probe("ScreenProbeFull", Enum.ScreenInsets.None)
		safeFrame = probe("ScreenProbeSafe", Enum.ScreenInsets.CoreUISafeInsets)
	end
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local origin = Vector2.new(0, -GuiService:GetGuiInset().Y)
	local left, top, right, bottom = 0, GuiService:GetGuiInset().Y, 0, 0
	local full, safe = fullFrame :: Frame, safeFrame :: Frame
	if full.AbsoluteSize.X > 0 and safe.AbsoluteSize.X > 0 then
		local fp, fs = full.AbsolutePosition, full.AbsoluteSize
		local sp, ss = safe.AbsolutePosition, safe.AbsoluteSize
		view = fs
		origin = fp
		left = math.max(0, sp.X - fp.X)
		top = math.max(0, sp.Y - fp.Y)
		right = math.max(0, (fp.X + fs.X) - (sp.X + ss.X))
		bottom = math.max(0, (fp.Y + fs.Y) - (sp.Y + ss.Y))
	end
	return {
		view = view,
		origin = origin,
		left = left,
		top = top,
		right = right,
		bottom = bottom,
		width = math.max(1, view.X - left - right),
		height = math.max(1, view.Y - top - bottom),
		scale = math.clamp(math.min(view.X / 1280, view.Y / 720), MIN_SCALE, 1),
		touch = Screen.isTouch(),
	}
end

-- Roblox sin hoppeknapp på mobil (nil hvis den ikke vises)
function Screen.jumpButton(): GuiObject?
	local playerGui = player:FindFirstChild("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	if not (touchGui and touchGui:IsA("ScreenGui") and touchGui.Enabled) then
		return nil
	end
	local frame = touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end

return Screen
