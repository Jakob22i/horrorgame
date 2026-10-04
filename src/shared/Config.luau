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
	WinReturnTime = 24, -- sekunder før alle sendes til lobbyen etter seier (sluttscenen varer ca. 20 sek)

	-- Spiller
	WalkSpeed = 12,
	SprintSpeed = 20,
	StaminaMax = 100,
	StaminaDrain = 24, -- per sekund mens du løper
	StaminaRegen = 14, -- per sekund når du ikke løper
	StaminaRegenDelay = 1.2,

	-- Monsteret (Patient #0413)
	Monster = {
		StartDelay = 12, -- sekunder før den begynner å jakte
		WanderSpeed = 9.2, -- (15 % raskere enn før)
		ChaseSpeed = 19,
		ExtraSpeedPerPlayer = 0.4, -- litt raskere for hver ekstra spiller
		SightRange = 75,
		FieldOfView = 140, -- grader
		HearRange = 14, -- hører deg alltid innenfor denne avstanden
		SprintHearRange = 32, -- hører deg på lengre avstand når du løper
		CatchRange = 4.5,
		LoseTargetTime = 6, -- sekunder den leter etter at den mistet deg av syne
		SeeHideRange = 12, -- ser den deg gjemme deg innenfor denne avstanden, drar den deg ut
		CatchCooldown = 6, -- sekunder den "forsvinner" etter å ha tatt noen
		GiggleCooldown = 10, -- sekunder mellom hver gang den fniser når den ser noen
		SpeedPerKey = 0.6, -- raskere for hver nøkkel som er satt inn
	},

	-- Redd vennene dine: blir du tatt mens en venn fortsatt står, ligger du nede en stund
	-- og kan bli hjulpet opp (uten å miste et liv)
	Downed = {
		Time = 15, -- sekunder du ligger nede før du mister et liv (0 = slått av)
		HelpTime = 2.5, -- hvor lenge en venn må holde E for å hjelpe deg opp
		Protection = 3, -- sekunder monsteret lar deg være i fred etter at du er hjulpet opp
	},

	-- Nightmare-modus (velges i heisen)
	Nightmare = {
		Lives = 1,
		MonsterSpeed = 1.15, -- ganger vanlig fart
		ClosetsKept = 0.6, -- andel av skapene som er igjen
		LampsOff = 0.45, -- andel lamper som er av
		CoinMultiplier = 2,
	},

	-- Skap: du kan ikke gjemme deg for alltid
	Closet = {
		MaxTime = 20, -- sekunder før du må ut og trekke pusten
		Cooldown = 6, -- sekunder før du kan gjemme deg igjen etter at du har gått ut
	},

	-- Strømbrudd: etter et visst antall nøkler går lyset av og på
	Blackout = {
		AfterKeys = 3,
		Every = { 30, 50 }, -- sekunder mellom hvert strømbrudd (tilfeldig)
		Length = { 10, 16 }, -- hvor lenge lyset er borte
	},

	-- Finalen: når alle nøklene er satt inn må dere overleve til døra åpner seg
	FinaleTime = 60,

	-- Kjøp med Robux. Opprett produktene på create.roblox.com etter at spillet er publisert,
	-- og lim inn ID-ene her. Står en ID på 0, er kjøpet gratis i Studio (for testing).
	Shop = {
		ReviveProductId = 0, -- Developer Product: Revive (39 Robux)
		PushGamePassId = 0, -- Game Pass: Push (49 Robux)
		JumpscareProductId = 0, -- Developer Product: Jumpscare everyone (49 Robux)
		RevivePrice = 39, -- prisene som vises i spillet
		PushPrice = 49,
		JumpscarePrice = 49,
	},
	ReviveProtection = 5, -- sekunder monsteret ignorerer deg etter revive
	DeathChoiceTime = 15, -- sekunder "YOU DIED"-menyen vises før du blir tilskuer

	-- Push (dytte andre spillere)
	Push = {
		Range = 7,
		Speed = 55, -- hvor hardt de blir dyttet
		Cooldown = 5,
	},

	-- Mynter du tjener (dobbelt i Nightmare). Brukes på kosmetikk i lobbyen.
	Coins = {
		Round = 10, -- for å spille en runde (minst 90 sekunder)
		KeyFound = 5,
		KeyInserted = 5,
		HelpUp = 10, -- for å hjelpe en venn opp
		Escape = 50, -- alle i runden får dette når noen kommer seg ut
	},

	-- Kosmetikk som kan kjøpes for mynter i butikken i lobbyen
	Cosmetics = {
		Flashlights = {
			{ id = "warm", name = "Warm", color = Color3.fromRGB(255, 244, 220), price = 0 },
			{ id = "white", name = "Cold White", color = Color3.fromRGB(215, 232, 255), price = 100 },
			{ id = "green", name = "Night Vision", color = Color3.fromRGB(130, 255, 140), price = 250 },
			{ id = "red", name = "Blood Red", color = Color3.fromRGB(255, 80, 66), price = 300 },
			{ id = "blue", name = "Deep Blue", color = Color3.fromRGB(110, 160, 255), price = 300 },
			{ id = "purple", name = "Ultraviolet", color = Color3.fromRGB(190, 110, 255), price = 450 },
			{ id = "gold", name = "Golden", color = Color3.fromRGB(255, 205, 90), price = 700 },
		},
		Titles = {
			{ id = "none", name = "No title", text = "", color = Color3.fromRGB(200, 200, 200), price = 0 },
			{ id = "survivor", name = "Survivor", text = "SURVIVOR", color = Color3.fromRGB(150, 235, 160), price = 150 },
			{ id = "nightshift", name = "Night Shift", text = "NIGHT SHIFT", color = Color3.fromRGB(150, 190, 255), price = 250 },
			{ id = "patient", name = "Patient", text = "PATIENT", color = Color3.fromRGB(235, 235, 220), price = 300 },
			{ id = "ghost", name = "Ghost", text = "GHOST", color = Color3.fromRGB(200, 200, 230), price = 400 },
			{ id = "visitor", name = "Late Visitor", text = "LATE VISITOR", color = Color3.fromRGB(255, 200, 120), price = 500 },
			{ id = "p0413", name = "#0413", text = "#0413", color = Color3.fromRGB(235, 50, 50), price = 1000 },
		},
	},

	-- Lyder (lisensierte Roblox-lyder fra Creator Store)
	Sounds = {
		LobbyMusic = "rbxassetid://1846999567", -- Creepy Night
		Ambience = "rbxassetid://9112775175", -- Eerie Ambience 1
		Static = "rbxassetid://9126160908", -- Video Static Distortion
		Heartbeat = "rbxassetid://9043365842", -- Heartbeat 96 BPM
		Scream = "rbxassetid://9125712561", -- Distorted Scream
		JumpscareHit = "rbxassetid://9041752524", -- Eyes Scream Horror Hit
		Breathing = "rbxassetid://9114226295", -- Eerie Breathing Howl
		Squeak = "rbxassetid://9120658777", -- Old Squeaky Wheel (dryppstativet)
		Giggle = "rbxassetid://9114571613", -- Ghost Giggle Creepy
		MusicBox = "rbxassetid://138717310622754", -- Twisted Music Box
		BoneCrack = "rbxassetid://9113546532", -- Bone Cracks
		KeyPickup = "rbxassetid://9116176803", -- Keys Jingle
		KeyInsert = "rbxassetid://9116324156", -- Lock Unlock Door
		Locker = "rbxassetid://9116742347", -- Metal Locker Door
		Elevator = "rbxassetid://9114305596", -- Elevator Doors Open Close
		LampBuzz = "rbxassetid://9112823813", -- Light Bulb Buzz
		Flashlight = "rbxassetid://9114480271", -- Flashlight Click
		GameOver = "rbxassetid://1840927247", -- Horror Hits 7
		Win = "rbxassetid://9047014318", -- Beautiful Horror Stinger
		Push = "rbxassetid://9117969687", -- Punch Kit Beefy Hit
		PowerDown = "rbxassetid://9117871125", -- Power Down
		PowerUp = "rbxassetid://9117883108", -- Power Up And Down
		Alarm = "rbxassetid://9119661709", -- Submarine Alarm Siren
		StaticBurst = "rbxassetid://9126160991", -- Video Static Burst
		KeyShimmer = "rbxassetid://9125986205", -- Sparkle Tone Constant High End Shimmer (nøklene)
		-- Lyder i det fjerne (spilles tilfeldig rundt deg)
		Knock = "rbxassetid://9114141413", -- Door Knock 5
		FranticKnock = "rbxassetid://9114432636", -- Fire Door Frantic Knocks 1
		DoorSlam = "rbxassetid://9114153270", -- Door Slams 2
		DoorCreak = "rbxassetid://9114135682", -- Door Creak 1
		Whisper = "rbxassetid://9126213995", -- Whisper Bursts Unintelligible Eerie
		WhisperClose = "rbxassetid://9126214616", -- Whisper Bursts Reverberant
		GurneyRoll = "rbxassetid://9114735770", -- Gurney Rolling 2
		MetalScrape = "rbxassetid://9116818437", -- Metal Scrapes 1
		DistantScream = "rbxassetid://9125438052", -- Child Scream Nightmare Distant
		PowerHum = "rbxassetid://9125784811", -- Power Throb Tonal Hum Slow Pulse
	},
}

return Config
