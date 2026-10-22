-- world: the floor, area by area. Every builder has two halves: the voxels (only on the first run: `project.first_run()`, the save keeps them) and the things that are not
-- voxels (emitters, events, gravity fields, bodies), made on every start.
Game = Game or {}
local G = Game
local W = {}
G.world = W

-- room rectangles (metres, local frame), used by the rest of the game (music, announcer, spawns, checkpoints)
W.rooms = {
    lobby    = { x = 0,   z = 0,   w = 26, d = 22, h = 9,   name = "Intake Lobby" },
    hall     = { x = 30,  z = 2,   w = 42, d = 18, h = 7,   name = "Hall of Mild Peril" },
    boiler   = { x = 76,  z = 0,   w = 36, d = 26, h = 10,  name = "The Boiler Gallery" },
    conveyor = { x = 114, z = 26,  w = 8,  d = 44, h = 6,   name = "The Conveyor of Consequences" },
    gutter   = { x = 80,  z = 70,  w = 42, d = 26, h = 7,   name = "The Gutter" },
    ballroom = { x = 38,  z = 66,  w = 38, d = 32, h = 14,  name = "The Zero-G Ballroom" },
    grotto   = { x = 0,   z = 52,  w = 34, d = 58, h = 12,  name = "The Mushroom Grotto" },
    arena    = { x = 12,  z = 114, w = 36, d = 36, h = 14,  name = "The Floor Manager's Office" },
    stairwell = { x = 54, z = 124, w = 16, d = 16, h = 6,   name = "Stairwell 1" },
}

-- which room is this local point in (nil: a corridor or outside)
function W.room_at(lx, lz)
    for id, r in pairs(W.rooms) do
        if lx >= r.x and lx < r.x + r.w and lz >= r.z and lz < r.z + r.d then return id, r end
    end
end

-- ================================================================================================ A: the Intake Lobby
local function build_lobby_voxels()
    local r = W.rooms.lobby
    G.room{ x = r.x, z = r.z, w = r.w, d = r.d, h = r.h, floor = "marble", wall = "dungeon_brick", ceil = "dungeon_brick", wtex = "blocks", ctex = "planks" }
    -- a checkered floor of marble and flagstone, 2 m squares
    for ix = 0, 12 do
        for iz = 0, 10 do
            if (ix + iz) % 2 == 1 then G.fill(ix * 2, -0.5, iz * 2, ix * 2 + 2, 0, iz * 2 + 2, "flagstone", "tiles") end
        end
    end
    -- ceiling beams
    for x = 2, 24, 4 do G.fill(x, 8.2, 0, x + 0.5, 9, 22, "dark_wood") end
    for z = 4, 20, 8 do G.fill(0, 8.5, z, 26, 9, z + 0.5, "dark_wood") end
    -- four pillars
    for _, p in ipairs({ { 7, 6 }, { 19, 6 }, { 7, 16 }, { 19, 16 } }) do
        G.pillar(p[1], p[2], 0.8, 0, 8.2, "marble", "blocks")
        G.pillar(p[1], p[2], 1.1, 0, 0.5, "dungeon_brick")
        G.pillar(p[1], p[2], 1.1, 7.7, 8.2, "dungeon_brick")
    end
    -- the reception desk on the north wall, with a golden trim, and the show's sign above it
    G.fill(8, 0, 2.2, 18, 1.1, 3.8, "marble", "blocks")
    G.fill(7.9, 1.1, 2.1, 18.1, 1.25, 3.9, "gold")
    G.fill(8, 0, 3.8, 18, 0.3, 4, "dark_wood")
    G.text(4.2, 5.3, 0, "THE DESCENT", { facing = "+z", material = "gold", size = 3, spacing = 1, depth = 2 })
    G.text(2.9, 4.1, 0, "SEASON 7 - NOW WITH 40% MORE DEATH", { facing = "+z", material = "neon_red", size = 1, depth = 1 })
    -- the check-in crystal (the save point of the lobby): a rune crystal on a plinth, west wall
    G.fill(2, 0, 9, 4, 0.8, 13, "marble", "blocks")
    G.sphere(3, 1.4, 11, 0.62, "rune")
    -- queue ropes: posts and chains along the south of the desk
    for i = 0, 5 do
        local x = 8 + i * 2
        G.fill(x, 0, 6, x + 0.15, 1.0, 6.15, "gold")
        if i < 5 then G.fill(x + 0.15, 0.8, 6.03, x + 2, 0.9, 6.1, "metal") end
    end
    -- benches along the south wall under the sconces
    for _, bx in ipairs({ 5, 12, 19 }) do
        G.fill(bx, 0.45, 19.4, bx + 3, 0.6, 20.4, "dark_wood")
        G.fill(bx + 0.2, 0, 19.5, bx + 0.4, 0.45, 20.3, "dark_wood"); G.fill(bx + 2.6, 0, 19.5, bx + 2.8, 0.45, 20.3, "dark_wood")
    end
    -- the gate: a barred portcullis in the corridor mouth (east wall), it drops into a slot in the floor
    G.corridor{ x = 26, z = 11, len = 4, w = 4, h = 4.5, axis = "x", floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    G.fill(25, 0, 8.8, 26.4, 5, 9.2, "metal"); G.fill(25, 0, 12.8, 26.4, 5, 13.2, "metal")      -- gate posts
    G.fill(25, 4.5, 8.8, 26.4, 5.2, 13.2, "metal")                                               -- the lintel
    G.vclear(26 * 16 + 4, -76, 9 * 16 + 4, 26 * 16 + 11, -1, 13 * 16 - 4)                          -- the slot the portcullis sinks into
    local gx = 26 * 16 + 5
    for z = 9 * 16 + 4, 13 * 16 - 4, 4 do G.vfill(gx, 0, z, gx + 3, 71, z + 1, "metal") end       -- bars
    G.vfill(gx, 0, 9 * 16 + 4, gx + 3, 3, 13 * 16 - 4, "metal"); G.vfill(gx, 34, 9 * 16 + 4, gx + 3, 37, 13 * 16 - 4, "metal"); G.vfill(gx, 68, 9 * 16 + 4, gx + 3, 71, 13 * 16 - 4, "metal")
    G.text(7.4, 6.4, 22, "GAUNTLET GATE - PLEASE SCREAM IN AN ORDERLY FASHION", { facing = "-z", material = "hazard_y", size = 1, depth = 1 })
end

local function build_lobby_things()
    local r = W.rooms.lobby
    for _, p in ipairs({ { 7, 6 }, { 19, 6 }, { 7, 16 }, { 19, 16 } }) do
        G.brazier(p[1] + 1.5, p[2] + 0.0, { reach = 14 })
    end
    for _, x in ipairs({ 5, 12, 19 }) do G.sconce(x + 1.5, 3.2, 22, "-z") end
    for _, z in ipairs({ 4, 18 }) do G.sconce(0, 3.2, z, "+x") end
    G.torch(3, 2.6, 11, { preset = "magic_sparks", color = { 0.7, 0.3, 1.0 }, reach = 9, name = "lobby_crystal" })
    emitter.create{ name = "lobby_dust", preset = "dust_motes", pos = { G.mx(13), G.my(4), G.mz(11) }, size = { 11, 4, 9 } }
    W.lobby_gate = events.door{ name = "lobby_gate", box = { G.wx(26) + 5, G.wy(0), G.wz(9) + 4, G.wx(26) + 7, G.wy(0) + 71, G.wz(13) - 5 },
                                travel = { 0, -72, 0 }, speed = 2 }
end

-- ================================================================================================ the whole floor
function W.build()
    if project.first_run() then
        build_lobby_voxels()
    end
    build_lobby_things()
end

W.checkpoints = {
    lobby     = { x = 3.5, y = 0.1, z = 11 },
    stairwell = { x = 58, y = 0.1, z = 132 },
}

function W.open_lobby_gate()
    if W.lobby_gate then events.command(W.lobby_gate, "open") end
end

function W.start_position()   -- where a new contestant wakes up: the west side of the lobby looking east at the gate
    return G.mx(3.5), G.my(0.1), G.mz(11)
end
