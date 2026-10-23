-- enemies: the dungeon's staff. The engine has no hostility (docs/AGENTS.md): this is follow + clips + events put together. Types are data; the AI looks at the player every 8 ticks,
-- an attack is a clip whose `hit` event is the frame that hurts (on_anim), a kill is a ragdoll (or a splat for the single-part ones), drops are little bodies the player walks into.
Game = Game or {}
local G = Game
local E = {}
G.enemies = E
local floor, max, min, abs, sqrt = math.floor, math.max, math.min, math.abs, math.sqrt

E.list = {}          -- agent id -> instance
E.by_model = {}      -- model id -> instance
E.projectiles = {}
E.loot = {}
E.AI_PERIOD = 8

-- hp, dmg (before the player's armour), speed (m/s), reach (m), aggro (m), xp, gold {lo, hi}, cd (ticks between attacks), height / radius (m), sfx (hit / die sounds), fx (splat effect)
E.types = {
    slime = { model = "slime", name = "Gutter Slime", hp = 28, dmg = 6, speed = 1.5, reach = 1.5, aggro = 10, xp = 12, gold = { 0, 3 }, cd = 95, height = 0.7, radius = 0.5, anim = "clip",
              splat = "splat_goo", hit_sfx = "squish", die_sfx = "squish_die", loot = "drop", loot_chance = 0.3, wander = 3 },
    slime_toxic = { inflict = { kind = "septic", chance = 0.35, dur = 1800 }, model = "slime_toxic", name = "Toxic Slime", hp = 46, dmg = 10, speed = 1.7, reach = 1.5, aggro = 11, xp = 24, gold = { 2, 6 }, cd = 85, height = 0.7, radius = 0.5, anim = "clip",
                    splat = "splat_toxic", hit_sfx = "squish", die_sfx = "squish_die", loot = "drop", loot_chance = 0.4, wander = 3 },
    intern = { inflict = { kind = "bleed", chance = 0.2, dur = 480 }, model = "intern", name = "Skeletal Intern", hp = 44, dmg = 9, speed = 1.6, reach = 2.0, aggro = 13, xp = 22, gold = { 1, 5 }, cd = 110, height = 2.4, radius = 0.5,
               splat = "splat_bone", hit_sfx = "bone", die_sfx = "bone_die", ragdoll = true, loot = "drop", loot_chance = 0.4, wander = 2 },
    goblin = { model = "goblin_sales", name = "Goblin Sales Associate", hp = 38, dmg = 8, speed = 2.1, reach = 1.9, aggro = 14, xp = 20, gold = { 2, 8 }, cd = 90, height = 1.75, radius = 0.5,
               splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", ragdoll = true, loot = "goblin", loot_chance = 0.5, wander = 2, pack = true },
    rat = { inflict = { kind = "septic", chance = 0.2, dur = 1500 }, model = "rat", name = "Cellar Rat", hp = 14, dmg = 4, speed = 3.2, reach = 1.2, aggro = 14, xp = 7, gold = { 0, 1 }, cd = 60, height = 0.7, radius = 0.35,
            splat = "splat_red", hit_sfx = "squeak", die_sfx = "squeak_die", loot = "drop", loot_chance = 0.1, wander = 4, pack = true },
    spitter = { inflict = { kind = "septic", chance = 0.3, dur = 1800 }, model = "spitter", name = "Mushroom Spitter", hp = 30, dmg = 8, speed = 1.0, reach = 11, aggro = 12, xp = 26, gold = { 2, 7 }, cd = 150, height = 1.4, radius = 0.5, ranged = true, keep = 7,
                splat = "splat_spore", hit_sfx = "squish", die_sfx = "squish_die", ragdoll = true, loot = "drop", loot_chance = 0.4, wander = 1.5 },
    foreman = { model = "foreman", name = "Goblin Foreman", hp = 340, dmg = 17, speed = 1.9, reach = 2.7, aggro = 16, xp = 160, gold = { 40, 70 }, cd = 100, height = 2.9, radius = 0.9, miniboss = true,
                splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", ragdoll = true, loot = "silver", loot_chance = 1, slam = true },
    manager = { model = "manager", name = "The Floor Manager", hp = 620, dmg = 20, speed = 1.7, reach = 3.2, aggro = 40, xp = 400, gold = { 150, 250 }, cd = 110, height = 3.9, radius = 1.2, boss = true,
                splat = "splat_red", hit_sfx = "boss_hit", die_sfx = "boss_die", ragdoll = true, loot = "platinum", loot_chance = 1 },
    -- the rigged kit figures (docs/ANIMATION.md, EQUIPMENT.md): drawn with finer voxels, they play the clips idle / walk / run / attack (event `hit`) / cast (event `cast`) / hit / die and carry things.
    -- `kit` is what they hold (equipment slots), `die_clip` replaces the ragdoll (a drawn-only model cannot go limp)
    orc = { inflict = { kind = "bleed", chance = 0.2, dur = 600 }, model = "figures/monster_orc_captain_green", name = "Orc Compliance Officer", hp = 110, dmg = 13, speed = 2.1, reach = 2.0, aggro = 14, xp = 40, gold = { 5, 15 }, cd = 95, height = 2.0, radius = 0.55,
            anim = "clip", die_clip = true, kit = { main_hand = "iron_sword.vxm", off_hand = "round_shield.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "goblin", loot_chance = 0.5, wander = 2, pack = true },
    bandit = { inflict = { kind = "bleed", chance = 0.3, dur = 600 }, model = "figures/human_man_warrior", name = "Disgruntled Contractor", hp = 80, dmg = 9, speed = 2.6, reach = 1.9, aggro = 15, xp = 32, gold = { 3, 11 }, cd = 80, height = 1.8, radius = 0.5,
               anim = "clip", die_clip = true, kit = { main_hand = "iron_sword.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "drop", loot_chance = 0.45, wander = 2 },
    samurai = { inflict = { kind = "bleed", chance = 0.45, dur = 720 }, model = "figures/human_man_samurai", name = "Redundant Samurai", hp = 120, dmg = 15, speed = 2.9, reach = 2.0, aggro = 16, xp = 55, gold = { 6, 18 }, cd = 75, height = 1.8, radius = 0.5,
                anim = "clip", die_clip = true, kit = { main_hand = "iron_sword.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "silver", loot_chance = 0.5, wander = 1.5 },
    imp = { model = "figures/human_demon_girl", name = "Intern from Marketing", hp = 70, dmg = 13, speed = 1.4, reach = 12, aggro = 15, xp = 38, gold = { 4, 12 }, cd = 140, height = 1.8, radius = 0.5, ranged = true, keep = 8, cast = "ember",
            anim = "clip", die_clip = true, kit = { main_hand = "wooden_staff.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "drop", loot_chance = 0.5, wander = 1.5 },
    troll = { inflict = { kind = "bleed", chance = 0.3, dur = 720 }, model = "figures/monster_troll_blue", name = "Troll of the Night Shift", hp = 230, dmg = 22, speed = 1.6, reach = 2.5, aggro = 14, xp = 85, gold = { 10, 28 }, cd = 110, height = 2.6, radius = 0.8,
              anim = "clip", die_clip = true, kit = { main_hand = "battle_axe.vxm" }, splat = "splat_red", hit_sfx = "boss_hit", die_sfx = "goblin_die", loot = "silver", loot_chance = 0.6, wander = 1.5 },
    cyclops = { model = "figures/monster_cyclop_pink", name = "Cyclops Auditor", hp = 520, dmg = 27, speed = 1.9, reach = 3.0, aggro = 18, xp = 220, gold = { 50, 90 }, cd = 100, height = 3.1, radius = 1.0, miniboss = true,
                anim = "clip", die_clip = true, kit = { main_hand = "battle_axe.vxm" }, splat = "splat_red", hit_sfx = "boss_hit", die_sfx = "boss_die", loot = "gold", loot_chance = 1 },
    -- rival crawlers (the show's other contestants: a named elite on some floors, with a bounty)
    rival_samurai = { model = "figures/human_man_samurai", name = "Rival Crawler", hp = 380, dmg = 22, speed = 3.1, reach = 2.1, aggro = 18, xp = 260, gold = { 80, 140 }, cd = 55, height = 1.8, radius = 0.5, miniboss = true, rival = true,
                      anim = "clip", die_clip = true, kit = { main_hand = "iron_sword.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "gold", loot_chance = 1, inflict = { kind = "bleed", chance = 0.4, dur = 720 } },
    rival_adventurer = { model = "figures/human_man_adventurer", name = "Rival Crawler", hp = 440, dmg = 20, speed = 2.5, reach = 2.0, aggro = 18, xp = 260, gold = { 80, 140 }, cd = 75, height = 1.8, radius = 0.5, miniboss = true, rival = true,
                         anim = "clip", die_clip = true, kit = { main_hand = "iron_sword.vxm", off_hand = "round_shield.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "gold", loot_chance = 1 },
    rival_witch = { model = "figures/human_woman_adventurer", name = "Rival Crawler", hp = 300, dmg = 18, speed = 1.9, reach = 12, aggro = 20, xp = 260, gold = { 80, 140 }, cd = 110, height = 1.8, radius = 0.5, miniboss = true, rival = true, ranged = true, keep = 9, cast = "ember",
                    anim = "clip", die_clip = true, kit = { main_hand = "wooden_staff.vxm" }, splat = "splat_red", hit_sfx = "goblin_hit", die_sfx = "goblin_die", loot = "gold", loot_chance = 1 },
    auditor = { model = "figures/monster_cyclop_pink", name = "The Chief Auditor", hp = 600, dmg = 23, speed = 1.9, reach = 3.1, aggro = 40, xp = 480, gold = { 180, 280 }, cd = 110, height = 3.1, radius = 1.0, boss = true,
                anim = "clip", die_clip = true, meter = true, clips = { summon = "cast", throw = "cast", slam = "attack", roar = "cast" }, minion = "bandit", kit = { main_hand = "battle_axe.vxm" },
                splat = "splat_red", hit_sfx = "boss_hit", die_sfx = "boss_die", loot = "platinum", loot_chance = 1 },
    golem = { model = "figures/monster_gold_golem", name = "The Golden Parachute", hp = 650, dmg = 24, speed = 1.7, reach = 3.4, aggro = 40, xp = 520, gold = { 200, 320 }, cd = 130, height = 3.4, radius = 1.3, boss = true,
              anim = "clip", die_clip = true, clips = { summon = "cast", throw = "cast", slam = "attack", roar = "cast" }, minion = "orc", splat = "splat_red", hit_sfx = "boss_hit", die_sfx = "boss_die", loot = "platinum", loot_chance = 1 },
}

function E.define_fx()
    -- hits: a spray that vanishes (sparks fall, puffs drift). Deaths: the same, plus `debris`, which SETTLES into the world as real voxels: the stains, bones and lumps of a fight stay where
    -- they fell (and are saved with the world). Wall chips below never use debris.
    local function splat(name, mat, count, gore_mat, chunk)
        fx.define{ name = name, emitters = {
            { class = "spark", material = mat, count = count or 16, speed = 34, speed_jitter = 0.6, spread = 0.9, life = 1.0, size = 1.3, radius = 2, direction = { 0, 1, 0 } },
            { class = "puff", material = mat, count = 4, size = 5, duration = 0.25, darkness = 0.15, direction = { 0, 1, 0 }, speed = 9, spread = 0.7 } } }
        fx.define{ name = "gore" .. name:sub(6), emitters = {
            { class = "spark", material = mat, count = (count or 16) + 12, speed = 40, speed_jitter = 0.7, spread = 1.2, life = 1.1, size = 1.4, radius = 3, direction = { 0, 1, 0 } },
            { class = "debris", material = gore_mat or mat, count = 40, speed = 32, speed_jitter = 0.8, spread = 1.5, life = 2.0, size = 1.0, radius = 3, direction = { 0, 1, 0 } },
            { class = "debris", material = chunk or gore_mat or mat, count = 12, speed = 22, speed_jitter = 0.8, spread = 1.5, life = 2.0, size = 1.0, radius = 3, direction = { 0, 1, 0 } },
            { class = "puff", material = mat, count = 8, size = 6, duration = 0.35, darkness = 0.25, direction = { 0, 1, 0 }, speed = 10, spread = 1.0 } } }
    end
    splat("splat_goo", "goo", 22, "goo", "goo"); splat("splat_toxic", "toxic", 22, "goo", "toxic"); splat("splat_bone", "bone", 14, "bone", "flesh")
    splat("splat_red", "blood", 14, "blood", "flesh"); splat("splat_spore", "glowcap", 14, "blood", "glowcap")
    fx.define{ name = "chip_stone", emitters = { { class = "spark", material = "stone", count = 10, speed = 30, speed_jitter = 0.6, spread = 0.9, life = 0.6, size = 1.4, radius = 1.5 },
                                                  { class = "puff", material = "stone", count = 3, size = 3, duration = 0.2, darkness = 0.2, direction = { 0, 1, 0 }, speed = 5, spread = 0.8 },
                                                  { class = "spark", material = "metal", count = 5, speed = 40, speed_jitter = 0.5, spread = 0.9, life = 0.3, size = 0.5, radius = 1 } } }
    fx.define{ name = "chip_wood", emitters = { { class = "spark", material = "wood", count = 10, speed = 24, speed_jitter = 0.6, spread = 0.9, life = 0.7, size = 1.2, radius = 1 },
                                                 { class = "puff", material = "wood", count = 2, size = 3, duration = 0.2, darkness = 0.1, direction = { 0, 1, 0 }, speed = 5, spread = 0.7 } } }
    fx.define{ name = "chip_metal", emitters = { { class = "spark", material = "metal", count = 24, speed = 55, speed_jitter = 0.5, spread = 0.9, life = 0.5, size = 0.6, radius = 1 } } }
    fx.define{ name = "slash", emitters = { { class = "spark", material = "metal", count = 10, speed = 40, speed_jitter = 0.5, spread = 0.6, life = 0.4, size = 0.6, radius = 1, direction = { 0, 0.3, 1 } } } }
    fx.define{ name = "poof", emitters = { { class = "puff", material = "stone", count = 8, size = 6, duration = 0.3, darkness = 0.3, direction = { 0, 1, 0 }, speed = 8, spread = 0.9 } } }
end

-- ---------------------------------------------------------------------------------------------- spawning
function E.position(inst)
    local info = agent.info(inst.id)
    if not info then return nil end
    return info.x, info.y, info.z, info
end

-- lx, lz (metres, local frame), ly = height above the lobby floor (the floor of the room)
function E.spawn(kind, lx, ly, lz, opts)
    local T = E.types[kind]
    if not T then error("unknown enemy " .. tostring(kind)) end
    opts = opts or {}
    local speed = T.speed * ((opts.affix == "swift") and 1.45 or 1)
    local id = agent.spawn{ x = G.mx(lx), y = G.my(ly) + 0.05, z = G.mz(lz), speed = speed, model = "models/" .. T.model .. ".vxm", creature = T.creature or kind,
                            animation = T.anim or "auto", turn_smoothing = 6 }
    if not id then return nil end
    local name = opts.name or T.name
    if opts.affix then name = ({ swift = "Swift ", armored = "Armored ", explosive = "Volatile " })[opts.affix] .. name end
    local inst = { id = id, mdl = id - 0x40000000, kind = kind, T = T, hp = T.hp * (opts.hp_mult or 1), max_hp = T.hp * (opts.hp_mult or 1), state = "idle",
                   next_attack = 0, stun_until = 0, room = opts.room, height = T.height, radius = T.radius, home = { lx, ly, lz }, born = time.tick(), name = name, index = opts.index,
                   dmg_mult = opts.dmg_mult or 1, affix = opts.affix, rematch = opts.rematch }
    if G.gen and G.gen.rules and G.floorgen.active then G.gen.rules.on_spawn(inst) end
    -- what it holds: items as models of their own that follow the hand ("attach"): a merged item changes the agent's hidden collision box, and that made recordings of fights replay to another hash
    if T.kit then
        local sock = { main_hand = "grip_r", off_hand = "grip_l" }
        for slot, f in pairs(T.kit) do pcall(model.attach, id, f, sock[slot], { mode = "attach", name = slot }) end
    end
    E.list[id] = inst
    E.by_model[inst.mdl] = inst
    if T.wander and not opts.still then agent.wander(id, T.wander) end
    if kind == "spitter" then model.procedural(inst.mdl, { look = { part = "head", limit_yaw = 60, limit_pitch = 30 } }) end
    return inst
end

-- a room's population: list of { kind, x, z [, y] } in local metres. Only the rooms near the player are alive (the engine allows 64 agents): rooms are spawned when the player comes close
-- and taken away again when he leaves; what was killed stays dead (W.remaining), a room that was cleared stays cleared (saved).
E.remaining = {}      -- room -> { [index] = true } of the entries still alive
E.spawned = {}        -- room -> true while its enemies exist
function E.spawn_room(room, list)
    if G.state.cleared[room] or E.spawned[room] then return 0 end
    E.spawned[room] = true
    local rem = E.remaining[room]
    local n = 0
    for i, e in ipairs(list) do
        if e.captive and G.state.opened[e.captive] then rem = rem            -- (let out already)
        elseif not rem or rem[i] then
            local fl = (G.run and G.run.floor_no() or 1) - 1
            local inst = E.spawn(e[1], e[2], e[4] or 0, e[3], { room = room, hp_mult = (1 + (G.state.level - 1) * 0.03) * (1 + fl * 0.2) * (e.hp or 1) * G.run.diff().hp, dmg_mult = (1 + fl * 0.1) * G.run.diff().dmg, affix = e.affix, name = e.name, rematch = e.rematch, index = i })
            if inst then n = n + 1; if e.captive then inst.captive = e.captive; agent.stop(inst.id) end end
        end
    end
    return n
end

function E.despawn_room(room)
    if not E.spawned[room] then return end
    E.spawned[room] = nil
    local rem = {}
    for id, inst in pairs(E.list) do
        if inst.room == room then
            if not inst.dead then rem[inst.index or 0] = true end
            agent.remove(id)
            E.list[id] = nil
            E.by_model[inst.mdl] = nil
        end
    end
    E.remaining[room] = rem
end

-- a new floor: nobody of the old one is left (the dead are gone with their rooms)
function E.reset_floor()
    for id in pairs(E.list) do pcall(agent.remove, id) end
    G.ally.inst = nil
    E.list, E.by_model, E.remaining, E.spawned, E.corpses = {}, {}, {}, {}, {}
    for _, l in ipairs(E.loot) do pcall(body.remove, l.body) end
    for _, p in ipairs(E.projectiles) do pcall(body.remove, p.body) end
    E.loot, E.projectiles = {}, {}
end

function E.alive_in(room)
    local n = 0
    for _, inst in pairs(E.list) do if inst.room == room and not inst.dead and not inst.captive then n = n + 1 end end
    return n
end

function E.alive_count()
    local n = 0
    for _, inst in pairs(E.list) do if not inst.dead then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------------------------------------- damage and death
local function wpos(inst)
    local x, y, z = E.position(inst)
    return x, y, z
end

function E.damage(inst, amount, opts)
    if inst.captive or (inst.ally and not (opts and opts.source == "test")) then return end
    if inst.affix == "armored" and amount > 0 then amount = amount * 0.65 end
    if opts and opts.source == "fire" then amount = amount * G.skills.fire_mult() end
    if inst.dead then return end
    opts = opts or {}
    local P = G.player
    if inst.marked and inst.marked > time.tick() then amount = amount * 2 end
    if opts.crit then amount = amount end
    amount = floor(amount + 0.5)
    inst.hp = inst.hp - amount
    inst.last_damage = time.tick()
    local x, y, z = wpos(inst)
    P.hitmark = time.tick(); P.hitmark_crit = opts.crit; P.hitmark_wall = false
    if G.state.flags.flat_numbers or not x then
        P.popup((opts.crit and "CRIT " or "") .. amount, opts.crit and "#ffd24a" or "#ffffff", opts.crit)       -- the plain numbers over the crosshair (Settings: "Damage numbers")
    else
        local kind = (inst.T.boss and "boss") or (opts.source == "fire" and "fire") or (opts.crit and "crit") or "plain"
        -- in front of the body (towards the player, at the edge of its radius) and at chest height, never higher than a head above the player's eyes: a number above a tall monster could not be seen up close
        local px, py, pz = player.pos()
        local dx, dz = px - x, pz - z
        local n = math.max(0.01, math.sqrt(dx * dx + dz * dz))
        local off = math.min(inst.radius * 0.9, n - 0.6)
        local ny = math.min(y + inst.height * 0.72, py + 2.0)
        G.vnum.show(amount, x + dx / n * off, ny, z + dz / n * off, kind, 1, inst.id)
    end
    G.sfx.play(opts.crit and "hit_crit" or "hit", nil, nil, nil, 0.8)
    if inst.T.hit_sfx then G.sfx.play(inst.T.hit_sfx, G.to_local(x, y, z)) end
    if x then
        fx.play(inst.T.splat or "splat_red", floor(x * 16), floor((y + inst.height * 0.6) * 16), floor(z * 16), 0.7)
        if inst.hp > 0 then G.gore.wound(inst, x, y + inst.height * 0.4, z, false) end
    end
    if opts.burn and G.rand() < opts.burn then E.ignite(inst) end
    -- aggro: whoever hits it is its business now
    if inst.state == "idle" then E.aggro(inst) end
    if G.show and opts.source ~= "test" then G.show.on_hit(amount) end
    if inst.T.meter and inst.meter and opts.source ~= "test" then inst.meter = inst.meter + 1.2 + math.min(amount, 40) * 0.12 end        -- the Auditor keeps count of every blow
    if inst.hp <= 0 then E.kill(inst, opts); return end
    -- a flinch (the clip), a stun for the big hits
    local T = inst.T
    if not T.boss and not inst.no_flinch then
        if not inst.attacking then model.play(inst.mdl, "hit", 1.0, false, 2) end
        local stun = opts.stun or (opts.crit and 30 or 0)
        if T.miniboss then stun = 0 end
        if stun > 0 then
            inst.stun_until = time.tick() + stun
            inst.state = "stunned"
            agent.stop(inst.id)
        end
    end
end

function E.damage_area(x, y, z, r, dmg, source)
    local n = 0
    for _, inst in pairs(E.list) do
        if not inst.dead then
            local ix, iy, iz = wpos(inst)
            if ix and G.dist3(ix, iy + inst.height * 0.5, iz, x, y, z) <= r + inst.radius then
                E.damage(inst, dmg, { source = source, stun = 40 })
                n = n + 1
            end
        end
    end
    return n
end

function E.ignite(inst)
    if inst.burning then return end
    inst.burning = time.tick() + 240
end

function E.kill(inst, opts)
    if inst.dead then return end
    opts = opts or {}
    local T, s, A, P = inst.T, G.state, G.announcer, G.player
    inst.dead = true
    inst.state = "dead"
    local x, y, z = wpos(inst)
    s.kills = s.kills + 1
    A.bump("kills_" .. inst.kind)
    local k = A.bump("kills")
    if not T.boss then A.award("first_blood") end
    local gold = G.irange(T.gold[1], T.gold[2])
    if G.state.marked_bonus and inst.marked then gold = gold * 2 end
    gold = floor(gold * (1 + P.gold_bonus()) + (inst.marked and inst.marked > time.tick() and gold or 0))
    s.gold = s.gold + gold
    if gold > 0 then P.log("+" .. gold .. " gold", "#ffd24a"); G.skills.bump("haggling", gold) end
    P.add_xp(floor(T.xp * (1 + 0.0 * s.level)), "kill")
    if x then G.sfx.play(T.die_sfx or "squish_die", G.to_local(x, y, z)) end
    -- overkill: more than twice the hp that was left
    if inst.hp < -inst.max_hp * 0.8 then A.award("overkill") end
    if inst.kind == "slime" or inst.kind == "slime_toxic" then if (A.bump("slimes") or 0) >= 10 then A.award("squeegee") end end
    if G.show then G.show.on_kill(inst, opts) end
    if T.rival then
        local bounty = 150 + 100 * (G.run and G.run.floor_no() or 1)
        s.gold = s.gold + bounty
        P.log("+" .. bounty .. " gold (bounty on " .. inst.name .. ")", "#ffd24a")
        s.rival = nil
        A.say_key("rival.dead", { prio = 2 }, inst.name, bounty)
    end
    if T.boss and G.floorgen.active and (A.bump("gen_bosses") or 0) >= 3 then A.award("reshuffle") end
    if opts.source == "fire" or inst.burning then G.skills.bump("pyromania") end
    if opts.source == "barrel" then G.skills.bump("demolition") end
    if G.gen and G.gen.rules and G.floorgen.active then G.gen.rules.on_kill(inst) end
    if inst.burning then A.award("pyro") end
    if x then
        G.gore.wound(inst, x, y + inst.height * 0.4, z, true)
        fx.play(((T.splat or "splat_red"):gsub("^splat", "gore")), floor(x * 16), floor((y + inst.height * 0.4) * 16), floor(z * 16), T.boss and 2.2 or (T.miniboss and 1.6 or 1.1))
        if T.die_clip then
            model.play(inst.mdl, "die", 1, false, 6)
        elseif T.ragdoll then
            local fx_, fy_, fz_ = player.forward()
            model.ragdoll(inst.mdl, true, fx_ * 120, 60, fz_ * 120)
        end
        if inst.affix == "explosive" then
            after(20, function() fx.explosion(floor(x * 16), floor((y + 0.6) * 16), floor(z * 16), 20, 0.4); E.shockwave(inst, x, y, z, 3.2, 22) end)
        end
    end
    agent.stop(inst.id)
    -- drops
    if x and G.rand() < (T.loot_chance or 0) then
        local item = G.items.roll(T.loot or "drop", inst.id)
        E.drop(x, y + 0.3, z, "item", item)
    end
    if x and gold > 3 then E.drop(x, y + 0.3, z, "gold", gold) end
    -- the cleanup of the body
    local id, mdl = inst.id, inst.mdl
    -- the body stays for a while (the last 8 bodies of the floor): it fades away when the 9th falls or after 40 s; single-part monsters (slimes) burst at once
    E.corpses = E.corpses or {}
    local function clear_it()
        if E.list[id] then E.list[id] = nil; E.by_model[mdl] = nil; agent.remove(id) end
    end
    if T.ragdoll or T.die_clip then
        E.corpses[#E.corpses + 1] = clear_it
        if #E.corpses > 8 then table.remove(E.corpses, 1)() end
        after(2400, clear_it)
    else
        after(20, clear_it)
    end
    if inst.room and E.alive_in(inst.room) == 0 and G.on_room_cleared then G.on_room_cleared(inst.room) end
    -- GLEE comments (not on every kill: she gets bored)
    if T.boss then
        A.say_key("kill.boss", { prio = 2 })
        if G.boss and G.boss.on_dead then G.boss.on_dead(inst) end
    elseif T.miniboss then
        if inst.kind == "foreman" then A.say_key("kill.foreman", { prio = 2 }) else A.say_key("kill.miniboss", { prio = 2 }, inst.name) end
    else
        A.say_key("kill." .. inst.kind, { prio = 0, key = "kill_" .. inst.kind, cooldown = 900 })
        if k % 5 == 0 then A.say_key("kill.streak", { prio = 0, key = "kill_streak", cooldown = 600 }, k) end
    end
    if G.companion and G.companion.on_kill then G.companion.on_kill(inst) end
end

function E.on_player_death()
    for _, inst in pairs(E.list) do
        if not inst.dead and not inst.ally and not inst.captive then
            inst.state = "idle"
            agent.stop(inst.id)
            if inst.T.wander then agent.wander(inst.id, inst.T.wander) end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- loot on the floor
function E.drop(x, y, z, kind, payload)
    if not x then return end
    local mat = (kind == "gold") and "gold" or "lantern"
    local sz = (kind == "gold") and 3 or 4
    local b = body.box(x + G.range(-0.2, 0.2), y, z + G.range(-0.2, 0.2), sz, sz, sz, mat)
    E.loot[#E.loot + 1] = { body = b, kind = kind, payload = payload, born = time.tick() }
end

local function pickup(l)
    local A = G.announcer
    if l.kind == "gold" then
        G.state.gold = G.state.gold + l.payload
        G.player.log("+" .. l.payload .. " gold", "#ffd24a")
        G.sfx.play("coin")
    else
        local d = G.items.defs[l.payload]
        if G.items.add(l.payload, 1) then
            G.player.log(d.name, d.color)
            G.sfx.play("pickup")
            if d.rarity ~= "common" then A.say_key("item." .. d.rarity, { key = "item_" .. d.rarity, cooldown = 600 }, d.name) end
            local n = 0
            for _, s in ipairs(G.items.inv.bag) do if s then n = n + 1 end end
            if n >= 18 then A.award("hoarder") end
        else
            G.player.popup("BAG FULL", "#ff8080")
            return false
        end
    end
    return true
end

function E.tick_loot(t)
    local px, py, pz = player.pos()
    for i = #E.loot, 1, -1 do
        local l = E.loot[i]
        local x, y, z, ok = body.pos(l.body)
        if not ok or (t - l.born) > 5400 then
            if ok then body.remove(l.body) end
            table.remove(E.loot, i)
        elseif G.dist3(x, y, z, px, py + 0.8, pz) < 1.7 and not G.player.dead then
            if pickup(l) then
                body.remove(l.body)
                table.remove(E.loot, i)
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- the AI
local function has_los(x0, y0, z0, x1, y1, z1)
    local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
    local d = sqrt(dx * dx + dy * dy + dz * dz)
    local n = max(1, floor(d / 0.4))
    for i = 1, n - 1 do
        local f = i / n
        if world.solid(floor((x0 + dx * f) * 16), floor((y0 + dy * f) * 16), floor((z0 + dz * f) * 16)) then return false end
    end
    return true
end
E.has_los = has_los

function E.aggro(inst, quiet)
    if inst.dead or inst.captive or inst.ally or inst.state == "chase" or inst.state == "attack" then return end
    inst.state = "chase"
    inst.aggro_tick = time.tick()
    if inst.affix and not inst.warned then inst.warned = true; G.player.popup(inst.name:upper(), "#ff9a5a", true) end
    if inst.T.rival and not inst.warned then
        inst.warned = true
        G.player.popup(inst.name:upper(), "#ff4fa3", true)
        G.state.rival = inst.name
        G.announcer.say_key(inst.rematch and "rival.again" or "rival.intro", { prio = 2 }, inst.name)
    end
    local T = inst.T
    if T.ranged then agent.follow(inst.id, T.keep or 8) else agent.follow(inst.id, max(0.9, T.reach * 0.7)) end
    if not quiet and T.pack then
        for _, o in pairs(E.list) do
            if o ~= inst and not o.dead and o.state == "idle" and o.T.pack then
                local ox, oy, oz = wpos(o); local ix, iy, iz = wpos(inst)
                if ox and G.dist3(ox, oy, oz, ix, iy, iz) < 9 then E.aggro(o, true) end
            end
        end
    end
end

local function do_attack(inst, t)
    local T = inst.T
    inst.next_attack = t + T.cd
    inst.attacking = true
    inst.attack_until = t + 40
    inst.state = "attack"
    agent.stop(inst.id)
    model.play(inst.mdl, T.cast and "cast" or (T.slam and G.rand() < 0.35 and "slam" or "attack"), 1, false, 3)
end

function E.ai(inst, t)
    if inst.dead then return end
    local info = agent.info(inst.id)
    if not info then return end
    local px, py, pz = player.pos()
    local d = G.dist2(info.x, info.z, px, pz)
    local dy = abs((info.y + inst.height * 0.5) - (py + 0.9))
    inst.dist = d
    -- burning: damage over time
    if inst.burning then
        if t > inst.burning then inst.burning = nil
        elseif t % 24 < E.AI_PERIOD then E.damage(inst, max(2, floor(inst.max_hp * 0.03)), { source = "fire" }) end
    end
    if inst.dead then return end
    if inst.ally then return G.ally.ai(inst, t, d, dy, info) end
    if G.player.dead or G.safe then
        if inst.state ~= "idle" then inst.state = "idle"; agent.stop(inst.id); if inst.T.wander then agent.wander(inst.id, inst.T.wander) end end
        return
    end
    if inst.captive then return end
    if inst.ally then return G.ally.ai(inst, t, d, dy, info) end
    if inst.ai or inst.T.ai then return (inst.ai or inst.T.ai)(inst, t, d, dy, info) end
    if inst.state == "stunned" then
        if t >= inst.stun_until then inst.state = "idle"; E.aggro(inst, true) end
        return
    end
    if inst.attacking then
        if t >= inst.attack_until then
            inst.attacking = false
            inst.state = "idle"
            E.aggro(inst, true)
        end
        return
    end
    if inst.state == "idle" then
        if d < inst.T.aggro * (inst.aggro_mult or 1) and dy < 4 then
            if has_los(info.x, info.y + 1.2, info.z, px, py + 1.4, pz) or d < 4 then E.aggro(inst) end
        end
    elseif inst.state == "chase" then
        if d > inst.T.aggro * 2 or dy > 8 then
            inst.state = "idle"
            agent.stop(inst.id)
            if inst.T.wander then agent.wander(inst.id, inst.T.wander) end
        elseif d <= inst.T.reach and t >= inst.next_attack and dy < 3 then
            if not inst.T.ranged or has_los(info.x, info.y + 1.2, info.z, px, py + 1.4, pz) then do_attack(inst, t) end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- animation events and projectiles
function E.on_anim(mdl, event, clip)
    local inst = E.by_model[mdl]
    if not inst or inst.dead then return false end
    local px, py, pz = player.pos()
    local x, y, z = wpos(inst)
    if not x then return true end
    if inst.ally then
        if event == "hit" or event == "cast" then G.ally.on_hit(inst) end
        return true
    end
    if event == "hit" then
        local d = G.dist2(x, z, px, pz)
        if d <= inst.T.reach + 0.9 and abs(y - py) < 3 then
            local dealt = G.player.hurt(inst.T.dmg * (inst.dmg_mult or 1) * G.contracts.edmg() * (0.9 + G.rand() * 0.2), inst.name)
            local inf = inst.T.inflict
            if inf and dealt and dealt > 0 and G.rand() < inf.chance then G.skills.afflict(inf.kind, inf.dur) end
        end
        G.sfx.play("swing", G.to_local(x, y + 1, z), 0.5, 0.7)
    elseif event == "slam" then
        E.shockwave(inst, x, y, z, inst.T.boss and 6 or 4.2, inst.T.dmg * 1.3)
    elseif event == "spit" then
        E.spit(inst, x, y, z)
    elseif event == "cast" and inst.T.cast then
        E.spit(inst, x, y, z, inst.T.cast)
    end
    if inst.T.boss and G.boss and G.boss.on_event then G.boss.on_event(inst, event, x, y, z) end
    return true
end

function E.shockwave(inst, x, y, z, r, dmg)
    G.sfx.play("slam", G.to_local(x, y, z))
    fx.explosion(floor(x * 16), floor(y * 16) + 2, floor(z * 16), inst.T.boss and 22 or 12, 0.35)
    local px, py, pz = player.pos()
    if G.dist2(x, z, px, pz) <= r and abs(py - y) < 2.2 then G.player.hurt(dmg, inst.name) end
end

function E.spit(inst, x, y, z, mat)
    local px, py, pz = player.pos()
    local sx, sy, sz = x, y + 1.1, z
    local dx, dy, dz = px - sx, (py + 1.1) - sy, pz - sz
    local d = max(0.1, sqrt(dx * dx + dy * dy + dz * dz))
    local b = body.ball(sx + dx / d * 0.7, sy, sz + dz / d * 0.7, 3, mat or "toxic")
    local sp = 11
    body.push(b, dx / d * sp * 40, (dy / d * sp + 2.4) * 40, dz / d * sp * 40)
    E.projectiles[#E.projectiles + 1] = { body = b, born = time.tick(), dmg = inst.T.dmg * (inst.dmg_mult or 1), from = inst.name, fx = (mat == "ember") and "splat_red" or "splat_toxic" }
    G.sfx.play("spit", G.to_local(x, y, z))
end

function E.tick_projectiles(t)
    local px, py, pz = player.pos()
    for i = #E.projectiles, 1, -1 do
        local p = E.projectiles[i]
        local x, y, z, ok = body.pos(p.body)
        local gone = (not ok) or (t - p.born > 220)
        if ok and not gone and G.dist3(x, y, z, px, py + 1.0, pz) < 1.0 then
            G.player.hurt(p.dmg, p.from)
            if (p.fx or "splat_toxic") == "splat_toxic" and G.rand() < 0.3 then G.skills.afflict("septic", 1800) end
            fx.play(p.fx or "splat_toxic", floor(x * 16), floor(y * 16), floor(z * 16), 0.8)
            gone = true
        end
        if gone then
            if ok then body.remove(p.body) end
            table.remove(E.projectiles, i)
        end
    end
end

-- fire hurts: anything standing in flames or embers (a cell at the feet or the knees) takes damage every half second and catches fire itself
-- is something burning at the feet (the floor layer, the cell above it, a cell to each side)? The carpet is one voxel thick: the burning voxel is the floor itself.
-- (world.burning(x, y, z) is the engine's own answer, exact; the first version of this scanned for ember cells)
local function on_fire(x, y, z, h)
    local cx, cz = floor(x * 16), floor(z * 16)
    for _, oy in ipairs({ -0.02, 0.05, 0.4 }) do
        local cy = floor((y + oy) * 16)
        for _, o in ipairs({ { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if world.burning(cx + o[1], cy, cz + o[2]) then return true end
        end
    end
    return false
end

function E.tick_fire(t)
    if t % 30 ~= 0 then return end
    for _, inst in pairs(E.list) do
        if not inst.dead then
            local x, y, z = E.position(inst)
            if x and on_fire(x, y, z) then
                E.damage(inst, max(3, floor(inst.max_hp * 0.04)), { source = "fire" })
                if not inst.dead then E.ignite(inst) end
            end
        end
    end
    local px, py, pz = player.pos()
    if not G.player.dead and not G.safe and on_fire(px, py, pz) then G.player.hurt(4, "the flames", { pierce = true }) end
end

function E.tick(t)
    E.tick_fire(t)
    local n = 0
    for _, inst in pairs(E.list) do
        n = n + 1
        if (t + inst.id) % E.AI_PERIOD == 0 then E.ai(inst, t) end
    end
    if t % 4 == 0 then E.tick_loot(t); E.tick_projectiles(t) end
end

function on_agent(id, what)
    local inst = E.list[id]
    if inst and not inst.dead and what == "fell" then
        inst.hp = 0
        E.kill(inst, {})
    end
    if G.companion and G.companion.on_agent then G.companion.on_agent(id, what) end
end
