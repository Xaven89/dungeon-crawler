-- gen/cell: the plan of a BIG floor as a pure function of (seed, floor, cell). No tables kept between calls except the memo of one context, no world reads, no `Game`: the same text runs in the
-- game and (later, P1) inside the engine's region hook. The hash is a parameter (`make_cellgen(H)`), H(a, b, c, d, e) -> [0, 1) from integers.
--
-- The model (plan r31 v2, ~/share/big-floors-plan.md):
--   cell      32 x 32 m, one room (or a connector, or part of a super-cell) in it, 5 m margin
--   quadrant  4 x 4 cells joined by a binary-tree maze toward its root (3, 3); one mob theme, one lair (two cells), one safe room or guild
--   block     2 x 2 quadrants = 8 x 8 cells, bordered by 8 m arteries; side halls (4 m) cross the quadrant borders; alleys (3 m) are loop edges only
--   super-cell 2 x 2 cells: the borough lair's courtyard (floors 1-2), a village or the park (floor 3): its four cells are connected inside, outside it follows the normal edges
-- A floor is BW x BH blocks (floor 3: 3 x 3 quadrants as a ruin, no arteries, roads instead).
-- Hook-safe: ONE global function, every table and helper inside it, no file-level locals and no `Game`/`G` (the engine's `hook_globals = {"cellgen_make", "cellgen_hash_from"}` shares exactly such functions).
-- Use inside the hook:  local CG = cellgen_make(cellgen_hash_from(worldgen.hash)); in the game: Game.gen.cell.make_cellgen() (the integer mixer below).

function cellgen_make(H)
    local floor, max, min = math.floor, math.max, math.min

    -- a default hash for the game side and the tests (integer mixing, no floats before the end): the hook passes worldgen.hash instead
    local function default_hash(a, b, c, d, e)
        local h = 0x2545F4914F6CDD1D
        local args = { a or 0, b or 0, c or 0, d or 0, e or 0 }
        for i = 1, 5 do
            h = h ~ (args[i] * 0x9E3779B97F4A7C15)
            h = (h ~ (h >> 31)) * 0xBF58476D1CE4E5B9
            h = (h ~ (h >> 29)) * 0x94D049BB133111EB
            h = h ~ (h >> 32)
        end
        return (h & 0xFFFFFF) / 0x1000000
    end

    -- the themes: size they need (min_w, min_d, min_h), weight by floor, hazard (never a dead end), what fills them
    local THEMES = {
        hall      = { min_w = 14, min_d = 14, weight = 3.0 },
        furnace   = { min_w = 18, min_d = 18, weight = 2.0, hazard = true },
        flooded   = { min_w = 18, min_d = 18, weight = 1.8, hazard = true },
        ballroom  = { min_w = 18, min_d = 18, weight = 1.4, min_h = 7 },
        grotto    = { min_w = 14, min_d = 14, weight = 2.0 },
        crypt     = { min_w = 14, min_d = 14, weight = 1.8 },
        library   = { min_w = 14, min_d = 14, weight = 1.8 },
        depot     = { min_w = 14, min_d = 14, weight = 1.8 },
        prize     = { min_w = 14, min_d = 14, weight = 0.9, unique = true },
        warlord   = { min_w = 20, min_d = 18, weight = 1.0, from = 2 },
        captive   = { min_w = 18, min_d = 18, weight = 0.9, from = 2 },
    }
    local THEME_ORDER = { "hall", "furnace", "flooded", "ballroom", "grotto", "crypt", "library", "depot", "prize", "warlord", "captive" }

    -- how dangerous a monster is (relative: a rat = 1), for the threat budget of a room
    local THREAT = { rat = 1, slime = 1.3, intern = 2, goblin = 2, slime_toxic = 2.4, spitter = 2.6, bandit = 3, orc = 4, imp = 3, samurai = 5, troll = 7, cyclops = 14 }
    local RADIUS = { rat = 0.35, slime = 0.5, slime_toxic = 0.5, intern = 0.5, goblin = 0.5, spitter = 0.5, bandit = 0.5, orc = 0.55, imp = 0.5, samurai = 0.5, troll = 0.8, cyclops = 1.0 }
    -- the pools by first floor: a quadrant draws 2-3 kinds from what exists on the floor
    local ROSTER = { { "rat", 1 }, { "slime", 1 }, { "intern", 1 }, { "goblin", 1 }, { "slime_toxic", 2 }, { "spitter", 2 }, { "bandit", 2 }, { "orc", 2 }, { "imp", 3 }, { "samurai", 4 }, { "troll", 4 } }

    local DIRS = { E = { 1, 0, "W" }, S = { 0, 1, "N" }, W = { -1, 0, "E" }, N = { 0, -1, "S" } }
    local CG = { CELL = 32, THEMES = THEMES, THREAT = THREAT, RADIUS = RADIUS }
    H = H or default_hash

    -- ------------------------------------------------------------------------------------------ floor parameters
    -- setting: "small" (the default: floor 1-2 are 1 x 2 blocks) or "large" (2 x 2 blocks)
    function CG.params(fl, setting)
        if fl == 4 then return nil end                      -- the transit floor is its own plan (a line graph, not this grid)
        local P = { floor = fl, setting = setting or "small" }
        if fl == 3 then
            P.kind, P.W, P.H, P.QW, P.QH = "ruin", 12, 12, 3, 3          -- 3 x 3 quadrants, no blocks, roads instead of arteries
            P.loop, P.alley_share, P.connector_share, P.supers = 0.5, 0.3, 0.2, "village"
        else
            local bw, bh
            if fl <= 2 then if P.setting == "large" then bw, bh = 2, 2 else bw, bh = 1, 2 end
            elseif fl == 5 then bw, bh = 1, 2
            else bw, bh = 1, 1 end
            P.kind, P.BW, P.BH = "grid", bw, bh
            P.W, P.H, P.QW, P.QH = bw * 8, bh * 8, bw * 2, bh * 2
            P.loop = (fl <= 2) and 0.22 or 0.12
            P.alley_share = 0.35
            P.connector_share = (fl <= 2) and 0.4 or 0.15
            P.supers = (fl <= 2) and "borough" or nil
        end
        P.free_stairs = 2
        P.side_extra = 0.25
        P.artery_door = 0.3
        return P
    end

    -- a new context: everything below is memoised in it (one call of the plan, or one region of the hook)
    function CG.new(seed, fl, setting)
        local P = CG.params(fl, setting)
        if not P then return nil end
        return { seed = seed, floor = fl, P = P, q = {}, c = {}, blk = {}, misc = {} }
    end

    local function h(ctx, a, b, c, d) return H(ctx.seed, ctx.floor * 1000 + (d or 0), a, b, c or 0) end

    -- ------------------------------------------------------------------------------------------ arrival, blocks, super-cells
    function CG.arrival(ctx)
        local m = ctx.misc.arrival
        if m then return m[1], m[2] end
        local W = ctx.P.W
        local ci = floor(h(ctx, 1, 1, 1, 11) * W)
        if ctx.P.kind == "ruin" then ci = 4 + floor(h(ctx, 1, 1, 1, 11) * 4) end         -- the ruin's gate road: a middle column of the top row
        ctx.misc.arrival = { ci, 0 }
        return ci, 0
    end

    local function block_of(ci, cj) return floor(ci // 8), floor(cj // 8) end

    -- the quadrant (qi, qj) -> its block (bi, bj)
    local function quad_block(qi, qj) return floor(qi / 2), floor(qj / 2) end

    -- the borough super-cell of a block (floors 1-2): { qi, qj, u, v } the quadrant and the 2 x 2 cell origin (0 or 2) inside it; never in the arrival block when there are several blocks
    function CG.borough(ctx, bi, bj)
        if ctx.P.supers ~= "borough" then return nil end
        local key = bi .. "," .. bj
        local b = ctx.blk[key]
        if b ~= nil then return b or nil end
        local aci, acj = CG.arrival(ctx)
        local abi, abj = block_of(aci, acj)
        if (ctx.P.BW * ctx.P.BH) > 1 and abi == bi and abj == bj then ctx.blk[key] = false; return nil end
        local qi, qj = bi * 2 + floor(h(ctx, bi, bj, 1, 21) * 2), bj * 2 + floor(h(ctx, bi, bj, 2, 21) * 2)
        local u, v = 2 * floor(h(ctx, bi, bj, 3, 21) * 2), 2 * floor(h(ctx, bi, bj, 4, 21) * 2)
        b = { qi = qi, qj = qj, u = u, v = v, ci = qi * 4 + u, cj = qj * 4 + v }
        ctx.blk[key] = b
        return b
    end

    -- the super-cell (borough, village, park) a cell belongs to, or nil: { kind, ci, cj (origin), id }
    function CG.super_of(ctx, ci, cj)
        local P = ctx.P
        if P.supers == "borough" then
            local bi, bj = block_of(ci, cj)
            local b = CG.borough(ctx, bi, bj)
            if b and ci >= b.ci and ci < b.ci + 2 and cj >= b.cj and cj < b.cj + 2 then return { kind = "borough", ci = b.ci, cj = b.cj, id = "r" .. bi .. "_" .. bj } end
        elseif P.supers == "village" then
            local qi, qj = floor(ci / 4), floor(cj / 4)
            local key = "v" .. qi .. "," .. qj
            local s = ctx.blk[key]
            if s == nil then
                s = false
                -- a village or the park in about half of the quadrants (the centre quadrant is the park)
                if (qi == 1 and qj == 1) then
                    s = { kind = "park", ci = qi * 4 + 1, cj = qj * 4 + 1, id = "park" }
                elseif h(ctx, qi, qj, 1, 31) < 0.6 then
                    local u, v = 2 * floor(h(ctx, qi, qj, 2, 31) * 2), 2 * floor(h(ctx, qi, qj, 3, 31) * 2)
                    s = { kind = "village", ci = qi * 4 + u, cj = qj * 4 + v, id = "t" .. qi .. "_" .. qj }
                end
                ctx.blk[key] = s
            end
            if s and ci >= s.ci and ci < s.ci + 2 and cj >= s.cj and cj < s.cj + 2 then return s end
        end
        return nil
    end

    -- ------------------------------------------------------------------------------------------ the maze of a quadrant
    -- the direction a cell opens toward in its quadrant's binary tree ("E" / "S"), nil for the root (3, 3)
    local function tree_dir(ctx, ci, cj)
        local u, v = ci % 4, cj % 4
        if u == 3 and v == 3 then return nil end
        if u == 3 then return "S" end
        if v == 3 then return "E" end
        return (h(ctx, ci, cj, 1, 41) < 0.5) and "E" or "S"
    end
    CG.tree_dir = tree_dir

    local function tree_parent(ctx, ci, cj)
        local d = tree_dir(ctx, ci, cj)
        if not d then return nil end
        return ci + DIRS[d][1], cj + DIRS[d][2]
    end

    -- the quadrant (qi, qj): leaves, lair, antechamber, safe room, prize, the mob theme ... (memo)
    function CG.quadrant(ctx, qi, qj)
        local key = qi .. "," .. qj
        local Q = ctx.q[key]
        if Q then return Q end
        Q = { qi = qi, qj = qj, cells = {}, extra = {} }
        ctx.q[key] = Q
        local P = ctx.P
        local aci, acj = CG.arrival(ctx)
        local ox, oz = qi * 4, qj * 4
        -- tree degree (incoming + outgoing) and incoming of every cell
        local incoming = {}
        for v = 0, 3 do for u = 0, 3 do
            local ci, cj = ox + u, oz + v
            local pi, pj = tree_parent(ctx, ci, cj)
            if pi then local k = pi .. "," .. pj; incoming[k] = (incoming[k] or 0) + 1 end
        end end
        local function deg(ci, cj) local pi = tree_parent(ctx, ci, cj); return (incoming[ci .. "," .. cj] or 0) + (pi and 1 or 0) end
        local function in_super(ci, cj) return CG.super_of(ctx, ci, cj) ~= nil end
        local function is_stair(ci, cj) for _, o in ipairs(CG.free_stairs(ctx)) do if o[1] == ci and o[2] == cj then return true end end return false end
        -- lairs and antechambers keep away from a borough: its courtyard needs its outside exits
        local function near_super(ci, cj) return in_super(ci + 1, cj) or in_super(ci - 1, cj) or in_super(ci, cj + 1) or in_super(ci, cj - 1) end
        local is_arrival = (aci >= ox and aci < ox + 4 and acj >= oz and acj < oz + 4)
        -- the lair: a leaf (nothing opens into it), not in a super-cell, its parent (the antechamber) neither
        local leaves = {}
        for v = 0, 3 do for u = 0, 3 do
            local ci, cj = ox + u, oz + v
            if not incoming[ci .. "," .. cj] and not in_super(ci, cj) and not is_stair(ci, cj) and not near_super(ci, cj) and not (ci == aci and cj == acj) and not (math.abs(ci - aci) + math.abs(cj - acj) <= 1) then
                local pi, pj = tree_parent(ctx, ci, cj)
                if pi and not in_super(pi, pj) and not is_stair(pi, pj) and not near_super(pi, pj) and not (pi == aci and pj == acj) and not (math.abs(pi - aci) + math.abs(pj - acj) <= 1) then leaves[#leaves + 1] = { ci, cj, pi, pj } end
            end
        end end
        if #leaves > 0 then
            local pick = leaves[1 + floor(h(ctx, qi, qj, 1, 51) * #leaves)]
            Q.lair = { pick[1], pick[2] }; Q.ante = { pick[3], pick[4] }
        end
        local function taken(ci, cj)
            return (Q.lair and Q.lair[1] == ci and Q.lair[2] == cj) or (Q.ante and Q.ante[1] == ci and Q.ante[2] == cj) or in_super(ci, cj) or is_stair(ci, cj)
        end
        -- tree distances inside the quadrant from a cell: dist map and eccentricity
        local tdcache = {}
        local function tree_dist(ci, cj)
            local ck = ci .. "," .. cj
            if tdcache[ck] then return tdcache[ck][1], tdcache[ck][2] end
            local dist, queue = { [ci .. "," .. cj] = 0 }, { { ci, cj } }
            local qh, ecc = 1, 0
            while qh <= #queue do
                local cu = queue[qh]; qh = qh + 1
                local d0 = dist[cu[1] .. "," .. cu[2]]
                local nb = {}
                local pi, pj = tree_parent(ctx, cu[1], cu[2]); if pi then nb[#nb + 1] = { pi, pj } end
                for _, dd in ipairs({ { -1, 0 }, { 0, -1 } }) do   -- the cells that open into this one
                    local ni, nj = cu[1] + dd[1], cu[2] + dd[2]
                    if ni >= ox and nj >= oz then
                        local qi2, qj2 = tree_parent(ctx, ni, nj)
                        if qi2 == cu[1] and qj2 == cu[2] then nb[#nb + 1] = { ni, nj } end
                    end
                end
                for _, n in ipairs(nb) do
                    local k = n[1] .. "," .. n[2]
                    if not dist[k] then dist[k] = d0 + 1; ecc = max(ecc, d0 + 1); queue[#queue + 1] = n end
                end
            end
            tdcache[ck] = { dist, ecc }
            return dist, ecc
        end
        -- the in-quadrant neighbours a cell could get an extra (non-tree) edge to
        local function extra_opts(ci, cj)
            local opts = {}
            for dn, d in pairs(DIRS) do
                local ni, nj = ci + d[1], cj + d[2]
                if ni >= ox and ni < ox + 4 and nj >= oz and nj < oz + 4 and not taken(ni, nj) then
                    local p1i, p1j = tree_parent(ctx, ci, cj); local p2i, p2j = tree_parent(ctx, ni, nj)
                    if not ((p1i == ni and p1j == nj) or (p2i == ci and p2j == cj)) then opts[#opts + 1] = { dn, ni, nj } end
                end
            end
            table.sort(opts, function(a, b) return a[1] < b[1] end)
            return opts
        end
        local function eligible(ci, cj) return not taken(ci, cj) and (deg(ci, cj) >= 2 or #extra_opts(ci, cj) > 0) and not (Q.lair and math.abs(Q.lair[1] - ci) + math.abs(Q.lair[2] - cj) <= 1) end
        -- the safe rooms: the arrival cell when it is in this quadrant, else the cell with the smallest tree eccentricity; and a second one as far from the first as the tree allows
        if is_arrival then Q.safe = { aci, acj }
        else
            local best, bestecc
            for v = 0, 3 do for u = 0, 3 do
                local ci, cj = ox + u, oz + v
                if eligible(ci, cj) then
                    local _, ecc = tree_dist(ci, cj)
                    local score = ecc + h(ctx, ci, cj, 2, 51) * 0.5
                    if not best or score < bestecc then best, bestecc = { ci, cj }, score end
                end
            end end
            Q.safe = best
        end
        if Q.safe then
            -- the second one minimises the worst distance from any cell to the nearer of the two (k-center on the quadrant tree)
            local dist = tree_dist(Q.safe[1], Q.safe[2])
            local far, fard
            for v = 0, 3 do for u = 0, 3 do
                local ci, cj = ox + u, oz + v
                if eligible(ci, cj) and not (ci == Q.safe[1] and cj == Q.safe[2]) then
                    local d2 = tree_dist(ci, cj)
                    local worst, sum = 0, 0
                    for k, d in pairs(dist) do local m = min(d, d2[k] or d); worst = max(worst, m); sum = sum + m end
                    local score = worst * 100 + sum + h(ctx, ci, cj, 3, 52)
                    if not far or score < fard then far, fard = { ci, cj }, score end
                end
            end end
            Q.safe2 = far
            Q.guild = (not is_arrival) and (qi % 2 == 1 or qj % 2 == 1) and h(ctx, qi, qj, 3, 51) < 0.25 or false
            -- a safe room has at least two openings: a hashed extra edge when its tree degree is 1
            for _, sf in ipairs({ Q.safe, Q.safe2 or false }) do
                if sf and deg(sf[1], sf[2]) < 2 then
                    local opts = extra_opts(sf[1], sf[2])
                    if #opts > 0 then local o = opts[1 + floor(h(ctx, qi, qj, 4, 51) * #opts)]; Q.extra[sf[1] .. "," .. sf[2] .. "," .. o[1]] = true; Q.extra[o[2] .. "," .. o[3] .. "," .. DIRS[o[1]][3]] = true end
                end
            end
        end
        -- a borough super-cell in this quadrant has at least three outside exits inside the quadrant (its courtyard is a hub, not a dead end)
        do
            local sup
            for v = 0, 3 do for u = 0, 3 do local sc = CG.super_of(ctx, ox + u, oz + v); if sc and sc.kind == "borough" then sup = sc end end end
            if sup then
                local cand = {}
                for dj = 0, 1 do for di = 0, 1 do
                    local ci, cj = sup.ci + di, sup.cj + dj
                    for dn, d in pairs(DIRS) do
                        local ni, nj = ci + d[1], cj + d[2]
                        local outside = not (ni >= sup.ci and ni < sup.ci + 2 and nj >= sup.cj and nj < sup.cj + 2)
                        if outside and ni >= ox and ni < ox + 4 and nj >= oz and nj < oz + 4 and not taken(ni, nj) then cand[#cand + 1] = { ci, cj, dn, ni, nj } end
                    end
                end end
                table.sort(cand, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end if a[2] ~= b[2] then return a[2] < b[2] end return a[3] < b[3] end)
                -- the tree edges that already leave or enter the super-cell count; open hashed extra edges until there are 3
                local have = 0
                for _, c in ipairs(cand) do
                    local pi, pj = tree_parent(ctx, c[1], c[2])
                    local npi, npj = tree_parent(ctx, c[4], c[5])
                    if (pi == c[4] and pj == c[5]) or (npi == c[1] and npj == c[2]) then have = have + 1 end
                end
                local order = {}
                for i = 1, #cand do order[i] = i end
                table.sort(order, function(a, b) return h(ctx, cand[a][1] * 7 + cand[a][2], a, 5, 53) < h(ctx, cand[b][1] * 7 + cand[b][2], b, 5, 53) end)
                for _, i in ipairs(order) do
                    if have >= 3 then break end
                    local c = cand[i]
                    local pi, pj = tree_parent(ctx, c[1], c[2])
                    local npi, npj = tree_parent(ctx, c[4], c[5])
                    if not ((pi == c[4] and pj == c[5]) or (npi == c[1] and npj == c[2])) then
                        Q.extra[c[1] .. "," .. c[2] .. "," .. c[3]] = true; Q.extra[c[4] .. "," .. c[5] .. "," .. DIRS[c[3]][3]] = true; have = have + 1
                    end
                end
            end
        end
        -- the prize / captive room: one of the cells not taken, not the safe room
        local cand = {}
        for v = 0, 3 do for u = 0, 3 do
            local ci, cj = ox + u, oz + v
            if not taken(ci, cj) and not (Q.safe and Q.safe[1] == ci and Q.safe[2] == cj) and not (Q.safe2 and Q.safe2[1] == ci and Q.safe2[2] == cj) then cand[#cand + 1] = { ci, cj } end
        end end
        if #cand > 0 then Q.prize = cand[1 + floor(h(ctx, qi, qj, 5, 51) * #cand)] end
        -- the mob theme: 2 or 3 kinds from what exists on this floor, a palette, an equipment variant, a name set
        local avail = {}
        for _, r in ipairs(ROSTER) do if ctx.floor >= r[2] then avail[#avail + 1] = r[1] end end
        local nk = (#avail >= 3) and (2 + floor(h(ctx, qi, qj, 6, 51) * 2)) or #avail
        local pool, used = {}, {}
        for i = 1, nk do
            local idx = 1 + floor(h(ctx, qi, qj, 10 + i, 51) * #avail)
            local tries = 0
            while used[idx] and tries < #avail do idx = idx % #avail + 1; tries = tries + 1 end
            used[idx] = true; pool[#pool + 1] = avail[idx]
        end
        Q.mob = { kinds = pool, palette = floor(h(ctx, qi, qj, 7, 51) * 8), gear = floor(h(ctx, qi, qj, 8, 51) * 4), names = floor(h(ctx, qi, qj, 9, 51) * 6) }
        return Q
    end

    -- ------------------------------------------------------------------------------------------ free stairwells
    -- chosen from the hash and cheap rules only (no quadrant lookup: a region would otherwise generate quadrants all over the floor); the quadrants keep their lair, safe room and prize off these cells
    function CG.free_stairs(ctx)
        local m = ctx.misc.free
        if m then return m end
        m = {}
        ctx.misc.free = m
        local W, Hc = ctx.P.W, ctx.P.H
        local aci, acj = CG.arrival(ctx)
        for i = 1, ctx.P.free_stairs do
            for t = 0, 40 do
                local ci, cj = floor(h(ctx, i, t, 1, 61) * W), floor(h(ctx, i, t, 2, 61) * Hc)
                local ok = math.abs(ci - aci) + math.abs(cj - acj) > 1 and not CG.super_of(ctx, ci, cj)
                if ok then
                    for _, o in ipairs(m) do if o[1] == ci and o[2] == cj then ok = false end end
                    -- a free stairwell is never in the arrival block when there is more than one block (the floor is explored, not skipped)
                    if ok and ctx.P.kind == "grid" and (ctx.P.BW * ctx.P.BH) > 1 then
                        local bi, bj = block_of(ci, cj); local abi, abj = block_of(aci, acj)
                        if bi == abi and bj == abj then ok = false end
                    end
                end
                if ok then m[#m + 1] = { ci, cj }; break end
            end
        end
        return m
    end

    -- ------------------------------------------------------------------------------------------ edges
    -- is the cell inside the floor?
    local function inside(ctx, ci, cj) return ci >= 0 and cj >= 0 and ci < ctx.P.W and cj < ctx.P.H end

    -- the role of a cell (without its theme): "arrival", "safe", "guild", "lair", "ante", "stairs", "prize", "borough", "village", "park", "room", "connector"
    function CG.role(ctx, ci, cj)
        local key = ci .. "," .. cj
        local r = ctx.c[key]
        if r then return r end
        local aci, acj = CG.arrival(ctx)
        local Q = CG.quadrant(ctx, floor(ci / 4), floor(cj / 4))
        local function same(p) return p and p[1] == ci and p[2] == cj end
        local sup = CG.super_of(ctx, ci, cj)
        if ci == aci and cj == acj then r = "arrival"
        elseif sup then r = sup.kind
        elseif same(Q.lair) then r = "lair"
        elseif same(Q.ante) then r = "ante"
        elseif same(Q.safe) then r = Q.guild and "guild" or "safe"
        elseif same(Q.safe2) then r = "rest"
        else
            r = nil
            for _, s in ipairs(CG.free_stairs(ctx)) do if s[1] == ci and s[2] == cj then r = "stairs" end end
            if not r then
                if same(Q.prize) then r = "prize"
                elseif h(ctx, ci, cj, 1, 71) < ctx.P.connector_share then r = "connector"
                else r = "room" end
            end
        end
        ctx.c[key] = r
        return r
    end

    local function sides_key(ci, cj, d) return ci .. "," .. cj .. "," .. d end

    -- the kind of the edge from cell (ci, cj) toward direction d ("E" or "S" canonical; W / N ask the neighbour): nil = closed, else
    -- "tree", "loop" (a hall), "alley", "side" (a side hall across a quadrant border inside a block), "internal" (inside a super-cell), "road" (floor 3 quadrant border)
    function CG.edge(ctx, ci, cj, d)
        if d == "W" or d == "N" then
            local dd = DIRS[d]
            return CG.edge(ctx, ci + dd[1], cj + dd[2], DIRS[d][3])
        end
        local dd = DIRS[d]
        local ni, nj = ci + dd[1], cj + dd[2]
        if not inside(ctx, ci, cj) or not inside(ctx, ni, nj) then return nil end
        local P = ctx.P
        -- the lair cell opens only toward its antechamber (and that edge is a tree edge)
        local ra, rb = CG.role(ctx, ci, cj), CG.role(ctx, ni, nj)
        local sa, sb = CG.super_of(ctx, ci, cj), CG.super_of(ctx, ni, nj)
        if sa and sb and sa.id == sb.id then return "internal" end
        -- block borders (floors 1-2, 5+): no direct edge, the artery lies between
        if P.kind == "grid" then
            if d == "E" and ci % 8 == 7 then return nil end
            if d == "S" and cj % 8 == 7 then return nil end
        end
        local same_quad = (floor(ci / 4) == floor(ni / 4)) and (floor(cj / 4) == floor(nj / 4))
        local kind
        if same_quad then
            local Q = CG.quadrant(ctx, floor(ci / 4), floor(cj / 4))
            if tree_dir(ctx, ci, cj) == d then kind = "tree"
            elseif Q.extra[sides_key(ci, cj, d)] then kind = "loop"
            else
                if h(ctx, ci, cj, (d == "E") and 1 or 2, 81) < P.loop then
                    kind = (h(ctx, ci, cj, (d == "E") and 3 or 4, 81) < P.alley_share) and "alley" or "loop"
                end
            end
        else
            -- a quadrant border: floor 3 has roads (open, 6 m), the grid has 1-2 side halls per border
            if P.kind == "ruin" then kind = "road"
            else
                -- the border is identified by the quadrant pair; the forced edge is the first of the 4 (from a hashed start) that touches no lair
                local bq1, bq2 = (d == "E") and ci or floor(ci / 4), (d == "E") and floor(cj / 4) or cj
                local f = floor(h(ctx, bq1, bq2, (d == "E") and 1 or 2, 91) * 4)
                local idx = (d == "E") and (cj % 4) or (ci % 4)
                local forced
                for k = 0, 3 do
                    local i2 = (f + k) % 4
                    local ai, aj, bi2, bj2
                    if d == "E" then ai, aj, bi2, bj2 = ci, floor(cj / 4) * 4 + i2, ci + 1, floor(cj / 4) * 4 + i2
                    else ai, aj, bi2, bj2 = floor(ci / 4) * 4 + i2, cj, floor(ci / 4) * 4 + i2, cj + 1 end
                    if CG.role(ctx, ai, aj) ~= "lair" and CG.role(ctx, bi2, bj2) ~= "lair" then forced = i2; break end
                end
                if idx == forced then kind = "side"
                elseif h(ctx, ci, cj, (d == "E") and 5 or 6, 81) < P.side_extra then kind = "side" end
            end
        end
        -- the lair: only its tree edge to the antechamber stays
        if ra == "lair" or rb == "lair" then
            if kind == "tree" and ((ra == "lair" and rb == "ante") or (rb == "lair" and ra == "ante")) then return "tree" end
            return nil
        end
        -- an alley never carries the tree (a loop edge only) and never touches a safe room (they have halls)
        if kind == "alley" and (ra == "safe" or rb == "safe" or ra == "arrival" or rb == "arrival" or ra == "guild" or rb == "guild" or ra == "rest" or rb == "rest") then kind = "loop" end
        return kind
    end

    -- the door of a cell toward an artery (floors 1-2, 5+), true / false; one forced door per block side
    function CG.artery_door(ctx, ci, cj, side)
        local P = ctx.P
        if P.kind ~= "grid" then return false end
        local on = (side == "W" and ci % 8 == 0) or (side == "E" and ci % 8 == 7) or (side == "N" and cj % 8 == 0) or (side == "S" and cj % 8 == 7)
        if not on then return false end
        if CG.role(ctx, ci, cj) == "lair" then return false end
        local bi, bj = block_of(ci, cj)
        local horiz = (side == "W" or side == "E")
        local along = horiz and (cj % 8) or (ci % 8)
        local sk = (side == "W" and 1) or (side == "E" and 2) or (side == "N" and 3) or 4
        local forced = floor(h(ctx, bi, bj, sk, 95) * 8)
        -- the forced door of this block side: the first cell from the hashed one on that is not a lair (a lair has no door but its antechamber)
        for k = 0, 7 do
            local idx = (forced + k) % 8
            local fi, fj
            if horiz then fi, fj = ci, bj * 8 + idx else fi, fj = bi * 8 + idx, cj end
            if CG.role(ctx, fi, fj) ~= "lair" then
                if along == idx then return true end
                break
            end
        end
        return h(ctx, ci, cj, sk, 96) < P.artery_door
    end

    -- ------------------------------------------------------------------------------------------ one cell: role, theme, room, doors, population
    local function pick_weighted(ctx, ci, cj, list, salt)
        local total = 0
        for _, e in ipairs(list) do total = total + e[2] end
        local x = h(ctx, ci, cj, salt, 101) * total
        for _, e in ipairs(list) do x = x - e[2]; if x <= 0 then return e[1] end end
        return list[#list][1]
    end

    -- the openings of a cell by side: { E = kind|"artery", ... }
    function CG.openings(ctx, ci, cj)
        local o = {}
        for _, d in ipairs({ "E", "S", "W", "N" }) do
            local k = CG.edge(ctx, ci, cj, d)
            if k then o[d] = k
            elseif CG.artery_door(ctx, ci, cj, d) then o[d] = "artery" end
        end
        return o
    end

    local function count(o) local n = 0; for _ in pairs(o) do n = n + 1 end return n end

    -- is a graph neighbour of this cell a safe room, the arrival or a guild? (hazard rooms keep away from them)
    function CG.next_to_safe(ctx, ci, cj)
        for _, d in ipairs({ "E", "S", "W", "N" }) do
            local k = CG.edge(ctx, ci, cj, d)
            if k then
                local r = CG.role(ctx, ci + DIRS[d][1], cj + DIRS[d][2])
                if r == "safe" or r == "arrival" or r == "guild" or r == "rest" then return true end
            end
        end
        return false
    end

    function CG.cell(ctx, ci, cj)
        local key = "C" .. ci .. "," .. cj
        local info = ctx.c[key]
        if info then return info end
        local role = CG.role(ctx, ci, cj)
        local Q = CG.quadrant(ctx, floor(ci / 4), floor(cj / 4))
        info = { ci = ci, cj = cj, role = role, q = { Q.qi, Q.qj }, mob = Q.mob, open = CG.openings(ctx, ci, cj) }
        info.deg = count(info.open)
        ctx.c[key] = info
        local fl = ctx.floor
        local function size(minw, mind, maxw, maxd)
            local w = minw + 2 * floor(h(ctx, ci, cj, 1, 111) * ((maxw - minw) / 2 + 1))
            local d = mind + 2 * floor(h(ctx, ci, cj, 2, 111) * ((maxd - mind) / 2 + 1))
            return w, d
        end
        local theme
        local w, d
        if role == "arrival" or role == "safe" then theme, w, d = "safe", 20, 20
        elseif role == "rest" then theme, w, d = "rest", 12, 12
        elseif role == "guild" then theme, w, d = "guild", 16, 16
        elseif role == "lair" then theme, w, d = "arena", 22, 20
        elseif role == "ante" then theme, w, d = "ante", 18, 14
        elseif role == "stairs" then theme, w, d = "stairs_free", 14, 14
        elseif role == "connector" then theme = "connector"; w, d = size(10, 10, 12, 12)
        elseif role == "prize" then
            theme = (h(ctx, ci, cj, 3, 111) < 0.5) and "prize" or ((fl >= 2) and "captive" or "prize")
            w, d = size(THEMES[theme].min_w, THEMES[theme].min_d, 22, 20)
        elseif role == "room" then
            -- the theme first (by weight, hazards only where there is a way out), then a size that fits it
            local list = {}
            for _, n in ipairs(THEME_ORDER) do
                local t = THEMES[n]
                if not t.unique and (not t.from or fl >= t.from) and not (t.hazard and (info.deg < 2 or CG.next_to_safe(ctx, ci, cj))) and n ~= "captive" then list[#list + 1] = { n, t.weight } end
            end
            theme = pick_weighted(ctx, ci, cj, list, 4)
            w, d = size(THEMES[theme].min_w, THEMES[theme].min_d, 22, 20)
        else
            theme = role                                       -- borough / village / park: the super-cell is built by its own plan
        end
        info.theme = theme
        -- a cell of a super-cell holds its quarter of the courtyard (6 m margin on the outside, none toward the other cells of the super-cell)
        local sup = (not w) and CG.super_of(ctx, ci, cj)
        if sup then
            local left, top = (ci == sup.ci), (cj == sup.cj)
            info.room = { x = left and 6 or 0, z = top and 6 or 0, w = 26, d = 26, h = 12 }
            w, d = nil, nil
            info.door = {}
            local r = info.room
            for sd, kind in pairs(info.open) do
                if kind ~= "internal" then
                    if sd == "E" or sd == "W" then info.door[sd] = r.z + 3 + 2 * floor(h(ctx, ci, cj, 8 + (sd == "E" and 0 or 1), 111) * ((r.d - 6) / 2 + 1))
                    else info.door[sd] = r.x + 3 + 2 * floor(h(ctx, ci, cj, 10 + (sd == "N" and 0 or 1), 111) * ((r.w - 6) / 2 + 1)) end
                end
            end
        end
        if w then
            local maxox, maxoz = 32 - 5 - w, 32 - 5 - d
            info.room = { x = 5 + 2 * floor(h(ctx, ci, cj, 5, 111) * ((maxox - 5) / 2 + 1)), z = 5 + 2 * floor(h(ctx, ci, cj, 6, 111) * ((maxoz - 5) / 2 + 1)), w = w, d = d,
                          h = (role == "lair") and 12 or (6 + floor(h(ctx, ci, cj, 7, 111) * 4)) }
            if THEMES[theme] and THEMES[theme].min_h and info.room.h < THEMES[theme].min_h then info.room.h = THEMES[theme].min_h end
            -- doors: the position of the opening on each wall, on the free band (3 m from the corners)
            info.door = {}
            local r = info.room
            for sd in pairs(info.open) do
                if sd == "E" or sd == "W" then info.door[sd] = r.z + 3 + 2 * floor(h(ctx, ci, cj, 8 + (sd == "E" and 0 or 1), 111) * ((r.d - 6) / 2 + 1))
                else info.door[sd] = r.x + 3 + 2 * floor(h(ctx, ci, cj, 10 + (sd == "N" and 0 or 1), 111) * ((r.w - 6) / 2 + 1)) end
            end
        end
        return info
    end

    -- ------------------------------------------------------------------------------------------ population (a plan, not monsters): kinds with a threat sum under the room's budget
    function CG.budget(ctx, info, dist)
        local fl = ctx.floor
        local ramp = 0.6 + 0.4 * min(1, (dist or 0) / 12)
        return (14 + 6 * (fl - 1)) * ramp
    end

    function CG.population(ctx, info, dist)
        if info.pop then return info.pop end
        local pop = { list = {}, threat = 0 }
        info.pop = pop
        local r = info.room
        local role, fl = info.role, ctx.floor
        local ci, cj = info.ci, info.cj
        local B = CG.budget(ctx, info, dist)
        if info.deg <= 1 then B = B * 0.7 end                   -- a dead end has no retreat
        pop.budget = B
        local n = 0
        local kinds = info.mob and info.mob.kinds or { "rat" }
        if role == "room" then n = max(3, min(14, floor(r.w * r.d / 75) + floor(h(ctx, ci, cj, 1, 121) * 3) + floor((fl - 1) / 2)))
        elseif role == "ante" then n = 3 + floor(h(ctx, ci, cj, 1, 121) * 3)
        elseif role == "prize" then n = 2 + floor(h(ctx, ci, cj, 1, 121) * 2) end
        pop.elites, pop.ranged = 0, 0
        for i = 1, n do
            local kind = kinds[1 + floor(h(ctx, ci, cj, 10 + i, 121) * #kinds)]
            local th = THREAT[kind] or 2
            local elite = (fl >= 2 and pop.elites < 1 and h(ctx, ci, cj, 30 + i, 121) < min(0.3, 0.07 * (fl - 1)))
            if elite then th = th * 1.6 end
            if pop.threat + th > B then break end
            if (kind == "spitter" or kind == "imp") then if pop.ranged >= 2 then kind = "rat"; th = THREAT.rat else pop.ranged = pop.ranged + 1 end end
            pop.threat = pop.threat + th
            if elite then pop.elites = pop.elites + 1 end
            pop.list[#pop.list + 1] = { kind = kind, elite = elite or nil, threat = th }
        end
        return pop
    end

    -- ------------------------------------------------------------------------------------------ the whole floor as a graph (for the contract and the dumps)
    local function cid(ci, cj) return "c" .. ci .. "_" .. cj end

    function CG.plan(seed, fl, setting)
        local ctx = CG.new(seed, fl, setting)
        if not ctx then return nil end
        local P = ctx.P
        local plan = { ctx = ctx, P = P, W = P.W, H = P.H, cells = {}, order = {}, adj = {}, nodes = {}, edges = {}, stairs = {}, safe = {}, gates = {} }
        local function node(id, kind, ci, cj) if not plan.nodes[id] then plan.nodes[id] = { id = id, kind = kind, ci = ci, cj = cj }; plan.adj[id] = {} end return plan.nodes[id] end
        local function link(a, b, kind, extra)
            local e = { a = a, b = b, kind = kind }
            if extra then for k, v in pairs(extra) do e[k] = v end end
            plan.edges[#plan.edges + 1] = e
            plan.adj[a][#plan.adj[a] + 1] = { to = b, kind = kind, edge = e }
            plan.adj[b][#plan.adj[b] + 1] = { to = a, kind = kind, edge = e }
        end
        for cj = 0, P.H - 1 do for ci = 0, P.W - 1 do
            local info = CG.cell(ctx, ci, cj)
            plan.cells[cid(ci, cj)] = info
            plan.order[#plan.order + 1] = cid(ci, cj)
            node(cid(ci, cj), info.role, ci, cj)
        end end
        local aci, acj = CG.arrival(ctx)
        plan.arrival = cid(aci, acj)
        -- cell edges
        for cj = 0, P.H - 1 do for ci = 0, P.W - 1 do
            for _, d in ipairs({ "E", "S" }) do
                local k = CG.edge(ctx, ci, cj, d)
                if k then
                    local ni, nj = ci + DIRS[d][1], cj + DIRS[d][2]
                    local ra, rb = CG.role(ctx, ci, cj), CG.role(ctx, ni, nj)
                    local gate = (ra == "lair" or rb == "lair")
                    link(cid(ci, cj), cid(ni, nj), k, { dir = d, gate = gate or nil })
                    if gate then plan.gates[#plan.gates + 1] = plan.edges[#plan.edges] end
                end
            end
        end end
        -- arteries (grid floors): lines on the block borders, plazas at the crossings, a door from the cells that have one
        if P.kind == "grid" then
            for k = 0, P.BW do
                local prev = node("ap" .. k .. "_0", "plaza", nil, nil)
                for cj = 0, P.H - 1 do
                    local n = node("av" .. k .. "_" .. cj, "artery", nil, cj)
                    link(prev.id, n.id, "artery")
                    prev = n
                    if (cj + 1) % 8 == 0 then local pl = node("ap" .. k .. "_" .. ((cj + 1) // 8), "plaza"); link(prev.id, pl.id, "artery"); prev = pl end
                end
            end
            for m = 0, P.BH do
                local prev = node("ap0_" .. m, "plaza")
                for ci = 0, P.W - 1 do
                    local n = node("ah" .. m .. "_" .. ci, "artery", ci, nil)
                    link(prev.id, n.id, "artery")
                    prev = n
                    if (ci + 1) % 8 == 0 then local pl = node("ap" .. ((ci + 1) // 8) .. "_" .. m, "plaza"); link(prev.id, pl.id, "artery"); prev = pl end
                end
            end
            for cj = 0, P.H - 1 do for ci = 0, P.W - 1 do
                if ci % 8 == 0 and CG.artery_door(ctx, ci, cj, "W") then link(cid(ci, cj), "av" .. (ci // 8) .. "_" .. cj, "door", { side = "W" }) end
                if ci % 8 == 7 and CG.artery_door(ctx, ci, cj, "E") then link(cid(ci, cj), "av" .. ((ci + 1) // 8) .. "_" .. cj, "door", { side = "E" }) end
                if cj % 8 == 0 and CG.artery_door(ctx, ci, cj, "N") then link(cid(ci, cj), "ah" .. (cj // 8) .. "_" .. ci, "door", { side = "N" }) end
                if cj % 8 == 7 and CG.artery_door(ctx, ci, cj, "S") then link(cid(ci, cj), "ah" .. ((cj + 1) // 8) .. "_" .. ci, "door", { side = "S" }) end
            end end
        end
        -- the borough rings (the stairwell behind the boss gate), the free stairwells
        for bj = 0, (P.BH or 0) - 1 do for bi = 0, (P.BW or 0) - 1 do
            local b = CG.borough(ctx, bi, bj)
            if b then
                local id = "r" .. bi .. "_" .. bj
                node(id, "ring", b.ci, b.cj)
                link(cid(b.ci, b.cj), id, "gate", { gate = true })
                plan.gates[#plan.gates + 1] = plan.edges[#plan.edges]
                plan.stairs[#plan.stairs + 1] = id
            end
        end end
        for _, s in ipairs(CG.free_stairs(ctx)) do plan.stairs[#plan.stairs + 1] = cid(s[1], s[2]) end
        for _, id in ipairs(plan.order) do
            local r = plan.cells[id].role
            if r == "arrival" or r == "safe" or r == "guild" or r == "rest" then plan.safe[#plan.safe + 1] = id end
        end
        return plan
    end

    -- breadth-first distances from a set of start nodes; `skip(edge)` -> true to ignore an edge
    function CG.bfs(plan, starts, skip)
        local dist, queue = {}, {}
        for _, s in ipairs(starts) do dist[s] = 0; queue[#queue + 1] = s end
        local qh = 1
        while qh <= #queue do
            local u = queue[qh]; qh = qh + 1
            for _, a in ipairs(plan.adj[u]) do
                if not dist[a.to] and not (skip and skip(a.edge)) then dist[a.to] = dist[u] + 1; queue[#queue + 1] = a.to end
            end
        end
        return dist
    end

    -- ------------------------------------------------------------------------------------------ ASCII dumps
    local ROLE_CH = { arrival = "@", safe = "S", guild = "G", rest = "r", lair = "L", ante = "a", stairs = "$", prize = "P", borough = "B", village = "V", park = "K", room = ".", connector = "c" }
    -- c0, r0 .. c1, r1 (cells, inclusive): each cell 4 columns x 2 rows, walls drawn, openings: ' ' hall, ':' alley, '=' side hall, '#' artery door at the border
    function CG.ascii(plan, c0, r0, c1, r1)
        local ctx = plan.ctx
        local out = {}
        for cj = r0, r1 do
            local l1, l2 = {}, {}
            for ci = c0, c1 do
                local info = plan.cells[cid(ci, cj)]
                local n = info.open.N
                l1[#l1 + 1] = "+" .. ((n == "alley") and "::" or ((n == "artery") and "##" or ((n and n ~= "alley") and "  " or "--")))
                local w = info.open.W
                local ch = ROLE_CH[info.role] or "?"
                local th = info.theme and info.theme:sub(1, 1) or " "
                l2[#l2 + 1] = ((w == "alley") and ":" or ((w == "artery") and "#" or (w and "'" or "|"))):gsub("'", " ") .. ch .. ((info.role == "room" or info.role == "prize") and th or " ")
            end
            local e = plan.cells[cid(c1, cj)].open.E
            l1[#l1 + 1] = "+"
            l2[#l2 + 1] = (e == "alley") and ":" or ((e == "artery") and "#" or (e and " " or "|"))
            out[#out + 1] = table.concat(l1); out[#out + 1] = table.concat(l2)
        end
        local last = {}
        for ci = c0, c1 do
            local s = plan.cells[cid(ci, r1)].open.S
            last[#last + 1] = "+" .. ((s == "alley") and "::" or ((s == "artery") and "##" or ((s and s ~= "alley") and "  " or "--")))
        end
        last[#last + 1] = "+"
        out[#out + 1] = table.concat(last)
        return table.concat(out, "\n")
    end

    return CG
end

-- The hash adapter: the plan calls H(seed, floor * 1000 + salt, a, b, c) with integers; worldgen.hash takes (x, z, salt) and mixes the world's seed itself.
-- Fold without collisions over the real domain (every argument -8 .. 4087 after the offset, floor * 1000 + salt < 16384):
--   x = (a + 8) * 4096 + (b + 8)     z = (c + 8) * 4096 + (seed % 4096)     salt = floor * 1000 + salt
-- The run seed is the world seed (design M1 (a)): the engine adds it, `seed % 4096` only keeps the offline tests (plan_check over many seeds) apart.
function cellgen_hash_from(wh)
    return function(s, f, a, b, c)
        assert(a >= -8 and a < 4088 and b >= -8 and b < 4088 and c >= -8 and c < 4088 and f >= 0 and f < 16384, "cellgen hash argument out of range")
        return wh((a + 8) * 4096 + (b + 8), (c + 8) * 4096 + (s % 4096), f)
    end
end

Game = Game or {}
Game.gen = Game.gen or {}
local probe = cellgen_make()
Game.gen.cell = { make_cellgen = cellgen_make, hash_from = cellgen_hash_from, THEMES = probe.THEMES, THREAT = probe.THREAT, RADIUS = probe.RADIUS }
return Game.gen.cell
