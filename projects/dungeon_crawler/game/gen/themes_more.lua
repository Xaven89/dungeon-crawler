-- gen/themes_more: the rooms of a floor besides the plain hall. Rules for every theme: the 4 m along the walls stay free (the doors are anywhere on a wall), decoration goes inside; what hurts
-- (lava, sludge) lies in the middle with a walkway around it and stepping stones to a prize.
Game = Game or {}
local G = Game
local F = G.floorgen
local T = G.traps
local floor, max, min = math.floor, math.max, math.min

local function inner(room, m) return room.x + m, room.z + m, room.x + room.w - m, room.z + room.d - m end

-- a sunken pool in the middle of the room with a stone island (the reward) and stepping stones to it; fluid = a material name; returns the pool rectangle and the island
local function pool(room, ctx, fluid, depth, surface_y)
    local x0, z0, x1, z1 = inner(room, 4)
    G.clear(x0, -depth, z0, x1, 0, z1)
    G.fill(x0 - 0.25, -depth, z0, x0, 0, z1, "obsidian"); G.fill(x1, -depth, z0, x1 + 0.25, 0, z1, "obsidian")
    G.fill(x0, -depth, z0 - 0.25, x1, 0, z0, "obsidian"); G.fill(x0, -depth, z1, x1, 0, z1 + 0.25, "obsidian")
    G.fill(x0, -depth - 0.3, z0, x1, -depth, z1, "obsidian")
    G.fill(x0, -depth, z0, x1, surface_y, z1, fluid)
    -- the island in the middle and a line of stepping stones from the nearest side
    local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    G.fill(cx - 1.2, -depth, cz - 1.2, cx + 1.2, 0.0, cz + 1.2, "obsidian", "tiles")
    local sx = (x1 - x0) >= (z1 - z0)
    local n = floor(((sx and (x1 - x0) or (z1 - z0)) / 2 - 1.2) / 1.7)
    for i = 1, max(1, n) do
        local d = 1.2 + i * 1.7 - 0.5
        if sx then G.fill(cx - d - 0.45, -depth, cz - 0.45, cx - d + 0.45, 0, cz + 0.45, "obsidian") else G.fill(cx - 0.45, -depth, cz - d - 0.45, cx + 0.45, 0, cz - d + 0.45, "obsidian") end
    end
    return { x0 = x0, z0 = z0, x1 = x1, z1 = z1 }, { x = cx, z = cz }
end
local function outside(pl) return function(x, z) return x < pl.x0 - 1 or x > pl.x1 + 1 or z < pl.z0 - 1 or z > pl.z1 + 1 end end
local function pool_rect(room) local x0, z0, x1, z1 = inner(room, 4); return { x0 = x0, z0 = z0, x1 = x1, z1 = z1 } end

-- ---------------------------------------------------------------------------------------------- furnace: a lava pool
F.register("furnace", {
    names = { "The Boiler Gallery", "Furnace of Consequences", "The Hot Seat", "Department of Heat" },
    weight = function(f, room) return (room.w >= 18 and room.d >= 18) and 2.2 or 0 end,
    voxels = function(room, ctx)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "flagstone", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "tiles", wtex = "blocks", ctex = "planks" }
        pool(room, ctx, "lava", 3, -0.45)
        for x = room.x + 3, room.x + room.w - 3, 4 do G.fill(x, room.h - 0.9, room.z, x + 0.5, room.h, room.z + room.d, "dark_wood") end
        G.fill(room.x, room.h - 1.8, room.z + 1.2, room.x + room.w, room.h - 1.1, room.z + 1.9, "metal")
        for _, c in ipairs({ { room.x + 2, room.z + 2 }, { room.x + room.w - 2, room.z + 2 }, { room.x + 2, room.z + room.d - 2 }, { room.x + room.w - 2, room.z + room.d - 2 } }) do
            if not ctx.near_door(room, c[1], c[2], 4.5) then G.pillar(c[1], c[2], 1.1, 0, room.h - 1, "metal", "stripes"); G.fill(c[1] - 0.3, 1.5, c[2] - 0.3, c[1] + 0.3, 2.1, c[2] + 0.3, "lantern") end
        end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        local pl = pool_rect(room)
        local cx, cz = (pl.x0 + pl.x1) / 2, (pl.z0 + pl.z1) / 2
        F.sconces(room, ctx, 8, 3.4)
        G.torch(cx, 0.2, pl.z0 + 2, { preset = "campfire", color = { 1, 0.35, 0.1 }, reach = 18, name = room.id .. "_glow1" })
        G.torch(cx, 0.2, pl.z1 - 2, { preset = "campfire", color = { 1, 0.35, 0.1 }, reach = 18, name = room.id .. "_glow2" })
        emitter.create(G.embers{ name = room.id .. "_embers", preset = "embers", pos = { G.mx(cx), G.my(0.4), G.mz(cz) }, size = { (pl.x1 - pl.x0) / 2, 0.5, (pl.z1 - pl.z0) / 2 } })
        T.hazard("lava", pl.x0, -3.4, pl.z0, pl.x1, 0.35, pl.z1, 28 + ctx.floor * 2)
        local tier = ctx.floor >= 3 and "gold" or "silver"
        ctx.crate(room, tier, cx - 0.6, cz - 0.4, "+z", 0)
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r) - 1, { allow = outside(pl), kinds = { { "goblin", 4 }, { "spitter", 3 }, { "slime_toxic", 1 }, { "intern", 2 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- flooded: toxic water, slimes
F.register("flooded", {
    names = { "The Gutter", "Sublevel Sump", "Department of Leaks", "The Wet Floor" },
    weight = function(f, room) return (room.w >= 18 and room.d >= 18) and 2.0 or 0 end,
    voxels = function(room, ctx)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "flagstone", wall = "mossy", ceil = "dungeon_brick", wtex = "big_bricks", ctex = "blocks" }
        pool(room, ctx, "gutter_water", 1.5, -0.2)
        for z = room.z + 3, room.z + room.d - 2, 7 do G.fill(room.x, room.h - 1.4, z, room.x + room.w, room.h - 0.8, z + 0.6, "metal") end
        for _, p in ipairs({ { 0.3, 0.3 }, { 0.7, 0.7 } }) do
            local x, z = room.x + room.w * p[1], room.z + room.d * p[2]
            G.fill(x, -0.2, z, x + 0.25, room.h - 1.4, z + 0.25, "toxic"); G.fill(x - 0.2, room.h - 2.0, z - 0.2, x + 0.45, room.h - 1.2, z + 0.45, "metal")
        end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        local pl = pool_rect(room)
        local cx, cz = (pl.x0 + pl.x1) / 2, (pl.z0 + pl.z1) / 2
        F.sconces(room, ctx, 9, 3.2)
        for i, p in ipairs({ { 0.3, 0.3 }, { 0.7, 0.7 } }) do
            G.torch(room.x + room.w * p[1] + 0.1, 1.5, room.z + room.d * p[2] + 0.1, { color = { 0.3, 1.0, 0.25 }, reach = 11, preset = "fireflies", name = room.id .. "_glow" .. i })
        end
        emitter.create{ name = room.id .. "_mist", preset = "steam_vent", pos = { G.mx(cx), G.my(0), G.mz(cz) }, rate = 10, size = { (pl.x1 - pl.x0) / 3, 0.3, (pl.z1 - pl.z0) / 3 } }
        T.hazard("toxic", pl.x0, -1.8, pl.z0, pl.x1, -0.2, pl.z1, 4)
        ctx.crate(room, "silver", cx - 0.6, cz - 0.4, "+z", 0)
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { allow = outside(pl), kinds = { { "slime_toxic", 4 }, { "slime", 3 }, { "rat", 4 }, { "spitter", 1 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- ballroom: almost no gravity
F.register("ballroom", {
    names = { "The Zero-G Ballroom", "The Floating Gala", "Ballroom of Deferred Gravity", "The Mingling Floor" },
    weight = function(f, room) return (room.h >= 7 and room.w >= 18) and 1.6 or 0 end,
    voxels = function(room, ctx)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h + 2, floor = "marble", wall = "dungeon_brick", ceil = "dungeon_brick", wtex = "blocks", ctex = "planks" }
        for ix = 0, floor(room.w / 2) - 1 do for iz = 0, floor(room.d / 2) - 1 do
            if (ix + iz) % 2 == 0 then G.fill(room.x + ix * 2, -0.5, room.z + iz * 2, room.x + ix * 2 + 2, 0, room.z + iz * 2 + 2, "obsidian", "tiles") end
        end end
        -- the stage on the far wall and chandeliers
        G.fill(room.x + 3, 0, room.z, room.x + room.w - 3, 1.0, room.z + 3, "dark_wood", "planks"); G.fill(room.x + 3, 1.0, room.z, room.x + room.w - 3, 1.08, room.z + 3, "carpet")
        local H = room.h + 2
        for i = 1, floor(room.w / 9) do
            local x, z = room.x + room.w * (i - 0.5) / floor(room.w / 9), room.z + room.d / 2
            G.fill(x - 0.08, H - 3, z - 0.08, x + 0.08, H, z + 0.08, "metal"); G.fill(x - 0.7, H - 3.2, z - 0.7, x + 0.7, H - 3.0, z + 0.7, "gold")
            for _, d in ipairs({ { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do G.fill(x + d[1] - 0.1, H - 3.0, z + d[2] - 0.1, x + d[1] + 0.1, H - 2.55, z + d[2] + 0.1, "lantern") end
        end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        local H = room.h + 2
        gravity.add{ type = "uniform", name = room.id .. "_lowg", dir = { 0, -1, 0 }, strength = 1.8, pos = { G.mx(room.x + room.w / 2), G.my(H / 2), G.mz(room.z + room.d / 2) }, half = { room.w / 2 - 0.5, H / 2, room.d / 2 - 0.5 }, priority = 10 }
        F.sconces(room, ctx, 9, 3.4)
        for i = 1, floor(room.w / 9) do
            local x, z = room.x + room.w * (i - 0.5) / floor(room.w / 9), room.z + room.d / 2
            G.torch(x, H - 3.2, z, { color = { 1, 0.8, 0.45 }, reach = 15, preset = "fireflies", name = room.id .. "_chandelier" .. i })
        end
        G.dust(room.id .. "_dust", "magic_sparks", { G.mx(room.x + room.w / 2), G.my(H / 2), G.mz(room.z + room.d / 2) }, { room.w / 3, H / 3, room.d / 3 })
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        local items = { "sushi", "gem", "trophy", "cheese", "monocle" }
        for i = 1, 3 do T.floating(room.id .. "_orb" .. i, cx + (r.next() - 0.5) * (room.w - 10), 3 + r.next() * (H - 6), cz + (r.next() - 0.5) * (room.d - 10), "item", items[r.int(1, #items)]) end
        ctx.crate(room, "silver", room.x + room.w - 4.5, room.z + 0.8, "-z", 1.08)
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { kinds = { { "goblin", 3 }, { "spitter", 3 }, { "intern", 3 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- grotto: caves, mushrooms
F.register("grotto", {
    names = { "The Mushroom Grotto", "Spore Department", "The Damp Annex", "Hall of Fungal Opportunity" },
    weight = function(f, room) return 2.0 end,
    voxels = function(room, ctx)
        local r = ctx.rng(room)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "cavestone", wall = "cavestone", ceil = "cavestone", wtex = "big_bricks" }
        local x0, z0, x1, z1 = inner(room, 4)
        for i = 1, floor(room.w * room.d / 40) do
            local x, z = x0 + r.next() * (x1 - x0), z0 + r.next() * (z1 - z0)
            local ytop = room.h - 0.2
            if r.next() < 0.5 then
                -- a stalagmite: a stack of shrinking squares
                local hh = 1.2 + r.next() * 2.2
                for k = 0, 6 do local hw = 0.5 - k * 0.06; G.fill(x - hw, k * hh / 7, z - hw, x + hw, (k + 1) * hh / 7, z + hw, "cavestone") end
            else
                -- a mushroom: a stem and a cap
                local hh, rr = 0.8 + r.next() * 1.6, 0.3 + r.next() * 0.45
                G.fill(x - 0.12, 0, z - 0.12, x + 0.12, hh, z + 0.12, "bone")
                G.sphere(x, hh, z, rr, (i % 2 == 0) and "glowcap" or "rune")
            end
            if r.next() < 0.45 then       -- a stalactite
                local hh = 0.8 + r.next() * 1.6
                for k = 0, 5 do local hw = 0.45 - k * 0.07; G.fill(x + 1.3 - hw, ytop - (k + 1) * hh / 6, z - hw, x + 1.3 + hw, ytop - k * hh / 6, z + hw, "cavestone") end
            end
        end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        local x0, z0, x1, z1 = inner(room, 4)
        for i = 1, 4 do
            G.torch(x0 + r.next() * (x1 - x0), 1.4, z0 + r.next() * (z1 - z0), { color = { 0.3, 1.0, 0.7 }, reach = 10, intensity = 9, preset = "fireflies", name = room.id .. "_shroom" .. i })
        end
        G.dust(room.id .. "_spores", "fireflies", { G.mx(room.x + room.w / 2), G.my(2), G.mz(room.z + room.d / 2) }, { room.w / 3, 1.5, room.d / 3 })
        F.sconces(room, ctx, 12, 3)
        ctx.crate(room, "bronze", room.x + room.w - 3, room.z + room.d - 3, "-z")
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { kinds = { { "spitter", 4 }, { "slime", 3 }, { "slime_toxic", 2 }, { "rat", 2 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- crypt: sarcophagi in rows
F.register("crypt", {
    names = { "The Records Crypt", "Archive of the Departed", "The Quiet Room", "Cold Storage" },
    weight = function(f, room) return 1.8 end,
    voxels = function(room, ctx)
        local r = ctx.rng(room)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "flagstone", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "tiles", wtex = "blocks", ctex = "blocks" }
        local x0, z0, x1, z1 = inner(room, 4.5)
        local ix = 0
        for x = x0, x1 - 1.2, 3.6 do
            ix = ix + 1
            for z = z0, z1 - 2.4, 4.6 do
                G.fill(x, 0, z, x + 1.2, 0.8, z + 2.4, "marble", "blocks")
                G.fill(x - 0.1, 0.8, z - 0.1, x + 1.3, 1.0, z + 2.5, "marble")
                if r.next() < 0.3 then G.fill(x + 0.25, 1.0, z + 0.3, x + 0.95, 1.1, z + 2.1, "bone") end
            end
        end
        for i = 1, floor(room.w * room.d / 90) do       -- bones on the floor
            local x, z = x0 + r.next() * (x1 - x0), z0 + r.next() * (z1 - z0)
            G.fill(x, 0, z, x + 0.5, 0.15, z + 0.3, "bone"); G.fill(x + 0.1, 0.15, z + 0.05, x + 0.25, 0.3, z + 0.2, "bone")
        end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.sconces(room, ctx, 8, 3.2)
        local x0, z0, x1, z1 = inner(room, 4.5)
        for i = 1, floor(room.w / 7) do
            G.torch(x0 + (i - 0.5) * (x1 - x0) / floor(room.w / 7), 2.0, (z0 + z1) / 2, { color = { 0.45, 0.8, 1.0 }, reach = 11, intensity = 9, name = room.id .. "_candle" .. i })
        end
        ctx.crate(room, "bronze", room.x + room.w - 2.6, room.z + 1.5, "-x")
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r) + 1, { kinds = { { "intern", 6 }, { "rat", 2 }, { "spitter", 1 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- library: shelves in rows
F.register("library", {
    names = { "The Department of Records", "The Filing Labyrinth", "Aisle of Pending Reviews", "Reference Section" },
    weight = function(f, room) return 1.8 end,
    voxels = function(room, ctx)
        local r = ctx.rng(room)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "dark_wood", wall = "dark_wood", ceil = "dark_wood", ftex = "planks", wtex = "fine_planks", ctex = "planks" }
        local x0, z0, x1, z1 = inner(room, 4.5)
        local cols = { "red", "blue", "green", "yellow", "violet", "orange" }
        for x = x0, x1 - 0.8, 3.6 do
            local z = z0
            while z < z1 - 1 do
                local len = min(2 + 2 * r.int(0, 3), z1 - z)
                if r.next() < 0.78 then
                    G.fill(x, 0, z, x + 0.8, 3.2, z + len, "dark_wood")
                    for k = 0, 3 do
                        local y = 0.35 + k * 0.75
                        for b = 0, floor(len / 0.5) - 1 do
                            G.fill(x - 0.04, y, z + b * 0.5 + 0.05, x + 0.84, y + 0.55, z + b * 0.5 + 0.42, "dark_wood")
                            G.paint(x - 0.04, y, z + b * 0.5 + 0.05, x + 0.84, y + 0.55, z + b * 0.5 + 0.42, cols[1 + (b + k + floor(x)) % 6])
                        end
                    end
                end
                z = z + len + 1.6                         -- a gap between shelves: the cross aisles
            end
        end
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.sconces(room, ctx, 8, 3.2)
        F.lamps(room, 13, 11)
        ctx.crate(room, "bronze", room.x + 2.6, room.z + 1.5, "+x")
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { kinds = { { "goblin", 5 }, { "intern", 3 }, { "rat", 2 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- depot: crates and explosive barrels
F.register("depot", {
    names = { "The Explosives Depot", "Warehouse of Regrets", "Shipping and Receiving", "The Unsafe Store" },
    weight = function(f, room) return 1.8 end,
    voxels = function(room, ctx)
        local r = ctx.rng(room)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "flagstone", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "tiles", wtex = "blocks", ctex = "planks" }
        local x0, z0, x1, z1 = inner(room, 4)
        for i = 1, floor(room.w * room.d / 45) do
            local x, z = x0 + r.next() * (x1 - x0 - 1.4), z0 + r.next() * (z1 - z0 - 1.4)
            local n = r.int(1, 3)
            for k = 0, n - 1 do G.fill(x + k * 0.1, k * 1.2, z, x + 1.3 + k * 0.1, (k + 1) * 1.2, z + 1.3, "dark_wood", "planks") end
        end
        G.text(room.x + room.w / 2 - 6, 3.4, room.z + room.d, "EXPLOSIVES: HANDLE WITH CARELESSNESS", { facing = "-z", material = "hazard_y", size = 1, depth = 1 })
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        F.sconces(room, ctx, 9, 3.3)
        F.lamps(room, 13, 11)
        local x0, z0, x1, z1 = inner(room, 3)
        for c = 1, 2 do
            local bx, bz = x0 + r.next() * (x1 - x0), z0 + r.next() * (z1 - z0)
            for k = 0, 2 do T.barrel(bx + (k % 2) * 0.9, 0, bz + floor(k / 2) * 0.9) end
        end
        ctx.crate(room, "silver", room.x + room.w - 3, room.z + 1.5, "-z")
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { kinds = { { "rat", 5 }, { "goblin", 3 }, { "slime", 1 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- prize room: three chests, one of them a mimic
F.register("prize", {
    names = { "The Prize Room", "Reward Suite", "The Raffle Floor", "Complimentary Lounge" },
    weight = function(f, room) return 1.3 end,
    voxels = function(room, ctx)
        G.room{ x = room.x, z = room.z, w = room.w, d = room.d, h = room.h, floor = "marble", wall = "dungeon_brick", ceil = "dungeon_brick", wtex = "blocks", ctex = "planks" }
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        G.fill(cx - 5, 0, cz - 2.5, cx + 5, 0.4, cz + 2.5, "dark_wood", "planks")
        G.fill(cx - 5, 0.4, cz - 2.5, cx + 5, 0.45, cz + 2.5, "carpet")
        for _, dx in ipairs({ -5.5, 5.2 }) do G.pillar(cx + dx, cz - 3, 0.5, 0, room.h, "gold"); G.pillar(cx + dx, cz + 3, 0.5, 0, room.h, "gold") end
        G.text(cx - 4, room.h - 1.2, room.z + room.d, "PLEASE CHOOSE ONE (1) PRIZE", { facing = "-z", material = "gold", size = 1, depth = 1 })
    end,
    things = function(room, ctx)
        local r = ctx.rng(room)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        F.sconces(room, ctx, 8, 3.3)
        F.lamps(room, 15, 13)
        G.torch(cx, 3, cz, { preset = "magic_sparks", color = { 1, 0.85, 0.3 }, reach = 10, name = room.id .. "_glitter" })
        local mimic = r.int(1, 3)
        for i = 1, 3 do
            local id = ctx.crate(room, i == 2 and "gold" or "silver", cx - 7 + (i - 1) * 5.2 + 0.2, cz - 0.4, "+z", 0.45)
            if i == mimic then
                T.crate_hooks[id] = function()
                    G.announcer.say_key("prize.mimic", { prio = 2 })
                    local lx, lz = cx - 7 + (i - 1) * 5.2, cz + 1.5
                    for k = 1, 5 do
                        local e = G.enemies.spawn(F.pick_kind(r, ctx.floor), lx + (k - 3) * 0.9, 0, lz + 1, { room = room.id, index = 90 + k })
                        if e then G.enemies.aggro(e, true) end
                    end
                end
            end
        end
        F.populate(room, ctx, r, 3 + floor(ctx.floor / 2), { allow = function(x, z) return math.abs(z - cz) > 4 end })
    end,
})
