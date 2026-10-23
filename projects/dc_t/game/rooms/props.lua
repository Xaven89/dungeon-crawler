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
    -- the closet door: a sliding portcullis-style slab (it goes up into the wall), open while anything stands in the doorway or on either side of it (the player, the goose, a crate), shut 2 s after
    -- the last one left; E opens it too. (The first version was the kit's swing door on a plate: one direction, and the goose blocked it.)
    if not G.state.flags.closet_door_v2 then
        for _, name in ipairs({ "closet_door", "sign_closet" }) do
            local old = prefab.find(name)
            if old and old ~= 0 then prefab.remove(old) end        -- (the first version's swing door, and its 4 m wide sign board that stood in the doorway)
        end
        G.clear(20.8, 0, -0.25, 23.4, 2.9, 0)                  -- the doorway
        G.clear(20.8, 2.9, -0.25, 23.4, 6.0, 0)                -- the slot above it that the slab slides into
        G.fill(20.6, 0, -0.25, 20.8, 3.1, 0, "metal"); G.fill(23.4, 0, -0.25, 23.6, 3.1, 0, "metal"); G.fill(20.6, 2.9, -0.25, 23.6, 3.1, 0, "metal")   -- the frame
        G.state.flags.closet_door_v2 = true
    end
    local slab = { G.wx(20.8), G.wy(0), G.wz(-0.25), G.wx(23.4) - 1, G.wy(2.9) - 1, G.wz(0) - 1 }
    local door = events.door{ name = "closet_slider", material = "dark_wood", box = slab, travel = { 0, 50, 0 }, speed = 2 }
    local plate = events.volume{ name = "closet_plate", box = { G.wx(20.2), G.wy(0), G.wz(-2.4), G.wx(24.0), G.wy(1.4), G.wz(2.4) }, player = true, bodies = true, min_mass = 3 }
    events.connect(plate, "enter", door, "open")
    events.connect(plate, "exit", door, "close", { delay = 120 })
    T.doors = T.doors or {}
    T.doors[#T.doors + 1] = { x = 22.1, z = 0, node = door, plate = plate }
    T.add_interact("closet_door", 22.1, 1.2, 0, "Open the door", 2.8, function() return events.state(door).open == false end)
    G.torch(22.2, 2.6, -1.5, { reach = 7, color = { 1, 0.75, 0.4 } })
    T.crate("lobby_closet", "bronze", 21, 0, -3.0, "+z")
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
