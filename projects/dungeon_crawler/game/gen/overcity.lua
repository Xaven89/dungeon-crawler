-- gen/overcity: floor 3, the OVER-CITY (P4 of ~/share/big-floors-plan.md, D12 / D13): an open-air floor on the plain, a ruin of roofless blocks with walled villages and a fortified park, a real sky
-- with a day and a night, guards by day and a night pool, locator stones, pubs that are the safe rooms and carry the note that tells where the free stairs are, and a small quest ("find out why":
-- three villagers, three clues, then the second stairwell opens). The voxels are the hook's (gen/shell.lua OPEN mode, gen/deco.lua deco_village); this module is the things.
--   OC.enter(P) / OC.leave()      the sky of the floor (a red dusk palette, the clock of the floor is the clock of the sky) / back to the underground's sky
--   OC.tick(t)                    dusk and dawn, the guards come and go, the lights of the villages, the night pool, the pubs as safe rooms
--   OC.cell_made(P, room)         a cell came alive: its night extras, a village's things (once, by its origin cell)
--   OC.drop_cell(id)              the NPCs of a cell go with it
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local OC = {}
G.gen.overcity = OC
local floor, max, min = math.floor, math.max, math.min

OC.START, OC.RATE = 0.10, 0.90          -- the sky's time = START + RATE * (the share of the floor's clock): a morning that ends at 44 %, then the night until the end (sunrise is at 100 %)
OC.npcs = {}                            -- cell id -> { { id, kind, x, z, village } ... }
OC.lights = {}                          -- the names of the village lights (switched on at dusk)
OC.pubs = {}                            -- { x0, z0, x1, z1, id } in floor metres
OC.night_added = {}

function OC.on_floor() local P = G.floorgen.layout; return P ~= nil and P.floor == 3 end
OC.fixed = nil                          -- a fixed sky time (pictures and tests)
function OC.sky_time(f) if OC.fixed then return OC.fixed end return (OC.START + OC.RATE * f) % 1 end
function OC.is_night()
    if not OC.on_floor() then return false end
    return OC.sky_time(G.floorgen.frac()) >= 0.5
end

-- the sky colours at the turn of the day (replace the engine's for as long as the band lasts): the red dusk of the book's fake sun, a paler dawn; the rest of the day keeps the engine's sky
function OC.sky_colours(t)
    if t >= 0.42 and t < 0.60 then return { zenith = { 0.35, 0.06, 0.07 }, horizon = { 1.1, 0.35, 0.2 }, ground = { 0.3, 0.12, 0.1 } }
    elseif t < 0.08 or t >= 0.96 then return { zenith = { 0.25, 0.14, 0.22 }, horizon = { 1.0, 0.55, 0.35 }, ground = { 0.3, 0.2, 0.15 } }
    elseif t < 0.42 then return { zenith = { 0.22, 0.07, 0.09 }, horizon = { 0.70, 0.30, 0.21 }, ground = { 0.22, 0.14, 0.12 } } end      -- the day: the book's red sky stays (the dome only: the sun below is white)
    return { zenith = false, horizon = false, ground = false }
end

-- (the red is the sky's: the sun on the walls is a plain warm white by day; the red dusk of the book is the zenith / horizon colours above, which only the turn of the day replaces)
local PALETTE = { tint = { 1.0, 0.95, 0.92 }, fog_tint = { 1.25, 0.75, 0.6 }, sun = { 0.5, 0.46, 0.4 }, ambient = 0.7, fog = 1.6 }

function OC.enter(P)
    OC.npcs, OC.lights, OC.pubs, OC.night_added = {}, {}, {}, {}
    OC.state = nil
    local t = OC.sky_time(G.floorgen.frac())
    local c0 = OC.sky_colours(t)
    sky.set{ time = t, speed = 0, zenith = c0.zenith, horizon = c0.horizon, ground = c0.ground, tint = PALETTE.tint, fog_tint = PALETTE.fog_tint, sun = PALETTE.sun, ambient = PALETTE.ambient, fog = PALETTE.fog, blend = 2 }
    OC.state = (t >= 0.5) and "night" or "day"
end

function OC.leave()
    OC.npcs, OC.lights, OC.pubs, OC.night_added = {}, {}, {}, {}
    sky.set{ time = 0.75, speed = 0, tint = false, fog_tint = false, sun = false, ambient = false, zenith = false, horizon = false, ground = false, fog = 1, blend = 0 }
end

-- ---------------------------------------------------------------------------------------------- NPCs
local NPC_MODEL = { guard = "models/figures/human_man_warrior.vxm", villager = "models/figures/human_woman_adventurer.vxm", elder = "models/figures/human_man_adventurer.vxm" }
local function spawn_npc(cell, kind, x, z, village, extra)
    local ok, id = pcall(agent.spawn, { x = G.mx(x), y = G.my(0.05), z = G.mz(z), speed = 1.2, model = NPC_MODEL[kind], animation = "auto", turn_smoothing = 6 })
    if not ok then print("overcity: a " .. kind .. " was refused at (" .. string.format("%.1f %.1f", x, z) .. "): " .. tostring(id)); return nil end
    if not id then return nil end
    if kind == "guard" then pcall(model.attach, id, "iron_sword.vxm", "grip_r", { mode = "attach", name = "main_hand" }) end
    local l = OC.npcs[cell]
    if not l then l = {}; OC.npcs[cell] = l end
    local n = { id = id, kind = kind, x = x, z = z, village = village }
    if extra then for k, v in pairs(extra) do n[k] = v end end
    l[#l + 1] = n
    return n
end

function OC.drop_cell(id)
    for _, n in ipairs(OC.npcs[id] or {}) do pcall(agent.remove, n.id) end
    OC.npcs[id] = nil
    for i = #OC.pubs, 1, -1 do if OC.pubs[i].cell == id then table.remove(OC.pubs, i) end end
    -- a village goes with its origin cell: out of the list (its lights went with the cell's scope), so that the next visit makes one entry again
    local P = G.floorgen.layout
    for i = #((P and P.villages) or {}), 1, -1 do
        local v = P.villages[i]
        if v.cell == id then
            local gone = {}
            for _, nm in ipairs(v.lights or {}) do gone[nm] = true end
            for k = #OC.lights, 1, -1 do if gone[OC.lights[k]] then table.remove(OC.lights, k) end end
            table.remove(P.villages, i)
        end
    end
end

-- the NPC in front of the player within 3 m (E)
function OC.npc_in_front()
    local px, py, pz = player.pos()
    local fx, fy, fz = player.forward()
    local best, bd
    local ids = {}
    for cell in pairs(OC.npcs) do ids[#ids + 1] = cell end
    table.sort(ids)
    for _, cell in ipairs(ids) do
        for _, n in ipairs(OC.npcs[cell]) do
            local info = agent.info(n.id)
            if info then
                local dx, dz = info.x - px, info.z - pz
                local d = math.sqrt(dx * dx + dz * dz)
                local dot = (dx * fx + dz * fz) / max(d, 0.01)
                if d < 3.0 and (dot > 0.3 or d < 1.4) and (not bd or d < bd) then best, bd = n, d end
            end
        end
    end
    return best
end

local CLUES = { "oc.clue1", "oc.clue2", "oc.clue3" }
function OC.talk(n)
    local A = G.announcer
    local s = G.state
    if n.kind == "guard" then A.say_key("oc.guard", { prio = 1, key = "guard", cooldown = 300 }); return true end
    -- a villager: one clue of the quest from every village
    s.quest = s.quest or { clues = {} }
    if s.flags.quest_why then A.say_key("oc.villager_done", { prio = 1, key = "villager", cooldown = 300 }); return true end
    if not s.quest.clues[n.village] then
        local k = 0; for _ in pairs(s.quest.clues) do k = k + 1 end
        s.quest.clues[n.village] = k + 1
        A.say_key(CLUES[min(3, k + 1)], { prio = 2 })
        if k + 1 >= 3 then OC.quest_done() end
        G.save()
    else
        A.say_key("oc.villager_again", { prio = 1, key = "villager", cooldown = 300 })
    end
    return true
end

function OC.clue_count()
    local k = 0
    for _ in pairs((G.state.quest or {}).clues or {}) do k = k + 1 end
    return k
end

function OC.quest_done()
    local s, A = G.state, G.announcer
    s.flags.quest_why = true
    A.say_key("oc.quest_done", { prio = 3 })
    if G.show then G.show.score(60, nil) end
    G.floorgen.refresh_pits()
end

-- ---------------------------------------------------------------------------------------------- buttons and stones
local function button(id, x0, y0, z0, x1, y1, z1, prompt, on_press, active)
    local node = events.button{ name = id, box = { G.wx(x0), G.wy(y0), G.wz(z0), G.wx(x1) - 1, G.wy(y1) - 1, G.wz(z1) - 1 }, prompt = prompt, on = "neon", off = "gold", press_ticks = 8 }
    events.on(node, "pressed", on_press)
    G.traps.add_interact(id, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, prompt, 2.8, active)
end

-- a locator stone tells the way: the nearest pub, the nearest village, the cells of the floor
function OC.locator_read(x, z)
    local P = G.floorgen.layout
    local A = G.announcer
    local function nearest(kind)
        local best, bd
        for _, id in ipairs(P.order) do
            local r = P.rooms[id]
            if r.theme == kind then
                local d = G.dist2(x, z, r.x + r.w / 2, r.z + r.d / 2)
                if not bd or d < bd then best, bd = r, d end
            end
        end
        return best, bd
    end
    local pubd
    for _, v in ipairs(P.villages or {}) do
        local d = G.dist2(x, z, v.pub.cx, v.pub.cz)
        if not pubd or d < pubd then pubd = d end
    end
    local rest, rd = nearest("rest")
    local safe, sd = nearest("safe")
    local lines = {}
    if pubd then lines[#lines + 1] = string.format(tr("oc.loc_pub"), floor(pubd / 32 + 0.5)) end
    if sd then lines[#lines + 1] = string.format(tr("oc.loc_safe"), floor(sd / 32 + 0.5)) end
    if rd then lines[#lines + 1] = string.format(tr("oc.loc_rest"), floor(rd / 32 + 0.5)) end
    A.say(tr("oc.locator") .. " " .. table.concat(lines, " "), { prio = 2, key = "locator", cooldown = 120 })
end

-- ---------------------------------------------------------------------------------------------- a village (made once, with the origin cell of its 2 x 2 cells)
function OC.make_village(P, sup, origin_id)
    local CG, H = G.floorgen.cg()
    local ox, oz = sup.ci * 32, sup.cj * 32
    local vid = "v" .. sup.ci .. "_" .. sup.cj
    local plan = deco_village_plan(function(salt) return deco_rng(H, P.floor, sup.ci, sup.cj, salt or 1) end)
    local dk = G.gen.rules.dark()
    P.villages = P.villages or {}
    local v = { id = vid, ox = ox, oz = oz, plan = plan, cell = origin_id, lights = {} }
    for i = #P.villages, 1, -1 do if P.villages[i].id == vid then table.remove(P.villages, i) end end      -- (one entry per village)
    local n = 0
    local function lamp(x, z, y)
        n = n + 1
        local name = vid .. "_l" .. n
        G.torch(x, y or 3.4, z, { preset = "torch", reach = 14, far = 40, intensity = 16 * dk, name = name })
        OC.lights[#OC.lights + 1] = name
        v.lights[#v.lights + 1] = name
        emitter.enable(name, OC.is_night())
    end
    -- the buildings
    for _, b in ipairs(plan.buildings) do
        local d = b.door
        local dx, dz = (d.side == "E") and (b.x1 + 1.2) or (b.x0 - 1.2), d.pos
        lamp(ox + dx, oz + dz - 1.8, 2.8)
        if b.kind == "pub" then
            v.pub = { x0 = ox + b.x0, z0 = oz + b.z0, x1 = ox + b.x1, z1 = oz + b.z1, cx = ox + b.cx, cz = oz + b.cz, id = vid .. "_pub", cell = origin_id }
            OC.pubs[#OC.pubs + 1] = v.pub
            local c, nt, f = b.crystal, b.note, b.fire
            G.torch(ox + f.x, 0.8, oz + f.z, { preset = "campfire", color = { 1, 0.55, 0.2 }, reach = 12, far = 30, name = vid .. "_fire" })
            G.torch(ox + c.x, 2.6, oz + c.z, { preset = "magic_sparks", color = { 0.62, 0.72, 1.0 }, reach = 9, far = 30, name = vid .. "_crystal" })
            G.torch(ox + b.cx, 3.2, oz + b.cz, { preset = "torch", reach = 10, far = 30, intensity = 12 * dk, name = vid .. "_pubcl" })
            button(vid .. "_save", ox + c.x - 0.25, 1.3, oz + c.z - 0.25, ox + c.x + 0.25, 1.9, oz + c.z + 0.25, tr("oc.pub_save"), function() G.save_now() end)
            button(vid .. "_note", ox + nt.x - 0.4, 1.4, oz + nt.z - 0.1, ox + nt.x + 0.4, 1.9, oz + nt.z + 0.15, tr("oc.pub_note"), function() OC.read_note() end)
            G.world.checkpoints[v.pub.id] = { x = ox + b.cx, y = 0.1, z = oz + b.cz + 1.5 }
            local lay, inner = deco_pub_layout(b, function(salt) return deco_rng(H, P.floor, sup.ci, sup.cj, salt or 1) end)
            local nch = 0
            if lay then for _, it in ipairs(lay.items) do
                if it.id == "chain_lamp" and nch < 4 then nch = nch + 1; G.chain_lantern(ox + (it.x0 + it.x1) / 2, inner.h - 0.1, oz + (it.z0 + it.z1) / 2, math.max(1.0, inner.h - 0.1 - 1.75 - 0.4)) end
            end end
        elseif b.kind == "store" then
            local vd = b.vend
            button(vid .. "_vend", ox + vd.x - 0.6, 1.0, oz + vd.z + 0.45, ox + vd.x + 0.6, 1.6, oz + vd.z + 0.65, tr("oc.store"), function()
                if OC.is_night() then G.announcer.say_key("oc.store_closed", { prio = 1, key = "store", cooldown = 300 }) elseif G.shop then G.shop.open() end
            end)
            lamp(ox + b.cx, oz + b.cz, 3.0)
        elseif b.kind == "hall" then
            button(vid .. "_board", ox + b.board.x - 0.8, 1.4, oz + b.board.z - 0.1, ox + b.board.x + 0.8, 2.0, oz + b.board.z + 0.15, tr("oc.board"), function() OC.read_board() end)
        end
    end
    -- the square: lamps at the corners, the locator stones, the well's light
    for k, l in ipairs(plan.locators) do
        lamp(ox + l[1] + ((l[1] < 32) and -1.2 or 1.2), oz + l[2] + ((l[2] < 32) and -1.2 or 1.2), 3.2)
        button(vid .. "_stone" .. k, ox + l[1] - 0.35, 1.3, oz + l[2] - 0.35, ox + l[1] + 0.35, 1.8, oz + l[2] + 0.35, tr("oc.stone"), function() OC.locator_read(ox + l[1], oz + l[2]) end)
    end
    -- the villager (a clue of the quest) by the well, an elder at the pub's door
    local vl = spawn_npc(origin_id, "villager", ox + 36, oz + 28, vid)
    if vl then G.traps.add_interact(vid .. "_talk", vl.x, 1.2, vl.z, tr("oc.talk"), 2.6) end
    v.guards = {}
    P.villages[#P.villages + 1] = v
    OC.guards_set(P, v, origin_id, not OC.is_night())
    return v
end

-- the guards of a village: at its gates by day
function OC.guards_set(P, v, cell, day)
    -- remove the ones that stand there
    local list = OC.npcs[cell] or {}
    for i = #list, 1, -1 do
        if list[i].kind == "guard" then pcall(agent.remove, list[i].id); table.remove(list, i) end
    end
    if not day then return end
    -- one guard inside every gate of the four cells (the doors of the courtyard that lead out)
    local CG = G.floorgen.cg()
    for dj = 0, 1 do for di = 0, 1 do
        local cid = G.floorgen.cid(v.ox // 32 + di, v.oz // 32 + dj)
        local room = P.rooms[cid]
        for _, d in ipairs(P.doors[cid] or {}) do
            local gx, gz
            if d.side == "E" and room.cellrole ~= "x" and room.x + room.w >= v.ox + 58 then gx, gz = room.x + room.w - 2.5, d.pos + 2.6
            elseif d.side == "W" and room.x <= v.ox + 6 then gx, gz = room.x + 2.5, d.pos + 2.6
            elseif d.side == "S" and room.z + room.d >= v.oz + 58 then gx, gz = d.pos + 2.6, room.z + room.d - 2.5
            elseif d.side == "N" and room.z <= v.oz + 6 then gx, gz = d.pos + 2.6, room.z + 2.5 end
            if gx then spawn_npc(cell, "guard", gx, gz, v.id) end
        end
    end end
end

function OC.read_note()
    local P = G.floorgen.layout
    local A = G.announcer
    local id = P.free_list and P.free_list[1]
    if not id then return end
    G.state.flags["known_" .. id] = true
    local r = P.rooms[id]
    A.say(string.format(tr("oc.note"), r.ci + 1, r.cj + 1), { prio = 3 })
    G.save()
end

function OC.read_board()
    local A = G.announcer
    if G.state.flags.quest_why then A.say_key("oc.board_done", { prio = 2, key = "board", cooldown = 300 })
    else A.say(string.format(tr("oc.board_text"), OC.clue_count()), { prio = 2, key = "board", cooldown = 300 }) end
end

-- ---------------------------------------------------------------------------------------------- the night pool
local NIGHT_KINDS = { "imp", "spitter", "slime_toxic", "bandit", "rat" }
function OC.add_night(P, room)
    if room.cellrole ~= "room" and room.cellrole ~= "ante" then return end
    if OC.night_added[room.id] then return end
    OC.night_added[room.id] = true
    local _, H = G.floorgen.cg()
    local rng = deco_rng(H, P.floor, room.ci, room.cj, 12)
    local list = G.world.populate_list[room.id]
    if not list then list = {}; G.world.populate_list[room.id] = list end
    for i = 1, 2 do
        local kind = NIGHT_KINDS[1 + floor(rng.next() * #NIGHT_KINDS) % #NIGHT_KINDS]
        local x = room.x + 3 + rng.next() * (room.w - 6)
        local z = room.z + 3 + rng.next() * (room.d - 6)
        list[#list + 1] = { kind, x, z, 0, hp = 1.2, name = nil }
        if G.enemies.spawned[room.id] then G.enemies.spawn_entry(room.id, list, #list) end
    end
end

function OC.cell_made(P, room)
    if not OC.on_floor() then return end
    if OC.is_night() then OC.add_night(P, room) end
    -- a village is made by the origin cell of its 2 x 2
    if room.theme == "village" then
        local CG = G.floorgen.cg()
        local sup = CG.super_of(P.ctx, room.ci, room.cj)
        if sup and sup.ci == room.ci and sup.cj == room.cj then OC.make_village(P, sup, room.id) end
    elseif room.theme == "connector" then
        -- a locator stone in the middle of the junction
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        button(room.id .. "_stone", cx - 0.3, 1.3, cz - 0.3, cx + 0.3, 1.8, cz + 0.3, tr("oc.stone"), function() OC.locator_read(cx, cz) end)
    end
end

-- ---------------------------------------------------------------------------------------------- the clock
function OC.tick(t)
    if not OC.on_floor() then return end
    local P = G.floorgen.layout
    if t % 60 == 0 then
        local f = G.floorgen.frac()
        local st = OC.sky_time(f)
        local c = OC.sky_colours(st)
        sky.set{ time = st, speed = 0, zenith = c.zenith, horizon = c.horizon, ground = c.ground }
        local state = (st >= 0.5) and "night" or "day"
        if state ~= OC.state then
            OC.state = state
            if state == "night" then
                G.announcer.say_key("oc.dusk", { prio = 3 })
                for _, id in ipairs(G.floorgen.made_list) do
                    OC.add_night(P, P.rooms[id])
                end
                for _, v in ipairs(P.villages or {}) do OC.guards_set(P, v, G.floorgen.cid(v.ox // 32, v.oz // 32), false) end
                for _, name in ipairs(OC.lights) do pcall(emitter.enable, name, true) end
            else
                G.announcer.say_key("oc.dawn", { prio = 3 })
                for _, v in ipairs(P.villages or {}) do OC.guards_set(P, v, G.floorgen.cid(v.ox // 32, v.oz // 32), true) end
                for _, name in ipairs(OC.lights) do pcall(emitter.enable, name, false) end
            end
        end
    end
end

-- is the player in a pub (a safe room by the rect of the building)
function OC.in_pub()
    if not OC.on_floor() or G.floorgen.safe_closed() then return nil end
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    for _, p in ipairs(OC.pubs) do
        if lx > p.x0 + 0.5 and lx < p.x1 - 0.5 and lz > p.z0 + 0.5 and lz < p.z1 - 0.5 then return p end
    end
    return nil
end
