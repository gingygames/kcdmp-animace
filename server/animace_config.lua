-- animace_config.lua - Konfigurace modulu Animace pro KCD:MP
local Config = {
    -- Chat prikaz pro otevreni panelu (napr. "/animace")
    prikaz = "animace",

    -- Kdo smi otevrit nahled a vypisovat hlaseni.
    -- "" = vsichni hraci. Jinak pravo modulu ("animace.otevrit") nebo spravce ("admin").
    opravneni = "animace.otevrit",

    -- Kdo smi ukladat predvolby a mazat cizi hlaseni.
    -- Pravo modulu ("animace.admin") nebo spravce ("admin").
    opravneniSpravce = "animace.admin",

    -- Vychozi soul figuriny pro muze a zenu
    figurinaMuz = "townsman",
    figurinaZena = "townswoman",

    -- Sirka panelu na obrazovce (0.55 = 55% zleva)
    panel = 0.55,

    -- Zakladni cislo pro soukrome virtualni svety (svet = svetBase + pid)
    -- Bezpecny rozsah mimo satnik (900000) a prichod (7000)
    svetBase = 30000000,

    -- Doba usazeni (ms) cerstve vytvoreneho herce pred prvni animaci.
    -- Zamezuje odmitnuti animace hrou v tiku spawnu (vyladeno na 600 ms).
    usazeni = 600,

    -- Zavrit nahled pri zasahu hrace (damage)
    zavritPriZasahu = true,

    -- Pauza po zasahu (s), behem ktere nelze nahled znovu otevrit
    pauzaPoZasahu = 20,

    -- Slozka pro trvala data (hlaseni, predvolby)
    dataDir = "data/animace",
}

return Config
