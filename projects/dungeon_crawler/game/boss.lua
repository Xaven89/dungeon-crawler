-- boss: THE FLOOR MANAGER. Three phases by health: (1) clipboard throws and swings, (2) "Restructuring": he summons interns and slams the floor, (3) "Hostile Takeover": lava geysers
-- erupt under the player's feet. A short third-person cutscene introduces him. When he falls the gate to the Stairwell opens.
Game = Game or {}
local G = Game
local B = {}
G.boss = B
local E, T, W = G.enemies, G.traps, G.world
local floor, max, min = math.floor, math.max, math.min

B.active = false
B.started = false
B.phase = 1
B.inst = nil

function B.begin()
    if B.started or G.state.flags.boss_dead then return end
    B.started = true
    local A = G.announcer
    local inst = E.spawn("manager", 30, 0, 136.5, { room = "arena", still = true, hp_mult = 1 + (G.state.level - 1) * 0.04 })
    if not inst then B.started = false; return end
    inst.ai = B.ai
    inst.no_flinch = true
    inst.state = "intro"
    inst.intro_until = time.tick() + 420
    inst.next_attack, inst.next_slam, inst.next_throw, inst.next_summon, inst.next_geyser = 0, 0, 0, 0, 0
    B.inst, B.active, B.phase = inst, true, 1
    A.say_key("boss.intro", { prio = 2 })
    A.say_key("boss.intro", { prio = 0 })
    G.sfx.play("boss_stinger")
    -- the cutscene: the editor camera (a free camera that leaves the player parked) circles him for seven seconds, then the view goes back to the player's eyes
    local t0 = time.tick()
    camera.mode("editor")
    local timer
    timer = every(4, function()
        local f = (time.tick() - t0) / 420
        camera.focus(G.mx(30), G.my(2.4), G.mz(136.5))
        camera.set{ zoom = 9 - 2.5 * f, pitch = 14, yaw = 95 - 55 * f }
        if f >= 1 then cancel(timer); camera.mode("first") end
    end)
    model.play(inst.mdl, "roar", 1, false, 4)
    if G.music and G.music.set then G.music.set("boss") end
end

local function minions_alive()
    local n = 0
    for _, i in pairs(E.list) do if not i.dead and i.room == "arena" and not i.T.boss then n = n + 1 end end
    return n
end

local function set_phase(inst, p)
    B.phase = p
    local A = G.announcer
    model.play(inst.mdl, "roar", 1, false, 4)
    G.sfx.play("boss_roar", G.to_local(E.position(inst)))
    if p == 2 then A.say_key("boss.p2", { prio = 2 }) else A.say_key("boss.p3", { prio = 2 }) end
    inst.attacking = true; inst.attack_until = time.tick() + 80
    agent.stop(inst.id)
end

-- lava geyser under the player: a warning of embers, then a blast
function B.geyser(lx, lz)
    local name = "geyser_" .. time.tick()
    emitter.create{ name = name, preset = "campfire", pos = { G.mx(lx), G.my(0.2), G.mz(lz) }, light = { color = { 1, 0.3, 0.1 }, reach = 8 } }
    G.sfx.play("rumble", lx, 0, lz, 0.7)
    after(80, function()
        emitter.remove(name)
        local wx, wy, wz = G.mx(lx), G.my(0.1), G.mz(lz)
        fx.explosion(floor(units.vox(wx)), floor(units.vox(wy)), floor(units.vox(wz)), 18, 0.5)
        fx.fire(floor(units.vox(wx)), floor(units.vox(wy)), floor(units.vox(wz)), 22)
        G.sfx.play("explosion", lx, 0, lz, 0.9)
        local px, py, pz = player.pos()
        if G.dist2(wx, wz, px, pz) < 2.4 and math.abs(py - wy) < 2 then G.player.hurt(26, "a lava geyser", { pierce = true }) end
    end)
end

function B.throw(inst, x, y, z)
    local px, py, pz = player.pos()
    local sx, sy, sz = x, y + 3.4, z
    local dx, dy, dz = px - sx, (py + 1.1) - sy, pz - sz
    local d = max(0.1, math.sqrt(dx * dx + dy * dy + dz * dz))
    local b = body.box(sx + dx / d * 1.6, sy, sz + dz / d * 1.6, 9, 11, 2, "marble")
    local sp = 13
    body.push(b, dx / d * sp * 30, (dy / d * sp + 2.5) * 30, dz / d * sp * 30)
    E.projectiles[#E.projectiles + 1] = { body = b, born = time.tick(), dmg = 12, from = "a thrown clipboard" }
    G.sfx.play("swing", G.to_local(x, y + 3, z), 0.8, 0.6)
end

function B.summon(inst, x, y, z)
    local n = 0
    for i = 1, 2 do
        local a = G.rand() * 6.283
        local lx, lz = G.to_local(x, y, z)
        local e = E.spawn("intern", lx + math.cos(a) * 4, 0, lz + math.sin(a) * 4, { room = "arena", index = 90 + i })
        if e then E.aggro(e, true); n = n + 1; fx.play("poof", floor(units.vox(x + math.cos(a) * 4)), floor(units.vox(y)), floor(units.vox(z + math.sin(a) * 4)), 1.4) end
    end
    G.sfx.play("boss_roar", G.to_local(x, y, z), 0.7, 1.3)
end

function B.ai(inst, t, d, dy, info)
    local T_ = inst.T
    local frac = inst.hp / inst.max_hp
    if inst.state == "intro" then
        if t >= inst.intro_until then
            inst.state = "fight"
            agent.follow(inst.id, 2.6)
        end
        return
    end
    if G.player.dead then return end
    -- leashing: the player left the arena: he goes home and recovers
    if G.current_room ~= "arena" then
        if inst.state ~= "home" then
            inst.state = "home"; agent.walk(inst.id, G.mx(30), G.my(0), G.mz(136.5)); B.active = false
        end
        inst.hp = min(inst.max_hp, inst.hp + inst.max_hp * 0.01)
        return
    elseif inst.state == "home" then
        inst.state = "fight"; B.active = true; agent.follow(inst.id, 2.6)
    end
    local phase = frac > 0.66 and 1 or (frac > 0.33 and 2 or 3)
    if phase > B.phase then set_phase(inst, phase); return end
    if inst.attacking then
        if t >= inst.attack_until then inst.attacking = false; agent.follow(inst.id, 2.6) end
        return
    end
    local function act(clip, dur)
        inst.attacking = true; inst.attack_until = t + dur
        agent.stop(inst.id)
        model.play(inst.mdl, clip, 1, false, 3)
    end
    if phase >= 2 and t >= inst.next_summon and minions_alive() < 3 then
        inst.next_summon = t + 1300; act("summon", 130); return
    end
    if phase == 3 and t >= inst.next_geyser then
        inst.next_geyser = t + 170
        local px, py, pz = player.pos()
        local lx, ly, lz = G.to_local(px, py, pz)
        B.geyser(lx + G.range(-1, 1), lz + G.range(-1, 1))
        if G.rand() < 0.5 then G.announcer.say_key("boss.taunt", { key = "boss_taunt", cooldown = 900 }) end
    end
    if d <= T_.reach and t >= inst.next_attack then
        inst.next_attack = t + T_.cd; act("attack", 70); return
    end
    if phase >= 2 and d <= 8 and t >= inst.next_slam then
        inst.next_slam = t + 480; act("slam", 110); return
    end
    if d >= 5 and d <= 20 and t >= inst.next_throw then
        inst.next_throw = t + (phase == 1 and 300 or 220); act("throw", 70); return
    end
end

-- animation events of the boss: the throw, the summon, the slam, the roar
function B.on_event(inst, event, x, y, z)
    if event == "throw" then B.throw(inst, x, y, z)
    elseif event == "summon" then B.summon(inst, x, y, z) end
end

function B.on_dead(inst)
    G.state.flags.boss_dead = true
    B.active = false
    local A = G.announcer
    A.award("boss_down")
    G.items.add("keycard", 1)
    G.player.popup("FLOOR MANAGER FIRED", "#ff7a7a", true)
    G.sfx.play("boss_die")
    if G.music and G.music.set then G.music.set("victory") end
    -- minions go with him
    for _, i in pairs(E.list) do if not i.dead and i.room == "arena" then E.damage(i, 9999, { source = "restructuring" }) end end
    after(180, function()
        events.command(W.arena_gate, "open")
        A.say("The gate to Stairwell One is open. Please collect your platinum crate. Please do not ask where the keycard goes. It goes nowhere. It is laminated.", { prio = 1 })
        T.build_crate_now("boss_platinum", "platinum", 28.7, 0, 134, "-z")
    end)
    G.save()
end
