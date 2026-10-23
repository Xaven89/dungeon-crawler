-- F: the Zero-G Ballroom. Gravity is switched off over the dance floor; a lever on the wall flips it. Floating loot, goblin dancers, an orchestra of interns.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.ballroom
W.gravity = {}

W.builders[#W.builders + 1] = function()
    G.room{ x = R.x, z = R.z, w = R.w, d = R.d, h = R.h, floor = "marble", wall = "dungeon_brick", ceil = "dungeon_brick", wtex = "blocks", ctex = "planks" }
    -- the dance floor: 2 m tiles, marble and obsidian, a gold ring in the middle
    for ix = 0, 18 do
        for iz = 0, 15 do
            if (ix + iz) % 2 == 0 then G.fill(38 + ix * 2, -0.5, 66 + iz * 2, 40 + ix * 2, 0, 68 + iz * 2, "obsidian", "tiles") end
        end
    end
    -- the stage on the north wall, curtains of carpet
    G.fill(44, 0, 66, 70, 1.0, 70.4, "dark_wood", "planks"); G.fill(44, 1.0, 66, 70, 1.08, 70.4, "carpet")
    G.fill(44, 1.0, 66, 49, 11, 66.5, "carpet"); G.fill(65, 1.0, 66, 70, 11, 66.5, "carpet"); G.fill(44, 9.5, 66, 70, 11, 66.8, "carpet")
    G.text(47, 8.2, 66.8, "SEASON 7 BALL", { facing = "+z", material = "gold", size = 2, depth = 1 })
    -- stained windows along both long walls: a niche with a glowing back and glass in front
    for i, x in ipairs({ 42, 48, 54, 60, 66, 72 }) do
        local back = ({ "lantern", "rune", "neon", "lantern", "rune", "neon" })[i]
        G.fill(x, 3, 97.5, x + 2, 9, 98, back); G.clear(x, 3, 98, x + 2, 9, 98.5); G.fill(x - 0.1, 2.9, 97.8, x + 2.1, 3, 98, "gold"); G.fill(x - 0.1, 9, 97.8, x + 2.1, 9.1, 98, "gold")
    end
    -- chandeliers: a chain from the ceiling and a ring of lanterns
    for _, p in ipairs({ { 50, 76 }, { 57, 82 }, { 64, 76 }, { 50, 90 }, { 64, 90 } }) do
        G.fill(p[1] - 0.08, 9.0, p[2] - 0.08, p[1] + 0.08, 12, p[2] + 0.08, "metal")
        G.fill(p[1] - 0.7, 8.8, p[2] - 0.7, p[1] + 0.7, 9.0, p[2] + 0.7, "gold")
        for _, d in ipairs({ { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do G.fill(p[1] + d[1] - 0.1, 9.0, p[2] + d[2] - 0.1, p[1] + d[1] + 0.1, 9.45, p[2] + d[2] + 0.1, "lantern") end
    end
    -- the ceiling vent (the shortcut): a hole in the ceiling over the dance floor, a service tunnel above the ceiling that runs south, steps down and joins the arena's own tunnel, skipping the Grotto
    G.clear(61.2, 12, 81.2, 62.8, 12.4, 82.8)
    G.fill(61.0, 11.9, 81.0, 61.2, 12.0, 83.0, "gold"); G.fill(62.8, 11.9, 81.0, 63.0, 12.0, 83.0, "gold"); G.fill(61.2, 11.9, 81.0, 62.8, 12.0, 81.2, "gold"); G.fill(61.2, 11.9, 82.8, 62.8, 12.0, 83.0, "gold")
    G.clear(60.6, 12.4, 80.2, 63.4, 15.0, 100.5)
    G.fill(60.4, 12.4, 80.0, 60.6, 15.2, 100.5, "dungeon_brick"); G.fill(63.4, 12.4, 80.0, 63.6, 15.2, 100.5, "dungeon_brick"); G.fill(60.4, 15.0, 80.0, 63.6, 15.2, 100.5, "dungeon_brick")
    G.fill(60.6, 12.4, 80.0, 63.4, 15.0, 80.2, "dungeon_brick")
    for k = 0, 31 do   -- the steps down (0.4 m each way)
        local top = 12.4 - 0.4 * (k + 1)
        G.clear(60.6, top, 100 + 0.4 * k, 63.4, top + 3.0, 100.4 + 0.4 * k + 0.8)
    end
    G.corridor{ x = 29.5, z = 112.6, len = 33.5, w = 3, h = 3.2, axis = "x", floor = "flagstone", wall = "dungeon_brick" }
    W.openings[#W.openings + 1] = { 29.3, 0, 111.4, 30.1, 3.2, 113.8 }               -- into the arena's own tunnel
    G.text(60.8, 13.2, 80.2, "SERVICE TUNNEL", { facing = "+z", material = "hazard_y", size = 1, depth = 1 })
    -- the lever plinth (south wall, west side)
    G.fill(41.2, 0, 94.6, 42.8, 0.9, 96.2, "marble", "blocks"); G.fill(41.8, 0.9, 95.2, 42.2, 1.5, 95.6, "metal")
    -- the doors: east to the Gutter, west to the Grotto
    W.openings[#W.openings + 1] = { 75.6, 0, 80, 76.4, 4.2, 84 }
    G.corridor{ x = 34, z = 82, len = 4, w = 4, h = 4.2, axis = "x", floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    W.openings[#W.openings + 1] = { 37.6, 0, 80, 38.4, 4.2, 84 }
end

W.things[#W.things + 1] = function()
    -- the gravity: nothing over the middle of the floor; a field that points up, switched on by the lever
    local null = gravity.add{ type = "null", name = "ballroom_zero_g", pos = { G.mx(57), G.my(6.2), G.mz(82) }, half = { 9.5, 6, 9.5 }, priority = 10 }
    -- the flip field reaches up into the first metres of the service tunnel (y to 15.4), so that whoever falls up through the vent keeps falling up until he is under the tunnel's roof
    local flip = gravity.add{ type = "uniform", name = "ballroom_flip", dir = { 0, 1, 0 }, strength = 9.81, priority = 20, pos = { G.mx(57), G.my(7.7), G.mz(82) }, half = { 9.5, 7.7, 9.5 }, enabled = false }
    W.gravity.null, W.gravity.flip = null, flip
    local target = events.gravity_target{ name = "ballroom_flip_target", field = flip, presets = { { { 0, 1, 0 }, 9.81 } } }
    local lever = events.lever{ name = "ballroom_lever", box = { G.wx(41.8), G.wy(0.9), G.wz(95.2), G.wx(42.2) - 1, G.wy(1.5), G.wz(95.6) - 1 }, prompt = "Flip gravity", on = "neon", off = "metal" }
    events.connect(lever, "on", target, "enable"); events.connect(lever, "off", target, "disable")
    events.on(lever, "on", function() G.announcer.say_key("trap.gravity", { prio = 1, key = "grav", cooldown = 3000 }); G.sfx.play("lever", 42, 1, 95.4) end)
    T.add_interact("ballroom_lever", 42, 1.2, 95.4, "Flip gravity (the lever)", 2.4)
    -- light: the windows, chandeliers and a few braziers
    for _, p in ipairs({ { 50, 76 }, { 57, 82 }, { 64, 76 }, { 50, 90 }, { 64, 90 } }) do G.torch(p[1], 8.3, p[2], { color = { 1, 0.8, 0.45 }, reach = 14, preset = "fireflies", name = "chandelier_" .. p[1] .. "_" .. p[2] }) end
    G.brazier(40, 68, { reach = 12 }); G.brazier(74, 68, { reach = 12 }); G.brazier(74, 96, { reach = 12 })
    emitter.create{ name = "ballroom_dust", preset = "magic_sparks", pos = { G.mx(57), G.my(6), G.mz(82) }, size = { 8, 5, 8 } }
    T.crate("ballroom_a", "silver", 71, 1.08, 68, "-z")
    G.torch(62, 13.6, 84, { reach = 8 }); G.torch(62, 1.2, 111, { reach = 8 }); G.torch(45, 1.8, 112.2, { reach = 9 })
    W.zones[#W.zones + 1] = { id = "vent", y0 = 11.5, x0 = 60.5, z0 = 80, x1 = 63.5, z1 = 100, on_enter = function() G.announcer.award("fine_print"); G.announcer.say_key("room.secret", { prio = 1 }) end }
    -- loot floating in the weightless air
    T.floating("ballroom_orb1", 52, 5.5, 79, "item", "sushi")
    T.floating("ballroom_orb2", 62, 8.5, 87, "item", "gem")
    T.floating("ballroom_orb3", 57, 10.8, 82, "item", "trophy")
    W.populate_list.ballroom = {
        { "goblin", 44, 76 }, { "goblin", 70, 78 }, { "goblin", 52, 94 }, { "goblin", 66, 94 },
        { "spitter", 56, 69, 1.0 }, { "spitter", 60, 69, 1.0 },
        { "intern", 48, 68, 1.0 }, { "intern", 66, 68, 1.0 }, { "intern", 57, 68, 1.0 },
    }
end
