-- test_animace.lua - Automatizovana testovaci sada pro modul kcdmp-animace
package.path = package.path .. ";server/?.lua;test/?.lua;data/?.lua"

local Mock = require("mock_kcdmp")
local Animace = require("animace")
local AnimaceData = require("animace_data")

local passCount = 0
local failCount = 0

local function assert_eq(actual, expected, msg)
    if actual == expected then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        print(string.format("  FAIL: %s (ocekavano: %s, obdrzeno: %s)", msg, tostring(expected), tostring(actual)))
    end
end

local function assert_true(cond, msg)
    assert_eq(not not cond, true, msg)
end

print("=== SPUSTENI TESTU: kcdmp-animace ===")

-- TEST 1: Inicializace a registrace prikazu
Mock.reset()
Animace.install()
assert_true(Mock.commands["animace"] ~= nil, "Prikaz /animace je zaregistrovan")
assert_true(AnimaceData.total >= 6000, "Katalog obsahuje 6000+ animaci")

-- TEST 2: Kontrola vyhledavani animaci a rekvizit
local rec = AnimaceData.get("Baker_kneeding")
assert_true(rec ~= nil, "Nalezena animace Baker_kneeding")
assert_eq(rec.f, "Baker_kneeding", "Fragment animace sedi")
assert_true(rec.c ~= nil and rec.c ~= "", "Animace ma prirazeny clip pro SetActorAnim")

-- TEST 3: Otevreni session v soukromem virtualnim svete
Mock.players[1] = { x = 100, y = 200, z = 15, yaw = 90, world = 0 }
local ok, err = Animace.open(1)
assert_true(ok, "Session pro hrace 1 uspesne otevrena")
assert_eq(Mock.players[1].world, 30000001, "Hrac byl presunut do soukromeho sveta 30000001")
assert_eq(Mock.players[1].frameShown, "animace", "Web frame animace byl zobrazen")

-- Vyhledat vytvoreneho herce (figurinu)
local mannequin = nil
for _, a in pairs(Mock.actors) do
    if a.name == "Figurina" and a.world == 30000001 then
        mannequin = a
        break
    end
end
assert_true(mannequin ~= nil, "Figurina byla vytvorena v soukromem svete")
assert_true(mannequin.invulnerable, "Figurina je chranena (invulnerable)")

-- Nechame figurinu usadit
Mock.clock = Mock.clock + 1.0
Animace.onTick()

-- TEST 4: Prehrani animace na figurine
Animace.onClientEvent(1, "animace.zadost", { op = "hrat", klic = "Baker_kneeding", loop = true }, "animace")
assert_true(mannequin.anim ~= nil and mannequin.anim ~= "", "Na figurine byla spustena animace")
assert_eq(mannequin.loop, true, "Animace je nastavena na smycku")

-- TEST 5: Zastaveni animace
Animace.onClientEvent(1, "animace.zadost", { op = "zastavit" }, "animace")
assert_eq(mannequin.anim, nil, "Animace na figurine byla zastavena")

-- TEST 6: Dvojice / Parove animace a synchronizace
-- Vybereme parovou animaci (napr. Party_Duo_Standing_Dancing_Loop)
local duo = AnimaceData.get("Party_Duo_Standing_Dancing_Loop|variant_01")
if not duo then
    duo = AnimaceData.get("Loot")
end
assert_true(duo ~= nil, "Parova animace existuje")

Animace.onClientEvent(1, "animace.zadost", { op = "hrat", klic = duo.k or duo.klic, loop = true }, "animace")

-- Zkontrolovat, ze vznikl partner v soukromem svete
local partner = nil
for _, a in pairs(Mock.actors) do
    if a.name == "Partner" and a.world == 30000001 then
        partner = a
        break
    end
end
assert_true(partner ~= nil, "Partner pro dvojici byl vytvoren v soukromem svete")

-- Simulace uplynuti casovace usazeni (600 ms)
Mock.clock = Mock.clock + 0.7
Animace.onTick()
assert_true(mannequin.anim ~= nil, "Figurina hraje po usazeni")
assert_true(partner.anim ~= nil, "Partner hraje synchronne s figurinou po usazeni")

-- TEST 7: Zmena pohlavi figuriny
Animace.onClientEvent(1, "animace.zadost", { op = "pohlavi", pohlavi = "f" }, "animace")
local femaleMannequin = nil
for _, a in pairs(Mock.actors) do
    if a.name == "Figurina" and a.world == 30000001 and a.soul == "townswoman" then
        femaleMannequin = a
        break
    end
end
assert_true(femaleMannequin ~= nil, "Figurina byla zmenena na zenu (townswoman)")

-- TEST 8: Prepnuti na hrace ("telo": "ja")
Animace.onClientEvent(1, "animace.zadost", { op = "telo", telo = "ja" }, "animace")
Animace.onClientEvent(1, "animace.zadost", { op = "hrat", klic = "Baker_kneeding", loop = false }, "animace")
assert_true(Mock.playingEmotes[1] ~= nil, "Emote byl spusten na vlastnim tele hrace")

-- TEST 9: Zavreni nahledu a uklid
Animace.onClientEvent(1, "animace.zadost", { op = "zavrit" }, "animace")
assert_eq(Mock.players[1].world, 0, "Hrac byl vracen do puvodniho sveta 0")
assert_eq(Mock.players[1].frameShown, nil, "Web frame byl schovan")

-- Overeni, ze zadne entity v soukromem svete nezustaly
local entityCount = 0
for _, a in pairs(Mock.actors) do
    if a.world == 30000001 then entityCount = entityCount + 1 end
end
for _, p in pairs(Mock.props) do
    if p.world == 30000001 then entityCount = entityCount + 1 end
end
assert_eq(entityCount, 0, "Vsechny entity v soukromem svete byly radne smazany")

-- TEST 10: Odpojeni hrace (disconnect cleanup)
Mock.players[2] = { x = 0, y = 0, z = 0, yaw = 0, world = 0 }
Animace.open(2)
Animace.onPlayerDisconnect(2, "timeout")
local leftEntities = 0
for _, a in pairs(Mock.actors) do
    if a.world == 30000002 then leftEntities = leftEntities + 1 end
end
assert_eq(leftEntities, 0, "Pri odpojeni hrace byly uklizeny vsechny entity")

-- TEST 11: Zasah hrace (damage) a cooldown
Mock.players[3] = { x = 0, y = 0, z = 0, yaw = 0, world = 0 }
Animace.open(3)
Animace.onPlayerDamage(3, 10, 50)
assert_eq(Mock.players[3].frameShown, nil, "Pri zasahu byl nahled automaticky zavren")
local openOk, openErr = Animace.open(3)
assert_eq(openOk, false, "Po zasahu nelze nahled ihned znovu otevrit (cooldown)")

print(string.format("\n=== VYSLEDEK TESTU: %d USPESNYCH, %d SELHALO ===", passCount, failCount))
if failCount > 0 then
    os.exit(1)
end
