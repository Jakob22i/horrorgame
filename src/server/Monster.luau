-- Den bleke damen: vandrer rundt i sykehuset, ser og hører spillere,
-- jager dem og tar dem når hun er nær nok.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(script.Parent:WaitForChild("Util"))

local M = Config.Monster
local EYE_HEIGHT = 9.6 -- over Root (Root står 1 stud over gulvet)
local EYE_FORWARD = 2 -- hodet henger et stykke foran kroppen

local Monster = {}
Monster.__index = Monster

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawFromDirection(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

local function lerpAngle(a: number, b: number, t: number): number
	local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + diff * t
end

function Monster.new(match: any, template: Model, parent: Instance)
	local model = template:Clone()
	model.Name = "Monster"
	local root = model:WaitForChild("Root") :: BasePart
	-- Lyder som følger monsteret (3D-lyd). Klienten styrer volumet på "Squeak" etter farten.
	local function loop(name: string, id: string, volume: number, maxDistance: number, speed: number)
		if id == "" then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = volume
		sound.PlaybackSpeed = speed
		sound.RollOffMinDistance = 5
		sound.RollOffMaxDistance = maxDistance
		sound.Parent = root
		sound:Play()
	end

	local self = setmetatable({
		match = match,
		model = model,
		root = root,
		position = root.Position,
		yaw = 0,
		state = "dormant", -- dormant | wander | chase | search | stunned
		target = nil :: Player?,
		targetVisible = false,
		lastSeenPos = nil :: Vector3?,
		lastSeenTime = 0,
		searchUntil = 0,
		goal = nil :: Vector3?,
		waypoints = {} :: { PathWaypoint },
		wpIndex = 1,
		computing = false,
		lastPathTime = 0,
		lastPathGoal = nil :: Vector3?,
		idleUntil = 0,
		stunnedUntil = 0,
		senseTimer = 0,
		lastGiggle = 0,
		nextHunt = 0,
		wasChasing = false,
		seenHiding = {} :: { [Player]: boolean },
		enraged = false,
		destroyed = false,
		pathFailed = false,
		path = PathfindingService:CreatePath({
			AgentRadius = 1.6,
			AgentHeight = 6,
			AgentCanJump = false,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		}),
	}, Monster)

	model.Parent = parent
	loop("Breathing", Config.Sounds.Breathing, 0.8, 50, 0.9)
	loop("MusicBox", Config.Sounds.MusicBox, 0.35, 45, 0.92)
	loop("Squeak", Config.Sounds.Squeak, 0, 60, 1)
	model:SetAttribute("Chasing", false)
	return self
end

function Monster:Teleport(position: Vector3)
	self.position = Vector3.new(position.X, self.match.floorY + 1, position.Z)
	self.waypoints = {}
	self.goal = nil
	self:_applyCFrame()
end

function Monster:Activate()
	if self.destroyed then
		return
	end
	self.state = "wander"
end

function Monster:Stop()
	self.state = "dormant"
	self.target = nil
end

function Monster:Enrage()
	self.enraged = true
end

function Monster:Destroy()
	self.destroyed = true
	self.model:Destroy()
end

function Monster:_speed(): number
	local keys = self.match.keysInserted or 0
	if self.state == "chase" or self.state == "search" then
		local extra = math.max(0, self.match:GetPlayerCount() - 1) * M.ExtraSpeedPerPlayer
		return M.ChaseSpeed + extra + keys * M.SpeedPerKey + (self.enraged and 2 or 0)
	end
	return M.WanderSpeed + keys * M.SpeedPerKey * 0.5 + (self.enraged and 3 or 0)
end

-- I finalen vet monsteret hele tiden omtrent hvor nærmeste spiller er (ikke de som gjemmer seg)
function Monster:_huntNearest(now: number)
	if self.state == "chase" or now < (self.nextHunt or 0) then
		return
	end
	self.nextHunt = now + 2.5
	local best, bestDist = nil, math.huge
	for player in self.match.players do
		if self.match:CanBeHunted(player) and player:GetAttribute("Hidden") ~= true then
			local root = Util.getRoot(player)
			if root then
				local d = (root.Position - self.position).Magnitude
				if d < bestDist then
					best, bestDist = root.Position, d
				end
			end
		end
	end
	if best then
		self.lastSeenPos = best
		self.state = "search"
		self.searchUntil = now + 4
		self.goal = nil
	end
end

function Monster:_applyCFrame()
	self.root.CFrame = CFrame.new(self.position) * CFrame.Angles(0, self.yaw, 0)
end

function Monster:_lookVector(): Vector3
	return Vector3.new(-math.sin(self.yaw), 0, -math.cos(self.yaw))
end

function Monster:_lineOfSight(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { self.model, self.match.keysFolder }
	for player in self.match.players do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(from, to - from, params)
	return result == nil
end

-- Ser og hører etter spillere
function Monster:_sense(now: number)
	local look = self:_lookVector()
	local eye = self.position + Vector3.new(0, EYE_HEIGHT, 0) + look * EYE_FORWARD
	local sightRange = M.SightRange * (self.enraged and 1.5 or 1)
	local bestPlayer: Player? = nil
	local bestDist = math.huge
	local bestVisible = false
	local bestPos: Vector3? = nil

	for player in self.match.players do
		if not self.match:CanBeHunted(player) then
			continue
		end
		local root = Util.getRoot(player)
		if not root then
			continue
		end
		local hidden = player:GetAttribute("Hidden") == true
		if hidden and not self.seenHiding[player] then
			continue
		end
		local offset = flat(root.Position - eye)
		local dist = offset.Magnitude
		local visible = false
		if hidden then
			visible = true -- hun så deg gå inn i skapet
		elseif dist <= sightRange then
			local dot = dist > 0.01 and look:Dot(offset.Unit) or 1
			local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
			if angle <= M.FieldOfView / 2 or dist < 10 or self.enraged then
				visible = self:_lineOfSight(eye, root.Position + Vector3.new(0, 1.5, 0))
			end
		end
		local speed = flat(root.AssemblyLinearVelocity).Magnitude
		local heard = dist <= M.HearRange or (speed > 15 and dist <= M.SprintHearRange)
		if (visible or heard) and dist < bestDist then
			bestPlayer = player
			bestDist = dist
			bestVisible = visible
			bestPos = root.Position
		end
	end

	if bestPlayer and bestPos then
		if self.target ~= bestPlayer or self.state ~= "chase" then
			self.match:OnMonsterSpotted(bestPlayer)
			if now - self.lastGiggle > M.GiggleCooldown then
				self.lastGiggle = now
				Util.playSound(self.root, Config.Sounds.Giggle, 1.2, 70)
			end
		end
		self.state = "chase"
		self.target = bestPlayer
		self.targetVisible = bestVisible
		self.lastSeenPos = bestPos
		self.lastSeenTime = now
	else
		self.targetVisible = false
	end
end

function Monster:OnPlayerHid(player: Player)
	if self.target ~= player then
		return
	end
	local root = Util.getRoot(player)
	local dist = root and flat(root.Position - self.position).Magnitude or math.huge
	if self.state == "chase" and self.targetVisible and dist <= M.SeeHideRange then
		self.seenHiding[player] = true
	else
		self.target = nil
		self.state = "search"
		self.searchUntil = os.clock() + M.LoseTargetTime
	end
end

function Monster:OnPlayerLeftCloset(player: Player)
	self.seenHiding[player] = nil
end

function Monster:ForgetPlayer(player: Player)
	self.seenHiding[player] = nil
	if self.target == player then
		self.target = nil
		self.state = "wander"
		self.goal = nil
	end
end

function Monster:_pickWanderGoal(): Vector3?
	local points = self.match.patrolPoints
	if #points == 0 then
		return nil
	end
	-- Av og til går hun mot en tilfeldig spiller, så hun ikke bare vandrer bort
	if math.random() < 0.35 then
		local candidates = {}
		for player in self.match.players do
			if self.match:CanBeHunted(player) and player:GetAttribute("Hidden") ~= true then
				local root = Util.getRoot(player)
				if root then
					table.insert(candidates, root.Position)
				end
			end
		end
		if #candidates > 0 then
			local near = candidates[math.random(1, #candidates)]
			local options = {}
			for _, p in points do
				if (p - near).Magnitude < 45 then
					table.insert(options, p)
				end
			end
			if #options > 0 then
				return options[math.random(1, #options)]
			end
		end
	end
	return points[math.random(1, #points)]
end

function Monster:_requestPath(goal: Vector3)
	if self.computing then
		return
	end
	self.computing = true
	self.lastPathTime = os.clock()
	self.lastPathGoal = goal
	local from = self.position
	task.spawn(function()
		local ok = pcall(function()
			self.path:ComputeAsync(from, goal)
		end)
		if self.destroyed then
			return
		end
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.wpIndex = math.min(2, #self.waypoints)
			self.pathFailed = false
		else
			self.waypoints = {}
			self.pathFailed = true
		end
		self.computing = false
	end)
end

-- Går et steg mot neste veipunkt. Returnerer true når målet er nådd.
function Monster:_followPath(dt: number, speed: number): boolean
	local wp = self.waypoints[self.wpIndex]
	if not wp then
		return true
	end
	local target = Vector3.new(wp.Position.X, self.position.Y, wp.Position.Z)
	local delta = target - self.position
	local dist = delta.Magnitude
	if dist < 0.8 then
		self.wpIndex += 1
		return self.waypoints[self.wpIndex] == nil
	end
	local step = math.min(dist, speed * dt)
	self.position += delta.Unit * step
	self.yaw = lerpAngle(self.yaw, yawFromDirection(delta), math.min(1, dt * 8))
	return false
end

function Monster:_moveDirect(dt: number, speed: number, goal: Vector3)
	local target = Vector3.new(goal.X, self.position.Y, goal.Z)
	local delta = target - self.position
	local dist = delta.Magnitude
	if dist < 0.5 then
		return
	end
	self.position += delta.Unit * math.min(dist, speed * dt)
	self.yaw = lerpAngle(self.yaw, yawFromDirection(delta), math.min(1, dt * 10))
end

function Monster:_checkCatch()
	for player in self.match.players do
		if not self.match:CanBeHunted(player) then
			continue
		end
		if player:GetAttribute("Hidden") == true and not self.seenHiding[player] then
			continue
		end
		local root = Util.getRoot(player)
		if not root then
			continue
		end
		local d = root.Position - self.position
		if flat(d).Magnitude <= M.CatchRange and math.abs(d.Y) < 9 then
			self:_caught(player)
			return
		end
	end
end

function Monster:_caught(player: Player)
	self.seenHiding[player] = nil
	self.target = nil
	self.state = "stunned"
	self.stunnedUntil = os.clock() + M.CatchCooldown
	self.match:OnCaught(player)
	-- Hun "forsvinner" og dukker opp et annet sted
	task.delay(0.6, function()
		if self.destroyed then
			return
		end
		local far = self.match:GetFarPatrolPoint()
		if far then
			self:Teleport(far)
		end
	end)
end

function Monster:Step(dt: number)
	if self.destroyed then
		return
	end
	local chasing = self.state == "chase"
	if chasing ~= self.wasChasing then
		self.wasChasing = chasing
		self.model:SetAttribute("Chasing", chasing)
	end
	if self.state == "dormant" then
		return
	end
	local now = os.clock()
	if self.state == "stunned" then
		if now < self.stunnedUntil then
			return
		end
		self.state = "wander"
		self.goal = nil
	end

	self.senseTimer -= dt
	if self.senseTimer <= 0 then
		self.senseTimer = 0.15
		self:_sense(now)
	end
	if self.enraged then
		self:_huntNearest(now)
	end

	local speed = self:_speed()

	if self.state == "chase" then
		local target = self.target
		local root = target and Util.getRoot(target)
		if not target or not root or not self.match:CanBeHunted(target) then
			self.state = "search"
			self.searchUntil = now + M.LoseTargetTime
		elseif now - self.lastSeenTime > M.LoseTargetTime then
			self.state = "search"
			self.searchUntil = now + 3
		else
			local goal = self.targetVisible and root.Position or (self.lastSeenPos or root.Position)
			local dist = flat(goal - self.position).Magnitude
			if self.targetVisible and dist < 22 then
				self:_moveDirect(dt, speed, goal)
				self.waypoints = {}
			else
				local lastGoal = self.lastPathGoal
				if not self.computing and (not lastGoal or (lastGoal - goal).Magnitude > 3 or now - self.lastPathTime > 1) then
					self:_requestPath(goal)
				end
				if #self.waypoints > 0 then
					self:_followPath(dt, speed)
				elseif self.pathFailed and dist < 12 then
					self:_moveDirect(dt, speed, goal)
				end
			end
		end
	elseif self.state == "search" then
		local goal = self.lastSeenPos
		if goal and flat(goal - self.position).Magnitude > 2 then
			if not self.computing and (self.lastPathGoal ~= goal) then
				self:_requestPath(goal)
			end
			if #self.waypoints > 0 then
				self:_followPath(dt, speed * 0.8)
			end
		end
		if now > self.searchUntil then
			self.state = "wander"
			self.goal = nil
			self.lastSeenPos = nil
		end
	elseif self.state == "wander" then
		if now < self.idleUntil then
			-- står stille og rykker på hodet
		elseif not self.goal then
			self.goal = self:_pickWanderGoal()
			if self.goal then
				self.waypoints = {}
				self:_requestPath(self.goal)
			end
		elseif not self.computing then
			local reached = #self.waypoints == 0 or self:_followPath(dt, speed)
			if reached then
				self.goal = nil
				self.idleUntil = now + 0.8 + math.random() * 2.5
			end
		end
	end

	self:_applyCFrame()
	self:_checkCatch()
end

return Monster
