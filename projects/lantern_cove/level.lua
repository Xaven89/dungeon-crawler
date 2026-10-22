-- Lantern Cove. Edits are in voxels (1/16 m), gravity and bodies in metres. Local coordinates: x east, z south, y relative to the pad's ground (y = 0 is the first free voxel).
local V = units.vox
local SIZE = 800                      -- the pad is 50 m x 50 m
local ox, oz, gy = 0, 0, 0

local function B(x0, y0, z0, x1, y1, z1, m) edit.box(ox + x0, gy + y0, oz + z0, ox + x1, gy + y1, oz + z1, m) end
local function C(x0, y0, z0, x1, y1, z1) edit.clear(ox + x0, gy + y0, oz + z0, ox + x1, gy + y1, oz + z1) end

-- a lantern post: metal pole, a cap, a warm glowing lantern (y = first free voxel above the surface)
local function lantern(x, y, z)
    B(x - 1, y, z - 1, x + 1, y + 50, z + 1, "metal")
    B(x - 3, y + 51, z - 3, x + 3, y + 51, z + 3, "metal")
    B(x - 2, y + 52, z - 2, x + 2, y + 58, z + 2, "lantern")
    B(x - 3, y + 59, z - 3, x + 3, y + 59, z + 3, "metal")
    B(x - 1, y + 60, z - 1, x + 1, y + 61, z + 1, "metal")
end

-- the lantern posts: four on the quay, four on the pier, one by the house path (x, z of each; y = 1)
local function posts()
    local list = {}
    for _, z in ipairs({ 300, 400, 540, 640 }) do list[#list + 1] = { 336, z } end
    for _, x in ipairs({ 420, 500, 580, 660 }) do list[#list + 1] = { x, ((x // 80) % 2 == 0) and 450 or 490 } end
    list[#list + 1] = { 270, 160 }
    return list
end

local function find_site()
    local px, py, pz = player.pos()
    ox, oz = math.floor(V(px)) + V(-112), math.floor(V(pz)) + V(6)
    if project.first_run() then
        local hs = {}
        for i = 0, 4 do for j = 0, 4 do hs[#hs + 1] = world.top(ox + i * 200, oz + j * 200) end end
        table.sort(hs)
        gy = math.max(hs[13], V(26)) + 1          -- median height of the terrain under the pad, but above the sea
    else
        gy = world.top(ox + 400, oz + 760) + 1    -- the lawn of the saved pad
    end
end

local function build_land()
    B(0, -130, 0, SIZE, -5, SIZE, "stone")
    B(0, -4, 0, SIZE, -2, SIZE, "dirt")
    B(0, -1, 0, SIZE, -1, SIZE, "grass")
    C(0, 0, 0, SIZE, 170, SIZE)
    -- cliffs shelter the cove on the north, west and east
    local seed = 7
    local function rnd(a, b) seed = (seed * 1103515245 + 12345) % 2147483648; return a + (seed % 1000) / 1000 * (b - a) end
    for x = 0, SIZE, 60 do edit.sphere(ox + x, gy + 20, oz + rnd(-10, 30), rnd(60, 90), "stone") end
    for z = 60, SIZE, 60 do edit.sphere(ox + rnd(-10, 25), gy + 10, oz + z, rnd(55, 80), "stone") end
    for z = 60, 520, 60 do edit.sphere(ox + SIZE + rnd(-25, 10), gy + 5, oz + z, rnd(50, 75), "stone") end
    -- the sea side gets a low breakwater of stone
    B(60, -6, SIZE - 20, SIZE - 60, 14, SIZE, "stone")
    C(70, 0, 770, SIZE - 70, 40, SIZE)
    B(0, -1, 700, 60, -1, SIZE, "sand")
end

local function build_lake()
    local cx, cz, rx, rz = 520, 470, 240, 200
    for z = cz - rz, cz + rz, 4 do
        local t = 1 - ((z + 2 - cz) / rz) ^ 2
        if t > 0 then
            local hw = math.floor(rx * math.sqrt(t))
            C(cx - hw, -60, z, cx + hw, 0, z + 3)
            B(cx - hw, -62, z, cx + hw, -57, z + 3, "sand")
            B(cx - hw, -56, z, cx + hw, -8, z + 3, "water")
        end
    end
end

local function build_quay()
    B(262, -60, 270, 342, -1, 670, "stone")
    B(262, -1, 270, 342, -1, 670, "concrete")                      -- a paved top
    B(338, -1, 270, 342, 0, 670, "brick")                          -- a kerb along the water
    for z = 300, 660, 120 do B(262, -1, z, 342, -1, z + 3, "brick") end   -- expansion joints
    B(262, -1, 266, 342, -1, 270, "brick"); B(262, -1, 670, 342, -1, 674, "brick")
end

local function build_pier()
    local z0, z1 = 448, 492
    B(342, -3, z0, 690, -1, z1, "wood")                            -- deck
    for x = 360, 680, 80 do                                        -- piles down to the lake floor
        B(x, -56, z0, x + 3, -4, z0 + 3, "wood"); B(x, -56, z1 - 3, x + 3, -4, z1, "wood")
    end
    for x = 345, 685, 8 do B(x, -1, z0, x, -1, z1, "concrete") end   -- board gaps are too fiddly: a lighter plank line instead (concrete: moss does not grow on it)
    B(640, -3, 420, 710, -1, 520, "wood")                          -- the pier head
    B(342, 0, z0, 700, 0, z0, "wood"); B(342, 0, z1, 700, 0, z1, "wood")
end

local function build_house()
    local x0, z0, x1, z1, h = 60, 90, 220, 230, 56
    B(x0, 0, z0, x1, h - 1, z1, "stone")
    C(x0 + 6, 0, z0 + 6, x1 - 6, h - 1, z1 - 6)
    B(x0 + 6, -1, z0 + 6, x1 - 6, -1, z1 - 6, "wood")                -- a wooden floor
    local zc = (z0 + z1) // 2
    C(x1 - 6, 0, zc - 11, x1, 39, zc + 11)                          -- the door opening (east, towards the quay)
    B(x1 - 2, 40, zc - 13, x1, 42, zc + 13, "wood"); B(x1 - 2, 0, zc - 13, x1, 39, zc - 12, "wood"); B(x1 - 2, 0, zc + 12, x1, 39, zc + 13, "wood")
    B(x1, -1, zc - 20, x1 + 24, -1, zc + 20, "concrete")           -- the path to the quay
    B(x1 + 24, -1, zc - 20, 262, -1, zc + 20, "concrete")
    -- the lit window (south wall) with the lamp behind it, and a second dark one on the north wall
    B(110, 22, z1 - 6, 140, 40, z1, "glass")
    B(104, 20, z1 - 6, 146, 21, z1, "wood"); B(104, 41, z1 - 6, 146, 42, z1, "wood")
    B(122, 16, z1 - 16, 130, 17, z1 - 8, "wood"); B(124, 0, z1 - 14, 128, 15, z1 - 10, "wood")   -- a little table
    B(122, 18, z1 - 16, 130, 24, z1 - 9, "lantern")
    B(90, 22, z0, 110, 40, z0 + 6, "glass")
    B(138, h - 8, zc - 3, 146, h - 3, zc + 3, "lantern")           -- a ceiling lamp
    -- the gable roof of brick: the roof is hollow, the gable ends stay brick
    for k = 0, 39 do
        local a, b = z0 - 10 + 2 * k, z1 + 10 - 2 * k
        if a > b then break end
        B(x0 - 8, h + k, a, x1 + 8, h + k, b, "brick")
        C(x0 + 6, h + k, math.max(z0 + 6, a + 5), x1 - 6, h + k, math.min(z1 - 6, b - 5))
    end
end

function on_start()
    find_site()
    if project.first_run() then
        build_land(); build_lake(); build_quay(); build_pier(); build_house()
        for _, p in ipairs(posts()) do lantern(p[1], 1, p[2]) end
        -- trees and props from the asset kit
        for _, t in ipairs({ { 30, 40 }, { 380, 70 }, { 560, 40 }, { 700, 120 }, { 40, 330 }, { 70, 520 }, { 160, 640 }, { 720, 620 } }) do
            edit.model("models/tree_small.vxm", ox + t[1], gy, oz + t[2])
        end
        -- the forest and the undergrowth, by rule (docs/FOLIAGE.md): the planner reads the ground, so it runs a few ticks after the land was built. Oaks, birches and pines on the grass of the
        -- west and south meadows (not on the steep cliff feet, not in clearings), then bushes and rocks over the lawn; everything keeps off the buildings, the quay, the lake and the props
        local placedTrees, placedSmall = {}, {} -- the footprints of earlier tries: a retry only adds (what is placed twice would grow back after the player chopped it)
        local function plant(tries)
            local keep = {
                { ox + 50, oz + 80, ox + 245, oz + 255 },      -- the house and its path
                { ox + 245, oz + 255, ox + 350, oz + 690 },    -- the quay
                { ox + 120, oz + 400, ox + 255, oz + 500 },    -- the glade ring, the doors and the switch
                { ox + 345, oz + 255, ox + 790, oz + 690 },    -- the lake and the pier (water is no ground anyway: this keeps the bank clear)
            }
            for _, t in ipairs({ { 30, 40 }, { 380, 70 }, { 560, 40 }, { 700, 120 }, { 40, 330 }, { 70, 520 }, { 160, 640 }, { 720, 620 } }) do keep[#keep + 1] = { ox + t[1] - 30, oz + t[2] - 30, ox + t[1] + 30, oz + t[2] + 30 } end
            local avoidTrees = {}
            for _, b in ipairs(keep) do avoidTrees[#avoidTrees + 1] = b end
            for _, b in ipairs(placedTrees) do avoidTrees[#avoidTrees + 1] = b end
            local trees, f1, s1 = scatter{ models = { { "models/oak.vxm", 4 }, { "models/birch.vxm", 3 }, { "models/pine.vxm", 3 } }, box = { ox + 10, oz + 260, ox + 340, oz + 790 }, spacing = 64, density = 0.55, seed = 11,
                                           on = { "grass" }, slope_max = 0.7, avoid = avoidTrees, clearings = { scale = 260, threshold = 0.3 } }
            for _, b in ipairs(f1) do placedTrees[#placedTrees + 1] = b end
            local avoidSmall = {}
            for _, b in ipairs(keep) do avoidSmall[#avoidSmall + 1] = b end
            for _, b in ipairs(placedTrees) do avoidSmall[#avoidSmall + 1] = b end
            for _, b in ipairs(placedSmall) do avoidSmall[#avoidSmall + 1] = b end
            local small, f2, s2 = scatter{ models = { { "models/bush.vxm", 3 }, { "models/rock.vxm", 1 } }, box = { ox + 10, oz + 10, ox + 790, oz + 790 }, spacing = 40, density = 0.3, seed = 12,
                                           on = { "grass" }, slope_max = 0.5, avoid = avoidSmall }
            for _, b in ipairs(f2) do placedSmall[#placedSmall + 1] = b end
            -- columns that are not loaded yet (the world streams in over the first seconds) place nothing: the same rule runs again until none are left (columns with no ground at all do not count)
            if (s1.unloaded > 0 or s2.unloaded > 0) and tries < 40 then after(30, function() plant(tries + 1) end)
            else print("Lantern Cove: " .. #placedTrees .. " trees, " .. #placedSmall .. " bushes and rocks") end
        end
        after(6, function() plant(0) end)
        edit.model("models/bench.vxm", ox + 270, gy, oz + 360, 0)
        edit.model("models/bench.vxm", ox + 270, gy, oz + 590, 0)
        edit.model("models/lantern_post.vxm", ox + 240, gy, oz + 90)
        -- the marker of the low gravity glade: a sand ring
        for a = 0, 355, 5 do
            local r = math.rad(a)
            B(math.floor(150 + 76 * math.cos(r)), -1, math.floor(430 + 76 * math.sin(r)), math.floor(150 + 76 * math.cos(r)) + 3, 0, math.floor(430 + 76 * math.sin(r)) + 3, "sand")
        end
        -- the lantern switch: a metal plate on a stone plinth east of the spot where you start (look at it, press E)
        B(246, 0, 451, 255, 13, 458, "stone")
        B(248, 14, 453, 253, 17, 456, "metal")
        -- the house door: a wooden slab in the doorway that swings into the house about its north edge; the plate in front of it is on the concrete path
        local zc = (90 + 230) // 2
        B(216, 0, zc - 11, 218, 39, zc + 11, "wood")
    end
    -- everything that is not a voxel, on every run:
    -- the lanterns are lamps: the switch lights and puts out all of them (they start lit)
    local lamps = {}
    for i, p in ipairs(posts()) do
        lamps[#lamps + 1] = events.lamp { name = "lantern_" .. i, lit = true, on = "lantern", off = "lantern_off",
                                         box = { ox + p[1] - 2, gy + 1 + 52, oz + p[2] - 2, ox + p[1] + 2, gy + 1 + 58, oz + p[2] + 2 } }
    end
    local switch = events.button { name = "lantern_switch", prompt = tr("switch_lanterns"), on = "neon", off = "metal", press_ticks = 12,
                                   box = { ox + 248, gy + 14, oz + 453, ox + 253, gy + 17, oz + 456 } }
    for _, l in ipairs(lamps) do events.connect(switch, "pressed", l, "toggle") end
    local zc = (90 + 230) // 2
    local door = events.door { name = "house_door", material = "wood",
                               box = { ox + 216, gy + 0, oz + zc - 11, ox + 218, gy + 39, oz + zc + 11 },
                               hinge = { axis = "y", at = { ox + 216, gy + 0, oz + zc - 11 }, open = -90, seconds = 1.0 } }
    local plate = events.volume { name = "house_plate", box = { ox + 236, gy, oz + zc - 18, ox + 256, gy + 8, oz + zc + 18 }, player = true, bodies = true, min_mass = 30 }
    events.connect(plate, "enter", door, "open")
    events.connect(plate, "exit", door, "close", { delay = 90 })
    -- a door from the prefab kit (models/door.prefab.lua) on the lawn by the lantern switch: step on its plate and the panel swings open
    prefab.place("door", ox + 186, gy, oz + 452, { name = "lawn_door", params = { open = -90 } })
    -- and a pushable one: a real body on a hinge, walk against it; friction holds it where it is left; a spring would make it fall shut (a saloon door: spring_k = 80, two_way = true)
    prefab.place("door", ox + 150, gy, oz + 452, { name = "push_door", params = { open = 90, plate = false, dynamic = true, friction = 6 } })
    -- (the glade, the crates and the teleport are not voxels either:)
    -- the moon glade: low gravity in a box over the sand ring
    glade = gravity.add { type = "uniform", name = "moon glade", dir = { 0, -1, 0 }, strength = 1.8, priority = 20,
                          pos = { units.m(ox + 150), units.m(gy) + 3, units.m(oz + 430) }, half = { 4.5, 4, 4.5 } }
    for i = 0, 2 do body.box(units.m(ox + 130 + i * 24), units.m(gy) + 1.5 + i * 0.8, units.m(oz + 430), 16, 16, 16, "wood") end
    -- a stack of crates on the quay to knock over (body.push(stack[6], -40, 10, 0) topples it)
    stack = {}
    for row = 0, 2 do
        for i = 0, 2 - row do
            stack[#stack + 1] = body.box(units.m(ox + 292 + i * 17 + row * 8), units.m(gy) + 0.55 + row * 1.0, units.m(oz + 500), 16, 16, 16, "wood")
        end
    end
    -- a little truck on the plaza, about 8 m north of the start: walk up to it and press E to get in, W / S drive, A / D steer (docs/VEHICLES.md)
    vehicle.spawn { x = units.m(ox + 285), y = units.m(gy) + 1.3, z = units.m(oz + 345), heading = 0, cab_material = "glass" }
    -- a resident of the cove: walks around the lawn by itself (docs/AGENTS.md); it comes over when you stand still near it and walks off again
    resident = agent.spawn { x = units.m(ox + 270), y = units.m(gy) + 0.1, z = units.m(oz + 570), speed = 1.3, model = "models/walker.vxm" }
    agent.wander(resident, 3.5)
    player.teleport(units.m(ox + 230), units.m(gy) + 0.2, units.m(oz + 470))
    project.store("visits", project.fetch("visits", 0) + 1) -- (the script's store is saved with the world: how many times the cove was entered)
    print("Lantern Cove pad at " .. ox .. ", " .. gy .. ", " .. oz)
end

function on_agent(id, what) -- an agent finished an order: "arrived", "stuck", "no_path" or "fell"
    if what ~= "arrived" then print("resident " .. id .. ": " .. what) end
end

-- the HUD (docs/HUD.md): drawn every frame over the picture, reads the world, never changes it
function on_hud(dt)
    local w, h = ui.size()
    local x, y, z = player.pos()
    ui.image(w - 100, 16, 80, 80, "images/lantern.svg") -- a vector picture of the project: it stays sharp at any size (docs/HUD.md ui.image)
    ui.text(28, 22, tr("title"), { size = 30 })
    ui.text(28, 60, tr("position", string.format("%.0f", x), string.format("%.0f", z), string.format("%.0f", y)), { size = 20, color = "#c8d8e8" })
    ui.text(28, 86, tr("visit", project.fetch("visits", 1)), { size = 18, color = "#8aa0b4" })
end
