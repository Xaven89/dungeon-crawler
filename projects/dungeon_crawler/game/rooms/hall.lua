-- B: the Hall of Mild Peril. A tutorial: slimes and interns, a plate that releases a boulder, explosive barrels next to a suspiciously hollow wall, a secret passage to the Grotto.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.hall

W.builders[#W.builders + 1] = function()
    G.room{ x = R.x, z = R.z, w = R.w, d = R.d, h = R.h, floor = "flagstone", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "big_tiles", wtex = "blocks", ctex = "planks" }
    -- a long red runner with gold edges
    G.fill(30, 0, 8, 72, 0.06, 14, "carpet"); G.fill(30, 0, 7.8, 72, 0.06, 8, "gold"); G.fill(30, 0, 14, 72, 0.06, 14.2, "gold")
    -- ceiling beams
    for x = 32, 70, 4 do G.fill(x, 6.2, 2, x + 0.4, 7, 20, "dark_wood") end
    -- two rows of pillars make the alcoves
    for x = 36, 68, 8 do
        for _, z in ipairs({ 5.2, 16.8 }) do
            G.pillar(x, z, 0.6, 0, 6.2, "marble", "blocks"); G.pillar(x, z, 0.85, 0, 0.4, "dungeon_brick")
        end
    end
    -- the pressure plate (hazard stripes) and the warnings
    G.fill(49, -0.05, 10, 51, 0.04, 12, "hazard_y")
    G.text(33.5, 3.6, 2, "THE HALL OF MILD PERIL", { facing = "+z", material = "lantern", size = 2, depth = 1 })
    G.text(41.5, 2.4, 2, "PLEASE DO NOT STEP ON THE PLATE", { facing = "+z", material = "hazard_y", size = 1, depth = 1 })
    G.text(34, 2.6, 20, "EXPLOSIVES: HANDLE WITH IRRESPONSIBILITY", { facing = "-z", material = "neon_red", size = 1, depth = 1 })
    -- the boulder's hatch in the east wall (a dark recess, just so that it can be seen)
    G.fill(71.2, 0, 8.6, 72, 3.4, 13.4, "obsidian")
    W.openings[#W.openings + 1] = { 29.6, 0, 9, 30.4, 4.4, 13 }                    -- the lobby corridor meets the hall
    -- the corridor east to the Boiler Gallery
    G.corridor{ x = 72, z = 11, len = 4, w = 4, h = 4, axis = "x", floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    W.openings[#W.openings + 1] = { 71.6, 0, 9, 72.4, 4, 13 }; W.openings[#W.openings + 1] = { 75.6, 0, 9, 76.4, 4, 13 }
    -- the secret wall (speckled, hollow) with a passage behind it
    G.fill(36, 0, 20, 40, 3.5, 20.25, "dungeon_brick", "speckle")
    G.paint(36, 0, 20, 40, 3.5, 20.25, "dark_slate")
    G.corridor{ x = 38, z = 20.25, len = 25.75, w = 2.6, h = 3.4, axis = "z", floor = "flagstone", wall = "dungeon_brick" }
    G.room{ x = 34.5, z = 28, w = 7, d = 7, h = 4, floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    -- the closet's own walls cross the corridor: open them (a bug of the first version: the passage was sealed by the room's north and south skins)
    W.openings[#W.openings + 1] = { 36.6, 0, 27.6, 39.4, 3.4, 28.1 }; W.openings[#W.openings + 1] = { 36.6, 0, 34.9, 39.4, 3.4, 35.4 }
    G.corridor{ x = 20, z = 46, len = 18.25, w = 2.6, h = 3.4, axis = "x", floor = "flagstone", wall = "dungeon_brick" }
    G.corridor{ x = 20, z = 46, len = 10, w = 2.6, h = 3.4, axis = "z", floor = "flagstone", wall = "dungeon_brick" }
    -- the hall-end checkpoint: a crystal on a plinth (north-east corner)
    G.fill(69, 0, 3, 71, 0.8, 5, "marble", "blocks")
    G.sphere(70, 1.4, 4, 0.6, "rune")
end

W.things[#W.things + 1] = function()
    for _, x in ipairs({ 40, 48, 56, 64 }) do G.sconce(x, 3.0, 2, "+z"); G.sconce(x, 3.0, 20, "-z") end
    for x = 38, 70, 8 do G.lamp(x, 11, 7.0, 1.2, { reach = 12 }) end
    G.torch(70, 2.4, 4, { preset = "magic_sparks", color = { 0.7, 0.3, 1.0 }, reach = 9, name = "hall_crystal" })
    G.torch(36.5, 1.5, 31.5, { reach = 9 })
    emitter.create{ name = "hall_dust", preset = "dust_motes", pos = { G.mx(51), G.my(3.5), G.mz(11) }, size = { 18, 3, 7 } }
    -- the barrels beside the secret wall (explosive: swing at them, or fire)
    T.barrel(36.6, 0, 18.7); T.barrel(37.9, 0, 18.7); T.barrel(39.2, 0, 18.7); T.barrel(37.3, 0, 17.5); T.barrel(38.6, 0, 17.5)
    T.secret("hall_south", 38, 1.4, 20.1)
    -- crates: a bronze one in the west alcove and one by the crystal; a gold one in the closet behind the secret wall
    T.crate("hall_a", "bronze", 32.2, 0, 2.6, "+z")
    T.crate("hall_b", "bronze", 66, 0, 3.2, "+z")
    T.crate("hall_secret", "gold", 37.6, 0, 33.2, "-z")
    -- the plate: stepping on it starts a rumble; a second later the boulder comes out of the east wall
    local plate = events.volume{ name = "hall_plate", box = { G.wx(49), G.wy(0), G.wz(10), G.wx(51), G.wy(1), G.wz(12) }, player = true, bodies = false }
    W.hall_plate_fired = W.hall_plate_fired or false
    events.on(plate, "enter", function()
        if W.hall_plate_fired or G.state.cleared.hall_boulder then return end
        W.hall_plate_fired = true
        G.announcer.say_key("trap.plate", { prio = 1 })
        G.sfx.play("trap_click", 50, 0, 11)
        after(70, function()
            T.release_boulder(69.3, 1.7, 11, -1, 0, 24, 11)
            G.state.counters.boulder_ok = 1
            after(420, function() W.hall_plate_fired = false end)
        end)
    end)
    -- the secret wall's hint, when you stand in front of it
    local near = events.volume{ name = "hall_secret_hint", box = { G.wx(35), G.wy(0), G.wz(15), G.wx(41), G.wy(2), G.wz(19) }, player = true }
    events.on(near, "enter", function() if not T.secret_wall.opened then G.announcer.say_key("secret.wall", { prio = 0, key = "secret_hint", cooldown = 6000 }) end end)
    W.populate_list.hall = {
        { "slime", 35, 8 }, { "slime", 38, 13 },
        { "intern", 45, 4 }, { "intern", 45, 17 },
        { "rat", 54, 4 }, { "rat", 57, 18 }, { "rat", 60, 11 },
        { "goblin", 66, 8 }, { "goblin", 66, 14 },
    }
end
