--!strict
-- Innstillinger for hele spillet. Endre tallene her for å justere vanskelighetsgrad.

local Config = {
	-- Lobby og heiser
	MaxPlayersPerElevator = 4,
	ElevatorCountdown = 15, -- sekunder fra første spiller går inn til heisen går
	ElevatorFullCountdown = 5, -- nedtelling når heisen er full

	-- Spillregler
	Lives = 3,
	KeysToEscape = 5,
	RespawnDelay = 4, -- sekunder med svart skjerm etter at du blir tatt
	RespawnProtection = 4, -- sekunder monsteret ignorerer deg etter respawn
	GameOverChoiceTime = 25, -- sekunder til å velge "prøv igjen" eller "lobby"
	WinReturnTime = 10, -- sekunder før alle sendes til lobbyen etter seier

	-- Spiller
	WalkSpeed = 12,
	SprintSpeed = 20,
	StaminaMax = 100,
	StaminaDrain = 24, -- per sekund mens du løper
	StaminaRegen = 14, -- per sekund når du ikke løper
	StaminaRegenDelay = 1.2,

	-- Monsteret (Den bleke damen)
	Monster = {
		StartDelay = 12, -- sekunder før hun begynner å jakte
		WanderSpeed = 8,
		ChaseSpeed = 16.5,
		ExtraSpeedPerPlayer = 0.4, -- litt raskere for hver ekstra spiller
		SightRange = 75,
		FieldOfView = 140, -- grader
		HearRange = 14, -- hører deg alltid innenfor denne avstanden
		SprintHearRange = 32, -- hører deg på lengre avstand når du løper
		CatchRange = 4.5,
		LoseTargetTime = 6, -- sekunder hun leter etter at hun mistet deg av syne
		SeeHideRange = 12, -- ser hun deg gjemme deg innenfor denne avstanden, drar hun deg ut
		CatchCooldown = 6, -- sekunder hun "forsvinner" etter å ha tatt noen
	},

	-- Lyder (lisensierte Roblox-lyder fra Creator Store)
	Sounds = {
		LobbyMusic = "rbxassetid://1846999567", -- Creepy Night
		Ambience = "rbxassetid://9112775175", -- Eerie Ambience 1
		Static = "rbxassetid://9126160908", -- Video Static Distortion
		Heartbeat = "rbxassetid://9043365842", -- Heartbeat 96 BPM
		Scream = "rbxassetid://9125712561", -- Distorted Scream
		JumpscareHit = "rbxassetid://9041752524", -- Eyes Scream Horror Hit
		Whisper = "rbxassetid://9126213995", -- Whisper Bursts
		Breathing = "rbxassetid://9114226295", -- Eerie Breathing Howl
		KeyPickup = "rbxassetid://9116176803", -- Keys Jingle
		KeyInsert = "rbxassetid://9116324156", -- Lock Unlock Door
		Locker = "rbxassetid://9116742347", -- Metal Locker Door
		Elevator = "rbxassetid://9114305596", -- Elevator Doors Open Close
		LampBuzz = "rbxassetid://9112823813", -- Light Bulb Buzz
		Flashlight = "rbxassetid://9114480271", -- Flashlight Click
		GameOver = "rbxassetid://1840927247", -- Horror Hits 7
		Win = "rbxassetid://9047014318", -- Beautiful Horror Stinger
	},

	-- Valgfritt: last opp bildet av damen som Decal på Roblox og lim inn ID-en her,
	-- f.eks. "rbxassetid://1234567890". Da brukes bildet som ansiktet hennes.
	MonsterFaceDecal = "",
}

return Config
