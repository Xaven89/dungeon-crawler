-- player: the contestant. State (saved with the project), classes, stats, levelling, combat (attack, class ability), items in use, death and respawn.
-- Everything here is a plain global function the HUD calls through ui.run, so the same code is driven by the MCP `lua` tool in the tests (no keyboard needed).
Game = Game or {}
local G = Game
local P = {}
G.player = P
local floor, max, min = math.floor, math.max, math.min

P.classes = {
    janitor = { name = "Janitor", tag = "Tank. Sweeper. Underpaid.", weapon = "mop", stats = { str = 7, dex = 4, int = 3, con = 8, cha = 3 },
                blurb = "Sturdy, slow, and professionally unbothered. Mop Sweep clears the room around you and knocks the muck back.",
                ability = { name = "Mop Sweep", cost = 0, cd = 330 }, color = "#6fd0ff" },
    pyro    = { name = "Pyromaniac", tag = "Glass cannon. Candle.", weapon = "torch_used", stats = { str = 3, dex = 5, int = 8, con = 4, cha = 5 },
                blurb = "Fragile and festive. Fire Bolt sets things alight, including things you did not mean to.",
                ability = { name = "Fire Bolt", cost = 14, cd = 100 }, color = "#ff8a3c" },
    bard    = { name = "Bard", tag = "Support. Sound. Mostly sound.", weapon = "lute", stats = { str = 4, dex = 5, int = 5, con = 5, cha = 8 },
                blurb = "Charming and loud. Power Chord stuns everything in earshot and lifts your spirits (and your health).",
                ability = { name = "Power Chord", cost = 12, cd = 300 }, color = "#d48cff" },
    accountant = { name = "Accountant", tag = "Precision. Paperwork. Pain.", weapon = "stapler", stats = { str = 3, dex = 6, int = 8, con = 3, cha = 6 },
                blurb = "Fast hands, sharp eyes. Audit marks a target: it takes double damage and pays out extra gold.",
                ability = { name = "Audit", cost = 10, cd = 240 }, color = "#ffe27a" },
}
P.class_order = { "janitor", "pyro", "bard", "accountant" }
P.MAX_LEVEL = 12

-- ---------------------------------------------------------------------------------------------- state
function G.new_state()
    return {
        class = nil, level = 1, xp = 0, hp = 100, mp = 40, gold = 0, points = 0,
        stats = { str = 5, dex = 5, int = 5, con = 5, cha = 5 },
        equip = {}, ach = {}, ach_count = 0, counters = {}, flags = {}, cleared = {}, opened = {},
        checkpoint = "lobby", deaths = 0, kills = 0, playtime = 0, floor = 1, intro_done = false,
        version = 1,
    }
end

function G.save()
    if G.state then project.store("state", G.state) end
    if G.items and G.items.inv then inventory.save(G.items.inv) end
end

function G.load()
    local s = project.fetch("state", nil)
    local fresh = G.new_state()
    if type(s) == "table" then
        for k, v in pairs(fresh) do if s[k] == nil then s[k] = v end end
        G.state = s
    else
        G.state = fresh
    end
    return G.state
end

local S = function() return G.state end

-- ---------------------------------------------------------------------------------------------- derived numbers
function P.stat(name)
    local s = G.state
    local v = s.stats[name] or 0
    for _, slot in pairs(s.equip) do
        local d = G.items.defs[slot]
        if d and d[name] then v = v + d[name] end
    end
    return v
end
function P.max_hp() return 50 + P.stat("con") * 8 + G.state.level * 10 end
function P.max_mp() return 20 + P.stat("int") * 5 + G.state.level * 3 end
function P.defense()
    local d = P.stat("con") * 0.2
    for _, id in pairs(G.state.equip) do local def = G.items.defs[id]; if def and def.def then d = d + def.def end end
    return d
end
function P.weapon() return G.items.defs[G.state.equip.weapon or "mop"] or G.items.defs.mop end
function P.crit_chance() return 0.05 + P.stat("dex") * 0.012 end
function P.gold_bonus()
    local b = 0
    for _, id in pairs(G.state.equip) do local d = G.items.defs[id]; if d and d.gold_bonus then b = b + d.gold_bonus end end
    return b
end
function P.xp_needed(level) return floor(60 * (level or G.state.level) ^ 1.4) end

-- ---------------------------------------------------------------------------------------------- feedback the HUD reads
P.popups = {}       -- { text, color, t, big }
P.flash = 0         -- tick of the last hit taken (red vignette)
P.hitmark = 0       -- tick of the last hit dealt
P.hitmark_crit = false
function P.popup(text, color, big)
    P.popups[#P.popups + 1] = { text = text, color = color or "#ffffff", t = time.tick(), big = big }
    if #P.popups > 6 then table.remove(P.popups, 1) end
end

-- ---------------------------------------------------------------------------------------------- start of a run
function P.pick_class(id)
    local c = P.classes[id]
    if not c or G.state.class then return false end
    local s = G.state
    s.class = id
    for k, v in pairs(c.stats) do s.stats[k] = v end
    s.equip.weapon = c.weapon
    s.hp, s.mp = P.max_hp(), P.max_mp()
    s.gold = 10
    G.items.add("smoothie", 2)
    G.items.add("bandage", 2)
    G.screen = nil
    G.sfx.play("levelup", nil, nil, nil, 0.7)
    G.announcer.award("check_in")
    G.announcer.say_key("class." .. id, { prio = 2 })
    after(300, function() G.announcer.say_key("class.go", { prio = 0 }) ; if G.world.open_lobby_gate then G.world.open_lobby_gate() end end)
    after(900, function() G.announcer.say_key("honk.intro", { prio = 0 }); if G.companion then G.companion.honk() end end)
    G.save()
    return true
end

-- ---------------------------------------------------------------------------------------------- xp, levels
function P.add_xp(n, why)
    local s = G.state
    if n <= 0 or s.level >= P.MAX_LEVEL then return end
    s.xp = s.xp + n
    P.popup("+" .. n .. " XP", "#9fe0ff")
    local up = false
    while s.level < P.MAX_LEVEL and s.xp >= P.xp_needed(s.level) do
        s.xp = s.xp - P.xp_needed(s.level)
        s.level = s.level + 1
        s.points = s.points + 2
        s.hp, s.mp = P.max_hp(), P.max_mp()
        up = true
    end
    if up then
        G.sfx.play("levelup")
        P.popup("LEVEL " .. s.level, "#ffd24a", true)
        G.announcer.say_key("levelup", { prio = 1 }, s.level)
        fx.play("confetti", units.vox(select(1, player.pos())), units.vox(select(2, player.pos())) + 40, units.vox(select(3, player.pos())))
    end
end

function P.spend(stat)
    local s = G.state
    if s.points <= 0 or not s.stats[stat] then return false end
    s.points = s.points - 1
    s.stats[stat] = s.stats[stat] + 1
    G.sfx.play("ui_click")
    if stat == "con" then s.hp = min(P.max_hp(), s.hp + 8) end
    G.save()
    return true
end

-- ---------------------------------------------------------------------------------------------- health
function P.heal(n, quiet)
    local s = G.state
    local before = s.hp
    s.hp = min(P.max_hp(), s.hp + n)
    if not quiet and s.hp > before then P.popup("+" .. floor(s.hp - before) .. " HP", "#6bff8a") end
end

local low_hp_warned = 0
function P.hurt(amount, src, opts)
    local s = G.state
    opts = opts or {}
    if P.dead or G.safe or (P.grace or 0) > time.tick() or not s.class then return 0 end
    if not opts.pierce then
        if G.hash(time.tick(), floor(amount), 7) < P.stat("dex") * 0.004 then
            P.popup("DODGE", "#cfe8ff")
            return 0
        end
        amount = max(1, amount - P.defense() * 0.5)
    end
    amount = floor(amount + 0.5)
    s.hp = s.hp - amount
    P.flash = time.tick()
    P.last_hurt = time.tick()
    P.popup("-" .. amount, "#ff6060")
    G.sfx.play("hurt", nil, nil, nil, 0.8)
    if s.hp <= 0 then
        s.hp = 0
        P.die(src)
    elseif s.hp < P.max_hp() * 0.25 and time.tick() - low_hp_warned > 1200 then
        low_hp_warned = time.tick()
        G.announcer.say_key("hp.low", { prio = 1 })
    end
    return amount
end

-- the pit, the lava, the water: hazards hurt by what they are, not by who
function P.die(src)
    if P.dead then return end
    local s = G.state
    P.dead = true
    P.dead_tick = time.tick()
    s.deaths = s.deaths + 1
    local lost = floor(s.gold * 0.2)
    s.gold = s.gold - lost
    P.death_gold_lost = lost
    P.death_src = src or "something"
    G.screen = "death"
    G.sfx.play("death")
    G.announcer.say_key("death", { prio = 2 }, P.death_src)
    local A = G.announcer
    A.award("fashionably")
    if s.deaths >= 3 then A.award("serial_victim") end
    if G.companion and G.companion.on_player_death then G.companion.on_player_death() end
    if G.enemies and G.enemies.on_player_death then G.enemies.on_player_death() end
    after(300, function() P.respawn() end)
    G.save()
end

function P.respawn()
    local s = G.state
    local W = G.world
    local cp = W.checkpoints[s.checkpoint] or W.checkpoints.lobby
    player.teleport(G.mx(cp.x), G.my(cp.y), G.mz(cp.z))
    s.hp = floor(P.max_hp() * 0.6)
    s.mp = P.max_mp()
    P.dead = false
    P.grace = time.tick() + 180
    G.screen = nil
    G.announcer.say_key("respawn", { prio = 1 })
    if G.companion and G.companion.respawn then G.companion.respawn() end
    G.save()
end

function P.set_checkpoint(id, quiet)
    local s = G.state
    if s.checkpoint == id then return end
    s.checkpoint = id
    if not quiet then
        P.popup("CHECKPOINT", "#a6ffcc", true)
        G.sfx.play("checkpoint")
        G.announcer.say_key("checkpoint." .. id, { prio = 1 })
    end
    G.save()
end

-- ---------------------------------------------------------------------------------------------- aiming
function P.eye()
    local x, y, z = player.pos()
    return x, y + 1.62, z
end

-- the first solid voxel (or the end of the range) along the view: world metres of the hit point and of the empty point just before it
function G.look_ray(maxd, step)
    local ex, ey, ez = P.eye()
    local dx, dy, dz = player.forward()
    step = step or 0.2
    local px, py, pz = ex, ey, ez
    local d = 0
    while d < maxd do
        d = d + step
        local x, y, z = ex + dx * d, ey + dy * d, ez + dz * d
        if world.solid(floor(x * 16), floor(y * 16), floor(z * 16)) then
            return px, py, pz, x, y, z, d, true
        end
        px, py, pz = x, y, z
    end
    return px, py, pz, px, py, pz, d, false
end

-- ---------------------------------------------------------------------------------------------- combat
P.next_attack = 0
P.next_ability = 0
P.swings = 0

local function roll_damage(base_lo, base_hi, mult)
    local s = G.state
    local dmg = base_lo + G.rand() * (base_hi - base_lo)
    dmg = dmg * (1 + P.stat("str") * 0.05) + s.level * 0.8
    dmg = dmg * (mult or 1)
    local crit = G.rand() < P.crit_chance()
    if crit then dmg = dmg * 2 end
    return max(1, floor(dmg + 0.5)), crit
end
P.roll_damage = roll_damage

-- enemies in front of the player within reach: a list of { inst, dist }
function P.targets_in_cone(reach, cos_half, max_n)
    local E = G.enemies
    local px, py, pz = player.pos()
    local fx, fy, fz = player.forward()
    local out = {}
    for _, inst in pairs(E.list) do
        if not inst.dead then
            local x, y, z = E.position(inst)
            if x then
                local cy = y + inst.height * 0.5
                local dx, dy, dz = x - px, cy - (py + 1.2), z - pz
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d <= reach + inst.radius then
                    local dot = (dx * fx + dy * fy + dz * fz) / max(d, 0.001)
                    if dot >= cos_half or d < inst.radius + 0.6 or G.autoaim then out[#out + 1] = { inst = inst, dist = d, dot = dot } end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    if max_n then while #out > max_n do table.remove(out) end end
    return out
end

function P.attack()
    local s = G.state
    local now = time.tick()
    if P.dead or not s.class or now < P.next_attack or G.screen then return false end
    local w = P.weapon()
    P.next_attack = now + w.cd
    P.swings = P.swings + 1
    P.swing_tick = now
    player.hand_play("swing"); player.model_play("attack")          -- the sword in the first-person view and the body in the third (render only)
    G.sfx.play("swing", nil, nil, nil, 0.6, 0.9 + (P.swings % 3) * 0.1)
    local targets = P.targets_in_cone(w.reach, 0.62, 2)
    local hit = false
    for _, t in ipairs(targets) do
        local dmg, crit = roll_damage(w.dmg[1], w.dmg[2])
        G.enemies.damage(t.inst, dmg, { crit = crit, burn = w.burn, source = "player" })
        hit = true
    end
    if not hit then
        -- the swing may open a chest (anywhere on it), set off a barrel, or just hit the wall
        local T = G.traps
        local c = T.crate_in_front(w.reach + 0.8, 0.45)
        if c then
            P.hitmark = now; P.hitmark_crit = false
            fx.play("chip_wood", floor(units.vox(G.mx(c.cx))), floor(units.vox(G.my(c.cy + 0.3))), floor(units.vox(G.mz(c.cz))), 0.8)
            T.open_crate(c.id); hit = true
        elseif T.swing_at(w.reach) then hit = true
        else T.swing_feedback(w.reach) end
    end
    return hit
end

function P.ability()
    local s = G.state
    local now = time.tick()
    local c = P.classes[s.class]
    if P.dead or not c or now < P.next_ability or G.screen then return false end
    if s.mp < c.ability.cost then
        P.popup("NOT ENOUGH MANA", "#8899ff")
        return false
    end
    P.next_ability = now + c.ability.cd
    s.mp = s.mp - c.ability.cost
    P.ability_tick = now
    local px, py, pz = player.pos()
    local E = G.enemies
    if s.class == "janitor" then
        G.sfx.play("sweep")
        fx.play("sparks", units.vox(px), units.vox(py) + 8, units.vox(pz), 0.8)
        for _, inst in pairs(E.list) do
            if not inst.dead then
                local x, y, z = E.position(inst)
                if x and G.dist3(x, y, z, px, py, pz) <= 3.6 + inst.radius then
                    local dmg, crit = roll_damage(P.weapon().dmg[1], P.weapon().dmg[2], 1.2)
                    E.damage(inst, dmg, { crit = crit, stun = 70, source = "player" })
                end
            end
        end
    elseif s.class == "pyro" then
        G.sfx.play("firebolt")
        local ex, ey, ez, hx, hy, hz, d, hit = G.look_ray(30, 0.25)
        local x, y, z = hx, hy, hz
        -- stop at the first enemy near the ray
        local fx_, fy_, fz_ = player.forward()
        local bx, by, bz = P.eye()
        for step = 0.5, d, 0.5 do
            local rx, ry, rz = bx + fx_ * step, by + fy_ * step, bz + fz_ * step
            local stop = false
            for _, inst in pairs(E.list) do
                if not inst.dead then
                    local ix, iy, iz = E.position(inst)
                    if ix and G.dist3(ix, iy + inst.height * 0.5, iz, rx, ry, rz) < inst.radius + 0.5 then x, y, z = rx, ry, rz; stop = true; break end
                end
            end
            if stop then break end
        end
        fx.fire(floor(x * 16), floor(y * 16), floor(z * 16), 28)
        G.traps.blast(x, y, z, 3.5)
        fx.play("sparks", floor(x * 16), floor(y * 16), floor(z * 16), 1.4)
        fx.explosion(floor(x * 16), floor(y * 16), floor(z * 16), 10, 0.4)
        for _, inst in pairs(E.list) do
            if not inst.dead then
                local ix, iy, iz = E.position(inst)
                if ix and G.dist3(ix, iy + inst.height * 0.5, iz, x, y, z) <= 3.2 + inst.radius then
                    local dmg, crit = roll_damage(14, 22, 1 + P.stat("int") * 0.06)
                    E.damage(inst, dmg, { crit = crit, burn = 1, source = "player" })
                end
            end
        end
        G.announcer.award("pyro")
    elseif s.class == "bard" then
        G.sfx.play("chord")
        fx.play("sparks", units.vox(px), units.vox(py) + 30, units.vox(pz), 1.6)
        for _, inst in pairs(E.list) do
            if not inst.dead then
                local x, y, z = E.position(inst)
                if x and G.dist3(x, y, z, px, py, pz) <= 9 then
                    local dmg, crit = roll_damage(8, 12, 1 + P.stat("cha") * 0.05)
                    E.damage(inst, dmg, { crit = crit, stun = 150, source = "player" })
                end
            end
        end
        P.heal(floor(P.max_hp() * 0.1))
    elseif s.class == "accountant" then
        G.sfx.play("audit")
        local t = P.targets_in_cone(18, 0.9, 1)[1]
        if t then
            t.inst.marked = now + 600
            P.popup("AUDITED", "#ffe27a", true)
        else
            s.mp = s.mp + c.ability.cost
            P.next_ability = now + 20
            P.popup("NOTHING TO AUDIT", "#8899ff")
        end
    end
    return true
end

-- ---------------------------------------------------------------------------------------------- items in use
function P.equip(id)
    local d = G.items.defs[id]
    local s = G.state
    if not d or (d.kind ~= "weapon" and d.kind ~= "armor" and d.kind ~= "trinket") then return false end
    if G.items.count(id) < 1 then return false end
    local slot = d.kind
    local old = s.equip[slot]
    G.items.remove(id, 1)
    if old then G.items.add(old, 1) end
    s.equip[slot] = id
    G.sfx.play("equip")
    P.popup("EQUIPPED: " .. d.name, d.color)
    s.hp = min(s.hp, P.max_hp())
    G.save()
    return true
end

function P.unequip(slot)
    local s = G.state
    local id = s.equip[slot]
    if not id or (slot == "weapon" and false) then return false end
    if G.items.add(id, 1) then s.equip[slot] = nil; G.save(); return true end
    return false
end

function P.use_item(id)
    local d = G.items.defs[id]
    local s = G.state
    if not d or P.dead or G.items.count(id) < 1 then return false end
    if d.kind == "weapon" or d.kind == "armor" or d.kind == "trinket" then return P.equip(id) end
    if d.kind ~= "consumable" then return false end
    if d.heal and s.hp >= P.max_hp() and not d.mana and not d.throw then P.popup("ALREADY HEALTHY", "#cccccc"); return false end
    G.items.remove(id, 1)
    if d.heal then P.heal(d.heal); G.sfx.play("heal") end
    if d.mana then s.mp = min(P.max_mp(), s.mp + d.mana); P.popup("+" .. d.mana .. " MP", "#7aa8ff"); G.sfx.play("heal", nil, nil, nil, 0.6, 1.3) end
    if d.throw then
        local ex, ey, ez, hx, hy, hz = G.look_ray(24, 0.25)
        G.sfx.play("swing")
        after(18, function()
            fx.explosion(floor(ex * 16), floor(ey * 16), floor(ez * 16), 14, 0.6)
            G.traps.blast(ex, ey, ez, 4.5)
            G.enemies.damage_area(ex, ey, ez, 4.2, 38, "player")
        end)
    end
    G.announcer.say_key("use." .. (d.kind), { key = "use_" .. id, cooldown = 1800 }, d.name)
    G.save()
    return true
end

-- the quick keys: R heals with the smallest item that does the job, T drinks mana, G throws a firecracker (the number keys are the engine's teleports, so no hotbar)
local quick_lists = { heal = { "bandage", "smoothie", "sushi", "cheese" }, mana = { "energy", "cheese" }, throw = { "firecracker" } }
function P.quick(kind)
    local s = G.state
    if P.dead or not s.class or G.screen then return false end
    local need = P.max_hp() - s.hp
    local pick
    for _, id in ipairs(quick_lists[kind] or {}) do
        local d = G.items.defs[id]
        if G.items.count(id) > 0 then
            if kind == "heal" then
                if d.heal and need > 0 then
                    if not pick then pick = id end
                    if d.heal >= need * 0.8 then pick = id; break end
                end
            elseif kind == "mana" then
                if d.mana and s.mp < P.max_mp() - 5 then pick = id; break end
            else pick = id; break end
        end
    end
    if not pick then P.popup(kind == "heal" and "NO HEALING ITEM" or (kind == "mana" and "NO MANA ITEM" or "NOTHING TO THROW"), "#cccccc"); return false end
    return P.use_item(pick)
end

-- ---------------------------------------------------------------------------------------------- per tick
function P.tick(t)
    local s = G.state
    if not s.class or P.dead then return end
    s.playtime = s.playtime + 1
    if t % 30 == 0 then
        local out_of_combat = t - (P.last_hurt or -9999) > 480
        if out_of_combat and s.hp < P.max_hp() then s.hp = min(P.max_hp(), s.hp + (0.8 + P.stat("con") * 0.12)) end
        if s.mp < P.max_mp() then s.mp = min(P.max_mp(), s.mp + 0.9 + P.stat("int") * 0.08) end
    end
    -- popups fade
    while P.popups[1] and t - P.popups[1].t > 150 do table.remove(P.popups, 1) end
end
