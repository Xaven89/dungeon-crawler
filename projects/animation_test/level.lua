-- Procedural animation test level (docs/ANIMATION.md). Two agents with rigged models and no clips:
--   the person (models/legged.vxm) walks up and down a staircase, its feet on the steps (two-bone IK, foot placement, planted feet, a smooth turn at the ends);
--   the animal (models/quad.vxm) wanders, and every 12 s is sent across the plaza (walk, then trot, then gallop as the agent's speed rises).
-- Every 20 s a crate falls on the person: a ragdoll rule makes it go limp, stagger and get up four seconds later.
local V = 16 -- voxels per metre
local sx, sz, gy
local person, animal, person_model, animal_model
local STEPS, STEP_D, STEP_W = 6, 6, 24
local crates = {}

local function m(vox) return vox / V end

function on_start()
    local px, py, pz = player.pos()
    sx, sz = math.floor(px * V) + 12, math.floor(pz * V) - 12
    gy = world.top(sx, sz)
    -- a staircase along +x: step i is i voxels (6 cm) higher than the ground, 6 voxels (37 cm) deep
    for i = 1, STEPS do
        edit.box(sx + (i - 1) * STEP_D, gy + 1, sz, sx + i * STEP_D - 1, gy + i, sz + STEP_W - 1, "concrete")
    end
    edit.box(sx + STEPS * STEP_D, gy + 1, sz, sx + STEPS * STEP_D + 11, gy + STEPS, sz + STEP_W - 1, "concrete") -- a landing
    edit.box(sx - 14, gy + 1, sz + STEP_W + 4, sx + 60, gy + 1, sz + STEP_W + 40, "brick") -- a low plaza for the animal
    person = agent.spawn{ x = m(sx - 8), y = m(gy + 1), z = m(sz + 12), speed = 1.3, model = "models/legged.vxm" }
    animal = agent.spawn{ x = m(sx + 20), y = m(gy + 2), z = m(sz + STEP_W + 14), speed = 1.6, model = "models/quad.vxm" }
    person_model, animal_model = person - 0x40000000, animal - 0x40000000
    -- the person goes limp when something hits it hard and gets up after four seconds
    model.procedural(person_model, { from_roles = true, turn_smoothing = 15, ragdoll = { impulse = 25, fall_time = 0.6, recover = 4 } })
    agent.walk(person, m(sx + STEPS * STEP_D + 6), m(gy + STEPS + 1), m(sz + 12))
    agent.wander(animal, 4)
    print("animation test: the person walks the stairs, the animal wanders; a crate hits the person every 20 s")
end

local forward = true
function on_agent(id, what)
    if id == person and what == "arrived" then
        forward = not forward
        if forward then agent.walk(person, m(sx + STEPS * STEP_D + 6), m(gy + STEPS + 1), m(sz + 12))
        else agent.walk(person, m(sx - 8), m(gy + 1), m(sz + 12)) end
    end
end

local ticks = 0
function on_tick()
    ticks = ticks + 1
    if ticks % 720 == 360 then -- sent across the plaza: the speed rises with the distance, so the gait goes walk, trot, gallop
        agent.speed(animal, 1.2); agent.walk(animal, m(sx + 40), m(gy + 2), m(sz + STEP_W + 14))
    elseif ticks % 720 == 0 then
        agent.speed(animal, 6.0); agent.walk(animal, m(sx - 10), m(gy + 2), m(sz + STEP_W + 30))
    end
    if ticks % 1200 == 600 then -- a crate on the person
        local info = agent.info(person)
        if info then
            local id = body.box(info.x, info.y + 1.6, info.z, 6, 6, 6, "wood")
            body.push(id, 0, -600, 0)
            crates[#crates + 1] = id
            if #crates > 4 then body.remove(table.remove(crates, 1)) end
        end
    end
end
