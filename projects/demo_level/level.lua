-- "Moon pool": a ten minute tour of what the engine does, built from this one script (see docs/LUA_API.md).
-- Everything is placed relative to where the player starts, so it works on any seed. Edits are in voxels (1/16 m), gravity in metres.
local V = units.vox

local function build_arena(x, y, z)
    -- a stone floor with a wall around it, 28 x 28 m
    edit.box(x, y - 8, z, x + V(28), y - 1, z + V(28), "concrete")
    edit.box(x, y, z, x + V(28), y + V(2), z + 1, "brick")
    edit.box(x, y, z + V(28) - 1, x + V(28), y + V(2), z + V(28), "brick")
    edit.box(x, y, z, x + 1, y + V(2), z + V(28), "brick")
    edit.box(x + V(28) - 1, y, z, x + V(28), y + V(2), z + V(28), "brick")
end

-- the arena's floor is concrete: once it is in the saved world, that is where the arena stands
local function floor_y(x, z, y0)
    for y = y0 + 400, y0 - 400, -1 do
        if world.material_at(x, y, z) == "concrete" then return y end
    end
end

function on_start()
    local px, py, pz = player.pos()
    local ox, oz = math.floor(V(px)) - V(40), math.floor(V(pz)) - V(14) -- west of the spawn, clear of the tower
    local cx, cz = ox + V(14), oz + V(14)
    -- With a world save (save = world.vxs in project.cfg) the second run starts from what the first one built: the world is built once, everything that is not a voxel
    -- (the gravity field, timers, the faucet, props, characters) is set up on every run.
    local first = project.first_run()
    local oy = (first and world.top(cx, cz) or floor_y(cx, cz, math.floor(V(py))) or world.top(cx, cz)) + 1 -- the arena stands on the ground at its middle

    if first then
        edit.box(ox, oy - V(6), oz, ox + V(28), oy - 1, oz + V(28), "concrete") -- on a block down to the lowest ground under it
        edit.clear(ox, oy, oz, ox + V(28), oy + V(14), oz + V(28)) -- the arena is dug out of whatever hill it stands on
        build_arena(ox, oy, oz)

        -- 1. a tank of water on stilts-free plinth, with a glass front: dig the wall (LMB) and the water runs out
        edit.box(ox + V(2), oy, oz + V(2), ox + V(10), oy + V(5), oz + V(10), "stone")
        edit.clear(ox + V(2) + 2, oy + 2, oz + V(2) + 2, ox + V(10) - 2, oy + V(5), oz + V(10) - 2)
        edit.box(ox + V(2) + 2, oy + 2, oz + V(2) + 2, ox + V(10) - 2, oy + V(4), oz + V(10) - 2, "water")
        edit.box(ox + V(3), oy + V(1), oz + V(10) - 2, ox + V(9), oy + V(3), oz + V(10), "glass")

        -- 2. a lava trough: when the flood reaches it, steam and stone
        edit.box(ox + V(16), oy, oz + V(2), ox + V(26), oy + V(2), oz + V(10), "stone")
        edit.clear(ox + V(16) + 2, oy + 2, oz + V(2) + 2, ox + V(26) - 2, oy + V(2), oz + V(10) - 2)
        edit.box(ox + V(16) + 2, oy + 2, oz + V(2) + 2, ox + V(26) - 2, oy + V(1) + 8, oz + V(10) - 2, "lava")

        -- 3. a wooden tower: set it alight (B) or blow its foot out (F) and watch it burn and fall
        edit.box(ox + V(4), oy, oz + V(18), ox + V(7), oy + V(9), oz + V(21), "wood")
        edit.sphere(ox + V(5), oy + V(10), oz + V(19), V(2), "leaves")

        -- the flip room's glass walls
        edit.box(ox + V(16), oy, oz + V(17), ox + V(24), oy + V(8), oz + V(25), "glass")
        edit.clear(ox + V(16) + 2, oy + 2, oz + V(17) + 2, ox + V(24) - 2, oy + V(8) - 2, oz + V(25) - 2)

        -- 5. events: a lamp post and a button plate on a plinth (aim at the plate and press E; the lamp is a stone block that turns into glowing neon)
        edit.box(ox + V(11), oy, oz + V(14), ox + V(11) + 5, oy + 15, oz + V(14) + 5, "stone")
        edit.box(ox + V(11) + 1, oy + 16, oz + V(14) + 1, ox + V(11) + 4, oy + 19, oz + V(14) + 4, "metal")
        edit.box(ox + V(13), oy, oz + V(14), ox + V(13) + 2, oy + 60, oz + V(14) + 2, "metal")
        edit.box(ox + V(13) - 2, oy + 61, oz + V(14) - 2, ox + V(13) + 4, oy + 67, oz + V(14) + 4, "stone")
        -- a wooden gate in front of the plinth that swings open about its west edge (the same button opens and closes it)
        edit.box(ox + V(10), oy, oz + V(10), ox + V(10) + 23, oy + 19, oz + V(10) + 1, "wood")
    end

    -- 5. events (every run: the nodes are declared by name, the world keeps the voxels): the button toggles the lamp
    do
        local btn = events.button{ name = "arena_button", prompt = "Light the lamp", on = "neon", off = "metal", press_ticks = 12,
                                   box = {ox + V(11) + 1, oy + 16, oz + V(14) + 1, ox + V(11) + 4, oy + 19, oz + V(14) + 4} }
        local lamp = events.lamp{ name = "arena_lamp", on = "neon", off = "stone", radiance = {30, 28, 24},
                                  box = {ox + V(13) - 2, oy + 61, oz + V(14) - 2, ox + V(13) + 4, oy + 67, oz + V(14) + 4} }
        events.connect(btn, "pressed", lamp, "toggle")
        local gate = events.door{ name = "arena_gate", material = "wood",
                                  box = {ox + V(10), oy, oz + V(10), ox + V(10) + 23, oy + 19, oz + V(10) + 1},
                                  hinge = { axis = "y", at = {ox + V(10), oy, oz + V(10)}, open = 90, seconds = 0.8 } }
        events.connect(btn, "pressed", gate, "toggle")
        -- a door from the prefab kit (models/door.prefab.lua): a glass panel in a metal frame, a plate in front of it; every run places it again (adopted when the world already has it)
        prefab.place("door", ox + V(16), oy, oz + V(7), { name = "arena_door", slots = { panel = "glass" }, params = { seconds = 1.0 } })
    end

    -- 4. gravity: a room where up is somewhere else, and a switch that flips it every ten seconds
    flip = gravity.add{type = "uniform", name = "moon pool flip room", dir = {0, -1, 0}, strength = 9.81, priority = 20,
                       pos = {units.m(ox + V(20)), units.m(oy) + 4, units.m(oz + V(21))}, half = {4, 4, 4}}
    local up = false
    every(600, function()
        up = not up
        gravity.retarget(flip, {0, up and 1 or -1, 0}, 9.81)
    end)

    -- 5. props: a wooden crate and a stone ball for the flood
    body.box(units.m(ox + V(12)), units.m(oy) + 2, units.m(oz + V(14)), 16, 16, 16, "wood")
    body.ball(units.m(ox + V(14)), units.m(oy) + 2, units.m(oz + V(15)), 8, "stone")

    -- 6. a faucet, and rain after a minute
    liquid.source(ox + V(13), oy + V(3), oz + V(13), "water", 12)
    after(3600, function() fx.rain(true) end)
    after(5400, function() fx.rain(false) end)

    -- 7. rigged characters from the model editor (parts, pivots, clips): one walks on the spot, one waves; they are driven bodies, so crates bounce off them.
    --    The statue is the same model as a static prefab: tracked, re-stamped when its file changes (a saved world adopts it instead of stamping it again).
    prefab.place("models/walker.vxm", ox + V(7), oy, oz + V(26), 0, "statue")
    local walker = model.spawn("models/walker.vxm", ox + V(10), oy, oz + V(26))
    model.play(walker, "walk")
    local waver = model.spawn("models/walker.vxm", ox + V(12.5), oy, oz + V(26))
    model.play(waver, "wave")
    -- 8. a lamp post and a crate from the asset kit
    prefab.place("models/lantern_post.vxm", ox + V(2), oy, oz + V(13), 0, "lamp")
    prefab.place("models/bench.vxm", ox + V(20), oy, oz + V(12), 0, "bench")

    player.teleport(units.m(ox) + 13, units.m(oy) + 0.2, units.m(oz) + 4) -- inside the wall, in the gap between the tank and the lava trough
    print("Moon pool " .. (first and "built" or "restored from the save") .. " at " .. ox .. ", " .. oy .. ", " .. oz)
end
