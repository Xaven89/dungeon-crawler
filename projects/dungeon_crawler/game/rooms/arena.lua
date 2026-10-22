-- H: the Floor Manager's Office, the boss arena: a round hall, a lava moat with four bridges, pillars, the manager's desk. The fight itself is game/boss.lua.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.arena
local CX, CZ, RAD = 30, 132, 17.5
W.arena = { cx = CX, cz = CZ, r = RAD }
W.AGATE = { x0 = 50 * 16 + 1, x1 = 50 * 16 + 3, z0 = 130 * 16 + 6, z1 = 134 * 16 - 8, h = 61 }      -- the exit portcullis (voxels, local), see the builder

W.builders[#W.builders + 1] = function()
    -- the shell: a cylinder of brick, hollowed out; the floor of marble with a gold ring, the moat of lava
    G.ring(CX, CZ, RAD, RAD + 0.25, 0, 14, "dungeon_brick", "blocks")
    G.cyl_clear(CX, CZ, RAD, 0, 14)
    G.pillar(CX, CZ, RAD + 0.25, 14, 14.4, "dungeon_brick", "planks")
    G.pillar(CX, CZ, RAD + 0.25, -0.5, 0, "flagstone", "big_tiles")
    G.ring(CX, CZ, 13.2, RAD, -0.5, 0, "flagstone", "skull")                          -- the outer floor: a custom pixel-art texture (textures.json)
    G.pillar(CX, CZ, 11, -0.5, 0, "marble", "tiles")
    G.ring(CX, CZ, 8.7, 9.1, -0.02, 0.04, "gold")
    G.ring(CX, CZ, 5, 5.4, -0.02, 0.04, "gold", "gold_stars")
    -- the moat: r 11..13.2, 3 m deep, lava; four marble bridges across it
    G.ring(CX, CZ, 11, 13.2, -3.4, 0, "air")
    G.cyl_clear(CX, CZ, 13.2, -3.4, -0.01)
    G.pillar(CX, CZ, 11, -3.4, -0.5, "obsidian")
    G.pillar(CX, CZ, 11, -0.5, 0, "marble", "tiles")
    G.ring(CX, CZ, 11, 13.2, -3.4, -3.0, "obsidian")
    G.ring(CX, CZ, 11, 13.2, -3.0, -0.45, "lava")
    G.ring(CX, CZ, 11, 11.2, -3.4, 0.4, "obsidian"); G.ring(CX, CZ, 13.0, 13.2, -3.4, 0.4, "obsidian")
    G.fill(CX - 1.5, -0.5, CZ - 13.2, CX + 1.5, 0, CZ - 11, "marble", "blocks"); G.fill(CX - 1.5, -0.5, CZ + 11, CX + 1.5, 0, CZ + 13.2, "marble", "blocks")
    G.fill(CX - 13.2, -0.5, CZ - 1.5, CX - 11, 0, CZ + 1.5, "marble", "blocks"); G.fill(CX + 11, -0.5, CZ - 1.5, CX + 13.2, 0, CZ + 1.5, "marble", "blocks")
    -- pillars around the outer ring
    for i = 0, 7 do
        local a = i * math.pi / 4 + math.pi / 8
        local x, z = CX + math.cos(a) * 15.6, CZ + math.sin(a) * 15.6
        G.pillar(x, z, 0.8, 0, 13.6, "marble", "blocks"); G.pillar(x, z, 1.1, 0, 0.5, "dungeon_brick"); G.pillar(x, z, 1.1, 13.0, 13.6, "dungeon_brick")
    end
    -- the manager's desk, his chair, and the sign
    G.fill(25, 0, 139, 35, 1.2, 141.2, "marble", "blocks"); G.fill(24.8, 1.2, 138.8, 35.2, 1.35, 141.4, "gold")
    G.fill(28, 0, 142, 32, 1.6, 143.4, "dark_wood"); G.fill(28, 1.6, 143, 32, 3.2, 143.6, "dark_wood")
    G.fill(24, 2.5, 148.7, 36, 9, 149.1, "dark_wood", "planks")
    G.text(25, 7.2, 148.7, "EMPLOYEE OF", { facing = "-z", material = "gold", size = 2, depth = 1 })
    G.text(25.6, 5.2, 148.7, "THE MONTH:", { facing = "-z", material = "gold", size = 2, depth = 1 })
    G.text(27.4, 3.2, 148.7, "NOBODY", { facing = "-z", material = "neon_red", size = 2, depth = 1 })
    -- the way in (north tunnel from the Grotto) and the way out (east, to the Stairwell: sealed until the manager is fired)
    W.openings[#W.openings + 1] = { 26.5, 0, 113.4, 29.5, 3.6, 115.2 }
    G.corridor{ x = 47, z = 132, len = 7.2, w = 3.6, h = 3.8, axis = "x", floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    W.openings[#W.openings + 1] = { 47.2, 0, 130.2, 48.0, 3.8, 133.8 }
    G.fill(49.5, 0, 130.0, 50.1, 4.1, 130.4, "metal"); G.fill(49.5, 0, 133.6, 50.1, 4.1, 134.0, "metal")             -- gate posts
    -- the gate: a portcullis slab that sinks into a slot in the floor (the door node moves exactly these voxels)
    local g = W.AGATE
    G.vclear(g.x0 - 1, -66, g.z0, g.x1 + 2, -1, g.z1)
    for z = g.z0, g.z1, 5 do G.vfill(g.x0, 0, z, g.x1, g.h, math.min(z + 1, g.z1), "metal") end
    G.vfill(g.x0, 0, g.z0, g.x1, 3, g.z1, "metal"); G.vfill(g.x0, 30, g.z0, g.x1, 33, g.z1, "metal"); G.vfill(g.x0, 58, g.z0, g.x1, g.h, g.z1, "metal")
end

W.things[#W.things + 1] = function()
    for i = 0, 7 do
        local a = i * math.pi / 4 + math.pi / 8
        G.torch(CX + math.cos(a) * 14.6, 3.5, CZ + math.sin(a) * 14.6, { reach = 13, color = { 1.0, 0.45, 0.2 } })
    end
    G.torch(CX, 0.5, CZ, { preset = "campfire", color = { 1, 0.3, 0.2 }, reach = 18, name = "arena_core" })
    G.brazier(23.5, 137.5, { reach = 12 }); G.brazier(36.5, 137.5, { reach = 12 })       -- they light the manager's face for his entrance
    emitter.create{ name = "arena_embers", preset = "embers", pos = { G.mx(CX), G.my(-0.3), G.mz(CZ) }, size = { 12.5, 0.4, 12.5 }, shape = "disc" }
    T.hazard("lava", CX - 13.3, -3.5, CZ - 13.3, CX + 13.3, 0.3, CZ + 13.3, 0)     -- placeholder replaced below: the moat only
    T.hazards[#T.hazards] = nil
    local g = W.AGATE
    W.arena_gate = events.door{ name = "arena_exit_gate", box = { G.OX + g.x0, G.OY, G.OZ + g.z0, G.OX + g.x1, G.OY + g.h, G.OZ + g.z1 }, travel = { 0, -62, 0 }, speed = 2 }
    if G.state.flags.boss_dead then events.command(W.arena_gate, "open") end
end

-- the moat hurts: standing between r 11 and 13.2 below the bridge level
function W.arena_tick(t)
    if t % 12 ~= 0 or G.current_room ~= "arena" then return end
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local d = G.dist2(lx, lz, CX, CZ)
    if d > 11.05 and d < 13.15 and ly < 0.3 then
        G.player.hurt(30, "the lava moat", { pierce = true })
        fx.play("sparks", math.floor(units.vox(px)), math.floor(units.vox(py)), math.floor(units.vox(pz)), 1.0)
    end
end
