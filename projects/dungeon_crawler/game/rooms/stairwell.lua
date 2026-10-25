-- I: Stairwell 1. A safe room between floors: a fireplace, a sofa, a vending machine, a save crystal, a goose's bed, and the stairs down (end of the slice).
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.stairwell

W.builders[#W.builders + 1] = function()
    G.room{ x = R.x, z = R.z, w = R.w, d = R.d, h = R.h, floor = "oak_floor", wall = "dark_wood", ceil = "plaster", wtex = "fine_planks" }
    W.openings[#W.openings + 1] = { 53.6, 0, 130.2, 54.4, 3.8, 133.8 }
    -- a red rug, the fireplace in the north wall, bookshelves along the west wall
    G.fill(58, 0, 128, 66, 0.05, 136, "carpet"); G.fill(57.9, 0, 127.9, 66.1, 0.05, 128, "gold"); G.fill(57.9, 0, 136, 66.1, 0.05, 136.1, "gold")
    G.fill(59, 0, 124, 65, 3.0, 125.2, "brick"); G.clear(60, 0, 124, 64, 1.8, 125.2); G.fill(60, 0, 124, 64, 0.2, 125, "obsidian")
    G.fill(58.4, 3.0, 124, 65.6, 3.4, 125.6, "marble")
    for _, i in ipairs({ 0, 3 }) do          -- (two bookcases at the corners: the middle two stood right in the entrance, z 130 to 134)
        local z = 126 + i * 3.5
        G.fill(54, 0, z, 55.2, 3.6, z + 3, "dark_wood")
        for sh = 0.4, 3.2, 0.7 do
            G.fill(55.2, sh, z + 0.1, 55.6, sh + 0.05, z + 2.9, "dark_wood")
            for b = 0, 9 do G.fill(55.2, sh + 0.05, z + 0.15 + b * 0.27, 55.55, sh + 0.55, z + 0.38 + b * 0.27, "dark_wood"); G.paint(55.2, sh + 0.05, z + 0.15 + b * 0.27, 55.55, sh + 0.55, z + 0.38 + b * 0.27, ({ "red", "blue", "green", "yellow", "violet", "orange" })[1 + (b + i) % 6]) end
        end
    end
    -- the sofa (south-west) and a little table
    G.fill(56, 0, 136.2, 60.5, 0.5, 138, "carpet"); G.fill(56, 0.5, 137.4, 60.5, 1.3, 138, "carpet"); G.fill(56, 0.5, 136.2, 56.5, 0.9, 138, "carpet"); G.fill(60, 0.5, 136.2, 60.5, 0.9, 138, "carpet")
    G.fill(62, 0, 136.6, 64, 0.6, 138, "dark_wood")
    -- the vending machine (east wall): a tall box with a glowing front and a coin slot (the button)
    G.fill(68.7, 0, 127, 70, 3.3, 130, "metal")                                                        -- (voxel-art) the props' machine, its front to -x
    deco_furniture("vending", function(u0, y0, v0, u1, y1, v1, mat) if mat then G.fill(68.7 - v1 + 0.9 - 0.96 + 0.06, y0, 128.5 + u0, 68.7 - v0 + 0.9 - 0.96 + 0.06, y1, 128.5 + u1, mat) end end)
    G.fill(67.55, 0.9, 129.1, 67.7, 1.2, 129.6, "gold")                                                -- the coin slot (the button's box)
    G.text(67.5, 3.4, 127.2, "MILD RELIEF", { facing = "-x", material = "gold", size = 1, depth = 1 })
    -- the save crystal on a plinth
    G.fill(66, 0, 124.6, 68.2, 0.9, 126.8, "marble", "blocks"); G.sphere(67.1, 1.6, 125.7, 0.62, "crystal")
    -- Honk's bed: a hay-filled box
    G.fill(56, 0, 131, 58.4, 0.4, 133.2, "dark_wood"); G.fill(56.2, 0.4, 131.2, 58.2, 0.6, 133, "sand")
    -- the stairs down: an opening in the floor with steps (south-east), and the sealed door at the bottom
    G.clear(64, -6.4, 138.4, 69.6, 0, 140)
    for k = 0, 11 do G.fill(64, -k * 0.5 - 0.5, 138.4 + k * 0.1, 69.6, -k * 0.5, 138.5 + k * 0.1 + 0.4, "flagstone") end
    G.fill(64, -6.4, 139.4, 69.6, -0.5, 140.6, "obsidian")
end

W.things[#W.things + 1] = function()
    G.torch(62, 0.7, 124.8, { preset = "campfire", color = { 1, 0.55, 0.2 }, reach = 14, name = "stairwell_fire" })
    G.sconce(54, 3.3, 126, "+x"); G.sconce(70, 3.3, 136, "-x"); G.sconce(57, 3.3, 140, "-z"); G.sconce(67, 3.3, 140, "-z")
    G.torch(67.1, 2.6, 125.7, { preset = "magic_sparks", color = { 0.7, 0.3, 1.0 }, reach = 10, name = "stairwell_crystal" })
    G.dust("stairwell_dust", "dust_motes", { G.mx(62), G.my(2.5), G.mz(132) }, { 6, 2, 6 })
    -- the vending machine
    local btn = events.button{ name = "vending_machine", box = { G.wx(67.55), G.wy(0.9), G.wz(129.1), G.wx(67.7) - 1, G.wy(1.2), G.wz(129.6) - 1 }, prompt = "Vending Machine of Mild Relief", on = "neon", off = "gold", press_ticks = 8 }
    events.on(btn, "pressed", function() if G.shop then G.shop.open("vending") end end)
    T.add_interact("vending", 67.6, 1.6, 128.4, "Use the Vending Machine", 2.8)
    -- the save crystal
    T.add_interact("save_crystal", 67.1, 1.4, 125.7, "Touch the crystal (save)", 2.4)
    local crystal = events.button{ name = "save_crystal", box = { G.wx(66.8), G.wy(1.2), G.wz(125.4), G.wx(67.4), G.wy(1.9), G.wz(126) }, prompt = "Touch the crystal", on = "neon", off = "crystal", press_ticks = 8 }
    events.on(crystal, "pressed", function() G.save_now("crystal") end)
    -- the way down: a button on the sealed door, a volume at the top of the stairs
    local down = events.button{ name = "stairs_down", box = { G.wx(66), G.wy(-3.4), G.wz(139.4), G.wx(67.2), G.wy(-2.6), G.wz(139.5) }, prompt = "Descend to Floor 2", on = "neon", off = "neon_red", press_ticks = 10 }
    events.on(down, "pressed", function() if G.finish_floor then G.finish_floor() end end)
    T.add_interact("stairs_down", 66.6, -2.9, 139, "Descend to Floor 2", 2.6)
end
