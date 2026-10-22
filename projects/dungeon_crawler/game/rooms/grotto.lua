-- G: the Mushroom Grotto. Carved by script from a list of chambers and tubes (edit.carve: the noisy bite of an explosion), with a flat floor put back, stalactites, giant glowing mushrooms, pools,
-- fireflies. The Goblin Foreman's cave is at the south end; the secret passage from the Hall arrives at the north end.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.grotto
local floor = math.floor

-- chambers: x, z, r (metres); the centre is r * 0.5 above the floor
local chambers = {
    A = { 28, 82, 7 }, B = { 18, 72, 7 }, C = { 18, 60, 6.5 }, D = { 14, 94, 8 }, E = { 20, 104, 8 },
}
local tubes = {     -- polylines of tube centres (r = 2.7)
    { { 28, 82 }, { 23, 77 }, { 18, 72 } },
    { { 18, 72 }, { 18, 66 }, { 18, 60 } },
    { { 18, 72 }, { 16, 80 }, { 14, 88 }, { 14, 94 } },
    { { 14, 94 }, { 17, 99 }, { 20, 104 } },
    { { 20, 104 }, { 24, 109 }, { 28, 113 } },
}

local function carve_ball(x, z, r, seed)
    local vr = G.vox(r)
    edit.carve(G.wx(x), G.wy(r * 0.5), G.wz(z), vr, 0.22, seed)
end

local function refill(x, z, r)
    local m = r * 1.08
    G.fill(x - m, -r * 0.6, z - m, x + m, 0, z + m, "cavestone")
    G.fill(x - m, -0.45, z - m, x + m, -0.02, z + m, "dirt")
end

local function stalactite(x, ytop, z, len)
    local steps = floor(len * 6)
    for k = 0, steps do
        local hw = math.max(0.04, 0.3 * (1 - k / (steps + 1)))
        G.fill(x - hw, ytop - k / 6, z - hw, x + hw, ytop - (k - 1) / 6, z + hw, "cavestone")
    end
end

local function mushroom(x, z, h, r, mat)
    G.pillar(x, z, 0.16 + r * 0.06, 0, h, "bone")
    G.sphere(x, h, z, r, mat or "glowcap")
    G.fill(x - r * 0.5, h - r - 0.12, z - r * 0.5, x + r * 0.5, h - r * 0.4, z + r * 0.5, "bone")          -- the gills under the cap
end

W.builders[#W.builders + 1] = function()
    G.seed(77)
    local seed = 100
    for id, c in pairs(chambers) do seed = seed + 17; carve_ball(c[1], c[2], c[3], seed) end
    for _, line in ipairs(tubes) do
        for i = 1, #line - 1 do
            local a, b = line[i], line[i + 1]
            local n = math.ceil(G.dist2(a[1], a[2], b[1], b[2]) / 1.4)
            for k = 0, n do
                local f = k / n
                seed = seed + 3
                carve_ball(a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, 2.7, seed)
            end
        end
    end
    for id, c in pairs(chambers) do refill(c[1], c[2], c[3]) end
    for _, line in ipairs(tubes) do for i = 1, #line - 1 do
        local a, b = line[i], line[i + 1]
        local n = math.ceil(G.dist2(a[1], a[2], b[1], b[2]) / 1.4)
        for k = 0, n do local f = k / n; refill(a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, 2.7) end
    end end
    -- openings: the ballroom corridor, the secret tunnel, the arena corridor
    W.openings[#W.openings + 1] = { 33.0, 0, 80, 35, 4.2, 84 }
    G.corridor{ x = 28, z = 112, len = 3, w = 3, h = 3.6, axis = "z", floor = "flagstone", wall = "dungeon_brick" }
    -- decoration, chamber by chamber
    for id, c in pairs(chambers) do
        local cx, cz, r = c[1], c[2], c[3]
        -- stalactites hang from the ceiling of the sphere (the tops start inside the rock)
        for i = 1, floor(r * 1.4) do
            local a, d = G.rand() * 6.283, G.rand() * (r * 0.7)
            local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
            local ceil = r * 0.5 + math.sqrt(math.max(0, r * r - d * d)) * 0.92
            if ceil < 13 then stalactite(x, ceil + 0.5, z, G.range(0.6, 1.9)) end
        end
        -- stalagmites and mushrooms on the floor
        for i = 1, floor(r) do
            local a, d = G.rand() * 6.283, G.range(r * 0.15, r * 0.75)
            local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
            if i % 3 == 0 then mushroom(x, z, G.range(0.8, 2.6), G.range(0.5, 1.1), (i % 2 == 0) and "glowcap" or "rune") 
            else for k = 0, 4 do G.fill(x - 0.25 + k * 0.045, k * 0.2, z - 0.25 + k * 0.045, x + 0.25 - k * 0.045, k * 0.2 + 0.2, z + 0.25 - k * 0.045, "cavestone") end end
        end
        -- glow cap clumps
        for i = 1, floor(r * 1.5) do
            local a, d = G.rand() * 6.283, G.range(r * 0.2, r * 0.8)
            local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
            G.fill(x, 0, z, x + 0.12, 0.12, z + 0.12, (i % 3 == 0) and "rune" or "glowcap")
            G.fill(x + 0.1, 0, z + 0.05, x + 0.2, 0.09, z + 0.15, "glowcap")
        end
    end
    -- two little pools: a dip in the floor with water
    for _, p in ipairs({ { 11, 91, 2.2 }, { 21, 68, 1.8 } }) do
        local cx, cz, r = p[1], p[2], p[3]
        local R_ = G.vox(r)
        for dz = -R_, R_ do
            local w = floor(math.sqrt(R_ * R_ - dz * dz) + 0.5)
            edit.box(G.wx(cx) - w, G.wy(-0.5), G.wz(cz) + dz, G.wx(cx) + w, G.wy(-0.05), G.wz(cz) + dz, "water")
        end
    end
    G.text(26.5, 3.3, 112, "THE FOREMAN IS IN", { facing = "+z", material = "hazard_y", size = 1, depth = 1 })
end

W.things[#W.things + 1] = function()
    for id, c in pairs(chambers) do
        emitter.create{ name = "grotto_flies_" .. id, preset = "fireflies", pos = { G.mx(c[1]), G.my(1.8), G.mz(c[2]) }, size = { c[3] * 0.6, 1.2, c[3] * 0.6 },
                        light = { color = { 0.6, 1.0, 0.7 }, reach = 12, flicker = true } }
        emitter.create{ name = "grotto_spores_" .. id, preset = "dust_motes", pos = { G.mx(c[1]), G.my(3), G.mz(c[2]) }, size = { c[3] * 0.7, 2.5, c[3] * 0.7 } }
    end
    G.torch(33, 1.6, 82, { reach = 9, color = { 1, 0.6, 0.3 } })
    G.torch(28, 1.6, 111, { reach = 9, color = { 1, 0.5, 0.2 } })
    -- the foreman's cave: a campfire he stole from the Lobby
    G.torch(20, 0.8, 104, { preset = "campfire", reach = 14, color = { 1, 0.5, 0.15 }, name = "foreman_fire" })
    T.crate("grotto_a", "silver", 16.5, 0, 59.5, "+z")
    T.crate("grotto_b", "bronze", 8, 0, 96, "+x")
    T.crate("grotto_foreman", "silver", 15, 0, 108, "+x")
    W.populate_list.grotto = {
        { "rat", 26, 80 }, { "rat", 30, 85 }, { "rat", 24, 84 }, { "spitter", 25, 78 },
        { "slime", 19, 70 }, { "slime", 16, 74 }, { "slime", 21, 74 }, { "spitter", 15, 70 }, { "spitter", 20, 72 },
        { "rat", 16, 61 }, { "rat", 20, 58 },
        { "goblin", 12, 91 }, { "goblin", 16, 96 }, { "goblin", 10, 96 }, { "spitter", 16, 92 }, { "slime_toxic", 12, 98 }, { "slime_toxic", 17, 90 },
        { "foreman", 20, 105 }, { "goblin", 17, 103 }, { "goblin", 23, 107 },
    }
end
