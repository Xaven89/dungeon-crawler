-- gen/track: remembers what a floor made that is not a voxel (event nodes, emitters, gravity fields, bodies, vehicles, prefabs) so that the floor can be taken away again when the next one is built.
-- The engine's constructors are wrapped once; whatever is made while `scope` is set goes on that scope's list. The authored Orientation floor is the scope "orientation", every generated floor its own.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local K = {}
G.gen.track = K

K.scope = "orientation"
K.lists = {}

local function remember(kind, key)
    if key == nil or key == false then return end
    local l = K.lists[K.scope]
    if not l then l = {}; K.lists[K.scope] = l end
    l[#l + 1] = { kind, key }
end

local function wrap(tbl, fname, kind, key_of)
    local orig = tbl and tbl[fname]
    if not orig then return end
    tbl[fname] = function(...)
        local r = orig(...)
        remember(kind, key_of and key_of(r, ...) or r)
        return r
    end
end

for _, f in ipairs({ "button", "lever", "volume", "lamp", "door", "timer", "logic", "gravity_target", "spawner", "effect" }) do wrap(events, f, "event") end
wrap(gravity, "add", "gravity")
wrap(emitter, "create", "emitter", function(_, def) return type(def) == "table" and def.name or nil end)
wrap(body, "box", "body"); wrap(body, "ball", "body")
wrap(vehicle, "spawn", "vehicle")
wrap(chain, "add", "chain", function(r) return r and r.group end)
wrap(prefab, "place", "prefab")

local remover = {
    event = function(id) events.remove(id) end,
    gravity = function(id) gravity.remove(id) end,
    emitter = function(name) if emitter.find(name) then emitter.remove(name) end end,
    body = function(id) body.remove(id) end,
    vehicle = function(id) vehicle.remove(id) end,
    chain = function(g) chain.remove(g) end,
    prefab = function(id) prefab.remove(id) end,
}

-- takes away everything of a scope; returns how many things there were
function K.teardown(scope)
    local l = K.lists[scope] or {}
    local n = 0
    for i = #l, 1, -1 do
        local e = l[i]
        local f = remover[e[1]]
        if f then pcall(f, e[2]); n = n + 1 end
    end
    K.lists[scope] = nil
    return n
end

function K.count(scope) return #(K.lists[scope] or {}) end
