-- gen/floor: builds a generated floor from its plan (gen/layout.lua) in the one volume the dungeon has, takes the old floor away first, and wires the rest of the game (game/world.lua) to it.
--
--   F.plan(seed, floor)            the plan (memoised)
--   F.start(seed, floor, on_done)  tears the old floor down, wipes the volume, builds voxels room by room across ticks (a loading veil), then makes the things; on_done() at the end
--   F.load(seed, floor)            a saved run: the plan again and the things only (the voxels are in the world save)
-- A theme (gen/themes.lua) has `voxels(room, ctx)` (only while building) and `things(room, ctx)` (every start; fills the population, crates, hazards).
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local F = {}
G.floorgen = F
local L = G.gen.layout
local floor = math.floor

F.themes = {}            -- name -> { voxels, things, weight(floor), names = {..} }
F.layout = nil
F.active = false         -- a generated floor is the world now
F.job = nil

-- the volume of the dungeon, in the local frame (metres): what a wipe takes
F.VOL = { x0 = -4, z0 = -4, x1 = 130, z1 = 158, y0 = -7, y1 = 15 }

function F.register(name, def) def.name = name; F.themes[name] = def end

local memo_key, memo
function F.plan(seed, floor_n)
    local k = seed .. ":" .. floor_n
    if memo_key ~= k then memo = L.generate(seed, floor_n); memo_key = k; F.assign_themes(memo); memo.rules = G.gen.rules.choose(seed, floor_n) end
    return memo
end

-- ---------------------------------------------------------------------------------------------- themes and names
function F.assign_themes(p)
    local r = L.make_rng(p.seed, p.floor, 777)
    local names = {}
    for n in pairs(F.themes) do names[#names + 1] = n end
    table.sort(names)
    local used = {}
    for _, id in ipairs(p.order) do
        local room = p.rooms[id]
        if room.role == "start" then room.theme = "arrival"
        elseif room.role == "exit" then room.theme = "stairwell"
        elseif room.role == "boss" then room.theme = "lair"
        else
            -- weighted pick, a theme twice in a row on one floor is less likely
            local total, ws = 0, {}
            for _, n in ipairs(names) do
                local def = F.themes[n]
                local w = (def.weight and def.weight(p.floor, room) or 0)
                if used[n] then w = w * 0.35 end
                ws[#ws + 1] = w; total = total + w
            end
            local pick = names[1]
            if total > 0 then
                local x = r.next() * total
                for i, n in ipairs(names) do x = x - ws[i]; if x <= 0 then pick = n; break end end
            end
            if F.force and F.themes[F.force] then pick = F.force end
            room.theme = pick
            used[pick] = (used[pick] or 0) + 1
        end
        local def = F.themes[room.theme]
        local pool = def and def.names or { "Room" }
        room.name = pool[r.int(1, #pool)]
    end
end

-- ---------------------------------------------------------------------------------------------- the world tables of the game (game/world.lua) follow the plan
function F.apply_tables(p)
    local W = G.world
    if not F.authored then
        F.authored = { rooms = W.rooms, zones = W.zones, checkpoints = W.checkpoints, room_order = W.room_order, neighbors = W.neighbors, populate_list = W.populate_list }
    end
    W.rooms = {}
    W.zones = {}
    W.checkpoints = {}
    for id, r in pairs(p.rooms) do
        W.rooms[id] = { x = r.x, z = r.z, w = r.w, d = r.d, h = r.h, name = r.name, kind = r.theme, role = r.role }
        W.checkpoints[id] = { x = r.x + r.w / 2, y = 0.1, z = r.z + r.d / 2 }
    end
    W.room_order = p.order
    W.neighbors = p.neighbors
    W.populate_list = {}
    G.traps.reset()
    G.enemies.reset_floor()
    G.torches = {}
    if G.boss and G.boss.reset then G.boss.reset() end
    G.gen.rules.apply(p)
end

-- ---------------------------------------------------------------------------------------------- the context a theme gets
local function make_ctx(p, building)
    local ctx = { plan = p, floor = p.floor, seed = p.seed, building = building }
    ctx.pop = G.world.populate_list
    function ctx.rng(room) return L.make_rng(p.seed, p.floor, 1000 + room.index) end
    function ctx.add(room, kind, lx, lz, ly, extra)
        local l = ctx.pop[room.id]
        if not l then l = {}; ctx.pop[room.id] = l end
        local e = { kind, lx, lz, ly or 0 }
        if extra then for k, v in pairs(extra) do e[k] = v end end
        l[#l + 1] = e
    end
    -- where the corridors meet each room: ctx.doors[room.id] = { { side = "E", pos = z or x (metres) } ... }; nothing may stand in front of them
    ctx.doors = {}
    for _, e in ipairs(p.edges) do
        for _, d in ipairs(e.doors) do
            local l = ctx.doors[d.room]; if not l then l = {}; ctx.doors[d.room] = l end
            l[#l + 1] = { side = d.side, pos = d.z or d.x }
        end
    end
    function ctx.near_door(room, x, z, r)
        for _, d in ipairs(ctx.doors[room.id] or {}) do
            local dx, dz
            if d.side == "E" then dx, dz = room.x + room.w, d.pos elseif d.side == "W" then dx, dz = room.x, d.pos
            elseif d.side == "S" then dx, dz = d.pos, room.z + room.d else dx, dz = d.pos, room.z end
            if G.dist2(x, z, dx, dz) < r then return true end
        end
        return false
    end
    ctx.crate_n = 0
    function ctx.crate(room, tier, lx, lz, face, ly)
        ctx.crate_n = ctx.crate_n + 1
        local id = "f" .. p.floor .. "c" .. room.index .. "_" .. ctx.crate_n
        G.traps.crate(id, tier, lx, ly or 0, lz, face or "+z")
        return id
    end
    return ctx
end

-- ---------------------------------------------------------------------------------------------- corridors
local function corridor_shell(s)
    local t = 0.25
    G.fill(s[1] - t, -0.5, s[2] - t, s[3] + t, 4.9, s[4] + t, "dungeon_brick", "blocks")
end
-- the air of a segment; where it meets a room (`lo` / `hi`: the end at the smaller / larger coordinate along `axis`) it reaches 0.3 m into the room, because the lining of the corridor
-- (0.25 m all round) covers the last bit of the room's floor space at the door otherwise and the door is walled shut
local function corridor_air(s, axis, lo, hi)
    local x0, z0, x1, z1 = s[1], s[2], s[3], s[4]
    if axis == "x" then if lo then x0 = x0 - 0.3 end; if hi then x1 = x1 + 0.3 end
    else if lo then z0 = z0 - 0.3 end; if hi then z1 = z1 + 0.3 end end
    G.clear(x0, 0, z0, x1, 4.5, z1)
    G.fill(x0, -0.5, z0, x1, 0, z1, "flagstone", "tiles")
end

local function build_corridors(p)
    for _, e in ipairs(p.edges) do for _, s in ipairs(e.segs) do corridor_shell(s) end end
    for _, e in ipairs(p.edges) do
        local axis = (e.doors[1].side == "E") and "x" or "z"
        for k, s in ipairs(e.segs) do corridor_air(s, axis, k == 1, k == #e.segs) end
    end
end

-- boulder corridors: a pressure plate in the middle of a long straight corridor (from floor 2), a boulder that comes out of one end. Pure function of the plan.
function F.trap_edges(p)
    local out = {}
    if p.floor < 2 then return out end
    for i, e in ipairs(p.edges) do
        if #e.segs == 1 and e.a ~= p.exit and e.b ~= p.exit then
            local s = e.segs[1]
            local along_x = (s[3] - s[1]) >= (s[4] - s[2])
            local len = along_x and (s[3] - s[1]) or (s[4] - s[2])
            if len >= 24 and G.hash(p.seed % 100000, p.floor, i) < 0.5 then
                local cx, cz = (s[1] + s[3]) / 2, (s[2] + s[4]) / 2
                local dir = (G.hash(p.seed % 100000, p.floor, i + 50) < 0.5) and 1 or -1       -- the boulder rolls towards +x / +z (dir = 1) or the other way
                local from = along_x and { dir == 1 and s[1] + 2 or s[3] - 2, 1.7, cz } or { cx, 1.7, dir == 1 and s[2] + 2 or s[4] - 2 }
                out[#out + 1] = { edge = i, along_x = along_x, cx = cx, cz = cz, from = from, dir = dir, id = "f" .. p.floor .. "trap" .. i }
            end
        end
    end
    return out
end

-- marble door frames where a corridor meets a room (voxels): two posts and a lintel, outside the 4 m opening
local function build_frames(p)
    for _, t in ipairs(F.trap_edges(p)) do G.fill(t.cx - 1.0, 0, t.cz - 1.0, t.cx + 1.0, 0.04, t.cz + 1.0, "hazard_y") end        -- the plate
    for _, e in ipairs(p.edges) do
        for _, d in ipairs(e.doors) do
            local r = p.rooms[d.room]
            if d.side == "E" or d.side == "W" then
                local xw = (d.side == "E") and (r.x + r.w) or r.x
                local x0, x1 = xw - 0.3, xw + 0.55
                if d.side == "W" then x0, x1 = xw - 0.55, xw + 0.3 end
                G.fill(x0, 0, d.z - 2.6, x1, 4.6, d.z - 2.0, "marble", "blocks"); G.fill(x0, 0, d.z + 2.0, x1, 4.6, d.z + 2.6, "marble", "blocks")
                G.fill(x0, 4.5, d.z - 2.6, x1, 5.0, d.z + 2.6, "marble", "blocks")
            else
                local zw = (d.side == "S") and (r.z + r.d) or r.z
                local z0, z1 = zw - 0.3, zw + 0.55
                if d.side == "N" then z0, z1 = zw - 0.55, zw + 0.3 end
                G.fill(d.x - 2.6, 0, z0, d.x - 2.0, 4.6, z1, "marble", "blocks"); G.fill(d.x + 2.0, 0, z0, d.x + 2.6, 4.6, z1, "marble", "blocks")
                G.fill(d.x - 2.6, 4.5, z0, d.x + 2.6, 5.0, z1, "marble", "blocks")
            end
        end
    end
end

local fired = {}
local function corridor_things(p)
    local T = G.traps
    for _, t in ipairs(F.trap_edges(p)) do
        local plate = events.volume{ name = t.id .. "_plate", box = { G.wx(t.cx - 1.0), G.wy(0), G.wz(t.cz - 1.0), G.wx(t.cx + 1.0) - 1, G.wy(0.5), G.wz(t.cz + 1.0) - 1 }, player = true, bodies = false }
        events.on(plate, "enter", function()
            if fired[t.id] then return end
            fired[t.id] = true
            G.announcer.say_key("trap.plate", { prio = 1 })
            G.sfx.play("trap_click", t.cx, 0, t.cz)
            after(60, function()
                local dx, dz = 0, 0
                if t.along_x then dx = t.dir else dz = t.dir end
                T.release_boulder(t.from[1], t.from[2], t.from[3], dx, dz, 24, 11)
                after(600, function() fired[t.id] = nil end)
            end)
        end)
    end
    local n = 0
    for _, e in ipairs(p.edges) do
        for k, s in ipairs(e.segs) do
            local len = math.max(s[3] - s[1], s[4] - s[2])
            if len >= 10 then
                local count = math.max(1, floor(len / 9))
                for q = 1, count do
                    n = n + 1
                    local f = (q - 0.5) / count
                    local cx, cz = s[1] + (s[3] - s[1]) * f, s[2] + (s[4] - s[2]) * f
                    G.torch(cx, 3.2, cz, { preset = "torch", reach = 10, intensity = 9 * G.gen.rules.dark(), name = "f" .. p.floor .. "_corr" .. n })
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- the build, one slice per tick
local function wipe_boxes(p_old)
    local boxes = {}
    local V = F.VOL
    if not p_old then
        -- the Orientation floor (hand built): the whole volume, in 40 m tiles (an edit may reach 40 m)
        local tile = 40
        for x = V.x0, V.x1 - 1, tile do
            for z = V.z0, V.z1 - 1, tile do
                boxes[#boxes + 1] = { x, V.y0, z, math.min(x + tile, V.x1), V.y1, math.min(z + tile, V.z1) }
            end
        end
    else
        for _, id in ipairs(p_old.order) do
            local r = p_old.rooms[id]
            boxes[#boxes + 1] = { r.x - 2, V.y0, r.z - 2, r.x + r.w + 2, V.y1, r.z + r.d + 2 }
        end
        for _, e in ipairs(p_old.edges) do
            for _, s in ipairs(e.segs) do boxes[#boxes + 1] = { s[1] - 2, V.y0, s[2] - 2, s[3] + 2, V.y1, s[4] + 2 } end
        end
    end
    return boxes
end

local function stone(b) G.vfill(G.vox(b[1]), G.vox(b[2]), G.vox(b[3]), G.vox(b[4]) - 1, G.vox(b[5]) - 1, G.vox(b[6]) - 1, "stone") end

-- the voxels of one room by its theme
local function room_voxels(p, room, ctx)
    local def = F.themes[room.theme]
    if room.theme == "arrival" then G.gen.safe.voxels(room, {})
    elseif room.theme == "stairwell" then G.gen.safe.voxels(room, { stairs = true })
    elseif def and def.voxels then def.voxels(room, ctx) end
end
local function room_things(p, room, ctx)
    local def = F.themes[room.theme]
    if room.theme == "arrival" then G.gen.safe.things(room, {})
    elseif room.theme == "stairwell" then G.gen.safe.things(room, { stairs = true, next_floor = p.floor + 1 })
    elseif def and def.things then def.things(room, ctx) end
end

function F.make_things(p, building)
    local ctx = make_ctx(p, building)
    G.gen.track.scope = "floor" .. p.floor
    for _, id in ipairs(p.order) do room_things(p, p.rooms[id], ctx) end
    corridor_things(p)
    F.ctx = ctx
end

function F.start(seed, floor_n, on_done)
    local old = F.layout                       -- nil: the hand built Orientation floor is in the world
    G.state.flags.boss_dead = nil              -- (the last floor's boss)
    local steps = {}
    G.gen.track.teardown(old and ("floor" .. old.floor) or "orientation")
    G.gen.track.scope = "floor" .. floor_n
    G.rebuilding = true
    local p = F.plan(seed, floor_n)
    local bad = L.check(p)
    if #bad > 0 then print("gen: plan problems: " .. table.concat(bad, "; ")) end
    -- (the tables first: from here on the rooms of the new floor are the world's)
    F.layout = p
    F.active = true
    F.apply_tables(p)
    local boxes = wipe_boxes(old)
    for _, b in ipairs(boxes) do steps[#steps + 1] = function() stone(b) end end
    local ctx = make_ctx(p, true)
    for _, id in ipairs(p.order) do
        local room = p.rooms[id]
        steps[#steps + 1] = function() room_voxels(p, room, ctx) end
    end
    steps[#steps + 1] = function() build_corridors(p); build_frames(p); F.build_gate(p) end
    steps[#steps + 1] = function() F.make_things(p, true) end
    steps[#steps + 1] = function() G.rebuilding = false end
    F.job = { steps = steps, i = 0, n = #steps, done = on_done, floor = floor_n }
    return F.job
end

-- a saved run: the voxels are in the world, the things are made again
function F.load(seed, floor_n)
    local p = F.plan(seed, floor_n)
    F.layout = p
    F.active = true
    G.rebuilding = false
    F.apply_tables(p)
    F.gate_of(p)
    p.gate = F.gate_of(p)
    F.make_things(p, false)
    G.show.redeclare()
end

function F.tick(t)
    local j = F.job
    if not j then return end
    j.i = j.i + 1
    local ok, err = pcall(j.steps[j.i])
    if not ok then print("gen: step " .. j.i .. " failed: " .. tostring(err)) end
    if j.i >= j.n then
        F.job = nil
        G.rebuilding = false
        if j.done then j.done() end
    end
end

function F.progress()
    local j = F.job
    if not j then return 1 end
    return j.i / j.n
end

-- back to the hand built Orientation (a new run that starts there while the world holds a generated floor): the generated floor goes, the volume is wiped, the old floor is built again
function F.restore_authored(on_done)
    local W = G.world
    local old = F.layout
    G.gen.track.teardown(old and ("floor" .. old.floor) or "orientation")
    local a = F.authored
    if a then
        W.rooms, W.zones, W.checkpoints, W.room_order, W.neighbors, W.populate_list = a.rooms, a.zones, a.checkpoints, a.room_order, a.neighbors, a.populate_list
    end
    G.traps.reset(); G.enemies.reset_floor(); G.torches = {}
    F.active, F.layout = false, nil
    local steps = {}
    for _, b in ipairs(wipe_boxes(nil)) do steps[#steps + 1] = function() stone(b) end end
    steps[#steps + 1] = function()
        G.gen.track.scope = "orientation"
        G.rebuilding = true
        G.world.build()
        G.rebuilding = false
    end
    steps[#steps + 1] = function() G.world.populate() end
    F.job = { steps = steps, i = 0, n = #steps, done = on_done }
end

-- ---------------------------------------------------------------------------------------------- the gate in front of the exit, the boss, the rooms as the player walks through them
-- a portcullis of voxels across the first corridor segment on the way to the exit (it opens when the boss falls): like the Orientation's gates, plain voxels that the script clears
function F.gate_of(p)
    for _, e in ipairs(p.edges) do
        if e.a == p.exit or e.b == p.exit then
            local s = e.segs[1]
            if e.b == p.exit then s = e.segs[#e.segs] end
            -- (the first segment on the boss side: the boss is the other end)
            local bossfirst = (e.a == p.boss) and e.segs[1] or e.segs[#e.segs]
            s = bossfirst
            local along_x = (s[3] - s[1]) >= (s[4] - s[2])
            local mid_x, mid_z = (s[1] + s[3]) / 2, (s[2] + s[4]) / 2
            local g
            if along_x then g = { x0 = G.vox(mid_x) - 4, x1 = G.vox(mid_x) + 3, z0 = G.vox(s[2]), z1 = G.vox(s[4]) - 1, h = 71, along_x = true }
            else g = { x0 = G.vox(s[1]), x1 = G.vox(s[3]) - 1, z0 = G.vox(mid_z) - 4, z1 = G.vox(mid_z) + 3, h = 71, along_x = false } end
            return g
        end
    end
end

local function build_gate(p)
    local g = F.gate_of(p)
    p.gate = g
    if not g or G.state.flags["gate_" .. p.boss] then return end
    if g.along_x then
        for z = g.z0, g.z1, 4 do G.vfill(g.x0, 0, z, g.x1, g.h, math.min(z + 1, g.z1), "metal") end
    else
        for x = g.x0, g.x1, 4 do G.vfill(x, 0, g.z0, math.min(x + 1, g.x1), g.h, g.z1, "metal") end
    end
    G.vfill(g.x0, 0, g.z0, g.x1, 3, g.z1, "metal"); G.vfill(g.x0, 34, g.z0, g.x1, 37, g.z1, "metal"); G.vfill(g.x0, 68, g.z0, g.x1, g.h, g.z1, "metal")
end
F.build_gate = build_gate

-- which boss waits on this floor: the Floor Manager on the first two, then by the seed
function F.boss_kind(p)
    if p.floor <= 2 then return "manager" end
    local r = L.make_rng(p.seed, p.floor, 4242)
    return ({ "manager", "golem" })[r.int(1, 2)]
end

function F.lair_of(p)
    local r = p.rooms[p.boss]
    return { room = p.boss, x = r.x + r.w / 2, z = r.z + r.d / 2, kind = F.boss_kind(p), hp_mult = 1 + (p.floor - 1) * 0.3,
             on_dead = function()
                 G.world.gate_open(p.gate, "gate_" .. p.boss)
                 G.announcer.say_key("floor.gate", { prio = 1 })
                 local c = p.rooms[p.boss]
                 G.traps.build_crate_now("f" .. p.floor .. "boss", p.floor >= 4 and "platinum" or "gold", c.x + c.w / 2 - 0.6, 0, c.z + 2, "+z")
             end }
end

function F.enter_room(id, old)
    local p = F.layout
    local room = p.rooms[id]
    local s, A = G.state, G.announcer
    s.flags["visited_" .. id] = true
    if room.role ~= "start" then A.award("hello_world") end
    if G.gen.rules.muted_rooms[id] then A.say_key("rule.muted.enter", { prio = 1, key = "muted_" .. id, cooldown = 99999 }) end
    A.say_key("room." .. room.theme, { prio = 0, key = "room_" .. id, cooldown = 99999 }, room.name)
    if G.music and G.music.on_room then G.music.on_room(id) end
    G.safe = (room.role == "start" or room.role == "exit")
    if G.safe then G.player.set_checkpoint(id); G.show.deliver(room) end
    if room.role == "boss" and not s.flags["gate_" .. id] and G.boss then after(120, function() if G.current_room == id then G.boss.begin(F.lair_of(p)) end end) end
    G.world.sync_active(id)
end

function F.room_cleared(id)
    local p = F.layout
    local room = p.rooms[id]
    if not room then return end
    G.announcer.say_key("room.cleared", { prio = 0, key = "cleared_" .. id, cooldown = 99999 }, room.name)
    if room.role == "room" then
        G.state.checkpoint = id            -- (quietly: the next death starts in the last room that was cleared)
        G.state.flags["visited_" .. id] = true
    end
end
