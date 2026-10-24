-- gen/shell: the BIG floors as static placements of the region hook (P1 of ~/share/big-floors-plan.md). A region is one 32 m cell: `on_region(rx, rz)` -> shell_region(rx, rz, worldgen.hash).
-- Pure and global (hook_globals = { "cellgen_make", "cellgen_hash_from", "shell_region" } in level.lua): no file locals, no Game.
--
-- Where: floor n lives in the band of regions rz = n * 32 + 1 + (cj + 1) .. , i.e. z = n * 1024 m + 64 m + cj * 32 m, x = ci * 32 m (ring regions ci or cj = -1 and W / H carry the outer half of the rim arteries).
-- What: every region starts with a solid mass of dungeon brick over its whole cell (y 6 m .. 21.6 m) and CARVES: its room, its half of every hall (to the cell border, with the jog to the neighbour's door:
-- both cells carve their own half of the jog, so no region ever touches another), the 4 m strips of the arteries on the block borders, then the floor layer and the ceiling lights.
-- Heights: the floor is at y = 128 voxels (8 m), rooms 6-10 m (arena 12), arteries 9 m, halls 5 m, alleys 3 m.
function shell_region(rx, rz, wh, run)
    local V = 16
    local fl = (rz - 1) // 32
    local ci, cj = rx, rz - fl * 32 - 2
    if fl < 1 or fl > 8 or fl == 4 then return {} end
    local CG = cellgen_make(cellgen_hash_from(wh, run))
    local P = CG.params(fl, "small")
    if not P or (P.kind ~= "grid" and P.kind ~= "ruin") or ci < -1 or cj < -1 or ci > P.W or cj > P.H then return {} end
    local ctx = CG.new(0, fl, "small")
    local H_ = cellgen_hash_from(wh, run)
    local info_open, info_door
    local W, H = P.W, P.H
    local X0, Z0 = rx * 512, rz * 512
    local ops = {}
    -- floor 3 is the open-air over-city: the ground of the plain (grass up to voxel 400) is the floor, the mass is a ruin wall of 9 m on it and everything carved is open to the sky
    local OPEN = (P.kind == "ruin")
    local YF, YB, YT = 128, 64, 360               -- floor surface (first air voxel), bottom and top of the brick mass
    if OPEN then YF, YB, YT = 401, 399, 401 + 144 end
    local SKY = 300                               -- the height of what is carved in the open: to the sky
    local function R(v) return math.floor(v * V + 0.5) end
    -- an axis box in metres local to the cell (x0, x1, z0, z1 half open), y in voxels (y0, y1 inclusive); clipped to the cell
    local function box(x0, x1, z0, z1, y0, y1, mat)
        x0, z0 = math.max(0, x0), math.max(0, z0); x1, z1 = math.min(32, x1), math.min(32, z1)
        if x1 <= x0 or z1 <= z0 then return end
        ops[#ops + 1] = { kind = mat and "box" or "clear", lo = { X0 + R(x0), y0, Z0 + R(z0) }, hi = { X0 + R(x1) - 1, y1, Z0 + R(z1) - 1 }, material = mat }
    end
    local function carve(x0, x1, z0, z1, hvox) box(x0, x1, z0, z1, YF, YF + hvox - 1) end
    local DX = { E = 1, W = -1, S = 0, N = 0 }
    local DZ = { E = 0, W = 0, S = 1, N = -1 }
    local OPP = { E = "W", W = "E", S = "N", N = "S" }
    local function inside(a, b) return a >= 0 and b >= 0 and a < W and b < H end
    local in_cell = inside(ci, cj)
    local deco
    local WALL = { flooded = "mossy", grotto = "cavestone", library = "dark_wood", safe = "dark_wood", rest = "dark_wood" }
    -- the mass: the cell's whole volume in the wall material of its theme (everything below is carved out of it)
    local base_wall = OPEN and "ruin_stone" or ((fl == 2) and "cinderblock" or "dungeon_brick")          -- floor 2: the orange city is cinderblock, floor 3 weathered stone
    local mass_mat = base_wall
    if in_cell then local th = CG.cell(ctx, ci, cj).theme; mass_mat = WALL[th] or base_wall end
    box(0, 32, 0, 32, YB, YT, mass_mat)
    if OPEN then                                                          -- broken wall tops: a few notches of 1-3 m
        for k = 1, 5 do
            if H_(0, fl * 1000 + 840, ci, cj, k) < 0.75 then
                local nx, nz = H_(0, fl * 1000 + 841, ci, cj, k) * 28, H_(0, fl * 1000 + 842, ci, cj, k) * 28
                local nw, nd, nh = 2 + H_(0, fl * 1000 + 843, ci, cj, k) * 5, 2 + H_(0, fl * 1000 + 844, ci, cj, k) * 5, 16 + math.floor(H_(0, fl * 1000 + 845, ci, cj, k) * 32)
                box(nx, nx + nw, nz, nz + nd, YT - nh, YT, nil)
            end
        end
    end
    local lights = {}
    local function light(x, z, y, mat) if not OPEN then lights[#lights + 1] = { x, z, y, mat } end end
    local LM = (fl == 2) and "lichen_orange" or "lantern"                 -- the ceiling lights: yellow lanterns, on floor 2 orange lichen (the side halls are lichen-lit on both: green, orange)
    local floors = {}                              -- floor material boxes, placed after the carving
    local function floor_mat(x0, x1, z0, z1, mat) floors[#floors + 1] = { x0, x1, z0, z1, mat } end

    -- the builder of the decoration (rooms, halls, streets): B.fill and B.vbox put boxes of the cell's own metres / voxels, B.sphere, B.pillar and B.ring the round things
    local B = {}
    local function yv(y) return YF + R(y) end
    local function rows(cx, cz, r, y0, y1, mat, r0)
        local RV, R0 = R(r), R(r0 or 0)
        for dz = -RV, RV do
            local w1 = math.floor(math.sqrt(RV * RV - dz * dz) + 0.5)
            local lo, hi = X0 + R(cx) - w1, X0 + R(cx) + w1
            local z = Z0 + R(cz) + dz
            local kind = mat and "box" or "clear"
            if math.abs(dz) >= R0 then
                ops[#ops + 1] = { kind = kind, lo = { lo, yv(y0), z }, hi = { hi, yv(y1) - 1, z }, material = mat }
            else
                local w0 = math.floor(math.sqrt(R0 * R0 - dz * dz) + 0.5)
                ops[#ops + 1] = { kind = kind, lo = { lo, yv(y0), z }, hi = { X0 + R(cx) - w0 - 1, yv(y1) - 1, z }, material = mat }
                ops[#ops + 1] = { kind = kind, lo = { X0 + R(cx) + w0 + 1, yv(y0), z }, hi = { hi, yv(y1) - 1, z }, material = mat }
            end
        end
    end
    function B.fill(x0, y0, z0, x1, y1, z1, mat)
        local ax, az, bx, bz = X0 + R(x0), Z0 + R(z0), X0 + R(x1) - 1, Z0 + R(z1) - 1
        local ay, by = yv(y0), yv(y1) - 1
        if bx < ax or bz < az or by < ay then return end
        ops[#ops + 1] = { kind = mat and "box" or "clear", lo = { ax, ay, az }, hi = { bx, by, bz }, material = mat }
    end
    function B.vbox(x0, y0, z0, x1, y1, z1, mat) ops[#ops + 1] = { kind = "box", lo = { X0 + x0, YF + y0, Z0 + z0 }, hi = { X0 + x1, YF + y1, Z0 + z1 }, material = mat } end
    function B.sphere(cx, cy, cz, r, mat) ops[#ops + 1] = { kind = "sphere", c = { X0 + R(cx), yv(cy), Z0 + R(cz) }, r = R(r), material = mat } end
    function B.pillar(cx, cz, r, y0, y1, mat) rows(cx, cz, r, y0, y1, mat, 0) end
    function B.ring(cx, cz, r0, r1, y0, y1, mat) rows(cx, cz, r1, y0, y1, mat, r0) end

    -- the arteries: 4 m strips along every side that lies on a block border (and the rim ring's half)
    local function artery_side(d)
        local len = (fl == 2) and 3 or 4                           -- (floor 2: narrower arteries, 6 m)
        if d == "E" then carve(32 - len, 32, 0, 32, 144); floor_mat(32 - len, 32, 0, 32, "flagstone")
        elseif d == "W" then carve(0, len, 0, 32, 144); floor_mat(0, len, 0, 32, "flagstone")
        elseif d == "S" then carve(0, 32, 32 - len, 32, 144); floor_mat(0, 32, 32 - len, 32, "flagstone")
        else carve(0, 32, 0, len, 144); floor_mat(0, 32, 0, len, "flagstone") end
        for t = 4, 28, 8 do
            if d == "E" then light(32 - 2, t, YF + 143) elseif d == "W" then light(2, t, YF + 143)
            elseif d == "S" then light(t, 32 - 2, YF + 143) else light(t, 2, YF + 143) end
        end
        if in_cell then                                          -- the street: lamp posts, benches, banners, a gutter and drains along the inner wall, off the mouths of the halls that open into it
            local inf = CG.cell(ctx, ci, cj)
            local mouths = {}
            if inf.open[d] == "artery" and inf.door and inf.door[d] then mouths[1] = { inf.door[d], 6 } end
            deco_street(B, { side = d, w = len, doors = mouths }, function(salt) return deco_rng(H_, fl, ci, cj, salt or 1) end, fl)
        end
    end
    if in_cell and not OPEN then
        for _, d in ipairs({ "E", "S", "W", "N" }) do
            if (d == "E" and ci % 8 == 7) or (d == "W" and ci % 8 == 0) or (d == "S" and cj % 8 == 7) or (d == "N" and cj % 8 == 0) then artery_side(d) end
        end
    elseif not OPEN then
        -- a ring region: the strips of the cells that face it (the corner squares come from the strips of its two neighbours' sides)
        if ci == -1 and cj >= -1 and cj <= H then artery_side("E") end
        if ci == W and cj >= -1 and cj <= H then artery_side("W") end
        if cj == -1 and ci >= -1 and ci <= W then artery_side("S") end
        if cj == H and ci >= -1 and ci <= W then artery_side("N") end
    end

    -- the name of the block at the corners of the arteries: gold text on the wall next to the strip, facing it
    if in_cell and not OPEN and (ci % 8 == 0 or ci % 8 == 7) and (cj % 8 == 0 or cj % 8 == 7) then
        local Bt = { vbox = function(x0, y0, z0, x1, y1, z1, mat) ops[#ops + 1] = { kind = "box", lo = { X0 + x0, YF + y0, Z0 + z0 }, hi = { X0 + x1, YF + y1, Z0 + z1 }, material = mat } end }
        local txt = "BLOCK " .. string.char(65 + ci // 8) .. (cj // 8 + 1)
        local len = deco_text_len(txt)
        if cj % 8 == 0 then deco_text(Bt, 16 + len / 2, 2.4, 4, txt, "-z", "gold") else deco_text(Bt, 16 - len / 2, 2.4, 28, txt, "+z", "gold") end
    end
    if in_cell then
        local info = CG.cell(ctx, ci, cj)
        info_open, info_door = info.open, info.door
        local r = info.room
        local theme = info.theme
        local hall_w = { tree = 6, loop = 6, side = 4, alley = 3, artery = 6, road = 6 }
        local hall_h = { tree = 80, loop = 80, side = 80, alley = 48, artery = 80, road = 80 }
        if OPEN then for k in pairs(hall_h) do hall_h[k] = SKY end end
        if r then
            local hv = (r.h + ((theme == "ballroom") and 2 or 0)) * V
            if OPEN then hv = SKY end
            carve(r.x, r.x + r.w, r.z, r.z + r.d, hv)
            local FLOOR = { warlord = "obsidian", ballroom = "marble", grotto = "cavestone", library = "dark_wood", safe = "dark_wood", rest = "dark_wood", prize = "marble", arena = "marble",
                            stairs_free = "marble" }
            floor_mat(r.x, r.x + r.w, r.z, r.z + r.d, FLOOR[theme] or "flagstone")
            -- ceiling lights: a grid of 8 m
            for x = r.x + 4, r.x + r.w - 2, 8 do for z = r.z + 4, r.z + r.d - 2, 8 do light(x, z, YF + hv - 1) end end
            deco = { theme = theme, room = r }
            if OPEN and theme ~= "village" and theme ~= "park" then floor_mat(r.x, r.x + r.w, r.z, r.z + r.d, "cobble") end
        end
        -- the halls: from one metre inside the room to the cell border, and the jog to the neighbour's door
        for _, d in ipairs({ "E", "S", "W", "N" }) do
            local kind = info.open[d]
            if kind and kind ~= "internal" and info.door and info.door[d] then
                local c = info.door[d]
                local hw, hh = hall_w[kind] or 6, hall_h[kind] or 80
                local a, b = c - hw / 2, c + hw / 2
                local ni, nj = ci + DX[d], cj + DZ[d]
                -- the far end of this cell's half: the border (32 / 0), or 3 m into the artery strip when the neighbour is the rim / across a block border
                local toward = (kind == "artery") and 3 or 0
                local function hcarve(x0, x1, z0, z1) carve(x0, x1, z0, z1, hh); if OPEN then floor_mat(x0, x1, z0, z1, "cobble") end end
                if d == "E" then hcarve(r.x + r.w - 1, 32, a, b)
                elseif d == "W" then hcarve(0, r.x + 1, a, b)
                elseif d == "S" then hcarve(a, b, r.z + r.d - 1, 32)
                else hcarve(a, b, 0, r.z + 1) end
                if kind ~= "artery" and inside(ni, nj) then
                    local nb = CG.cell(ctx, ni, nj)
                    local cn = nb.door and nb.door[OPP[d]]
                    if cn and cn ~= c then
                        local lo, hi = math.min(c, cn) - hw / 2, math.max(c, cn) + hw / 2
                        local t = hw / 2
                        if d == "E" then hcarve(32 - t, 32, lo, hi) elseif d == "W" then hcarve(0, t, lo, hi)
                        elseif d == "S" then hcarve(lo, hi, 32 - t, 32) else hcarve(lo, hi, 0, t) end
                    end
                end
                -- a bathroom door: a landmark on the wall at the middle of some halls (a plain plate and a sign; it sits at the middle of the hall, never on a door band)
                if not OPEN and (d == "E" or d == "S") and (kind == "tree" or kind == "loop") and H_(0, fl * 1000 + 830, ci, cj, (d == "E") and 1 or 2) < 0.3 then
                    if d == "E" then
                        local xm = (r.x + r.w + 32) / 2
                        box(xm - 0.8, xm + 0.8, a - 0.12, a, YF, YF + 38, "dark_wood"); box(xm - 0.4, xm + 0.4, a - 0.12, a, YF + 42, YF + 50, "lantern")
                    else
                        local zm = (r.z + r.d + 32) / 2
                        box(a - 0.12, a, zm - 0.8, zm + 0.8, YF, YF + 38, "dark_wood"); box(a - 0.12, a, zm - 0.4, zm + 0.4, YF + 42, YF + 50, "lantern")
                    end
                end
                -- the hall's own decoration (pilasters, beams, a runner, trim in the palette of the room it leaves; pipes in a side hall; rubble and crates in an alley): floors 1, 2 and up under a roof
                if not OPEN then
                    local seg = deco_hall_seg(info, d)
                    if seg then deco_hall(B, seg, function(salt) return deco_rng(H_, fl, ci, cj, (salt or 1) + (d == "E" and 0 or (d == "S" and 20 or (d == "W" and 40 or 60)))) end, fl) end
                end
                -- a light in the middle of every hall's half
                if kind ~= "alley" then
                    local lm = (kind == "side") and ((fl == 2) and "lichen_orange" or "lichen_green") or nil
                    if d == "E" then light(r.x + r.w + (32 - r.x - r.w) / 2, c, YF + hh - 1, lm) elseif d == "W" then light(r.x / 2, c, YF + hh - 1, lm)
                    elseif d == "S" then light(c, r.z + r.d + (32 - r.z - r.d) / 2, YF + hh - 1, lm) else light(c, r.z / 2, YF + hh - 1, lm) end
                end
            end
        end
    end
    for _, f in ipairs(floors) do box(f[1], f[2], f[3], f[4], YF - 2, YF - 1, f[5]) end
    if deco then
        local doors = {}
        for _, d in ipairs({ "E", "S", "W", "N" }) do
            local k = info_open and info_open[d]
            if k and k ~= "internal" and info_door and info_door[d] then doors[#doors + 1] = { side = d, pos = info_door[d] } end
        end
        local oci, ocj = ci, cj
        local sup = CG.super_of(ctx, ci, cj)
        if sup then oci, ocj = sup.ci, sup.cj end                         -- (the four cells of a super-cell draw one plan)
        deco_room(B, deco.theme, deco.room, doors, function(salt) return deco_rng(H_, fl, oci, ocj, salt or 1) end, fl)
    end
    for _, l in ipairs(lights) do box(l[1] - 0.0625, l[1] + 0.0625, l[2] - 0.0625, l[2] + 0.0625, l[3], l[3], l[4] or LM) end
    return ops
end
