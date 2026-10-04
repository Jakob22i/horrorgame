# horrorgame – St. Agathe sykehus

Et analog-horror-spill i Roblox for 1–4 spillere per gruppe. Alt i spillet er på engelsk.

## Slik fungerer spillet

- Alle spawner i **lobbyen**. Langs veggen står **4 heiser** med plass til maks 4 spillere hver.
  Gå inn i en heis, så starter en nedtelling (15 sek, eller 5 sek hvis heisen er full).
- Gruppa havner i et mørkt, forlatt **sykehus** med tre fløyer (hovedbygget, østfløyen med
  intensiv, apotek, isolat og kantine, og sørfløyen med vaskeri, kapell, lab, arkiv og
  lasterampe). Målet er å finne **5 nøkler** som ligger tilfeldig plassert rundt i kartet, og
  sette dem inn ved **nødutgangen** på lasterampen (LOADING DOCK) helt i sørøst.
- **Patient #0413** jakter på dere: en høy, utmagret pasient med et altfor bredt, sydd glis,
  svarte øyehuler og et dryppstativ med blodpose som den drar etter seg. Den ser dere, hører
  dere når dere løper, halter, rykker i hodet, klaprer med kjeven når den jakter, og du kan
  høre de knirkende hjulene og en spilledåse når den er i nærheten.
- Gjem deg i **skapene** (44 stk). Trykk E på skapet for å gå inn og ut (eller LEAVE-knappen).
  Ser den deg gå inn, drar den deg ut.
- Hver spiller har **3 liv**. Blir du tatt, får du en jumpscare, nøklene du bar faller der
  du døde, og du starter på nytt i resepsjonen.
- Bruker du opp alle livene, får du valget **REVIVE** (39 Robux, du kommer tilbake i
  resepsjonen med 1 liv) eller **SPECTATE**. Har alle mistet alle liv, kan hver spiller
  velge **REVIVE**, **Try again** (ny runde fra starten) eller **To lobby**.
- Monsteret blir **raskere for hver nøkkel** som settes inn.
- Etter **3 nøkler** begynner strømmen å svikte: hvert 30.–50. sekund dempes lyset sakte ned i
  10–16 sekunder (bare noen svake, røde nødlys står igjen) før det sakte kommer tilbake. Da
  trenger du lommelykta.
- **Lyset blinker ikke.** I stedet dempes lampene og blir røde der monsteret er, så du ser at
  gangen foran deg blir mørkere og rødere før den kommer rundt hjørnet.
- **Ting som skjer av og til** (bare på din skjerm, og aldri når monsteret er nær):
  - lyder i det fjerne: banking, dører som smeller, hvisking, en båre som ruller, skraping
  - en mørk skikkelse med lysende øyne som står langt borte og ser på deg, og forsvinner med et
    støyglimt når du ser rett på den
  - lampene slukner én etter én med et «klonk» bortover gangen mot deg, og kommer tilbake etterpå
- **Nøklene skinner**: de svever og snurrer over der de ligger, lyser varmt gult, glitrer og har
  en svak klingende lyd, så de er lette å finne.
- **Blodet** er tegnet med myke, organiske former: mørke, våte pytter som har rent ut, inntørkede
  brune flekker, slepespor, bare fotspor som går ut av en pytt, sprut og renner på veggene og
  flekkete håndavtrykk.
- Når alle 5 nøklene er satt inn, starter **LOCKDOWN**: alarmen går, alle lamper blinker rødt,
  monsteret jakter på nærmeste spiller, og døra åpner seg først etter **60 sekunder**.
  Overlev, og løp ut når den åpner seg.
- Kommer noen seg ut, spilles **sluttscenen** for alle i runden: dere er ute... men noe står i
  døråpningen bak dere. Den slutter med en cliffhanger og **PART 2 – COMING SOON**, og så går
  alle tilbake til lobbyen.
- Når du kommer inn i spillet, vises en **VHS-loading screen** («PLEASE STAND BY») mens lyder
  og monsteret lastes inn.

**Taster:** `1` lommelykt (eller `F`) · `2` push · `3` jumpscare everyone · `Shift` løp ·
`E` bruk / gjem deg / gå ut av skap. Musa er bare fri når en meny er åpen.
Knappene nederst på skjermen kan trykkes på (mobil).

## Robux-kjøp

| Kjøp | Type | Pris | Hva det gjør |
| --- | --- | --- | --- |
| Revive | Developer Product | 39 | Tilbake i resepsjonen med 1 liv og 5 sek beskyttelse |
| Push | Game Pass | 49 | Låser opp Push: dytter spilleren foran deg (5 sek ventetid) |
| Jumpscare everyone | Developer Product | 49 | Jumpscarer alle de andre i runden din (ikke lobbyen) |

Slik setter du dem opp:

1. Publiser spillet (**File → Publish to Roblox**).
2. Gå til [create.roblox.com](https://create.roblox.com) → spillet ditt → **Monetization**.
3. Under **Developer Products**: lag «Revive» (39) og «Jumpscare everyone» (49).
4. Under **Passes**: lag «Push», og sett den til salgs for 49.
5. Kopier ID-ene inn i `ReplicatedStorage/Shared/Config` → `Shop`
   (`ReviveProductId`, `JumpscareProductId`, `PushGamePassId`).

Så lenge en ID er `0`, er kjøpet gratis i Studio, slik at du kan teste. Kjøpte revives og
jumpscares som ikke ble brukt med en gang, lagres og blir gratis neste gang (krever at
**Enable Studio Access to API Services** er på hvis du vil teste lagringen i Studio).

## Åpne spillet i Roblox Studio

1. Last ned `horrorgame.rbxl`.
2. Åpne den i Roblox Studio (**File → Open from File**).
3. Trykk **Play** for å teste alene, eller gå til **Test → Clients and Servers**, velg 2–4
   spillere og trykk **Start** for å teste flerspiller.
4. Når du publiserer, setter du maks antall spillere til **16** (4 heiser × 4 spillere) i
   **Game Settings**.

## Hvor ligger alt?

| Hva | Hvor i Explorer |
| --- | --- |
| Lobbyen med heisene | `Workspace/Lobby` |
| Sykehuskartet (malen) | `ServerStorage/HospitalTemplate` |
| Monsteret (Patient #0413) | `ServerStorage/Monster` |
| Nøkkelen | `ServerStorage/Key` |
| Innstillinger | `ReplicatedStorage/Shared/Config` |
| Serverscript | `ServerScriptService/GameServer` (+ modulene Lobby, Match, Monster, Shop, Util) |
| Klientscript | `StarterPlayer/StarterPlayerScripts/ClientMain` (+ UI, Effects, Controls, Jumpscare, MonsterAnimator, Ending, Scares) |
| Loading screen | `ReplicatedFirst/LoadingScreen` |

Sykehuset ligger i `ServerStorage` og klones inn i `Workspace/Matches` for hver gruppe.
Vil du redigere kartet, drar du `HospitalTemplate` inn i `Workspace`, endrer det og drar
det tilbake. Mappene i kartet styrer spillet:

- `Closets`: skapene (må ha `HidePoint`, `OutPoint` og `PromptPart`)
- `KeySpots`: steder der nøkler kan dukke opp. Attributtet `Room` sørger for maks én nøkkel per rom.
- `SpawnPoints`: startpunktene i resepsjonen
- `PatrolPoints`: punktene monsteret vandrer mellom
- `Lamps`: taklampene. Serveren velger tilfeldig om de er på, svake (`dim`) eller av.
  Klienten styrer lysnivået mykt (`Effects`).

## Justere spillet

Alt av tall ligger i `ReplicatedStorage/Shared/Config`: antall liv, nøkler, nedtelling,
hvor fort monsteret går, hvor langt det ser, lyder osv. Noen nyttige:

- `Monster.SpeedPerKey`: hvor mye raskere monsteret blir per nøkkel som er satt inn
- `Blackout`: etter hvor mange nøkler strømmen begynner å svikte, og hvor ofte og lenge
- `FinaleTime`: hvor lenge dere må overleve før døra åpnes (sekunder)
- `WinReturnTime`: hvor lang tid sluttscenen får før alle sendes til lobbyen

Monsteret er bygget av ca. 800 deler som er sveiset til et "skjelett" (mappen `Rig`).
Leddene ligger i mappen `Joints` og animeres av `MonsterAnimator` på hver klient, mens
serveren bare flytter `Root`. Bilder av karakteren, knappene, sluttscenen og loading screenen ligger i `preview/`.

## For utviklere

Spillfila bygges av Lune-scriptene i `build/`. Grunnlaget er `place/base.rbxl` (den
opprinnelige Baseplate-fila), og scriptene hentes fra `src/`.

```sh
lune run build/build.luau   # lager horrorgame.rbxl og sourcemap.json
```

Andre verktøy:

```sh
lune run build/check_map.luau                         # sjekker at alle skap kan brukes
lune run build/export_preview.luau patient out.json   # eksporterer modellen for forhåndsvisning
lune run build/export_preview.luau ending out.json    # sluttscenen: monsteret i døråpningen
lune run build/export_preview.luau blood out.json     # utstilling av blodet
lune run build/export_preview.luau keyroom out.json   # en glødende nøkkel i et mørkt rom
```

Blodet bygges av `build/blood.luau` (avrundede Frames i en SurfaceGui på usynlige deler), og
nøkkelen av `build/key.luau`.

Merk: Lune sin `CFrame.lookAt` snur Z-aksen feil, så byggescriptene bruker `lib.lookAt`.

Typesjekk med [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp):

```sh
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --platform=roblox src/
```
