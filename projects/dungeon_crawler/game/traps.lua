-- traps: things that are not enemies but still want you dead (or rich): loot crates, explosive barrels, the boulder, lava and water hazards, levers, plates, the secret wall.
-- Also the interaction registry the HUD uses for its "[E] ..." prompts (the engine's own hint line is part of its debug HUD).
Game = Game or {}
local G = Game
local T = {}
G.traps = T
local floor, max, min = math.floor, math.max, math.min

T.interact = {}      -- { name, x, y, z (local metres), radius, prompt, active = function }
T.crate_loot = {}    -- crate id -> a list of item ids that replaces the tier's loot (a sponsor's joke)
T.crate_hooks = {}   -- crate id -> function run when it is opened (events.on keeps only ONE callback per node: see ENGINE_FEEDBACK.md)
T.barrels = {}
T.hazards = {}
T.plates = {}

-- a cell of a big floor goes: forget what it registered (its event nodes, emitters and bodies go through gen/track.lua)
function T.drop_cell(id)
    local function keep(list) local out = {}; for _, e in ipairs(list or {}) do if e.cell ~= id then out[#out + 1] = e elseif e.body then pcall(body.remove, e.body) end end return out end
    T.interact, T.barrels, T.hazards, T.floating_list = keep(T.interact), keep(T.barrels), keep(T.hazards), keep(T.floating_list)
    for cid_, c in pairs(T.crates or {}) do
        if c.cell == id then
            T.crates[cid_] = nil
            for i, ch in ipairs(T.all_chests) do if ch.id == cid_ then table.remove(T.all_chests, i); break end end
        end
    end
end

-- a new floor: forget everything the old one registered (the nodes and bodies themselves go through gen/track.lua)
function T.reset()
    T.crate_loot = {}
    T.interact, T.crates, T.all_chests, T.crate_hooks, T.barrels, T.hazards, T.plates, T.doors = {}, {}, {}, {}, {}, {}, {}, nil
    T.floating_list, T.secret_wall, T.boulder = {}, nil, nil
    G.texts = {}
end

function T.add_interact(name, lx, ly, lz, prompt, radius, active)
    T.interact[#T.interact + 1] = { cell = T.cell, name = name, x = lx, y = ly, z = lz, prompt = prompt, radius = radius or 2.6, active = active }
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
local function chest_dims(face)
    local alongx = (face == "+z" or face == "-z")
    return alongx and 20 or 12, alongx and 12 or 20       -- extents in voxels along x and z
end

-- the lid at an angle (0 = shut, 100 = standing open at the back): a slab of two voxels hinged on the back edge of the body. `draw` true writes it, false clears exactly what a draw would write.
local function lid_boxes(face, ang)
    local lx_, lz_ = chest_dims(face)
    local alongx = (face == "+z" or face == "-z")
    local D = alongx and lz_ or lx_                         -- depth (from the back to the front)
    local W = alongx and lx_ or lz_                         -- width along the lock's side
    local sgn = (face == "+z" or face == "+x") and 1 or -1  -- the direction from the back towards the front
    local back = (sgn == 1) and 0 or (D - 1)
    local a = math.rad(ang)
    local ca, sa = math.cos(a), math.sin(a)
    local out, seen = {}, {}
    local u = 0.0
    while u <= D - 1 + 0.01 do
        for t = 0, 1 do
            local pos = math.floor(back + sgn * (u * ca - t * sa) + 0.5)
            local y = math.floor(9 + u * sa + t * ca + 0.5)
            local key = pos * 1000 + y
            if not seen[key] then
                seen[key] = true
                if alongx then out[#out + 1] = { 0, y, pos, W - 1, y, pos } else out[#out + 1] = { pos, y, 0, pos, y, W - 1 } end
            end
        end
        u = u + 0.5
    end
    return out
end

local function draw_lid(ox, oy, oz, face, ang, mat)
    for _, bx in ipairs(lid_boxes(face, ang)) do
        local x0, y0, z0, x1, y1, z1 = bx[1], bx[2], bx[3], bx[4], bx[5], bx[6]
        if mat == "air" then edit.clear(ox + x0, oy + y0, oz + z0, ox + x1, oy + y1, oz + z1)
        else edit.box(ox + x0, oy + y0, oz + z0, ox + x1, oy + y1, oz + z1, mat) end
    end
end

local function chest_voxels(tier, lx, ly, lz, face, open)
    local ox, oy, oz = G.wx(lx), G.wy(ly), G.wz(lz)
    local lx_, lz_ = chest_dims(face)
    local alongx = (face == "+z" or face == "-z")
    local function B(x0, y0, z0, x1, y1, z1, mat, paint)
        edit.box(ox + x0, oy + y0, oz + z0, ox + x1, oy + y1, oz + z1, mat)
        if paint then edit.paint_box(ox + x0, oy + y0, oz + z0, ox + x1, oy + y1, oz + z1, paint) end
    end
    B(0, 0, 0, lx_ - 1, 8, lz_ - 1, "chest_wood")                          -- the body
    local c = tier_paint[tier]
    if open then
        B(1, 8, 1, lx_ - 2, 8, lz_ - 2, "gold")
        draw_lid(ox, oy, oz, face, 100, "chest_wood")                       -- the lid, standing open at the back
    else
        B(0, 9, 0, lx_ - 1, 10, lz_ - 1, "chest_wood")                      -- the lid
        B(1, 11, 1, lx_ - 2, 11, lz_ - 2, "chest_wood")
    end
    -- bands in the tier's colour
    if alongx then
        B(3, 0, 0, 4, open and 8 or 10, lz_ - 1, "metal", c); B(lx_ - 5, 0, 0, lx_ - 4, open and 8 or 10, lz_ - 1, "metal", c)
    else
        B(0, 0, 3, lx_ - 1, open and 8 or 10, 4, "metal", c); B(0, 0, lz_ - 5, lx_ - 1, open and 8 or 10, lz_ - 4, "metal", c)
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

-- the lid opens in five steps (about a third of a second), the creak starts at once, the glitter and the loot come when it is up
local function animate_open(tier, lx, ly, lz, face)
    local ox, oy, oz = G.wx(lx), G.wy(ly), G.wz(lz)
    local lx_, lz_ = chest_dims(face)
    -- clear the shut lid and its band tops first
    edit.clear(ox, oy + 9, oz, ox + lx_ - 1, oy + 11, oz + lz_ - 1)
    edit.box(ox + 1, oy + 8, oz + 1, ox + lx_ - 2, oy + 8, oz + lz_ - 2, "gold")
    local prev
    local angles = { 12, 32, 55, 80, 100 }
    for i, ang in ipairs(angles) do
        after((i - 1) * 4 + 2, function()
            if prev then draw_lid(ox, oy, oz, face, prev, "air") end
            draw_lid(ox, oy, oz, face, ang, "chest_wood")
            prev = ang
        end)
    end
end

-- id: a unique name (saved in state.opened); tier: bronze | silver | gold | platinum
T.crates = {}
T.all_chests = {}
function T.crate(id, tier, lx, ly, lz, face)
    face = face or "+z"
    local opened = G.state.opened[id]
    local lx_, lz_ = chest_dims(face)
    local lockbox
    if G.should_build() then lockbox = chest_voxels(tier, lx, ly, lz, face, opened)
    else
        -- the lock's place again, to declare the button on a loaded world
        local ox, oy, oz = G.wx(lx), G.wy(ly), G.wz(lz)
        if face == "+z" then lockbox = { ox + 9, oy + 6, oz + lz_, ox + 10, oy + 7, oz + lz_ }
        elseif face == "-z" then lockbox = { ox + 9, oy + 6, oz - 1, ox + 10, oy + 7, oz - 1 }
        elseif face == "+x" then lockbox = { ox + lx_, oy + 6, oz + 9, ox + lx_, oy + 7, oz + 10 }
        else lockbox = { ox - 1, oy + 6, oz + 9, ox - 1, oy + 7, oz + 10 } end
    end
    T.all_chests[#T.all_chests + 1] = { tier = tier, lx = lx, ly = ly, lz = lz, face = face, id = id }
    if opened then return end
    local cx, cz = lx + lx_ / 32, lz + lz_ / 32                   -- the centre of the chest (metres)
    T.crates[id] = { cell = T.cell, id = id, tier = tier, lx = lx, ly = ly, lz = lz, face = face, cx = cx, cy = ly + 0.3, cz = cz }
    local node = events.button{ name = "crate_" .. id, box = lockbox, prompt = "Open the " .. G.items.tiers[tier].name, on = "neon", off = tier_glow[tier], press_ticks = 10 }
    events.on(node, "pressed", function() T.open_crate(id) end)
    T.add_interact("crate_" .. id, cx, ly + 0.5, cz, "Open the " .. G.items.tiers[tier].name, 3.0, function() return not G.state.opened[id] end)
    -- a faint light so that it can be found in the dark
    G.torch(cx, ly + 1.4, cz, { preset = "magic_sparks", reach = 5, color = ({ bronze = { 1, .6, .3 }, silver = { .7, .7, 1 }, gold = { 1, .85, .3 }, platinum = { .4, 1, 1 } })[tier], name = "crate_light_" .. id })
end

-- worlds saved by earlier versions: chests that a blast or a fire has damaged (the old body was ordinary, burnable wood) are drawn again, in the tough wood
function T.redraw_all_chests()
    for _, c in ipairs(T.all_chests) do chest_voxels(c.tier, c.lx, c.ly, c.lz, c.face, G.state.opened[c.id] and true or false) end
end

-- a crate made while the game runs (the boss's reward): the voxels now, and the button
function T.build_crate_now(id, tier, lx, ly, lz, face)
    if G.state.opened[id] then return end
    local was = G.rebuilding
    G.rebuilding = true
    T.crate(id, tier, lx, ly, lz, face)
    G.rebuilding = was
end

-- the unopened chest that a click (attack, or E) means: the nearest one within `reach` metres whose middle is in front of the player (or very close). Any part of the chest counts, not the lock.
function T.crate_in_front(reach, min_dot)
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local fx, fy, fz = player.forward()
    local best, bd
    for id, c in pairs(T.crates) do
        if not G.state.opened[id] then
            local dx, dy, dz = c.cx - lx, (c.cy + 0.2) - (ly + 1.3), c.cz - lz
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            local dot = (dx * fx + dy * fy + dz * fz) / math.max(d, 0.01)
            if d <= reach and (dot >= (min_dot or 0.5) or d < 1.6) and (not bd or d < bd) then best, bd = c, d end
        end
    end
    return best
end

-- E at a sliding door: open it, and shut it again after a while if nobody is on its plate
function T.use_door()
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    for _, d in ipairs(T.doors or {}) do
        if G.dist2(lx, lz, d.x, d.z) < 3.2 then
            events.command(d.node, "open")
            after(420, function() if not events.state(d.plate).player then events.command(d.node, "close") end end)
            G.sfx.play("lever", d.x, 1.2, d.z)
            return true
        end
    end
    return false
end

function T.open_crate(id)
    local c = T.crates[id]
    local s = G.state
    if not c or s.opened[id] then return end
    s.opened[id] = true
    local tier, lx, ly, lz, face = c.tier, c.lx, c.ly, c.lz, c.face
    local tdef = G.items.tiers[tier]
    local A = G.announcer
    local cx, cy, cz = G.mx(c.cx), G.my(c.cy + 0.5), G.mz(c.cz)
    G.sfx.play("crate_open", c.cx, c.cy, c.cz)
    A.say_key("box." .. tier, { prio = 1 })
    animate_open(tier, lx, ly, lz, face)
    -- when the lid is up: glitter, the loot jumps out
    after(24, function()
        fx.play("confetti", floor(units.vox(cx)), floor(units.vox(cy)), floor(units.vox(cz)), 1.2)
        if emitter.find("crate_light_" .. id) then
            emitter.burst("crate_light_" .. id, 80)
            after(300, function() if emitter.find("crate_light_" .. id) then emitter.remove("crate_light_" .. id) end end)      -- the glitter stops after five seconds
        end
        G.sfx.play("coin", c.cx, c.cy + 0.5, c.cz, 0.6, 1.2)
        local n = G.irange(tdef.rolls[1], tdef.rolls[2])
        local gold = G.irange(tdef.gold[1], tdef.gold[2])
        G.enemies.drop(cx, cy + 0.3, cz, "gold", gold)
        n = n + G.skills.extra_rolls()
        G.skills.bump("looting")
        if T.crate_loot[id] then n = #T.crate_loot[id] end
        for i = 1, n do
            local item = T.crate_loot[id] and T.crate_loot[id][i] or G.items.roll(tier, i * 31 + #id)
            if tier == "platinum" and i == 1 then item = ({ "excalibur", "tux", "spoon" })[1 + (s.level or 1) % 3] end
            G.enemies.drop(cx + G.range(-0.4, 0.4), cy + 0.2 * i, cz + G.range(-0.4, 0.4), "item", item)
        end
        if T.crate_hooks[id] then T.crate_hooks[id]() end
    end)
    if G.show then G.show.score(({ bronze = 4, silver = 7, gold = 12, platinum = 25 })[tier] or 4, nil) end
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
    T.barrels[#T.barrels + 1] = { cell = T.cell, x = lx, y = ly + 0.45, z = lz, alive = true }
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
    if d < 4.5 then G.player.hurt(floor((floor(40 * (1 - d / 5.5)) + 8) * G.skills.blast_taken()), "an explosive barrel", { pierce = true }) end
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

-- what a swing that hit no enemy, barrel or chest feels like: chips of whatever it struck, a knock in that material's voice, and a grey hit mark. Returns true when it struck something solid.
local chip_of = { wood = "chip_wood", dark_wood = "chip_wood", planks = "chip_wood", carpet = "chip_wood", metal = "chip_metal", gold = "chip_metal", hazard_y = "chip_metal", obsidian = "chip_stone" }
local sound_of = { wood = "wood", dark_wood = "wood", metal = "metal", gold = "metal", glass = "glass", gutter_water = "glass", dirt = "stone" }
function T.swing_feedback(reach)
    local _, _, _, hx, hy, hz, d, hit = G.look_ray(reach + 0.2, 0.08)
    if not hit then return false end
    local m = world.material_at(floor(hx * 16), floor(hy * 16), floor(hz * 16))
    G.player.hitmark = time.tick(); G.player.hitmark_crit = false; G.player.hitmark_wall = true
    fx.play(chip_of[m] or "chip_stone", floor(hx * 16), floor(hy * 16), floor(hz * 16), 1.0)
    sound.hit(sound_of[m] or "stone", 5 + G.state.level * 0.3, 1.0, hx, hy, hz)
    if m == "metal" or m == "gold" then G.sfx.play("trap_click", nil, nil, nil, 0.5, 0.7) end
    return true
end

function T.secret(name, lx, ly, lz, wall_box)
    T.secret_wall = { x = lx, y = ly, z = lz, opened = G.state.flags["secret_" .. name] or false, name = name }
end

function T.reveal_secret()
    local s = T.secret_wall
    if s.opened then return end
    s.opened = true
    G.state.flags["secret_" .. s.name] = true
    -- the blast cracks the hollow wall wide open (the bricks are tougher than a barrel)
    after(6, function() edit.carve(G.wx(s.x), G.wy(s.y + 0.1), G.wz(s.z + 0.15), 30, 0.25, 4242) end)
    G.announcer.say_key("room.secret", { prio = 1 })
    G.announcer.award("fine_print")
    G.player.popup("SECRET FOUND", "#ffd24a", true)
    G.save()
end

-- loot that hangs in the air (weightless places): a little body, picked up by walking into it; once taken it is not made again
T.floating_list = {}
function T.floating(id, lx, ly, lz, kind, payload)
    if G.state.opened["float_" .. id] then return end
    local b = body.box(G.mx(lx), G.my(ly), G.mz(lz), 5, 5, 5, "lantern")
    T.floating_list[#T.floating_list + 1] = { cell = T.cell, id = id, body = b, kind = kind, payload = payload, x = lx, y = ly, z = lz }
end

-- ---------------------------------------------------------------------------------------------- hazards: a box (local metres) that hurts whoever stands in it
-- kind: "lava" (burns), "water" (wet: only the achievement), "fire"
function T.hazard(kind, x0, y0, z0, x1, y1, z1, dmg)
    T.hazards[#T.hazards + 1] = { cell = T.cell, kind = kind, x0 = x0, y0 = y0, z0 = z0, x1 = x1, y1 = y1, z1 = z1, dmg = dmg or 25 }
end

function T.tick_floating(t)
    if t % 6 ~= 0 then return end
    local px, py, pz = player.pos()
    for i = #T.floating_list, 1, -1 do
        local f = T.floating_list[i]
        local x, y, z, ok = body.pos(f.body)
        if ok and G.dist3(x, y, z, px, py + 0.9, pz) < 1.5 then
            G.state.opened["float_" .. f.id] = true
            body.remove(f.body)
            table.remove(T.floating_list, i)
            if f.kind == "item" then
                if G.items.add(f.payload, 1) then
                    local d = G.items.defs[f.payload]
                    G.player.log(d.name, d.color); G.sfx.play("pickup")
                end
            end
            G.save()
        end
    end
end

-- a barrel that burns goes off: its wood turns to ember / char / flame (any fire: a fire bolt, a torch bolt, the lava, the boss's geysers) or is gone
function T.tick_barrels(t)
    if t % 12 ~= 0 then return end
    for _, b in ipairs(T.barrels) do
        if b.alive and not b.fuse then
            local m = world.material_at(G.wx(b.x), G.wy(b.y - 0.1), G.wz(b.z))
            local m2 = world.material_at(G.wx(b.x), G.wy(b.y + 0.35), G.wz(b.z))
            local burnt = { ember = true, char = true, flame = true, air = true }
            if m ~= "unloaded" and m2 ~= "unloaded" and (burnt[m] or burnt[m2]) then
                b.fuse = true
                after(G.irange(2, 14), function() T.explode_barrel(b) end)
            end
        end
    end
end

function T.tick(t)
    T.tick_floating(t)
    T.tick_barrels(t)
    if t % 6 ~= 0 then return end
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py + 0.2, pz)
    for _, h in ipairs(T.hazards) do
        if lx >= h.x0 and lx <= h.x1 and ly >= h.y0 and ly <= h.y1 and lz >= h.z0 and lz <= h.z1 then
            if h.kind == "lava" then
                if t % 18 == 0 then local fl_ = (G.run and G.run.floor_no and G.run.floor_no()) or 1; local lr = h.cell and G.floorgen and G.floorgen.layout and G.floorgen.layout.rooms and G.floorgen.layout.rooms[h.cell]; G.tally("lava_where", (lr and lr.theme) or "authored", 1); G.player.hurt(((fl_ == 1 or fl_ == 2) and 0.5 or 1) * h.dmg, "the lava", { pierce = true }); fx.play("sparks", floor(units.vox(px)), floor(units.vox(py)), floor(units.vox(pz)), 1.0) end
                if not T.lava_said then T.lava_said = true; G.announcer.say_key("trap.lava", { prio = 1, key = "lava", cooldown = 3000 }) end
            elseif h.kind == "toxic" then
                if t % 36 == 0 then G.player.hurt(h.dmg, "toxic sludge", { pierce = true }) end
                if not G.state.counters.soggy then G.state.counters.soggy = 1; G.announcer.award("soggy") end
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
