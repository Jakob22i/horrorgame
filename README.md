# horrorgame – St. Agathe sykehus

Et analog-horror-spill i Roblox for 1–4 spillere per gruppe. Alt i spillet er på engelsk.

## Slik fungerer spillet

- Alle spawner i **lobbyen**. Langs veggen står **4 heiser** med plass til maks 4 spillere hver.
  Gå inn i en heis, så starter en nedtelling (15 sek, eller 5 sek hvis heisen er full).
- Gruppa havner i et mørkt, forlatt **sykehus**. Målet er å finne **5 nøkler** som ligger
  tilfeldig plassert rundt i kartet, og sette dem inn ved **nødutgangen** i resepsjonen.
- **Patient #0413** jakter på dere: en høy, utmagret pasient med et altfor bredt, sydd glis,
  svarte øyehuler og et dryppstativ med blodpose som den drar etter seg. Den ser dere, hører
  dere når dere løper, halter, rykker i hodet, klaprer med kjeven når den jakter, og du kan
  høre de knirkende hjulene og en spilledåse når den er i nærheten.
- Gjem deg i **skapene** (24 stk). Trykk E på skapet for å gå inn og ut (eller LEAVE-knappen).
  Ser den deg gå inn, drar den deg ut.
- Hver spiller har **3 liv**. Blir du tatt, får du en jumpscare, nøklene du bar faller der
  du døde, og du starter på nytt i resepsjonen.
- Har alle mistet alle liv, kan hver spiller velge **Try again** (ny runde fra starten)
  eller **To lobby**.
- Når 5 nøkler er satt inn, åpner nødutgangen seg. Løp ut, så har dere vunnet.

**Taster:** `F` lommelykt · `Shift` løp · `E` bruk / gjem deg / gå ut av skap.
På mobil dukker det opp egne knapper.

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
| Serverscript | `ServerScriptService/GameServer` (+ modulene Lobby, Match, Monster, Util) |
| Klientscript | `StarterPlayer/StarterPlayerScripts/ClientMain` (+ UI, Effects, Controls, Jumpscare, MonsterAnimator) |

Sykehuset ligger i `ServerStorage` og klones inn i `Workspace/Matches` for hver gruppe.
Vil du redigere kartet, drar du `HospitalTemplate` inn i `Workspace`, endrer det og drar
det tilbake. Mappene i kartet styrer spillet:

- `Closets`: skapene (må ha `HidePoint`, `OutPoint` og `PromptPart`)
- `KeySpots`: steder der nøkler kan dukke opp. Attributtet `Room` sørger for maks én nøkkel per rom.
- `SpawnPoints`: startpunktene i resepsjonen
- `PatrolPoints`: punktene monsteret vandrer mellom
- `Lamps`: taklampene. Serveren velger tilfeldig om de er på, av eller blinker.

## Justere spillet

Alt av tall ligger i `ReplicatedStorage/Shared/Config`: antall liv, nøkler, nedtelling,
hvor fort monsteret går, hvor langt det ser, lyder osv.

Monsteret er bygget av ca. 800 deler som er sveiset til et "skjelett" (mappen `Rig`).
Leddene ligger i mappen `Joints` og animeres av `MonsterAnimator` på hver klient, mens
serveren bare flytter `Root`. Bilder av karakteren ligger i `preview/`.

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
```

Merk: Lune sin `CFrame.lookAt` snur Z-aksen feil, så byggescriptene bruker `lib.lookAt`.

Typesjekk med [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp):

```sh
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --platform=roblox src/
```
