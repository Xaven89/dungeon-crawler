-- ally: a monster you let out of its cage (the Captive room). It follows you, fights what is near and goes with you down the stairs. One at a time, it cannot be hurt: the dungeon respects a
-- good deed about as much as it respects rank (compare the goose).
Game = Game or {}
local G = Game
local A = {}
G.ally = A
local floor, max, min = math.floor, math.max, math.min

A.inst = nil

-- a freed captive (an enemy instance that was `captive`) becomes the ally
function A.adopt(inst)
    if A.inst and not A.inst.dead then A.release_old() end
    inst.captive, inst.ally, inst.room, inst.state = nil, true, nil, "follow"
    inst.index = nil
    inst.name = "Freed " .. inst.T.name
    A.inst = inst
    G.state.ally = inst.kind
    agent.stop(inst.id)
    agent.follow(inst.id, 3.0)
    G.announcer.say_key("ally.freed", { prio = 1 }, inst.T.name)
    G.announcer.award("peta")
end

function A.release_old()
    local old = A.inst
    if old and G.enemies.list[old.id] then agent.remove(old.id); G.enemies.list[old.id] = nil; G.enemies.by_model[old.mdl] = nil end
    A.inst = nil
end

-- next to the player (a new floor, a lost ally)
function A.respawn()
    local kind = G.state.ally
    if not kind or not G.enemies.types[kind] then return end
    A.release_old()
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local e = G.enemies.spawn(kind, lx - 2, ly, lz - 2, { room = nil, still = true })
    if e then
        e.ally, e.state = true, "follow"
        e.name = "Freed " .. e.T.name
        A.inst = e
        agent.follow(e.id, 3.0)
    end
end

local function nearest_enemy(x, z, r)
    local best, bd
    for _, o in pairs(G.enemies.list) do
        if not o.dead and not o.ally and not o.captive and o.room then
            local ox, oy, oz = G.enemies.position(o)
            if ox then local d = G.dist2(x, z, ox, oz); if d < r and (not bd or d < bd) then best, bd = o, d end end
        end
    end
    return best, bd
end

-- called from E.ai for an ally
function A.ai(inst, t, d, dy, info)
    if G.player.dead then return end
    local tg, td = nearest_enemy(info.x, info.z, 14)
    if tg and not G.safe then
        local ox, oy, oz = G.enemies.position(tg)
        if inst.target ~= tg then inst.target = tg; agent.follow(inst.id, max(0.9, inst.T.reach * 0.7)) ; inst.following_player = false end
        if td and td <= inst.T.reach and t >= inst.next_attack then
            inst.next_attack = t + inst.T.cd
            agent.stop(inst.id)
            model.play(inst.mdl, inst.T.cast and "cast" or "attack", 1, false, 3)
            inst.swing_target = tg
            inst.reattack = t + 40
        end
    else
        inst.target = nil
        if not inst.following_player then inst.following_player = true; agent.follow(inst.id, 3.0) end
        -- a long way behind: it is put next to the player
        if d > 25 then A.respawn() end
    end
    if inst.reattack and t >= inst.reattack then inst.reattack = nil; if inst.target then agent.follow(inst.id, max(0.9, inst.T.reach * 0.7)) end end
end

-- the clip's `hit`: the blow lands
function A.on_hit(inst)
    local tg = inst.swing_target
    inst.swing_target = nil
    if tg and not tg.dead then
        G.enemies.damage(tg, inst.T.dmg * 0.7 + (G.state.level or 1) * 0.6, { source = "ally", stun = 25 })
        do local lx, ly, lz = G.to_local(G.enemies.position(tg)); G.sfx.play("hit", lx, ly, lz, 1.25) end
    end
end
