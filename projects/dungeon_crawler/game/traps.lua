-- traps: things that are not enemies but still want you dead (or rich): loot crates, explosive barrels, the boulder, lava and water hazards, levers, plates, the secret wall.
-- Also the interaction registry the HUD uses for its "[E] ..." prompts (the engine's own hint line is part of its debug HUD).
Game = Game or {}
local G = Game
local T = {}
G.traps = T
local floor, max, min = math.floor, math.max, math.min

T.interact = {}      -- { name, x, y, z (local metres), radius, prompt, active = function }
T.barrels = {}
T.hazards = {}
T.plates = {}

function T.add_interact(name, lx, ly, lz, prompt, radius, active)
    T.interact[#T.interact + 1] = { name = name, x = lx, y = ly, z = lz, prompt = prompt, radius = radius or 2.6, active = active }
end

-- the prompt to show now: the nearest active interactable within reach and roughly in front
function T.current_prompt()
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local fx, fy, fz = player.forward()
    local best, bd = nil, 1e9
    for _, it in ipairs(T.interact) do
        if not it.active or it.active() then
            local dx, dy, dz = it.x - lx, it.y - (ly + 1.2), it.z - lz
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < it.radius + 1.2 then
                local dot = (dx * fx + dy * fy + dz * fz) / max(d, 0.01)
                if dot > 0.3 and d < bd then best, bd = it, d end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------------------------- loot crates ("Crates of Consequence")
local tier_paint = { bronze = "brown", silver = "silver", gold = "gold", platinum = "cyan" }
local tier_glow = { bronze = "lantern", silver = "rune", gold = "lantern", platinum = "neon" }

-- a chest 1.25 x 0.75 x 0.75 m at (lx, lz) on the floor level ly, its lock facing `face` ("+z" "-z" "+x" "-x")
local function chest_voxels(tier, lx, ly, lz, face, open)
    local ox, oy, oz = G.wx(lx), G.wy(ly), G.wz(lz)
    local alongx = (face == "+z" or face == "-z")
    local lx_, lz_ = alongx and 20 or 12, alongx and 12 or 20            -- voxel extents
    local function B(x0, y0, z0, x1, y1, z1, mat, paint)
        local ax, az, bx, bz = x0, z0, x1, z1
        edit.box(ox + ax, oy + y0, oz + az, ox + bx, oy + y1, oz + bz, mat)
        if paint then edit.paint_box(ox + ax, oy + y0, oz + az, ox + bx, oy + y1, oz + bz, paint) end
    end
    B(0, 0, 0, lx_ - 1, 8, lz_ - 1, "dark_wood")                          -- the body
    if open then
        B(1, 8, 1, lx_ - 2, 8, lz_ - 2, "gold")
        B(0, 9, 0, lx_ - 1, 11, 1, "dark_wood")                           -- the lid, standing open at the back
    else
        B(0, 9, 0, lx_ - 1, 10, lz_ - 1, "dark_wood")                      -- the lid
        B(1, 11, 1, lx_ - 2, 11, lz_ - 2, "dark_wood")
    end
    -- bands in the tier's colour
    local c = tier_paint[tier]
    if alongx then
        B(3, 0, 0, 4, 10, lz_ - 1, "metal", c); B(lx_ - 5, 0, 0, lx_ - 4, 10, lz_ - 1, "metal", c)
    else
        B(0, 0, 3, lx_ - 1, 10, 4, "metal", c); B(0, 0, lz_ - 5, lx_ - 1, 10, lz_ - 4, "metal", c)
    end
    -- the lock (the button): 2 x 2 x 1 on the front face
    local lockbox
    if face == "+z" then lockbox = { ox + 9, oy + 6, oz + lz_, ox + 10, oy + 7, oz + lz_ }
    elseif face == "-z" then lockbox = { ox + 9, oy + 6, oz - 1, ox + 10, oy + 7, oz - 1 }
    elseif face == "+x" then lockbox = { ox + lx_, oy + 6, oz + 9, ox + lx_, oy + 7, oz + 10 }
    else lockbox = { ox - 1, oy + 6, oz + 9, ox - 1, oy + 7, oz + 10 } end
    if not open then edit.box(lockbox[1], lockbox[2], lockbox[3], lockbox[4], lockbox[5], lockbox[6], tier_glow[tier]) end
    return lockbox
end

-- id: a unique name (saved in state.opened); tier: bronze | silver | gold | platinum
function T.crate(id, tier, lx, ly, lz, face)
    local opened = G.state.opened[id]
    local lockbox
    if G.should_build() then lockbox = chest_voxels(tier, lx, ly, lz, face or "+z", opened)
    else
        -- the lock's place again, to declare the button on a loaded world
        local alongx = (face == "+z" or face == "-z")
        local lx_, lz_ = alongx and 20 or 12, alongx and 12 or 20
        local ox, oy, oz = G.wx(lx), G.wy(ly), G.wz(lz)
        if face == "+z" or face == nil then lockbox = { ox + 9, oy + 6, oz + lz_, ox + 10, oy + 7, oz + lz_ }
        elseif face == "-z" then lockbox = { ox + 9, oy + 6, oz - 1, ox + 10, oy + 7, oz - 1 }
        elseif face == "+x" then lockbox = { ox + lx_, oy + 6, oz + 9, ox + lx_, oy + 7, oz + 10 }
        else lockbox = { ox - 1, oy + 6, oz + 9, ox - 1, oy + 7, oz + 10 } end
    end
    if opened then return end
    local node = events.button{ name = "crate_" .. id, box = lockbox, prompt = "Open the " .. G.items.tiers[tier].name, on = "neon", off = tier_glow[tier], press_ticks = 10 }
    events.on(node, "pressed", function() T.open_crate(id, tier, lx, ly, lz, face) end)
    local cx, cz = lx + 0.6, lz + 0.4
    T.add_interact("crate_" .. id, cx, ly + 0.5, cz, "Open the " .. G.items.tiers[tier].name, 2.4, function() return not G.state.opened[id] end)
    -- a faint light so that it can be found in the dark
    T.crate_lights = T.crate_lights or {}
    G.torch(cx, ly + 1.4, cz, { preset = "magic_sparks", reach = 5, color = ({ bronze = { 1, .6, .3 }, silver = { .7, .7, 1 }, gold = { 1, .85, .3 }, platinum = { .4, 1, 1 } })[tier], name = "crate_light_" .. id })
end

function T.open_crate(id, tier, lx, ly, lz, face)
    local s = G.state
    if s.opened[id] then return end
    s.opened[id] = true
    local tdef = G.items.tiers[tier]
    local A = G.announcer
    -- open it: replace the lid, show the gold
    chest_voxels(tier, lx, ly, lz, face or "+z", true)
    local cx, cy, cz = G.mx(lx + 0.6), G.my(ly + 0.8), G.mz(lz + 0.4)
    fx.play("confetti", floor(units.vox(cx)), floor(units.vox(cy)), floor(units.vox(cz)), 1.2)
    if emitter.find("crate_light_" .. id) then emitter.burst("crate_light_" .. id, 60) end
    G.sfx.play("crate_open", lx + 0.6, ly + 0.8, lz + 0.4)
    A.say_key("box." .. tier, { prio = 1 })
    local n = G.irange(tdef.rolls[1], tdef.rolls[2])
    local gold = G.irange(tdef.gold[1], tdef.gold[2])
    G.enemies.drop(cx, cy + 0.3, cz, "gold", gold)
    for i = 1, n do
        local item = G.items.roll(tier, i * 31 + #id)
        if tier == "platinum" and i == 1 then item = ({ "excalibur", "tux", "spoon" })[1 + (s.level or 1) % 3] end
        G.enemies.drop(cx + G.range(-0.4, 0.4), cy + 0.2 * i, cz + G.range(-0.4, 0.4), "item", item)
    end
    local cnt = A.bump("crates")
    if cnt >= 5 then A.award("loot_goblin") end
    if tier == "gold" or tier == "platinum" then A.award("crate_exp") end
    G.save()
end

-- ---------------------------------------------------------------------------------------------- explosive barrels
function T.barrel(lx, ly, lz)
    -- a barrel: a stack of rings 0.6 m wide, 0.85 m high (voxels, built once; the explosion carves it away)
    if G.should_build() then
        local x, y, z = G.wx(lx), G.wy(ly), G.wz(lz)
        edit.box(x - 4, y, z - 4, x + 4, y + 13, z + 4, "dark_wood")
        edit.box(x - 5, y + 2, z - 4, x + 5, y + 3, z + 4, "metal"); edit.box(x - 4, y + 2, z - 5, x + 4, y + 3, z + 5, "metal")
        edit.box(x - 5, y + 10, z - 4, x + 5, y + 11, z + 4, "metal"); edit.box(x - 4, y + 10, z - 5, x + 4, y + 11, z + 5, "metal")
        edit.box(x - 2, y + 14, z - 2, x + 2, y + 14, z + 2, "hazard_y")
        edit.paint_box(x - 5, y, z - 5, x + 5, y + 14, z + 5, "dark_red")
        edit.paint_box(x - 5, y + 2, z - 5, x + 5, y + 3, z + 5, "dark_slate"); edit.paint_box(x - 5, y + 10, z - 5, x + 5, y + 11, z + 5, "dark_slate")
    end
    T.barrels[#T.barrels + 1] = { x = lx, y = ly + 0.45, z = lz, alive = true }
end

function T.explode_barrel(b, by_chain)
    if not b.alive then return end
    b.alive = false
    local wx, wy, wz = G.mx(b.x), G.my(b.y), G.mz(b.z)
    fx.explosion(floor(units.vox(wx)), floor(units.vox(wy)), floor(units.vox(wz)), 26, 1.2)
    G.sfx.play("explosion", b.x, b.y, b.z, 1.0)
    G.announcer.say_key("trap.barrel", { key = "barrel", cooldown = 3600 })
    -- the blast hurts what is near, and sets off the next barrels
    G.enemies.damage_area(wx, wy, wz, 4.5, 70, "barrel")
    local px, py, pz = player.pos()
    local d = G.dist3(px, py + 0.9, pz, wx, wy, wz)
    if d < 4.5 then G.player.hurt(floor(40 * (1 - d / 5.5)) + 8, "an explosive barrel", { pierce = true }) end
    for _, o in ipairs(T.barrels) do
        if o.alive and G.dist3(o.x, o.y, o.z, b.x, b.y, b.z) < 2.6 then after(8, function() T.explode_barrel(o, true) end) end
    end
    if T.secret_wall and not T.secret_wall.opened and G.dist3(b.x, b.y, b.z, T.secret_wall.x, T.secret_wall.y, T.secret_wall.z) < 4 then
        T.reveal_secret()
    end
end

-- an explosion (a firecracker, a fire bolt) at world metres sets off barrels within 3 m
function T.blast(wx, wy, wz, r)
    for _, b in ipairs(T.barrels) do
        if b.alive and G.dist3(G.mx(b.x), G.my(b.y), G.mz(b.z), wx, wy, wz) < (r or 3) then after(4, function() T.explode_barrel(b) end) end
    end
end

-- the player's swing: a barrel or a secret hairline crack within reach in front
function T.swing_at(reach)
    local px, py, pz = player.pos()
    local fx_, fy_, fz_ = player.forward()
    for _, b in ipairs(T.barrels) do
        if b.alive then
            local bx, by, bz = G.mx(b.x), G.my(b.y), G.mz(b.z)
            local dx, dy, dz = bx - px, by - (py + 1.2), bz - pz
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < reach + 0.5 and (dx * fx_ + dy * fy_ + dz * fz_) / max(d, 0.01) > 0.5 then T.explode_barrel(b); return true end
        end
    end
    return false
end

function T.secret(name, lx, ly, lz, wall_box)
    T.secret_wall = { x = lx, y = ly, z = lz, opened = G.state.flags["secret_" .. name] or false, name = name }
end

function T.reveal_secret()
    local s = T.secret_wall
    if s.opened then return end
    s.opened = true
    G.state.flags["secret_" .. s.name] = true
    G.announcer.say_key("room.secret", { prio = 1 })
    G.announcer.award("fine_print")
    G.player.popup("SECRET FOUND", "#ffd24a", true)
    G.save()
end

-- ---------------------------------------------------------------------------------------------- hazards: a box (local metres) that hurts whoever stands in it
-- kind: "lava" (burns), "water" (wet: only the achievement), "fire"
function T.hazard(kind, x0, y0, z0, x1, y1, z1, dmg)
    T.hazards[#T.hazards + 1] = { kind = kind, x0 = x0, y0 = y0, z0 = z0, x1 = x1, y1 = y1, z1 = z1, dmg = dmg or 25 }
end

function T.tick(t)
    if t % 6 ~= 0 then return end
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py + 0.2, pz)
    for _, h in ipairs(T.hazards) do
        if lx >= h.x0 and lx <= h.x1 and ly >= h.y0 and ly <= h.y1 and lz >= h.z0 and lz <= h.z1 then
            if h.kind == "lava" then
                if t % 18 == 0 then G.player.hurt(h.dmg, "the lava", { pierce = true }); fx.play("sparks", floor(units.vox(px)), floor(units.vox(py)), floor(units.vox(pz)), 1.0) end
                if not T.lava_said then T.lava_said = true; G.announcer.say_key("trap.lava", { prio = 1, key = "lava", cooldown = 3000 }) end
            elseif h.kind == "water" then
                if not G.state.counters.soggy then G.state.counters.soggy = 1; G.announcer.award("soggy") end
            end
        end
    end
    for _, b in ipairs(T.plates) do
        if b.tick then b.tick(t, px, py, pz) end
    end
end

-- ---------------------------------------------------------------------------------------------- the boulder
-- a stone ball rolled from `from` (local metres) towards `dir` (x, z); hurts the player and enemies it touches
T.boulder = nil
function T.release_boulder(fx_, fy, fz, dx, dz, radius_vox, speed)
    local r = radius_vox or 24
    local id = body.ball(G.mx(fx_), G.my(fy), G.mz(fz), r, "stone")
    -- impulse: a ball of r voxels weighs about 0.4 kg a voxel
    local mass = 2.78 * r * r * r
    body.push(id, dx * mass * (speed or 7), 0, dz * mass * (speed or 7))
    T.boulder = { id = id, born = time.tick(), hit_player = false, radius = r / 16, dx = dx, dz = dz }
    G.sfx.play("rumble", fx_, fy, fz, 1.0)
    G.announcer.say_key("trap.boulder", { prio = 1, key = "boulder", cooldown = 3000 })
end

function T.tick_boulder(t)
    local b = T.boulder
    if not b then return end
    local x, y, z, ok = body.pos(b.id)
    if not ok or t - b.born > 900 then
        if ok then body.remove(b.id) end
        T.boulder = nil
        return
    end
    -- keep it rolling for the first seconds (friction eats the push)
    local px, py, pz = player.pos()
    if t - b.born < 300 and t % 6 == 0 then
        local mass = 2.78 * (b.radius * 16) ^ 3
        body.push(b.id, b.dx * mass * 0.9, 0, b.dz * mass * 0.9)
    end
    if G.dist3(x, y, z, px, py + 0.9, pz) < b.radius + 0.7 and not b.hit_player then
        b.hit_player = true
        G.player.hurt(45, "a boulder", { pierce = true })
        if G.state.counters.boulder_ok then G.state.counters.boulder_ok = nil end
    end
    for _, inst in pairs(G.enemies.list) do
        if not inst.dead then
            local ix, iy, iz = G.enemies.position(inst)
            if ix and G.dist3(ix, iy + 0.8, iz, x, y, z) < b.radius + 0.6 then G.enemies.damage(inst, 80, { source = "boulder" }) end
        end
    end
    if t % 30 == 0 then G.sfx.play("rumble", G.to_local(x, y, z)) end
end

function T.tick_all(t)
    T.tick(t)
    T.tick_boulder(t)
end
