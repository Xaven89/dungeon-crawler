-- gen/deco: what a big floor's rooms look like inside, as pure global functions (hook_globals): the region hook calls `deco_room(B, ...)` with a builder B for the static decoration (pools, pillars, shelves,
-- the safe room's fixtures ...) and the game calls the same `deco_*_plan` functions for the things that must stand where the voxels are (enemies keep clear of the pillars, the crystal button sits on the crystal).
-- No file locals and no Game: everything a function needs is a parameter or a global function below. Coordinates: metres, local to the CELL (0 .. 32), y above the floor (the game adds the cell's origin).
--
--   B.fill(x0, y0, z0, x1, y1, z1, material)   half open box; no material: air          B.sphere(cx, cy, cz, r, material)
--   B.pillar(cx, cz, r, y0, y1, material)      a round column                          B.ring(cx, cz, r0, r1, y0, y1, material)
--   room = { x, z, w, d, h }, doors = { { side = "E" | "S" | "W" | "N", pos = z or x }, ... }, mk() = a fresh stream of the room's own random numbers (next(), int(a, b)), the same in the hook and the game

-- (mk(salt) = a fresh stream: 1 the plans, 3 the crates, 2 the population)
-- the room's own random numbers: a hashed counter (the hash is cellgen_hash_from(worldgen.hash) in both places), `salt` < 100 keeps the streams of a cell apart
function deco_rng(H, fl, ci, cj, salt)
    local k = 0
    local r = {}
    function r.next() k = k + 1; return H(0, fl * 1000 + 600 + salt, ci, cj, k) end
    function r.int(a, b) return a + math.floor(r.next() * (b - a + 1)) end
    return r
end

-- is the point within r metres of a door (the door's point on the room's wall)
function deco_near_door(room, doors, x, z, r)
    for _, d in ipairs(doors or {}) do
        local dx, dz
        if d.side == "E" then dx, dz = room.x + room.w, d.pos elseif d.side == "W" then dx, dz = room.x, d.pos
        elseif d.side == "S" then dx, dz = d.pos, room.z + room.d else dx, dz = d.pos, room.z end
        local ex, ez = x - dx, z - dz
        if math.sqrt(ex * ex + ez * ez) < r then return true end
    end
    return false
end

function deco_inner(room, m) return room.x + m, room.z + m, room.x + room.w - m, room.z + room.d - m end

-- ---------------------------------------------------------------------------------------------- the plans (shared with the game's things)
function deco_hall_plan(room, mk)
    local r = mk()
    local pillars = {}
    local nx, nz = math.floor(room.w / 8), math.floor(room.d / 8)
    for i = 1, nx do for j = 1, nz do
        if r.next() < 0.7 then pillars[#pillars + 1] = { room.x + room.w * i / (nx + 1), room.z + room.d * j / (nz + 1) } end
    end end
    return pillars
end

function deco_grotto_plan(room, mk)
    local r = mk()
    local x0, z0, x1, z1 = deco_inner(room, 4)
    local items = {}
    for i = 1, math.floor(room.w * room.d / 45) do
        local it = { x = x0 + r.next() * (x1 - x0), z = z0 + r.next() * (z1 - z0), kind = (r.next() < 0.5) and "stalagmite" or "mushroom", i = i }
        it.a, it.b, it.c = r.next(), r.next(), r.next()
        items[#items + 1] = it
    end
    return items
end

function deco_crypt_plan(room, mk)
    local r = mk()
    local x0, z0, x1, z1 = deco_inner(room, 4.5)
    local boxes, bones = {}, {}
    local x = x0
    while x <= x1 - 1.2 do
        local z = z0
        while z <= z1 - 2.4 do boxes[#boxes + 1] = { x, z, x + 1.2, z + 2.4, r.next() < 0.3 }; z = z + 4.6 end
        x = x + 3.6
    end
    for i = 1, math.floor(room.w * room.d / 90) do bones[#bones + 1] = { x0 + r.next() * (x1 - x0), z0 + r.next() * (z1 - z0) } end
    return boxes, bones
end

function deco_library_plan(room, mk)
    local r = mk()
    local x0, z0, x1, z1 = deco_inner(room, 4.5)
    local shelves = {}
    local x = x0
    while x <= x1 - 0.8 do
        local z = z0
        while z < z1 - 1 do
            local len = math.min(2 + 2 * r.int(0, 3), z1 - z)
            if r.next() < 0.78 then shelves[#shelves + 1] = { x, z, x + 0.8, z + len } end
            z = z + len + 1.6
        end
        x = x + 3.6
    end
    return shelves
end

function deco_depot_plan(room, mk)
    local r = mk()
    local x0, z0, x1, z1 = deco_inner(room, 4)
    local stacks = {}
    for i = 1, math.floor(room.w * room.d / 45) do
        stacks[#stacks + 1] = { x0 + r.next() * (x1 - x0 - 1.4), z0 + r.next() * (z1 - z0 - 1.4), r.int(1, 3) }
    end
    local barrels = {}
    for c = 1, 2 do
        local bx, bz = x0 + 1 + r.next() * (x1 - x0 - 2), z0 + 1 + r.next() * (z1 - z0 - 2)
        for k = 0, 2 do barrels[#barrels + 1] = { bx + (k % 2) * 0.9, bz + math.floor(k / 2) * 0.9 } end
    end
    return stacks, barrels
end

-- the safe room's fixtures in canonical offsets (u east, v south, 0 .. 16, the room's corner nearest the origin of the 16 x 16 square in the middle of the 20 x 20 room), mirrored so that none stands in a doorway
function deco_safe_plan(room, doors, stairs)
    local FIX = {
        fireplace = { 5, 0, 11, 1.8, must = true }, crystal = { 12, 0.6, 14.2, 2.8, must = true }, vending = { 13.4, 3, 16, 6, must = true },
        shelf_a = { 0, 2, 1.8, 5 }, shelf_b = { 0, 12.5, 1.8, 15.5 }, sofa = { 2, 12.2, 6.5, 14 }, table = { 8, 12.6, 10, 14 }, bed = { 2, 7, 4.4, 9.2 },
    }
    local ox, oz = room.x + (room.w - 16) / 2, room.z + (room.d - 16) / 2
    local function rect(mx, mz, r)
        return { ox + (mx and 16 - r[3] or r[1]), oz + (mz and 16 - r[4] or r[2]), ox + (mx and 16 - r[1] or r[3]), oz + (mz and 16 - r[2] or r[4]) }
    end
    local zones = {}
    for _, d in ipairs(doors or {}) do
        if d.side == "E" then zones[#zones + 1] = { room.x + room.w - 3, d.pos - 2.8, room.x + room.w, d.pos + 2.8 }
        elseif d.side == "W" then zones[#zones + 1] = { room.x, d.pos - 2.8, room.x + 3, d.pos + 2.8 }
        elseif d.side == "S" then zones[#zones + 1] = { d.pos - 2.8, room.z + room.d - 3, d.pos + 2.8, room.z + room.d }
        else zones[#zones + 1] = { d.pos - 2.8, room.z, d.pos + 2.8, room.z + 3 } end
    end
    local function hit(a, b) return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4] end
    local best
    local names = { "fireplace", "crystal", "vending", "shelf_a", "shelf_b", "sofa", "table", "bed" }
    for _, f in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
        local blocked, dropped = 0, {}
        for _, name in ipairs(names) do
            local r = FIX[name]
            local w = rect(f[1], f[2], r)
            for _, z in ipairs(zones) do if hit(w, z) then if r.must then blocked = blocked + 10 else dropped[name] = true; blocked = blocked + 1 end break end end
        end
        if not best or blocked < best.blocked then best = { mx = f[1], mz = f[2], dropped = dropped, blocked = blocked } end
        if blocked == 0 then break end
    end
    best.ox, best.oz = ox, oz
    function best.X(u) return ox + (best.mx and 16 - u or u) end
    function best.Z(v) return oz + (best.mz and 16 - v or v) end
    function best.face(f)
        if best.mx then f = ({ ["+x"] = "-x", ["-x"] = "+x" })[f] or f end
        if best.mz then f = ({ ["+z"] = "-z", ["-z"] = "+z" })[f] or f end
        return f
    end
    return best
end

-- the loot crates of a room: { tier, x, z, face, y [, mimic] } in cell metres (the voxels come from the hook, the buttons from the game's things)
function deco_crates(theme, room, doors, mk, fl)
    local out = {}
    local cx, cz = room.x + room.w / 2, room.z + room.d / 2
    local function add(tier, x, z, face, y, mimic) out[#out + 1] = { tier = tier, x = x, z = z, face = face, y = y or 0, mimic = mimic } end
    if theme == "hall" then
        if mk(3).next() < 0.5 then add(fl >= 3 and "silver" or "bronze", room.x + 3, room.z + 3, "+z", 0) end
    elseif theme == "warlord" then
        local door_s = false
        for _, d in ipairs(doors or {}) do if d.side == "S" and math.abs(d.pos - cx) < 5.5 then door_s = true end end
        if door_s then add("gold", room.x + 2.5, room.z + room.d - 2, "-z", 0) else add("gold", cx - 0.6, room.z + room.d - 2, "-z", 0.45) end
    elseif theme == "furnace" then add(fl >= 3 and "gold" or "silver", cx - 0.6, cz - 0.4, "+z", 0)
    elseif theme == "flooded" then add("silver", cx - 0.6, cz - 0.4, "+z", 0)
    elseif theme == "ballroom" then
        local door_n = false
        for _, d in ipairs(doors or {}) do if d.side == "N" then door_n = true end end
        add("silver", room.x + room.w - 4.5, room.z + 0.8, "-z", door_n and 0 or 1.08)
    elseif theme == "grotto" then add("bronze", room.x + room.w - 3, room.z + room.d - 3, "-z", 0)
    elseif theme == "crypt" then add("bronze", room.x + room.w - 2.6, room.z + 1.5, "-x", 0)
    elseif theme == "library" then add("bronze", room.x + 2.6, room.z + 1.5, "+x", 0)
    elseif theme == "depot" then add("silver", room.x + room.w - 3, room.z + 1.5, "-z", 0)
    elseif theme == "prize" then
        local mimic = mk(3).int(1, 3)
        for i = 1, 3 do add(i == 2 and "gold" or "silver", cx - 4.025 + (i - 1) * 3.4, cz - 0.4, "+z", 0.45, i == mimic) end
    end
    -- a chest never stands at a door: the first mirror image of its place (and way it faces) that is free
    for _, c in ipairs(out) do
        local function bad(x, z) return deco_near_door(room, doors, x + 0.6, z + 0.4, 3.0) end
        if bad(c.x, c.z) then
            local mx, mz = room.x + room.w - (c.x - room.x) - 1.25, room.z + room.d - (c.z - room.z) - 0.75
            local FLIP = { ["+x"] = "-x", ["-x"] = "+x", ["+z"] = "-z", ["-z"] = "+z" }
            if not bad(mx, c.z) then c.x = mx; c.face = (c.face == "+x" or c.face == "-x") and FLIP[c.face] or c.face
            elseif not bad(c.x, mz) then c.z = mz; c.face = (c.face == "+z" or c.face == "-z") and FLIP[c.face] or c.face
            elseif not bad(mx, mz) then c.x, c.z = mx, mz; c.face = FLIP[c.face] end
        end
    end
    return out
end

-- a chest as voxels (what traps.lua draws on a floor that is built by script): x, y, z in cell metres; B.vbox takes voxels relative to the cell's origin and the floor
function deco_chest(B, tier, x, y, z, face)
    local function R(v) return math.floor(v * 16 + 0.5) end
    local ox, oy, oz = R(x), R(y), R(z)
    local alongx = (face == "+z" or face == "-z")
    local lx_, lz_ = alongx and 20 or 12, alongx and 12 or 20
    local function bx(x0, y0, z0, x1, y1, z1, mat) B.vbox(ox + x0, oy + y0, oz + z0, ox + x1, oy + y1, oz + z1, mat) end
    bx(0, 0, 0, lx_ - 1, 8, lz_ - 1, "chest_wood")
    bx(0, 9, 0, lx_ - 1, 10, lz_ - 1, "chest_wood"); bx(1, 11, 1, lx_ - 2, 11, lz_ - 2, "chest_wood")
    if alongx then bx(3, 0, 0, 4, 10, lz_ - 1, "metal"); bx(lx_ - 5, 0, 0, lx_ - 4, 10, lz_ - 1, "metal")
    else bx(0, 0, 3, lx_ - 1, 10, 4, "metal"); bx(0, 0, lz_ - 5, lx_ - 1, 10, lz_ - 4, "metal") end
    local glow = ({ bronze = "lantern", silver = "rune", gold = "lantern", platinum = "neon" })[tier] or "lantern"
    if face == "+z" then bx(9, 6, lz_, 10, 7, lz_, glow) elseif face == "-z" then bx(9, 6, -1, 10, 7, -1, glow)
    elseif face == "+x" then bx(lx_, 6, 9, lx_, 7, 10, glow) else bx(-1, 6, 9, -1, 7, 10, glow) end
end

function deco_barrel(B, x, y, z)
    local function R(v) return math.floor(v * 16 + 0.5) end
    local cx, cy, cz = R(x), R(y), R(z)
    B.vbox(cx - 4, cy, cz - 4, cx + 4, cy + 13, cz + 4, "dark_wood")
    B.vbox(cx - 5, cy + 2, cz - 4, cx + 5, cy + 3, cz + 4, "metal"); B.vbox(cx - 4, cy + 2, cz - 5, cx + 4, cy + 3, cz + 5, "metal")
    B.vbox(cx - 5, cy + 10, cz - 4, cx + 5, cy + 11, cz + 4, "metal"); B.vbox(cx - 4, cy + 10, cz - 5, cx + 4, cy + 11, cz + 5, "metal")
    B.vbox(cx - 2, cy + 14, cz - 2, cx + 2, cy + 14, cz + 2, "hazard_y")
end

-- ---------------------------------------------------------------------------------------------- the borough lair: a static spiral of rings in the courtyard (the 2 x 2 cells = 64 x 64 m, centre at 32, 32)
-- walls (half-sizes of squares around the centre): W1 22 -> 20.8 (gap S), ring C1 20.8 -> 17, W2 17 -> 15.8 (gap N), ring C2 15.8 -> 12, W3 12 -> 10.8 (gap S), the arena inside 10.8 (21.6 m square);
-- the stairwell pit sits in the arena's north part under a forcefield slab (a glowing voxel slab, cleared by the game when the boss falls). Coordinates are super-cell local metres.
function deco_borough_geom(fl)
    local g = {
        cx = 32, cz = 32, wall = 1.2, gap = 2.5, h = 6.2,
        w1 = 22, w2 = 17, w3 = 12,                     -- outer half-sizes of the three walls
        arena = 10.8,                                  -- half-size of the arena
        pit = { x0 = 30, z0 = 32 - 8, x1 = 34, z1 = 32 - 4 },     -- the stairwell pit under the forcefield (4 x 4 m)
        gaps = { w1 = "S", w2 = "N", w3 = "S" },
        c1 = 18.9, c2 = 13.9, brazier = 8,             -- the middle of the ring corridors, where the braziers of the arena stand
    }
    if fl == 2 then                                    -- floor 2: smaller boroughs (the orange city): corridors 3.4 m, an arena of 19.2 m
        g.w1, g.w2, g.w3, g.arena = 20, 15.4, 10.8, 9.6
        g.pit = { x0 = 30, z0 = 32 - 7, x1 = 34, z1 = 32 - 3 }
        g.c1, g.c2, g.brazier = 17.1, 12.5, 7
    end
    return g
end

-- the moving walls of the rotunda (floors 2 and 3; floor 1 is the tutorial fortress and keeps its static spiral): in each ring corridor a slab of metal across the west side and one across the east
-- side (the way round the ring is the west or the east side). A slab rests in a trench under the floor when it is open (its top flush with the floor) and stands in the corridor when it is shut.
-- They open and shut on the floor clock: a period of 720 ticks (12 s), each slab open for 432 of them (7.2 s), the east one half a period behind the west one, so that one of the two is always
-- open and one wait is never longer than 3 s; the second ring is a quarter period later than the first. Super-cell local metres, 0.5 m thick, 4.9 m high (the lintel above is fixed).
function deco_wall_plan(fl)
    if fl < 2 or fl > 3 then return {} end                     -- (fortresses stand on floors 1 and 2 (boroughs) and 3 (the park); floors 5+ have none)
    local g = deco_borough_geom(fl)
    local t = g.wall
    local out = {}
    local rings = { { n = "1", a = g.w2, b = g.w1 - t, ph = 0 }, { n = "2", a = g.w3, b = g.w2 - t, ph = 180 } }
    for _, r in ipairs(rings) do
        out[#out + 1] = { id = r.n .. "W", x0 = g.cx - r.b, x1 = g.cx - r.a, z0 = g.cz - 5.25, z1 = g.cz - 4.75, h = 4.9, period = 720, open = 432, phase = r.ph, side = "W", ring = r.n }
        out[#out + 1] = { id = r.n .. "E", x0 = g.cx + r.a, x1 = g.cx + r.b, z0 = g.cz + 4.75, z1 = g.cz + 5.25, h = 4.9, period = 720, open = 432, phase = r.ph + 360, side = "E", ring = r.n }
    end
    return out
end

function deco_wall_open(w, clock) return (clock + w.phase) % w.period < w.open end

-- the spiral stays solvable at every phase: walk the ring from the gap you came in by to the gap of the next wall (half a ring: about 40 m, the slab on the way) from every start tick of
-- the period. A walker takes the first side whose slab is open for the whole crossing (60 ticks to cross, 30 for the slab to move) or waits where he stands. Returns the worst wait in ticks
-- and the list of problems (a slab that is never open long enough, a phase from which no side opens).
function deco_wall_check(fl)
    local plan, bad, worst = deco_wall_plan(fl), {}, 0
    local walk = 40 / 5 * 60          -- ticks from the gap to a slab (40 m at 5 m/s)
    local need = 60 + 30
    local by = {}
    for _, w in ipairs(plan) do by[w.ring] = by[w.ring] or {}; table.insert(by[w.ring], w); if w.open < 240 or w.open > w.period - 120 then bad[#bad + 1] = w.id .. ": open " .. w.open .. " of " .. w.period end end
    for ring, ws in pairs(by) do
        for t0 = 0, ws[1].period - 1, 10 do
            local best
            for _, w in ipairs(ws) do
                -- the wait before the slab: the first tick from which it stays open for the whole crossing
                for step = 0, w.period do
                    local ok = true
                    for k = 0, need, 10 do if not deco_wall_open(w, t0 + walk + step + k) then ok = false; break end end
                    if ok then if not best or step < best then best = step end; break end
                end
            end
            if not best then bad[#bad + 1] = "ring " .. ring .. " closed from tick " .. t0 else worst = math.max(worst, best) end
        end
    end
    return worst, bad
end

-- cu, cv: which cell of the 2 x 2 (0 / 1): the builder clips to the cell's own 32 x 32 m
function deco_borough(B, cu, cv, fl)
    local g = deco_borough_geom(fl)
    local ox, oz = cu * 32, cv * 32
    local function bb(x0, y0, z0, x1, y1, z1, mat)
        x0, x1, z0, z1 = x0 - ox, x1 - ox, z0 - oz, z1 - oz
        if x1 <= 0 or z1 <= 0 or x0 >= 32 or z0 >= 32 then return end
        B.fill(math.max(0, x0), y0, math.max(0, z0), math.min(32, x1), y1, math.min(32, z1), mat)
    end
    local cx, cz, t, hw = g.cx, g.cz, g.wall, g.gap
    local H = g.h
    -- a square wall of outer half-size h with a gap on one side
    local function wall(h, gapside, mat)
        local i = h - t
        -- N and S strips (full width), W and E strips (between them)
        local function strip(x0, z0, x1, z1, side)
            if side == gapside then
                if side == "N" or side == "S" then
                    bb(x0, 0, z0, cx - hw, H, z1, mat); bb(cx + hw, 0, z0, x1, H, z1, mat)
                    bb(cx - hw, 4.8, z0, cx + hw, H, z1, mat)          -- the lintel over the opening
                end
            else bb(x0, 0, z0, x1, H, z1, mat) end
        end
        strip(cx - h, cz - h, cx + h, cz - i, "N"); strip(cx - h, cz + i, cx + h, cz + h, "S")
        strip(cx - h, cz - i, cx - i, cz + i, "W"); strip(cx + i, cz - i, cx + h, cz + i, "E")
    end
    -- floor 3 (the park of the over-city): a wall of bone and rock, open to the sky
    local pal = (fl == 3) and { "cavestone", "bone", "ruin_stone" } or ((fl == 2) and { "cinderblock", "cinderblock", "marble" } or { "dungeon_brick", "mossy", "marble" })
    wall(g.w1, g.gaps.w1, pal[1]); wall(g.w2, g.gaps.w2, pal[2]); wall(g.w3, g.gaps.w3, pal[3])
    -- the roof over the ring corridors and the walls (the arena keeps the courtyard's ceiling)
    local function roof(h0, h1)
        bb(cx - h1, H, cz - h1, cx + h1, H + 0.5, cz - h0, "dungeon_brick"); bb(cx - h1, H, cz + h0, cx + h1, H + 0.5, cz + h1, "dungeon_brick")
        bb(cx - h1, H, cz - h0, cx - h0, H + 0.5, cz + h0, "dungeon_brick"); bb(cx + h0, H, cz - h0, cx + h1, H + 0.5, cz + h0, "dungeon_brick")
    end
    if fl ~= 3 then roof(g.arena, g.w1) end
    -- the drawbridge: two posts and a lintel of gold in front of the outer gap, a rug to the door
    bb(cx - hw - 0.4, 0, cz + g.w1, cx - hw, 5.4, cz + g.w1 + 0.4, "gold"); bb(cx + hw, 0, cz + g.w1, cx + hw + 0.4, 5.4, cz + g.w1 + 0.4, "gold")
    bb(cx - hw, 5.0, cz + g.w1, cx + hw, 5.4, cz + g.w1 + 0.4, "gold")
    bb(cx - hw, 0, cz + g.w1 + 0.4, cx + hw, 0.05, cz + g.w1 + 4, "neon_red")
    -- the moving walls (floors 2+): the slab in its trench, a lintel over the corridor with a hazard band
    for _, w in ipairs(deco_wall_plan(fl)) do
        bb(w.x0, -w.h, w.z0, w.x1, 0, w.z1, "obsidian")                  -- (built OPEN: the slab lies in its trench, flush with the floor; the floor clock shuts it, and the plan's flood sees open corridors)
        bb(w.x0, w.h, w.z0, w.x1, H, w.z1, "dungeon_brick")
        bb(w.x0, w.h, w.z0, w.x1, w.h + 0.3, w.z1, "hazard_y")
    end
    -- the arena: a gold ring on the floor, the stairwell pit and its forcefield
    local p = g.pit
    local pitw = { x0 = p.x0 - 0.3, z0 = p.z0 - 0.3, x1 = p.x1 + 0.3, z1 = p.z1 + 0.3 }
    bb(p.x0, -1.5, p.z0, p.x1, 0, p.z1, nil)
    bb(pitw.x0, 0, pitw.z0, p.x0, 0.5, pitw.z1, "marble"); bb(p.x1, 0, pitw.z0, pitw.x1, 0.5, pitw.z1, "marble")
    bb(p.x0, 0, pitw.z0, p.x1, 0.5, p.z0, "marble"); bb(p.x0, 0, p.z1, p.x1, 0.5, pitw.z1, "marble")
    bb(p.x0, -1.55, p.z0, p.x1, -1.5, p.z1, "gold")
    bb(p.x0, 0, p.z0, p.x1, 0.5, p.z1, "neon_red")                                   -- the forcefield: a glowing slab that fills the pit up to the rim
    -- a ring of gold in the arena floor
    B.ring(cx - ox, cz - oz, g.arena - 3.3, g.arena - 2.6, 0, 0.1, "gold")
end

-- a gold frame around a door of a room (the arena's themed door, the gates of a village): side, pos (the door's coordinate along the wall), half-width of the opening
function deco_door_frame(B, room, side, pos, mat, hw, hh)
    hw = hw or 3.4; hh = hh or 5.2; mat = mat or "gold"
    if side == "E" or side == "W" then
        local x = (side == "E") and room.x + room.w - 0.5 or room.x
        B.fill(x, 0, pos - hw, x + 0.5, hh, pos - hw + 0.4, mat); B.fill(x, 0, pos + hw - 0.4, x + 0.5, hh, pos + hw, mat); B.fill(x, hh - 0.6, pos - hw, x + 0.5, hh, pos + hw, mat)
    else
        local z = (side == "S") and room.z + room.d - 0.5 or room.z
        B.fill(pos - hw, 0, z, pos - hw + 0.4, hh, z + 0.5, mat); B.fill(pos + hw - 0.4, 0, z, pos + hw, hh, z + 0.5, mat); B.fill(pos - hw, hh - 0.6, z, pos + hw, hh, z + 0.5, mat)
    end
end

-- ---------------------------------------------------------------------------------------------- floor 3: a village (a 2 x 2 super-cell of 64 x 64 m, super-cell metres, the courtyard 6 .. 58)
-- four blocks of 14 x 14 m around a square of 14 x 14 m: the pub, a store, the town hall and houses in a hashed order; every building faces the square and has a door; the plan is shared with the game
-- (guards at the gates, the crystal of the pub, the vending machine of the store, the notice board of the hall). mk(salt) is the stream of the ORIGIN cell of the super-cell.
function deco_village_plan(mk)
    local r = mk(1)
    local roles = { "pub", "store", "hall", "houses" }
    for i = 4, 2, -1 do local j = r.int(1, i); roles[i], roles[j] = roles[j], roles[i] end
    local slots = { { 11, 11 }, { 39, 11 }, { 11, 39 }, { 39, 39 } }
    local out = { square = { x0 = 25, z0 = 25, x1 = 39, z1 = 39 }, buildings = {}, locators = {} }
    for i, sl in ipairs(slots) do
        local sx, sz = sl[1], sl[2]
        local east = (sx < 32)                                       -- the doors face the square
        local function add(kind, x0, z0, w, d, h)
            local b = { kind = kind, x0 = x0, z0 = z0, x1 = x0 + w, z1 = z0 + d, h = h }
            b.door = { side = east and "E" or "W", pos = z0 + d / 2 }
            b.cx, b.cz = x0 + w / 2, z0 + d / 2
            out.buildings[#out.buildings + 1] = b
            return b
        end
        local role = roles[i]
        if role == "pub" then
            local b = add("pub", sx + 1, sz + 2, 12, 10, 4.4)
            b.crystal = { x = b.cx, z = b.z0 + 1.6 }; b.note = { x = b.x0 + 3.2, z = b.z0 + 0.7 }; b.fire = { x = b.cx + 3.5, z = b.z0 + 0.7 }
        elseif role == "store" then
            local b = add("store", sx + 2, sz + 3, 10, 8, 3.8)
            b.vend = { x = b.cx, z = b.z0 + 1.2 }
        elseif role == "hall" then
            local b = add("hall", sx + 1, sz + 2, 12, 10, 4.8)
            b.board = { x = b.cx, z = b.z0 + 0.7 }
        else
            add("house", sx + 1, sz + 0.5, 7, 6, 3.4); add("house", sx + 3, sz + 8, 8, 5.5, 3.4)
        end
    end
    -- the locator stones: one at every corner of the square
    out.locators = { { 25.8, 25.8 }, { 38.2, 25.8 }, { 25.8, 38.2 }, { 38.2, 38.2 } }
    return out
end

-- cu, cv: which cell of the 2 x 2; doors: the cell's own doors (cell metres) get a gold gate; the builder clips to the cell
function deco_village(B, cu, cv, room, doors, mk)
    local plan = deco_village_plan(mk)
    local ox, oz = cu * 32, cv * 32
    local function bb(x0, y0, z0, x1, y1, z1, mat)
        x0, x1, z0, z1 = x0 - ox, x1 - ox, z0 - oz, z1 - oz
        if x1 <= 0 or z1 <= 0 or x0 >= 32 or z0 >= 32 then return end
        B.fill(math.max(0, x0), y0, math.max(0, z0), math.min(32, x1), y1, math.min(32, z1), mat)
    end
    bb(6, -0.125, 6, 58, 0, 58, "cobble")                                           -- the paving of the village
    local q = plan.square
    bb(q.x0, -0.125, q.z0, q.x1, 0, q.z1, "marble")
    -- the well in the middle of the square
    B.ring(32 - ox, 32 - oz, 1.0, 1.6, 0, 0.9, "marble")
    B.pillar(32 - ox, 32 - oz, 1.0, -0.6, 0.05, "gutter_water")
    for _, b in ipairs(plan.buildings) do
        local wall = (b.kind == "hall") and "marble" or ((b.kind == "pub") and "dark_wood" or "dungeon_brick")
        bb(b.x0, 0, b.z0, b.x1, b.h, b.z1, wall)                                      -- the solid block with its roof (the top 0.4 m)
        bb(b.x0 + 0.5, 0, b.z0 + 0.5, b.x1 - 0.5, b.h - 0.4, b.z1 - 0.5, nil)        -- the inside
        local d = b.door
        if d.side == "E" then bb(b.x1 - 0.6, 0, d.pos - 1.25, b.x1 + 0.02, 3.0, d.pos + 1.25, nil) else bb(b.x0 - 0.02, 0, d.pos - 1.25, b.x0 + 0.6, 3.0, d.pos + 1.25, nil) end
        bb(b.x0 + 0.5, -0.125, b.z0 + 0.5, b.x1 - 0.5, 0, b.z1 - 0.5, "dark_wood")   -- the floor
        if b.kind == "pub" then
            bb(b.x0 + 3.0, 0, b.z1 - 3.2, b.x1 - 3.0, 1.1, b.z1 - 2.2, "dark_wood")             -- the bar along the back wall
            bb(b.crystal.x - 1, 0, b.crystal.z - 0.8, b.crystal.x + 1, 0.9, b.crystal.z + 0.8, "marble")
            if cu * 32 <= b.crystal.x and b.crystal.x < cu * 32 + 32 and cv * 32 <= b.crystal.z and b.crystal.z < cv * 32 + 32 then B.sphere(b.crystal.x - ox, 1.55, b.crystal.z - oz, 0.55, "rune") end
            bb(b.fire.x - 1.2, 0, b.fire.z - 0.4, b.fire.x + 1.2, 2.4, b.fire.z + 0.4, "brick"); bb(b.fire.x - 0.7, 0, b.fire.z - 0.4, b.fire.x + 0.7, 1.4, b.fire.z + 0.4, nil)
            bb(b.note.x - 0.6, 1.3, b.note.z - 0.1, b.note.x + 0.6, 2.1, b.note.z + 0.15, "lantern")   -- the notice board with the note
            for k = 0, 1 do bb(b.x0 + 2 + k * 4, 0, b.cz - 1, b.x0 + 3.2 + k * 4, 0.9, b.cz + 0.2, "dark_wood") end
        elseif b.kind == "store" then
            bb(b.vend.x - 1.2, 0, b.vend.z - 0.5, b.vend.x + 1.2, 2.8, b.vend.z + 0.5, "metal"); bb(b.vend.x - 1.0, 0.8, b.vend.z + 0.5, b.vend.x + 1.0, 2.4, b.vend.z + 0.6, "lantern")
            bb(b.x0 + 3, 0, b.cz, b.x1 - 3, 1.0, b.cz + 0.9, "dark_wood")
        elseif b.kind == "hall" then
            bb(b.cx - 3, 0, b.z0 + 0.5, b.cx + 3, 0.5, b.z0 + 2.5, "dark_wood"); bb(b.board.x - 1.5, 1.2, b.board.z - 0.1, b.board.x + 1.5, 2.6, b.board.z + 0.15, "neon_red")
        end
    end
    -- the locator stones
    for _, l in ipairs(plan.locators) do bb(l[1] - 0.4, 0, l[2] - 0.4, l[1] + 0.4, 2.2, l[2] + 0.4, "marble"); bb(l[1] - 0.25, 2.2, l[2] - 0.25, l[1] + 0.25, 2.6, l[2] + 0.25, "lantern") end
    -- the gates: a frame at every hall that leaves this cell's quarter of the courtyard
    for _, d in ipairs(doors or {}) do deco_door_frame(B, room, d.side, d.pos, "gold", 3.4, 5.2) end
end

-- ---------------------------------------------------------------------------------------------- wall sconces and hanging lamps (plates and chains are the hook's, the flames are the game's)
-- per theme: the step along the walls and the height of the sconces (x1.5 in the game's 15-lights-a-room budget), the themes that hang lamps
function deco_sconce_plan(theme, room, doors)
    local T = { hall = { 8, 3.3 }, warlord = { 8, 3.3 }, furnace = { 8, 3.4 }, flooded = { 9, 3.2 }, ballroom = { 9, 3.4 }, grotto = { 12, 3 }, crypt = { 8, 3.2 }, library = { 8, 3.2 },
                depot = { 9, 3.3 }, safe = { 8, 3.3 }, prize = { 8, 3.3 }, captive = { 8, 3.3 }, ante = { 8, 3.3 }, guild = { 8, 3.3 }, stairs_free = { 8, 3.2 } }
    local c = T[theme]
    local out = {}
    if not c then return out end
    local step, y = c[1] * 1.5, c[2]
    local x = room.x + 4
    while x <= room.x + room.w - 3 do
        if not deco_near_door(room, doors, x, room.z, 3) then out[#out + 1] = { x = x, y = y, z = room.z, face = "+z" } end
        if not deco_near_door(room, doors, x, room.z + room.d, 3) then out[#out + 1] = { x = x, y = y, z = room.z + room.d, face = "-z" } end
        x = x + step
    end
    local z = room.z + 4
    while z <= room.z + room.d - 3 do
        if not deco_near_door(room, doors, room.x, z, 3) then out[#out + 1] = { x = room.x, y = y, z = z, face = "+x" } end
        if not deco_near_door(room, doors, room.x + room.w, z, 3) then out[#out + 1] = { x = room.x + room.w, y = y, z = z, face = "-x" } end
        z = z + step
    end
    return out
end

-- the hanging lamps of a room (a grid of about one per 60 m2) for the themes that have them
function deco_lamp_plan(theme, room)
    local LAMPS = { hall = true, warlord = true, library = true, depot = true, prize = true, captive = true, guild = true, ante = true }
    local out = {}
    if not LAMPS[theme] then return out end
    local nx, nz = math.max(1, math.floor(room.w / 8)), math.max(1, math.floor(room.d / 8))
    for i = 1, nx do for j = 1, nz do out[#out + 1] = { x = room.x + room.w * (i - 0.5) / nx, z = room.z + room.d * (j - 0.5) / nz } end end
    return out
end

-- the plate of a sconce on the wall (the voxels G.sconce draws on a hand-built floor): x, y, z the point on the wall's inner face, face the way the wall looks into the room
function deco_sconce(B, sc)
    local function R(v) return math.floor(v * 16 + 0.5) end
    local cx, cy, cz = R(sc.x), R(sc.y), R(sc.z)
    local fx = (sc.face == "+x") and 1 or ((sc.face == "-x") and -1 or 0)
    local fz = (sc.face == "+z") and 1 or ((sc.face == "-z") and -1 or 0)
    local function cell(d, k) return (d > 0) and k or (-1 - k) end
    local function bx(k0, k1, hw, y0, y1, mat)
        local xa, xb, za, zb
        if fx ~= 0 then xa, xb = cx + cell(fx, k0), cx + cell(fx, k1); za, zb = cz - hw, cz + hw
        else za, zb = cz + cell(fz, k0), cz + cell(fz, k1); xa, xb = cx - hw, cx + hw end
        B.vbox(math.min(xa, xb), cy + y0, math.min(za, zb), math.max(xa, xb), cy + y1, math.max(za, zb), mat)
    end
    bx(0, 1, 1, -2, 2, "metal"); bx(2, 3, 0, -2, 1, "dark_wood"); bx(2, 3, 1, 2, 2, "metal")
end

function deco_lamp(B, lm, hh, drop)
    B.fill(lm.x - 0.04, hh - drop, lm.z - 0.04, lm.x + 0.04, hh, lm.z + 0.04, "metal")
    B.fill(lm.x - 0.2, hh - drop - 0.4, lm.z - 0.2, lm.x + 0.2, hh - drop, lm.z + 0.2, "lantern")
    B.fill(lm.x - 0.25, hh - drop - 0.05, lm.z - 0.25, lm.x + 0.25, hh - drop, lm.z + 0.25, "metal")
end

-- ---------------------------------------------------------------------------------------------- voxel text for the hook (the engine's edit.text is a world edit: edits made when a cell comes alive made a replay differ)
-- a 5 x 7 font, one voxel a pixel; `facing` is the way the text looks (the way a reader stands), the line starts at (x, z) and its bottom is at y (cell metres); B.vbox takes voxels
function deco_text(B, x, y, z, text, facing, mat)
    local F5 = {
        A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" }, B = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
        C = { "01110", "10001", "10000", "10000", "10000", "10001", "01110" }, D = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
        E = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" }, F = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
        G = { "01110", "10001", "10000", "10111", "10001", "10001", "01111" }, H = { "10001", "10001", "10001", "11111", "10001", "10001", "10001" },
        I = { "01110", "00100", "00100", "00100", "00100", "00100", "01110" }, J = { "00111", "00010", "00010", "00010", "00010", "10010", "01100" },
        K = { "10001", "10010", "10100", "11000", "10100", "10010", "10001" }, L = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
        M = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" }, N = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
        O = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" }, P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
        Q = { "01110", "10001", "10001", "10001", "10101", "10010", "01101" }, R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
        S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" }, T = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
        U = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" }, V = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
        W = { "10001", "10001", "10001", "10101", "10101", "11011", "10001" }, X = { "10001", "10001", "01010", "00100", "01010", "10001", "10001" },
        Y = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" }, Z = { "11111", "00001", "00010", "00100", "01000", "10000", "11111" },
        ["0"] = { "01110", "10001", "10011", "10101", "11001", "10001", "01110" }, ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
        ["2"] = { "01110", "10001", "00001", "00110", "01000", "10000", "11111" }, ["3"] = { "11110", "00001", "00001", "01110", "00001", "00001", "11110" },
        ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" }, ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
        ["6"] = { "00110", "01000", "10000", "11110", "10001", "10001", "01110" }, ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
        ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" }, ["9"] = { "01110", "10001", "10001", "01111", "00001", "00010", "01100" },
        ["."] = { "00000", "00000", "00000", "00000", "00000", "01100", "01100" }, ["-"] = { "00000", "00000", "00000", "11111", "00000", "00000", "00000" },
        [">"] = { "10000", "01000", "00100", "00010", "00100", "01000", "10000" }, ["("] = { "00010", "00100", "01000", "01000", "01000", "00100", "00010" },
        [")"] = { "01000", "00100", "00010", "00010", "00010", "00100", "01000" }, [":"] = { "00000", "01100", "01100", "00000", "01100", "01100", "00000" },
    }
    local function R(v) return math.floor(v * 16 + 0.5) end
    local vx, vy, vz = R(x), R(y), R(z)
    local dirx, dirz, depth_z, depth_x = 0, 0, 0, 0     -- the way the line runs; the voxel layer in front of the wall
    if facing == "+z" then dirx = 1 elseif facing == "-z" then dirx = -1 elseif facing == "+x" then dirz = -1 else dirz = 1 end
    local n = 0
    for ci = 1, #text do
        local ch = string.sub(text, ci, ci)
        local g = F5[ch]
        if g then
            for row = 1, 7 do
                local line = g[row]
                local c = 1
                while c <= 5 do
                    if string.sub(line, c, c) == "1" then
                        local c2 = c
                        while c2 < 5 and string.sub(line, c2 + 1, c2 + 1) == "1" do c2 = c2 + 1 end
                        -- pixels c .. c2 of the glyph at position n (0-based) along the line; row 1 is the top
                        local u0, u1 = n * 6 + (c - 1), n * 6 + (c2 - 1)
                        local y0 = vy + (7 - row)
                        if dirx ~= 0 then
                            local xa, xb = vx + dirx * u0, vx + dirx * u1
                            local zz = (facing == "+z") and vz or (vz - 1)
                            B.vbox(math.min(xa, xb), y0, zz, math.max(xa, xb), y0, zz, mat)
                        else
                            local za, zb = vz + dirz * u0, vz + dirz * u1
                            local xx = (facing == "+x") and vx or (vx - 1)
                            B.vbox(xx, y0, math.min(za, zb), xx, y0, math.max(za, zb), mat)
                        end
                        c = c2 + 1
                    else c = c + 1 end
                end
            end
        end
        n = n + 1
    end
end

-- the width of a line of text in metres
function deco_text_len(text) return #text * 6 / 16 end

-- ---------------------------------------------------------------------------------------------- the decoration of a room by its theme (the hook)
function deco_room(B, theme, room, doors, mk, fl)
    local floor = math.floor
    local function pool(fluid, depth, surface_y)
        local x0, z0, x1, z1 = deco_inner(room, 4)
        B.fill(x0, -depth, z0, x1, 0, z1)
        B.fill(x0 - 0.25, -depth, z0, x0, 0, z1, "obsidian"); B.fill(x1, -depth, z0, x1 + 0.25, 0, z1, "obsidian")
        B.fill(x0, -depth, z0 - 0.25, x1, 0, z0, "obsidian"); B.fill(x0, -depth, z1, x1, 0, z1 + 0.25, "obsidian")
        B.fill(x0, -depth - 0.3, z0, x1, -depth, z1, "obsidian")
        B.fill(x0, -depth, z0, x1, surface_y, z1, fluid)
        local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        B.fill(cx - 1.2, -depth, cz - 1.2, cx + 1.2, 0.0, cz + 1.2, "obsidian")
        local sx = (x1 - x0) >= (z1 - z0)
        local n = floor(((sx and (x1 - x0) or (z1 - z0)) / 2 - 1.2) / 1.7)
        for i = 1, math.max(1, n) do
            local d = 1.2 + i * 1.7 - 0.5
            if sx then B.fill(cx - d - 0.45, -depth, cz - 0.45, cx - d + 0.45, 0, cz + 0.45, "obsidian") else B.fill(cx - 0.45, -depth, cz - d - 0.45, cx + 0.45, 0, cz - d + 0.45, "obsidian") end
        end
    end
    local h = room.h
    local open = ((fl or 1) == 3)                                  -- floor 3 has no ceiling: nothing hangs from it
    local lay = deco_layout(theme, room, doors, mk, fl)           -- the layout grammar (gen/furnish.lua): the themes it has a row for are furnished by it
    if lay then for _, it in ipairs(lay.items) do deco_item_draw(B, it, fl) end end
    if theme == "hall" or theme == "ante" or theme == "guild" then
        if room.w >= room.d then B.fill(room.x + 1, 0, room.z + room.d / 2 - 2, room.x + room.w - 1, 0.05, room.z + room.d / 2 + 2, "carpet")
        else B.fill(room.x + room.w / 2 - 2, 0, room.z + 1, room.x + room.w / 2 + 2, 0.05, room.z + room.d - 1, "carpet") end
        if not lay then
            for _, p in ipairs(deco_hall_plan(room, mk)) do
                if not deco_near_door(room, doors, p[1], p[2], 3) then B.pillar(p[1], p[2], 0.7, 0, h, "marble") end
            end
        end
        if not open then for x = room.x + 3, room.x + room.w - 3, 6 do B.fill(x, h - 0.8, room.z, x + 0.5, h, room.z + room.d, "dark_wood") end end
    elseif theme == "warlord" then
        local cx = room.x + room.w / 2
        local door_s = false
        for _, d in ipairs(doors or {}) do if d.side == "S" and math.abs(d.pos - cx) < 5.5 then door_s = true end end
        if not door_s then B.fill(cx - 3, 0, room.z + room.d - 6, cx + 3, 0.4, room.z + room.d - 1, "dark_wood"); B.fill(cx - 3, 0.4, room.z + room.d - 6, cx + 3, 0.45, room.z + room.d - 1, "carpet") end
        for _, dx in ipairs({ -8, 8 }) do for k = 1, 2 do if not deco_near_door(room, doors, cx + dx, room.z + room.d * k / 3, 3.2) then B.pillar(cx + dx, room.z + room.d * k / 3, 0.8, 0, h, "dungeon_brick") end end end
        for i = 1, 3 do B.fill(room.x + room.w * i / 4 - 0.6, 3.2, room.z + 0.05, room.x + room.w * i / 4 + 0.6, 6, room.z + 0.2, "neon_red") end
    elseif theme == "furnace" then
        pool("lava", 3, -0.45)
        if not open then
            for x = room.x + 3, room.x + room.w - 3, 4 do B.fill(x, h - 0.9, room.z, x + 0.5, h, room.z + room.d, "dark_wood") end
            B.fill(room.x, h - 1.8, room.z + 1.2, room.x + room.w, h - 1.1, room.z + 1.9, "metal")
        end
        for _, c in ipairs({ { room.x + 2, room.z + 2 }, { room.x + room.w - 2, room.z + 2 }, { room.x + 2, room.z + room.d - 2 }, { room.x + room.w - 2, room.z + room.d - 2 } }) do
            if not deco_near_door(room, doors, c[1], c[2], 4.5) then B.pillar(c[1], c[2], 1.1, 0, h - 1, "metal"); B.fill(c[1] - 0.3, 1.5, c[2] - 0.3, c[1] + 0.3, 2.1, c[2] + 0.3, "lantern") end
        end
    elseif theme == "flooded" then
        pool("gutter_water", 1.0, -0.2)
        if not open then for z = room.z + 3, room.z + room.d - 2, 7 do B.fill(room.x, h - 1.4, z, room.x + room.w, h - 0.8, z + 0.6, "metal") end end
        for _, p in ipairs(open and {} or { { 0.3, 0.3 }, { 0.7, 0.7 } }) do
            local x, z = room.x + room.w * p[1], room.z + room.d * p[2]
            B.fill(x, -0.2, z, x + 0.25, h - 1.4, z + 0.25, "toxic"); B.fill(x - 0.2, h - 2.0, z - 0.2, x + 0.45, h - 1.2, z + 0.45, "metal")
        end
    elseif theme == "ballroom" then
        for ix = 0, floor(room.w / 2) - 1 do for iz = 0, floor(room.d / 2) - 1 do
            if (ix + iz) % 2 == 0 then B.fill(room.x + ix * 2, -0.5, room.z + iz * 2, room.x + ix * 2 + 2, 0, room.z + iz * 2 + 2, "obsidian") end
        end end
        local door_n = false
        for _, d in ipairs(doors or {}) do if d.side == "N" then door_n = true end end
        if not door_n then
            B.fill(room.x + 3, 0, room.z, room.x + room.w - 3, 1.0, room.z + 3, "dark_wood"); B.fill(room.x + 3, 1.0, room.z, room.x + room.w - 3, 1.08, room.z + 3, "carpet")
        end
        local H = h + 2
        for i = 1, (open and 0 or floor(room.w / 9)) do
            local x, z = room.x + room.w * (i - 0.5) / floor(room.w / 9), room.z + room.d / 2
            B.fill(x - 0.08, H - 3, z - 0.08, x + 0.08, H, z + 0.08, "metal"); B.fill(x - 0.7, H - 3.2, z - 0.7, x + 0.7, H - 3.0, z + 0.7, "gold")
            for _, d in ipairs({ { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do B.fill(x + d[1] - 0.1, H - 3.0, z + d[2] - 0.1, x + d[1] + 0.1, H - 2.55, z + d[2] + 0.1, "lantern") end
        end
    elseif theme == "grotto" then
        local ytop = h - 0.2
        for _, it in ipairs(deco_grotto_plan(room, mk)) do
            local x, z = it.x, it.z
            if it.kind == "stalagmite" then
                local hh = 1.2 + it.a * 2.2
                for k = 0, 6 do local hw = 0.5 - k * 0.06; B.fill(x - hw, k * hh / 7, z - hw, x + hw, (k + 1) * hh / 7, z + hw, "cavestone") end
            else
                local hh, rr = 0.8 + it.a * 1.6, 0.3 + it.b * 0.45
                B.fill(x - 0.12, 0, z - 0.12, x + 0.12, hh, z + 0.12, "bone")
                B.sphere(x, hh, z, rr, (it.i % 2 == 0) and "glowcap" or "rune")
            end
            if it.c < 0.45 and not open then
                local hh = 0.8 + it.b * 1.6
                for k = 0, 5 do local hw = 0.45 - k * 0.07; B.fill(x + 1.3 - hw, ytop - (k + 1) * hh / 6, z - hw, x + 1.3 + hw, ytop - k * hh / 6, z + hw, "cavestone") end
            end
        end
    elseif theme == "crypt" and not lay then
        local boxes, bones = deco_crypt_plan(room, mk)
        for _, b in ipairs(boxes) do
            local x, z = b[1], b[2]
            B.fill(x, 0, z, x + 1.2, 0.8, z + 2.4, "marble")
            B.fill(x - 0.1, 0.8, z - 0.1, x + 1.3, 1.0, z + 2.5, "marble")
            if b[5] then B.fill(x + 0.25, 1.0, z + 0.3, x + 0.95, 1.1, z + 2.1, "bone") end
        end
        for _, b in ipairs(bones) do B.fill(b[1], 0, b[2], b[1] + 0.5, 0.15, b[2] + 0.3, "bone"); B.fill(b[1] + 0.1, 0.15, b[2] + 0.05, b[1] + 0.25, 0.3, b[2] + 0.2, "bone") end
    elseif theme == "library" and not lay then
        for _, sh in ipairs(deco_library_plan(room, mk)) do
            local x, z, len = sh[1], sh[2], sh[4] - sh[2]
            B.fill(x, 0, z, x + 0.8, 3.2, z + len, "dark_wood")
            for k = 0, 3 do
                local y = 0.35 + k * 0.75
                for b = 0, floor(len / 0.5) - 1 do
                    B.fill(x - 0.04, y, z + b * 0.5 + 0.05, x + 0.84, y + 0.55, z + b * 0.5 + 0.42, ((b + k) % 3 == 0) and "chest_wood" or "dark_wood")
                end
            end
        end
    elseif theme == "depot" and not lay then
        for _, st in ipairs(deco_depot_plan(room, mk)) do
            for k = 0, st[3] - 1 do B.fill(st[1] + k * 0.1, k * 1.2, st[2], st[1] + 1.3 + k * 0.1, (k + 1) * 1.2, st[2] + 1.3, "dark_wood") end
        end
    elseif theme == "prize" then
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        B.fill(cx - 5, 0, cz - 2.5, cx + 5, 0.4, cz + 2.5, "dark_wood")
        B.fill(cx - 5, 0.4, cz - 2.5, cx + 5, 0.45, cz + 2.5, "carpet")
        for _, dx in ipairs({ -5.5, 5.2 }) do for _, dz in ipairs({ -3, 3 }) do if not deco_near_door(room, doors, cx + dx, cz + dz, 3) then B.pillar(cx + dx, cz + dz, 0.5, 0, h, "gold") end end end
    elseif theme == "captive" then
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        local x0, z0, x1, z1 = cx - 2, cz - 2, cx + 2, cz + 2
        B.fill(x0, 0, z0, x1, 0.15, z1, "metal")
        for t = 0, 8 do
            local u = t * 0.5
            B.fill(x0 + u, 0, z0, x0 + u + 0.12, 3.2, z0 + 0.12, "metal"); B.fill(x0 + u, 0, z1 - 0.12, x0 + u + 0.12, 3.2, z1, "metal")
            B.fill(x0, 0, z0 + u, x0 + 0.12, 3.2, z0 + u + 0.12, "metal"); B.fill(x1 - 0.12, 0, z0 + u, x1, 3.2, z0 + u + 0.12, "metal")
        end
        B.fill(x0, 3.2, z0, x1, 3.4, z1, "metal")
        B.fill(x0 + 1.5, 0.9, z1 - 0.2, x0 + 1.9, 1.3, z1 + 0.1, "gold")
    elseif theme == "arena" then
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        for _, d in ipairs(doors or {}) do                                    -- the themed door: a gold frame and a sign (the notice) over the opening
            local p = d.pos
            if d.side == "E" or d.side == "W" then
                local x = (d.side == "E") and room.x + room.w - 0.5 or room.x
                B.fill(x, 0, p - 3.4, x + 0.5, 5.2, p - 3.0, "gold"); B.fill(x, 0, p + 3.0, x + 0.5, 5.2, p + 3.4, "gold"); B.fill(x, 4.6, p - 3.4, x + 0.5, 5.2, p + 3.4, "gold")
                local xs = (d.side == "E") and x - 0.15 or x + 0.5; B.fill(xs, 3.8, p - 1.2, xs + 0.15, 4.5, p + 1.2, "neon_red")
            else
                local z = (d.side == "S") and room.z + room.d - 0.5 or room.z
                B.fill(p - 3.4, 0, z, p - 3.0, 5.2, z + 0.5, "gold"); B.fill(p + 3.0, 0, z, p + 3.4, 5.2, z + 0.5, "gold"); B.fill(p - 3.4, 4.6, z, p + 3.4, 5.2, z + 0.5, "gold")
                local zs = (d.side == "S") and z - 0.15 or z + 0.5; B.fill(p - 1.2, 3.8, zs, p + 1.2, 4.5, zs + 0.15, "neon_red")
            end
        end
        B.ring(cx, cz, 7.5, 8.2, 0, 0.1, "gold")
        for i = 0, 7 do
            local a = i * math.pi / 4 + math.pi / 8
            local px, pz = cx + math.cos(a) * 9.5, cz + math.sin(a) * 8
            if not deco_near_door(room, doors, px, pz, 3.5) then B.pillar(px, pz, 0.7, 0, h, "marble") end
        end
    elseif theme == "safe" then
        local plan = deco_safe_plan(room, doors, false)
        local X, Z = plan.X, plan.Z
        local function F(u0, y0, v0, u1, y1, v1, mat) B.fill(math.min(X(u0), X(u1)), y0, math.min(Z(v0), Z(v1)), math.max(X(u0), X(u1)), y1, math.max(Z(v0), Z(v1)), mat) end
        local function C(u0, y0, v0, u1, y1, v1) F(u0, y0, v0, u1, y1, v1, nil) end
        F(4, 0, 4, 12, 0.05, 12, "carpet"); F(3.9, 0, 3.9, 12.1, 0.05, 4, "gold"); F(3.9, 0, 12, 12.1, 0.05, 12.1, "gold")
        F(5, 0, 0, 11, 3.0, 1.2, "brick"); C(6, 0, 0, 10, 1.8, 1.2); F(6, 0, 0, 10, 0.2, 1, "obsidian"); F(4.4, 3.0, 0, 11.6, 3.4, 1.6, "marble")
        for _, e in ipairs({ { "shelf_a", 2 }, { "shelf_b", 12.5 } }) do
            if not plan.dropped[e[1]] then
                local dv = e[2]
                F(0, 0, dv, 1.2, 3.6, dv + 3, "dark_wood")
                local sh = 0.4
                while sh <= 3.2 do
                    F(1.2, sh, dv + 0.1, 1.6, sh + 0.05, dv + 2.9, "dark_wood")
                    for b = 0, 9 do local bz = dv + 0.15 + b * 0.27; F(1.2, sh + 0.05, bz, 1.55, sh + 0.55, bz + 0.23, (b % 2 == 0) and "chest_wood" or "dark_wood") end
                    sh = sh + 0.7
                end
            end
        end
        if not plan.dropped.sofa then
            F(2, 0, 12.2, 6.5, 0.5, 14, "carpet"); F(2, 0.5, 13.4, 6.5, 1.3, 14, "carpet")
            F(2, 0.5, 12.2, 2.5, 0.9, 14, "carpet"); F(6, 0.5, 12.2, 6.5, 0.9, 14, "carpet")
        end
        if not plan.dropped.table then F(8, 0, 12.6, 10, 0.6, 14, "dark_wood") end
        F(14, 0, 3, 16, 3.3, 6, "metal"); F(13.6, 0.8, 3.2, 14, 2.6, 5.8, "lantern"); F(13.55, 0.9, 5.1, 13.7, 1.2, 5.6, "gold")
        F(13.55, 2.0, 3.4, 13.7, 2.4, 4.7, "neon_red")
        F(12, 0, 0.6, 14.2, 0.9, 2.8, "marble"); B.sphere(X(13.1), 1.6, Z(1.7), 0.62, "rune")
        if not plan.dropped.bed then F(2, 0, 7, 4.4, 0.4, 9.2, "dark_wood"); F(2.2, 0.4, 7.2, 4.2, 0.6, 9, "sand") end
    elseif theme == "rest" then
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        B.fill(room.x + 1, 0, room.z + 1, room.x + room.w - 1, 0.05, room.z + room.d - 1, "carpet")
        -- three cots along a wall without a door (the first of W, E, N, S that has none), the fountain by the middle, a screen on the opposite wall
        local used = {}
        for _, d in ipairs(doors or {}) do used[d.side] = true end
        local side = "W"
        for _, sd in ipairs({ "W", "E", "N", "S" }) do if not used[sd] then side = sd; break end end
        for i = 0, 2 do
            local o = 2 + i * 2.6
            if side == "W" then B.fill(room.x + 0.4, 0, room.z + o, room.x + 2.4, 0.4, room.z + o + 1.0, "dark_wood"); B.fill(room.x + 0.5, 0.4, room.z + o + 0.05, room.x + 2.3, 0.55, room.z + o + 0.95, "sand")
            elseif side == "E" then B.fill(room.x + room.w - 2.4, 0, room.z + o, room.x + room.w - 0.4, 0.4, room.z + o + 1.0, "dark_wood"); B.fill(room.x + room.w - 2.3, 0.4, room.z + o + 0.05, room.x + room.w - 0.5, 0.55, room.z + o + 0.95, "sand")
            elseif side == "N" then B.fill(room.x + o, 0, room.z + 0.4, room.x + o + 1.0, 0.4, room.z + 2.4, "dark_wood"); B.fill(room.x + o + 0.05, 0.4, room.z + 0.5, room.x + o + 0.95, 0.55, room.z + 2.3, "sand")
            else B.fill(room.x + o, 0, room.z + room.d - 2.4, room.x + o + 1.0, 0.4, room.z + room.d - 0.4, "dark_wood"); B.fill(room.x + o + 0.05, 0.4, room.z + room.d - 2.3, room.x + o + 0.95, 0.55, room.z + room.d - 0.5, "sand") end
        end
        B.fill(cx - 1, 0, cz - 1, cx + 1, 0.8, cz + 1, "marble"); B.fill(cx - 0.8, 0.8, cz - 0.8, cx + 0.8, 0.95, cz + 0.8, "gutter_water")       -- the fountain
    elseif theme == "stairs_free" then
        -- the stairwell of the books: a round hole of 3.3 m radius with a lit rim, a wide stair (0.45 m steps) down its west side to a floor 2.25 m below
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        B.pillar(cx, cz, 3.3, -2.3, 0, nil)
        B.ring(cx, cz, 3.3, 3.7, 0, 0.45, "marble")
        for k = 1, 5 do B.fill(cx - 3.3 + (k - 1) * 0.9, -2.3, cz - 1.6, cx - 3.3 + k * 0.9, -0.45 * k, cz + 1.6, "marble") end
        B.pillar(cx, cz, 3.3, -2.35, -2.3, "gold")
        for i = 0, 7 do local a = i * math.pi / 4 + math.pi / 8; local px, pz = cx + math.cos(a) * 3.55, cz + math.sin(a) * 3.55; B.fill(px - 0.12, 0.45, pz - 0.12, px + 0.12, 0.85, pz + 0.12, "lantern") end
    elseif theme == "borough" or theme == "park" then
        deco_borough(B, (room.x == 0) and 1 or 0, (room.z == 0) and 1 or 0, fl)
    elseif theme == "village" then
        deco_village(B, (room.x == 0) and 1 or 0, (room.z == 0) and 1 or 0, room, doors, mk)
    elseif theme == "connector" and (fl or 1) == 3 then
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2              -- a locator stone at the junction
        B.pillar(cx, cz, 0.45, 0, 2.2, "marble"); B.pillar(cx, cz, 0.3, 2.2, 2.6, "lantern")
    end
    for _, sc in ipairs(deco_sconce_plan(theme, room, doors)) do deco_sconce(B, sc) end
    if not open then for _, lm in ipairs(deco_lamp_plan(theme, room)) do deco_lamp(B, lm, h, 1.2) end end
    -- graffiti on a wall without a door of about one room in five (not in the special rooms)
    local PLAIN = { hall = true, crypt = true, library = true, depot = true, grotto = true, flooded = true, furnace = true, ballroom = true, warlord = true, captive = true, prize = true }
    if PLAIN[theme] and mk(4).next() < 0.22 then
        local LINES = { "THE FLOOR IS LAVA (IT IS NOT)", "I WAS HERE. NOBODY ELSE WAS", "DO NOT FEED THE MANAGER", "EXIT -> (NOT THIS WAY)", "UNION OF CONTESTANTS LOCAL 7", "SPONSOR ME", "THE CRATES LIE",
                        "GLEE IS WATCHING", "PLEASE STAND CLEAR OF THE CEILING", "ASK ABOUT OUR VENDING MACHINES", "FOUND A SAFE ROOM. LOST IT", "NO REFUNDS" }
        local txt = LINES[mk(5).int(1, #LINES)]
        local used = {}
        for _, d in ipairs(doors or {}) do used[d.side] = true end
        local len = deco_text_len(txt)
        local cx, cz = room.x + room.w / 2, room.z + room.d / 2
        if not used.N then deco_text(B, cx - len / 2, 1.7, room.z + 0.0, txt, "+z", "neon_red")
        elseif not used.S then deco_text(B, cx + len / 2, 1.7, room.z + room.d, txt, "-z", "neon_red")
        elseif not used.W then deco_text(B, room.x, 1.7, cz + len / 2, txt, "+x", "neon_red")
        elseif not used.E then deco_text(B, room.x + room.w, 1.7, cz - len / 2, txt, "-x", "neon_red") end
    end
    for _, c in ipairs(deco_crates(theme, room, doors, mk, fl or 1)) do deco_chest(B, c.tier, c.x, c.y, c.z, c.face) end
    if theme == "depot" and not lay then
        local _, barrels = deco_depot_plan(room, mk)
        for _, b in ipairs(barrels) do deco_barrel(B, b[1], 0, b[2]) end
    end
end
