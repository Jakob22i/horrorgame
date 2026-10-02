# horrorgame – St. Agathe sykehus

Et analog-horror-spill i Roblox for 1–4 spillere per gruppe.

## Slik fungerer spillet

- Alle spawner i **lobbyen**. Langs veggen står **4 heiser** med plass til maks 4 spillere hver.
  Gå inn i en heis, så starter en nedtelling (15 sek, eller 5 sek hvis heisen er full).
- Gruppa havner i et mørkt, forlatt **sykehus**. Målet er å finne **5 nøkler** som ligger
  tilfeldig plassert rundt i kartet, og sette dem inn ved **nødutgangen** i resepsjonen.
- **Den bleke damen** jakter på dere. Hun ser dere, hører dere når dere løper, og rykker
  og blinker som et gammelt VHS-opptak.
- Gjem deg i **skapene** (24 stk). Ser hun deg gå inn, drar hun deg ut.
- Hver spiller har **3 liv**. Blir du tatt, får du en jumpscare, nøklene du bar faller der
  du døde, og du starter på nytt i resepsjonen.
- Har alle mistet alle liv, kan hver spiller velge **Prøv igjen** (ny runde fra starten)
  eller **Til lobbyen**.
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
| Monsteret | `ServerStorage/Monster` |
| Nøkkelen | `ServerStorage/Key` |
| Innstillinger | `ReplicatedStorage/Shared/Config` |
| Serverscript | `ServerScriptService/GameServer` (+ modulene Lobby, Match, Monster, Util) |
| Klientscript | `StarterPlayer/StarterPlayerScripts/ClientMain` (+ UI, Effects, Controls, Jumpscare) |

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
hvor fort hun går, hvor langt hun ser, lyder osv.

**Bruke ditt eget bilde som ansiktet hennes:** last opp bildet som en Decal på Roblox, og
lim inn ID-en i `MonsterFaceDecal`, f.eks. `"rbxassetid://1234567890"`.

## For utviklere

Spillfila bygges av Lune-scriptene i `build/`. Grunnlaget er `place/base.rbxl` (den
opprinnelige Baseplate-fila), og scriptene hentes fra `src/`.

```sh
lune run build/build.luau   # lager horrorgame.rbxl og sourcemap.json
```

Typesjekk med [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp):

```sh
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --platform=roblox src/
```
