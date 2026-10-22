-- Creature test (docs/ANIMATION.md): the six sample creatures of tools/make_creatures.py.
--   Unfriendly: the slime hops after the player and lunges, the skeleton and the goblin follow and swing when they are within reach (their "attack" clip; its "hit" event is where a game would take health).
--   Friendly: the deer and the chicken wander; the rabbit bolts away when the player comes within 4 m and settles again when they are far.
-- Hostility is this script's: the engine has follow, wander and walk, and clips with events (docs/AGENTS.md "Limits").
local V = 16
local function m(vox) return vox / V end
local function dist(ax, az, bx, bz) local dx, dz = ax - bx, az - bz; return math.sqrt(dx * dx + dz * dz) end

local hostile = {}   -- id -> { name, model, reach, cooldown }
local friendly = {}  -- id -> { name, model, flee }
local rabbit

local function spawn(name, dx, dz, speed, extra)
    local px, py, pz = player.pos()
    local x, z = px + dx, pz + dz
    local gy = world.top(math.floor(x * V), math.floor(z * V))
    local id = agent.spawn{ x = x, y = m(gy + 1), z = z, speed = speed, model = "models/" .. name .. ".vxm", creature = name }
    local mdl = id - 0x40000000
    if extra then model.procedural(mdl, extra) end
    return id, mdl
end

function on_start()
    local id, mdl
    id, mdl = spawn("slime", 6, 8, 1.4)
    hostile[id] = { name = "slime", model = mdl, reach = 1.4, cooldown = 0 }
    id, mdl = spawn("skeleton", -6, 9, 1.5)
    hostile[id] = { name = "skeleton", model = mdl, reach = 1.8, cooldown = 0 }
    id, mdl = spawn("goblin", 0, 12, 1.8)
    hostile[id] = { name = "goblin", model = mdl, reach = 1.8, cooldown = 0 }
    for aid, h in pairs(hostile) do agent.follow(aid, h.reach * 0.8) end
    id, mdl = spawn("deer", 10, -6, 1.3)
    friendly[id] = { name = "deer", model = mdl }
    agent.wander(id, 10)
    id, mdl = spawn("chicken", -8, -4, 0.8)
    friendly[id] = { name = "chicken", model = mdl }
    agent.wander(id, 3)
    rabbit, mdl = spawn("rabbit", 4, -5, 2.6)
    friendly[rabbit] = { name = "rabbit", model = mdl, flee = false }
    agent.wander(rabbit, 5)
    print("creature test: a slime, a skeleton and a goblin come for you; a deer, a chicken and a rabbit live here")
end

local ticks = 0
function on_tick()
    ticks = ticks + 1
    if ticks % 10 ~= 0 then return end
    local px, py, pz = player.pos()
    for id, h in pairs(hostile) do
        local i = agent.info(id)
        if i then
            if h.cooldown > 0 then h.cooldown = h.cooldown - 10 end
            if h.cooldown <= 0 and dist(i.x, i.z, px, pz) < h.reach then
                model.play(h.model, "attack", 1, false, 3)
                h.cooldown = 90
            end
        end
    end
    local r = friendly[rabbit]
    local i = agent.info(rabbit)
    if r and i then
        local d = dist(i.x, i.z, px, pz)
        if d < 4 and not r.flee then
            r.flee = true
            local dx, dz = i.x - px, i.z - pz
            local n = math.max(d, 0.1)
            local tx, tz = i.x + dx / n * 10, i.z + dz / n * 10
            local gy = world.top(math.floor(tx * V), math.floor(tz * V))
            agent.walk(rabbit, tx, m(gy + 1), tz)
        elseif d > 8 and r.flee then
            r.flee = false
            agent.wander(rabbit, 5)
        end
    end
end

function on_agent(id, what)
    if id == rabbit and (what == "arrived" or what == "stuck" or what == "no_path") then
        local r = friendly[rabbit]
        if r and r.flee then r.flee = false; agent.wander(rabbit, 5) end
    end
end

function on_anim(model, event, clip)
    for id, h in pairs(hostile) do
        if h.model == model and event == "hit" then
            local i = agent.info(id)
            local px, py, pz = player.pos()
            if i and dist(i.x, i.z, px, pz) < h.reach + 0.4 then print("the " .. h.name .. " hits you") end
        end
    end
end
