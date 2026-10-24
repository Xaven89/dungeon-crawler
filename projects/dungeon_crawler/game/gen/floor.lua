-- gen/floor: the BIG floors at runtime (P2 of ~/share/big-floors-plan.md). The voxels of a floor come from the region hook (gen/shell.lua, gen/deco.lua); this module is everything that is not a voxel:
-- the plan of the floor (gen/cell.lua, the same pure code as the hook), the local frame of the floor's band, the cells that are alive around the player (things, population, lights) and the way in and out.
--
--   F.enter(floor_n, on_done)   a new floor of the run: the frame of its band, the plan, the tables of the world, the player in the arrival room; on_done() when the arrival room has been generated
--   F.load(floor_n)             a saved run: the same without the teleport (the things are made again around the player)
--   F.tick(t)                   the cells around the player come alive (radius 1, two per tick) and go (beyond 2); the enemies of the cells next to the player exist
--   F.leave()                   back to the Orientation (or the end of a run): every cell is taken away
-- A floor is the band z = floor * 1024 m + 64 m .. of the endless world, x = 0 ..; the game's local frame (metres, G.OX / G.OZ) is the floor's own: local (x, z) = (cell column * 32 + ..., cell row * 32 + ...).
-- A cell is `F.layout.rooms[id]` ("c4_0"): { id, ci, cj, x, z, w, d, h (local metres), theme, cellrole, name, info }.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local F = {}
G.floorgen = F
local floor, max, min = math.floor, math.max, math.min

F.themes = {}            -- name -> { things(room, ctx), names = { .. } }   (gen/themes.lua, themes_more.lua)
F.layout = nil           -- the plan of the floor in the world (nil: the Orientation)
F.active = false         -- a big floor is the world now
F.job = nil              -- the loading veil: { i, n, done }
F.made, F.made_list = {}, {}
F.queue = {}
F.RADIUS_MAKE, F.RADIUS_KEEP = 1, 2
F.ENEMY_CAP = 56

function F.register(name, def) def.name = name; F.themes[name] = def end

-- ---------------------------------------------------------------------------------------------- the plan: the same pure code as the hook
local CGobj, Hobj
function F.cg()
    if not CGobj then Hobj = cellgen_hash_from(worldgen.hash); CGobj = cellgen_make(Hobj) end
    return CGobj, Hobj
end
function F.world_seed() return floor(worldgen.seed or 0) end

-- the frame of a band (or of the Orientation: floor 0)
F.ORIENT = { 1072, 128, 848 }
function F.frame(fl)
    if not fl or fl == 0 then G.OX, G.OY, G.OZ = F.ORIENT[1], F.ORIENT[2], F.ORIENT[3]
    else G.OX, G.OY, G.OZ = 0, 128, (fl * 32 + 2) * 512 end
end

local function cid(ci, cj) return "c" .. ci .. "_" .. cj end
F.cid = cid

-- ---------------------------------------------------------------------------------------------- the plan of a floor as the game sees it
function F.build_plan(fl)
    local CG = F.cg()
    local plan = CG.plan(0, fl, "small")
    local seed = F.world_seed()
    local P = { floor = fl, seed = seed, big = true, plan = plan, ctx = plan.ctx, order = {}, start = plan.arrival, W = plan.W, H = plan.H, rooms = {}, doors = {} }
    P.dist = CG.bfs(plan, { plan.arrival })
    P.rules = G.gen.rules.choose(seed, fl)
    for _, id in ipairs(plan.order) do
        local info = plan.cells[id]
        local r = info.room
        if r then
            local def = F.themes[info.theme]
            local names = def and def.names or { "Room" }
            local role = (info.role == "arrival") and "start" or ((info.role == "stairs") and "exit" or ((info.role == "lair") and "boss" or "room"))
            P.rooms[id] = { id = id, index = info.ci * 100 + info.cj, ci = info.ci, cj = info.cj, x = info.ci * 32 + r.x, z = info.cj * 32 + r.z, w = r.w, d = r.d, h = r.h,
                            theme = info.theme, cellrole = info.role, role = role, kind = info.theme, name = names[1 + floor(Hobj(0, fl * 1000 + 700, info.ci, info.cj, 1) * #names)], info = info }
            P.order[#P.order + 1] = id
            local l = {}
            for _, d in ipairs({ "E", "S", "W", "N" }) do
                local k = info.open[d]
                if k and k ~= "internal" and info.door and info.door[d] then
                    l[#l + 1] = { side = d, pos = ((d == "E" or d == "W") and info.cj or info.ci) * 32 + info.door[d], kind = k }
                end
            end
            P.doors[id] = l
        end
    end
    -- the borough lairs (floors 1-2): a ring = the fortress of the courtyard; its arena is a room of its own (id "r<block column>_<block row>") that overlaps the four quarter rooms
    P.rings, P.ring_list = {}, {}
    local g = deco_borough_geom()
    for bj = 0, (plan.P.BH or 0) - 1 do
        for bi = 0, (plan.P.BW or 0) - 1 do
            local b = CG.borough(plan.ctx, bi, bj)
            if b and plan.ctx.P.supers == "borough" then
                local id = "r" .. bi .. "_" .. bj
                local ox, oz = b.ci * 32, b.cj * 32
                local ar = { x = ox + g.cx - g.arena, z = oz + g.cz - g.arena, w = 2 * g.arena, d = 2 * g.arena }
                local ring = { id = id, origin = cid(b.ci, b.cj), ox = ox, oz = oz, g = g, arena = ar, ff_flag = "ff_" .. id,
                               pit = { x0 = ox + g.pit.x0, z0 = oz + g.pit.z0, x1 = ox + g.pit.x1, z1 = oz + g.pit.z1 } }
                P.rings[id] = ring
                P.ring_list[#P.ring_list + 1] = ring
                P.rooms[id] = { id = id, index = 9000 + bi * 10 + bj, ci = b.ci, cj = b.cj, x = ar.x, z = ar.z, w = ar.w, d = ar.d, h = 12, theme = "borough_arena", cellrole = "ring", role = "boss",
                                kind = "borough_arena", name = "The Borough Rotunda", ring = ring }
            end
        end
    end
    -- the free stairwells: the first opens at 30 % of the floor's time, on floors 5+ the second is a SERVICE stairwell (80 %, no price for going early)
    P.free = {}
    for i, sc in ipairs(CG.free_stairs(plan.ctx)) do P.free[cid(sc[1], sc[2])] = { index = i, service = (fl >= 5 and i == 2) }; P.free_list = P.free_list or {}; P.free_list[#P.free_list + 1] = cid(sc[1], sc[2]) end
    P.first_of = {}
    for _, id in ipairs(P.order) do local th = P.rooms[id].theme; if not P.first_of[th] then P.first_of[th] = id end end
    return P
end

-- the doors of a room in the room's own cell coordinates (what deco_* takes)
function F.local_doors(room)
    local l = {}
    for _, d in ipairs({ "E", "S", "W", "N" }) do
        local k = room.info.open[d]
        if k and k ~= "internal" and room.info.door and room.info.door[d] then l[#l + 1] = { side = d, pos = room.info.door[d] } end
    end
    return l
end
function F.local_room(room) return room.info.room end

-- the tables of the game's world follow the plan
function F.apply_tables(P)
    local W = G.world
    if not F.authored then
        F.authored = { rooms = W.rooms, zones = W.zones, checkpoints = W.checkpoints, room_order = W.room_order, neighbors = W.neighbors, populate_list = W.populate_list }
    end
    W.rooms, W.zones, W.checkpoints, W.neighbors, W.populate_list = {}, {}, {}, {}, {}
    for _, id in ipairs(P.order) do
        local r = P.rooms[id]
        W.rooms[id] = r
        W.checkpoints[id] = { x = r.x + r.w / 2, y = 0.1, z = r.z + r.d / 2 }
        -- a place to wake up that is not the middle (a pool, a pillar, a shelf): just inside the first door
        local d = P.doors[id] and P.doors[id][1]
        if d and r.cellrole ~= "arrival" then
            local c = W.checkpoints[id]
            if d.side == "E" then c.x, c.z = r.x + r.w - 2.5, d.pos elseif d.side == "W" then c.x, c.z = r.x + 2.5, d.pos
            elseif d.side == "S" then c.x, c.z = d.pos, r.z + r.d - 2.5 else c.x, c.z = d.pos, r.z + 2.5 end
        end
    end
    for _, ring in ipairs(P.ring_list) do
        local r = P.rooms[ring.id]
        W.rooms[ring.id] = r
        W.checkpoints[ring.id] = { x = r.x + r.w / 2, y = 0.1, z = r.z + r.d - 2.5 }
    end
    W.room_order = P.order
    G.traps.reset()
    G.enemies.reset_floor()
    G.torches = {}
    if G.boss and G.boss.reset then G.boss.reset() end
    G.gen.rules.apply(P)
end

-- ---------------------------------------------------------------------------------------------- the context a theme gets (the same shape as the old floors')
local function make_ctx(P, room)
    local CG, H = F.cg()
    local ctx = { plan = P, floor = P.floor, seed = P.seed, building = false, cell = room.id }
    ctx.pop = G.world.populate_list
    if room.cellrole == "room" or room.cellrole == "ante" or room.cellrole == "prize" then ctx.cellpop = CG.population(P.ctx, room.info, P.dist[room.id]) end
    function ctx.rng(rm) return deco_rng(H, P.floor, rm.ci, rm.cj, 1) end
    function ctx.mk(rm) return function(salt) return deco_rng(H, P.floor, rm.ci, rm.cj, salt or 1) end end
    function ctx.add(rm, kind, lx, lz, ly, extra)
        local l = ctx.pop[rm.id]
        if not l then l = {}; ctx.pop[rm.id] = l end
        local e = { kind, lx, lz, ly or 0 }
        if extra then for k, v in pairs(extra) do e[k] = v end end
        l[#l + 1] = e
    end
    ctx.doors = { [room.id] = P.doors[room.id] or {} }
    function ctx.near_door(rm, x, z, r)
        for _, d in ipairs(ctx.doors[rm.id] or {}) do
            local dx, dz
            if d.side == "E" then dx, dz = rm.x + rm.w, d.pos elseif d.side == "W" then dx, dz = rm.x, d.pos
            elseif d.side == "S" then dx, dz = d.pos, rm.z + rm.d else dx, dz = d.pos, rm.z end
            if G.dist2(x, z, dx, dz) < r then return true end
        end
        return false
    end
    function ctx.first_of(theme) return P.first_of and P.first_of[theme] == room.id end
    return ctx
end

-- ---------------------------------------------------------------------------------------------- one cell comes alive
local function cell_lights(P, room)
    local dk = G.gen.rules.dark()
    local info = room.info
    local n = 0
    -- a torch in the middle of every hall (not alleys), at the wall of the room
    for _, d in ipairs(P.doors[room.id] or {}) do
        if d.kind == "tree" or d.kind == "loop" or d.kind == "side" then
            local x, z
            if d.side == "E" then x, z = room.x + room.w + (32 - (room.info.room.x + room.w)) / 2, d.pos
            elseif d.side == "W" then x, z = room.ci * 32 + room.info.room.x / 2, d.pos
            elseif d.side == "S" then x, z = d.pos, room.cj * 32 + room.info.room.z + room.d + (32 - room.info.room.z - room.d) / 2
            else x, z = d.pos, room.cj * 32 + room.info.room.z / 2 end
            n = n + 1
            G.torch(x, 3.2, z, { preset = "torch", reach = 10, far = 24, intensity = 9 * dk, name = room.id .. "_h" .. n })
        end
    end
    -- the artery strips along the block borders: a torch every 8 m
    local ci, cj, W, H = room.ci, room.cj, P.W, P.H
    local x0, z0 = ci * 32, cj * 32
    local function strip(side)
        for t = 4, 28, 8 do
            n = n + 1
            local x, z
            if side == "E" then x, z = x0 + 30, z0 + t elseif side == "W" then x, z = x0 + 2, z0 + t elseif side == "S" then x, z = x0 + t, z0 + 30 else x, z = x0 + t, z0 + 2 end
            G.torch(x, 4.5, z, { preset = "torch", reach = 12, far = 28, intensity = 11 * dk, name = room.id .. "_a" .. n })
        end
    end
    if ci % 8 == 0 then strip("W") end
    if ci % 8 == 7 then strip("E") end
    if cj % 8 == 0 then strip("N") end
    if cj % 8 == 7 then strip("S") end
end

function F.make_cell(id)
    local P = F.layout
    local room = P and P.rooms[id]
    if not room or F.made[id] then return end
    F.made[id] = true
    F.made_list[#F.made_list + 1] = id
    local prev = G.gen.track.scope
    G.gen.track.scope = "cell" .. P.floor .. id
    G.traps.cell = id
    local ctx = make_ctx(P, room)
    local def = F.themes[room.theme]
    local ok, err = pcall(function()
        if def and def.things then def.things(room, ctx) end
        -- the loot crates: the voxels are the hook's (deco_crates), the buttons are ours
        local lroom, ldoors = room.info.room, F.local_doors(room)
        local mk = ctx.mk(room)
        for k, c in ipairs(deco_crates(room.theme, lroom, ldoors, mk, P.floor)) do
            local cidn = string.format("c%d_%d_%d_%d", P.floor, room.ci, room.cj, k)
            G.traps.crate(cidn, c.tier, room.ci * 32 + c.x, c.y, room.cj * 32 + c.z, c.face)
            if c.mimic then
                G.traps.crate_hooks[cidn] = function()
                    G.announcer.say_key("prize.mimic", { prio = 2 })
                    G.announcer.award("mimic_food")
                    local r = ctx.rng(room)
                    for q = 1, 5 do
                        local e = G.enemies.spawn(F.pick_kind(r, P.floor), room.ci * 32 + c.x + (q - 3) * 0.9, 0, room.cj * 32 + c.z + 2.2, { room = room.id, index = 90 + q })
                        if e then G.enemies.aggro(e, true) end
                    end
                end
            end
        end
        cell_lights(P, room)
        if P.rings then for _, ring in ipairs(P.ring_list) do if ring.origin == id then F.make_ring(P, ring) end end end
        if room.theme == 'stairs_free' then F.pit_cover(room, F.stairs_open(id)) end
        F.cell_signs(P, room)
    end)
    if not ok then print("floor: cell " .. id .. " failed: " .. tostring(err)) end
    G.traps.cell = nil
    G.gen.track.scope = prev
end

function F.drop_cell(id)
    local P = F.layout
    if not F.made[id] then return end
    F.made[id] = nil
    for i, v in ipairs(F.made_list) do if v == id then table.remove(F.made_list, i); break end end
    G.gen.track.teardown("cell" .. P.floor .. id)
    G.traps.drop_cell(id)
    G.enemies.despawn_room(id)
    G.world.populate_list[id] = nil
end

-- ---------------------------------------------------------------------------------------------- the cells around the player
function F.player_cell()
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    return floor(lx / 32), floor(lz / 32), lx, ly, lz
end

local function in_queue(id) for _, v in ipairs(F.queue) do if v == id then return true end end return false end

function F.update_cells(force)
    local P = F.layout
    if not P then return end
    local ci, cj = F.player_cell()
    if ci == F.pci and cj == F.pcj and not force then return end
    F.pci, F.pcj = ci, cj
    local R = F.RADIUS_MAKE
    for d = 0, R do                                     -- the nearest first
        for dj = -d, d do for di = -d, d do
            if max(math.abs(di), math.abs(dj)) == d then
                local id = cid(ci + di, cj + dj)
                if P.rooms[id] and not F.made[id] and not in_queue(id) then F.queue[#F.queue + 1] = id end
            end
        end end
    end
    for i = #F.made_list, 1, -1 do
        local id = F.made_list[i]
        local room = P.rooms[id]
        if max(math.abs(room.ci - ci), math.abs(room.cj - cj)) > F.RADIUS_KEEP then F.drop_cell(id) end
    end
    F.sync_enemies()
end

-- who exists: the enemies of the cell the player is in and of the cells next to it, nearest first; a room is spawned whole only when all of it fits under the cap (the engine's 64 agents
-- also carry the ally, the companion and a boss): otherwise it waits for the next sync
function F.sync_enemies()
    local P = F.layout
    if not P then return end
    local W = G.world
    local near = {}
    for _, id in ipairs(F.made_list) do
        local room = P.rooms[id]
        local d = max(math.abs(room.ci - (F.pci or -99)), math.abs(room.cj - (F.pcj or -99)))
        local list = W.populate_list[id]
        if list and d <= 1 then near[#near + 1] = { id = id, d = d, list = list } else G.enemies.despawn_room(id) end
    end
    for id, ring in pairs(P.rings or {}) do        -- (a ring has its own list: made with its origin cell)
        local oc = P.rooms[ring.origin]
        local list = W.populate_list[id]
        if oc and F.made[ring.origin] and list then
            local d = max(math.abs(oc.ci + 0.5 - (F.pci or -99)), math.abs(oc.cj + 0.5 - (F.pcj or -99)))
            if d <= 1.5 then near[#near + 1] = { id = id, d = d, list = list } else G.enemies.despawn_room(id) end
        end
    end
    table.sort(near, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.id < b.id end)
    for _, n in ipairs(near) do
        if not G.enemies.spawned[n.id] and G.enemies.alive_count() + G.enemies.owed(n.id, n.list) <= F.ENEMY_CAP then G.enemies.spawn_room(n.id, n.list) end
    end
end

function F.tick(t)
    local j = F.job
    if j then
        j.i = j.i + 1
        -- the arrival room must be generated: the floor under the player is not "unloaded"
        local r = F.layout.rooms[j.room or F.layout.start]
        local ax, az = r.x + r.w / 2, r.z + r.d / 2
        if j.at then ax, az = j.at[1], j.at[2] end
        local m = world.material_at(G.wx(ax), G.wy(-0.1), G.wz(az))
        local ready = (m ~= "unloaded" and m ~= "air") and j.i >= 8
        if ready or j.i > 1800 then
            F.job = nil
            F.update_cells(true)
            for _ = 1, 4 do local id = table.remove(F.queue, 1); if id then F.make_cell(id) end end
            if j.done then j.done() end
        end
        return
    end
    if not (F.active and F.layout) then return end
    if t % 5 == 0 then F.update_cells(false) end
    for _ = 1, 2 do local id = table.remove(F.queue, 1); if id then F.make_cell(id) end end
    if t % 30 == 0 then
        F.sync_enemies()
        F.safe_rules()
    end
    local run = G.run.cur()
    if run and G.state.class and not G.screen and not G.player.dead then run.fclock = (run.fclock or 0) + 1 end
    if t % 60 == 0 then F.timer_step() end
end

function F.progress()
    local j = F.job
    if not j then return 1 end
    return min(1, j.i / 60)
end

-- ---------------------------------------------------------------------------------------------- the way in and out
function F.teardown_all()
    local P = F.layout
    if P then
        for i = #F.made_list, 1, -1 do F.drop_cell(F.made_list[i]) end
        G.gen.track.teardown("floor" .. P.floor)
    end
    F.made, F.made_list, F.queue = {}, {}, {}
    F.pci, F.pcj = nil, nil
end

function F.enter(fl, on_done)
    G.gen.track.teardown("orientation")
    F.teardown_all()
    G.state.flags.boss_dead = nil
    F.frame(fl)
    G.bigfloor = true
    local P = F.build_plan(fl)
    F.layout, F.active = P, true
    G.gen.track.scope = "floor" .. fl
    F.apply_tables(P)
    local r = P.rooms[P.start]
    local x, y, z = G.mx(r.x + r.w / 2), G.my(0.1), G.mz(r.z + r.d / 2)
    player.teleport(x, y, z)
    G.frozen_at = { x, y, z }                                -- (the veil holds the player where the floor will appear)
    G.current_room = nil
    F.job = { i = 0, done = on_done }
end

-- a saved run: the frame and the plan, the cells come alive around the player when the hook has made them
function F.load(fl)
    G.gen.track.teardown("orientation")
    F.teardown_all()
    F.frame(fl)
    G.bigfloor = true
    local P = F.build_plan(fl)
    F.layout, F.active = P, true
    G.gen.track.scope = "floor" .. fl
    F.apply_tables(P)
    G.show.redeclare()
    -- the veil until the floor around the checkpoint exists (the hook makes it when the player is there), then the player wakes up at the checkpoint
    local cpid = G.state.checkpoint
    if not P.rooms[cpid] then cpid = P.start end
    local c = G.world.checkpoints[cpid]
    local x, y, z = G.mx(c.x), G.my(0.1), G.mz(c.z)
    player.teleport(x, y, z)
    G.frozen_at = { x, y, z }
    G.screen = "loading"
    F.job = { i = 0, room = cpid, at = { c.x, c.z }, done = function() G.frozen_at = nil; if G.screen == "loading" then G.screen = nil end end }
end

-- back to the hand built Orientation
function F.restore_authored(on_done)
    local W = G.world
    F.teardown_all()
    G.traps.reset(); G.enemies.reset_floor(); G.torches = {}
    local a = F.authored
    if a then W.rooms, W.zones, W.checkpoints, W.room_order, W.neighbors, W.populate_list = a.rooms, a.zones, a.checkpoints, a.room_order, a.neighbors, a.populate_list end
    F.active, F.layout, G.bigfloor = false, nil, false
    F.frame(0)
    G.gen.track.scope = "orientation"
    G.world.build()                                          -- (the things; the voxels are in the world)
    G.world.populate()
    if on_done then on_done() end
end

-- ---------------------------------------------------------------------------------------------- rooms as the player walks through them
function F.room_at(lx, lz)
    local P = F.layout
    if not P then return nil end
    for _, ring in ipairs(P.ring_list) do
        local a = ring.arena
        if lx >= a.x and lx < a.x + a.w and lz >= a.z and lz < a.z + a.d then return ring.id, P.rooms[ring.id] end
    end
    local ci, cj = floor(lx / 32), floor(lz / 32)
    local id = cid(ci, cj)
    local r = P.rooms[id]
    if r and lx >= r.x and lx < r.x + r.w and lz >= r.z and lz < r.z + r.d then return id, r end
    return nil
end

-- ---------------------------------------------------------------------------------------------- the floor's clock: 30 % the stairwells open, 80 % the early-descent price ends (and the service stairwell opens),
-- 95 % the safe rooms close, 100 % the floor collapses (the player is taken to a stairwell with a penalty; under the hardcore contract he dies)
F.FLOOR_TICKS = 108000            -- 30 minutes of play (the clock runs only while the player plays: no screen open, not dead)
F.AT_OPEN, F.AT_LATE, F.AT_CLOSE = 0.30, 0.80, 0.95

function F.clock() local run = G.run.cur(); return run and run.fclock or 0 end
function F.floor_ticks() local run = G.run.cur(); return (run and run.floor_ticks) or F.FLOOR_TICKS end
function F.frac() return F.clock() / F.floor_ticks() end
function F.remaining_s() return max(0, floor((F.floor_ticks() - F.clock()) / 60)) end

-- is this free stairwell open now
function F.stairs_open(id)
    local P = F.layout
    local f = P and P.free and P.free[id]
    if not f then return true end
    return F.frac() >= (f.service and F.AT_LATE or F.AT_OPEN)
end

function F.safe_closed() return F.layout ~= nil and F.frac() >= F.AT_CLOSE end

local SAFE = { safe = true, rest = true, guild = true }
function F.is_safe(room) return SAFE[room.theme] == true and not F.safe_closed() end

-- the sealed pit of a free stairwell: a glowing slab over the round hole until the stairs exist (edits, saved: the state is re-applied whenever the cell comes alive)
function F.pit_cover(room, open)
    local cx, cz = room.x + room.w / 2, room.z + room.d / 2
    local key = "cov_" .. room.id
    local flags = G.state.flags
    if open and flags[key] then G.cyl_clear(cx, cz, 3.2, -0.3, 0); flags[key] = nil
    elseif not open and not flags[key] then G.pillar(cx, cz, 3.2, -0.3, 0, "neon_red"); flags[key] = true end
end

function F.timer_step()
    local P, run = F.layout, G.run.cur()
    if not P or not run or not G.state.class then return end
    local f = F.frac()
    local stage = run.fstage or 0
    local A = G.announcer
    if stage < 1 and f >= F.AT_OPEN then
        run.fstage = 1
        A.say_key("timer.open", { prio = 2 })
        for _, id in ipairs(F.made_list) do local r = P.rooms[id]; if r.theme == "stairs_free" and F.stairs_open(id) then F.pit_cover(r, true) end end
    end
    if stage < 2 and f >= F.AT_LATE then
        run.fstage = 2
        A.say_key("timer.late", { prio = 2 })
        for _, id in ipairs(F.made_list) do local r = P.rooms[id]; if r.theme == "stairs_free" and F.stairs_open(id) then F.pit_cover(r, true) end end
    end
    if stage < 3 and f >= F.AT_CLOSE then
        run.fstage = 3
        A.say_key("timer.close", { prio = 2 })
        local id = G.current_room
        local r = id and P.rooms[id]
        if r and SAFE[r.theme] then F.eject(r) end
        G.safe = false
    end
    if stage < 4 and f >= 1 then run.fstage = 4; F.collapse() end
end

-- the player is put outside a safe room that closes
function F.eject(room)
    local d = (G.floorgen.layout.doors[room.id] or {})[1]
    local x, z = room.x + room.w / 2, room.z - 3
    if d then
        if d.side == "E" then x, z = room.x + room.w + 3, d.pos elseif d.side == "W" then x, z = room.x - 3, d.pos
        elseif d.side == "S" then x, z = d.pos, room.z + room.d + 3 else x, z = d.pos, room.z - 3 end
    end
    player.teleport(G.mx(x), G.my(0.1), G.mz(z))
    G.announcer.say_key("timer.eject", { prio = 2 })
end

-- the floor collapses: to the nearest open stairwell with a penalty, and down; the hardcore contract dies
function F.collapse()
    local P = F.layout
    local A = G.announcer
    A.say_key("timer.collapse", { prio = 3 })
    G.sfx.play("rumble", nil, nil, nil, 1.0, 0.5)
    if G.contracts.hardcore() then G.player.hurt(99999, "the collapse of the floor", { pierce = true }); return end
    local s = G.state
    s.gold = floor(s.gold * 0.7)
    s.hp = min(s.hp, floor(G.player.max_hp() * 0.5))
    local sh = G.show.st(); sh.views = floor(sh.views * 0.8)
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local best, bd
    for _, id in ipairs(P.free_list or {}) do
        local r = P.rooms[id]
        local d = G.dist2(lx, lz, r.x + r.w / 2, r.z + r.d / 2)
        if not bd or d < bd then best, bd = id, d end
    end
    if not best then return end
    local r = P.rooms[best]
    local c = G.world.checkpoints[best]
    player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z))
    G.frozen_at = nil
    G.run.cur().collapsed = true
    after(240, function() if G.floorgen.layout == P and G.screen == nil then G.run.descend(true) end end)
end

-- ---------------------------------------------------------------------------------------------- the lairs: the neighbourhood boss (the arena behind its antechamber) and the borough boss (the rotunda of the fortress)
F.STAGING = {
    quarter = { hp = 1.0, crate = "gold", music = "boss", guards = 3 },
    borough = { hp = 1.8, crate = "platinum", music = "boss", guards = 4 },
}

function F.boss_kind(P, id)
    if P.floor <= 2 then return "manager" end
    local _, H = F.cg()
    return ({ "manager", "golem", "auditor" })[1 + floor(H(0, P.floor * 1000 + 710, P.rooms[id].ci, P.rooms[id].cj, 1) * 3) % 3]
end

function F.lair_of(P, id)
    local room = P.rooms[id]
    local tier = room.ring and "borough" or "quarter"
    local S = F.STAGING[tier]
    return { room = id, x = room.x + room.w / 2, z = room.z + room.d / 2 + (room.ring and 2 or 0), kind = F.boss_kind(P, id), hp_mult = S.hp * (1 + (P.floor - 1) * 0.18),
             flag = "boss_dead_" .. id, tier = tier, on_dead = function() F.lair_cleared(P, id, tier) end }
end

function F.ff_clear(ring)
    local p = ring.pit
    G.clear(p.x0, 0, p.z0, p.x1, 0.55, p.z1)
end

function F.lair_cleared(P, id, tier)
    local room = P.rooms[id]
    local A = G.announcer
    A.say_key(tier == "borough" and "lair.borough_down" or "lair.quarter_down", { prio = 2 })
    G.player.popup(tier == "borough" and "BOROUGH BOSS FIRED" or "NEIGHBOURHOOD BOSS FIRED", "#ff7a7a", true)
    G.traps.build_crate_now("f" .. P.floor .. "boss" .. id, F.STAGING[tier].crate, room.x + room.w / 2 - 0.6, 0, room.z + 2.5, "+z")
    if room.ring then
        G.state.flags[room.ring.ff_flag] = true
        F.ff_clear(room.ring)
        A.say_key("lair.forcefield", { prio = 1 })
    end
    G.save()
end

-- the fortress of a borough: lights, guards in the rings and the arena, the stairwell pit under its forcefield (made with the origin cell of the courtyard)
function F.make_ring(P, ring)
    local g, ox, oz = ring.g, ring.ox, ring.oz
    local dk = G.gen.rules.dark()
    local room = P.rooms[ring.id]
    local _, H = F.cg()
    for k, d in ipairs({ { 18.9, 0 }, { -18.9, 0 }, { 0, 18.9 }, { 0, -18.9 }, { 13.9, 0 }, { -13.9, 0 }, { 0, 13.9 }, { 0, -13.9 } }) do
        G.torch(ox + g.cx + d[1], 3.4, oz + g.cz + d[2], { preset = "torch", reach = 10, far = 22, intensity = 9 * dk, name = ring.id .. "_t" .. k })
    end
    for k, d in ipairs({ { 8, 8 }, { -8, 8 }, { 8, -8 }, { -8, -8 } }) do G.brazier(ox + g.cx + d[1], oz + g.cz + d[2], { reach = 14, far = 24 }) end
    local p = ring.pit
    G.torch((p.x0 + p.x1) / 2, 0.9, (p.z0 + p.z1) / 2, { preset = "campfire", color = { 1, 0.15, 0.15 }, reach = 10, far = 22, name = ring.id .. "_ff" })
    -- the guards: two in each ring corridor, a few in the arena
    local rng = deco_rng(H, P.floor, room.ci, room.cj, 9)
    local list = G.world.populate_list
    list[ring.id] = {}
    local function add(kind, x, z, extra)
        local e = { kind, x, z, 0 }
        if extra then for k, v in pairs(extra) do e[k] = v end end
        list[ring.id][#list[ring.id] + 1] = e
    end
    local spots = { { 18.9, 3 }, { -18.9, -3 }, { 13.9, -3 }, { -13.9, 3 } }
    for _, d in ipairs(spots) do add(F.pick_kind(rng, P.floor), ox + g.cx + d[1], oz + g.cz + d[2]) end
    for i = 1, F.STAGING.borough.guards do
        local a = i * 6.2832 / F.STAGING.borough.guards
        add(F.pick_kind(rng, P.floor), ox + g.cx + math.cos(a) * 6, oz + g.cz + 3 + math.sin(a) * 4)
    end
    -- the stairwell: under the forcefield until the boss falls
    local vol = events.volume{ name = ring.id .. "_down", box = { G.wx(p.x0), G.wy(-1.4), G.wz(p.z0), G.wx(p.x1) - 1, G.wy(-0.3), G.wz(p.z1) - 1 }, player = true, bodies = false }
    events.on(vol, "enter", function() if G.state.flags[ring.ff_flag] then F.stairs_enter(ring.id) end end)
    G.traps.add_interact(ring.id .. "_down", (p.x0 + p.x1) / 2, 0.4, (p.z0 + p.z1) / 2, tr("ui.descend", G.run.next_floor(P.floor) or "?"), 3.2, function() return G.state.flags[ring.ff_flag] end)
    if G.state.flags[ring.ff_flag] then F.ff_clear(ring) end
end

-- ---------------------------------------------------------------------------------------------- stairs, signs, safe rooms
function F.stairs_enter(id)
    if G.screen or G.player.dead then return end
    local P = F.layout
    local run = G.run.cur()
    if P.free and P.free[id] then
        if not F.stairs_open(id) then G.announcer.say_key("stairs.sealed", { prio = 1, key = "sealed", cooldown = 600 }); return end
        run.early_descent = (F.frac() < F.AT_LATE) and not P.free[id].service
    else
        run.early_descent = false
    end
    G.run.descend()
end

-- the price of going down early (before 80 % of the floor's time, by a free stairwell that is not the service one)
function F.early_penalty()
    local sh = G.show.st()
    sh.views = floor(sh.views * 0.75)
    sh.followers = floor(sh.followers * 0.95)
    G.state.flags.forced_contract = "stasis"
    G.announcer.say_key("stairs.early", { prio = 2 })
end

local GRAFFITI = { "THE FLOOR IS LAVA (IT IS NOT)", "I WAS HERE. NOBODY ELSE WAS", "DO NOT FEED THE MANAGER", "EXIT -> (NOT THIS WAY)", "UNION OF CONTESTANTS LOCAL 7", "SPONSOR ME", "THE CRATES LIE",
               "GLEE IS WATCHING", "PLEASE STAND CLEAR OF THE CEILING", "ASK ABOUT OUR VENDING MACHINES", "FOUND A SAFE ROOM. LOST IT", "NO REFUNDS" }
-- hashed text on a wall of some rooms and the block names at the corners of the arteries (voxel text, written once: the edit is in the world's save)
function F.cell_signs(P, room)
    local _, H = F.cg()
    local signs = G.state.signs
    if not signs then signs = {}; G.state.signs = signs end
    local key = P.floor .. room.id
    if signs[key] then return end
    signs[key] = true
    local x0, z0 = room.ci * 32, room.cj * 32
    -- the name of the block at the corners of the arteries (the plaza signs: on the wall that borders the artery strip, facing it)
    if P.plan.ctx.P.kind == "grid" and (room.ci % 8 == 0 or room.ci % 8 == 7) and (room.cj % 8 == 0 or room.cj % 8 == 7) then
        local bi, bj = room.ci // 8, room.cj // 8
        local txt = "BLOCK " .. string.char(65 + bi) .. (bj + 1)
        local len = #txt * 6 * 0.0625
        if room.cj % 8 == 0 then G.text(x0 + 16 + len / 2, 2.4, z0 + 4, txt, { facing = "-z", material = "gold", size = 1, depth = 1 })
        else G.text(x0 + 16 - len / 2, 2.4, z0 + 28, txt, { facing = "+z", material = "gold", size = 1, depth = 1 }) end
    end
    if room.cellrole == "room" and H(0, P.floor * 1000 + 720, room.ci, room.cj, 1) < 0.22 then
        local txt = GRAFFITI[1 + floor(H(0, P.floor * 1000 + 721, room.ci, room.cj, 1) * #GRAFFITI) % #GRAFFITI]
        local doors = P.doors[room.id] or {}
        local used = {}
        for _, d in ipairs(doors) do used[d.side] = true end
        local side
        for _, sd in ipairs({ "N", "S", "W", "E" }) do if not used[sd] then side = sd; break end end
        if side then
            local len = #txt * 6 * 0.0625                                    -- 5 x 7 font at 1 voxel: about 6 voxels a letter
            if side == "N" then G.text(room.x + room.w / 2 - len / 2, 1.7, room.z + 0.05, txt, { facing = "+z", material = "neon_red", size = 1, depth = 1 })
            elseif side == "S" then G.text(room.x + room.w / 2 + len / 2, 1.7, room.z + room.d - 0.05, txt, { facing = "-z", material = "neon_red", size = 1, depth = 1 })
            elseif side == "W" then G.text(room.x + 0.05, 1.7, room.z + room.d / 2 + len / 2, txt, { facing = "+x", material = "neon_red", size = 1, depth = 1 })
            else G.text(room.x + room.w - 0.05, 1.7, room.z + room.d / 2 - len / 2, txt, { facing = "-x", material = "neon_red", size = 1, depth = 1 }) end
        end
    end
end

-- an enemy inside a safe room is sent out for a minute and a half
function F.safe_rules()
    local P = F.layout
    if F.safe_closed() then return end
    local E = G.enemies
    local rects = {}
    for _, id in ipairs(F.made_list) do
        local r = P.rooms[id]
        if SAFE[r.theme] or r.cellrole == "arrival" then rects[#rects + 1] = r end
    end
    if #rects == 0 then return end
    local ids = {}
    for id in pairs(E.list) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local inst = E.list[id]
        if inst and not inst.dead and not inst.captive and not inst.T.boss and inst ~= (G.ally and G.ally.inst) then
            local x, y, z = E.position(inst)
            if x then
                local lx, ly, lz = G.to_local(x, y, z)
                for _, r in ipairs(rects) do
                    if lx > r.x + 0.5 and lx < r.x + r.w - 0.5 and lz > r.z + 0.5 and lz < r.z + r.d - 0.5 then
                        E.exile(inst, 4500 + floor(G.hash(id, floor(time.tick() / 30), 7) * 2700))
                        break
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- entering and clearing rooms
function F.enter_room(id, old)
    local P = F.layout
    local room = P.rooms[id]
    local s, A = G.state, G.announcer
    s.flags["visited_" .. id] = true
    if room.cellrole ~= "arrival" then A.award("hello_world") end
    if G.gen.rules.muted_rooms[id] then A.say_key("rule.muted.enter", { prio = 1, key = "muted_" .. id, cooldown = 99999 }) end
    A.say_key("room." .. room.theme, { prio = 0, key = "room_" .. id, cooldown = 99999 }, room.name)
    if G.music and G.music.on_room then G.music.on_room(id) end
    G.safe = F.is_safe(room) or (room.cellrole == "arrival" and not F.safe_closed())
    if G.safe then
        G.player.set_checkpoint(id)
        if room.theme == "safe" or room.cellrole == "arrival" then G.show.deliver(room) end        -- (the sponsors' boxes only in the safe rooms, not in the rest stops)
    end
    if room.theme == "arena" or room.theme == "borough_arena" then
        if not s.flags["boss_dead_" .. id] and G.boss then after(120, function() if G.current_room == id then G.boss.begin(F.lair_of(P, id)) end end) end
        if room.ring then G.player.set_checkpoint(id, true) end
    end
    F.sync_enemies()
end

function F.room_cleared(id)
    local P = F.layout
    local room = P.rooms[id]
    if not room then return end
    G.announcer.say_key("room.cleared", { prio = 0, key = "cleared_" .. id, cooldown = 99999 }, room.name)
    G.contracts.on_room_cleared()
    if room.cellrole == "room" then
        G.state.checkpoint = id            -- (quietly: the next death starts in the last room that was cleared)
    end
end
