-- C: the Boiler Gallery. A lava channel splits the hall; the drawbridge is raised until somebody pulls the lever on the west bank. Goblins, spitters across the water, hot pipes.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.boiler

W.builders[#W.builders + 1] = function()
    G.room{ x = R.x, z = R.z, w = R.w, d = R.d, h = R.h, floor = "scorched_stone", wall = "soot_brick", ceil = "ceiling_dark" }
    -- the lava channel, x 90..96, down to -3 m, lined with obsidian
    G.clear(90, -3, 0, 96, 0, 26)
    G.fill(89.75, -3, 0, 90, 0, 26, "obsidian"); G.fill(96, -3, 0, 96.25, 0, 26, "obsidian"); G.fill(90, -3.3, 0, 96, -3, 26, "obsidian")
    G.fill(90, -3, 0, 96, -0.45, 26, "lava")
    -- ceiling beams and big pipes
    for x = 78, 110, 4 do G.fill(x, 9.0, 0, x + 0.5, 10, 26, "dark_wood") end
    G.fill(76, 8.2, 1.2, 112, 8.9, 1.9, "metal"); G.fill(76, 7.0, 24.2, 112, 7.7, 24.9, "metal")
    for _, x in ipairs({ 82, 100, 108 }) do G.fill(x, 0, 1.2, x + 0.6, 8.2, 1.9, "metal") end
    -- boilers: tanks along the north wall, with glowing gauges
    for _, x in ipairs({ 80, 86, 100, 106 }) do
        G.pillar(x, 3.4, 1.7, 0, 6.5, "metal", "stripes"); G.pillar(x, 3.4, 1.2, 6.5, 7.4, "metal")
        G.fill(x - 0.3, 3.2, 5.0, x + 0.3, 3.8, 5.15, "lantern")        -- the gauge
        G.fill(x - 0.9, 1.6, 5.0, x - 0.6, 2.0, 5.15, "neon_red")
    end
    -- railings along the channel (open at the drawbridge)
    for z = 0.5, 25.5, 1.0 do
        if z < 10 or z > 14 then
            G.fill(89.2, 0, z, 89.35, 0.9, z + 0.15, "metal"); G.fill(96.65, 0, z, 96.8, 0.9, z + 0.15, "metal")
        end
    end
    G.fill(89.2, 0.8, 0, 89.35, 0.9, 10, "metal"); G.fill(89.2, 0.8, 14, 89.35, 0.9, 26, "metal")
    G.fill(96.65, 0.8, 0, 96.8, 0.9, 10, "metal"); G.fill(96.65, 0.8, 14, 96.8, 0.9, 26, "metal")
    -- the lever plinth on the west bank
    G.fill(86.6, 0, 8.2, 88.2, 0.9, 9.8, "marble", "blocks")
    G.fill(87.2, 0.9, 8.8, 87.6, 1.5, 9.2, "metal")
    -- the exit to the Conveyor, east wall
    G.corridor{ x = 112, z = 22, len = 2, w = 4, h = 4, axis = "x", floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    W.openings[#W.openings + 1] = { 111.6, 0, 20, 112.4, 4, 24 }
    W.openings[#W.openings + 1] = { 113.6, 0, 20, 114.4, 4, 24 }
    G.text(79, 6.6, 26, "BOILER GALLERY - MIND THE LAVA", { facing = "-z", material = "hazard_y", size = 1, depth = 1 })
end

W.things[#W.things + 1] = function()
    for _, x in ipairs({ 80, 106 }) do G.brazier(x, 12, { reach = 12 }) end
    for _, z in ipairs({ 6, 20 }) do G.sconce(76, 3.4, z, "+x"); G.sconce(112, 3.4, z - 4, "-x") end
    G.torch(93, 0.2, 5, { preset = "campfire", color = { 1, 0.35, 0.1 }, reach = 18, name = "lava_glow_1" })
    G.torch(93, 0.2, 20, { preset = "campfire", color = { 1, 0.35, 0.1 }, reach = 18, name = "lava_glow_2" })
    emitter.create{ name = "boiler_steam_1", preset = "steam_vent", pos = { G.mx(84), G.my(0.2), G.mz(22) } }
    emitter.create{ name = "boiler_steam_2", preset = "steam_vent", pos = { G.mx(104), G.my(0.2), G.mz(22) } }
    emitter.create(G.embers{ name = "boiler_embers", preset = "embers", pos = { G.mx(93), G.my(0.4), G.mz(13) }, size = { 3, 0.5, 12 } })
    T.hazard("lava", 90, -3.4, 0, 96, 0.35, 26, 28)
    G.sfx.bed("boiler", "boiler:lava", "lava_bed", 93, 0, 13)
    -- the drawbridge: a vertical slab on the west bank, lowered by the lever
    local bridge = events.door{ name = "drawbridge", material = "metal", box = { G.wx(90), G.wy(0), G.wz(10.8), G.wx(90) + 3, G.wy(0) + 94, G.wz(13.2) - 1 },
                                hinge = { axis = "z", at = { G.wx(90), G.wy(0), G.wz(10.8) }, open = -90, seconds = 2.2 }, sound = false }
    G.sfx.watch_door("boiler:drawbridge", bridge, 90, 12)
    local lever = events.lever{ name = "drawbridge_lever", box = { G.wx(87.2), G.wy(0.9), G.wz(8.8), G.wx(87.6) - 1, G.wy(1.5), G.wz(9.2) - 1 }, prompt = "Lower the drawbridge", on = "neon", off = "metal" }
    events.connect(lever, "on", bridge, "open")
    events.connect(lever, "off", bridge, "close")
    T.add_interact("drawbridge_lever", 87.4, 1.1, 9.0, "Pull the lever (the drawbridge)", 2.4)
    events.on(lever, "on", function() G.announcer.say_key("trap.bridge", { prio = 1, key = "bridge", cooldown = 6000 }); G.sfx.play("lever", 87.4, 1, 9) end)
    T.crate("boiler_a", "silver", 107.5, 0, 22, "-x")
    T.crate("boiler_b", "bronze", 79.5, 0, 22.5, "+z")
    W.populate_list.boiler = {
        { "goblin", 82, 6 }, { "goblin", 82, 19 }, { "goblin", 80, 13 },
        { "goblin", 102, 6 }, { "goblin", 100, 20 }, { "spitter", 103, 11 }, { "spitter", 106, 17 },
        { "slime_toxic", 100, 3 }, { "slime_toxic", 99, 23 },
    }
end
