-- world: the floor, area by area. Every builder has two halves: the voxels (only on the first run: `project.first_run()`, the save keeps them) and the things that are not
-- voxels (emitters, events, gravity fields, bodies), made on every start.
Game = Game or {}
local G = Game
local W = {}
G.world = W

-- the slab of the lobby's portcullis (voxels, local): the door node moves exactly these voxels
W.GATE = { x0 = 26 * 16 + 5, x1 = 26 * 16 + 8, z0 = 9 * 16 + 4, z1 = 13 * 16 - 4, h = 71 }

-- room rectangles (metres, local frame), used by the rest of the game (music, announcer, spawns, checkpoints)
W.rooms = {
    lobby    = { x = 0,   z = 0,   w = 26, d = 22, h = 9,   name = "Intake Lobby" },
    hall     = { x = 30,  z = 2,   w = 42, d = 18, h = 7,   name = "Hall of Mild Peril" },
    boiler   = { x = 76,  z = 0,   w = 36, d = 26, h = 10,  name = "The Boiler Gallery" },
    conveyor = { x = 114, z = 20,  w = 8,  d = 50, h = 6,   name = "The Conveyor of Consequences" },
    gutter   = { x = 80,  z = 70,  w = 42, d = 26, h = 7,   name = "The Gutter" },
    ballroom = { x = 38,  z = 66,  w = 38, d = 32, h = 12,  name = "The Zero-G Ballroom" },
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
    local g = W.GATE
    G.vclear(g.x0 - 1, -76, g.z0, g.x1 + 3, -1, g.z1)                                                      -- the slot the portcullis sinks into
    for z = g.z0, g.z1, 4 do G.vfill(g.x0, 0, z, g.x1, g.h, math.min(z + 1, g.z1), "metal") end            -- bars
    G.vfill(g.x0, 0, g.z0, g.x1, 3, g.z1, "metal"); G.vfill(g.x0, 34, g.z0, g.x1, 37, g.z1, "metal"); G.vfill(g.x0, 68, g.z0, g.x1, g.h, g.z1, "metal")
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
    local g = W.GATE
    W.lobby_gate = events.door{ name = "lobby_gate", box = { G.OX + g.x0, G.OY, G.OZ + g.z0, G.OX + g.x1, G.OY + g.h, G.OZ + g.z1 }, travel = { 0, -72, 0 }, speed = 2 }
end

-- ================================================================================================ the whole floor
W.builders = { build_lobby_voxels }
W.things = {}
W.openings = {}       -- { x0, y0, z0, x1, y1, z1 } (metres, local): cleared after every room is built, so a corridor can cut through the walls of the rooms it joins
W.populate_list = {}
W.zones = {}          -- { id, x0, z0, x1, z1, y0, y1, on_enter }

-- one call per area (each is an undo step of its own)
function W.build()
    if G.should_build() then
        for _, b in ipairs(W.builders) do b() end
        for _, o in ipairs(W.openings) do G.clear(o[1], o[2], o[3], o[4], o[5], o[6]) end
    end
    build_lobby_things()
    for _, f in ipairs(W.things or {}) do f() end
end

-- the rooms next to each other (enemies exist only in the room the player is in and the rooms next to it)
W.neighbors = {
    lobby = { "hall" }, hall = { "lobby", "boiler" }, boiler = { "hall", "conveyor" }, conveyor = { "boiler", "gutter" }, gutter = { "conveyor", "ballroom" },
    ballroom = { "gutter", "grotto" }, grotto = { "ballroom", "arena" }, arena = { "grotto", "stairwell" }, stairwell = { "arena" },
}
function W.sync_active(room)
    local active = {}
    if room then
        active[room] = true
        for _, n in ipairs(W.neighbors[room] or {}) do active[n] = true end
        if room == "hall" and G.state.flags.secret_hall_south then active.grotto = true end
        if room == "grotto" and G.state.flags.secret_hall_south then active.hall = true end
    end
    for r, list in pairs(W.populate_list) do
        if active[r] then G.enemies.spawn_room(r, list) else G.enemies.despawn_room(r) end
    end
end
function W.populate() W.sync_active(G.current_room or "lobby") end

function G.on_room_cleared(room)
    local s = G.state
    s.cleared[room] = true
    local A = G.announcer
    if room == "hall" then
        if G.state.kills <= 2 then A.award("pacifist_ish") end
        A.say("The Hall of Mild Peril has been cleared. It is now just a Hall. Please file a complaint with the Hall.", { prio = 0, key = "cleared_hall", cooldown = 99999 })
    elseif G.world.room_cleared_hook then G.world.room_cleared_hook(room) end
    G.save()
end

-- ================================================================================================ housekeeping: the engine's debug keys cannot be unbound (docs/INPUT.md), so the game defends itself
W.last_safe = nil
W.heart = false
local function in_dungeon(lx, ly, lz) return lx > -2 and lx < 126 and lz > -2 and lz < 154 and ly > -8 and ly < 15.5 end

function W.tick(t)
    -- the undo shield: Z undoes "the last user action"; one tiny hidden edit a second means the last action is never the dungeon
    if t % 45 == 0 then
        W.heart = not W.heart
        edit.voxel(G.wx(61), G.wy(-4), G.wz(75), W.heart and "dirt" or "stone")
    end
    -- the sentinel: if the lobby floor is gone anyway (many Z presses), build it all again
    if t % 120 == 60 and G.state and G.state.class then
        local m = world.material_at(G.wx(3), G.wy(-0.25), G.wz(11))
        if m ~= "marble" and m ~= "unloaded" and not G.rebuilding then
            G.rebuilding = true
            W.build()
            G.rebuilding = false
            G.announcer.say("Somebody pressed undo. The management has restored the dungeon from backup. Please do not do that again.", { prio = 1 })
        end
    end
    if t % 10 == 0 then
        local px, py, pz = player.pos()
        local lx, ly, lz = G.to_local(px, py, pz)
        if in_dungeon(lx, ly, lz) then
            if t % 30 == 0 and not G.player.dead then W.last_safe = { px, py, pz } end
        elseif G.state and G.state.class and not G.player.dead then
            local ls = W.last_safe or { W.start_position() }
            player.teleport(ls[1], ls[2], ls[3])
            G.announcer.say_key("guard.teleport", { prio = 1, key = "guard", cooldown = 300 })
        end
    end
    if t % 180 == 0 then fx.rain(false) end
    G.traps.tick_all(t)
    if W.tick_belt then W.tick_belt(t) end
    if W.arena_tick then W.arena_tick(t) end
    if W.shuttle and W.shuttle.tick then W.shuttle.tick(t) end
    if W.tick_gutter then W.tick_gutter(t) end
    if t % 15 == 0 and G.state and G.state.class and not G.player.dead then W.track_room(t) end
end

-- which room is the player in: announcements, music, safe zones, checkpoints
G.current_room = nil
local function zone(id, x0, z0, x1, z1) W.zones[#W.zones + 1] = { id = id, x0 = x0, z0 = z0, x1 = x1, z1 = z1, on_enter = function() G.player.set_checkpoint(id) end, repeatable = true } end
zone("hall", 66, 2, 72, 8); zone("boiler", 112, 20, 114, 24); zone("ballroom", 34, 80, 37, 84); zone("arena", 26.5, 108, 30, 112)
function W.track_room(t)
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local id = W.room_at(lx, lz)
    if id ~= G.current_room then
        local old = G.current_room
        G.current_room = id
        if id then W.enter_room(id, old) end
    end
    for _, z in ipairs(W.zones) do
        local inside = lx >= z.x0 and lx <= z.x1 and lz >= z.z0 and lz <= z.z1 and ly >= (z.y0 or -99) and ly <= (z.y1 or 99)
        if inside and not z.fired then z.fired = true; z.on_enter()
        elseif not inside and z.fired and z.repeatable then z.fired = false end
    end
end

function W.enter_room(id, old)
    local s, A = G.state, G.announcer
    s.flags["visited_" .. id] = true
    if id ~= "lobby" then A.award("hello_world") end
    A.say_key("room." .. id, { prio = 0, key = "room_" .. id, cooldown = 36000 })
    if id == "ballroom" then A.award("zero_g") end
    if G.music and G.music.on_room then G.music.on_room(id) end
    if id == "arena" and G.boss and not G.state.flags.boss_dead then after(120, G.boss.begin) end
    G.safe = (id == "stairwell")
    if id == "stairwell" then G.player.set_checkpoint("stairwell") end
    W.sync_active(id)
    if W.on_enter_room then W.on_enter_room(id, old) end
end

W.checkpoints = {
    lobby     = { x = 3.5, y = 0.1, z = 11 },
    hall      = { x = 68.5, y = 0.1, z = 6.5 },
    boiler    = { x = 113, y = 0.1, z = 22 },
    ballroom  = { x = 36, y = 0.1, z = 82 },
    arena     = { x = 28.5, y = 0.1, z = 110.5 },
    stairwell = { x = 58, y = 0.1, z = 132 },
}

function W.open_lobby_gate()
    if W.lobby_gate then events.command(W.lobby_gate, "open") end
end

function W.start_position()   -- where a new contestant wakes up: the west side of the lobby looking east at the gate
    return G.mx(3.5), G.my(0.1), G.mz(11)
end
