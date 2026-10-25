-- gen/rules: the rule set of a floor (from the seed). Floor 1 has none; later floors have one or two. They are announced on arrival, shown under the place name, and bend the game:
--   night   NIGHT SHIFT     the lights are half as strong, enemies notice you from farther away
--   dts     THE DTs         a countdown illness: after 4, 7 and 10 minutes on the floor every monster is a stage worse (marked, harder hitting, faster; the last stage hatches rats when it dies)
--   muted   QUIET FLOOR     in some rooms spells and abilities do nothing
--   crowd   CROWD PLEASER   a third more enemies, double the spectacle
--   third_rail THIRD RAIL   (floor 4 only, always) the bed of every track is live: standing in it (not on a car's deck, not on a platform) costs G.BAL.third_rail (14) health every half second
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local R = {}
G.gen.rules = R
local floor, max, min = math.floor, math.max, math.min

R.ALL = { "night", "dts", "muted", "crowd", "third_rail" }
R.POOL = { "night", "dts", "muted", "crowd" }        -- what a floor draws from (third_rail is the transit floor's own)
R.cur = {}            -- id -> true, for the floor in the world
R.muted_rooms = {}

function R.choose(seed, floor_n)
    if floor_n <= 1 then return {} end
    local r = G.gen.layout.make_rng(seed, floor_n, 31337)
    local pool = {}
    for _, id in ipairs(R.POOL) do pool[#pool + 1] = id end
    r.shuffle(pool)
    local out = { pool[1] }
    if floor_n >= 3 and r.next() < 0.45 then out[2] = pool[2] end
    if floor_n == 4 then out = { "third_rail", pool[1] } end
    return out
end

function R.apply(p)
    R.cur = {}
    for _, id in ipairs(p.rules or {}) do R.cur[id] = true end
    R.muted_rooms = {}
    if R.cur.muted then
        local r = G.gen.layout.make_rng(p.seed, p.floor, 555)
        for _, id in ipairs(p.order) do
            local room = p.rooms[id]
            if room.role == "room" and r.next() < 0.5 then R.muted_rooms[id] = true end
        end
    end
    R.stage = 0
    R.t0 = time.tick()
end

function R.has(id) return R.cur[id] == true end
function R.dark() return R.cur.night and 0.5 or 1.0 end
function R.aggro() return R.cur.night and 1.35 or 1.0 end
function R.count() return R.cur.crowd and 1.3 or 1.0 end
function R.spectacle() return R.cur.crowd and 2 or 1 end
function R.dmg() return 1 + (R.stage or 0) * (R.cur.dts and 0.3 or 0) end
function R.in_muted() return G.current_room ~= nil and R.muted_rooms[G.current_room] == true end

-- the DTs: stages at 4, 7 and 10 minutes
local STAGE_AT = { 4 * 3600, 7 * 3600, 10 * 3600 }
function R.stage_next()
    if not R.cur.dts or (R.stage or 0) >= 3 then return nil end
    return (R.t0 or 0) + STAGE_AT[(R.stage or 0) + 1]
end

-- the third rail: every 30 ticks, a player in the bed of a track (below the floor of its level) is hurt
function R.tick_third_rail(t)
    if t % 30 ~= 0 or not G.state.class or G.screen or G.player.dead then return end
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local lvl = (ly > 4) and 1 or 0
    if transit_on_bed(lx, lz, lvl) and ly < lvl * 8 - 0.08 then
        G.player.hurt(G.BAL.third_rail, "the third rail", { pierce = true })
        G.tally("zaps", "third_rail")
        if not R.rail_warned then R.rail_warned = true; G.announcer.say_key("rule.third_rail.zap", { prio = 2 }) end
        G.sfx.play_world("zap", px, py, pz)
    end
end

function R.tick(t)
    if R.cur.third_rail then R.tick_third_rail(t) end
    if not R.cur.dts or not G.state or not G.state.class or G.screen == "loading" then return end
    local nxt = R.stage_next()
    if nxt and t >= nxt then
        R.stage = (R.stage or 0) + 1
        G.announcer.say_key("rule.dts.stage" .. R.stage, { prio = 2 })
        G.sfx.play("rumble", nil, nil, nil, 0.8, 0.6)
        for _, inst in pairs(G.enemies.list) do
            if not inst.dead then inst.dmg_mult = (inst.dmg_mult or 1) * 1.3; if R.stage >= 2 then pcall(agent.speed, inst.id, inst.T.speed * 1.25) end end
        end
    end
end

-- a new enemy on a DTs floor starts at the floor's stage
function R.on_spawn(inst)
    if R.cur.dts and (R.stage or 0) > 0 then
        inst.dmg_mult = (inst.dmg_mult or 1) * (1 + 0.3 * R.stage)
        if R.stage >= 2 then pcall(agent.speed, inst.id, inst.T.speed * 1.25) end
    end
    inst.aggro_mult = R.aggro()
end

-- stage 3: what dies hatches
function R.on_kill(inst)
    if R.cur.dts and (R.stage or 0) >= 3 and inst.room and not inst.T.boss then
        local x, y, z = G.enemies.position(inst)
        if x then
            local lx, ly, lz = G.to_local(x, y, z)
            for k = 1, 2 do
                local e = G.enemies.spawn("rat", lx + (k - 1.5) * 0.8, 0, lz, { room = inst.room, index = 70 + k })
                if e then G.enemies.aggro(e, true) end
            end
        end
    end
end

-- the label under the place name
function R.label()
    local names = {}
    for _, id in ipairs(R.ALL) do if R.cur[id] then names[#names + 1] = tr("rule." .. id .. ".name") end end
    if #names == 0 then return nil end
    local s = table.concat(names, " + ")
    if R.cur.dts then
        local nxt = R.stage_next()
        if nxt then local left = max(0, floor((nxt - time.tick()) / 60)); s = s .. string.format("  (stage %d in %d:%02d)", (R.stage or 0) + 1, floor(left / 60), left % 60)
        else s = s .. "  (stage 3)" end
    end
    if R.in_muted() then s = s .. "  [MUTED]" end
    return s
end
