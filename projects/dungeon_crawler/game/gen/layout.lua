-- gen/layout: a floor's plan from a seed. A pure function (own LCG, no globals, nothing from the world): the same (seed, floor) is the same plan on every machine, in every replay.
--
-- The footprint is the old floor's: x 2..122, z 2..150 (metres, local frame). A grid of 3 x 4 cells (40 x 37 m); a connected random subset of the cells holds one room each, inset by at
-- least 5 m, so the gaps between neighbouring rooms are 10 m or more and a corridor in a gap never touches a third room. A random spanning tree joins the rooms (plus a loop or two);
-- the start is a cell of the top row, the exit is the farthest room of the tree and hangs behind its parent, the BOSS room.
-- Result: { seed, floor, rooms = { [id] = { id, cell = {i, j}, x, z, w, d, h, role, depth } }, order = { ids }, edges = { { a, b, segs = { {x0, z0, x1, z1} } } }, neighbors = { id = { ids } },
--           start = id, exit = id, boss = id, n = number of rooms }
-- A corridor segment is a rectangle in metres (x0, z0, x1, z1), 4 m wide, inside the gap between the two rooms and the walls of both; `doors` are the places where it meets a room.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local L = {}
G.gen.layout = L

L.COLS, L.ROWS = 3, 4
L.X0, L.Z0, L.CW, L.CD = 2, 2, 40, 37
L.MARGIN = 5
L.CORR_W = 4

local floor = math.floor

local function make_rng(seed, floor_n, attempt)
    local s = (seed * 2654435761 + floor_n * 40503 + attempt * 9973 + 12345) % 2147483648
    for _ = 1, 4 do s = (s * 1103515245 + 12345) % 2147483648 end
    local r = {}
    function r.next() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
    function r.int(a, b) return a + floor(r.next() * (b - a + 1)) end
    function r.pick(t) return t[r.int(1, #t)] end
    function r.shuffle(t) for i = #t, 2, -1 do local j = r.int(1, i); t[i], t[j] = t[j], t[i] end return t end
    return r
end
L.make_rng = make_rng

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }       -- (cell column, cell row)

local function cell_key(i, j) return i * 10 + j end

-- the plan of one attempt; nil when it does not meet the rules
local function attempt(seed, floor_n, att)
    local r = make_rng(seed, floor_n, att)
    local cols, rows = L.COLS, L.ROWS
    -- 1. which cells: a random connected set, growing from a cell of the top row
    local n_target = r.int(8, 10)
    local si = r.int(0, cols - 1)
    local occ, list = { [cell_key(si, 0)] = true }, { { si, 0 } }
    local guard = 0
    while #list < n_target and guard < 400 do
        guard = guard + 1
        local c = list[r.int(1, #list)]
        local d = DIRS[r.int(1, 4)]
        local ni, nj = c[1] + d[1], c[2] + d[2]
        if ni >= 0 and ni < cols and nj >= 0 and nj < rows and not occ[cell_key(ni, nj)] then
            occ[cell_key(ni, nj)] = true
            list[#list + 1] = { ni, nj }
        end
    end
    if #list < 7 then return nil end
    -- 2. a random spanning tree (randomised Prim) with the start as the root
    local idx = {}          -- cell key -> room index
    for k, c in ipairs(list) do idx[cell_key(c[1], c[2])] = k end
    local parent, depth, in_tree = {}, { [1] = 0 }, { [1] = true }
    local tree_edges, frontier = {}, {}
    local function add_frontier(a)
        for _, d in ipairs(DIRS) do
            local b = idx[cell_key(list[a][1] + d[1], list[a][2] + d[2])]
            if b and not in_tree[b] then frontier[#frontier + 1] = { a, b } end
        end
    end
    add_frontier(1)
    while #frontier > 0 do
        local k = r.int(1, #frontier)
        local e = frontier[k]; frontier[k] = frontier[#frontier]; frontier[#frontier] = nil
        if not in_tree[e[2]] then
            in_tree[e[2]] = true
            parent[e[2]] = e[1]; depth[e[2]] = depth[e[1]] + 1
            tree_edges[#tree_edges + 1] = e
            add_frontier(e[2])
        end
    end
    -- 3. the exit: the deepest room (a leaf); its parent is the boss room
    local exit_i, best = nil, -1
    for k = 2, #list do
        if depth[k] > best or (depth[k] == best and r.next() < 0.5) then exit_i, best = k, depth[k] end
    end
    if best < 4 then return nil end                      -- too short a way: the boss would be the third room
    local boss_i = parent[exit_i]
    -- 4. a loop or two (never at the exit; never at the start room's only way out)
    local edges = {}
    for _, e in ipairs(tree_edges) do edges[#edges + 1] = { e[1], e[2] } end
    local has = {}
    for _, e in ipairs(edges) do has[e[1] * 100 + e[2]] = true; has[e[2] * 100 + e[1]] = true end
    local extra, tries = r.int(1, 2), 0
    while extra > 0 and tries < 30 do
        tries = tries + 1
        local a = r.int(1, #list)
        local d = DIRS[r.int(1, 4)]
        local b = idx[cell_key(list[a][1] + d[1], list[a][2] + d[2])]
        if b and a ~= exit_i and b ~= exit_i and not has[a * 100 + b] then
            edges[#edges + 1] = { a, b }; has[a * 100 + b] = true; has[b * 100 + a] = true; extra = extra - 1
        end
    end
    -- 5. the rooms
    local rooms, order = {}, {}
    local ids = {}
    for k, c in ipairs(list) do
        local id = "f" .. floor_n .. "r" .. k
        ids[k] = id
        local role = (k == 1) and "start" or (k == exit_i and "exit" or (k == boss_i and "boss" or "room"))
        local w, d, h
        if role == "start" or role == "exit" then w, d, h = 16, 16, 6
        elseif role == "boss" then w, d, h = 30, 26, 12
        else w = 14 + 2 * r.int(0, 8); d = 14 + 2 * r.int(0, 6); h = r.pick({ 6, 7, 8, 9 }) end
        local cx0 = L.X0 + c[1] * L.CW
        local cz0 = L.Z0 + c[2] * L.CD
        local ox = L.MARGIN + 2 * r.int(0, floor((L.CW - 2 * L.MARGIN - w) / 2))
        local oz = L.MARGIN + 2 * r.int(0, floor((L.CD - 2 * L.MARGIN - d) / 2))
        rooms[id] = { id = id, cell = { c[1], c[2] }, x = cx0 + ox, z = cz0 + oz, w = w, d = d, h = h, role = role, depth = depth[k], index = k }
        order[#order + 1] = id
    end
    -- 6. the corridors
    local cw = L.CORR_W
    local out_edges = {}
    for _, e in ipairs(edges) do
        local A, B = rooms[ids[e[1]]], rooms[ids[e[2]]]
        local segs, doors = {}, {}
        local horizontal = (A.cell[2] == B.cell[2])
        if horizontal then
            if A.cell[1] > B.cell[1] then A, B = B, A end            -- A is west of B
            local lo = math.max(A.z, B.z) + cw / 2 + 1
            local hi = math.min(A.z + A.d, B.z + B.d) - cw / 2 - 1
            local ax1, bx0 = A.x + A.w, B.x
            if hi - lo >= 0 then
                local z = lo + 2 * floor(r.next() * ((hi - lo) / 2 + 1)); if z > hi then z = hi end
                segs[1] = { ax1, z - cw / 2, bx0, z + cw / 2 }
                doors[1] = { room = A.id, side = "E", z = z }; doors[2] = { room = B.id, side = "W", z = z }
            else
                local za, zb = A.z + floor(A.d / 2), B.z + floor(B.d / 2)
                local xm = floor((ax1 + bx0) / 4) * 2
                segs[1] = { ax1, za - cw / 2, xm + cw / 2, za + cw / 2 }
                segs[2] = { xm - cw / 2, math.min(za, zb) - cw / 2, xm + cw / 2, math.max(za, zb) + cw / 2 }
                segs[3] = { xm - cw / 2, zb - cw / 2, bx0, zb + cw / 2 }
                doors[1] = { room = A.id, side = "E", z = za }; doors[2] = { room = B.id, side = "W", z = zb }
            end
        else
            if A.cell[2] > B.cell[2] then A, B = B, A end            -- A is north (small z) of B
            local lo = math.max(A.x, B.x) + cw / 2 + 1
            local hi = math.min(A.x + A.w, B.x + B.w) - cw / 2 - 1
            local az1, bz0 = A.z + A.d, B.z
            if hi - lo >= 0 then
                local x = lo + 2 * floor(r.next() * ((hi - lo) / 2 + 1)); if x > hi then x = hi end
                segs[1] = { x - cw / 2, az1, x + cw / 2, bz0 }
                doors[1] = { room = A.id, side = "S", x = x }; doors[2] = { room = B.id, side = "N", x = x }
            else
                local xa, xb = A.x + floor(A.w / 2), B.x + floor(B.w / 2)
                local zm = floor((az1 + bz0) / 4) * 2
                segs[1] = { xa - cw / 2, az1, xa + cw / 2, zm + cw / 2 }
                segs[2] = { math.min(xa, xb) - cw / 2, zm - cw / 2, math.max(xa, xb) + cw / 2, zm + cw / 2 }
                segs[3] = { xb - cw / 2, zm - cw / 2, xb + cw / 2, bz0 }
                doors[1] = { room = A.id, side = "S", x = xa }; doors[2] = { room = B.id, side = "N", x = xb }
            end
        end
        out_edges[#out_edges + 1] = { a = A.id, b = B.id, segs = segs, doors = doors }
    end
    local neighbors = {}
    for _, id in ipairs(order) do neighbors[id] = {} end
    for _, e in ipairs(out_edges) do
        neighbors[e.a][#neighbors[e.a] + 1] = e.b
        neighbors[e.b][#neighbors[e.b] + 1] = e.a
    end
    return { seed = seed, floor = floor_n, rooms = rooms, order = order, edges = out_edges, neighbors = neighbors, start = ids[1], exit = ids[exit_i], boss = ids[boss_i],
             n = #list, attempt = att }
end

function L.generate(seed, floor_n)
    for att = 0, 60 do
        local p = attempt(seed, floor_n, att)
        if p then return p end
    end
    error("gen.layout: no plan for seed " .. tostring(seed) .. " floor " .. tostring(floor_n))
end

-- the checks that must hold for every plan (used by the tests and, in debug, after every generation): returns a list of problems
function L.check(p)
    local bad = {}
    local ids = p.order
    local function overlap(a, b, pad)
        return a.x - pad < b.x + b.w and b.x - pad < a.x + a.w and a.z - pad < b.z + b.d and b.z - pad < a.z + a.d
    end
    for i = 1, #ids do
        local a = p.rooms[ids[i]]
        if a.x < L.X0 or a.z < L.Z0 or a.x + a.w > L.X0 + L.COLS * L.CW or a.z + a.d > L.Z0 + L.ROWS * L.CD then bad[#bad + 1] = a.id .. " outside the footprint" end
        for j = i + 1, #ids do
            local b = p.rooms[ids[j]]
            if overlap(a, b, 8) then bad[#bad + 1] = a.id .. " touches " .. b.id end
        end
    end
    -- every corridor segment stays out of every room except the two it joins
    for _, e in ipairs(p.edges) do
        for _, s in ipairs(e.segs) do
            for _, id in ipairs(ids) do
                local r = p.rooms[id]
                if id ~= e.a and id ~= e.b then
                    if s[1] < r.x + r.w + 1 and s[3] > r.x - 1 and s[2] < r.z + r.d + 1 and s[4] > r.z - 1 then bad[#bad + 1] = "corridor " .. e.a .. "-" .. e.b .. " enters " .. id end
                end
            end
        end
    end
    -- connected, and the exit's only neighbour is the boss
    local seen, q = { [p.start] = true }, { p.start }
    local qi = 1
    while qi <= #q do
        local c = q[qi]; qi = qi + 1
        for _, n in ipairs(p.neighbors[c]) do if not seen[n] then seen[n] = true; q[#q + 1] = n end end
    end
    if #q ~= p.n then bad[#bad + 1] = "not connected" end
    if #p.neighbors[p.exit] ~= 1 or p.neighbors[p.exit][1] ~= p.boss then bad[#bad + 1] = "the exit is not behind the boss" end
    return bad
end

-- a text picture: one character per 2 m (rooms by role: S start, X exit, B boss, digits for the rest; corridors #)
function L.ascii(p)
    local W, H = floor((L.COLS * L.CW + 4) / 2), floor((L.ROWS * L.CD + 4) / 2)
    local g = {}
    for z = 1, H do g[z] = {}; for x = 1, W do g[z][x] = " " end end
    local function box(x0, z0, x1, z1, ch)
        for z = floor(z0 / 2), floor((z1 - 1) / 2) do for x = floor(x0 / 2), floor((x1 - 1) / 2) do if g[z + 1] and g[z + 1][x + 1] then g[z + 1][x + 1] = ch end end end
    end
    for _, e in ipairs(p.edges) do for _, s in ipairs(e.segs) do box(s[1], s[2], s[3], s[4], "#") end end
    local n = 0
    for _, id in ipairs(p.order) do
        local r = p.rooms[id]
        n = n + 1
        local ch = r.role == "start" and "S" or (r.role == "exit" and "X" or (r.role == "boss" and "B" or tostring(n % 10)))
        box(r.x, r.z, r.x + r.w, r.z + r.d, ch)
    end
    local lines = {}
    for z = 1, H do lines[#lines + 1] = table.concat(g[z]) end
    return table.concat(lines, "\n")
end
