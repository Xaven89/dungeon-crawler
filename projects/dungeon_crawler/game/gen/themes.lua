-- gen/themes: who lives in a room of a big floor and what stands around them. A theme: things(room, ctx) (made when the cell comes alive: lights, hazards, the population), names for the signs and the announcer.
-- The decoration itself (pillars, pools, shelves, the loot crates' voxels) is the region hook's (gen/deco.lua): the things here ask the same pure `deco_*_plan` functions for where it stands.
-- A room (F.layout.rooms[id]): x, z, w, d, h in the floor's local metres, ci / cj the cell, info the plan's cell (info.room: the room in the cell's own coordinates, what deco_* takes).
Game = Game or {}
local G = Game
local F = G.floorgen
local L = G.gen.layout
local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------------------------- who lives here
local ROSTER = {
    { "rat", 1, 3 }, { "slime", 1, 3 }, { "intern", 1, 2 }, { "goblin", 1, 2 },
    { "slime_toxic", 2, 2 }, { "spitter", 2, 2 }, { "bandit", 2, 2 }, { "orc", 2, 2 },
    { "imp", 3, 2 }, { "samurai", 4, 1.5 }, { "troll", 4, 2 },
}
local AFFIXES = { "swift", "armored", "explosive" }
F.AFFIXES = AFFIXES
function F.pick_kind(rng, floor_n)
    local total = 0
    for _, e in ipairs(ROSTER) do if floor_n >= e[2] then total = total + e[3] end end
    local x = rng.next() * total
    for _, e in ipairs(ROSTER) do
        if floor_n >= e[2] then x = x - e[3]; if x <= 0 then return e[1] end end
    end
    return "rat"
end

-- the plan functions of deco.lua work in the cell's own coordinates (that is what the hook has); the things want the floor's: shift by the cell's origin
function F.off(room) return room.ci * 32, room.cj * 32 end
function F.lroom(room) return room.info.room end

-- n enemies somewhere in the room (3 m from the walls, 2.5 m from each other, 5 m from the doors). opts: kinds = { {kind, weight} } instead of the floor's roster, allow(x, z) -> bool,
-- own = true: this theme's own cast (a warlord's retinue), not the quadrant's. With the plan's population of the cell (ctx.cellpop: the budget by distance from the arrival, one mob theme per
-- quadrant) the number and the kinds come from the plan.
function F.populate(room, ctx, rng, n, opts)
    opts = opts or {}
    local plist = (not opts.own) and ctx.cellpop and ctx.cellpop.list or nil
    if plist then n = #plist end
    local placed = {}
    local tries = 0
    -- the layout's spots first (a guard behind the bar, an ambush between the shelves): in a shuffled order, then the random places for the rest
    if opts.spots and #opts.spots > 0 then
        local order = {}
        for i = 1, #opts.spots do order[i] = i end
        for i = #order, 2, -1 do local j = rng.int(1, i); order[i], order[j] = order[j], order[i] end
        for _, k in ipairs(order) do
            local sp = opts.spots[k]
            if #placed >= n then break end
            local kind_ok = opts.spot_kinds == nil and sp.kind ~= "boss"
            if opts.spot_kinds then for _, kk in ipairs(opts.spot_kinds) do if kk == sp.kind then kind_ok = true end end end
            if kind_ok and (not opts.allow or opts.allow(sp.x, sp.z)) and not ctx.near_door(room, sp.x, sp.z, 3.5) then placed[#placed + 1] = { sp.x, sp.z } end
        end
    end
    while #placed < n and tries < n * 40 do
        tries = tries + 1
        local m = opts.margin or 3
        local x = room.x + m + rng.next() * (room.w - 2 * m)
        local z = room.z + m + rng.next() * (room.d - 2 * m)
        local ok = not ctx.near_door(room, x, z, 5) and (not opts.allow or opts.allow(x, z))
        if ok then for _, q in ipairs(placed) do if G.dist2(x, z, q[1], q[2]) < 2.5 then ok = false; break end end end
        if ok then placed[#placed + 1] = { x, z } end
    end
    for i, q in ipairs(placed) do
        local kind, extra
        if plist then
            kind = plist[i].kind
            if plist[i].elite then extra = { affix = AFFIXES[1 + (room.index + i) % 3] } end
        else
            if opts.kinds then
                local total = 0; for _, k in ipairs(opts.kinds) do total = total + k[2] end
                local x = rng.next() * total
                for _, k in ipairs(opts.kinds) do x = x - k[2]; if x <= 0 then kind = k[1]; break end end
            end
            if ctx.floor >= 2 and rng.next() < min(0.3, 0.07 * (ctx.floor - 1)) then extra = { affix = AFFIXES[rng.int(1, 3)] } end
        end
        ctx.add(room, kind or F.pick_kind(rng, ctx.floor), q[1], q[2], opts.y or 0, extra)
    end
    return #placed
end

-- allow(x, z): not inside any of the rectangles { x0, z0, x1, z1 } padded by `pad`
function F.clear_of(rects, pad)
    return function(x, z)
        for _, q in ipairs(rects or {}) do if x > q[1] - pad and x < q[3] + pad and z > q[2] - pad and z < q[4] + pad then return false end end
        return true
    end
end

-- the layout grammar's view of a room for the game (gen/furnish.lua: the same pure plan as the hook): the layout, the blocking footprints and the spots in the floor's coordinates;
-- nil for a theme without a row
function F.furnished(room, ctx)
    local lay = deco_layout(room.theme, F.lroom(room), F.local_doors(room), ctx.mk(room), ctx.floor)
    if not lay then return nil end
    local ox, oz = F.off(room)
    local rects, spots = {}, {}
    for _, it in ipairs(lay.items) do if it.blocks then rects[#rects + 1] = { it.x0 + ox, it.z0 + oz, it.x1 + ox, it.z1 + oz } end end
    for _, sp in ipairs(lay.spots) do spots[#spots + 1] = { x = sp.x + ox, z = sp.z + oz, kind = sp.kind } end
    return lay, rects, spots
end

-- where the boss of an arena stands: the dais of its layout (the middle of the room without one), in the floor's coordinates
function F.boss_spot(room, ctx)
    local lay = deco_layout(room.theme, F.lroom(room), F.local_doors(room), ctx.mk(room), ctx.floor)
    local ox, oz = F.off(room)
    if lay then for _, sp in ipairs(lay.spots) do if sp.kind == "boss" then return sp.x + ox, sp.z + oz end end end
    return room.x + room.w / 2, room.z + room.d / 2
end

-- wall sconces: the plan is deco.lua's (the plates are voxels of the hook), the flames are made here; no flame within 3 m of a door
function F.sconces(room, ctx, step, y)
    local dk = G.gen.rules.dark()
    local ox, oz = F.off(room)
    for _, sc in ipairs(deco_sconce_plan(room.theme, F.lroom(room), F.local_doors(room))) do
        G.sconce(sc.x + ox, sc.y, sc.z + oz, sc.face, { intensity = 11 * dk, far = 24 })
    end
end

-- hanging lamps on a grid, about one per 60 m2
function F.lamps(room, intensity, reach)
    local nx, nz = max(1, floor(room.w / 8)), max(1, floor(room.d / 8))
    for i = 1, nx do for j = 1, nz do
        G.lamp(room.x + room.w * (i - 0.5) / nx, room.z + room.d * (j - 0.5) / nz, room.h, 1.2, { reach = reach or 12, far = 24, intensity = (intensity or 11) * G.gen.rules.dark() })
    end end
end

-- how many enemies a room of this size holds on this floor (the fallback without the plan's population)
function F.head_count(room, floor_n, rng)
    local n = floor(room.w * room.d / 75) + rng.int(0, 2) + floor((floor_n - 1) / 2)
    return max(3, min(floor(n * G.gen.rules.count() + 0.5), 14))
end

-- ---------------------------------------------------------------------------------------------- the rooms that are not fights: safe rooms, the rest stop, the stairwell, connectors
F.register("safe", { names = { "Intake Landing", "The Lounge", "Safe Harbour", "Mild Relief" }, things = function(room, ctx) G.gen.safe.things(room, ctx, {}) end })
F.register("rest", {
    names = { "Rest Stop", "The Cot Room", "Break Room", "Quiet Corner" },
    things = function(room, ctx)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        G.torch(cx, 2.4, cz, { preset = "campfire", color = { 1, 0.6, 0.25 }, reach = 12, far = 24, name = room.id .. "_fire" })
        G.dust(room.id .. "_dust", "dust_motes", { G.mx(cx), G.my(2), G.mz(cz) }, { 4, 2, 4 })
    end,
})
F.register("guild", {
    names = { "The Guild Classroom", "Orientation Annex", "Training Hall" },
    things = function(room, ctx) F.sconces(room, ctx, 8, 3.3); F.lamps(room, 13, 11) end,
})
F.register("connector", {
    names = { "A Corridor", "Service Junction", "The Landing", "Utility Closet" },
    things = function(room, ctx)
        G.torch(room.x + room.w / 2, 2.8, room.z + room.d / 2, { preset = "torch", reach = 9, far = 22, intensity = 9 * G.gen.rules.dark(), name = room.id .. "_c" })
    end,
})
F.register("borough", {
    names = { "The Courtyard", "Borough Square", "The Rotunda" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.sconces(room, ctx, 8, 3.4); F.lamps(room, 13, 12)
        F.populate(room, ctx, r, 4, { own = true, kinds = { { "orc", 3 }, { "bandit", 3 }, { "goblin", 3 } } })
    end,
})
-- floor 3: the village (the quarter rooms of its 2 x 2: lights come with the village's own things (gen/overcity.lua)), the park (the fortress of the park boss: guards in the quarters like the borough's)
F.register("village", { names = { "Village Green", "The Hamlet", "Market Row", "Old Town" }, things = function(room, ctx) end })
F.register("park", {
    names = { "The Park", "Bone Gardens", "The Fairground" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.populate(room, ctx, r, 4, { own = true, kinds = { { "orc", 3 }, { "bandit", 3 }, { "goblin", 3 } } })
    end,
})
F.register("stairs_free", {
    names = { "Stairwell", "Service Stairs", "The Way Down" },
    things = function(room, ctx)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        G.torch(cx, 1.4, cz, { preset = "campfire", color = { 1, 0.8, 0.4 }, reach = 14, far = 26, name = room.id .. "_glow" })
        F.sconces(room, ctx, 8, 3.2)
        local id = room.id .. "_down"
        -- the foot of the stair (the east half of the hole, 2.25 m down)
        local box = { G.wx(cx - 0.5), G.wy(-2.2), G.wz(cz - 1.5), G.wx(cx + 3.0) - 1, G.wy(-1.0), G.wz(cz + 1.5) - 1 }
        local vol = events.volume{ name = id, box = box, player = true, bodies = false }
        events.on(vol, "enter", function() F.stairs_enter(room.id) end)
        G.traps.add_interact(id, cx - 3.4, 0.4, cz, tr("ui.descend", G.run.next_floor(ctx.floor) or "?"), 3.6, function() return F.stairs_open(room.id) end)
    end,
})

-- ---------------------------------------------------------------------------------------------- arena: a neighbourhood boss (a miniboss and his guards)
F.register("arena", {
    names = { "The Manager's Office", "The Corner Office", "The Compliance Floor", "The Board Room" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            G.brazier(cx + math.cos(a) * 9, cz + math.sin(a) * 7, { reach = 16, far = 26 })
        end
        G.lamp(cx, cz, room.h, 2.0, { reach = 18, far = 26, intensity = 16 * G.gen.rules.dark() })
        -- the boss himself is made by G.boss.begin when the player steps in (F.lair_of): here only his guards
        local lay, rects, spots = F.furnished(room, ctx)
        local bx, bz = F.boss_spot(room, ctx)
        F.populate(room, ctx, r, F.STAGING.quarter.guards, { own = true, kinds = { { "orc", 4 }, { "bandit", 3 }, { "goblin", 3 } }, spots = spots, spot_kinds = { "guard" },
                   allow = function(x, z) return G.dist2(x, z, cx, cz) > 5 and G.dist2(x, z, bx, bz) > 3 and F.clear_of(rects, 0.45)(x, z) end })
    end,
})
F.register("ante", {
    names = { "The Antechamber", "Waiting Room B", "The Vestibule" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.sconces(room, ctx, 8, 3.3); F.lamps(room, 14, 12)
        local lay, rects, spots = F.furnished(room, ctx)
        F.populate(room, ctx, L.make_rng(ctx.seed, ctx.floor, 2000 + room.index), 3, { allow = F.clear_of(rects, 0.45), spots = spots, spot_kinds = { "guard", "idle" } })
    end,
})

-- ---------------------------------------------------------------------------------------------- hall: the plain fighting room
F.register("hall", {
    names = { "Hall of Mild Peril", "The Waiting Room", "Hall of Pending Approvals", "The Open Plan" },
    things = function(room, ctx)
        F.sconces(room, ctx)
        F.lamps(room, 15, 13)
        local lay, rects, spots = F.furnished(room, ctx)
        local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
        F.populate(room, ctx, r2, F.head_count(room, ctx.floor, r2), { allow = F.clear_of(rects, 0.45), spots = spots })
    end,
})

-- ---------------------------------------------------------------------------------------------- warlord: a hall with a miniboss and his retinue
F.register("warlord", {
    names = { "The Warlord's Lounge", "Middle Management", "The Regional Office", "Hall of Brutal Efficiency" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local cx = room.x + room.w / 2
        F.sconces(room, ctx, 8, 3.3); F.lamps(room, 15, 12)
        G.brazier(cx - 5, room.z + room.d - 3, { reach = 12, far = 24 }); G.brazier(cx + 5, room.z + room.d - 3, { reach = 12, far = 24 })
        local kind = (ctx.floor >= 3) and "cyclops" or "troll"
        local extra = { hp = (kind == "troll") and 1.8 or 1 }
        -- from floor 3 a rival crawler may hold the first warlord room of the floor (the one you did not kill follows you from floor to floor)
        if ctx.floor >= 3 and ctx.first_of("warlord") and G.hash(ctx.seed % 100000, ctx.floor, 3) < 0.7 then
            local names = { "Skullface Tamara", "Reginald Redundant", "Big Dolly", "Wendell the Unpaid", "Madame Overdraft", "The Intern Who Knew Too Much" }
            kind = ({ "rival_samurai", "rival_adventurer", "rival_witch" })[1 + floor(G.hash(ctx.floor, room.index, 5) * 3) % 3]
            extra = { name = names[1 + floor(G.hash(ctx.seed % 100000, ctx.floor, 77) * #names) % #names], hp = 1 }
            if G.state.rival then extra.name = G.state.rival; extra.rematch = true; extra.hp = 1.3 end
        end
        ctx.add(room, kind, cx, room.z + room.d - 8, 0, extra)
        F.populate(room, ctx, r, 3 + floor(ctx.floor / 2), { own = true, kinds = { { "orc", 4 }, { "bandit", 3 }, { "imp", 2 } }, allow = function(x, z)
            if z >= room.z + room.d - 10 then return false end
            for _, dx in ipairs({ -8, 8 }) do for k = 1, 2 do if G.dist2(x, z, cx + dx, room.z + room.d * k / 3) < 1.8 then return false end end end
            return true
        end })
    end,
})
