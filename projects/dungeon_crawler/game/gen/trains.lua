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
    for _, old in pairs(T.cars or {}) do if type(old.run) == "number" then pcall(sound.stop, old.run, 0.2) end end          -- (the loops of the last floor 4)
    if T.ride_h then if type(T.ride_h) == "number" then pcall(sound.stop, T.ride_h, 0.2) end; T.ride_h = nil end
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
    T.sound_tick(t)
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
for k = 0, 6 do for _, sx in ipairs({ -0.9, 0.9 }) do SLOTS[#SLOTS + 1] = { sx, -0.36, -4.5 + k * 1.5 } end end       -- 14 slots: 2 across, 7 along (the middle of the deck is z = 0; the deck is 14 x 3.6 m: 0.5 m clear at the ends)
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
    c.brake_armed = false
    -- the chimes (voxel-audio): 2D, only for a player in that station's cell; the departure chime 150 ticks before the car leaves
    local function in_station()
        local px, py, pz = player.pos()
        local lx, _, lz = G.to_local(px, py, pz)
        return lx and cell_of(lx, lz) == here
    end
    if in_station() then G.sfx.play("tr_chime_arrive") end
    after(math.max(1, line.stops[e.stop][2] * 60 - 150), function() if G.floorgen.layout and G.floorgen.layout.floor == 4 and in_station() then G.sfx.play("tr_chime_depart") end end)
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
        if (inst.room == here or inst.walker_to == here) and not inst.dead and not inst.captive and not inst.T.boss and not inst.riding then
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
            inst.riding = name; inst.walker_to = nil
            riders[#riders + 1] = { inst = inst, dest = dest, slot = slot }
        end
    end
    -- 3. when the car has gone, the den's walkers come to this platform
    after(line.stops[e.stop][2] * 60 + 30, function() T.send_walkers(here) end)
end

-- DEN WALKERS: the monsters of a den that has a door to a station walk to the platform after the car has left it (the stop's seconds + half a second), stand at the crowd's places and board at the next `arrived` like the crowd
-- (BOARD_RANGE); two at most per departure, the lowest ids, no boss, no captive. The walk is the agent's own (agent.walk): deterministic, only while the den and the station are alive.
T.WALKERS = 2
function T.send_walkers(here)
    local P = G.floorgen.layout
    if not P or P.floor ~= 4 then return end
    local room = P.rooms[here]
    if not room or not G.floorgen.made[here] then return end
    local info, E = room.info, G.enemies
    local dens = {}
    for _, side in ipairs({ "N", "S", "E", "W" }) do
        if info.open[side] == "service" then
            local d = ({ N = { 0, -1 }, S = { 0, 1 }, E = { 1, 0 }, W = { -1, 0 } })[side]
            local id = "c" .. (info.ci + d[1]) .. "_" .. (info.cj + d[2])
            local nb = P.rooms[id]
            if nb and nb.info.code == "d" and G.floorgen.made[id] then dens[#dens + 1] = id end
        end
    end
    if #dens == 0 then return end
    local ox, oz = G.floorgen.off(room)
    local spots = transit_crowd_spots(info)
    local n = 0
    for _, den in ipairs(dens) do
        local cand = {}
        for _, inst in pairs(E.list) do
            if inst.room == den and not inst.dead and not inst.captive and not inst.T.boss and not inst.riding and not inst.walker_to then cand[#cand + 1] = inst end
        end
        table.sort(cand, function(a, b) return a.id < b.id end)
        for _, inst in ipairs(cand) do
            if n >= T.WALKERS then break end
            n = n + 1
            local sp = spots[1 + (n - 1) % #spots]
            if pcall(agent.walk, inst.id, G.mx(ox + sp.x), G.my(room.info.room.y or 0), G.mz(oz + sp.z)) then inst.walker_to = here end
        end
    end
end

function T.on_departing(name, e)
    local c = T.cars[name]
    if not c then return end
    c.brake_armed = false
    if c.near then pcall(sound.play, { file = "sounds/tr_depart.wav", at = { body = c.body }, bus = "sfx" }); G.sfx.logline("tr_depart", "sfx", 1, 1, true) end
end

-- ---------------------------------------------------------------------------------------------- sounds (voxel-audio, step 2a): cosmetic, nothing here touches the simulation
-- The car's own sounds follow its body (E25): one running loop per car near the player (volume and pitch by its speed), a clack every 6 m, the brake when it starts to slow, the departure; and the
-- ride loop (2D) while the player stands on a moving deck. The speed is the car's own movement per tick (T.where), smoothed.
local SND_RANGE = 60
local CLACKS = { "tr_clack", "tr_clack_2", "tr_clack_3", "tr_clack_4" }
local function sfx_at(c, file, pitch)
    pcall(sound.play, { file = "sounds/" .. file .. ".wav", at = { body = c.body }, bus = "sfx", pitch = pitch or 1 })
    G.sfx.logline(file, "sfx", 1, pitch or 1, true)
end
function T.sound_tick(t)
    if not T.cars or not G.state or not G.state.class or G.screen then return end
    if not G.floorgen.layout or G.floorgen.layout.floor ~= 4 then
        if T.ride_h then if type(T.ride_h) == "number" then pcall(sound.stop, T.ride_h, 0.5) end; T.ride_h = nil end
        return
    end
    local px, py, pz = player.pos()
    local deck, deck_v = nil, 0
    for name, c in pairs(T.cars) do
        local x, y, z = T.where(name)
        if x then
            local last = c.last
            if last then
                local dx, dz = x - last[1], z - last[2]
                local step = math.sqrt(dx * dx + dz * dz)
                c.v = (c.v or 0) * 0.85 + (step * 60) * 0.15
                c.travel = (c.travel or 0) + step
                if step > 0.005 then c.dir = { dx / step, dz / step } end
            end
            c.last = { x, z }
            local v = c.v or 0
            local d2 = G.dist2(px, pz, x, z)
            c.near = d2 < SND_RANGE
            -- the running loop: on a body, silent until the speed raises it
            if c.near and not c.run then
                c.run = sound.play{ file = "sounds/tr_run_loop.wav", loop = true, bus = "sfx", at = { body = c.body }, volume = 0 } or true          -- (true: no sound card / sink, a session without audio-out gets no handle and must not start it again every tick)
                G.sfx.logline("tr_run_loop", "sfx", 0, 1, true)
            elseif not c.near and c.run and d2 > SND_RANGE + 10 then
                if type(c.run) == "number" then pcall(sound.stop, c.run, 0.5) end; c.run = nil
            end
            if type(c.run) == "number" and t % 15 == 0 then
                local f = math.min(1, v / 5)
                pcall(sound.volume, c.run, f, 0.25); pcall(sound.pitch, c.run, 0.75 + 0.25 * f, 0.25)
            end
            if c.near then
                -- rail joints every 6 m while it moves at speed
                if v > 1.5 and (c.travel or 0) - (c.next_clack or 0) >= 6 then
                    c.next_clack = c.travel; c.clack_n = (c.clack_n or 0) + 1
                    sfx_at(c, CLACKS[(c.clack_n - 1) % #CLACKS + 1], math.max(0.5, math.min(1, v / 5)))
                end
                -- the brake: once, when the car that has been at speed starts to slow (that is 8.3 m before its stop)
                if v > 3.5 then c.brake_armed = true; c.vmax = math.max(c.vmax or 0, v)
                elseif c.brake_armed and v < (c.vmax or 5) - 0.4 and v > 0.8 then c.brake_armed = false; c.vmax = 0; sfx_at(c, "tr_brake", 1) end
            end
            -- is the player on this car's deck (14 x 3.6 m, along its heading)?
            if c.dir then
                local rx, rz = px - x, pz - z
                local along, across = rx * c.dir[1] + rz * c.dir[2], -rx * c.dir[2] + rz * c.dir[1]
                if math.abs(along) <= 7.0 and math.abs(across) <= 1.7 and py - y > -1.0 and py - y < 3.0 then deck, deck_v = c, v end
            end
        end
    end
    -- the ride: 2D, only while the deck moves
    if deck and deck_v > 0.3 then
        if not T.ride_h then
            T.ride_h = sound.play{ file = "sounds/tr_ride.wav", loop = true, bus = "sfx", volume = 0 } or true
            G.sfx.logline("tr_ride", "sfx", 0, 1, false)
        end
        if t % 15 == 0 and type(T.ride_h) == "number" then
            local f = math.min(1, deck_v / 5)
            pcall(sound.volume, T.ride_h, 0.3 + 0.7 * f, 0.25); pcall(sound.pitch, T.ride_h, 0.8 + 0.2 * f, 0.25)
        end
    elseif T.ride_h then
        if type(T.ride_h) == "number" then pcall(sound.stop, T.ride_h, 0.5) end; T.ride_h = nil
    end
end

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
