-- D: the Conveyor of Consequences. A sushi belt that carries everything towards a furnace; ledges on both sides, a lever to stop it, crates that ride it to their doom.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.conveyor

W.builders[#W.builders + 1] = function()
    G.room{ x = R.x, z = R.z, w = R.w, d = R.d, h = R.h, floor = "metal", wall = "dungeon_brick", ceil = "dungeon_brick", ftex = "hazard", wtex = "blocks", ctex = "planks" }
    -- the belt bed (4 m wide) is the floor itself; the ledges either side are raised half a metre
    G.fill(114, 0, 20, 116, 0.5, 70, "flagstone", "tiles"); G.fill(120, 0, 20, 122, 0.5, 70, "flagstone", "tiles")
    G.fill(115.8, 0.5, 20, 116, 1.3, 70, "metal"); G.fill(120, 0.5, 20, 120.2, 1.3, 70, "metal")
    G.fill(115.95, 0, 22, 116, 0.06, 62, "neon_red"); G.fill(120, 0, 22, 120.05, 0.06, 62, "neon_red")              -- guide lights along the belt
    for z = 21, 69, 4 do G.fill(115.6, 0.5, z, 116, 1.6, z + 0.3, "metal"); G.fill(120, 0.5, z, 120.4, 1.6, z + 0.3, "metal") end
    -- the furnace pit across the belt at the far end, z 62..68
    G.clear(116, -6, 62, 120, 0, 68)
    G.fill(115.8, -6, 62, 116, 0, 68, "obsidian"); G.fill(120, -6, 62, 120.2, 0, 68, "obsidian"); G.fill(116, -6.4, 62, 120, -6, 68, "obsidian")
    G.fill(116, -6, 62, 120, -2.2, 68, "lava")
    G.fill(116, -2.2, 68, 120, 0, 68.4, "obsidian")
    G.text(115.2, 3.6, 69.6, "FURNACE OF CONSEQUENCES", { facing = "-z", material = "neon_red", size = 1, depth = 1 })
    G.text(114.4, 4.4, 20, "THE BELT IS ALWAYS ON", { facing = "+z", material = "hazard_y", size = 1, depth = 1 })
    -- the lever (east wall, mid-way)
    G.fill(121.2, 0.5, 43.2, 122, 1.4, 44.8, "marble")
    G.fill(121.0, 1.4, 43.8, 121.4, 2.0, 44.2, "metal")
    W.openings[#W.openings + 1] = { 113.6, 0, 20.2, 114.4, 4, 24 }
    W.openings[#W.openings + 1] = { 114, 0, 69.6, 122, 6, 70.4 }
end

W.things[#W.things + 1] = function()
    for z = 28, 64, 12 do G.sconce(114, 3.2, z, "+x"); G.sconce(122, 3.2, z + 5, "-x") end
    for z = 26, 62, 9 do G.lamp(118, z, 6.0, 1.0, { color = { 1.0, 0.45, 0.25 }, reach = 12, mat = "neon_red" }) end
    G.torch(118, -1.5, 65, { preset = "campfire", color = { 1, 0.3, 0.1 }, reach = 16, name = "furnace_glow" })
    emitter.create{ name = "furnace_embers", preset = "embers", pos = { G.mx(118), G.my(-1), G.mz(65) }, size = { 1.8, 0.5, 2.6 } }
    T.hazard("lava", 116, -6.4, 62, 120, 0.3, 68, 60)
    local belt = events.belt{ name = "conveyor", box = { G.wx(116), G.wy(-0.25), G.wz(22), G.wx(120) - 1, G.wy(0) - 1, G.wz(62) - 1 }, dir = { 0, 0, 1 }, speed = 1.6, texture = "stripes", lit = true }
    local lever = events.lever{ name = "conveyor_lever", box = { G.wx(121.0), G.wy(1.4), G.wz(43.8), G.wx(121.4) - 1, G.wy(2.0), G.wz(44.2) - 1 }, prompt = "Emergency stop", on = "neon", off = "metal", lit = false }
    events.connect(lever, "on", belt, "off")
    events.connect(lever, "off", belt, "on")
    T.add_interact("conveyor_lever", 121.2, 1.7, 44, "Emergency stop (the belt)", 2.4)
    events.on(lever, "on", function() G.announcer.say("Emergency stop engaged. The belt is resting. The belt is also unionised. It will remember this.", { prio = 1, key = "belt_stop", cooldown = 6000 }) end)
    W.belt_node = belt
    T.crate("conveyor_a", "bronze", 120.4, 0.5, 66.4, "-x")
    -- crates ride the belt (and go into the furnace); at most three at a time
    W.belt_crates = W.belt_crates or {}
    W.populate_list.conveyor = {
        { "intern", 115, 32, 0.5 }, { "intern", 115, 52, 0.5 },
        { "rat", 121, 28, 0.5 }, { "rat", 121, 40, 0.5 }, { "rat", 121, 58, 0.5 },
        { "goblin", 115, 64, 0.5 }, { "goblin", 121, 64, 0.5 },
    }
    G.announcer_belt_said = false
end

function W.tick_belt(t)
    if t % 240 == 0 and G.current_room == "conveyor" or (t % 240 == 0 and #W.belt_crates < 3 and G.current_room == "boiler") then
        if #W.belt_crates < 3 then
            local id = body.box(G.mx(118) - 0.35, G.my(0.4), G.mz(23), 11, 11, 11, "dark_wood")
            W.belt_crates[#W.belt_crates + 1] = id
        end
    end
    if t % 30 == 0 then
        for i = #W.belt_crates, 1, -1 do
            local x, y, z, ok = body.pos(W.belt_crates[i])
            if not ok or y < G.my(-1.5) or z > G.mz(70) or t % 3000 == 0 then
                if ok then
                    fx.play("splat_red", math.floor(units.vox(x)), math.floor(units.vox(y)), math.floor(units.vox(z)), 1.2)
                    body.remove(W.belt_crates[i])
                end
                table.remove(W.belt_crates, i)
            end
        end
    end
end
