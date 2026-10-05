-- Små hjelpefunksjoner som brukes av flere servermoduler.

local Debris = game:GetService("Debris")

local Util = {}

function Util.getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

-- Flytter karakteren og setter om den skal stå fast (anchored).
function Util.placeCharacter(player: Player, cframe: CFrame, anchored: boolean?)
	local character = player.Character
	local root = Util.getRoot(player)
	if not character or not root then
		return
	end
	root.Anchored = anchored == true
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cframe)
end

function Util.setAnchored(player: Player, anchored: boolean)
	local root = Util.getRoot(player)
	if root then
		root.Anchored = anchored
	end
end

-- Spiller en lyd én gang i en del (3D) eller i SoundService hvis parent er nil.
function Util.playSound(parent: Instance, soundId: string, volume: number?, maxDistance: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1
	sound.RollOffMaxDistance = maxDistance or 60
	sound.RollOffMinDistance = 6
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 12)
end

function Util.shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Util
