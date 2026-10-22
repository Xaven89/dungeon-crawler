-- Conveyor belt test: a belt 8 m long and 1.5 m wide on a low concrete table, its surface drawn as dark and light stripes that move at the belt's speed,
-- and crates that a script carries along at that speed. Built from what the engine has today (docs/CONVEYOR.md): there is no "surface velocity" in the physics,
-- so a crate on the belt is pushed with an impulse each tick towards the belt's speed (friction holds it on the belt, the push does the carrying).
local V = units.vox

local SPEED = 1.0          -- belt speed in m/s (along +x); change it at run time with belt.speed(...)
local LENGTH, WIDTH = 128, 24   -- voxels (8 m x 1.5 m)
local TABLE = 8            -- height of the concrete table under the belt, voxels
local STRIPE = 4           -- the stripes are 4 voxels long, a period is 8
local CRATE = 6            -- crate edge, voxels
local CRATE_MASS = CRATE * CRATE * CRATE * 0.1875   -- kg: a wooden voxel weighs 187.5 g here (a 6-voxel crate: 40.5 kg, `bodies` shows mass_kg)
local MAX_CRATES, SPAWN_EVERY = 4, 240   -- one crate every 4 s while fewer than 4 ride

local x0, z0, gy             -- the belt's minimum corner (voxels) and the ground's top
local crates = {}            -- id -> { last = {x, y, z} }
local phase = -1
local running = true

local function belt_top() return gy + TABLE + 2 end   -- the belt's top voxel layer

local function draw_belt(p)
    -- a light surface with dark stripes shifted by p voxels along +x: the stripes seem to travel with the belt
    local y0, y1 = gy + TABLE + 1, gy + TABLE + 2
    edit.box(x0, y0, z0, x0 + LENGTH - 1, y1, z0 + WIDTH - 1, "stone")
    local period = STRIPE * 2
    for s = -1, math.ceil(LENGTH / period) do
        local a = x0 + s * period + (p % period)
        local lo, hi = math.max(a, x0), math.min(a + STRIPE - 1, x0 + LENGTH - 1)
        if hi >= lo then edit.box(lo, y0, z0, hi, y1, z0 + WIDTH - 1, "metal") end
    end
end

local function build()
    local px, py, pz = player.pos()
    x0, z0 = math.floor(V(px)) + V(6), math.floor(V(pz)) - V(1)
    gy = world.top(x0, z0)
    edit.box(x0 - 2, gy + 1, z0 - 2, x0 + LENGTH + 1, gy + TABLE, z0 + WIDTH + 1, "concrete")             -- the table
    edit.box(x0 - 2, gy + TABLE + 1, z0 - 2, x0 + LENGTH + 1, gy + TABLE + 4, z0 - 1, "brick")            -- the two side rails
    edit.box(x0 - 2, gy + TABLE + 1, z0 + WIDTH, x0 + LENGTH + 1, gy + TABLE + 4, z0 + WIDTH + 1, "brick")
    edit.box(x0 - 2, gy + TABLE + 1, z0 - 2, x0 - 1, gy + TABLE + 4, z0 + WIDTH + 1, "brick")            -- a stop at the start end only
    phase = 0
    draw_belt(0)
end

local function spawn_crate()
    local cx = (x0 + 12) / 16
    local cz = (z0 + WIDTH / 2) / 16
    local cy = (belt_top() + 1 + CRATE / 2) / 16 + 0.02
    local id = body.box(cx - CRATE / 32, cy - CRATE / 32, cz - CRATE / 32, CRATE, CRATE, CRATE, "wood")
    crates[id] = { last = nil }
end

function on_start()
    build()
    print("conveyor test: crates ride the belt at " .. SPEED .. " m/s (belt.speed(v), belt.stop(), belt.start())")
end

local function carry(id, c)
    local x, y, z, ok = body.pos(id)
    if not ok then crates[id] = nil return end
    local tx = x0 / 16
    if x > (x0 + LENGTH) / 16 + 0.8 or y < (gy + TABLE) / 16 + 0.05 then body.remove(id) crates[id] = nil return end -- (it fell off the end onto the ground: taken away)
    if c.last then
        c.v = (c.v or 0) * 0.9 + (x - c.last[1]) * 60 * 0.1   -- the speed along the belt, smoothed over a few ticks (a crate rocks a little)
        local on = x >= tx and x <= (x0 + LENGTH) / 16 and z >= z0 / 16 and z <= (z0 + WIDTH) / 16 and y < (belt_top() + CRATE * 2) / 16
        if on and running then
            c.i = math.max(-0.5, math.min(1.0, (c.i or 0) + (SPEED - c.v) * 0.004))   -- what friction eats, learned: the push aims a little above the belt's speed
            body.push(id, CRATE_MASS * (SPEED * (1 + c.i) - c.v) * 0.5, 0, 0, x, y - CRATE / 32, z) -- pushed where the belt touches the crate (a push at the middle tips it)
        end
    end
    c.last = { x, y, z }
end

function on_tick(t)
    if running then
        local p = math.floor(t * SPEED * 16 / 60)    -- how many voxels the belt has moved
        if p ~= phase then phase = p draw_belt(p) end
    end
    local n = 0
    for id, c in pairs(crates) do carry(id, c) n = n + 1 end
    if running and t % SPAWN_EVERY == 1 and n < MAX_CRATES then spawn_crate() end
end

belt = {
    speed = function(v) SPEED = v end,   -- belt.speed(2.0) from the console / the lua MCP tool
    stop = function() running = false end,
    start = function() running = true end,
}
