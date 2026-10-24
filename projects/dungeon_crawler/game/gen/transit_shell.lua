-- gen/transit_shell: the Iron Tangle (floor 4) as static placements of the region hook (T1 of ~/share/floor4-design.md). One region = one 32 m cell, like shell_region; the plan is gen/transit.lua.
-- Every cell starts as a solid mass of dungeon brick (y -4 m .. +17 m around the floor surface) and CARVES: its room, the halls to its doors, the bed of every track (a trench 0.25 m deep: the deck of
-- a car lies in it flush with the platform), then the floor, the sleepers and rails, lights, pillars; B1 / B3 hold the stair up to the Blue level (+8 m), X is a two-storey hall.
-- Coordinates: metres local to the cell (x, z); y metres above the floor surface of level 0.
function transit_region(rx, rz, wh, run)
    local fl = (rz - 1) // 32
    if fl ~= 4 then return {} end
    local ci, cj = rx, rz - fl * 32 - 2
    if ci < 0 or cj < 0 or ci > 4 or cj > 4 then return {} end
    local info = transit_cell_info(ci, cj)
    local X0, Z0 = rx * 512, rz * 512
    local YF = 128
    local ops = {}
    local B = deco_builder(ops, X0, Z0, YF)
    local code, room, lv = info.code, info.room, info.level
    local yl = lv * transit_const().level_m              -- the floor level of this cell's room
    local floor, max, min = math.floor, math.max, math.min
    local function F(x0, y0, z0, x1, y1, z1, mat)
        B.fill(max(0, x0), y0, max(0, z0), min(32, x1), y1, min(32, z1), mat)
    end
    local HW = transit_hall_widths()
    local lines = transit_lines()
    -- the mass
    F(0, -4, 0, 32, 17, 32, "dungeon_brick")
    local function carve(x0, z0, x1, z1, y0, y1) F(x0, y0, z0, x1, y1, z1, nil) end
    local function floor_mat(x0, z0, x1, z1, y, mat) F(x0, y - 0.125, z0, x1, y, z1, mat) end

    -- ------------------------------------------------------------------------------------------ the rooms
    local rx0, rz0, rx1, rz1 = room.x, room.z, room.x + room.w, room.z + room.d
    local top = room.y + room.h
    if code == "B" then
        -- the Blue station: a stair corridor (6 m wide) up from the hub at level 0 over the first 16 m, then the platform hall at +8 m
        local north = (cj == 1)                                   -- B1: the stair is at the north end, B3: at the south end
        local s0, s1 = north and 0 or 16, north and 16 or 32
        local p0, p1 = north and 16 or 0, north and 32 or 16
        carve(13, s0, 19, s1, 0, top)                             -- the stair corridor, from the level-0 floor to the ceiling of level 1
        carve(rx0, p0, rx1, p1, yl, top)                          -- the platform hall
        for k = 0, 15 do                                           -- the steps: 0.5 m a metre of run
            local z0 = north and k or (31 - k)
            F(13, 0, z0, 19, 0.5 * (k + 1), z0 + 1, "marble")
        end
        floor_mat(rx0, p0, rx1, p1, yl, "marble")
        F(rx0, 0, p0, rx1, yl - 0.125, p1, "dungeon_brick")
        floor_mat(13, s0, 19, s1, 0, "marble")
        -- the rail along the edge of the platform up there and at the head of the stair
        for _, zz in ipairs(north and { 16 } or { 15.9 }) do F(13, yl, zz, 19, yl + 0.1, zz + 0.1, "metal") end
    elseif code == "X" then
        carve(rx0, rz0, rx1, rz1, 0, top)                         -- the hall: two storeys, 14 m
        floor_mat(rx0, rz0, rx1, rz1, 0, "marble")
        -- the upper deck (Blue, +8 m): a slab 1 m thick over the whole hall except the stair strip along the north wall (z 4 .. 7)
        F(rx0, yl - 1, rz0 + 3, rx1, yl, rz1, "dungeon_brick"); floor_mat(rx0, rz0 + 3, rx1, rz1, yl, "marble")
        for k = 0, 23 do F(rx0 + k, 0, rz0, rx0 + k + 1, (k + 1) * yl / 24, rz0 + 3, "marble") end     -- the stair: 24 steps eastward along the north wall, up to the deck
        F(rx0, yl, rz0 + 3, rx1 - 1, yl + 1.0, rz0 + 3.1, "metal")                                          -- the rail along the stair's opening
        -- the pit: a round hole in the deck, a guard ring and the glow of the Abyss
        for _, p in ipairs({ { 22, 22 } }) do B.pillar(p[1], p[2], 2.6, yl - 1, yl, nil); B.ring(p[1], p[2], 2.6, 3.0, yl, yl + 1.0, "metal") end
        F(21.6, yl + 0.5, 18.85, 22.4, yl + 1.0, 18.95, "gold")                                      -- the plaque on the rail of the pit: THE ABYSS (a button of the game)
        -- the columns that carry the deck (the cars and the Yellow platform stay clear: the columns stand at the corners)
        for _, p in ipairs({ { 6, 9 }, { 26, 9 }, { 6, 23 }, { 26, 23 } }) do B.pillar(p[1], p[2], 0.6, 0, yl, "metal") end
    elseif code == "c" then
        carve(rx0, rz0, rx1, rz1, 0, room.h)
        floor_mat(rx0, rz0, rx1, rz1, 0, "dungeon_brick")                  -- (plain brick floors in the tunnels: the ground cover rows are for the flagstone rooms)
    elseif code == "d" or code == "s" then
        carve(rx0, rz0, rx1, rz1, 0, room.h)
        floor_mat(rx0, rz0, rx1, rz1, 0, "flagstone")
    else                                                          -- tunnels, hubs, Yellow stations: along the axis
        carve(rx0, rz0, rx1, rz1, yl, yl + room.h)
        floor_mat(rx0, rz0, rx1, rz1, yl, (code == "H" or code == "Y") and "marble" or "dungeon_brick")
    end

    -- ------------------------------------------------------------------------------------------ the halls to the doors
    for side, kind in pairs(info.open) do
        local c, hw = info.door[side], HW[kind] or 6
        local dl = yl
        if code == "X" and (side == "N" or side == "S") then dl = transit_const().level_m end
        if code == "B" and (side == "N" or side == "S") and kind == "stair" then dl = 0 end
        local hh = (kind == "tunnel" or kind == "wide") and 6 or 5
        if dl == 0 and kind == "stair" then hh = 8 end
        if code == "B" and kind == "stair" then
            -- the stair corridor itself reaches the border: nothing to add
        else
            local a, b = c - hw / 2, c + hw / 2
            if side == "E" then carve(rx1 - 0.0, a, 32, b, dl, dl + hh); floor_mat(rx1, a, 32, b, dl, "dungeon_brick")
            elseif side == "W" then carve(0, a, rx0, b, dl, dl + hh); floor_mat(0, a, rx0, b, dl, "dungeon_brick")
            elseif side == "S" then carve(a, rz1, b, 32, dl, dl + hh); floor_mat(a, rz1, b, 32, dl, "dungeon_brick")
            else carve(a, 0, b, rz0, dl, dl + hh); floor_mat(a, 0, b, rz0, dl, "dungeon_brick") end
        end
    end

    -- ------------------------------------------------------------------------------------------ the tracks
    local BED = 4.2
    for _, line in ipairs(lines) do
        local pts = line.points
        local n = #pts
        local last = line.closed and n or n - 1
        local ly = line.level * transit_const().level_m
        for i = 1, last do
            local a, b = pts[i], pts[i % n + 1]
            local ax, az, bx, bz = a[1] - ci * 32, a[2] - cj * 32, b[1] - ci * 32, b[2] - cj * 32
            local dx, dz = bx - ax, bz - az
            local len = math.sqrt(dx * dx + dz * dz)
            if len > 0 and max(ax, bx) > -2 and min(ax, bx) < 34 and max(az, bz) > -2 and min(az, bz) < 34 then
                if dx == 0 or dz == 0 then                         -- a straight: one bed, sleepers every metre, two rails
                    local x0, x1, z0, z1 = min(ax, bx), max(ax, bx), min(az, bz), max(az, bz)
                    local along_x = (dz == 0)
                    local hb = BED / 2
                    if along_x then F(x0, ly - 0.25, z0 - hb, x1, ly, z0 + hb, nil) else F(x0 - hb, ly - 0.25, z0, x0 + hb, ly, z1, nil) end
                    if along_x then
                        F(x0, ly - 0.25, z0 - 1.25, x1, ly - 0.2, z0 - 1.13, "metal"); F(x0, ly - 0.25, z0 + 1.13, x1, ly - 0.2, z0 + 1.25, "metal")
                        local t = math.ceil(max(0, x0)); while t < min(32, x1) do F(t, ly - 0.25, z0 - 1.6, t + 0.3, ly - 0.22, z0 + 1.6, "dark_wood"); t = t + 1 end
                    else
                        F(x0 - 1.25, ly - 0.25, z0, x0 - 1.13, ly - 0.2, z1, "metal"); F(x0 + 1.13, ly - 0.25, z0, x0 + 1.25, ly - 0.2, z1, "metal")
                        local t = math.ceil(max(0, z0)); while t < min(32, z1) do F(x0 - 1.6, ly - 0.25, t, x0 + 1.6, ly - 0.22, t + 0.3, "dark_wood"); t = t + 1 end
                    end
                else                                                -- an arc chord: dots along it
                    local nx, nz = -dz / len, dx / len
                    local t = 0
                    while t <= len do
                        local px, pz = ax + dx * t / len, az + dz * t / len
                        if px > 0 and px < 32 and pz > 0 and pz < 32 then
                            F(px - BED / 2, ly - 0.25, pz - BED / 2, px + BED / 2, ly, pz + BED / 2, nil)
                        end
                        t = t + 1
                    end
                    t = 0
                    while t <= len do
                        local px, pz = ax + dx * t / len, az + dz * t / len
                        for _, o in ipairs({ -1.6, -0.8, 0, 0.8, 1.6 }) do
                            local qx, qz = px + nx * o, pz + nz * o
                            if qx > 0.2 and qx < 31.8 and qz > 0.2 and qz < 31.8 then F(qx - 0.15, ly - 0.25, qz - 0.15, qx + 0.15, ly - 0.22, qz + 0.15, "dark_wood") end
                        end
                        for _, o in ipairs({ -1.19, 1.19 }) do
                            local qx, qz = px + nx * o, pz + nz * o
                            if qx > 0.2 and qx < 31.8 and qz > 0.2 and qz < 31.8 then F(qx - 0.07, ly - 0.22, qz - 0.07, qx + 0.07, ly - 0.2, qz + 0.07, "metal") end
                        end
                        t = t + 0.5
                    end
                end
            end
        end
    end

    -- ------------------------------------------------------------------------------------------ light, pillars, edges
    local function lamp(x, z, y)
        F(x - 0.15, y, z - 0.15, x + 0.15, y + 0.12, z + 0.15, "lantern")
    end
    if code == "-" or code == "|" then
        for t = 4, 28, 8 do
            if code == "-" then lamp(t, 16, yl + room.h - 0.12); F(t - 0.1, yl + room.h - 0.5, rz0, t + 0.1, yl + room.h, rz1, "metal")
            else lamp(16, t, yl + room.h - 0.12); F(rx0, yl + room.h - 0.5, t - 0.1, rx1, yl + room.h, t + 0.1, "metal") end
        end
    elseif code == "H" or code == "Y" or code == "B" then
        local along_x = (info.axis == "x")
        for t = 4, 28, 8 do
            for _, o in ipairs({ -5, 5 }) do
                local x, z = (along_x and t or 16 + o), (along_x and 16 + o or t)
                if code ~= "B" or (cj == 1 and t > 16) or (cj == 3 and t < 16) then      -- B: the platform half only
                    lamp(x, z, yl + room.h - 0.12)
                    B.pillar(along_x and t or 16 + o * 0.62, along_x and 16 + o * 0.62 or t, 0.35, yl, yl + room.h, "metal")
                end
            end
        end
        -- the edge of the platform: a hazard strip along the bed
        if along_x then F(rx0, yl - 0.0625, 16 - 2.4, rx1, yl, 16 - 2.1, "hazard_y"); F(rx0, yl - 0.0625, 16 + 2.1, rx1, yl, 16 + 2.4, "hazard_y")
        else F(16 - 2.4, yl - 0.0625, rz0, 16 - 2.1, yl, rz1, "hazard_y"); F(16 + 2.1, yl - 0.0625, rz0, 16 + 2.4, yl, rz1, "hazard_y") end
    elseif code == "c" then
        for _, p in ipairs({ { 8, 8 }, { 24, 8 }, { 8, 24 }, { 24, 24 }, { 16, 16 } }) do lamp(p[1], p[2], room.h - 0.12) end
    elseif code == "X" then
        for _, p in ipairs({ { 10, 10 }, { 22, 10 }, { 10, 22 }, { 22, 22 } }) do lamp(p[1], p[2], 7.6); lamp(p[1], p[2], yl + 5.5) end
    end

    -- ------------------------------------------------------------------------------------------ the hubs' fixtures and the signs of the stations
    local text = transit_station_text(info)
    if text then
        local len = deco_text_len(text)
        if code == "X" then deco_text(B, 16 + len / 2, 4.2, 4.0, text, "-z", "gold")                       -- on the north wall of the hall, looking south... (the reader stands south of it)
        elseif info.axis == "x" then deco_text(B, 16 - len / 2, 3.4, rz0, text, "+z", "gold")
        else deco_text(B, rx0, 3.4, 16 + len / 2, text, "+x", "gold") end
    end
    if code == "H" then
        local f = transit_hub_fixtures(info)
        local ax = (info.axis == "x")
        local function fx(x0, y0, z0, x1, y1, z1, mat)        -- a box in the platform's own frame: (u along the wall, v out from it), mapped to the cell
            if ax then F(f.vend.x + x0, y0, f.vend.z - 0.45 + z0, f.vend.x + x1, y1, f.vend.z - 0.45 + z1, mat)
            else F(f.vend.x - 0.45 + z0, y0, f.vend.z + x0, f.vend.x - 0.45 + z1, y1, f.vend.z + x1, mat) end
        end
        fx(-1.2, 0, 0, 1.2, 2.3, 0.9, "metal"); fx(-1.0, 0.8, 0.9, 1.0, 2.0, 0.96, "lantern"); fx(-0.7, 0.9, 0.96, -0.3, 1.2, 1.0, "neon_red")
        local c = f.crystal
        if ax then F(c.x - 0.6, 0, c.z - 0.45, c.x + 0.6, 0.9, c.z + 0.45, "marble") else F(c.x - 0.45, 0, c.z - 0.6, c.x + 0.45, 0.9, c.z + 0.6, "marble") end
        B.sphere(c.x, 1.55, c.z, 0.5, "rune")
    end

    -- the layout grammar's items: benches, kiosks, banners, crates ... (hubs, Yellow stations, dens)
    local lay = transit_layout(info, function(salt) return deco_rng(cellgen_hash_from(wh, run), fl, ci, cj, salt or 1) end)
    if lay then for _, it in ipairs(lay.items) do if it.y0 == nil then it.y0 = 0 end; deco_item_draw(B, it, fl) end end

    -- ------------------------------------------------------------------------------------------ the rooms the grammar furnishes (dens, the stairwell)
    if code == "s" then
        local doors = {}
        for _, d in ipairs({ "E", "S", "W", "N" }) do if info.open[d] then doors[#doors + 1] = { side = d, pos = info.door[d] } end end
        deco_room(B, info.theme, room, doors, function(salt) return deco_rng(cellgen_hash_from(wh, run), fl, ci, cj, salt or 1) end, fl)
    end
    return ops
end
