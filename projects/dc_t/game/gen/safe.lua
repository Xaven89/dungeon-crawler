-- gen/safe: the two safe rooms of a generated floor, 16 x 16 m: the ARRIVAL (where the stairs of the floor above end up: a fireplace, a sofa, the check-in crystal, a vending machine) and the
-- EXIT STAIRWELL (the same room with the stairs down, sealed by a door button). Drawn from the old Stairwell 1 with every coordinate relative to the room's corner.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local S = {}
G.gen.safe = S

-- the voxels
function S.voxels(r, opts)
    local x, z = r.x, r.z
    G.room{ x = x, z = z, w = r.w, d = r.d, h = r.h, floor = "dark_wood", wall = "dark_wood", ceil = "dark_wood", ftex = "planks", wtex = "fine_planks", ctex = "planks" }
    -- the rug, the fireplace in the north wall, bookshelves on the west wall
    G.fill(x + 4, 0, z + 4, x + 12, 0.05, z + 12, "carpet"); G.fill(x + 3.9, 0, z + 3.9, x + 12.1, 0.05, z + 4, "gold"); G.fill(x + 3.9, 0, z + 12, x + 12.1, 0.05, z + 12.1, "gold")
    G.fill(x + 5, 0, z, x + 11, 3.0, z + 1.2, "brick"); G.clear(x + 6, 0, z, x + 10, 1.8, z + 1.2); G.fill(x + 6, 0, z, x + 10, 0.2, z + 1, "obsidian")
    G.fill(x + 4.4, 3.0, z, x + 11.6, 3.4, z + 1.6, "marble")
    for _, dz in ipairs({ 2, 12.5 }) do
        G.fill(x, 0, z + dz, x + 1.2, 3.6, z + dz + 3, "dark_wood")
        for sh = 0.4, 3.2, 0.7 do
            G.fill(x + 1.2, sh, z + dz + 0.1, x + 1.6, sh + 0.05, z + dz + 2.9, "dark_wood")
            for b = 0, 9 do
                local bz = z + dz + 0.15 + b * 0.27
                G.fill(x + 1.2, sh + 0.05, bz, x + 1.55, sh + 0.55, bz + 0.23, "dark_wood")
                G.paint(x + 1.2, sh + 0.05, bz, x + 1.55, sh + 0.55, bz + 0.23, ({ "red", "blue", "green", "yellow", "violet", "orange" })[1 + (b + math.floor(dz)) % 6])
            end
        end
    end
    -- the sofa (south-west) and a table
    G.fill(x + 2, 0, z + 12.2, x + 6.5, 0.5, z + 14, "carpet"); G.fill(x + 2, 0.5, z + 13.4, x + 6.5, 1.3, z + 14, "carpet")
    G.fill(x + 2, 0.5, z + 12.2, x + 2.5, 0.9, z + 14, "carpet"); G.fill(x + 6, 0.5, z + 12.2, x + 6.5, 0.9, z + 14, "carpet")
    G.fill(x + 8, 0, z + 12.6, x + 10, 0.6, z + 14, "dark_wood")
    -- the vending machine (east wall)
    G.fill(x + 14, 0, z + 3, x + 16, 3.3, z + 6, "metal"); G.fill(x + 13.6, 0.8, z + 3.2, x + 14, 2.6, z + 5.8, "lantern"); G.fill(x + 13.55, 0.9, z + 5.1, x + 13.7, 1.2, z + 5.6, "gold")
    G.fill(x + 13.55, 2.0, z + 3.4, x + 13.7, 2.4, z + 4.7, "neon_red")
    G.text(x + 13.5, 3.4, z + 3.2, "MILD RELIEF", { facing = "-x", material = "gold", size = 1, depth = 1 })
    -- the check-in crystal on a plinth
    G.fill(x + 12, 0, z + 0.6, x + 14.2, 0.9, z + 2.8, "marble", "blocks"); G.sphere(x + 13.1, 1.6, z + 1.7, 0.62, "rune")
    -- a hay bed
    G.fill(x + 2, 0, z + 7, x + 4.4, 0.4, z + 9.2, "dark_wood"); G.fill(x + 2.2, 0.4, z + 7.2, x + 4.2, 0.6, z + 9, "sand")
    if opts and opts.stairs then
        -- the stairs down: a shaft in the south-east of the floor with steps, sealed by an obsidian door at the bottom
        G.clear(x + 10, -6.4, z + 14.4, x + 15.6, 0, z + 16)
        for k = 0, 11 do G.fill(x + 10, -k * 0.5 - 0.5, z + 14.4 + k * 0.1, x + 15.6, -k * 0.5, z + 14.5 + k * 0.1 + 0.4, "flagstone") end
        G.fill(x + 10, -6.4, z + 15.4, x + 15.6, -0.5, z + 16.6, "obsidian")
    end
end

-- the things (every start): lights, the save crystal, the vending machine, the stairs
function S.things(r, opts)
    local x, z = r.x, r.z
    local id = r.id
    G.torch(x + 8, 0.7, z + 0.8, { preset = "campfire", color = { 1, 0.55, 0.2 }, reach = 14, name = id .. "_fire" })
    G.sconce(x, 3.3, z + 2, "+x"); G.sconce(x + 16, 3.3, z + 12, "-x"); G.sconce(x + 3, 3.3, z + 16, "-z"); G.sconce(x + 13, 3.3, z + 16, "-z")
    G.torch(x + 13.1, 2.6, z + 1.7, { preset = "magic_sparks", color = { 0.7, 0.3, 1.0 }, reach = 10, name = id .. "_crystal" })
    G.dust(id .. "_dust", "dust_motes", { G.mx(x + 8), G.my(2.5), G.mz(z + 8) }, { 6, 2, 6 })
    local T = G.traps
    local btn = events.button{ name = id .. "_vending", box = { G.wx(x + 13.55), G.wy(0.9), G.wz(z + 5.1), G.wx(x + 13.7) - 1, G.wy(1.2), G.wz(z + 5.6) - 1 }, prompt = "Vending Machine of Mild Relief", on = "neon", off = "gold", press_ticks = 8 }
    events.on(btn, "pressed", function() if G.shop then G.shop.open() end end)
    T.add_interact(id .. "_vending", x + 13.6, 1.6, z + 4.4, "Use the Vending Machine", 2.8)
    T.add_interact(id .. "_crystal", x + 13.1, 1.4, z + 1.7, "Touch the crystal (save)", 2.4)
    local crystal = events.button{ name = id .. "_save", box = { G.wx(x + 12.8), G.wy(1.2), G.wz(z + 1.4), G.wx(x + 13.4), G.wy(1.9), G.wz(z + 2) - 1 }, prompt = "Touch the crystal", on = "neon", off = "rune", press_ticks = 8 }
    events.on(crystal, "pressed", function() G.save_now() end)
    if opts and opts.stairs then
        local down = events.button{ name = id .. "_down", box = { G.wx(x + 12), G.wy(-3.4), G.wz(z + 15.4), G.wx(x + 13.2), G.wy(-2.6), G.wz(z + 15.5) - 1 }, prompt = tr("ui.descend", opts.next_floor or 2), on = "neon", off = "neon_red", press_ticks = 10 }
        events.on(down, "pressed", function() if G.run and G.run.descend then G.run.descend() end end)
        T.add_interact(id .. "_down", x + 12.6, -2.9, z + 15, tr("ui.descend", opts.next_floor or 2), 2.6)
    end
end
