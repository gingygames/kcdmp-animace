-- mock_kcdmp.lua - Mockovaci vrstva pro KCD:MP API pro testovani modulu Animace bez hry
local Mock = {}
_G.Mock = Mock

Mock.actors = {}
Mock.props = {}
Mock.players = {}
Mock.webMessages = {}
Mock.commands = {}
Mock.emotes = {}
Mock.playingEmotes = {}
Mock.nextEntityId = 100
Mock.clock = 1000.0

function Mock.reset()
    Mock.actors = {}
    Mock.props = {}
    Mock.players = {}
    Mock.webMessages = {}
    Mock.commands = {}
    Mock.emotes = {}
    Mock.playingEmotes = {}
    Mock.nextEntityId = 100
    Mock.clock = 1000.0
end

-- Globální KCD:MP funkce pro serverové skripty

function CreateActor(soul, x, y, z, yaw, name, clothing, weapons, world)
    local id = Mock.nextEntityId
    Mock.nextEntityId = Mock.nextEntityId + 1
    Mock.actors[id] = {
        id = id,
        soul = soul,
        x = x, y = y, z = z, yaw = yaw,
        name = name,
        clothing = clothing,
        weapons = weapons,
        world = world,
        anim = nil,
        loop = false,
        invulnerable = false,
    }
    return id
end

function DestroyEntity(id)
    if Mock.actors[id] then
        Mock.actors[id] = nil
        return true
    end
    if Mock.props[id] then
        Mock.props[id] = nil
        return true
    end
    return false
end

function SetActorAnim(id, clip, loop)
    local a = Mock.actors[id]
    if a then
        a.anim = clip
        a.loop = (loop == true)
        return true
    end
    return false
end

function SetActorInvulnerable(id, inv)
    local a = Mock.actors[id]
    if a then
        a.invulnerable = inv
        return true
    end
    return false
end

function TurnActor(id, yaw)
    local a = Mock.actors[id]
    if a then
        a.yaw = yaw
        return true
    end
    return false
end

function CreateProp(mesh, x, y, z, yaw, scale, rigid, world)
    local id = Mock.nextEntityId
    Mock.nextEntityId = Mock.nextEntityId + 1
    Mock.props[id] = {
        id = id,
        mesh = mesh,
        x = x, y = y, z = z, yaw = yaw,
        scale = scale,
        rigid = rigid,
        world = world
    }
    return id
end

function GetPlayerPos(pid)
    local p = Mock.players[pid] or { x = 0, y = 0, z = 0, yaw = 0 }
    return p.x, p.y, p.z, p.yaw
end

function GetPlayerVirtualWorld(pid)
    local p = Mock.players[pid]
    return p and p.world or 0
end

function SetPlayerVirtualWorld(pid, world)
    if not Mock.players[pid] then
        Mock.players[pid] = { x = 0, y = 0, z = 0, yaw = 0, world = 0 }
    end
    Mock.players[pid].world = world
    return true
end

function ShowPlayerWebFrame(pid, frame)
    if not Mock.players[pid] then Mock.players[pid] = {} end
    Mock.players[pid].frameShown = frame
end

function HidePlayerWebFrame(pid, frame)
    if Mock.players[pid] and Mock.players[pid].frameShown == frame then
        Mock.players[pid].frameShown = nil
    end
end

function SetPlayerWebFocus(pid, frame, kbd, mouse)
    if Mock.players[pid] then
        Mock.players[pid].focus = { frame = frame, kbd = kbd, mouse = mouse }
    end
end

function SendPlayerWebMessage(pid, frame, msg)
    table.insert(Mock.webMessages, { pid = pid, frame = frame, msg = msg })
end

function RegisterCommand(cmd, fn, opts)
    Mock.commands[cmd] = { fn = fn, opts = opts }
end

function IsPlayerAdmin(pid)
    return pid == 1 or pid == 999
end

function GetPlayerName(pid)
    return "Player_" .. tostring(pid)
end

function AddEmote(name, label, clip, fragment, tags, loop, opts)
    Mock.emotes[name] = { label = label, clip = clip, fragment = fragment, tags = tags, loop = loop, opts = opts }
    return true
end

function PlayPlayerEmote(pid, name)
    Mock.playingEmotes[pid] = name
    return true
end

function StopPlayerEmote(pid)
    if Mock.playingEmotes[pid] then
        Mock.playingEmotes[pid] = nil
        return true
    end
    return false
end

function SendClientMessage(pid, color, text)
    -- Mock chat log
end

-- Jednoducha serializace JSON pro mockovani
function JsonEncode(t)
    local function serialize(o)
        local t_o = type(o)
        if t_o == "number" or t_o == "boolean" then
            return tostring(o)
        elseif t_o == "string" then
            return string.format("%q", o)
        elseif t_o == "table" then
            local is_list = true
            local n = 0
            for k, _ in pairs(o) do
                n = n + 1
                if type(k) ~= "number" then is_list = false end
            end
            local parts = {}
            if is_list then
                for i = 1, #o do
                    table.insert(parts, serialize(o[i]))
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                for k, v in pairs(o) do
                    table.insert(parts, string.format("%q:%s", tostring(k), serialize(v)))
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
        return "null"
    end
    return serialize(t)
end

function JsonDecode(s)
    -- Mockovaci parser
    return {}
end

return Mock
