-- gen/themes_more: the things of the rooms of a big floor besides the plain hall (their voxels are gen/deco.lua's, in the region hook). Rules for every theme: the 4 m along the walls stay free
-- (the doors are anywhere on a wall); what hurts (lava, sludge) lies in the middle with a walkway around it and stepping stones to a prize (the crate on the island is deco_crates').
Game = Game or {}
local G = Game
local F = G.floorgen
local L = G.gen.layout
local T = G.traps
local floor, max, min = math.floor, math.max, math.min

local function inner(room, m) return room.x + m, room.z + m, room.x + room.w - m, room.z + room.d - m end

-- allow() that keeps clear of a list of rectangles { x0, z0, x1, z1 } (metres) by `pad`
local function clear_of(rects, pad)
    return function(x, z)
        for _, q in ipairs(rects) do if x > q[1] - pad and x < q[3] + pad and z > q[2] - pad and z < q[4] + pad then return false end end
        return true
    end
end
local function outside(pl) return function(x, z) return x < pl.x0 - 0.6 or x > pl.x1 + 0.6 or z < pl.z0 - 0.6 or z > pl.z1 + 0.6 end end
local function pool_rect(room) local x0, z0, x1, z1 = inner(room, 4); return { x0 = x0, z0 = z0, x1 = x1, z1 = z1 } end

-- ---------------------------------------------------------------------------------------------- furnace: a lava pool
F.register("furnace", {
    names = { "The Boiler Gallery", "Furnace of Consequences", "The Hot Seat", "Department of Heat" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local pl = pool_rect(room)
        local cx, cz = (pl.x0 + pl.x1) / 2, (pl.z0 + pl.z1) / 2
        F.sconces(room, ctx, 8, 3.4)
        G.torch(cx, 0.2, pl.z0 + 2, { preset = "campfire", color = { 1, 0.35, 0.1 }, reach = 18, far = 26, name = room.id .. "_glow1" })
        G.torch(cx, 0.2, pl.z1 - 2, { preset = "campfire", color = { 1, 0.35, 0.1 }, reach = 18, far = 26, name = room.id .. "_glow2" })
        emitter.create(G.embers{ name = room.id .. "_embers", preset = "embers", pos = { G.mx(cx), G.my(0.4), G.mz(cz) }, size = { (pl.x1 - pl.x0) / 2, 0.5, (pl.z1 - pl.z0) / 2 } })
        G.sfx.bed(room.id, room.id .. ":lava", "lava_bed", cx, 0, cz); G.sfx.bed(room.id, room.id .. ":fire", "fire_bed", cx, 0.5, pl.z0 + 2)          -- (voxel-art / voxel-audio: the pool's and the glows' beds while the player is in the room)
        T.hazard("lava", pl.x0, -3.4, pl.z0, pl.x1, -0.1, pl.z1, 28 + ctx.floor * 2)       -- (balance step 1: the box ended at +0.35, so the stones and the causeway at 0 hurt too; now only whoever is IN the lava, like the toxic pool)
        local corners = { { room.x + 2, room.z + 2 }, { room.x + room.w - 2, room.z + 2 }, { room.x + 2, room.z + room.d - 2 }, { room.x + room.w - 2, room.z + room.d - 2 } }
        local out = outside(pl)
        local function allow(x, z) for _, c in ipairs(corners) do if G.dist2(x, z, c[1], c[2]) < 2.1 then return false end end return out(x, z) end
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r) - 1, { allow = allow, margin = 1.2, kinds = { { "goblin", 4 }, { "spitter", 3 }, { "slime_toxic", 1 }, { "intern", 2 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- flooded: toxic water, slimes
F.register("flooded", {
    names = { "The Gutter", "Sublevel Sump", "Department of Leaks", "The Wet Floor" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local pl = pool_rect(room)
        local cx, cz = (pl.x0 + pl.x1) / 2, (pl.z0 + pl.z1) / 2
        F.sconces(room, ctx, 9, 3.2)
        for i, p in ipairs({ { 0.3, 0.3 }, { 0.7, 0.7 } }) do
            G.torch(room.x + room.w * p[1] + 0.1, 1.5, room.z + room.d * p[2] + 0.1, { color = { 0.3, 1.0, 0.25 }, reach = 11, far = 22, preset = "fireflies", name = room.id .. "_glow" .. i })
        end
        emitter.create{ name = room.id .. "_mist", preset = "steam_vent", pos = { G.mx(cx), G.my(0), G.mz(cz) }, rate = 10, size = { (pl.x1 - pl.x0) / 3, 0.3, (pl.z1 - pl.z0) / 3 } }
        G.sfx.bed(room.id, room.id .. ":water", "water_bed", cx, 0, cz)
        T.hazard("toxic", pl.x0, -1.3, pl.z0, pl.x1, -0.2, pl.z1, 4)
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { allow = outside(pl), margin = 1.2, kinds = { { "slime_toxic", 4 }, { "slime", 3 }, { "rat", 4 }, { "spitter", 1 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- ballroom: almost no gravity
F.register("ballroom", {
    names = { "The Zero-G Ballroom", "The Floating Gala", "Ballroom of Deferred Gravity", "The Mingling Floor" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local H = room.h + 2
        gravity.add{ type = "uniform", name = room.id .. "_lowg", dir = { 0, -1, 0 }, strength = 1.8, pos = { G.mx(room.x + room.w / 2), G.my(H / 2), G.mz(room.z + room.d / 2) }, half = { room.w / 2 - 0.5, H / 2, room.d / 2 - 0.5 }, priority = 10 }
        F.sconces(room, ctx, 9, 3.4)
        for i = 1, floor(room.w / 9) do
            local x, z = room.x + room.w * (i - 0.5) / floor(room.w / 9), room.z + room.d / 2
            G.torch(x, H - 3.2, z, { color = { 1, 0.8, 0.45 }, reach = 15, far = 26, preset = "fireflies", name = room.id .. "_chandelier" .. i })
        end
        G.dust(room.id .. "_dust", "magic_sparks", { G.mx(room.x + room.w / 2), G.my(H / 2), G.mz(room.z + room.d / 2) }, { room.w / 3, H / 3, room.d / 3 })
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        local items = { "sushi", "gem", "trophy", "cheese", "monocle" }
        for i = 1, 3 do T.floating(room.id .. "_orb" .. i, cx + (r.next() - 0.5) * (room.w - 10), 3 + r.next() * (H - 6), cz + (r.next() - 0.5) * (room.d - 10), "item", items[r.int(1, #items)]) end
        F.populate(room, ctx, r, F.head_count(room, ctx.floor, r), { kinds = { { "goblin", 3 }, { "spitter", 3 }, { "intern", 3 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- grotto: caves, mushrooms
F.register("grotto", {
    names = { "The Mushroom Grotto", "Spore Department", "The Damp Annex", "Hall of Fungal Opportunity" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local x0, z0, x1, z1 = inner(room, 4)
        for i = 1, 3 do
            G.torch(x0 + r.next() * (x1 - x0), 1.4, z0 + r.next() * (z1 - z0), { color = { 0.3, 1.0, 0.7 }, reach = 10, far = 22, intensity = 9, preset = "fireflies", name = room.id .. "_shroom" .. i })
        end
        G.dust(room.id .. "_spores", "fireflies", { G.mx(room.x + room.w / 2), G.my(2), G.mz(room.z + room.d / 2) }, { room.w / 3, 1.5, room.d / 3 })
        F.sconces(room, ctx, 12, 3)
        local ox, oz = F.off(room)
        local rects = {}
        local nl = 0
        for _, it in ipairs(deco_grotto_plan(F.lroom(room), ctx.mk(room))) do
            rects[#rects + 1] = { it.x + ox - 0.6, it.z + oz - 0.6, it.x + ox + 0.6, it.z + oz + 0.6 }
            if it.kind ~= "stalagmite" and nl < 8 then                 -- (voxel-art) the caps are the light: under each cap, in its colour
                nl = nl + 1
                local hh = 0.8 + it.a * 1.6
                local col = (it.i % 2 == 0) and { 1.0, 0.35, 0.75 } or { 0.3, 1.0, 0.85 }
                G.torch(it.x + ox, hh - 0.1, it.z + oz, { color = col, reach = 7, far = 22, intensity = 7, flicker = false, raw = true, name = room.id .. "_cap" .. nl })
            end
        end
        local k = 0                                                     -- (voxel-art) a cold green wash on the walls, every 8 m, 1 m off the wall
        for u = room.x + 4, room.x + room.w - 2, 8 do for _, z in ipairs({ room.z + 1, room.z + room.d - 1 }) do
            k = k + 1; G.torch(u, 2.5, z, { color = { 0.45, 1.0, 0.8 }, reach = 7, far = 22, intensity = 5, flicker = false, raw = true, name = room.id .. "_wash" .. k })
        end end
        local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
        F.populate(room, ctx, r2, F.head_count(room, ctx.floor, r2), { allow = clear_of(rects, 0.5), kinds = { { "spitter", 4 }, { "slime", 3 }, { "slime_toxic", 2 }, { "rat", 2 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- crypt: sarcophagi in rows
F.register("crypt", {
    names = { "The Records Crypt", "Archive of the Departed", "The Quiet Room", "Cold Storage" },
    things = function(room, ctx)
        do                                                                   -- (voxel-art) the sconces raw: the crypt read near-black (L* 14) at the game's sconce strength
            local dk = G.gen.rules.dark()
            local ox, oz = F.off(room)
            for _, sc in ipairs(deco_sconce_plan("crypt", F.lroom(room), F.local_doors(room))) do G.sconce(sc.x + ox, sc.y, sc.z + oz, sc.face, { color = G.WARM, intensity = 7 * dk, reach = 7, far = 24, raw = true, flicker = false }) end
        end
        local x0, z0, x1, z1 = inner(room, 4.5)
        for i = 1, floor(room.w / 7) do
            G.torch(x0 + (i - 0.5) * (x1 - x0) / floor(room.w / 7), 2.0, (z0 + z1) / 2, { color = { 0.45, 0.8, 1.0 }, reach = 7, far = 22, intensity = 6, raw = true, flicker = false, name = room.id .. "_candle" .. i })
        end
        local lay, rects, spots = F.furnished(room, ctx)
        local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
        F.populate(room, ctx, r2, F.head_count(room, ctx.floor, r2) + 1, { allow = clear_of(rects, 0.4), spots = spots, kinds = { { "intern", 6 }, { "rat", 2 }, { "spitter", 1 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- library: shelves in rows
F.register("library", {
    names = { "The Department of Records", "The Filing Labyrinth", "Aisle of Pending Reviews", "Reference Section" },
    things = function(room, ctx)
        F.sconces(room, ctx, 8, 3.2)
        F.lamps(room, 13, 11)
        local lay, rects, spots = F.furnished(room, ctx)
        local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
        F.populate(room, ctx, r2, F.head_count(room, ctx.floor, r2), { allow = clear_of(rects, 0.5), spots = spots, kinds = { { "goblin", 5 }, { "intern", 3 }, { "rat", 2 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- depot: crates and explosive barrels
F.register("depot", {
    names = { "The Explosives Depot", "Warehouse of Regrets", "Shipping and Receiving", "The Unsafe Store" },
    things = function(room, ctx)
        F.sconces(room, ctx, 9, 3.3)
        F.lamps(room, 13, 11)
        local ox, oz = F.off(room)
        local lay, rects, spots = F.furnished(room, ctx)
        for _, it in ipairs(lay.items) do for _, q in ipairs(deco_item_parts(it)) do if q[1] == "barrel" then T.barrel(q[2] + ox, 0, q[3] + oz) end end end
        local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
        F.populate(room, ctx, r2, F.head_count(room, ctx.floor, r2), { allow = clear_of(rects, 0.5), spots = spots, kinds = { { "rat", 5 }, { "goblin", 3 }, { "slime", 1 } } })
    end,
})

-- ---------------------------------------------------------------------------------------------- prize room: three chests, one of them a mimic (the chests are deco_crates')
F.register("prize", {
    names = { "The Prize Room", "Reward Suite", "The Raffle Floor", "Complimentary Lounge" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        F.sconces(room, ctx, 8, 3.3)
        F.lamps(room, 15, 13)
        G.torch(cx, 3, cz, { preset = "magic_sparks", color = { 1, 0.85, 0.3 }, reach = 10, far = 22, name = room.id .. "_glitter" })
        F.populate(room, ctx, r, 3 + floor(ctx.floor / 2), { allow = function(x, z) return math.abs(z - cz) > 4 end })
    end,
})

-- ---------------------------------------------------------------------------------------------- captive: a caged monster and its guards
F.register("captive", {
    names = { "The Holding Cell", "Detention", "Exhibit B", "The Animal Rights Violation" },
    things = function(room, ctx)
        local r = ctx.rng(room)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        F.sconces(room, ctx, 8, 3.3); F.lamps(room, 14, 12)
        local id = "f" .. ctx.floor .. "cage" .. room.index
        local kind = ({ "orc", "troll", "cyclops", "samurai" })[1 + (ctx.floor + room.index) % 4]
        if ctx.floor < 6 and (kind == "cyclops" or kind == "samurai") then kind = "orc" end
        ctx.add(room, kind, cx, cz, 0, { captive = id })
        local x0, z0, x1, z1 = cx - 2, cz - 2, cx + 2, cz + 2
        local lock = events.button{ name = id .. "_lock", box = { G.wx(x0 + 1.5), G.wy(0.9), G.wz(z1 - 0.2), G.wx(x0 + 1.9) - 1, G.wy(1.3), G.wz(z1 + 0.1) - 1 }, prompt = "Open the cage", on = "neon", off = "gold", press_ticks = 10 }
        T.add_interact(id, x0 + 1.7, 1.1, z1 + 0.2, "Open the cage", 2.8, function() return not G.state.opened[id] end)
        events.on(lock, "pressed", function()
            if G.state.opened[id] then return end
            G.state.opened[id] = true
            G.clear(x0 + 1.0, 0.15, z1 - 0.2, x0 + 2.4, 3.2, z1 + 0.2)               -- the hatch: the bars of that part go
            G.sfx.play("lever", cx, 1, z1)
            for _, inst in pairs(G.enemies.list) do if inst.captive == id then G.ally.adopt(inst) end end
            G.save()
        end)
        local cage = { { x0 - 1.5, z0 - 1.5, x1 + 1.5, z1 + 1.5 } }
        F.populate(room, ctx, r, 3 + floor(ctx.floor / 2), { own = true, allow = clear_of(cage, 0), kinds = { { "bandit", 4 }, { "orc", 2 }, { "imp", 2 }, { "goblin", 2 } } })
    end,
})
