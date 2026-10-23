-- gen/validate: can a contestant WALK through the floor that was built? A flood fill over the voxels (0.5 m cells: a surface within 0.6 m of its neighbour, 1.7 m of headroom) from the arrival
-- room. Reports the rooms, crates and enemies that cannot be reached (the exit counts as reachable only with the gate open). Used by tools/gen_validate.py and in debug runs.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local V = {}
G.gen.validate = V
local floor, abs = math.floor, math.abs

local CELL = 0.5
local function key(i, j) return i * 4096 + j end

function V.start(p)
    local st = { p = p, seen = {}, h = {}, queue = {}, qi = 1, memo = {}, done = false, cells = 0 }
    V.st = st
    local r = p.rooms[p.start]
    -- a walkable cell near the middle of the arrival room
    for d = 0, 12 do
        local i, j = floor((r.x + 7.5 + d * 0.25) / CELL), floor((r.z + 9.5) / CELL)
        local ok, h = V.walkable(st, i, j)
        if ok then st.seen[key(i, j)] = true; st.h[key(i, j)] = h; st.queue[1] = { i, j }; break end
    end
    if #st.queue == 0 then st.done = true; st.error = "no walkable cell in the arrival room" end
    return st
end

function V.walkable(st, i, j)
    local k = key(i, j)
    local m = st.memo[k]
    if m ~= nil then return m[1], m[2] end
    local x, z = (i + 0.5) * CELL, (j + 0.5) * CELL
    local vx, vz = G.wx(x), G.wz(z)
    local top = world.top(vx, vz, G.OY + 16 * 2.0, true)
    local ok, h = false, 0
    if top and top > 0 then
        h = (top + 1 - G.OY) / 16
        if h > -0.9 and h < 1.4 then
            ok = not world.blocks(vx, top + 1 + 8, vz) and not world.blocks(vx, top + 1 + 24, vz)
        end
    end
    st.memo[k] = { ok, h }
    return ok, h
end

-- processes up to n cells of the queue; true when the flood is finished
function V.step(n)
    local st = V.st
    if st.done then return true end
    local count = 0
    while st.qi <= #st.queue and count < n do
        local c = st.queue[st.qi]; st.qi = st.qi + 1; count = count + 1
        local ch = st.h[key(c[1], c[2])]
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local ni, nj = c[1] + d[1], c[2] + d[2]
            local k = key(ni, nj)
            if not st.seen[k] then
                local ok, h = V.walkable(st, ni, nj)
                if ok and abs(h - ch) <= 0.6 then st.seen[k] = true; st.h[k] = h; st.queue[#st.queue + 1] = { ni, nj }; st.cells = st.cells + 1 end
            end
        end
    end
    if st.qi > #st.queue then st.done = true end
    return st.done
end

function V.reached(x, z)
    local st = V.st
    local i, j = floor(x / CELL), floor(z / CELL)
    for di = -1, 1 do for dj = -1, 1 do if st.seen[key(i + di, j + dj)] then return true end end end
    return false
end

-- the report: lines of text
function V.report()
    local st = V.st
    local p = st.p
    local out = {}
    for _, id in ipairs(p.order) do
        local r = p.rooms[id]
        local n, tot = 0, 0
        for x = r.x + 1, r.x + r.w - 1, 2 do for z = r.z + 1, r.z + r.d - 1, 2 do tot = tot + 1; if V.reached(x, z) then n = n + 1 end end end
        if n == 0 then out[#out + 1] = string.format("ROOM %s (%s %s) is NOT reachable", id, r.role, r.theme)
        elseif n / tot < 0.25 and r.theme ~= "furnace" and r.theme ~= "flooded" then out[#out + 1] = string.format("room %s (%s) only %d%% reachable", id, r.theme, floor(100 * n / tot)) end
    end
    for id, c in pairs(G.traps.crates) do
        if not V.reached(c.cx, c.cz + 0.9) and not V.reached(c.cx, c.cz - 0.9) and not V.reached(c.cx + 0.9, c.cz) and not V.reached(c.cx - 0.9, c.cz) then out[#out + 1] = "crate " .. id .. " is NOT reachable" end
    end
    local bad = 0
    for rid, list in pairs(G.world.populate_list) do
        for _, e in ipairs(list) do if not V.reached(e[2], e[3]) then bad = bad + 1; out[#out + 1] = string.format("enemy %s at %.1f, %.1f in %s is not on walkable ground", e[1], e[2], e[3], rid) end end
    end
    out[#out + 1] = string.format("walkable cells %d", st.cells)
    return out
end
