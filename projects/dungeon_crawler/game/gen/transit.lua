-- gen/transit: the Iron Tangle (floor 4), pure global functions (hook_globals): the plan of a transit floor (5 x 5 cells, three lines, 11 stations), the tracks of its trains and the sweep check.
-- Design: ~/share/floor4-design.md (reviewed). No Game, no file locals: cell.lua asks `transit_cell` for the cells, shell / transit_region draw them, the game builds the trains from `transit_lines`.
--
--     c0        c1        c2        c3        c4
--  r0 corner    tunnel    HUB N     tunnel    corner       RED   = the ring (closed track along the 16 border cells), one car, stops at the four hubs (25 s)
--  r1 tunnel    den       B1 (+8 m) stairs    tunnel       YELLOW= row 2, Y1 - X - Y3 (open track, to and fro, level 0)
--  r2 HUB W     Y1        X         Y3        HUB E        BLUE  = column 2, B1 - X - B3 (open track, to and fro, 8 m ABOVE yellow along its whole length, X is a two-storey hall)
--  r3 tunnel    stairs    B3 (+8 m) den       tunnel       hubs are the safe rooms (platform, crystal, shop); the arrival is HUB S; the stairwells (stairs_free) are the cells (3,1) and (1,3)
--  r4 corner    tunnel    HUB S     tunnel    corner
-- Coordinates: metres in the floor's local frame (a cell is 32 m: floor x = ci * 32 + cell x); a level is 8 m (level 1 = Blue); the deck of every car is the first air voxel above the floor of its level.

function transit_spec()
    if transit_spec_memo then return transit_spec_memo end
    transit_spec_memo = {
        "c-H-c",
        "|dBs|",
        "HYXYH",
        "|sBd|",
        "c-H-c",
    }
    return transit_spec_memo
end

-- the constants (a function: the hook sees functions only): the size of the floor, the height of the Blue level above the floor, the car
function transit_const()
    if transit_const_memo then return transit_const_memo end
    transit_const_memo = { W = 5, H = 5, level_m = 8, car = { len = 14, width = 3.6, thickness = 0.25, speed = 5, accel = 1.5 } }
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
    local function put(side, kind, pos) o[side] = { kind, pos } end
    if c == "c" then
        -- the ring: the corner cell joins its two ring neighbours
        if ci == 0 then put("E", "tunnel", 16) else put("W", "tunnel", 16) end
        if cj == 0 then put("S", "tunnel", 16) else put("N", "tunnel", 16) end
    elseif c == "-" then put("E", "tunnel", 16); put("W", "tunnel", 16)
    elseif c == "|" then put("N", "tunnel", 16); put("S", "tunnel", 16)
    elseif c == "H" then
        if cj == 0 or cj == 4 then                       -- N, S hubs: along x
            put("E", "tunnel", 16); put("W", "tunnel", 16)
            put(cj == 0 and "S" or "N", "stair", 16)        -- the stair up to B1 / B3
        else                                             -- W, E hubs: along z
            put("N", "tunnel", 16); put("S", "tunnel", 16)
            put(ci == 0 and "E" or "W", "concourse", 9)     -- the concourse to Y1 / Y3 (z = 9: the north platform)
        end
    elseif c == "Y" then                                 -- Y1 (1,2), Y3 (3,2): along x
        if ci == 1 then put("W", "concourse", 9); put("E", "tunnel", 16) else put("E", "concourse", 9); put("W", "tunnel", 16) end
        put("N", "service", 16); put("S", "service", 16)
    elseif c == "B" then                                 -- B1 (2,1), B3 (2,3): along z, level 1
        if cj == 1 then put("N", "stair", 16); put("S", "wide", 16) else put("S", "stair", 16); put("N", "wide", 16) end
    elseif c == "X" then put("E", "tunnel", 16); put("W", "tunnel", 16); put("N", "wide", 16); put("S", "wide", 16)
    elseif c == "d" or c == "s" then                     -- dens (1,1) (3,3) and stairs (3,1) (1,3): one door toward the Yellow station beside them
        if cj == 1 then put("S", "service", 16) else put("N", "service", 16) end
    end
    return o
end

-- the cell as the plan wants it: { ci, cj, role, theme, room = { x, z, w, d, h, y (the floor level in metres) }, open = { side = kind }, door = { side = pos }, deg, line, level, axis }
function transit_cell_info(ci, cj)
    local c = transit_code(ci, cj)
    if not c then return nil end
    local o = transit_open(ci, cj)
    local info = { ci = ci, cj = cj, code = c, open = {}, door = {}, deg = 0, level = 0 }
    for side, kd in pairs(o) do info.open[side] = kd[1]; info.door[side] = kd[2]; info.deg = info.deg + 1 end
    local ax = "x"
    if c == "|" or c == "B" or ((c == "H") and (cj == 2)) then ax = "z" end
    info.axis = ax
    if c == "c" then info.role, info.theme, info.room = "connector", "corner", { x = 2, z = 2, w = 28, d = 28, h = 8, y = 0 }
    elseif c == "-" or c == "|" then
        info.role, info.theme = "connector", "tunnel"
        info.room = (ax == "x") and { x = 0, z = 12, w = 32, d = 8, h = 6, y = 0 } or { x = 12, z = 0, w = 8, d = 32, h = 6, y = 0 }
    elseif c == "H" then
        info.role, info.theme = (ci == 2 and cj == 4) and "arrival" or "safe", "hub"
        info.room = (ax == "x") and { x = 0, z = 6, w = 32, d = 20, h = 7, y = 0 } or { x = 6, z = 0, w = 20, d = 32, h = 7, y = 0 }
        info.line = "red"
    elseif c == "Y" then info.role, info.theme, info.room, info.line = "connector", "station", { x = 0, z = 6, w = 32, d = 20, h = 7, y = 0 }, "yellow"
    elseif c == "B" then
        info.role, info.theme, info.room, info.line, info.level = "connector", "station", { x = 6, z = 0, w = 20, d = 32, h = 7, y = transit_const().level_m }, "blue", 1
    elseif c == "X" then info.role, info.theme, info.room, info.line = "connector", "station", { x = 4, z = 4, w = 24, d = 24, h = 14, y = 0 }, "cross"
    elseif c == "d" then info.role, info.theme, info.room = "room", "den", { x = 6, z = 6, w = 20, d = 20, h = 7, y = 0 }
    elseif c == "s" then info.role, info.theme, info.room = "stairs", "stairs_free", { x = 9, z = 9, w = 14, d = 14, h = 6, y = 0 } end
    return info
end

-- ---------------------------------------------------------------------------------------------- the lines
-- the tracks of the three cars: waypoints { x, z } in floor metres, the level, the stops { waypoint, seconds }. Red is a closed loop that starts at HUB S (waypoint 1, its stop is waited out first), it goes
-- west, north, east, south; the corners are arcs of radius 12 m in 12 steps of 7.5 degrees laid so that they start and end on the centre lines of the cells.
function transit_lines()
    if transit_lines_memo then return transit_lines_memo end
    local red, stops = {}, {}
    local function pt(x, z) red[#red + 1] = { x, z } end
    local function arc(cx, cz, a0, a1)               -- degrees, points from a0 to a1 (both included)
        local n = 12
        for k = 0, n do local a = math.rad(a0 + (a1 - a0) * k / n); pt(cx + 12 * math.cos(a), cz + 12 * math.sin(a)) end
    end
    local function stop() stops[#stops + 1] = { #red, 25 } end
    pt(80, 144); stop()                                 -- HUB S
    arc(28, 132, 90, 180)                               -- the SW corner: from (28, 144) to (16, 132)
    pt(16, 80); stop()                                  -- HUB W
    arc(28, 28, 180, 270)                               -- the NW corner: from (16, 28) to (28, 16)
    pt(80, 16); stop()                                  -- HUB N
    arc(132, 28, 270, 360)                              -- the NE corner: from (132, 16) to (144, 28)
    pt(144, 80); stop()                                 -- HUB E
    arc(132, 132, 0, 90)                                -- the SE corner: from (144, 132) to (132, 144)
    transit_lines_memo = {
        { name = "red", closed = true, level = 0, points = red, stops = stops, speed = transit_const().car.speed },
        { name = "yellow", closed = false, level = 0, points = { { 48, 80 }, { 80, 80 }, { 112, 80 } }, stops = { { 1, 20 }, { 2, 20 }, { 3, 20 } }, speed = transit_const().car.speed },
        { name = "blue", closed = false, level = 1, points = { { 80, 55 }, { 80, 80 }, { 80, 105 } }, stops = { { 1, 20 }, { 2, 20 }, { 3, 20 } }, speed = transit_const().car.speed },
    }
    return transit_lines_memo
end

-- is the point (x, z) of floor metres (at level 0 or 1) in air of the plan: a room of its cell, or a door hall between two rooms (the width of the door kind)
function transit_carved(x, z, level)
    local ci, cj = math.floor(x / 32), math.floor(z / 32)
    if x < 0 or z < 0 or ci > transit_const().W - 1 or cj > transit_const().H - 1 then return false end
    local info = transit_cell_info(ci, cj)
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
