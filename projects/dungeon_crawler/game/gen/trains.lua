-- gen/trains: the cars of the Iron Tangle (floor 4): one `events.train` per line (gen/transit.lua `transit_lines`), a flat deck 14 x 3.6 m that lies in the track bed flush with the platforms. The node moves
-- the body; the player standing on it is carried (R1), the game puts the commuters on and takes them off at the stops (T4).
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local T = {}
G.gen.trains = T
local floor = math.floor

T.cars = {}                  -- line name -> { id, body, line }
T.pending_reset = false
local DECK = { red = "carpet", yellow = "gold", orange = "cinderblock", green = "mossy", blue = "obsidian", violet = "rune" }

-- the cars of the floor (made when the floor is entered or loaded, in the floor's scope: taken away with it)
function T.enter(P)
    T.cars, T.riders = {}, {}
    local car = transit_const().car
    for _, line in ipairs(transit_lines()) do
        local pts = {}
        for i, p in ipairs(line.points) do pts[i] = { G.wx(p[1]), G.wy(line.level * transit_const().level_m), G.wz(p[2]) } end
        local id = events.train{ name = "iron_" .. line.name, model = "models/train_car_" .. line.name .. ".vxm", deck = 4,                 -- (the artist's railed car: voxel-exact, hollow, the deck 4 layers, 58 x 54 x 224 voxels)
                                 track = pts, closed = line.closed, speed = line.speed, accel = car.accel, stops = line.stops, end_seconds = 20, start_on = true }
        T.cars[line.name] = { id = id, body = events.train_body(id), line = line }
        events.on(id, "arrived", function(e) T.on_stopped(line.name, e) end)       -- (the pulse that comes with the stop: e.stop is its number)
        events.on(id, "departing", function(e) T.on_departing(line.name, e) end)
    end
    T.pending_reset = true
end

-- every car starts over at its first stop when the player can act (the veil and the contract screen are over): the first lap begins with the Red car standing at HUB S
function T.tick(t)
    if t % 60 == 0 then T.sweep(t) end
    if T.pending_reset and G.state.class and not G.screen and not G.player.dead then
        T.pending_reset = false
        for _, c in pairs(T.cars) do events.command(c.id, "reset") end
    end
end

-- ---------------------------------------------------------------------------------------------- the commuters
-- Monsters of a station's crowd (the enemies of its room) board the car where it stops and get off where it stops next: at the `stopped` edge ONLY, never polled. A rider is an ordinary enemy
-- (E.list) that the engine carries (agent.ride): it stands on a fixed slot of the deck and fights in world space. Getting off: the rider is removed and an ordinary enemy of its kind is spawned on a
-- platform spot of the destination station (when that cell is alive), because an agent that was unridden stands on the deck and the departing car would leave it in the bed.
local SLOTS = {}
for k = 0, 6 do for _, sx in ipairs({ -0.9, 0.9 }) do SLOTS[#SLOTS + 1] = { sx, 0.15, -4.5 + k * 1.5 } end end       -- 14 slots: 2 across, 7 along (the middle of the deck is z = 0; the deck is 14 x 3.6 m: 0.5 m clear at the ends)
T.riders = {}                -- line name -> { { inst, dest = cell id } }
T.BOARD_RANGE = 8               -- metres from the middle of the deck (the car is 14 m long: the crowd stands 3 m either side of the middle)

local function cell_of(x, z) return "c" .. floor(x / 32) .. "_" .. floor(z / 32) end
local function station_of(line, stop) local p = line.points[line.stops[stop][1]]; return p and cell_of(p[1], p[2]) end

function T.on_stopped(name, e)
    if T.dbg then print('DBG arrived', name, e.stop, e.moving) end
    local c = T.cars[name]
    if not c or not G.floorgen.layout or G.floorgen.layout.floor ~= 4 then return end
    local line = c.line
    local here = station_of(line, e.stop)
    if not here then return end
    local E = G.enemies
    local P = G.floorgen.layout
    local riders = T.riders[name] or {}
    T.riders[name] = riders
    -- 1. the riders whose station this is: they get off
    local stay = {}
    for _, r in ipairs(riders) do
        local inst = r.inst
        if inst.dead or not E.list[inst.id] then
            -- gone already
        elseif r.dest == here then
            local kind, hp_mult = inst.kind, inst.hp / inst.max_hp
            pcall(agent.remove, inst.id); E.list[inst.id] = nil; E.by_model[inst.mdl] = nil
            local room = P.rooms[here]
            if room and G.floorgen.made[here] then
                local lay, rects, spots = G.floorgen.furnished(room, { floor = 4, mk = function(rm) return function(salt) return deco_rng(select(2, G.floorgen.cg()), 4, rm.ci, rm.cj, salt or 1) end end })
                local ox, oz = G.floorgen.off(room)
                local sp = spots and spots[1 + (#riders + inst.id) % math.max(1, #spots)]
                local x, z = sp and sp.x or (room.x + 10), sp and sp.z or (room.z + 8)
                local n = E.spawn(kind, x, room.info.room.y or 0, z, { room = here, hp_mult = 1 })
                if n then n.commuter = true end
            end
        else stay[#stay + 1] = r end
    end
    T.riders[name] = stay
    riders = stay
    -- 2. those of this station's crowd within 6 m of the deck board (sorted by id; the slots in that order)
    local bx, by, bz = T.where(name)
    if not bx then return end
    local lx, _, lz = G.to_local(bx, by, bz)
    local dest
    if line.closed then dest = station_of(line, e.stop % #line.stops + 1)
    else dest = station_of(line, (e.stop == 1) and #line.stops or 1) end
    local cand = {}
    for id, inst in pairs(E.list) do
        if inst.room == here and not inst.dead and not inst.captive and not inst.T.boss and not inst.riding then
            local x, y, z = E.position(inst)
            if x and G.dist2(x, z, bx, bz) <= T.BOARD_RANGE and math.abs(y - by) < 1.2 then cand[#cand + 1] = inst end
        end
    end
    table.sort(cand, function(a, b) return a.id < b.id end)
    if T.dbg then local d = {}; for id, inst in pairs(E.list) do if inst.room == here then local x, y, z = E.position(inst); d[#d + 1] = string.format('%d:%s %.1f %.1f', id % 1000, inst.kind, x and G.dist2(x, z, bx, bz) or -1, x and (y - by) or -1) end end; print('DBG stop', name, e.stop, here, 'cand', #cand, 'deck', bx, by, bz, table.concat(d, ' ')) end
    local used = {}
    for _, r in ipairs(riders) do used[r.slot] = true end
    for _, inst in ipairs(cand) do
        local slot
        for k = 1, #SLOTS do if not used[k] then slot = k; break end end
        if not slot then break end
        local o = SLOTS[slot]
        if agent.ride(inst.id, c.body, { o[1], o[2], o[3] }) then
            used[slot] = true
            inst.riding = name
            riders[#riders + 1] = { inst = inst, dest = dest, slot = slot }
        end
    end
end

function T.on_departing(name, e) end

-- the riders of a car the player is far from are let go (the cells around the car are not alive: nobody sees it)
function T.sweep(t)
    local px, py, pz = player.pos()
    for name, list in pairs(T.riders) do
        local bx, by, bz = T.where(name)
        if bx and G.dist2(px, pz, bx, bz) > 100 then
            for _, r in ipairs(list) do
                if G.enemies.list[r.inst.id] then pcall(agent.remove, r.inst.id); G.enemies.list[r.inst.id] = nil; G.enemies.by_model[r.inst.mdl] = nil end
            end
            T.riders[name] = {}
        end
    end
end

-- where a car is (world metres of the middle of its deck) or nil
function T.where(name)
    local c = T.cars[name]
    if not c then return nil end
    local x, y, z, ok = body.pos(c.body)
    if not ok then return nil end
    return x, y, z
end
