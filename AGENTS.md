# kcdmp-animace – Instrukce pro AI agenty

Tento repozitář obsahuje modul Galerie animací pro multiplayerovou platformu **KCD:MP** (Kingdom Come: Deliverance II multiplayer).

---

## Architektura modulu

* **`server/animace.lua`**: Hlavní serverová logika pro KCD:MP. Spravuje soukromé světy (`30000000 + pid`), vytváří figurínu (`CreateActor`), partnera pro dvojice a nábytek (`CreateProp`). Řídí přehrávání na hercích (`SetActorAnim`) i hráčích (`AddEmote`, `PlayPlayerEmote`).
* **`server/animace_data.lua`**: Předem vygenerovaný katalog a index 6 097 animací pro serverový lookup.
* **`server/animace_config.lua`**: Výchozí nastavení práv, příkazů a časovačů.
* **`client/zz_animace.lua`**: Klientský skript řídící kameru (`SetCamera`, `ResetCamera`) podle vybraného zoom presetu a klientské události.
* **`ui/`**: CEF Webové rozhraní (`ui.toml`, `index.html`, `app.js`, `katalog.js`, `style.css`, `kit/`).
* **`test/`**: Offline testovací sada (`run.py`, `test_animace.lua`, `mock_kcdmp.lua`).
* **`tools/`**: Nástroje pro přegenerování dat z herních archivů a lokální vývojový HTTP server (`ui-dev.mjs`).

---

## Pravidla a zásady pro úpravy

1. **Žádné entity bez virtuálního světa:** Všechny entity figurín, partnerů a rekvizit musí vždy vznikat přímo v soukromém světě `Config.svetBase + pid`. Nikdy nevytvářejte entitu ve světě 0 nebo globálním světě.
2. **Synchronizace dvojic:** Při vytváření partnera pro párové animace vždy dodržujte usazovací prodlevu (`Config.usazeni`, 600 ms). Hra odmítá povely poslané bezprostředně po spawnu herce.
3. **Přednost oprávnění:** Správcovské akce (ukládání předvoleb) musí respektovat jak specifické právo modulu, tak obecné administrátorské oprávnění (`admin`).
4. **Validace testy:** Před každým commitem musí projít testy:
   ```sh
   python test/run.py
   ```
