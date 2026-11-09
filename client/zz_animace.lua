-- zz_animace.lua - Klientsky skript galerie animaci pro KCD:MP
-- Ridi nastaveni kamery (SetCamera), zoom presety, rotaci a obnoveni puvodniho pohledu.

local camActive = false
local currentZoom = "postava"

-- Predvolby kamery: { vyskaKoukani, vzdalenost, vyskaKamery, fov }
local ZOOM = {
    postava = { 0.95, 3.0, 1.3, 48 },
    horni   = { 1.30, 1.8, 1.5, 40 },
    ruce    = { 1.15, 1.25, 1.35, 40 },
    hlava   = { 1.62, 0.95, 1.66, 30 },
    shora   = { 0.50, 2.6, 2.6, 50 },
}

local function nastavKameru(zoomKey, ms)
    local z = ZOOM[zoomKey] or ZOOM.postava
    local lookHeight = z[1]
    local dist = z[2]
    local camHeight = z[3]
    local fov = z[4]

    -- Ziskat pozici hrace
    local px, py, pz, pyaw = 0, 0, 0, 0
    if type(GetPlayerPos) == "function" then
        px, py, pz, pyaw = GetPlayerPos()
    end

    -- Figurina stoji 3.7 m pred hracem:
    local rad = math.rad(pyaw or 0)
    local fx, fy = -math.sin(rad), math.cos(rad)
    local rx, ry = fy, -fx

    local mx = px + fx * 3.7
    local my = py + fy * 3.7
    local mz = pz

    -- Kamera se diva na figurinu (s mirnym posunem vpravo, aby vlevo byl prostor pro UI panel)
    local panelShift = 0.55 * dist * math.tan(math.rad(fov / 2))
    local lx = mx - rx * panelShift
    local ly = my - ry * panelShift
    local lz = mz + lookHeight

    -- Kamera stoji pred figurinou (blize k hraci)
    local cx = mx + fx * dist
    local cy = my + fy * dist
    local cz = mz + camHeight

    if type(SetCamera) == "function" then
        SetCamera(cx, cy, cz, lx, ly, lz, ms or 300, fov)
        camActive = true
    end
end

local function obnovitKameru(ms)
    if camActive and type(ResetCamera) == "function" then
        ResetCamera(ms or 300)
        camActive = false
    end
end

-- ---------------------------------------------------------------------------
-- Zpracovani zprav z weboveho rozhrani a serveru
-- ---------------------------------------------------------------------------

function OnWebEvent(frame, name, data)
    if frame ~= "animace" then return end

    if name == "animace:otevrit" then
        currentZoom = (data and data.stav and data.stav.zoom) or "postava"
        nastavKameru(currentZoom, 400)
    elseif name == "animace:zavrit" then
        obnovitKameru(300)
    elseif name == "animace:zoom" then
        if data and data.zoom then
            currentZoom = data.zoom
            nastavKameru(currentZoom, 250)
        end
    end
end

function OnServerEvent(name, payload)
    if name == "animace:otevrit" then
        nastavKameru("postava", 400)
    elseif name == "animace:zavrit" then
        obnovitKameru(300)
    end
end

-- ---------------------------------------------------------------------------
-- Klavesova zkratka pro otevreni/zavreni
-- ---------------------------------------------------------------------------

function OnKeyBinding(name, pressed)
    if name == "animace.otevrit" and pressed then
        if camActive then
            SendServerEvent("animace.zadost", { op = "zavrit" })
            obnovitKameru(300)
        else
            SendServerEvent("animace.zadost", { op = "otevrit" })
        end
    end
end
