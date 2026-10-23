-- companion: Admiral Honk, a goose. He follows the contestant, bites whatever hostile comes within reach (small damage, large attitude), comments in his own voice, and is
-- never hurt: the dungeon respects rank. If he is left behind or stuck he is put back next to the player.
Game = Game or {}
local G = Game
local C = {}
G.companion = C
local floor, max, min = math.floor, math.max, math.min

C.id = nil
C.mdl = nil
C.state = "follow"
C.next_bite = 0
C.next_chatter = 0
C.target = nil
C.bites = 0

function C.spawn()
    if C.id then return end
    local px, py, pz = player.pos()
    local id = agent.spawn{ x = px - 1.2, y = py + 0.1, z = pz - 1.2, speed = 4.2, model = "models/honk.vxm", creature = "honk", animation = "auto", turn_smoothing = 8 }
    if not id then return end
    C.id, C.mdl = id, id - 0x40000000
    C.state = "follow"
    agent.follow(id, 2.8)
    C.next_chatter = time.tick() + 1800
end

function C.respawn()
    if C.id then agent.remove(C.id); C.id, C.mdl = nil, nil end
    C.spawn()
end

local function say(key)
    G.announcer.say_key(key, { who = "HONK", key = "honk_" .. key, cooldown = 900, prio = 0 })
end

function C.tick(t)
    if not G.state.class then return end
    if not C.id then if t % 60 == 0 and not G.player.dead then C.spawn() end return end
    if t % 10 ~= 0 then return end
    local info = agent.info(C.id)
    if not info then C.id = nil; return end
    local px, py, pz = player.pos()
    local d = G.dist3(info.x, info.y, info.z, px, py, pz)
    -- lost or stuck: put him back near the player
    if d > 28 or info.falling then
        C.respawn()
        return
    end
    -- he trots at the player's back right shoulder, not in front of the camera
    if C.state == "follow" and t % 30 == 0 then
        local fx_, fy_, fz_ = player.forward()
        local n = math.max(0.01, math.sqrt(fx_ * fx_ + fz_ * fz_))
        fx_, fz_ = fx_ / n, fz_ / n
        local sx, sz = px - fx_ * 2.4 - fz_ * 1.5, pz - fz_ * 2.4 + fx_ * 1.5
        if G.dist2(info.x, info.z, sx, sz) > 1.6 and d < 14 then
            local sy = nav.floor(sx, py + 0.5, sz)
            if sy then agent.walk(C.id, sx, sy, sz) else agent.follow(C.id, 2.8) end
        end
    end
    -- in the safe room he sits in his bed
    if G.safe then
        if C.state ~= "bed" then
            C.state = "bed"
            local bx, bz = G.mx(57.2), G.mz(132.1)
            agent.walk(C.id, bx, G.my(0.1), bz)
        end
        return
    elseif C.state == "bed" then
        C.state = "follow"; agent.follow(C.id, 2.8)
    end
    -- a target: a hostile close to him and not too far from the player
    if C.state == "attack" then
        local tg = C.target
        if not tg or tg.dead or not G.enemies.list[tg.id] then
            C.state = "follow"; C.target = nil; agent.follow(C.id, 2.8)
        else
            local ex, ey, ez = G.enemies.position(tg)
            if not ex then C.state = "follow"; C.target = nil; agent.follow(C.id, 2.8); return end
            local dd = G.dist2(info.x, info.z, ex, ez)
            if G.dist2(ex, ez, px, pz) > 16 then C.state = "follow"; C.target = nil; agent.follow(C.id, 2.8)
            elseif dd < 1.7 and t >= C.next_bite then
                C.next_bite = t + 80
                model.play(C.mdl, "attack", 1, false, 3)
                C.bite_target = tg
            elseif dd >= 1.7 and t % 30 == 0 then agent.walk(C.id, ex, ey, ez) end
        end
    else
        if t % 30 == 0 then
            local best, bd = nil, 1e9
            for _, inst in pairs(G.enemies.list) do
                if not inst.dead and not inst.T.boss then
                    local ex, ey, ez = G.enemies.position(inst)
                    if ex then
                        local dd = G.dist2(info.x, info.z, ex, ez)
                        if dd < 7 and G.dist2(ex, ez, px, pz) < 12 and dd < bd and math.abs(ey - info.y) < 3 then best, bd = inst, dd end
                    end
                end
            end
            if best then C.state = "attack"; C.target = best; say("honk") end
        end
    end
    -- idle chatter
    if t >= C.next_chatter and G.current_room and not G.screen then
        C.next_chatter = t + G.irange(2400, 4200)
        local keys = { "honk", "honk", "honk" }
        say("honk")
    end
end

function C.on_anim(m, event, clip)
    if m ~= C.mdl then return end
    if event == "hit" then
        local tg = C.bite_target
        C.bite_target = nil
        if tg and not tg.dead then
            local lv = G.state.level or 1
            G.enemies.damage(tg, 5 + lv * 1.6, { source = "honk", stun = 20 })
            C.bites = C.bites + 1
            G.sfx.play("honk_bite")
            G.announcer.bump("honk_bites")
            if (G.state.counters.honk_bites or 0) >= 5 then G.announcer.award("goose") end
            if tg.dead then C.on_kill_by_honk() end
        end
    elseif event == "honk" then
        G.sfx.play("honk")
    end
end

function C.on_kill_by_honk()
    G.announcer.say_key("honk.kill", { who = "HONK", key = "honk_kill", cooldown = 1200, prio = 1 })
end

function C.on_player_death()
    G.announcer.say_key("honk.dead", { who = "HONK", prio = 0, key = "honk_dead", cooldown = 600 })
end

function C.on_kill(inst) end
function C.on_agent(id, what)
    if id == C.id and (what == "stuck" or what == "no_path") then
        if C.state == "follow" then
            local px, py, pz = player.pos()
            local info = agent.info(C.id)
            if info and G.dist3(info.x, info.y, info.z, px, py, pz) > 10 then C.respawn() end
        end
    end
end

function C.honk()
    if not C.mdl then return end
    model.play(C.mdl, "honk", 1, false, 3)
    G.sfx.play("honk")
end
