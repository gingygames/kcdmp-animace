-- animace.lua - Herni modul Galerie animaci pro KCD:MP
-- Serverova logika: virtualni svety, figurina, partner, nabytek, prehavani klipu a emotu.
local AnimaceData = require("animace_data")
local Config = require("animace_config")

local Animace = {}
Animace.config = Config
Animace.data = AnimaceData

-- Stav aktivnich relaci: pid -> session table
local sessions = {}
-- Cas posledniho zasahu: pid -> timestamp (os.time)
local lastHit = {}
-- Trvala uloziste
local hlaseni = {}
local predvolby = {}

local function getTime()
    local mock = rawget(_G, "Mock")
    if mock and mock.clock then return mock.clock end
    return os.clock()
end

-- ---------------------------------------------------------------------------
-- Pomocne funkce pro ukladani dat (JSON)
-- ---------------------------------------------------------------------------

local function readJson(path, fallback)
    local f = io.open(path, "r")
    if not f then return fallback end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return fallback end
    local ok, res = pcall(function()
        if type(JsonDecode) == "function" then
            return JsonDecode(content)
        end
        return nil
    end)
    if ok and res then return res end
    return fallback
end

local function writeJson(path, data)
    local encoded = nil
    if type(JsonEncode) == "function" then
        encoded = JsonEncode(data)
    end
    if not encoded then return false end

    -- Ulozeni pres docasny soubor
    local tmpPath = path .. ".tmp"
    local f = io.open(tmpPath, "w")
    if not f then return false end
    f:write(encoded)
    f:close()
    os.remove(path)
    os.rename(tmpPath, path)
    return true
end

local function nacistUloziste()
    hlaseni = readJson(Config.dataDir .. "/hlaseni.json", {})
    predvolby = readJson(Config.dataDir .. "/predvolby.json", {})
end

local function ulozitHlaseni()
    writeJson(Config.dataDir .. "/hlaseni.json", hlaseni)
end

local function ulozitPredvolby()
    writeJson(Config.dataDir .. "/predvolby.json", predvolby)
end

-- ---------------------------------------------------------------------------
-- Overeni prav
-- ---------------------------------------------------------------------------

local function maOpravneni(pid, pravo)
    if not pravo or pravo == "" then return true end
    -- Kontrola admina ze serveru
    if type(IsPlayerAdmin) == "function" and IsPlayerAdmin(pid) then
        return true
    end
    -- Kontrola z mostu/frameworku, pokud je k dispozici
    local most = package.loaded["most"] or package.loaded["kostra"]
    if most and type(most.hasPermission) == "function" then
        return most.hasPermission(pid, pravo) or most.hasPermission(pid, "admin")
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Vypocet pozic v prostoru (CryEngine souradnice)
-- ---------------------------------------------------------------------------

local function smerYaw(yawDeg)
    local rad = math.rad(yawDeg or 0)
    return -math.sin(rad), math.cos(rad)
end

local function posunuteMisto(x, y, z, yawDeg, posun)
    local fx, fy = smerYaw(yawDeg)
    local rx, ry = fy, -fx -- vpravo
    local px = posun.x or 0
    local py = posun.y or 0
    local pz = posun.z or 0
    local pyaw = posun.yaw or 0

    local nx = x + rx * px + fx * py
    local ny = y + ry * px + fy * py
    local nz = z + pz
    local nyaw = (yawDeg + pyaw) % 360
    return nx, ny, nz, nyaw
end

-- ---------------------------------------------------------------------------
-- Sprava session (otevreni, obnova, zavreni)
-- ---------------------------------------------------------------------------

local function uklidSession(pid)
    local s = sessions[pid]
    if not s then return end

    -- Zrusit casovace usazeni
    s.settleTimer = nil

    -- Smazat figurinu a partnera
    if s.mannequinId then
        pcall(DestroyEntity, s.mannequinId)
        s.mannequinId = nil
    end
    if s.partnerId then
        pcall(DestroyEntity, s.partnerId)
        s.partnerId = nil
    end
    if s.furnitureId then
        pcall(DestroyEntity, s.furnitureId)
        s.furnitureId = nil
    end

    -- Zastavit pripadny emote na hraci
    pcall(StopPlayerEmote, pid)

    -- Obnovit puvodni virtualni svet
    if s.origWorld and type(SetPlayerVirtualWorld) == "function" then
        SetPlayerVirtualWorld(pid, s.origWorld)
    end

    -- Schovat web frame a vratit focus
    if type(HidePlayerWebFrame) == "function" then
        HidePlayerWebFrame(pid, "animace")
    end

    -- Informovat klienta o obnoveni kamery
    if type(SendPlayerWebMessage) == "function" then
        SendPlayerWebMessage(pid, "animace", { op = "zavrit" })
    end

    sessions[pid] = nil
end

local function otevritSession(pid, filtrDotaz)
    if not maOpravneni(pid, Config.opravneni) then
        if type(SendClientMessage) == "function" then
            SendClientMessage(pid, 0xFF5555, "Nemas opravneni otevrit galerii animaci.")
        end
        return false, "Nemas opravneni."
    end

    -- Kontrola pauzy po zasahu
    local ted = os.time()
    if lastHit[pid] and (ted - lastHit[pid]) < Config.pauzaPoZasahu then
        local zbyva = Config.pauzaPoZasahu - (ted - lastHit[pid])
        local zpr = string.format("Nedavno jsi utrpel zasah. Nahled muzes otevrit za %d s.", zbyva)
        if type(SendClientMessage) == "function" then
            SendClientMessage(pid, 0xFF5555, zpr)
        end
        return false, zpr
    end

    -- Pokud uz session bezi, nejdriv ji uklidime
    if sessions[pid] then
        uklidSession(pid)
    end

    -- Zjistit polohu hrace
    local px, py, pz, pyaw = 0, 0, 0, 0
    if type(GetPlayerPos) == "function" then
        px, py, pz, pyaw = GetPlayerPos(pid)
    end

    local origWorld = 0
    if type(GetPlayerVirtualWorld) == "function" then
        origWorld = GetPlayerVirtualWorld(pid) or 0
    end

    local privateWorld = Config.svetBase + pid
    if type(SetPlayerVirtualWorld) == "function" then
        SetPlayerVirtualWorld(pid, privateWorld)
    end

    -- Figurina stoji 3.7 m pred hracem, celem k nemu (yaw + 180)
    local fx, fy = smerYaw(pyaw)
    local odstup = 3.7
    local mx = px + fx * odstup
    local my = py + fy * odstup
    local mz = pz
    local myaw = (pyaw + 180) % 360

    -- Vytvorit figurinu
    local soul = Config.figurinaMuz
    local mannequinId = nil
    if type(CreateActor) == "function" then
        mannequinId = CreateActor(soul, mx, my, mz, myaw, "Figurina", nil, "none", privateWorld)
        if mannequinId and type(SetActorInvulnerable) == "function" then
            SetActorInvulnerable(mannequinId, true)
        end
    end

    local s = {
        pid = pid,
        origWorld = origWorld,
        privateWorld = privateWorld,
        px = px, py = py, pz = pz, pyaw = pyaw,
        mx = mx, my = my, mz = mz, myaw = myaw,
        mannequinId = mannequinId,
        partnerId = nil,
        furnitureId = nil,
        telo = "figurina",
        pohlavi = "m",
        obleceni = "moje",
        curAnim = nil,
        loop = false,
        zoom = "postava",
        spawnTime = getTime(),
    }
    sessions[pid] = s

    -- Otevrit web frame
    if type(ShowPlayerWebFrame) == "function" then
        ShowPlayerWebFrame(pid, "animace")
    end
    if type(SetPlayerWebFocus) == "function" then
        SetPlayerWebFocus(pid, "animace", true, true)
    end

    -- Poslat uvodni stav klientovi
    local uvodniInfo = {
        op = "otevrit",
        q = filtrDotaz or "",
        panel = Config.panel,
        stav = {
            telo = s.telo,
            pohlavi = s.pohlavi,
            obleceni = s.obleceni,
            zoom = s.zoom,
            klic = "",
        }
    }
    if type(SendPlayerWebMessage) == "function" then
        SendPlayerWebMessage(pid, "animace", uvodniInfo)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Přehrávání animací a synchronizace dvojic
-- ---------------------------------------------------------------------------

local function zahratNaFigurine(s, animRec, loop)
    if not s or not s.mannequinId then return end
    local clip = animRec.c or animRec.clip or ""
    if clip == "" then
        clip = animRec.f or animRec.fragment or ""
    end

    if type(SetActorAnim) == "function" then
        SetActorAnim(s.mannequinId, clip, loop)
    end
end

local function zahratNaPartnerovi(s, animRec, loop)
    if not s or not s.partnerId then return end
    local partnerKlic = animRec.dv and animRec.dv.klic
    if not partnerKlic then return end

    local partnerRec = AnimaceData.get(partnerKlic)
    if not partnerRec then return end

    local clip = partnerRec.c or partnerRec.clip or ""
    if clip == "" then clip = partnerRec.f or partnerRec.fragment or "" end

    if type(SetActorAnim) == "function" then
        SetActorAnim(s.partnerId, clip, loop)
    end
end

local function nastavitNabytek(s, animRec)
    if not s then return end

    -- Zrusit stavajici nabytek
    if s.furnitureId then
        pcall(DestroyEntity, s.furnitureId)
        s.furnitureId = nil
    end

    local po = animRec.po or animRec.postoj
    if not po or po.na == "zem" then return end

    -- Určit model nábytku
    local mesh = nil
    if po.na == "lavice" then
        mesh = "objects/manmade/civil_furniture/seating/bench_1place_low.cgf"
    elseif po.na == "stul" then
        mesh = "objects/manmade/civil_furniture/seating/bench_1place_low_table.cgf"
    elseif po.na == "zidle" then
        mesh = "objects/manmade/civil_furniture/seating/chair_low.cgf"
    elseif po.na == "postel" or po.na == "lavicePostel" then
        mesh = "objects/manmade/civil_furniture/beds/bed_low.cgf"
    elseif po.na == "stan" then
        mesh = "objects/manmade/military/camp/tent_small.cgf"
    end

    if not mesh then return end

    -- Spocitat posun: sedadlo -0.35m vzad, postel s otocenim 90 stupnu
    local posun = { x = 0, y = -0.35, z = 0, yaw = 0 }
    if po.na == "postel" or po.na == "lavicePostel" then
        posun = { x = 0, y = 0, z = 0, yaw = 90 }
    end

    local bx, by, bz, byaw = posunuteMisto(s.mx, s.my, s.mz, s.myaw, posun)
    if type(CreateProp) == "function" then
        s.furnitureId = CreateProp(mesh, bx, by, bz, byaw, 1.0, false, s.privateWorld)
    end
end

local function zajistitPartnera(s, animRec)
    if not s then return end
    local dv = animRec.dv or animRec.dvojice

    if not dv then
        -- Pokud animace neni parova, partnera uklidime
        if s.partnerId then
            pcall(DestroyEntity, s.partnerId)
            s.partnerId = nil
        end
        return
    end

    -- Vypocet pozice partnera
    local pp = animRec.pp or animRec.posunPartner or { x = 0, y = 0, z = 0, yaw = 0 }
    local px, py, pz, pyaw = posunuteMisto(s.mx, s.my, s.mz, s.myaw, pp)

    if not s.partnerId then
        local pSoul = (s.pohlavi == "m") and Config.figurinaZena or Config.figurinaMuz
        if type(CreateActor) == "function" then
            s.partnerId = CreateActor(pSoul, px, py, pz, pyaw, "Partner", nil, "none", s.privateWorld)
            s.partnerSpawnTime = getTime()
            if s.partnerId and type(SetActorInvulnerable) == "function" then
                SetActorInvulnerable(s.partnerId, true)
            end
        end
    else
        -- Preposition partner if already exists
        if type(SetEntityPos) == "function" then
            SetEntityPos(s.partnerId, px, py, pz, pyaw)
        end
    end
end

local function prehratAnimaci(s, klic, loop)
    if not s then return false, "Relace neexistuje." end
    local animRec = AnimaceData.get(klic)
    if not animRec then return false, "Neznama animace." end

    s.curAnim = animRec
    s.loop = (loop == true)

    -- Nabytek
    nastavitNabytek(s, animRec)

    -- Dvojice
    zajistitPartnera(s, animRec)

    if s.telo == "figurina" then
        -- Vyladeni bugu: Pokud partner nebo figurina vznikli cerstve, pockame 600 ms na usazeni
        -- a pak spustime obe tela v jednom tiku, aby nedoslo k odmitnuti hrou.
        local settleMs = Config.usazeni
        local now = getTime()
        local mElapsed = (now - (s.spawnTime or 0)) * 1000
        local pElapsed = s.partnerSpawnTime and ((now - s.partnerSpawnTime) * 1000) or 999999

        if mElapsed < settleMs or pElapsed < settleMs then
            -- Kratke odlozeni pro synchronni start obou tel
            s.settleTimer = {
                target = now + (settleMs / 1000),
                fn = function()
                    zahratNaFigurine(s, animRec, s.loop)
                    zahratNaPartnerovi(s, animRec, s.loop)
                end
            }
        else
            zahratNaFigurine(s, animRec, s.loop)
            zahratNaPartnerovi(s, animRec, s.loop)
        end
    elseif s.telo == "ja" then
        -- Prehrat na hraci pres AddEmote a PlayPlayerEmote
        local emoteName = "anim_kcdmp_" .. tostring(s.pid)
        local clip = animRec.c or animRec.clip or ""
        local frag = animRec.f or animRec.fragment or ""
        local tags = animRec.t or animRec.tags or ""

        if type(AddEmote) == "function" then
            AddEmote(emoteName, frag, clip, frag, tags, s.loop, {})
        end
        if type(PlayPlayerEmote) == "function" then
            PlayPlayerEmote(s.pid, emoteName)
        end
    end

    -- Odeslat stav do Web UI
    if type(SendPlayerWebMessage) == "function" then
        SendPlayerWebMessage(s.pid, "animace", {
            op = "stav",
            klic = klic,
            fragment = animRec.f or animRec.fragment,
            loop = s.loop,
            props = animRec.pr or animRec.props or {},
            partner = s.partnerId ~= nil,
        })
    end

    return true
end

local function zastavitAnimaci(s)
    if not s then return end
    if s.telo == "figurina" then
        if s.mannequinId and type(SetActorAnim) == "function" then
            SetActorAnim(s.mannequinId, nil, false)
        end
        if s.partnerId and type(SetActorAnim) == "function" then
            SetActorAnim(s.partnerId, nil, false)
        end
    elseif s.telo == "ja" then
        if type(StopPlayerEmote) == "function" then
            StopPlayerEmote(s.pid)
        end
    end

    if type(SendPlayerWebMessage) == "function" then
        SendPlayerWebMessage(s.pid, "animace", {
            op = "stav",
            klic = "",
            loop = false,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Zpracovani pozadavku z Web UI
-- ---------------------------------------------------------------------------

function Animace.onClientEvent(pid, name, payload, source)
    if source ~= "animace" and name ~= "animace.zadost" then
        return
    end

    local s = sessions[pid]
    local op = payload and payload.op
    local rid = payload and payload.rid

    local function odpoved(ok, data, chyba)
        local res = data or {}
        res.rid = rid
        res.ok = ok
        if chyba then res.chyba = chyba end
        if type(SendPlayerWebMessage) == "function" then
            SendPlayerWebMessage(pid, "animace", { op = "vysledek", vysledek = res })
        end
    end

    if op == "zavrit" then
        uklidSession(pid)
        return
    end

    if not s then
        odpoved(false, nil, "Relace neni otevrena.")
        return
    end

    if op == "hrat" then
        local klic = payload.klic
        local loop = payload.loop == true
        local ok, err = prehratAnimaci(s, klic, loop)
        odpoved(ok, nil, err)

    elseif op == "zastavit" then
        zastavitAnimaci(s)
        odpoved(true)

    elseif op == "telo" then
        s.telo = (payload.telo == "ja") and "ja" or "figurina"
        zastavitAnimaci(s)
        odpoved(true, { telo = s.telo })

    elseif op == "pohlavi" then
        local pohl = (payload.pohlavi == "f") and "f" or "m"
        s.pohlavi = pohl
        -- Zmenit soula figuriny
        if s.mannequinId then
            pcall(DestroyEntity, s.mannequinId)
            local soul = (pohl == "f") and Config.figurinaZena or Config.figurinaMuz
            if type(CreateActor) == "function" then
                s.mannequinId = CreateActor(soul, s.mx, s.my, s.mz, s.myaw, "Figurina", nil, "none", s.privateWorld)
                s.spawnTime = os.clock()
            end
        end
        if s.curAnim then
            prehratAnimaci(s, s.curAnim.k or s.curAnim.klic, s.loop)
        end
        odpoved(true, { pohlavi = s.pohlavi })

    elseif op == "zoom" then
        s.zoom = payload.zoom or "postava"
        odpoved(true, { zoom = s.zoom })

    elseif op == "otocit" then
        local uhel = tonumber(payload.uhel) or 30
        s.myaw = (s.myaw + uhel) % 360
        if s.mannequinId and type(TurnActor) == "function" then
            TurnActor(s.mannequinId, s.myaw)
        end
        odpoved(true, { yaw = s.myaw })

    elseif op == "hlasit" then
        local klic = payload.klic
        local stav = payload.stav -- "nefunguje" | "ok"
        local pozn = tostring(payload.pozn or ""):sub(1, 300)
        local hRec = {
            klic = klic,
            pohlavi = s.pohlavi,
            stav = stav,
            pozn = pozn,
            kdo = type(GetPlayerName) == "function" and GetPlayerName(pid) or tostring(pid),
            kdoId = tostring(pid),
            telo = s.telo,
            kdy = os.time(),
        }
        hlaseni[#hlaseni + 1] = hRec
        ulozitHlaseni()
        odpoved(true, { zprava = "Hlaseni bylo ulozeno." })

    elseif op == "ulozitPredvolbu" then
        if not maOpravneni(pid, Config.opravneniSpravce) then
            odpoved(false, nil, "Nemas prava spravce.")
            return
        end
        local klic = payload.klic
        predvolby[klic] = {
            props = payload.props,
            nabytek = payload.nabytek,
            posun = payload.posun,
            posunPartner = payload.posunPartner,
            kdo = type(GetPlayerName) == "function" and GetPlayerName(pid) or tostring(pid),
            kdy = os.time(),
        }
        ulozitPredvolby()
        odpoved(true, { zprava = "Predvolba byla ulozena pro vsechny hrace." })

    else
        odpoved(false, nil, "Neznama operace.")
    end
end

-- ---------------------------------------------------------------------------
-- KCD:MP Callbacky
-- ---------------------------------------------------------------------------

function Animace.onTick()
    -- Vyrizovani casovacu usazeni
    local now = getTime()
    for _, s in pairs(sessions) do
        if s.settleTimer and now >= s.settleTimer.target then
            local fn = s.settleTimer.fn
            s.settleTimer = nil
            if fn then fn() end
        end
    end
end

function Animace.onPlayerDisconnect(pid, reason)
    uklidSession(pid)
    lastHit[pid] = nil
end

function Animace.onPlayerDeath(pid, killer)
    uklidSession(pid)
end

function Animace.onPlayerDamage(pid, attacker, damage)
    lastHit[pid] = os.time()
    if Config.zavritPriZasahu and sessions[pid] then
        uklidSession(pid)
        if type(SendClientMessage) == "function" then
            SendClientMessage(pid, 0xFF5555, "Nahled animaci byl zavren kvuli zasahu.")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Inicializace a registrace modulu
-- ---------------------------------------------------------------------------

function Animace.install()
    nacistUloziste()

    if type(RegisterCommand) == "function" then
        RegisterCommand(Config.prikaz, function(pid, args)
            local arg1 = args and args[1]
            if arg1 == "zavrit" then
                uklidSession(pid)
            elseif arg1 == "hlaseni" then
                if type(SendClientMessage) == "function" then
                    SendClientMessage(pid, 0x55FF55, "--- Nahlásené nefunkcní animace ---")
                    for i, h in ipairs(hlaseni) do
                        if i > 10 then break end
                        SendClientMessage(pid, 0xAAAAAA, string.format("[%s] %s (%s)", h.pohlavi, h.klic, h.pozn))
                    end
                end
            else
                otevritSession(pid, arg1)
            end
        end, { help = "Otevrit galerii animaci hry (/animace [filtr | zavrit | hlaseni])" })
    end

    print("[animace] Modul uspesne nainstalovan pro KCD:MP.")
end

Animace.open = otevritSession
Animace.close = uklidSession

return Animace
