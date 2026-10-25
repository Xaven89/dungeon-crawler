-- gen/transit: the Iron Tangle (floor 4), pure global functions (hook_globals): the plan of a transit floor (7 x 7 cells, six lines, 17 stations), the tracks of its cars and the sweep check.
-- Design: ~/share/floor4-design.md (reviewed; the 7 x 7 map is its question 3 answered: "a data change in the plan"). No Game, no file locals: cell.lua asks `transit_cell_info` for the cells,
-- shell / transit_region draw them, the game builds the cars from `transit_lines`.
--
--      c0   c1   c2   c3   c4   c5   c6
--  r0  c    -    T    H    T    -    c       RED    = the ring (closed track along the 24 border cells), one car, stops at the four hubs (25 s); T = a ring tunnel with the stair up to Blue / Violet
--  r1  |    s    B    d    B    d    |       YELLOW = row 2, ORANGE = row 3, GREEN = row 4: open tracks at level 0 (Y stations at both ends, X halls where they cross the vertical lines)
--  r2  |    Y    X    m    X    Y    |       BLUE = column 2, VIOLET = column 4: open tracks at level 1 (+8 m), B stations at both ends; X is a two-storey hall (m: a tunnel with a door to a den)
--  r3  H    Y    X    X    X    Y    H       the centre X (3,3) is THE ABYSS (Orange stops there, the pit is in its deck); hubs are the safe rooms; the arrival is HUB SOUTH
--  r4  |    Y    X    m    X    Y    |       dens (d) at (3,1) (5,1) (1,5) (3,5); the stairwells (stairs_free) are the cells (1,1) and (5,5)
--  r5  |    d    B    d    B    s    |
--  r6  c    -    T    H    T    -    c
-- Coordinates: metres in the floor's local frame (a cell is 32 m: floor x = ci * 32 + cell x); a level is 8 m (level 1 = Blue, Violet); the deck of every car is the first air voxel above the floor of its level.

function transit_spec()
    if transit_spec_memo then return transit_spec_memo end
    transit_spec_memo = {
        "c-THT-c",
        "|sBdBd|",
        "|YXmXY|",
        "HYXXXYH",
        "|YXmXY|",
        "|dBdBs|",
        "c-THT-c",
    }
    return transit_spec_memo
end

-- the constants (a function: the hook sees functions only): the size of the floor, the height of the Blue level above the floor, the car
function transit_const()
    if transit_const_memo then return transit_const_memo end
    transit_const_memo = { W = 7, H = 7, level_m = 8, car = { len = 14, width = 3.6, thickness = 0.25, speed = 5, accel = 1.5 } }
    return transit_const_memo
end

-- the letter of a cell
function transit_code(ci, cj)
    local row = transit_spec()[cj + 1]
    return row and row:sub(ci + 1, ci + 1) or nil
end

-- the width of the door halls by kind (the Blue cars turn round at their ends: their doorways to X are 12 m)
function transit_hall_widths() return { tunnel = 8, wide = 12, concourse = 6, service = 6, stair = 6 } end

-- the doors of a cell: side -> { kind, pos } (pos = the coordinate along the wall: z for E / W, x for N / S, cell metres)
-- hub / station halls run along x (N, S hubs, Y stations) or along z (W, E hubs, B stations); the ring tunnels, the track tunnels and the corners follow the line.
function transit_open(ci, cj)
    local c = transit_code(ci, cj)
    local o = {}
    local W, H = transit_const().W, transit_const().H
    local function put(side, kind, pos) o[side] = { kind, pos } end
    if c == "c" then
        -- the ring: the corner cell joins its two ring neighbours
        if ci == 0 then put("E", "tunnel", 16) else put("W", "tunnel", 16) end
        if cj == 0 then put("S", "tunnel", 16) else put("N", "tunnel", 16) end
    elseif c == "-" or c == "T" or c == "m" then
        put("E", "tunnel", 16); put("W", "tunnel", 16)
        if c == "T" then put(cj == 0 and "S" or "N", "stair", 16)            -- the stair up to the Blue / Violet station beside the ring
        elseif c == "m" then put(cj == 2 and "N" or "S", "service", 16) end   -- the door to the den
    elseif c == "|" then put("N", "tunnel", 16); put("S", "tunnel", 16)
    elseif c == "H" then
        if cj == 0 or cj == H - 1 then                   -- N, S hubs: along x
            put("E", "tunnel", 16); put("W", "tunnel", 16)
        else                                             -- W, E hubs: along z
            put("N", "tunnel", 16); put("S", "tunnel", 16)
            put(ci == 0 and "E" or "W", "concourse", 9)     -- the concourse to the Y station beside it (z = 9: the north platform)
        end
    elseif c == "Y" then                                 -- the ends of Yellow, Orange, Green: along x
        if ci == 1 then
            if cj == 3 then put("W", "concourse", 9) end
            put("E", "tunnel", 16)
        else
            if cj == 3 then put("E", "concourse", 9) end
            put("W", "tunnel", 16)
        end
        put("N", "service", 16); put("S", "service", 16)
    elseif c == "B" then                                 -- the ends of Blue (column 2) and Violet (column 4): along z, level 1
        if cj == 1 then put("N", "stair", 16); put("S", "wide", 16) else put("S", "stair", 16); put("N", "wide", 16) end
    elseif c == "X" then
        put("E", "tunnel", 16); put("W", "tunnel", 16)
        if ci == 2 or ci == 4 then put("N", "wide", 16); put("S", "wide", 16) end
    elseif c == "d" or c == "s" then                     -- dens and stairs: one door toward the neighbour on the inner side
        put(cj == 1 and "S" or "N", "service", 16)
    end
    return o
end

-- the cell as the plan wants it: { ci, cj, role, theme, room = { x, z, w, d, h, y (the floor level in metres) }, open = { side = kind }, door = { side = pos }, deg, line, level, axis }
function transit_cell_info(ci, cj)
    local c = transit_code(ci, cj)
    if not c then return nil end
    local W = transit_const().W
    local o = transit_open(ci, cj)
    local info = { ci = ci, cj = cj, code = c, open = {}, door = {}, deg = 0, level = 0 }
    for side, kd in pairs(o) do info.open[side] = kd[1]; info.door[side] = kd[2]; info.deg = info.deg + 1 end
    local ax = "x"
    if c == "|" or c == "B" or ((c == "H") and (ci == 0 or ci == W - 1)) then ax = "z" end
    info.axis = ax
    if c == "c" then info.role, info.theme, info.room = "connector", "corner", { x = 2, z = 2, w = 28, d = 28, h = 8, y = 0 }
    elseif c == "-" or c == "|" or c == "T" or c == "m" then
        info.role, info.theme = "connector", "tunnel"
        info.room = (ax == "x") and { x = 0, z = 12, w = 32, d = 8, h = 6, y = 0 } or { x = 12, z = 0, w = 8, d = 32, h = 6, y = 0 }
    elseif c == "H" then
        info.role, info.theme = (ci == W // 2 and cj == transit_const().H - 1) and "arrival" or "safe", "hub"
        info.room = (ax == "x") and { x = 0, z = 6, w = 32, d = 20, h = 7, y = 0 } or { x = 6, z = 0, w = 20, d = 32, h = 7, y = 0 }
        info.line = "red"
    elseif c == "Y" then
        info.role, info.theme, info.room = "connector", "station", { x = 0, z = 6, w = 32, d = 20, h = 7, y = 0 }
        info.line = ({ [2] = "yellow", [3] = "orange", [4] = "green" })[cj]
    elseif c == "B" then
        info.role, info.theme, info.room, info.level = "connector", "station", { x = 6, z = 0, w = 20, d = 32, h = 7, y = transit_const().level_m }, 1
        info.line = (ci == 2) and "blue" or "violet"
    elseif c == "X" then
        info.role, info.theme, info.room, info.line = "connector", "station", { x = 4, z = 4, w = 24, d = 24, h = 14, y = 0 }, "cross"
        info.abyss = (ci == W // 2 and cj == transit_const().H // 2)
    elseif c == "d" then info.role, info.theme, info.room = "room", "den", { x = 6, z = 6, w = 20, d = 20, h = 7, y = 0 }
    elseif c == "s" then info.role, info.theme, info.room = "stairs", "stairs_free", { x = 9, z = 9, w = 14, d = 14, h = 6, y = 0 } end
    return info
end

-- ---------------------------------------------------------------------------------------------- the lines
-- the tracks of the three cars: waypoints { x, z } in floor metres, the level, the stops { waypoint, seconds }. Red is a closed loop that starts at HUB S (waypoint 1, its stop is waited out first), it goes
-- west, north, east, south; the corners are arcs of radius 12 m in 12 steps of 7.5 degrees laid so that they start and end on the centre lines of the cells.
function transit_lines()
    if transit_lines_memo then return transit_lines_memo end
    local C = transit_const()
    local WM, HM = C.W * 32, C.H * 32                    -- the floor in metres
    local red, stops = {}, {}
    local function pt(x, z) red[#red + 1] = { x, z } end
    local function arc(cx, cz, a0, a1)               -- degrees, points from a0 to a1 (both included)
        local n = 12
        for k = 0, n do local a = (a0 + (a1 - a0) * k / n) * math.pi / 180; pt(cx + 12 * math.cos(a), cz + 12 * math.sin(a)) end
    end
    local function stop() stops[#stops + 1] = { #red, 25 } end
    pt(WM / 2, HM - 16); stop()                         -- HUB S
    arc(28, HM - 28, 90, 180)                           -- the SW corner: from (28, HM - 16) to (16, HM - 28)
    pt(16, HM / 2); stop()                              -- HUB W
    arc(28, 28, 180, 270)                               -- the NW corner: from (16, 28) to (28, 16)
    pt(WM / 2, 16); stop()                              -- HUB N
    arc(WM - 28, 28, 270, 360)                          -- the NE corner: from (WM - 28, 16) to (WM - 16, 28)
    pt(WM - 16, HM / 2); stop()                         -- HUB E
    arc(WM - 28, HM - 28, 0, 90)                        -- the SE corner: from (WM - 16, HM - 28) to (WM - 28, HM - 16)
    local sp = C.car.speed
    local function open_line(name, level, pts)
        local st = {}
        for i = 1, #pts do st[i] = { i, 20 } end
        return { name = name, closed = false, level = level, points = pts, stops = st, speed = sp }
    end
    -- rows 2 / 3 / 4 at level 0 (the Y stations at columns 1 and 5, the X halls at columns 2 and 4, Orange also the Abyss at column 3), columns 2 / 4 at level 1 (the B stations at rows 1 and 5 stop 9 m from the cell border)
    transit_lines_memo = {
        { name = "red", closed = true, level = 0, points = red, stops = stops, speed = sp },
        open_line("yellow", 0, { { 48, 80 }, { 80, 80 }, { 144, 80 }, { 176, 80 } }),
        open_line("orange", 0, { { 48, 112 }, { 80, 112 }, { 112, 112 }, { 144, 112 }, { 176, 112 } }),
        open_line("green", 0, { { 48, 144 }, { 80, 144 }, { 144, 144 }, { 176, 144 } }),
        open_line("blue", 1, { { 80, 55 }, { 80, 80 }, { 80, 112 }, { 80, 144 }, { 80, 169 } }),
        open_line("violet", 1, { { 144, 55 }, { 144, 80 }, { 144, 112 }, { 144, 144 }, { 144, 169 } }),
    }
    return transit_lines_memo
end

-- is the point (x, z) of floor metres (at level 0 or 1) in air of the plan: a room of its cell, or a door hall between two rooms (the width of the door kind)
function transit_carved(x, z, level)
    local ci, cj = math.floor(x / 32), math.floor(z / 32)
    if x < 0 or z < 0 or ci > transit_const().W - 1 or cj > transit_const().H - 1 then return false end
    transit_carved_memo = transit_carved_memo or {}                 -- (the cells are constants: this table is the sweep's own, never handed out)
    local key = ci * 16 + cj
    local info = transit_carved_memo[key]
    if info == nil then info = transit_cell_info(ci, cj) or false; transit_carved_memo[key] = info end
    if not info then return false end
    local lx, lz = x - ci * 32, z - cj * 32
    local r = info.room
    local function level_ok(i) return i.level == level or i.code == "X" end
    if level_ok(info) and lx >= r.x and lx <= r.x + r.w and lz >= r.z and lz <= r.z + r.d then return true end
    -- the halls from the room to the cell border (half of the width of the kind each side of the door)
    local HW = transit_hall_widths()
    if level_ok(info) then
        for side, kind in pairs(info.open) do
            local c, hw = info.door[side], HW[kind] or 6
            if side == "E" and lx >= r.x + r.w and math.abs(lz - c) <= hw / 2 then return true end
            if side == "W" and lx <= r.x and math.abs(lz - c) <= hw / 2 then return true end
            if side == "S" and lz >= r.z + r.d and math.abs(lx - c) <= hw / 2 then return true end
            if side == "N" and lz <= r.z and math.abs(lx - c) <= hw / 2 then return true end
        end
    end
    return false
end

-- the sweep of a car along its line, the way the engine moves it: it starts from rest (stops are eased: accel 1.5 m/s2 up to the speed), and its yaw turns toward the heading of the segment it is
-- on at up to 1 rad/s (yaw += clamp(heading - yaw, -1/60, 1/60) a tick, about the middle of its deck), so at the end of an open track it turns round while it pulls away: the four corners of its
-- footprint must be in carved air at every tick. Returns a list of problems.
function transit_sweep(line)
    local bad = {}
    local pts = {}
    for i, p in ipairs(line.points) do pts[i] = p end
    if line.closed then pts[#pts + 1] = line.points[1] end
    local car = transit_const().car
    local half_l, half_w = car.len / 2, car.width / 2
    local function wrap(a) while a > math.pi do a = a - 2 * math.pi end while a < -math.pi do a = a + 2 * math.pi end return a end
    local yaw
    local function lap(forward)
        local n = #pts
        local P = {}
        for i = 1, n do P[i] = forward and pts[i] or pts[n - i + 1] end
        local segs, total = {}, 0
        for i = 1, n - 1 do
            local dx, dz = P[i + 1][1] - P[i][1], P[i + 1][2] - P[i][2]
            local len = math.sqrt(dx * dx + dz * dz)
            segs[i] = { s0 = total, len = len, dx = dx / len, dz = dz / len, head = math.atan(dx, dz) }
            total = total + len
        end
        if not yaw then yaw = segs[1].head end
        local s, v, seg = 0, 0, 1
        while s < total do
            v = math.min(car.speed, v + car.accel / 60)
            -- the stops: slow down to stand on the end of the lap (v^2 / 2a before it)
            local brake = v * v / (2 * car.accel)
            if total - s <= brake then v = math.max(0.3, math.sqrt(2 * car.accel * math.max(0, total - s))) end
            s = s + v / 60
            while seg < #segs and s > segs[seg].s0 + segs[seg].len do seg = seg + 1 end
            local g = segs[seg]
            local t = math.min(s, total) - g.s0
            local cx, cz = P[seg][1] + g.dx * t, P[seg][2] + g.dz * t
            yaw = yaw + math.max(-1 / 60, math.min(1 / 60, wrap(g.head - yaw)))
            local sy, cy = math.sin(yaw), math.cos(yaw)
            for _, c in ipairs({ { -half_w, -half_l }, { half_w, -half_l }, { half_w, half_l }, { -half_w, half_l } }) do
                local px, pz = cx + c[1] * cy + c[2] * sy, cz - c[1] * sy + c[2] * cy
                if not transit_carved(px, pz, line.level) then
                    bad[#bad + 1] = string.format("%s: the car's corner at (%.1f, %.1f) is in rock (the deck at (%.1f, %.1f), yaw %.0f deg)", line.name, px, pz, cx, cz, math.deg(yaw))
                    return
                end
            end
        end
    end
    lap(true)
    if #bad == 0 and not line.closed then lap(false) end
    return bad
end

-- the fixtures of a hub (the safe station): the crystal that saves and the vending machine stand against the wall of the north (axis x) or west (axis z) platform; the place to wake up is on the
-- platform too. Positions in cell metres. Also the text of the sign of every station.
function transit_hub_fixtures(info)
    if info.axis == "x" then return { vend = { x = 9, z = 6.45 }, crystal = { x = 23, z = 7.2 }, wake = { x = 12, z = 10.5 }, face = "+z" } end
    return { vend = { x = 6.45, z = 24 }, crystal = { x = 7.2, z = 8 }, wake = { x = 10.5, z = 12 }, face = "+x" }
end

function transit_station_text(info)
    local c = info.code
    local C = transit_const()
    local function up(n) return n:upper() end
    if c == "H" then return "HUB " .. (info.cj == 0 and "NORTH" or (info.cj == C.H - 1 and "SOUTH" or (info.ci == 0 and "WEST" or "EAST"))) end
    if c == "Y" then return up(info.line) .. ((info.ci == 1) and " WEST" or " EAST") end
    if c == "B" then return up(info.line) .. ((info.cj == 1) and " NORTH" or " SOUTH") end
    if c == "X" then
        if info.abyss then return "THE ABYSS" end
        return up(info.ci == 2 and "blue" or "violet") .. "-" .. up(({ [2] = "yellow", [3] = "orange", [4] = "green" })[info.cj])
    end
    return nil
end

-- where the player wakes up in a cell (cell metres): the platform of a hub, the ledge beside the track of a tunnel, the middle elsewhere
function transit_checkpoint(info)
    if info.code == "H" or info.code == "Y" then
        local f = transit_hub_fixtures(info)
        return f.wake.x, f.wake.z
    end
    if info.code == "-" or info.code == "T" or info.code == "m" then return 16, 13 end
    if info.code == "|" then return 13, 16 end
    return nil
end

-- the layout grammar's view of a cell of the Iron Tangle (hubs, Yellow stations, dens): the room with the bed of the track and the hub's fixtures reserved; shared by the hook and the game
function transit_layout(info, mk)
    local theme = ({ H = "hub", Y = "station", d = "den" })[info.code]
    if not theme then return nil end
    local room = info.room
    local doors = {}
    for _, d in ipairs({ "E", "S", "W", "N" }) do if info.open[d] then doors[#doors + 1] = { side = d, pos = info.door[d] } end end
    local reserve = {}
    if info.code ~= "d" then
        if info.axis == "x" then reserve[#reserve + 1] = { room.x, 16 - 2.6, room.x + room.w, 16 + 2.6 } else reserve[#reserve + 1] = { 16 - 2.6, room.z, 16 + 2.6, room.z + room.d } end
    end
    if info.code == "H" then
        local f = transit_hub_fixtures(info)
        reserve[#reserve + 1] = { f.vend.x - 1.5, f.vend.z - 0.3, f.vend.x + 1.5, f.vend.z + 2.0 }
        reserve[#reserve + 1] = { f.crystal.x - 1.4, f.crystal.z - 0.6, f.crystal.x + 1.4, f.crystal.z + 1.6 }
        if info.axis == "z" then
            reserve[#reserve] = { f.crystal.x - 0.6, f.crystal.z - 1.4, f.crystal.x + 1.6, f.crystal.z + 1.4 }
            reserve[#reserve - 1] = { f.vend.x - 0.3, f.vend.z - 1.5, f.vend.x + 2.0, f.vend.z + 1.5 }
        end
    end
    return deco_layout(theme, room, doors, mk, 4, { reserve = reserve, door_half = 3.0, door_depth = 3.5 })
end

-- where a car stops in a cell (cell metres) and the places of the crowd that waits for it: two on each platform, 3 m either side of the middle of the car
function transit_crowd_spots(info)
    local sx, sz = 16, 16
    if info.code == "B" then sz = (info.cj == 1) and 23 or 9 end
    local out = {}
    if info.axis == "x" then
        for _, dz in ipairs({ -5, 5 }) do for _, dx in ipairs({ -0.9, 0.9 }) do out[#out + 1] = { x = sx + dx, z = sz + dz, kind = "idle" } end end      -- (the car's boarding gaps are 2.5 m wide in its middle: the crowd stands in front of them)
    else
        for _, dx in ipairs({ -5, 5 }) do for _, dz in ipairs({ -0.9, 0.9 }) do out[#out + 1] = { x = sx + dx, z = sz + dz, kind = "idle" } end end
    end
    return out
end

-- is the point (x, z) of floor metres within the bed of a track (2.1 m of the polyline of a line of this level)
function transit_on_bed(x, z, level)
    for _, line in ipairs(transit_lines()) do
        if line.level == level then
            local pts, n = line.points, #line.points
            local last = line.closed and n or n - 1
            for i = 1, last do
                local a, b = pts[i], pts[i % n + 1]
                local dx, dz = b[1] - a[1], b[2] - a[2]
                local len2 = dx * dx + dz * dz
                local t = (len2 > 0) and math.max(0, math.min(1, ((x - a[1]) * dx + (z - a[2]) * dz) / len2)) or 0
                local qx, qz = a[1] + dx * t - x, a[2] + dz * t - z
                if qx * qx + qz * qz < 2.1 * 2.1 then return true end
            end
        end
    end
    return false
end
