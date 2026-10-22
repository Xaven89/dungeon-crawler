-- props: the engine's starter kit (prefabs, docs/PREFABS.md) used as set dressing, and one real prefab with logic: the janitor's closet door of the lobby (a pushable swing door on a hinge).
Game = Game or {}
local G = Game
local W, T = G.world, G.traps
local floor = math.floor

local function place(model, lx, ly, lz, rot, name, opts)
    -- minimum corner, local metres -> world voxels; tracked by the engine (a saved world adopts it instead of stamping again)
    return prefab.place("models/" .. model .. ".vxm", G.wx(lx), G.wy(ly), G.wz(lz), rot or 0, name, opts and opts.carve_air or false)
end

W.builders[#W.builders + 1] = function()
    -- the janitor's closet behind the lobby's north wall: 3 x 3 m, a bronze crate, a mop that is not a weapon
    G.room{ x = 20, z = -3.4, w = 4.4, d = 3.15, h = 3.6, floor = "flagstone", wall = "dungeon_brick", ceil = "dungeon_brick", wtex = "blocks" }
end

W.things[#W.things + 1] = function()
    -- the door: a manifest prefab (models/buildings/door.prefab.lua): a frame, a panel on a hinge, no plate, a real body that swings when pushed
    local ok, id, h = pcall(prefab.place, "buildings/door", G.wx(21), G.wy(0), G.wz(-0.25), { rotation = 0, name = "closet_door", params = { open = 90, plate = false }, carve_air = true })
    if not ok then print("closet door: " .. tostring(id))
    elseif type(h) == "table" and h.door then
        -- a plate on the lobby side (the kit's own plate sits behind the door for this rotation): step in front of it and it swings open, closing again after 2.5 s
        local plate = events.volume{ name = "closet_plate", box = { G.wx(20.6), G.wy(0), G.wz(0.1), G.wx(23.2), G.wy(1), G.wz(2.2) }, player = true, bodies = true, min_mass = 30 }
        events.connect(plate, "enter", h.door, "open")
        events.connect(plate, "exit", h.door, "close", { delay = 150 })
    end
    G.torch(22.2, 2.6, -1.5, { reach = 7, color = { 1, 0.75, 0.4 } })
    T.crate("lobby_closet", "bronze", 21, 0, -3.0, "+z")
    -- signs (the sign_board prefab writes its text into the model)
    pcall(prefab.place, "props/sign_board", G.wx(22), G.wy(0), G.wz(-0.2) - 6, { rotation = 0, name = "sign_closet", params = { text = "STAFF ONLY", material = "hazard_y", color = "", size = 1 } })
    -- clutter
    for _, c in ipairs({ { "props/crate", 31.5, 6 }, { "props/crate", 31.5, 6.9 }, { "props/barrel", 33.2, 19 }, { "props/barrel", 70.2, 19 }, { "props/crate", 70.5, 17.6 },
                         { "props/crate", 76.5, 1.6 }, { "props/barrel", 78.5, 1.8 }, { "props/crate", 120.6, 22.2 }, { "props/barrel", 114.6, 68.4 } }) do
        place(c[1], c[2], 0, c[3], 0, "clutter_" .. floor(c[2] * 10) .. "_" .. floor(c[3] * 10))
    end
    -- the stairwell's table and chairs
    place("props/table", 56.5, 0, 129.5, 0, "stair_table")
    place("props/chair", 57.2, 0, 128.2, 0, "stair_chair_a"); place("props/chair", 59.4, 0, 131.4, 8, "stair_chair_b")
    place("props/bench", 61.0, 0, 134.2, 0, "stair_bench")
    -- the grotto: giant mushrooms, rocks and boulders by hand (the chambers are carved by rule, this is the set dressing)
    local spots = { { 24, 80 }, { 31, 84 }, { 16, 68 }, { 21, 75 }, { 14, 62 }, { 20, 57 }, { 10, 92 }, { 17, 97 }, { 12, 99 }, { 22, 103 }, { 17, 108 }, { 25, 100 } }
    for i, p in ipairs(spots) do
        place(({ "nature/mushroom_big", "nature/rock", "nature/boulder_big", "nature/dead_shrub", "nature/cairn" })[1 + (i * 3) % 5], p[1] + 0.3, -0.1, p[2], 0, "grotto_prop_" .. i)
    end
end
