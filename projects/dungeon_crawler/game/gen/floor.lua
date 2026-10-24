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

-- who exists: the enemies of the cell the player is in and of the cells next to it (inside the engine's 64 agents)
function F.sync_enemies()
    local P = F.layout
    if not P then return end
    local W = G.world
    for _, id in ipairs(F.made_list) do
        local room = P.rooms[id]
        local near = max(math.abs(room.ci - (F.pci or -99)), math.abs(room.cj - (F.pcj or -99))) <= 1
        local list = W.populate_list[id]
        if list and near then
            if G.enemies.alive_count() < F.ENEMY_CAP then G.enemies.spawn_room(id, list) end
        else G.enemies.despawn_room(id) end
    end
end

function F.tick(t)
    local j = F.job
    if j then
        j.i = j.i + 1
        -- the arrival room must be generated: the floor under the player is not "unloaded"
        local r = F.layout.rooms[F.layout.start]
        local m = world.material_at(G.wx(r.x + r.w / 2), G.wy(-0.1), G.wz(r.z + r.d / 2))
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
    if t % 30 == 0 then F.sync_enemies() end
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
    local ci, cj = floor(lx / 32), floor(lz / 32)
    local id = cid(ci, cj)
    local r = P.rooms[id]
    if r and lx >= r.x and lx < r.x + r.w and lz >= r.z and lz < r.z + r.d then return id, r end
    return nil
end

local SAFE = { safe = true, rest = true, guild = true }
function F.is_safe(room) return SAFE[room.theme] == true end

function F.enter_room(id, old)
    local P = F.layout
    local room = P.rooms[id]
    local s, A = G.state, G.announcer
    s.flags["visited_" .. id] = true
    if room.cellrole ~= "arrival" then A.award("hello_world") end
    if G.gen.rules.muted_rooms[id] then A.say_key("rule.muted.enter", { prio = 1, key = "muted_" .. id, cooldown = 99999 }) end
    A.say_key("room." .. room.theme, { prio = 0, key = "room_" .. id, cooldown = 99999 }, room.name)
    if G.music and G.music.on_room then G.music.on_room(id) end
    G.safe = F.is_safe(room) or room.cellrole == "arrival"
    if G.safe then G.player.set_checkpoint(id); G.show.deliver(room) end
    F.sync_enemies()
end

function F.room_cleared(id)
    local P = F.layout
    local room = P.rooms[id]
    if not room then return end
    G.announcer.say_key("room.cleared", { prio = 0, key = "cleared_" .. id, cooldown = 99999 }, room.name)
    G.contracts.on_room_cleared()
    if room.theme == "arena" then
        G.traps.build_crate_now("f" .. P.floor .. "boss" .. id, P.floor >= 4 and "platinum" or "gold", room.x + room.w / 2 - 0.6, 0, room.z + 2, "+z")
    elseif room.cellrole == "room" then
        G.state.checkpoint = id            -- (quietly: the next death starts in the last room that was cleared)
    end
end

-- the stairwell: the pit of a free stairwell takes the player down (the recap first)
function F.stairs_enter()
    if G.screen or G.player.dead then return end
    G.run.descend()
end
