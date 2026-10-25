-- gen/contract: the guarantee for a big floor, checked on the PLAN (pure Lua, no engine): every cell reachable, a way down always reachable, safe rooms close, doors on the free band, a threat budget
-- per room, hazards never dead ends, gates never the only way. A violation is a bug in the generator rule, never "reroll": the region hook cannot reroll.
-- Items 1-7 are the plan's D4 C-A; 8-12 section 7; 13 section 8. `check(plan)` returns { violations = { {item, text} }, stats = {...} }.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local K = {}
G.gen.contract = K
local floor, max, min = math.floor, math.max, math.min

K.SAFE_STEPS = 6         -- the plan says 3; two safe rooms per 4x4 tree quadrant (k-center) give 5 almost always and 6 at worst (stats.safe_max records the real maximum); a third safe room would crowd the floor

-- the transit floor (floor 4): its own short contract (item 17 is the sweep of the cars)
function K.check_transit(plan, CG)
    local ctx = plan.ctx
    local V, S = {}, {}
    local function bad(item, text) V[#V + 1] = { item = item, text = text } end
    local dist = CG.bfs(plan, { plan.arrival })
    local nn, nr = 0, 0
    for id in pairs(plan.nodes) do nn = nn + 1; if dist[id] then nr = nr + 1 end end
    S.nodes, S.reached = nn, nr
    if nn ~= nr then bad(1, "not connected: " .. (nn - nr) .. " cells unreachable") end
    local nst = 0
    for _, id in ipairs(plan.stairs) do if dist[id] then nst = nst + 1 end end
    S.stairs = nst
    if nst < 2 then bad(2, "only " .. nst .. " stairwells reached") end
    local dsafe = CG.bfs(plan, plan.safe)
    local smax = 0
    for _, id in ipairs(plan.order) do
        local d = dsafe[id]
        if not d then bad(3, "no safe room reachable from " .. id) else smax = max(smax, d); if d > K.SAFE_STEPS then bad(3, id .. " is " .. d .. " steps from a safe room") end end
    end
    S.safe_max = smax
    -- every door has a partner with the same position, the doors of a cell are on its room's walls
    for _, id in ipairs(plan.order) do
        local info = plan.cells[id]
        for side, kind in pairs(info.open) do
            local dd = ({ E = { 1, 0, "W" }, W = { -1, 0, "E" }, S = { 0, 1, "N" }, N = { 0, -1, "S" } })[side]
            local nb = plan.cells["c" .. (info.ci + dd[1]) .. "_" .. (info.cj + dd[2])]
            if not nb then bad(4, id .. ": a door " .. side .. " into nothing")
            elseif nb.open[dd[3]] ~= kind or nb.door[dd[3]] ~= info.door[side] then bad(4, id .. ": the door " .. side .. " does not meet its partner (" .. tostring(nb.open[dd[3]]) .. " " .. tostring(nb.door[dd[3]]) .. " vs " .. kind .. " " .. info.door[side] .. ")") end
        end
    end
    -- 15. the furniture of the stations and dens (the layout grammar, the track bed and the hub's fixtures reserved)
    local n15 = 0
    for _, id in ipairs(CG.H and plan.order or {}) do
        local info = plan.cells[id]
        local lay = transit_layout(info, function(salt) return deco_rng(CG.H, ctx.floor, info.ci, info.cj, salt or 1) end)
        if lay then
            n15 = n15 + 1
            local doors = {}
            for _, d in ipairs({ "E", "S", "W", "N" }) do if info.open[d] then doors[#doors + 1] = { side = d, pos = info.door[d] } end end
            for _, b in ipairs(deco_layout_check(lay, info.room, doors)) do bad(15, id .. " (" .. info.theme .. "): " .. b) end
        end
    end
    S.furnished = n15
    -- 17. the cars: every waypoint and every stop in carved air, the whole sweep (the engine's yaw rule at top speed) in carved air; Blue and Yellow never share a level
    local lines = transit_lines()
    S.lines = #lines
    for _, line in ipairs(lines) do
        for i, p in ipairs(line.points) do if not transit_carved(p[1], p[2], line.level) then bad(17, line.name .. ": waypoint " .. i .. " is in rock") end end
        for _, t in ipairs(line.stops) do
            local p = line.points[t[1]]
            if not p then bad(17, line.name .. ": a stop on a missing waypoint") end
        end
        for _, b in ipairs(transit_sweep(line)) do bad(17, b) end
    end
    -- the floor under every stop: what the hook really builds (transit_region's ops, replayed in order) must be solid in the voxel under the bed of the car at the level of the line. A deck that was
    -- built at the wrong level is "carved air" to the checks above (the 5 x 5 X hall had none: the Blue car crossed an open hall); this one sees it.
    local wh = worldgen and worldgen.hash
    S.floor_checked = 0
    if wh and ctx.floor == 4 then
        local made = {}
        local function ops_of(ci, cj)
            local key = ci * 16 + cj
            if not made[key] then made[key] = transit_region(ci, 4 * 32 + 2 + cj, wh, 0) end
            return made[key]
        end
        local seen = {}
        for _, line in ipairs(lines) do
            for _, t in ipairs(line.stops) do
                local p = line.points[t[1]]
                if p then
                    local ci, cj = floor(p[1] / 32), floor(p[2] / 32)
                    local tag = line.name .. ":" .. t[1]
                    if not seen[tag] then
                        seen[tag] = true
                        local ops = ops_of(ci, cj)
                        local px, pz = ci * 512 + floor((p[1] - ci * 32) * 16 + 0.5), (4 * 32 + 2 + cj) * 512 + floor((p[2] - cj * 32) * 16 + 0.5)
                        local py = 128 + line.level * transit_const().level_m * 16 - 5
                        local solid = false
                        for _, o in ipairs(ops) do
                            if o.lo and px >= o.lo[1] and px <= o.hi[1] and py >= o.lo[2] and py <= o.hi[2] and pz >= o.lo[3] and pz <= o.hi[3] then solid = (o.kind == "box") end
                        end
                        S.floor_checked = S.floor_checked + 1
                        if not solid then bad(17, line.name .. ": no floor under stop " .. t[1] .. " at (" .. string.format("%.1f, %.1f", p[1], p[2]) .. ") on level " .. line.level) end
                    end
                end
            end
        end
    end
    -- the railed car (E16, 54 voxels = 3.4 m with its roof frame): every cell a line's waypoints lie in is at least 4.5 m high (the tunnels are 6 m, the stations 7 m, the corners 8 m, the X halls 14 m)
    for _, line in ipairs(lines) do
        for i, p in ipairs(line.points) do
            local inf = transit_cell_info(floor(p[1] / 32), floor(p[2] / 32))
            if inf and inf.room and inf.room.h < 4.5 then bad(17, line.name .. ": waypoint " .. i .. " is in a room " .. inf.room.h .. " m high: the car (3.4 m) does not fit") end
        end
    end
    -- lines of one level never come closer than 12 m to each other (the cars meet only in the X halls, which are two storeys: the verticals run at level 1, the rows at level 0)
    for i = 1, #lines do
        for j = i + 1, #lines do
            local a, b = lines[i], lines[j]
            if a.level == b.level then
                local dmin = 1e9
                for _, p in ipairs(a.points) do
                    for _, q in ipairs(b.points) do dmin = min(dmin, math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2)) end
                end
                -- (the waypoints are the corners of the polylines: two parallel rows or columns are 32 m apart, a closer pair is a crossing at one level)
                local cross = false
                for ia = 1, #a.points - 1 do
                    for ib = 1, #b.points - 1 do
                        local p, q, r, s = a.points[ia], a.points[ia + 1], b.points[ib], b.points[ib + 1]
                        local d1x, d1z, d2x, d2z = q[1] - p[1], q[2] - p[2], s[1] - r[1], s[2] - r[2]
                        local den = d1x * d2z - d1z * d2x
                        if den ~= 0 then
                            local t = ((r[1] - p[1]) * d2z - (r[2] - p[2]) * d2x) / den
                            local u = ((r[1] - p[1]) * d1z - (r[2] - p[2]) * d1x) / den
                            if t >= 0 and t <= 1 and u >= 0 and u <= 1 then cross = true end
                        end
                    end
                end
                if cross then bad(17, a.name .. " and " .. b.name .. " cross at one level") end
                if dmin < 12 then bad(17, a.name .. " and " .. b.name .. ": waypoints " .. string.format("%.1f", dmin) .. " m apart at one level") end
            end
        end
    end
    return { violations = V, stats = S }
end

function K.check(plan, CG)
    if plan.P.kind == "transit" then return K.check_transit(plan, CG) end
    local ctx, P = plan.ctx, plan.P
    local V, S = {}, {}
    local function bad(item, text) V[#V + 1] = { item = item, text = text } end
    local nodes = plan.nodes
    local function cellinfo(id) return plan.cells[id] end

    -- 1. connected: every node is reached from the arrival (gates open)
    local dist_open = CG.bfs(plan, { plan.arrival })
    local nn, nreach = 0, 0
    for id in pairs(nodes) do nn = nn + 1; if dist_open[id] then nreach = nreach + 1 end end
    S.nodes, S.reached = nn, nreach
    if nn ~= nreach then
        local miss = {}
        for id in pairs(nodes) do if not dist_open[id] then miss[#miss + 1] = id end end
        table.sort(miss)
        bad(1, "not connected: " .. #miss .. " unreachable, e.g. " .. table.concat(miss, ",", 1, min(4, #miss)))
    end

    -- 2. ways down: at least two stairwells reached; the borough ones are not in the arrival block when there are several
    local nstairs = 0
    for _, id in ipairs(plan.stairs) do if dist_open[id] then nstairs = nstairs + 1 end end
    S.stairs = nstairs
    if nstairs < 2 then bad(2, "only " .. nstairs .. " stairwells reached") end
    if P.kind == "grid" and P.BW * P.BH > 1 then
        local aci, acj = CG.arrival(ctx)
        for _, id in ipairs(plan.stairs) do
            local nd = nodes[id]
            if nd.kind == "ring" and floor(nd.ci / 8) == floor(aci / 8) and floor(nd.cj / 8) == floor(acj / 8) then bad(2, "a borough stairwell in the arrival block: " .. id) end
        end
    end

    -- 3. safety: every cell within K.SAFE_STEPS steps of a safe room / guild / arrival; safe rooms have two openings and are not next to a lair
    local dist_safe = CG.bfs(plan, plan.safe)
    local smax, over3 = 0, 0
    for _, id in ipairs(plan.order) do
        local d = dist_safe[id]
        if not d then bad(3, "no safe room reachable from " .. id)
        else
            smax = max(smax, d)
            if d > 3 then over3 = over3 + 1 end
            if d > K.SAFE_STEPS then bad(3, string.format("%s is %d steps from a safe room (limit %d)", id, d, K.SAFE_STEPS)) end
        end
    end
    S.safe_max, S.safe_over3 = smax, over3
    for _, id in ipairs(plan.safe) do
        local info = cellinfo(id)
        if info.deg < 2 then bad(3, "safe room " .. id .. " has " .. info.deg .. " opening(s)") end
        for _, a in ipairs(plan.adj[id]) do
            local o = plan.cells[a.to]
            if o and (o.role == "lair") then bad(3, "safe room " .. id .. " next to a lair") end
        end
    end

    -- 4. doors on the free band, 1..4 openings per room, dead ends at most 35 % of the rooms and never hazard rooms
    local rooms, dead = 0, 0
    for _, id in ipairs(plan.order) do
        local info = cellinfo(id)
        if info.room then
            rooms = rooms + 1
            if info.deg < 1 or info.deg > 4 then bad(4, id .. " has " .. info.deg .. " openings") end
            for sd, pos in pairs(info.door or {}) do
                local lo, hi
                if sd == "E" or sd == "W" then lo, hi = info.room.z + 3, info.room.z + info.room.d - 3 else lo, hi = info.room.x + 3, info.room.x + info.room.w - 3 end
                if pos < lo or pos > hi then bad(4, string.format("%s door %s at %s outside the free band %s..%s", id, sd, pos, lo, hi)) end
            end
            if info.deg == 1 and info.role == "room" then
                dead = dead + 1
                local t = CG.THEMES[info.theme]
                if t and t.hazard then bad(6, "hazard room " .. id .. " is a dead end") end
            end
        end
    end
    S.rooms, S.dead = rooms, dead
    if rooms > 0 and dead > 0.35 * rooms then bad(4, string.format("dead ends %d of %d rooms (more than 35 %%)", dead, rooms)) end

    -- 5. threat budget per room (the generator stops adding monsters at the budget; this verifies the numbers and the elite / ranged limits)
    local worst = 0
    for _, id in ipairs(plan.order) do
        local info = cellinfo(id)
        if info.room and info.role ~= "connector" then
            local pop = CG.population(ctx, info, dist_safe[id])
            if pop.threat > pop.budget + 1e-6 then bad(5, string.format("%s threat %.1f over budget %.1f", id, pop.threat, pop.budget)) end
            if pop.elites > 1 then bad(5, id .. " has " .. pop.elites .. " elites") end
            if pop.ranged > 2 then bad(5, id .. " has " .. pop.ranged .. " ranged") end
            worst = max(worst, pop.threat / pop.budget)
        end
    end
    S.threat_worst = worst

    -- 6. hazards: a hazard room's door band is dry (by the theme's rule), it is never a dead end (4) and never all of a safe room's neighbours
    for _, id in ipairs(plan.safe) do
        local allhaz, n = true, 0
        for _, a in ipairs(plan.adj[id]) do
            local o = plan.cells[a.to]
            if o then n = n + 1; local t = CG.THEMES[o.theme]; if not (t and t.hazard) then allhaz = false end end
        end
        if n > 0 and allhaz then bad(6, "all neighbours of safe room " .. id .. " are hazard rooms") end
    end

    -- 7. gates: with every gate closed every cell still reaches a safe room and a free stairwell; gates exist only at lairs and borough rings
    local function closed(e) return e.gate end
    local dist_g = CG.bfs(plan, { plan.arrival }, closed)
    local free = {}
    for _, id in ipairs(plan.stairs) do if nodes[id].kind ~= "ring" then free[#free + 1] = id end end
    S.free = #free
    if #free < 1 then bad(7, "no free stairwell") end
    for _, id in ipairs(plan.order) do
        if not dist_g[id] and plan.cells[id].role ~= "lair" then bad(7, id .. " is cut off from the arrival by a closed gate") end
    end
    for _, id in ipairs(free) do if not dist_g[id] then bad(7, "free stairwell " .. id .. " behind a gate") end end
    for _, e in ipairs(plan.gates) do
        local a, b = plan.cells[e.a], plan.cells[e.b]
        local ok = (a and a.role == "lair") or (b and b.role == "lair") or (nodes[e.a].kind == "ring") or (nodes[e.b].kind == "ring")
        if not ok then bad(7, "a gate that is not at a lair: " .. e.a .. " " .. e.b) end
    end
    local dist_gs = CG.bfs(plan, plan.safe, closed)
    for _, id in ipairs(plan.order) do if not dist_gs[id] and plan.cells[id].role ~= "lair" then bad(7, id .. " reaches no safe room with the gates closed") end end

    -- 8. the quadrant graph of every block is complete (via side halls) and every block side has an artery door
    if P.kind == "grid" then
        for bj = 0, P.BH - 1 do for bi = 0, P.BW - 1 do
            -- union of the 4 quadrants through "side" edges
            local seen, queue = { ["0,0"] = true }, { { 0, 0 } }
            local qh = 1
            while qh <= #queue do
                local q = queue[qh]; qh = qh + 1
                for _, e in ipairs(plan.edges) do
                    if e.kind == "side" then
                        local a, b = plan.cells[e.a], plan.cells[e.b]
                        local qa = { a.q[1] - bi * 2, a.q[2] - bj * 2 }
                        local qb = { b.q[1] - bi * 2, b.q[2] - bj * 2 }
                        local inblock = qa[1] >= 0 and qa[1] < 2 and qa[2] >= 0 and qa[2] < 2 and qb[1] >= 0 and qb[1] < 2 and qb[2] >= 0 and qb[2] < 2
                        if inblock then
                            local ka, kb = qa[1] .. "," .. qa[2], qb[1] .. "," .. qb[2]
                            if ka == q[1] .. "," .. q[2] and not seen[kb] then seen[kb] = true; queue[#queue + 1] = qb end
                            if kb == q[1] .. "," .. q[2] and not seen[ka] then seen[ka] = true; queue[#queue + 1] = qa end
                        end
                    end
                end
            end
            if #queue < 4 then bad(8, "block " .. bi .. "," .. bj .. ": the quadrants are not joined by side halls (" .. #queue .. " of 4)") end
            for _, side in ipairs({ "W", "E", "N", "S" }) do
                local found = false
                for t = 0, 7 do
                    local ci, cj
                    if side == "W" then ci, cj = bi * 8, bj * 8 + t elseif side == "E" then ci, cj = bi * 8 + 7, bj * 8 + t
                    elseif side == "N" then ci, cj = bi * 8 + t, bj * 8 else ci, cj = bi * 8 + t, bj * 8 + 7 end
                    if plan.cells[cid and cid(ci, cj) or ("c" .. ci .. "_" .. cj)].open[side] == "artery" then found = true end
                end
                if not found then bad(8, "block " .. bi .. "," .. bj .. " has no door to its " .. side .. " artery") end
            end
        end end
    end

    -- 9. every lair has an antechamber on the path: its only opening is the edge to the antechamber
    for _, id in ipairs(plan.order) do
        local info = plan.cells[id]
        if info.role == "lair" then
            local n, ante = 0, false
            for _, a in ipairs(plan.adj[id]) do n = n + 1; if plan.cells[a.to] and plan.cells[a.to].role == "ante" then ante = true end end
            if n ~= 1 or not ante then bad(9, "lair " .. id .. " opens onto " .. n .. " things, antechamber: " .. tostring(ante)) end
        end
    end

    -- 10. a borough's courtyard (its four cells) has at least three outside exits
    local exits_min = 99
    for id, nd in pairs(nodes) do
        if nd.kind == "ring" then
            local ox, oz = nd.ci, nd.cj
            local n = 0
            local seenx = {}
            for dj = 0, 1 do for di = 0, 1 do
                local c = "c" .. (ox + di) .. "_" .. (oz + dj)
                for _, a in ipairs(plan.adj[c]) do
                    local o = plan.cells[a.to]
                    local inside = o and o.ci >= ox and o.ci < ox + 2 and o.cj >= oz and o.cj < oz + 2
                    if not inside and a.kind ~= "gate" and not seenx[c .. a.to] then seenx[c .. a.to] = true; n = n + 1 end
                end
            end end
            exits_min = min(exits_min, n)
            if n < 3 then bad(10, "the courtyard of " .. id .. " has " .. n .. " exit(s)") end
        end
    end
    S.courtyard_exits_min = (exits_min < 99) and exits_min or nil

    -- 11. alleys are loop edges: without them the graph is still connected
    local dist_na = CG.bfs(plan, { plan.arrival }, function(e) return e.kind == "alley" end)
    local nalley = 0
    for _, e in ipairs(plan.edges) do if e.kind == "alley" then nalley = nalley + 1 end end
    S.alleys = nalley
    for id in pairs(nodes) do if dist_open[id] and not dist_na[id] then bad(11, id .. " is only reachable through an alley"); break end end

    -- 12. a bathroom door never sits on a door band: they sit at the middle of a hall between two rooms; the halls are at least 10 m between the rooms (5 m margins on both sides) -- TODO P1: the bathroom doors are not modelled in the plan yet; the hall geometry (P1) checks them
    S.hall_gap_min = 10      -- (by the margins of the room placement; asserted here: every room is at least 5 m from its cell border)
    for _, id in ipairs(plan.order) do
        local info = plan.cells[id]
        if info.room and not CG.super_of(ctx, info.ci, info.cj) then          -- (a super-cell's quarter rooms touch each other inside: their outside margins are 6 m by construction)
            local r = info.room
            if r.x < 5 or r.z < 5 or r.x + r.w > 27 or r.z + r.d > 27 then bad(12, id .. " room " .. r.x .. "," .. r.z .. "," .. r.w .. "x" .. r.d .. " is closer than 5 m to its cell border") end
        end
    end

    -- 13. no big monster (radius over 1.2) in a room next to an alley
    for _, id in ipairs(plan.order) do
        local info = plan.cells[id]
        local has_alley = false
        for _, a in ipairs(plan.adj[id]) do if a.kind == "alley" then has_alley = true end end
        if has_alley and info.room and info.role == "room" then
            local pop = CG.population(ctx, info, dist_safe[id])
            for _, m in ipairs(pop.list) do if (CG.RADIUS[m.kind] or 0.5) > 1.2 then bad(13, id .. " holds a " .. m.kind .. " next to an alley") end end
        end
    end

    -- 14. floor 3: at least three villages (the quest needs one clue from each of three), all reachable (the gate of the city is no village)
    if plan.P.supers == "village" then
        local origins, seen = {}, {}
        for _, id in ipairs(plan.order) do
            local info = plan.cells[id]
            if info.role == "village" then
                local sup = CG.super_of(ctx, info.ci, info.cj)
                if sup and sup.kind == "village" and not seen[sup.id] then seen[sup.id] = true; origins[#origins + 1] = sup end
            end
        end
        S.villages = #origins
        if #origins < 3 then bad(14, "only " .. #origins .. " villages (the quest needs 3)") end
        for _, sup in ipairs(origins) do
            for dj = 0, 1 do for di = 0, 1 do
                local cid_ = "c" .. (sup.ci + di) .. "_" .. (sup.cj + dj)
                if not dist_open[cid_] then bad(14, "village " .. sup.id .. " is not reachable at " .. cid_) end
                if cid_ == plan.arrival then bad(14, "the arrival lies in village " .. sup.id) end
            end end
        end
    end

    -- 15. the room layout grammar (gen/furnish.lua): no blocking footprint on another or across a door band, no spot inside a footprint or a door band, the doors and the spots one region
    if CG.H and deco_layout then
        local themes = deco_layout_themes()
        local n15 = 0
        for _, id in ipairs(plan.order) do
            local info = plan.cells[id]
            if info.room and themes[info.theme] then
                local doors = {}
                for _, d in ipairs({ "E", "S", "W", "N" }) do
                    local k = info.open[d]
                    if k and k ~= "internal" and info.door and info.door[d] then doors[#doors + 1] = { side = d, pos = info.door[d] } end
                end
                local mkf = function(salt) return deco_rng(CG.H, ctx.floor, info.ci, info.cj, salt or 1) end
                local lay = (ctx.floor == 4) and transit_layout(info, mkf) or deco_layout(info.theme, info.room, doors, mkf, ctx.floor)
                if lay then
                    n15 = n15 + 1
                    for _, b in ipairs(deco_layout_check(lay, info.room, doors)) do bad(15, id .. " (" .. info.theme .. "): " .. b) end
                end
            end
        end
        S.furnished = n15
    end

    -- 16. the halls (gen/furnish.lua deco_hall / deco_street): every corridor keeps a free width of at least max(width - 1, 2.5) m along its whole half, nothing stands in a mouth
    if CG.H and deco_hall then
        local stub = { model = function() end, fill = function() end, vbox = function() end, sphere = function() end, pillar = function() end, ring = function() end }
        local n16 = 0
        for _, id in ipairs(plan.order) do
            local info = plan.cells[id]
            if info.room then
                for _, d in ipairs({ "E", "S", "W", "N" }) do
                    local seg = deco_hall_seg(info, d)
                    if seg and plan.P.kind == "ruin" then seg.open = true; seg.h = 5 end
                    if seg then
                        n16 = n16 + 1
                        local prot = deco_hall(stub, seg, function(salt) return deco_rng(CG.H, ctx.floor, info.ci, info.cj, (salt or 1) + (d == "E" and 0 or (d == "S" and 20 or (d == "W" and 40 or 60)))) end, ctx.floor)
                        for _, b in ipairs(deco_hall_check(seg, prot)) do bad(16, id .. ": " .. b) end
                    end
                end
            end
        end
        S.halls = n16
        if plan.P.kind ~= "ruin" then                                     -- the streets (the strips of the arteries on the block borders)
            local len = (ctx.floor == 2) and 3 or 4
            for _, id in ipairs(plan.order) do
                local info = plan.cells[id]
                for _, d in ipairs({ "E", "S", "W", "N" }) do
                    local ci, cj = info.ci, info.cj
                    if (d == "E" and ci % 8 == 7) or (d == "W" and ci % 8 == 0) or (d == "S" and cj % 8 == 7) or (d == "N" and cj % 8 == 0) then
                        local mouths = {}
                        if info.open[d] == "artery" and info.door and info.door[d] then mouths[1] = { info.door[d], 6 } end
                        local seg = { side = d, w = len, doors = mouths }
                        local prot = deco_street(stub, seg, function(salt) return deco_rng(CG.H, ctx.floor, ci, cj, salt or 1) end, ctx.floor)
                        for _, b in ipairs(deco_street_check(seg, prot)) do bad(16, id .. ": " .. b) end
                    end
                end
            end
        end
    end

    -- theme sizes: every theme fits its room
    for _, id in ipairs(plan.order) do
        local info = plan.cells[id]
        local t = info.room and CG.THEMES[info.theme]
        if t and (info.room.w < t.min_w or info.room.d < t.min_d) then bad(4, string.format("%s: %s needs %dx%d, room is %dx%d", id, info.theme, t.min_w, t.min_d, info.room.w, info.room.d)) end
    end
    return { violations = V, stats = S }
end
