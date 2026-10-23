-- gen/themes: what a generated room looks like and who lives in it. Each theme: voxels(room, ctx) (only while the floor is built), things(room, ctx) (every start: lights, hazards, crates,
-- the population), weight(floor, room) for the pick, names for the signs and the announcer. Rooms of the plan: x, z, w, d, h (metres, local), index, role.
Game = Game or {}
local G = Game
local F = G.floorgen
local L = G.gen.layout
local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------------------------- who lives here
-- weights by floor: { kind, first_floor, weight }
local ROSTER = {
    { "rat", 1, 3 }, { "slime", 1, 3 }, { "intern", 1, 2 }, { "goblin", 1, 2 },
    { "slime_toxic", 2, 2 }, { "spitter", 2, 2 }, { "bandit", 2, 2 }, { "orc", 2, 2 },
    { "imp", 3, 2 }, { "samurai", 4, 1.5 }, { "troll", 4, 2 },
}
local AFFIXES = { "swift", "armored", "explosive" }
function F.pick_kind(rng, floor_n)
    local total = 0
    for _, e in ipairs(ROSTER) do if floor_n >= e[2] then total = total + e[3] end end
    local x = rng.next() * total
    for _, e in ipairs(ROSTER) do
        if floor_n >= e[2] then x = x - e[3]; if x <= 0 then return e[1] end end
    end
    return "rat"
end

-- n enemies somewhere in the room (3 m from the walls, 2.5 m from each other, 5 m from the doors). opts: kinds = { {kind, weight} } instead of the floor's roster, allow(x, z) -> bool, elite = n of them tougher
function F.populate(room, ctx, rng, n, opts)
    opts = opts or {}
    local placed = {}
    local tries = 0
    while #placed < n and tries < n * 40 do
        tries = tries + 1
        local m = opts.margin or 3
        local x = room.x + m + rng.next() * (room.w - 2 * m)
        local z = room.z + m + rng.next() * (room.d - 2 * m)
        local ok = not ctx.near_door(room, x, z, 5) and (not opts.allow or opts.allow(x, z))
        if ok then for _, q in ipairs(placed) do if G.dist2(x, z, q[1], q[2]) < 2.5 then ok = false; break end end end
        if ok then placed[#placed + 1] = { x, z } end
    end
    for _, q in ipairs(placed) do
        local kind
        if opts.kinds then
            local total = 0; for _, k in ipairs(opts.kinds) do total = total + k[2] end
            local x = rng.next() * total
            for _, k in ipairs(opts.kinds) do x = x - k[2]; if x <= 0 then kind = k[1]; break end end
        end
        local extra
        if ctx.floor >= 2 and rng.next() < min(0.3, 0.07 * (ctx.floor - 1)) then extra = { affix = AFFIXES[rng.int(1, 3)] } end
        ctx.add(room, kind or F.pick_kind(rng, ctx.floor), q[1], q[2], opts.y or 0, extra)
    end
    return #placed
end

-- wall sconces along the four walls, none within 3 m of a door
function F.sconces(room, ctx, step, y)
    step = step or 8; y = y or 3.3
    for x = room.x + 4, room.x + room.w - 3, step do
        if not ctx.near_door(room, x, room.z, 3) then G.sconce(x, y, room.z, "+z") end
        if not ctx.near_door(room, x, room.z + room.d, 3) then G.sconce(x, y, room.z + room.d, "-z") end
    end
    for z = room.z + 4, room.z + room.d - 3, step do
        if not ctx.near_door(room, room.x, z, 3) then G.sconce(room.x, y, z, "+x") end
        if not ctx.near_door(room, room.x + room.w, z, 3) then G.sconce(room.x + room.w, y, z, "-x") end
    end
end

-- hanging lamps on a grid, about one per 60 m2
function F.lamps(room, intensity, reach)
    local nx, nz = max(1, floor(room.w / 8)), max(1, floor(room.d / 8))
    for i = 1, nx do for j = 1, nz do
        G.lamp(room.x + room.w * (i - 0.5) / nx, room.z + room.d * (j - 0.5) / nz, room.h, 1.2, { reach = reach or 12, intensity = intensity })
    end end
end

-- how many enemies a room of this size holds on this floor
function F.head_count(room, floor_n, rng)
    local n = floor(room.w * room.d / 75) + rng.int(0, 2) + floor((floor_n - 1) / 2)
    return max(3, min(n, 11))
end

-- ---------------------------------------------------------------------------------------------- the safe rooms and the lair are drawn by gen/safe.lua; these only name them
F.register("arrival", { names = { "Intake Landing" }, weight = function() return 0 end })
F.register("stairwell", { names = { "Stairwell" }, weight = function() return 0 end })

-- ---------------------------------------------------------------------------------------------- lair: the boss room (a big hall with a ring of pillars)
F.register("lair", {
    names = { "The Manager's Office", "The Corner Office", "The Compliance Floor", "The Board Room" },
    weight = function() return 0 end,
    voxels = function(room, ctx)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "marble", wall = "dungeon_brick", ceil = "dungeon_brick", wtex = "blocks", ctex = "planks" }
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        G.ring(cx, cz, 7.5, 8.2, 0, 0.1, "gold")
        G.ring(cx, cz, 11.5, 12.0, 0, 0.1, "gold")
        for i = 0, 7 do
            local a = i * math.pi / 4 + math.pi / 8
            G.pillar(cx + math.cos(a) * 11, cz + math.sin(a) * 9, 0.7, 0, room.h, "marble", "blocks")
        end
    end,
    things = function(room, ctx)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            G.brazier(cx + math.cos(a) * 11, cz + math.sin(a) * 9, { reach = 16 })
        end
        G.dust(room.id .. "_dust", "dust_motes", { G.mx(cx), G.my(room.h / 2), G.mz(cz) }, { 12, room.h / 2, 10 })
    end,
})

-- ---------------------------------------------------------------------------------------------- hall: the plain fighting room
F.register("hall", {
    names = { "Hall of Mild Peril", "The Waiting Room", "Hall of Pending Approvals", "The Open Plan" },
    weight = function(floor_n, room) return 3 end,
    voxels = function(room, ctx)
        local r = ctx.rng(room)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "flagstone", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "tiles", wtex = "blocks", ctex = "planks" }
        -- a carpet down the long axis
        if room.w >= room.d then G.fill(room.x + 1, 0, room.z + room.d / 2 - 2, room.x + room.w - 1, 0.05, room.z + room.d / 2 + 2, "carpet")
        else G.fill(room.x + room.w / 2 - 2, 0, room.z + 1, room.x + room.w / 2 + 2, 0.05, room.z + room.d - 1, "carpet") end
        -- rows of pillars
        local nx, nz = floor(room.w / 8), floor(room.d / 8)
        for i = 1, nx do for j = 1, nz do
            if r.next() < 0.7 then G.pillar(room.x + room.w * i / (nx + 1), room.z + room.d * j / (nz + 1), 0.7, 0, room.h, "marble", "blocks") end
        end end
        for x = room.x + 3, room.x + room.w - 3, 6 do G.fill(x, room.h - 0.8, room.z, x + 0.5, room.h, room.z + room.d, "dark_wood") end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.sconces(room, ctx)
        F.lamps(room, 15, 13)
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r))
        if r.next() < 0.5 then ctx.crate(room, ctx.floor >= 3 and "silver" or "bronze", room.x + 3, room.z + 3, "+z") end
    end,
})

-- ---------------------------------------------------------------------------------------------- warlord: a hall with a miniboss and his retinue (a gold crate behind them)
F.register("warlord", {
    names = { "The Warlord's Lounge", "Middle Management", "The Regional Office", "Hall of Brutal Efficiency" },
    weight = function(f, room) return (f >= 2 and room.w >= 20 and room.d >= 18) and (0.8 + 0.25 * f) or 0 end,
    voxels = function(room, ctx)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "obsidian", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "tiles", wtex = "blocks", ctex = "planks" }
        local cx = room.x + room.w / 2
        G.fill(cx - 3, 0, room.z + room.d - 6, cx + 3, 0.5, room.z + room.d - 1, "dark_wood"); G.fill(cx - 3, 0.5, room.z + room.d - 6, cx + 3, 0.55, room.z + room.d - 1, "carpet")
        for _, dx in ipairs({ -8, 8 }) do for k = 1, 2 do G.pillar(cx + dx, room.z + room.d * k / 3, 0.8, 0, room.h, "dungeon_brick", "blocks") end end
        for i = 1, 3 do G.fill(room.x + room.w * i / 4 - 0.6, 3.2, room.z + 0.05, room.x + room.w * i / 4 + 0.6, 6, room.z + 0.2, "neon_red") end        -- banners
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        local cx = room.x + room.w / 2
        F.sconces(room, ctx, 8, 3.3); F.lamps(room, 15, 12)
        G.brazier(cx - 5, room.z + room.d - 3, { reach = 12 }); G.brazier(cx + 5, room.z + room.d - 3, { reach = 12 })
        ctx.crate(room, "gold", cx - 0.6, room.z + room.d - 2, "-z", 0.55)
        local kind = (ctx.floor >= 3) and "cyclops" or "troll"
        ctx.add(room, kind, cx, room.z + room.d - 8, 0, { hp = (kind == "troll") and 1.8 or 1 })
        F.populate(room, ctx, r, 3 + floor(ctx.floor / 2), { kinds = { { "orc", 4 }, { "bandit", 3 }, { "imp", 2 } }, allow = function(x, z) return z < room.z + room.d - 10 end })
    end,
})
