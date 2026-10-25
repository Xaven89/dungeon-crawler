-- gen/themes_transit: who lives where in the Iron Tangle (floor 4) and what stands around them: the lights of the tunnels and stations, the hubs (safe stations: the crystal that saves, the vending
-- machine), the dens. The voxels are the hook's (gen/transit_shell.lua); the trains are gen/trains.lua's.
Game = Game or {}
local G = Game
local F = G.floorgen
local floor, max, min = math.floor, math.max, math.min

local function yl(room) return room.info.room.y or 0 end

-- the kiosks of the grammar (hubs, stations, dens): search one for what the last traveller left (an item and some gold, once). The voxels are the hook's; the button is a box on the kiosk's counter
local function kiosk_drops(room, ctx)
    local lay = F.furnished(room, ctx)
    if not lay then return end
    local ox, oz = F.off(room)
    local T = G.traps
    local FRONT = { ["+z"] = { 0, 1 }, ["-z"] = { 0, -1 }, ["+x"] = { 1, 0 }, ["-x"] = { -1, 0 } }
    local n = 0
    for _, it in ipairs(lay.items) do
        if it.id == "kiosk" then
            n = n + 1
            local id = string.format("k%d_%d_%d_%d", ctx.floor, room.ci, room.cj, n)
            local x0, z0, x1, z1 = it.x0 + ox, it.z0 + oz, it.x1 + ox, it.z1 + oz
            local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            local fr = FRONT[it.face] or { 0, 1 }
            local btn = events.button{ name = id, box = { G.wx(x0), G.wy(0.9), G.wz(z0), G.wx(x1) - 1, G.wy(1.5), G.wz(z1) - 1 }, prompt = "Search the kiosk", on = "neon", off = "gold", press_ticks = 8 }
            local function search()
                if G.state.opened[id] then return end
                G.state.opened[id] = true
                local wx, wy, wz = G.mx(cx + fr[1] * 1.1), G.my(1.0), G.mz(cz + fr[2] * 1.1)
                G.sfx.play("coin", cx, 1.2, cz, 0.6, 1.2)
                G.enemies.drop(wx, wy, wz, "gold", G.irange(8, 18))
                G.enemies.drop(wx, wy + 0.2, wz, "item", G.items.roll("bronze", 17 * n + #id))
                G.tally("kiosks", "searched", 1)
            end
            events.on(btn, "pressed", search)
            T.kiosks[id] = { cell = room.id, search = search, x = cx + fr[1] * 1.0, z = cz + fr[2] * 1.0 }          -- (the bot searches them like it opens crates)
            T.add_interact(id, cx, 1.4, cz, "Search the kiosk", 2.8, function() return not G.state.opened[id] end)
        end
    end
end

-- a row of lights along the axis of a hall, every 8 m, at the ceiling of its level
local function strip_lights(room, ctx, step, intensity, reach)
    step = step * 2                                                    -- (one light per 12 m: the polish pass)
    local dk = G.gen.rules.dark()
    local ox, oz = F.off(room)
    local ir = room.info.room
    local y = yl(room) + 3.6
    local n = 0
    for t = 4, 28, step do
        n = n + 1
        local x, z
        local o = (n % 2 == 0) and 2.5 or -2.5                         -- alternate beside the track (on the platform / the ledge), never over the bed
        if room.info.axis == "x" then x, z = ox + t, oz + 16 + o else x, z = ox + 16 + o, oz + t end
        G.torch(x, y, z, { preset = "torch", color = { 0.8, 0.88, 1.0 }, reach = reach or 12, far = 26, intensity = (intensity or 10) * dk, name = room.id .. "_t" .. n })
    end
end


-- (voxel-art) wall lights: every wall within the probes' ~7 m of a light
local function wall_lights(room, y, pts, tag)
    local ox, oz = F.off(room)
    for k, p in ipairs(pts) do
        G.torch(ox + p[1], y, oz + p[2], { preset = "torch", color = G.COOL, reach = 7, far = 26, intensity = 7, raw = true, flicker = false, name = room.id .. tag .. k })
    end
end
local function platform_lights(room)
    local ir = room.info.room
    local pts = {}
    local ax = (room.info.axis == "x")
    local a0, a1 = ax and ir.z or ir.x, ax and (ir.z + ir.d) or (ir.x + ir.w)      -- across: the two long walls
    local b0, b1 = ax and ir.x or ir.z, ax and (ir.x + ir.w) or (ir.z + ir.d)      -- along
    for t = b0 + 4, b1 - 2, 8 do
        for _, a in ipairs({ a0 + 1.5, a1 - 1.5 }) do pts[#pts + 1] = ax and { t, a } or { a, t } end
    end
    wall_lights(room, yl(room) + 3.0, pts, "_wl")
end
F.register("tunnel", { names = { "A Tunnel", "Service Tunnel", "Track Segment" }, things = function(room, ctx) strip_lights(room, ctx, 6, 15, 13) end })
F.register("corner", {
    names = { "The Bend", "Curve Cavern", "Switching Yard" },
    things = function(room, ctx)
        local dk = G.gen.rules.dark()
        local ox, oz = F.off(room)
        local n = 0
        for _, p in ipairs({ { 8, 8 }, { 24, 8 }, { 8, 24 }, { 24, 24 }, { 16, 16 } }) do
            n = n + 1
            G.torch(ox + p[1], 4.5, oz + p[2], { preset = "torch", color = G.COOL, reach = 14, far = 30, intensity = 15 * dk, name = room.id .. "_c" .. n })
        end
    end,
})
F.register("station", {
    names = { "Platform", "The Concourse", "Transfer Platform" },
    things = function(room, ctx)
        strip_lights(room, ctx, 6, 16, 14)
        kiosk_drops(room, ctx)
        if room.info.code ~= "X" then platform_lights(room) end                     -- (voxel-art)
        if room.info.code == "X" then                                               -- (voxel-art) the cross hall: wall lights at both levels
            local pts = { { 16, 5 }, { 16, 27 }, { 5, 16 }, { 27, 16 }, { 5, 5 }, { 27, 5 }, { 5, 27 }, { 27, 27 } }
            wall_lights(room, 3.0, pts, "_xw"); wall_lights(room, transit_const().level_m + 3.0, pts, "_xd")
        end
        if room.info.code == "Y" or room.info.code == "B" then                  -- the crowd that waits for the train
            local lay, rects = F.furnished(room, ctx)
            local ox, oz = F.off(room)
            local spots = {}
            for _, sp in ipairs(transit_crowd_spots(room.info)) do spots[#spots + 1] = { x = sp.x + ox, z = sp.z + oz, kind = "idle" } end
            local L = G.gen.layout
            local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
            F.populate(room, ctx, r2, 2 + (room.info.code == "Y" and 1 or 0), { allow = rects and F.clear_of(rects, 0.45) or nil, spots = spots, still = true, y = yl(room), kinds = { { "goblin", 4 }, { "bandit", 3 }, { "imp", 2 }, { "rat", 2 } } })
        end
        if room.info.code == "X" then                                              -- the centre: lights below and on the deck, the glow of the pit, the plaque on its rail
            local dk = G.gen.rules.dark()
            local ox, oz = F.off(room)
            for k, p in ipairs({ { 10, 10 }, { 22, 10 }, { 10, 22 }, { 22, 22 } }) do
                G.torch(ox + p[1], 6.0, oz + p[2], { preset = "torch", reach = 12, far = 28, intensity = 14 * dk, name = room.id .. "_xl" .. k })
                G.torch(ox + p[1], 13.0, oz + p[2], { preset = "torch", reach = 12, far = 28, intensity = 14 * dk, name = room.id .. "_xu" .. k })
            end
        if room.info.abyss then
            G.torch(ox + 22, 6.5, oz + 22, { preset = "campfire", color = { 0.9, 0.2, 0.15 }, reach = 12, far = 28, name = room.id .. "_pit" })
            local abyss = events.button{ name = room.id .. "_abyss", box = { G.wx(ox + 21.6), G.wy(8.5), G.wz(oz + 18.85), G.wx(ox + 22.4) - 1, G.wy(9.0), G.wz(oz + 18.95) - 1 }, prompt = tr("transit.abyss_prompt"), on = "neon_red", off = "gold", press_ticks = 8 }
            events.on(abyss, "pressed", function()
                G.announcer.say_key("transit.abyss", { prio = 2 })
                G.sfx.play("rumble", ox + 22, 9, oz + 22, 0.8, 0.5)
            end)
            G.traps.add_interact(room.id .. "_abyss", ox + 22, 9.2, oz + 18.6, tr("transit.abyss_prompt"), 2.6)
        end
        end
    end,
})
F.register("hub", {
    names = { "Transfer Station", "Hub", "The Interchange" },
    things = function(room, ctx)
        strip_lights(room, ctx, 6, 17, 14)
        platform_lights(room)                                                       -- (voxel-art)
        kiosk_drops(room, ctx)
        local dk = G.gen.rules.dark()
        local ox, oz = F.off(room)
        local f = transit_hub_fixtures(room.info)
        local id = room.id
        local T = G.traps
        G.torch(ox + f.crystal.x, 2.6, oz + f.crystal.z, { preset = "magic_sparks", color = { 0.62, 0.72, 1.0 }, reach = 10, name = id .. "_crystal" })
        G.dust(id .. "_dust", "dust_motes", { G.mx(ox + 16), G.my(2.5), G.mz(oz + 16) }, { 8, 2, 8 })
        local vx, vz, cx, cz = ox + f.vend.x, oz + f.vend.z, ox + f.crystal.x, oz + f.crystal.z
        local ax = (room.info.axis == "x")
        local function wb(x0, y0, z0, x1, y1, z1) return { G.wx(x0), G.wy(y0), G.wz(z0), G.wx(x1) - 1, G.wy(y1), G.wz(z1) - 1 } end
        local vbox = ax and wb(vx - 0.5, 0.9, vz + 0.45, vx + 0.5, 1.5, vz + 0.65) or wb(vx + 0.45, 0.9, vz - 0.5, vx + 0.65, 1.5, vz + 0.5)
        local btn = events.button{ name = id .. "_vending", box = vbox, prompt = "Vending Machine of Mild Relief", on = "neon", off = "gold", press_ticks = 8 }
        events.on(btn, "pressed", function() if G.shop then G.shop.open() end end)
        T.add_interact(id .. "_vending", ax and vx or vx + 0.9, 1.6, ax and vz + 0.9 or vz, "Use the Vending Machine", 2.8)
        T.add_interact(id .. "_crystal", cx, 1.4, cz, "Touch the crystal (save)", 2.4)
        local cb = ax and wb(cx - 0.3, 1.2, cz - 0.3, cx + 0.3, 1.9, cz + 0.3) or wb(cx - 0.3, 1.2, cz - 0.3, cx + 0.3, 1.9, cz + 0.3)
        local crystal = events.button{ name = id .. "_save", box = cb, prompt = "Touch the crystal", on = "neon", off = "crystal", press_ticks = 8 }
        events.on(crystal, "pressed", function() G.save_now() end)
        -- the sponsors' boxes: along the south platform's wall (axis x) / the east platform's wall (axis z)
        room.box_spots = {}
        for k = 1, 3 do
            local u = 10 + 4 * (k - 1)
            room.box_spots[k] = ax and { x = ox + u, z = oz + 24.6, face = "-z" } or { x = ox + 24.6, z = oz + u, face = "-x" }
        end
    end,
})
F.register("den", {
    names = { "The Commuters' Den", "Rest Hall B", "The Waiting Pen" },
    things = function(room, ctx)
        kiosk_drops(room, ctx)
        local dk = G.gen.rules.dark()
        local ox, oz = F.off(room)
        local n = 0
        for _, p in ipairs({ { 12, 12 }, { 20, 12 }, { 12, 20 }, { 20, 20 } }) do
            n = n + 1
            G.torch(ox + p[1], 5.8, oz + p[2], { preset = "torch", color = G.COOL, reach = 12, far = 26, intensity = 11 * dk, name = room.id .. "_d" .. n })
        end
        local lay, rects, spots = F.furnished(room, ctx)
        local r = ctx.rng(room)
        local L = G.gen.layout
        local r2 = L.make_rng(ctx.seed, ctx.floor, 2000 + room.index)
        F.populate(room, ctx, r2, F.head_count(room, ctx.floor, r2) + 1, { allow = rects and F.clear_of(rects, 0.45) or nil, spots = spots, kinds = { { "goblin", 4 }, { "bandit", 3 }, { "imp", 2 }, { "rat", 2 } } })
    end,
})
