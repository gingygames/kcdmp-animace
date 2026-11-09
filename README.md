# Galerie animací pro KCD:MP (kcdmp-animace)

Modul a interaktivní prohlížeč všech herních animací pro multiplayerovou platformu **KCD:MP** (Kingdom Come: Deliverance II multiplayer).

Příkaz **`/animace`** otevře webový panel se všemi **6 097 animacemi hry** roztříděnými do 21 kategorií a vedle něj postaví **soukromou figurínu**, na které se animace okamžitě přehrávají. Lze zkoušet i přímo **na své postavě**.

Vše probíhá v **soukromém virtuálním světě** hráče (`30000000 + pid`), takže figurínu, rekvizity, nábytek ani partnera nikdo jiný nevidí a během náhledu nevidí ani tebe. Nefunkční animace lze přímo v rozhraní nahlásit (zvlášť pro muže a ženy).

---

## Hlavní funkce

* **Kompletní katalog:** 21 kategorií (sezení, ležení a spánek, tanec, jídlo a pití, hudba, práce a řemesla, boj a zbraně, kůň a vůz, víra, zajetí a tresty, hospoda a hry, obchod, dveře a zámky, péče a zranění, gesta, rozhovor, obličej, stání, pohyb, úkoly, ostatní).
* **Okamžité vyhledávání a filtry:** Textové hledání podle názvu fragmentu, tagu i rekvizity. Filtry pro muže/ženu, celé tělo vs. horní polovina, smyčky vs. jednorázové, přítomnost rekvizity, sezení/ležení, sekvence a párové animace.
* **Přehrávání:** Kliknutí = jednorázově, dvojklik nebo Enter = smyčka, mezerník = přehrát, S = stop.
* **Synchronizované dvojice (Dvojice / Páry):** 258 párových animací (Master/Slave, úkoly, duo tance, rukojmí, přípitky). Partner se spawnuje v privátním světě a po **600 ms usazení** (`usazeni`) se obě postavy spustí v jednom tiku, aby nedošlo k odmítnutí enginem. U tanců stojí čelem k sobě ve vzdálenosti 0,8 m.
* **Rekvizity v ruce:** Automatické přiřazení výchozí rekvizity do pravé/levé ruky (včetně 35 modelů z herních archivů – luky, kuše, pušky, knihy, flétna, brk atd. a 48 pravidel podle názvů).
* **Nábytek a scéna:** Pod postavu se automaticky umístí lavice, stůl, židle, postel nebo stan podle postoje animace.
* **Kamera a zobrazení:** Předvolby záběru kamery (Postava, Trup, Ruce, Hlava, Shora) a otáčení figuríny (klávesy Q a E).
* **Hlášení chyb a předvolby:** Možnost označit animaci jako nefunkční (✗) nebo ověřenou (✓) s poznámkou. Správce může uložit vyladěné rekvizity a posuny jako globální výchozí předvolbu pro všechny hráče.

---

## Rozdíl oproti verzi pro Kingdoms Connected (KCDC)

Původní verze vznikla pro KCDC v repozitáři [gingygames/gingy-kcdc](https://github.com/gingygames/gingy-kcdc). KCD:MP nepodporuje dynamické reflexní API `Animations.list()`, proto tato verze:
1. Nese předem vygenerovaný a zvalidovaný katalog 6 097 animací a mapování na engine klipy (`katalog-animaci.json` a `animace_data.lua`).
2. Serverová část je napsána v čistém Lua pro KCD:MP API (`CreateActor`, `SetActorAnim`, `AddEmote`, `PlayPlayerEmote`, `SetPlayerVirtualWorld`).
3. Klientská kamera a interakce běží nativně přes `SetCamera` a CEF Web Frame rozhraní (`ui.toml` + `KcdMp` SDK).

---

## Instalace do KCD:MP serveru

1. Složku `ui/` zkopírujte do složky vašeho módu nebo zaregistrujte v `server.toml` v sekci `[ui]`.
2. Soubory ze složky `server/`:
   * `server/animace.lua`
   * `server/animace_data.lua`
   * `server/animace_config.lua`
   umístěte vedle hlavního skriptu vašeho gamemodu (do `gamemodes/`).
3. Soubor `client/zz_animace.lua` umístěte do `gamemodes/<vas_mod>/client/` (předpona `zz_` zajistí načtení na konci).
4. Na konec hlavního serverového skriptu přidejte:
   ```lua
   local Animace = require("animace")
   Animace.install()
   ```

---

## Ovládání a příkazy

| Příkaz / Klávesa | Akce |
|---|---|
| `/animace` | Otevře galerii animací |
| `/animace <text>` | Otevře galerii s předvyplněným hledáním |
| `/animace zavrit` (nebo Esc) | Zavře galerii a vrátí hráče do původního světa |
| `/animace hlaseni` | Vypíše do chatu přehled nahlášených nefunkčních animací |
| **Klik** | Přehrát animaci jednou |
| **Dvojklik / Enter** | Přehrávat animaci ve smyčce |
| **Mezerník** | Přehrát vybranou animaci |
| **S** | Zastavit přehrávání |
| **Q / E** | Otočit figurínu vlevo / vpravo |

---

## Nastavení (`server/animace_config.lua`)

| Klíč | Výchozí | Význam |
|---|---|---|
| `prikaz` | `"animace"` | Název chat příkazu |
| `opravneni` | `"animace.otevrit"` | Právo pro otevření (`""` = všichni hráči, správce s obecným `admin` má přístup vždy) |
| `opravneniSpravce` | `"animace.admin"` | Právo pro ukládání předvoleb a správu hlášení |
| `panel` | `0.55` | Šířka panelu na obrazovce (poměr zleva) |
| `svetBase` | `30000000` | Základna privátních světů (`30000000 + pid`) |
| `usazeni` | `600` | Doba (ms) na usazení postavy a synchronizaci dvojic |
| `zavritPriZasahu`| `true` | Automaticky zavřít náhled při udělení damage hráči |
| `pauzaPoZasahu` | `20` | Doba (s) po zásahu, kdy nelze náhled otevřít |

---

## Testy a vývoj

Projekt obsahuje kompletní offline testovací sadu simulující KCD:MP API v Lua 5.4:

```sh
pip install lupa
python test/run.py
```

Pro lokální náhled a ladění webového rozhraní v běžném prohlížeči (bez spouštění hry):
```sh
node tools/ui-dev.mjs
# Otevřete http://localhost:5180/
```

---

## Licence

MIT License. Copyright (c) 2026 gingygames.
Tento projekt je fanouškovský a není spojen se společnostmi Warhorse Studios, PLAION ani vývojáři KCD:MP.
