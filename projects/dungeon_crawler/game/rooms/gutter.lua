-- E: the Gutter. A flooded sewer: toxic water between narrow walkways, slimes and rats. The gold crate on the island floods the room when it is opened.
Game = Game or {}
local G = Game
local W, T, E = G.world, G.traps, G.enemies
local R = W.rooms.gutter

local walkways = {      -- { x0, z0, x1, z1 } (metres, local): the dry paths, 2 m wide
    { 114, 70, 122, 76 }, { 116, 76, 118.4, 82 }, { 100, 80, 118.4, 82.4 }, { 100, 80, 102.4, 92 }, { 84, 90, 102.4, 92.4 },
    { 80, 82, 86.4, 84.4 }, { 84, 82, 86.4, 92.4 }, { 102, 86, 108, 88 }, { 108, 83, 114, 93 },
}
W.gutter_level = -0.2

W.builders[#W.builders + 1] = function()
    G.room{ x = R.x, z = R.z, w = R.w, d = R.d, h = R.h, floor = "flagstone", wall = "mossy", ceil = "dungeon_brick", wtex = "big_bricks", ctex = "blocks" }
    -- the sunken channel: the whole floor goes down 1.5 m and fills with toxic water
    G.clear(80, -1.5, 70, 122, 0, 96)
    G.fill(80, -2, 70, 122, -1.5, 96, "flagstone")
    G.fill(80, -1.5, 70, 122, -0.2, 96, "gutter_water")
    for _, w in ipairs(walkways) do
        G.fill(w[1], -1.5, w[2], w[3], 0, w[4], "flagstone", "tiles")
        G.fill(w[1], 0, w[2], w[1] + 0.12, 0.2, w[4], "metal"); G.fill(w[3] - 0.12, 0, w[2], w[3], 0.2, w[4], "metal")
    end
    -- the island with the crate, a little pavilion roof on pillars
    G.fill(108, 0, 83, 114, 0.4, 93, "marble", "tiles")
    -- pipes across the ceiling and a few leaking ones: thin green streams into the water
    for z = 74, 94, 8 do G.fill(80, 6.0, z, 122, 6.6, z + 0.6, "metal") end
    for _, p in ipairs({ { 96, 78 }, { 110, 74 }, { 90, 88 }, { 104, 94 } }) do
        G.fill(p[1], -0.2, p[2], p[1] + 0.25, 6.0, p[2] + 0.25, "toxic")
        G.fill(p[1] - 0.2, 5.4, p[2] - 0.2, p[1] + 0.45, 6.2, p[2] + 0.45, "metal")
    end
    G.text(81, 4.8, 96, "THE GUTTER - NO LIFEGUARD ON DUTY", { facing = "-z", material = "toxic", size = 1, depth = 1 })
    W.openings[#W.openings + 1] = { 114, 0, 69.7, 122, 6, 70.3 }
    -- the exit west, to the Ballroom
    G.corridor{ x = 76, z = 82, len = 4, w = 4, h = 4.2, axis = "x", floor = "flagstone", wall = "dungeon_brick", wtex = "blocks" }
    W.openings[#W.openings + 1] = { 79.6, 0, 80, 80.4, 4.2, 84 }
    W.openings[#W.openings + 1] = { 75.6, 0, 80, 76.4, 4.2, 84 }
end

local function set_level(y)
    -- the water rises (or falls) to y: a slab of water over the whole channel, only into air / out of water
    if y > W.gutter_level then
        G.vfill(80 * 16, math.floor(W.gutter_level * 16) + 1, 70 * 16, 122 * 16 - 1, math.floor(y * 16), 96 * 16 - 1, "gutter_water")
    else
        G.vclear(80 * 16, math.floor(y * 16) + 1, 70 * 16, 122 * 16 - 1, math.floor(W.gutter_level * 16), 96 * 16 - 1)
        -- the walkways stay (only water was cleared above them; the stone is below y = 0)
    end
    W.gutter_level = y
end

function W.start_flood()
    if W.flooding or G.state.flags.gutter_flooded then return end
    W.flooding = { t0 = time.tick() }
    G.announcer.say_key("trap.water", { prio = 1 })
    G.sfx.play("rumble", 100, 1, 82)
end

function W.tick_gutter(t)
    local f = W.flooding
    if f then
        local age = t - f.t0
        if age % 20 == 0 and age <= 840 then
            local target = -0.2 + 1.5 * math.min(1, age / 840)
            set_level(target)
        elseif age > 1500 and age % 20 == 0 then
            local target = math.max(-0.2, W.gutter_level - 0.15)
            if target < W.gutter_level then set_level(target) end
            if target <= -0.2 then W.flooding = nil; G.state.flags.gutter_flooded = true end
        end
    end
    -- the water hurts a little (toxic): it is the gutter
    if t % 40 == 0 and G.current_room == "gutter" then
        local px, py, pz = player.pos()
        local lx, ly, lz = G.to_local(px, py, pz)
        if ly < W.gutter_level + 0.3 and ly > -1.8 then
            G.player.hurt(4, "toxic sludge", { pierce = true })
            if not G.state.counters.soggy then G.state.counters.soggy = 1; G.announcer.award("soggy") end
        end
    end
end

W.things[#W.things + 1] = function()
    for _, p in ipairs({ { 96, 78 }, { 110, 74 }, { 90, 88 }, { 104, 94 } }) do
        G.torch(p[1] + 0.1, 1.5, p[2] + 0.1, { color = { 0.3, 1.0, 0.25 }, reach = 11, preset = "fireflies", name = "gutter_glow_" .. p[1] })
    end
    G.brazier(111, 88, { reach = 10, color = { 0.5, 1, 0.4 } })
    for _, z in ipairs({ 74, 88 }) do G.sconce(80, 3.2, z, "+x") ; G.sconce(122, 3.2, z, "-x") end
    emitter.create{ name = "gutter_mist", preset = "steam_vent", pos = { G.mx(100), G.my(0), G.mz(86) }, rate = 12, size = { 12, 0.3, 4 } }
    T.hazard("water", 80, -2, 70, 122, 0.4, 96)
    T.crate("gutter_gold", "gold", 110.2, 0.4, 87.4, "-x")
    local node = events.find("crate_gutter_gold")
    if node and node ~= 0 then events.on(node, "pressed", function() after(30, W.start_flood) end) end
    W.populate_list.gutter = {
        { "slime_toxic", 117, 73 }, { "slime_toxic", 109, 81 }, { "slime_toxic", 93, 91 }, { "slime_toxic", 85, 86 },
        { "rat", 112, 82 }, { "rat", 101, 84 }, { "rat", 95, 91 }, { "rat", 118, 79 },
        { "intern", 105, 81, 0 }, { "spitter", 110, 90, 0.4 }, { "spitter", 100, 91 },
    }
end
