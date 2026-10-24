-- gen/furnish: the ROOM LAYOUT GRAMMAR (P6d). One data-driven pass per room decides what stands where: furniture, crates' reserved places, and the SPOTS where enemies stand. The region hook draws
-- the items (voxels), the game asks for the same layout to put the population on its spots and to keep monsters out of the footprints: pure global functions, no file locals, no Game, seeded by
-- the cell's own stream mk(6), so the hook and the game get the same integers.
--
--   deco_catalogue()                       the items: one row each (category, footprint w x d, height, anchor, clearance, slots for dependents, spots offered)
--   deco_layout_themes()                   a row per theme: margin, door guards, the items to place in order (required first, then dependents and the fill)
--   deco_layout(theme, room, doors, mk, fl) -> { items, spots, bands, theme } or nil (a theme without a row keeps its hand-made decoration)
--   deco_layout_flood(lay, room, doors)    the contract's flood: the doors and every spot are connected across the room
--   deco_layout_check(lay, room, doors)    contract item 15: a list of problems (overlaps, an item in a door band, a spot in a footprint or a band, the flood)
--   deco_item_draw(B, it, fl)              the voxels of one item (B as in deco.lua)
-- Coordinates: cell metres, like deco.lua. An item: { id, cat, x0, z0, x1, z1 (its footprint), face = "+x" | "-x" | "+z" | "-z" (the way its FRONT looks), w, d (across, deep, in its own frame), h,
-- blocks, zone = the footprint with its free band }. In its own frame u runs across (0 .. w), v from the back (0) to the front (d); a wall item has its back on the wall.

function deco_catalogue()
    if deco_catalogue_memo then return deco_catalogue_memo end
    deco_catalogue_memo = {
        -- furniture
        table      = { cat = "table", w = 1.6, d = 0.9, h = 0.8, anchor = "centre", clear = 0.8, slots = "around", spots = { { "idle", 0, 1.1 } } },
        table_long = { cat = "table", w = 3.2, d = 1.0, h = 0.8, anchor = "centre", clear = 0.8, slots = "around", spots = { { "idle", 0, 1.2 } } },
        chair      = { cat = "chair", w = 0.5, d = 0.5, h = 1.0, near = "table", per = { 2, 4 }, gap = 0.08 },
        stool      = { cat = "chair", w = 0.4, d = 0.4, h = 0.6, near = "bar", per = { 3, 5 }, gap = 0.12, front_only = true },
        bench      = { cat = "bench", w = 1.8, d = 0.5, h = 0.55, anchor = "wall", clear = 0.6, spots = { { "idle", 0, 1.0 } } },
        lectern    = { cat = "lectern", w = 0.6, d = 0.6, h = 1.2, near = "bookcase", per = { 1, 1 }, gap = 0.5, front_only = true },
        urn        = { cat = "urn", w = 0.5, d = 0.5, h = 0.9, anchor = "corner", clear = 0.5 },
        candle     = { cat = "candle", w = 0.4, d = 0.4, h = 1.5, near = "sarcophagus", per = { 0, 1 }, gap = 0.4, front_only = true },
        -- shelving
        bookcase   = { cat = "bookcase", w = 2.4, d = 0.5, h = 3.2, anchor = "wall", clear = 0.9, spots = { { "idle", 0, 1.3 } } },
        stack_s    = { cat = "stack", w = 0.8, d = 2.4, h = 3.0, anchor = "free", align = 3.4, clear = 1.0, spots = { { "ambush", 0.9, 1.2 } } },
        stack_m    = { cat = "stack", w = 0.8, d = 3.6, h = 3.0, anchor = "free", align = 3.4, clear = 1.0, spots = { { "ambush", 0.9, 1.8 } } },
        stack_l    = { cat = "stack", w = 0.8, d = 4.8, h = 3.0, anchor = "free", align = 3.4, clear = 1.0, spots = { { "ambush", 0.9, 2.4 } } },
        rack       = { cat = "rack", w = 2.4, d = 0.8, h = 2.6, anchor = "wall", clear = 1.0, spots = { { "guard", 0, 1.5 } } },
        -- the dead
        sarcophagus = { cat = "sarcophagus", w = 1.2, d = 2.4, h = 1.0, anchor = "free", align = 3.6, alignz = 4.4, clear = 0.8, spots = { { "ambush", 1.5, 1.2 } } },
        -- stores
        crates     = { cat = "crates", w = 1.4, d = 1.4, h = 3.6, anchor = "free", clear = 0.9, spots = { { "idle", 1.5, 0.7 } } },
        barrels    = { cat = "barrels", w = 1.8, d = 1.8, h = 1.1, anchor = "corner", clear = 0.8 },
        -- authored models (the starter kit's, copied to models/kit/): msize = the model's size in voxels (w, h, d), mfront = the way its front looks as it is; the hook places the file (B.model)
        bed        = { cat = "bed", model = "models/kit/bed.vxm", msize = { 9, 11, 17 }, mfront = "+z", anchor = "wall", clear = 0.7 },
        couch      = { cat = "sofa", model = "models/kit/couch.vxm", msize = { 19, 13, 11 }, mfront = "+z", anchor = "wall", clear = 0.7, spots = { { "idle", 0, 1.2 } } },
        wardrobe   = { cat = "cabinet", model = "models/kit/wardrobe_light_brown.vxm", msize = { 20, 20, 11 }, mfront = "+z", anchor = "wall", clear = 0.7 },
        drawer     = { cat = "cabinet", model = "models/kit/drawer_light_brown.vxm", msize = { 13, 11, 8 }, mfront = "+z", anchor = "wall", clear = 0.6 },
        pub_table  = { cat = "table", model = "models/kit/pub_table.vxm", msize = { 11, 15, 25 }, mfront = "+z", anchor = "centre", clear = 0.8, slots = "around", spots = { { "idle", 0, 1.4 } } },
        pub_stool  = { cat = "chair", model = "models/kit/pub_stool.vxm", msize = { 8, 10, 8 }, mfront = "+z", near = "table", per = { 2, 4 }, gap = 0.1 },
        bar_stool  = { cat = "chair", model = "models/kit/pub_stool.vxm", msize = { 8, 10, 8 }, mfront = "+z", near = "bar", per = { 3, 5 }, gap = 0.12, front_only = true },
        tomb_a     = { cat = "tomb", model = "models/kit/graveyard_tomb_1.vxm", msize = { 12, 20, 12 }, mfront = "+z", anchor = "free", clear = 0.7 },
        tomb_b     = { cat = "tomb", model = "models/kit/graveyard_tomb_2.vxm", msize = { 11, 7, 12 }, mfront = "+z", anchor = "free", clear = 0.7 },
        tomb_c     = { cat = "tomb", model = "models/kit/graveyard_tomb_3.vxm", msize = { 16, 15, 12 }, mfront = "+z", anchor = "free", clear = 0.7 },
        -- lairs, bars
        dais       = { cat = "dais", w = 7.0, d = 3.0, h = 0.4, anchor = "far_wall", clear = 1.0, blocks = false, spots = { { "boss", 0, 2.35 } } },
        throne     = { cat = "throne", w = 1.6, d = 1.2, h = 2.6, on = "dais", clear = 0.3 },
        bar        = { cat = "bar", w = 4.4, d = 0.9, h = 1.1, anchor = "wall_gap", gapw = 1.7, clear = 0.8, spots = { { "idle", 0, -0.85 } } },
        shelf_wall = { cat = "shelf", w = 3.0, d = 0.4, h = 2.3, behind = "bar", clear = 0.3, offs = { -1.7, 1.7 } },
        sofa       = { cat = "sofa", w = 2.4, d = 0.9, h = 0.9, anchor = "wall", clear = 0.7 },
        -- the hall
        pillar     = { cat = "pillar", w = 1.4, d = 1.4, h = 0, anchor = "pillars", clear = 0.4 },
        banner     = { cat = "banner", w = 1.2, d = 0.15, h = 2.6, anchor = "wall", clear = 0, blocks = false },
        bones      = { cat = "bones", w = 0.6, d = 0.4, h = 0.3, anchor = "free", clear = 0, blocks = false },
    }
    for _, d in pairs(deco_catalogue_memo) do
        if d.msize then d.w, d.d, d.h = d.msize[1] / 16, d.msize[3] / 16, d.msize[2] / 16 end
    end
    return deco_catalogue_memo
end

-- a row per theme. margin: how far the free items keep from the walls; fill: { id, base, area (per 100 m2), wall (per metre of wall), jit, p } in this order;
-- door_guards: spots flanking every door (the guards of an antechamber)
function deco_layout_themes()
    if deco_layout_themes_memo then return deco_layout_themes_memo end
    deco_layout_themes_memo = {
        hall = { margin = 1.2, fill = {
            { id = "pillar", p = 0.7 },
            { id = "bench", base = 0, wall = 0.045, jit = 1, p = 0.7 },
            { id = "urn", base = 1, jit = 2 },
            { id = "banner", base = 0, wall = 0.06, jit = 1 },
            { id = "couch", base = 0, jit = 1.5 }, { id = "drawer", base = 0, jit = 1.5 },
            { id = "table", base = 0, area = 0.5, jit = 1.2, p = 0.6 },
            { id = "chair" },
        } },
        library = { margin = 3.0, fill = {
            { id = "bookcase", wall = 0.2, jit = 1 },
            { id = "lectern", p = 0.25 },
            { id = "stack_m", area = 1.6, jit = 2 },
            { id = "stack_s", area = 0.9, jit = 2 },
            { id = "stack_l", area = 0.8, jit = 1 },
            { id = "table", base = 1, jit = 1 },
            { id = "chair" },
        } },
        crypt = { margin = 2.6, fill = {
            { id = "sarcophagus", area = 3.0, jit = 2 },
            { id = "tomb_a", area = 1.0, jit = 2 }, { id = "tomb_c", area = 0.8, jit = 2 }, { id = "tomb_b", area = 1.0, jit = 2 },
            { id = "candle", p = 0.6 },
            { id = "urn", base = 2, jit = 2 },
            { id = "bones", area = 1.4, jit = 2 },
        } },
        arena = { margin = 2.0, door_guards = true, fill = {
            { id = "dais" }, { id = "throne" },
            { id = "banner", base = 3, jit = 2 },
            { id = "urn", base = 1, jit = 1 },
        } },
        ante = { margin = 1.5, door_guards = true, fill = {
            { id = "pillar", p = 0.7 },
            { id = "rack", wall = 0.1, jit = 1 },
            { id = "bench", wall = 0.05, jit = 1 },
            { id = "banner", wall = 0.05, jit = 1 },
            { id = "urn", base = 1, jit = 1 },
        } },
        safe = { margin = 1.0, reserve = "safe", fill = {
            { id = "bed", base = 1, jit = 2 }, { id = "couch", base = 0, jit = 2 }, { id = "drawer", base = 1, jit = 2 }, { id = "wardrobe", base = 0, jit = 2 },
            { id = "bench", base = 1, jit = 2 },
            { id = "urn", base = 2, jit = 2 },
            { id = "banner", base = 2, jit = 2 },
        } },
        pub = { margin = 0.8, fill = {
            { id = "bar" }, { id = "shelf_wall" }, { id = "bar_stool" },
            { id = "pub_table", base = 2, jit = 1 },
            { id = "pub_stool" },
            { id = "bench", base = 1, jit = 1 },
        } },
        depot = { margin = 3.0, fill = {
            { id = "rack", wall = 0.14, jit = 1 },
            { id = "crates", area = 2.2, jit = 2 },
            { id = "barrels", base = 1, jit = 1 },
        } },
    }
    return deco_layout_themes_memo
end

-- ---------------------------------------------------------------------------------------------- the pass
function deco_layout(theme, room, doors, mk, fl, extra)
    local TH = deco_layout_themes()[theme]
    if not TH then return nil end
    local CAT = deco_catalogue()
    local r = mk(6)
    local floor, abs, max, min = math.floor, math.abs, math.max, math.min
    local X0, Z0, X1, Z1 = room.x, room.z, room.x + room.w, room.z + room.d
    local items, spots, bands = {}, {}, {}
    local lay = { items = items, spots = spots, bands = bands, theme = theme }
    local function hit(a, b, pad) pad = pad or 0; return a[1] - pad < b[3] and b[1] < a[3] + pad and a[2] - pad < b[4] and b[2] < a[4] + pad end
    -- 1. reserve: the door bands (the doorway, the way in) and the places of the loot crates
    for _, d in ipairs(doors or {}) do
        local half, depth = (extra and extra.door_half) or 3.6, (extra and extra.door_depth) or 4.0
        if d.side == "E" then bands[#bands + 1] = { X1 - depth, d.pos - half, X1, d.pos + half }
        elseif d.side == "W" then bands[#bands + 1] = { X0, d.pos - half, X0 + depth, d.pos + half }
        elseif d.side == "S" then bands[#bands + 1] = { d.pos - half, Z1 - depth, d.pos + half, Z1 }
        else bands[#bands + 1] = { d.pos - half, Z0, d.pos + half, Z0 + depth } end
    end
    for _, q in ipairs((extra and extra.reserve) or {}) do bands[#bands + 1] = q end
    if TH.reserve == "safe" then
        local ox, oz = room.x + (room.w - 16) / 2, room.z + (room.d - 16) / 2
        bands[#bands + 1] = { ox - 0.3, oz - 0.3, ox + 16.3, oz + 16.3 }
    end
    for _, c in ipairs(deco_crates(theme, room, doors, mk, fl or 1)) do
        local alongx = (c.face == "+z" or c.face == "-z")
        local cw, cd = alongx and 1.25 or 0.75, alongx and 0.75 or 1.25
        bands[#bands + 1] = { c.x - 0.9, c.z - 0.9, c.x + cw + 0.9, c.z + cd + 0.9 }
    end
    -- geometry of an item: the footprint for a position (centre) and a face, the zone around it
    local function dims(def, face) if face == "+z" or face == "-z" then return def.w, def.d end return def.d, def.w end
    local function make(id, def, cx, cz, face)
        local w, d = dims(def, face)
        local it = { id = id, cat = def.cat, def = def, face = face, w = def.w, d = def.d, h = def.h, blocks = (def.blocks ~= false),
                     x0 = cx - w / 2, z0 = cz - d / 2, x1 = cx + w / 2, z1 = cz + d / 2 }
        local c = def.clear or 0
        it.foot = { it.x0, it.z0, it.x1, it.z1 }
        if def.anchor == "wall" or def.anchor == "corner" or def.anchor == "far_wall" or def.anchor == "wall_gap" then       -- the free band is in front
            if face == "+z" then it.zone = { it.x0, it.z0, it.x1, it.z1 + c } elseif face == "-z" then it.zone = { it.x0, it.z0 - c, it.x1, it.z1 }
            elseif face == "+x" then it.zone = { it.x0, it.z0, it.x1 + c, it.z1 } else it.zone = { it.x0 - c, it.z0, it.x1, it.z1 } end
        else it.zone = { it.x0 - c, it.z0 - c, it.x1 + c, it.z1 + c } end
        return it
    end
    -- may it stand there: inside the room, off the bands, off the others' feet and zones (the parent's zone is where a dependent belongs)
    local function fits(it, inset, parent)
        local f, zn = it.foot, it.zone
        local fx0, fz0, fx1, fz1 = f[1], f[2], f[3], f[4]
        if fx0 < X0 + inset or fz0 < Z0 + inset or fx1 > X1 - inset or fz1 > Z1 - inset then return false end
        local pad = it.blocks and 0.05 or 0
        for i = 1, #bands do
            local b = bands[i]
            if fx0 - pad < b[3] and b[1] < fx1 + pad and fz0 - pad < b[4] and b[2] < fz1 + pad then return false end
        end
        if not it.blocks then
            for i = 1, #items do
                local p = items[i]
                if p.blocks then
                    local q = p.foot
                    if fx0 - 0.1 < q[3] and q[1] < fx1 + 0.1 and fz0 - 0.1 < q[4] and q[2] < fz1 + 0.1 then return false end
                end
            end
            return true
        end
        local zx0, zz0, zx1, zz1 = zn[1], zn[2], zn[3], zn[4]
        for i = 1, #items do
            local p = items[i]
            if p.blocks then
                local q = p.foot
                if p == parent then
                    if fx0 - 0.02 < q[3] and q[1] < fx1 + 0.02 and fz0 - 0.02 < q[4] and q[2] < fz1 + 0.02 then return false end
                else
                    local y = p.zone
                    if (fx0 < y[3] and y[1] < fx1 and fz0 < y[4] and y[2] < fz1) or (zx0 < q[3] and q[1] < zx1 and zz0 < q[4] and q[2] < zz1) then return false end
                end
            end
        end
        return true
    end
    local serial = 0
    local function add(it) serial = serial + 1; it.n = serial; items[#items + 1] = it; return it end
    local FACES = { "+z", "-z", "+x", "-x" }
    local M = TH.margin or 1.0
    -- candidate generators by anchor (one random candidate per call)
    local function cand(id, def)
        local a = def.anchor
        if a == "wall" or a == "corner" then
            local side = r.int(1, 4)                      -- 1 N (z0), 2 S (z1), 3 W (x0), 4 E (x1)
            local face = ({ "+z", "-z", "+x", "-x" })[side]
            local w, d = dims(def, face)
            if a == "wall" then
                if side <= 2 then
                    local x = X0 + 0.5 + r.next() * (room.w - 1.0 - w)
                    local z = (side == 1) and Z0 + 0.04 or Z1 - 0.04 - d
                    return make(id, def, x + w / 2, z + d / 2, face)
                else
                    local z = Z0 + 0.5 + r.next() * (room.d - 1.0 - d)
                    local x = (side == 3) and X0 + 0.04 or X1 - 0.04 - w
                    return make(id, def, x + w / 2, z + d / 2, face)
                end
            end
            local cx = (r.next() < 0.5) and X0 + 0.04 + w / 2 or X1 - 0.04 - w / 2
            local cz = (r.next() < 0.5) and Z0 + 0.04 + d / 2 or Z1 - 0.04 - d / 2
            return make(id, def, cx, cz, (cx < (X0 + X1) / 2) and "+x" or "-x")
        elseif a == "far_wall" or a == "wall_gap" then
            -- the wall farthest from the doors (far_wall) / any wall that has no door band (wall_gap: a counter with room behind it)
            local best, bs = nil, -1
            for side = 1, 4 do
                local face = ({ "+z", "-z", "+x", "-x" })[side]
                local w, d = dims(def, face)
                local gap = (a == "wall_gap") and (def.gapw or 1.4) or 0.04
                local cx, cz
                if side == 1 then cx, cz = (X0 + X1) / 2, Z0 + gap + d / 2 elseif side == 2 then cx, cz = (X0 + X1) / 2, Z1 - gap - d / 2
                elseif side == 3 then cx, cz = X0 + gap + w / 2, (Z0 + Z1) / 2 else cx, cz = X1 - gap - w / 2, (Z0 + Z1) / 2 end
                local sc = 0
                for _, dd in ipairs(doors or {}) do
                    local dx, dz
                    if dd.side == "E" then dx, dz = X1, dd.pos elseif dd.side == "W" then dx, dz = X0, dd.pos elseif dd.side == "S" then dx, dz = dd.pos, Z1 else dx, dz = dd.pos, Z0 end
                    sc = sc - 100 / (1 + (cx - dx) ^ 2 + (cz - dz) ^ 2)
                end
                sc = sc + r.next() * 0.3
                if sc > bs then
                    local it = make(id, def, cx, cz, face)
                    if fits(it, 0.0) then best, bs = it, sc end
                end
            end
            return best
        elseif a == "centre" then
            local sp = min(room.w, room.d) * 0.3
            local cx = (X0 + X1) / 2 + (r.next() - 0.5) * 2 * sp
            local cz = (Z0 + Z1) / 2 + (r.next() - 0.5) * 2 * sp
            return make(id, def, floor(cx * 4) / 4, floor(cz * 4) / 4, FACES[r.int(1, 4)])
        elseif a == "pillars" then
            return nil
        else                                              -- free (with an optional column grid)
            local face = (def.align) and "+z" or FACES[r.int(1, 4)]
            local w, d = dims(def, face)
            local x, z
            if def.align then
                local ncol = max(1, floor((room.w - 2 * M) / def.align))
                x = X0 + M + r.int(0, ncol - 1) * def.align + (def.align - w) / 2
            else x = X0 + M + r.next() * max(0, room.w - 2 * M - w) end
            if def.alignz then
                local nrow = max(1, floor((room.d - 2 * M) / def.alignz))
                z = Z0 + M + r.int(0, nrow - 1) * def.alignz + (def.alignz - d) / 2
            else z = Z0 + M + r.next() * max(0, room.d - 2 * M - d) end
            return make(id, def, floor((x + w / 2) * 8) / 8, floor((z + d / 2) * 8) / 8, face)
        end
    end
    local function count_of(row)
        if not (row.base or row.area or row.wall) then return 1 end        -- a row without a count is one item (the dais, the bar)
        local n = (row.base or 0) + (row.area or 0) * room.w * room.d / 100 + (row.wall or 0) * 2 * (room.w + room.d) + (row.jit or 0) * r.next()
        return floor(n + 0.5)
    end
    -- dependents: poses around the parents already placed
    local function dependents(id, def, row)
        local parents = {}
        for _, p in ipairs(items) do if p.cat == def.near then parents[#parents + 1] = p end end
        for _, p in ipairs(parents) do
            local want = r.int(def.per[1], def.per[2])
            if row.p and r.next() > row.p then want = 0 end
            local slots = {}
            local pf = p.foot
            local w, d = def.w, def.d
            local g = def.gap or 0.1
            -- front side (the side the parent faces), then the others (not for front_only)
            local sides = { p.face }
            if not def.front_only then for _, f in ipairs({ "-z", "+z", "-x", "+x" }) do if f ~= p.face then sides[#sides + 1] = f end end end
            for _, f in ipairs(sides) do
                local len = (f == "+z" or f == "-z") and (pf[3] - pf[1]) or (pf[4] - pf[2])
                local n = max(1, floor(len / (0.9 * max(w, 0.5)) + 0.5))
                if not def.front_only and len < 1.7 then n = 1 end
                for k = 1, n do
                    local t = (k - 0.5) / n                       -- along the side
                    local cx, cz, face
                    if f == "+z" then cx, cz, face = pf[1] + t * (pf[3] - pf[1]), pf[4] + g + d / 2, "-z"        -- on the parent's +z side, looking back at it
                    elseif f == "-z" then cx, cz, face = pf[1] + t * (pf[3] - pf[1]), pf[2] - g - d / 2, "+z"
                    elseif f == "+x" then cx, cz, face = pf[3] + g + d / 2, pf[2] + t * (pf[4] - pf[2]), "-x"
                    else cx, cz, face = pf[1] - g - d / 2, pf[2] + t * (pf[4] - pf[2]), "+x" end
                    slots[#slots + 1] = { cx, cz, face }
                end
            end
            local start = (#slots > 0) and r.int(0, #slots - 1) or 0
            local placed = 0
            for k = 0, #slots - 1 do
                if placed >= want then break end
                local s = slots[1 + (start + k) % #slots]
                local it = make(id, def, s[1], s[2], s[3])
                if fits(it, 0.3, p) then add(it); placed = placed + 1 end
            end
        end
    end
    -- 2..5. the rows of the theme, in order
    for _, row in ipairs(TH.fill) do
        local def = CAT[row.id]
        if def then
            if def.on then
                for _, p in ipairs(items) do
                    if p.cat == def.on then
                        local back = 0.3
                        local cx, cz = (p.x0 + p.x1) / 2, (p.z0 + p.z1) / 2
                        local dxs = (p.face == "+x") and -1 or ((p.face == "-x") and 1 or 0)
                        local dzs = (p.face == "+z") and -1 or ((p.face == "-z") and 1 or 0)
                        local lenv = (p.face == "+z" or p.face == "-z") and (p.z1 - p.z0) or (p.x1 - p.x0)
                        local it = make(row.id, def, cx + dxs * (lenv / 2 - def.d / 2 - back), cz + dzs * (lenv / 2 - def.d / 2 - back), p.face)
                        local ok = true
                        for _, q in ipairs(items) do if q.blocks and q ~= p and hit(it.foot, q.foot, 0.05) then ok = false end end
                        if ok then it.y0 = p.h; add(it) end
                    end
                end
            elseif def.behind then
                for _, p in ipairs(items) do
                    if p.cat == def.behind then
                        for _, off in ipairs(def.offs or { 0 }) do
                            local f = p.face
                            local pcx, pcz = (p.x0 + p.x1) / 2, (p.z0 + p.z1) / 2
                            local cx, cz
                            local w, d = dims(def, f)
                            if f == "+z" then cx, cz = pcx + off, Z0 + 0.04 + d / 2 elseif f == "-z" then cx, cz = pcx - off, Z1 - 0.04 - d / 2
                            elseif f == "+x" then cx, cz = X0 + 0.04 + w / 2, pcz - off else cx, cz = X1 - 0.04 - w / 2, pcz + off end
                            local it = make(row.id, def, cx, cz, f)
                            it.zone = { it.x0, it.z0, it.x1, it.z1 }
                            if fits(it, 0.0) then add(it) end
                        end
                    end
                end
            elseif def.near then dependents(row.id, def, row)
            elseif def.anchor == "pillars" then
                local nx, nz = floor(room.w / 8), floor(room.d / 8)
                for i = 1, nx do for j = 1, nz do
                    if r.next() < (row.p or 1) then
                        local it = make(row.id, def, room.x + room.w * i / (nx + 1), room.z + room.d * j / (nz + 1), "+z")
                        it.h = room.h
                        if fits(it, 0.5) then add(it) end
                    end
                end end
            else
                local n = count_of(row)
                local misses = 0
                local placed = 0
                while placed < n and misses < 24 do
                    if row.p and r.next() > row.p then placed = placed + 1
                    else
                        local best
                        local tries = (def.anchor == "centre") and 8 or 1
                        for _ = 1, tries do
                            local it = cand(row.id, def)
                            if it and fits(it, (def.anchor == "wall" or def.anchor == "corner" or def.anchor == "far_wall" or def.anchor == "wall_gap") and 0.0 or M * 0.5) then
                                if not best then best = it
                                elseif def.anchor == "centre" then
                                    local function dc(q) return abs((q.x0 + q.x1) / 2 - (X0 + X1) / 2) + abs((q.z0 + q.z1) / 2 - (Z0 + Z1) / 2) end
                                    if dc(it) < dc(best) then best = it end
                                end
                            end
                        end
                        if best then add(best); placed = placed + 1; misses = 0 else misses = misses + 1 end
                    end
                end
            end
        end
    end
    -- 6. the spots: what every item offers, in its own frame; the door guards
    local function frame(it, u, v)                           -- own frame (u across from the left edge as the item faces, v from the back) -> world
        local f = it.face
        local ww, dd = it.w, it.d
        if f == "+z" then return it.x0 + u, it.z0 + v elseif f == "-z" then return it.x1 - u, it.z1 - v
        elseif f == "+x" then return it.x0 + v, it.z0 + u else return it.x1 - v, it.z1 - u end
    end
    local function spot_ok(x, z)
        if x < X0 + 0.8 or z < Z0 + 0.8 or x > X1 - 0.8 or z > Z1 - 0.8 then return false end
        for _, b in ipairs(bands) do if x > b[1] and x < b[3] and z > b[2] and z < b[4] then return false end end
        for _, p in ipairs(items) do if p.blocks and x > p.x0 - 0.45 and x < p.x1 + 0.45 and z > p.z0 - 0.45 and z < p.z1 + 0.45 then return false end end
        for _, s in ipairs(spots) do local dx, dz = s.x - x, s.z - z; if dx * dx + dz * dz < 2.25 then return false end end
        return true
    end
    for _, it in ipairs(items) do
        for _, sp in ipairs(it.def.spots or {}) do
            local x, z = frame(it, it.w / 2 + sp[2], sp[3])
            if spot_ok(x, z) then spots[#spots + 1] = { kind = sp[1], x = x, z = z, face = it.face, item = it.id, n = it.n } end
        end
    end
    if TH.door_guards then
        for _, d in ipairs(doors or {}) do
            for _, s in ipairs({ -1, 1 }) do
                local x, z
                if d.side == "E" then x, z = X1 - 1.6, d.pos + s * 4.6 elseif d.side == "W" then x, z = X0 + 1.6, d.pos + s * 4.6
                elseif d.side == "S" then x, z = d.pos + s * 4.6, Z1 - 1.6 else x, z = d.pos + s * 4.6, Z0 + 1.6 end
                if x >= X0 + 0.8 and z >= Z0 + 0.8 and x <= X1 - 0.8 and z <= Z1 - 0.8 then
                    local ok = true
                    for _, p in ipairs(items) do if p.blocks and x > p.x0 - 0.45 and x < p.x1 + 0.45 and z > p.z0 - 0.45 and z < p.z1 + 0.45 then ok = false end end
                    if ok then spots[#spots + 1] = { kind = "guard", x = x, z = z, face = d.side, item = "door", n = 0 } end
                end
            end
        end
    end
    -- the flood: a spot that is cut off from the doors is dropped; when the doors themselves are cut apart the last item goes until they are one region
    lay.trimmed = 0
    while true do
        local ok, lost = deco_layout_flood(lay, room, doors)
        for k = #lost, 1, -1 do table.remove(spots, lost[k]) end
        if ok or #items == 0 then break end
        local gone = table.remove(items)
        lay.trimmed = lay.trimmed + 1
        for i = #spots, 1, -1 do if spots[i].n == gone.n then table.remove(spots, i) end end
    end
    return lay
end

-- ---------------------------------------------------------------------------------------------- the contract
-- the doors and the spots are one region of the room's floor: a 0.5 m grid, a cell is blocked by the foot of a blocking item (padded by the width of a body)
function deco_layout_flood(lay, room, doors)
    local floor = math.floor
    local S = 0.5
    local nx, nz = floor(room.w / S), floor(room.d / S)
    local blocked = {}
    for _, p in ipairs(lay.items) do
        if p.blocks then
            local i0, i1 = floor((p.x0 - 0.2 - room.x) / S), floor((p.x1 + 0.2 - room.x) / S)
            local j0, j1 = floor((p.z0 - 0.2 - room.z) / S), floor((p.z1 + 0.2 - room.z) / S)
            if i0 < 0 then i0 = 0 end
            if j0 < 0 then j0 = 0 end
            if i1 > nx - 1 then i1 = nx - 1 end
            if j1 > nz - 1 then j1 = nz - 1 end
            for i = i0, i1 do local base = i * nz; for j = j0, j1 do blocked[base + j] = true end end
        end
    end
    local function cell(x, z)
        local i, j = floor((x - room.x) / S), floor((z - room.z) / S)
        if i < 0 then i = 0 elseif i > nx - 1 then i = nx - 1 end
        if j < 0 then j = 0 elseif j > nz - 1 then j = nz - 1 end
        return i * nz + j
    end
    local dstarts, nd = {}, 0
    for _, d in ipairs(doors or {}) do
        local x, z
        if d.side == "E" then x, z = room.x + room.w - 0.6, d.pos elseif d.side == "W" then x, z = room.x + 0.6, d.pos
        elseif d.side == "S" then x, z = d.pos, room.z + room.d - 0.6 else x, z = d.pos, room.z + 0.6 end
        nd = nd + 1; dstarts[nd] = cell(x, z)
    end
    local seed = dstarts[1]
    if not seed then local sp = lay.spots[1]; if not sp then return true, {} end seed = cell(sp.x, sp.z) end
    local seen, q, qh, qn = {}, {}, 1, 1
    q[1] = seed; seen[seed] = true
    while qh <= qn do
        local c = q[qh]; qh = qh + 1
        local i = (c - c % nz) / nz
        local j = c - i * nz
        local k
        if i > 0 then k = c - nz; if not seen[k] and not blocked[k] then seen[k] = true; qn = qn + 1; q[qn] = k end end
        if i < nx - 1 then k = c + nz; if not seen[k] and not blocked[k] then seen[k] = true; qn = qn + 1; q[qn] = k end end
        if j > 0 then k = c - 1; if not seen[k] and not blocked[k] then seen[k] = true; qn = qn + 1; q[qn] = k end end
        if j < nz - 1 then k = c + 1; if not seen[k] and not blocked[k] then seen[k] = true; qn = qn + 1; q[qn] = k end end
    end
    local function reached(c) if blocked[c] then return seen[c - nz] or seen[c + nz] or seen[c - 1] or seen[c + 1] end return seen[c] end
    local ok = true
    for n = 1, nd do if not reached(dstarts[n]) then ok = false end end
    local lost = {}
    for n, sp in ipairs(lay.spots) do if not reached(cell(sp.x, sp.z)) then lost[#lost + 1] = n end end
    return ok, lost
end

-- contract item 15: what must hold of a layout (a list of problems, empty when it does)
function deco_layout_check(lay, room, doors)
    local bad = {}
    local X0, Z0, X1, Z1 = room.x, room.z, room.x + room.w, room.z + room.d
    local function hit(a, b) return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4] end
    for i, p in ipairs(lay.items) do
        if p.x0 < X0 - 0.001 or p.z0 < Z0 - 0.001 or p.x1 > X1 + 0.001 or p.z1 > Z1 + 0.001 then bad[#bad + 1] = p.id .. " outside the room" end
        if p.blocks then
            for _, b in ipairs(lay.bands) do if hit(p.foot, b) then bad[#bad + 1] = p.id .. " in a door band or on a crate's place" end end
            for j = i + 1, #lay.items do local q = lay.items[j]; if q.blocks and hit(p.foot, q.foot) then bad[#bad + 1] = p.id .. " overlaps " .. q.id end end
        end
    end
    for _, s in ipairs(lay.spots) do
        for _, p in ipairs(lay.items) do if p.blocks and s.x > p.x0 and s.x < p.x1 and s.z > p.z0 and s.z < p.z1 then bad[#bad + 1] = "a " .. s.kind .. " spot inside " .. p.id end end
        if s.item ~= "door" then for _, b in ipairs(lay.bands) do if s.x > b[1] and s.x < b[3] and s.z > b[2] and s.z < b[4] then bad[#bad + 1] = "a " .. s.kind .. " spot in a door band" end end end
    end
    local ok, lost = deco_layout_flood(lay, room, doors)
    if not ok or #lost > 0 then bad[#bad + 1] = "the doors and the spots are not one region" end
    return bad
end

-- ---------------------------------------------------------------------------------------------- the voxels of an item
function deco_item_draw(B, it, fl)
    local x0, z0, x1, z1, face = it.x0, it.z0, it.x1, it.z1, it.face
    local W, D = it.w, it.d
    local function P(u, v)
        if face == "+z" then return x0 + u, z0 + v elseif face == "-z" then return x1 - u, z1 - v
        elseif face == "+x" then return x0 + v, z0 + u else return x1 - v, z1 - u end
    end
    local oy = it.y0 or 0
    local function box(u0, y0, v0, u1, y1, v1, mat)
        local ax, az = P(u0, v0); local bx, bz = P(u1, v1)
        B.fill(math.min(ax, bx), y0 + oy, math.min(az, bz), math.max(ax, bx), y1 + oy, math.max(az, bz), mat)
    end
    local id = it.id
    if it.def and it.def.model then                                   -- an authored model: the hook places the file, turned so that its front looks the way the item faces
        local IDX = { ["+z"] = 0, ["+x"] = 1, ["-z"] = 2, ["-x"] = 3 }
        B.model(it.def.model, it.x0, oy, it.z0, (IDX[face] - IDX[it.def.mfront or "+z"]) % 4)
        return
    end
    if id == "table" or id == "table_long" then
        box(0, 0.72, 0, W, 0.8, D, "dark_wood")
        for _, u in ipairs({ 0.06, W - 0.18 }) do for _, v in ipairs({ 0.06, D - 0.18 }) do box(u, 0, v, u + 0.12, 0.72, v + 0.12, "dark_wood") end end
        box(0.15, 0.8, D / 2 - 0.12, W - 0.15, 0.82, D / 2 + 0.12, "carpet")
    elseif id == "chair" then
        box(0, 0.4, 0, W, 0.48, D, "chest_wood")
        for _, u in ipairs({ 0.02, W - 0.1 }) do for _, v in ipairs({ 0.02, D - 0.1 }) do box(u, 0, v, u + 0.08, 0.4, v + 0.08, "dark_wood") end end
        box(0, 0.48, 0, W, 1.0, 0.1, "chest_wood")
    elseif id == "stool" then
        box(0, 0.5, 0, W, 0.58, D, "chest_wood"); box(0.1, 0, 0.1, W - 0.1, 0.5, D - 0.1, "dark_wood")
    elseif id == "bench" then
        box(0, 0.4, 0, W, 0.5, D, "dark_wood")
        for _, u in ipairs({ 0.1, W - 0.2 }) do box(u, 0, 0.05, u + 0.1, 0.4, D - 0.05, "dark_wood") end
    elseif id == "lectern" then
        box(0.2, 0, 0.2, W - 0.2, 1.0, D - 0.2, "dark_wood")
        box(0, 1.0, 0, W, 1.12, D * 0.5, "dark_wood"); box(0, 1.12, D * 0.25, W, 1.2, D, "dark_wood")
    elseif id == "urn" then
        box(0.05, 0, 0.05, W - 0.05, 0.12, D - 0.05, "marble"); box(0.1, 0.12, 0.1, W - 0.1, 0.6, D - 0.1, "marble"); box(0.04, 0.6, 0.04, W - 0.04, 0.72, D - 0.04, "gold")
        box(0.14, 0.72, 0.14, W - 0.14, 0.9, D - 0.14, "marble")
    elseif id == "candle" then
        box(0.1, 0, 0.1, W - 0.1, 0.08, D - 0.1, "metal"); box(W / 2 - 0.04, 0.08, D / 2 - 0.04, W / 2 + 0.04, 1.2, D / 2 + 0.04, "metal")
        box(0.05, 1.2, 0.05, W - 0.05, 1.28, D - 0.05, "metal"); box(W / 2 - 0.04, 1.28, D / 2 - 0.04, W / 2 + 0.04, 1.5, D / 2 + 0.04, "lantern")
    elseif id == "bookcase" then
        box(0, 0, 0, W, 0.1, D, "dark_wood"); box(0, 0, 0, 0.08, it.h, D, "dark_wood"); box(W - 0.08, 0, 0, W, it.h, D, "dark_wood")
        box(0, 0.1, 0, W, it.h, 0.08, "dark_wood"); box(0, it.h - 0.1, 0, W, it.h, D, "dark_wood")
        local MAT = { "chest_wood", "dark_wood", "rune", "chest_wood", "bone", "dark_wood" }
        for k = 0, 3 do
            local y = 0.1 + k * 0.78
            box(0.08, y, 0.06, W - 0.08, y + 0.05, D, "dark_wood")
            -- the books: three or four blocks of different height and colour (a block is a row of spines)
            local u, n = 0.12, 0
            while u < W - 0.3 do
                local bw = math.min(0.55 + ((n * 3 + k) % 3) * 0.2, W - 0.1 - u)
                local bh = 0.45 + ((n * 5 + k) % 3) * 0.1
                box(u, y + 0.05, 0.12, u + bw, y + 0.05 + bh, D - 0.05, MAT[1 + (n * 2 + k * 3 + math.floor(x0 + z0)) % #MAT])
                u = u + bw + 0.06; n = n + 1
            end
        end
    elseif id == "stack_s" or id == "stack_m" or id == "stack_l" then
        box(0, 0, 0, W, it.h, D, "dark_wood")
        for k = 0, 3 do
            local y = 0.35 + k * 0.75
            local v, n = 0.05, 0
            while v < D - 0.3 do
                local bl = math.min(0.9 + ((n + k) % 3) * 0.3, D - 0.05 - v)
                box(-0.04, y, v, W + 0.04, y + 0.55, v + bl, ((n + k) % 3 == 0) and "chest_wood" or "dark_wood")
                v = v + bl + 0.05; n = n + 1
            end
        end
    elseif id == "rack" then
        for _, u in ipairs({ 0, W - 0.12 }) do box(u, 0, 0, u + 0.12, it.h, D, "metal") end
        for k = 0, 2 do
            local y = 0.4 + k * 0.85
            box(0, y, 0, W, y + 0.08, D, "dark_wood")
            for c = 0, 1 do box(0.15 + c * 1.1, y + 0.08, 0.1, 1.15 + c * 1.1, y + 0.7, D - 0.1, ((c + k) % 2 == 0) and "chest_wood" or "dark_wood") end
        end
    elseif id == "sarcophagus" then
        box(0, 0, 0, W, 0.8, D, "marble"); box(-0.1, 0.8, -0.1, W + 0.1, 1.0, D + 0.1, "marble")
        if (math.floor(x0 * 3 + z0 * 5) % 3) == 0 then box(0.25, 1.0, 0.3, W - 0.25, 1.1, D - 0.3, "bone") end
    elseif id == "crates" then
        local n = 1 + math.floor(x0 * 7 + z0 * 3) % 3
        for k = 0, n - 1 do box(k * 0.08, k * 1.2, 0, 1.3 + k * 0.08, (k + 1) * 1.2, 1.3, "dark_wood") end
    elseif id == "barrels" then
        for _, q in ipairs(deco_item_parts(it)) do deco_barrel(B, q[2], 0, q[3]) end
    elseif id == "pillar" then
        B.pillar((x0 + x1) / 2, (z0 + z1) / 2, 0.7, 0, it.h, "marble")
    elseif id == "banner" then
        box(0, 2.6, 0, W, 2.7, D, "metal"); box(0.1, 1.2, 0, W - 0.1, 2.6, D, "neon_red"); box(0.3, 1.0, 0, W - 0.3, 1.2, D, "neon_red")
    elseif id == "dais" then
        box(0, 0, 0, W, 0.3, D, "dark_wood"); box(0.1, 0.3, 0.1, W - 0.1, 0.4, D - 0.1, "carpet"); box(0, 0.3, 0, W, 0.4, 0.1, "gold"); box(0, 0.3, D - 0.1, W, 0.4, D, "gold")
        box(0, 0.3, 0, 0.1, 0.4, D, "gold"); box(W - 0.1, 0.3, 0, W, 0.4, D, "gold")
    elseif id == "throne" then
        box(0.1, 0, 0.1, W - 0.1, 0.5, D - 0.1, "dark_wood"); box(0.2, 0.5, 0.3, W - 0.2, 0.62, D - 0.1, "neon_red")
        box(0.1, 0.5, 0, W - 0.1, 2.4, 0.22, "dark_wood"); box(0.3, 1.0, 0.04, W - 0.3, 2.2, 0.26, "neon_red")
        box(0.1, 2.4, 0, W - 0.1, 2.6, 0.3, "gold"); box(0, 0.5, 0.1, 0.18, 1.0, D - 0.1, "gold"); box(W - 0.18, 0.5, 0.1, W, 1.0, D - 0.1, "gold")
        box(0.05, 2.0, 0, 0.25, 2.5, 0.3, "gold"); box(W - 0.25, 2.0, 0, W - 0.05, 2.5, 0.3, "gold")
    elseif id == "bar" then
        box(0, 0, 0, W, 1.0, D, "dark_wood"); box(-0.05, 1.0, -0.05, W + 0.05, 1.1, D + 0.12, "marble")
        for k = 0, 3 do box(0.3 + k * 1.05, 0.15, D, 1.0 + k * 1.05, 0.9, D + 0.04, "chest_wood") end
        box(0, 0, D - 0.06, W, 0.12, D + 0.1, "metal")
    elseif id == "shelf_wall" then
        box(0, 0, 0, W, it.h, 0.06, "dark_wood"); box(0, 0, 0, 0.06, it.h, D, "dark_wood"); box(W - 0.06, 0, 0, W, it.h, D, "dark_wood")
        for k = 0, 3 do
            local y = 0.5 + k * 0.5
            box(0, y, 0, W, y + 0.05, D, "dark_wood")
            for b = 0, 4 do box(0.2 + b * 0.55, y + 0.05, 0.1, 0.4 + b * 0.55, y + 0.05 + 0.25 + ((b + k) % 2) * 0.1, D - 0.1, ((b * 2 + k) % 3 == 0) and "lantern" or (((b + k) % 2 == 0) and "rune" or "chest_wood")) end
        end
    elseif id == "sofa" then
        box(0, 0, 0, W, 0.45, D, "carpet"); box(0, 0.45, 0, W, 0.9, 0.25, "carpet"); box(0, 0.45, 0, 0.25, 0.7, D, "carpet"); box(W - 0.25, 0.45, 0, W, 0.7, D, "carpet")
    elseif id == "bones" then
        box(0, 0, 0, 0.5, 0.15, 0.3, "bone"); box(0.1, 0.15, 0.05, 0.25, 0.3, 0.2, "bone")
    end
end

-- what the game adds on top of an item's voxels (explosive barrels, ...): { kind, x, z } in cell metres
function deco_item_parts(it)
    if it.id == "barrels" then return { { "barrel", it.x0 + 0.5, it.z0 + 0.5 }, { "barrel", it.x0 + 1.3, it.z0 + 0.5 }, { "barrel", it.x0 + 0.9, it.z0 + 1.3 } } end
    return {}
end

-- ---------------------------------------------------------------------------------------------- the halls (P6d part 3): what a corridor looks like
-- the palette of a room theme: { floor material, trim material } (a hall takes the palette of the room its half leaves: the first half of a corridor is the room's, the second the next room's)
function deco_palette(theme, fl)
    local P = {
        library = { "dark_wood", "dark_wood" }, safe = { "dark_wood", "carpet" }, rest = { "dark_wood", "carpet" }, grotto = { "cavestone", "mossy" }, flooded = { "flagstone", "mossy" },
        ballroom = { "marble", "marble" }, warlord = { "obsidian", "dark_wood" }, crypt = { "flagstone", "bone" }, depot = { "dark_wood", "metal" }, furnace = { "obsidian", "metal" },
        arena = { "marble", "gold" }, ante = { "marble", "gold" }, guild = { "marble", "gold" }, prize = { "marble", "gold" }, captive = { "flagstone", "metal" },
    }
    local p = P[theme]
    if p then return p[1], p[2] end
    if fl == 2 then return "flagstone", "brick" end
    return "flagstone", "brick"
end

-- the segment of the hall half that leaves a cell's room by side d (nil when there is none or it is no corridor kind): shared by the hook and the contract
function deco_hall_seg(info, d)
    local kind, r = info.open[d], info.room
    if not r or not kind or kind == "internal" or not (info.door and info.door[d]) then return nil end
    local HW = { tree = 6, loop = 6, side = 4, alley = 3 }
    local HH = { tree = 5, loop = 5, side = 5, alley = 3 }
    if not HW[kind] then return nil end
    local u0, len
    if d == "E" then u0, len = r.x + r.w, 32 - r.x - r.w elseif d == "W" then u0, len = r.x, r.x elseif d == "S" then u0, len = r.z + r.d, 32 - r.z - r.d else u0, len = r.z, r.z end
    return { side = d, kind = kind, c = info.door[d], hw = HW[kind], h = HH[kind], u0 = u0, len = len, theme = info.theme }
end

-- one half of a hall as a segment: seg = { side = "E" | "S" | "W" | "N" (the way the half leaves its room), kind, c (the middle of the hall across), hw (its width), u0 (the coordinate along the axis where the half
-- starts: the room's wall), len (metres to the cell border), h (its height in m), theme (of the room it leaves), bath (the along-coordinate of the bathroom door's plate or nil) }
-- Returns the protrusions for contract item 16: a list of { u0, u1, side (-1 | 1), depth }.
function deco_hall(B, seg, mk, fl)
    local r = mk(7)
    local hw, h, kind = seg.hw, seg.h, seg.kind
    local len = seg.len - ((seg.kind == "alley") and 0.6 or (seg.hw / 2 + 0.5))      -- (the last stretch near the border is the jog to the neighbour's door)
    local floor_mat_, trim = deco_palette(seg.theme, fl)
    local prot = {}
    local function XZ(u, v)
        if seg.side == "E" then return seg.u0 + u, seg.c + v elseif seg.side == "W" then return seg.u0 - u, seg.c + v
        elseif seg.side == "S" then return seg.c + v, seg.u0 + u else return seg.c + v, seg.u0 - u end
    end
    local function box(u0, y0, v0, u1, y1, v1, mat)
        local ax, az = XZ(u0, v0); local bx, bz = XZ(u1, v1)
        B.fill(math.min(ax, bx), y0, math.min(az, bz), math.max(ax, bx), y1, math.max(az, bz), mat)
    end
    local function note(u0, u1, side, depth) prot[#prot + 1] = { u0, u1, side, depth } end
    if len < 3 then return prot end
    local function bath_clear(u0, u1, side) return not (seg.bath and side == -1 and u1 > seg.bath - 1.4 and u0 < seg.bath + 1.4) end
    if kind == "tree" or kind == "loop" or kind == "side" then
        -- the floor in the palette of the room, a trim band at the height of a hand along both walls
        box(1.0, -0.0625, -hw / 2, len, 0, hw / 2, floor_mat_)
        local ht = hw / 2
        if bath_clear(1.0, len, -1) then box(1.0, 0.85, -ht, len, 1.0, -ht + 0.08, trim) end
        box(1.0, 0.85, ht - 0.08, len, 1.0, ht, trim)
        note(1.0, len, -1, 0.08); note(1.0, len, 1, 0.08)
        local dep = (kind == "side") and 0.3 or 0.35
        local step = 6
        local u = 2.5 + r.int(0, 2)
        while u < len - 0.8 do
            for _, s in ipairs({ -1, 1 }) do
                if bath_clear(u - 0.3, u + 0.3, s) then
                    local v0, v1 = (s > 0) and (ht - dep) or -ht, (s > 0) and ht or (-ht + dep)
                    box(u - 0.2, 0, v0, u + 0.2, h - 0.3, v1, "marble")
                    box(u - 0.3, h - 0.3, v0 - ((s > 0) and 0.1 or -0.1) * 0, u + 0.3, h - 0.05, v1, "marble")
                    note(u - 0.3, u + 0.3, s, dep + 0.1)
                end
            end
            if kind ~= "side" then box(u - 0.2, h - 0.5, -ht, u + 0.2, h - 0.05, ht, "dark_wood") end      -- a beam across, over the pilasters
            u = u + step
        end
        if kind == "side" then                                   -- pipes along the ceiling on one wall, a cable on the other
            box(0.5, h - 0.6, ht - 0.4, len, h - 0.4, ht - 0.2, "metal"); box(0.5, h - 0.45, -ht + 0.15, len, h - 0.35, -ht + 0.25, "metal")
        else
            box(1.0, 0, -0.8, len, 0.0625, 0.8, "carpet")           -- a runner down the middle of the main corridors
        end
    elseif kind == "alley" then
        -- a back lane: rubble, crates, litter on ONE side (the other stays free; nothing deeper than 0.5 m)
        local s = (r.next() < 0.5) and -1 or 1
        if not bath_clear(0, 0, s) then s = -s end
        local ht = hw / 2
        box(0.6, -0.0625, -ht, len, 0, ht, "cobble")
        local u = 1.5 + r.next() * 2
        while u < len - 1 do
            local k = r.int(1, 4)
            local v0, v1 = (s > 0) and (ht - 0.4) or -ht, (s > 0) and ht or (-ht + 0.4)
            if k == 1 then box(u, 0, v0, u + 0.8, 0.35, v1, "cavestone"); box(u + 0.2, 0.35, v0 + 0.1, u + 0.6, 0.5, v1 - 0.1, "cavestone")
            elseif k == 2 then box(u, 0, v0, u + 0.7, 0.7, v1, "dark_wood"); box(u + 0.05, 0.7, v0, u + 0.65, 1.2, v1 - 0.05, "chest_wood")
            elseif k == 3 then box(u, 0, v0 + 0.1, u + 0.3, 0.1, v0 + 0.4, "bone"); box(u + 0.5, 0, v0 + 0.1, u + 0.6, 0.06, v0 + 0.3, "bone")
            else box(u, 0, v0 + 0.05, u + 0.9, 0.0625, v1 - 0.05, "gutter_water") end
            note(u, u + 0.9, s, 0.4)
            u = u + 2.2 + r.next() * 3
        end
        -- a wall lamp on the free side every 5.5 m (the alleys have no ceiling lights)
        local lu = 2.0 + r.next() * 1.5
        while lu < len - 1 do
            local lv = (-s > 0) and (ht - 0.1) or -ht
            box(lu - 0.1, 1.9, lv, lu + 0.1, 2.0, lv + 0.1, "metal"); box(lu - 0.08, 2.0, lv, lu + 0.08, 2.35, lv + 0.1, "lantern")
            note(lu - 0.1, lu + 0.1, -s, 0.1)
            lu = lu + 5.5
        end
        -- loose paper and pebbles on the floor (flat: stepped over)
        for _ = 1, 3 do local pu, pv = 1 + r.next() * (len - 2), (r.next() - 0.5) * (hw - 0.6); box(pu, 0, pv, pu + 0.25, 0.0625, pv + 0.2, "sand") end
    end
    return prot
end

-- an artery's strip (the street): the cell's own 4 m half along one side. `seg` = { side (the side of the cell the strip lies on), w (3 or 4 m), doors = { c1, c2 ... centres of halls that open into it, with their widths },
-- fl }. Lamp posts every 8 m on the inner wall, a bench and a banner between them, a gutter strip along the wall and drains in the floor; nothing within a hall's mouth.
function deco_street(B, seg, mk, fl)
    local r = mk(8)
    local w = seg.w
    local function XZ(u, v)                          -- u along the strip (0 .. 32), v from the inner wall into the strip (0 .. w)
        if seg.side == "E" then return 32 - w + v, u elseif seg.side == "W" then return w - v, u elseif seg.side == "S" then return u, 32 - w + v else return u, w - v end
    end
    local function box(u0, y0, v0, u1, y1, v1, mat)
        local ax, az = XZ(u0, v0); local bx, bz = XZ(u1, v1)
        B.fill(math.min(ax, bx), y0, math.min(az, bz), math.max(ax, bx), y1, math.max(az, bz), mat)
    end
    local function mouth(u0, u1)
        for _, d in ipairs(seg.doors or {}) do if u1 > d[1] - d[2] / 2 - 1.0 and u0 < d[1] + d[2] / 2 + 1.0 then return true end end
        return false
    end
    local prot = {}
    local off = r.int(0, 3)
    local gutter = (r.next() < 0.5) and "gutter_water" or "dark_wood"
    -- the gutter strip along the inner wall (one voxel deep, 0.3 m wide), broken at the mouths
    local u = 0
    while u < 32 do
        local u1 = math.min(32, u + 4)
        if not mouth(u, u1) then box(u, -0.0625, 0, u1, 0, 0.3, gutter) end
        u = u1
    end
    for k = 0, 3 do
        local lu = 4 + k * 8 + off * 0.25
        if not mouth(lu - 0.5, lu + 0.5) then
            box(lu - 0.15, 0, 0, lu + 0.15, 3.3, 0.3, "metal"); box(lu - 0.25, 3.3, 0, lu + 0.25, 3.45, 0.5, "metal"); box(lu - 0.18, 3.45, 0.05, lu + 0.18, 3.8, 0.4, "lantern")
            prot[#prot + 1] = { lu - 0.25, lu + 0.25, 0.5 }
        end
        local mu = lu + 4
        if mu < 31 and not mouth(mu - 1, mu + 1) then
            if (k + off) % 2 == 0 then
                box(mu - 0.9, 0, 0, mu + 0.9, 0.45, 0.5, "dark_wood"); box(mu - 0.9, 0.45, 0, mu + 0.9, 0.55, 0.12, "dark_wood")        -- a bench against the wall
                prot[#prot + 1] = { mu - 0.9, mu + 0.9, 0.5 }
            else
                box(mu - 0.6, 1.4, 0, mu + 0.6, 3.6, 0.1, (k % 2 == 0) and "neon_red" or "gold")                                         -- a banner on the wall
                box(mu - 0.7, 3.6, 0, mu + 0.7, 3.7, 0.12, "metal")
                prot[#prot + 1] = { mu - 0.7, mu + 0.7, 0.12 }
            end
        end
    end
    for k = 0, 2 do
        local du = 6 + k * 10 + off * 0.5
        if not mouth(du - 0.4, du + 0.4) then box(du, -0.0625, w * 0.5 - 0.25, du + 0.5, 0, w * 0.5 + 0.25, "metal") end        -- a drain
    end
    return prot
end

-- contract item 16 for a street: the items stand on the inner wall (at most 0.5 m deep: 3.5 of 4 m stay free) and none within a hall's mouth
function deco_street_check(seg, prot)
    local bad = {}
    for _, p in ipairs(prot) do
        if seg.w - p[3] < math.max(seg.w - 1, 2.5) then bad[#bad + 1] = "street " .. seg.side .. ": an item " .. p[3] .. " m deep leaves " .. (seg.w - p[3]) .. " m" end
        for _, d in ipairs(seg.doors or {}) do if p[2] > d[1] - d[2] / 2 and p[1] < d[1] + d[2] / 2 then bad[#bad + 1] = "street " .. seg.side .. ": an item in a hall's mouth" end end
    end
    return bad
end

-- contract item 16: the free corridor of a hall half: at no point may the protrusions of both walls leave less than max(hw - 1, 2.5) m, and the mouths stay free
function deco_hall_check(seg, prot)
    local need = math.max(seg.hw - 1, 2.5)
    local bad = {}
    local len = seg.len
    for u = 0, len, 0.25 do
        local l, rr = 0, 0
        for _, p in ipairs(prot) do if u >= p[1] and u <= p[2] then if p[3] < 0 then l = math.max(l, p[4]) else rr = math.max(rr, p[4]) end end end
        if seg.hw - l - rr < need - 1e-6 then bad[#bad + 1] = string.format("hall %s %s: free %.2f m at %.1f", seg.side, seg.kind, seg.hw - l - rr, u); break end
    end
    for _, p in ipairs(prot) do
        if p[1] < 0.99 or p[2] > len then bad[#bad + 1] = string.format("hall %s %s: an item in the mouth (%.1f .. %.1f)", seg.side, seg.kind, p[1], p[2]); break end
    end
    return bad
end
