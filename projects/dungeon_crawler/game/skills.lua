-- skills: what the contestant gets better at by doing it (a list that fills in as you play), and conditions: named things that happen to the body (Bleed, Septic), with cures.
Game = Game or {}
local G = Game
local K = {}
G.skills = K
local floor, max, min = math.floor, math.max, math.min

-- id -> { name, what counts, thresholds for levels 1..5 (the count), what a level does }
K.defs = {
    brawling   = { name = "Brawling",   thr = { 30, 100, 250, 500, 900 },   desc = "Hits landed. +4% damage per level." },
    mopcraft   = { name = "Mopcraft",   thr = { 10, 30, 70, 140, 250 },     desc = "Stains mopped up. A wider swing and +1 gold per spot per level." },
    pyromania  = { name = "Pyromania",  thr = { 5, 15, 40, 80, 150 },       desc = "Things burned to death. +15% fire damage per level." },
    demolition = { name = "Demolitions", thr = { 3, 8, 16, 30, 50 },       desc = "Things blown up. 15% less damage from explosions per level." },
    haggling   = { name = "Haggling",   thr = { 200, 600, 1500, 4000, 9000 }, desc = "Gold earned. +3% gold per level." },
    dodging    = { name = "Dodging",    thr = { 20, 60, 150, 300, 600 },    desc = "Hits taken. +0.6% dodge per level." },
    looting    = { name = "Looting",    thr = { 3, 8, 15, 30, 50 },         desc = "Crates opened. A bonus item from level 2, another from level 4." },
}
K.order = { "brawling", "mopcraft", "pyromania", "demolition", "haggling", "dodging", "looting" }

function K.st()
    local s = G.state
    if not s.skills then s.skills = {} end
    return s.skills
end
function K.count(id) return K.st()[id] or 0 end
function K.level_of(id, count)
    local d = K.defs[id]
    local lv = 0
    for i, t in ipairs(d.thr) do if count >= t then lv = i end end
    return lv
end
function K.level(id) return K.level_of(id, K.count(id)) end

function K.bump(id, n)
    local st = K.st()
    local before = K.level_of(id, st[id] or 0)
    st[id] = (st[id] or 0) + (n or 1)
    local after = K.level_of(id, st[id])
    if after > before then
        G.player.popup(tr("skill.up", K.defs[id].name, after), "#7fe0ff", true)
        G.player.log(tr("skill.up", K.defs[id].name, after), "#7fe0ff")
        G.announcer.say_key("skill.up", { prio = 1 }, K.defs[id].name, after)
        G.sfx.play("levelup", nil, nil, nil, 0.5, 1.4)
        if G.show then G.show.score(10, nil) end
    end
end

-- ---------------------------------------------------------------------------------------------- conditions
K.COND = { bleed = { name = "BLEEDING", color = "#ff5a5a" }, septic = { name = "SEPTIC", color = "#9be34a" } }

function K.afflict(kind, dur)
    local s = G.state
    if G.safe or G.player.dead or not s.class then return end
    s.cond = s.cond or {}
    local now = time.tick()
    local fresh = not (s.cond[kind] and s.cond[kind] > now)
    s.cond[kind] = max(s.cond[kind] or 0, now + dur)
    if fresh then
        G.player.popup(K.COND[kind].name, K.COND[kind].color, true)
        G.announcer.say_key("cond." .. kind, { prio = 1, key = "cond_" .. kind, cooldown = 1800 })
    end
end

function K.has(kind) local c = G.state.cond; return c ~= nil and c[kind] ~= nil and c[kind] > time.tick() end
function K.cure(kind) local c = G.state.cond; if c and c[kind] and c[kind] > time.tick() then c[kind] = nil; G.player.log(tr("cond.cured", K.COND[kind].name), "#a6ffcc"); return true end return false end
function K.clear() G.state.cond = {} end

function K.tick(t)
    local s = G.state
    if not s or not s.class or G.player.dead then return end
    if G.safe and s.cond and (s.cond.bleed or s.cond.septic) then K.clear() end
    if t % 60 == 0 and K.has("bleed") then
        local px, py, pz = player.pos()
        G.player.hurt(3 + floor((G.run and G.run.floor_no() or 1) / 2), "bleeding", { pierce = true })
        if G.gore then G.gore.splat(px, py + 0.05, pz, "blood_stain", 0.45) end
    end
end

function K.heal_factor() return K.has("septic") and 0.5 or 1 end

-- ---------------------------------------------------------------------------------------------- the numbers the rest of the game asks for
function K.damage_mult() return 1 + 0.04 * K.level("brawling") end
function K.fire_mult() return 1 + 0.15 * K.level("pyromania") end
function K.blast_taken() return max(0.4, 1 - 0.15 * K.level("demolition")) end
function K.gold_mult() return 1 + 0.03 * K.level("haggling") end
function K.dodge_bonus() return 0.006 * K.level("dodging") end
function K.mop_bonus() return K.level("mopcraft") end
function K.extra_rolls() local l = K.level("looting"); return (l >= 2 and 1 or 0) + (l >= 4 and 1 or 0) end
