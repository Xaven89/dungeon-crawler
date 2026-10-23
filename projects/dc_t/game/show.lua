-- show: the audience. Every fight is a performance: SPECTACLE points (combos, traps, bosses, crates, a clean floor) raise the show's numbers; the viewers watch, followers follow, and every few
-- thousand followers one of them marks the contestant a FAVORITE: a favorite makes a sponsor send a box to the next safe room (one in four is a joke). The recap screen at the stairs adds it up.
Game = Game or {}
local G = Game
local S = {}
G.show = S
local floor, max, min = math.floor, math.max, math.min

S.SPONSORS = { "Borant Pest Control", "Skullface Energy Drinks", "Mister Wiggles Funeral Home", "Dunder-Mifflin-Adjacent Paper", "The Mild Death Insurance Co.", "Hydration Station No. 9",
               "Goblin Litigation Group", "Moist Towelette Holdings" }
S.TROLL = { "rubber_chicken", "branded_water", "autograph" }

function S.st()
    local s = G.state
    if not s.show then s.show = { followers = 0, favorites = 0, fav_total = 0, views = 0, buzz = 0, combo = 0, combo_t = 0, peak = 0, total = 0, boxes = {} } end
    return s.show
end

-- the floor's own numbers (the recap): reset at every arrival
function S.floor_begin()
    local s, sh = G.state, S.st()
    sh.prev_points = sh.fs and sh.fs.points or 0
    sh.boxes = {}
    sh.fs = { t0 = time.tick(), kills = s.kills, gold = s.gold, deaths = s.deaths, followers = sh.followers, views = sh.views, crates = G.announcer.counters.crates or 0, best_hit = 0, best_combo = 0,
              worst_hit = 0, worst_src = "", points = 0, cleared = 0, stains = G.announcer.counters.cleaned or 0 }
end

-- points of spectacle: `label` pops up when it is worth showing
function S.score(points, label)
    local sh = S.st()
    if G.floorgen and G.floorgen.active then points = points * G.gen.rules.spectacle() end
    points = points * G.contracts.spectacle()
    sh.buzz = min(300, sh.buzz + points)
    sh.total = sh.total + points
    if sh.fs then sh.fs.points = sh.fs.points + points end
    local before = floor(sh.followers / 2500)
    sh.followers = sh.followers + floor(points * 35)
    local after_ = floor(sh.followers / 2500)
    if after_ > before then
        sh.favorites = sh.favorites + (after_ - before); sh.fav_total = sh.fav_total + (after_ - before)
        G.player.popup(tr("show.favorite"), "#ffd24a", true)
        G.sfx.play("achievement", nil, nil, nil, 0.6)
    end
    if label and points >= 8 then G.player.log("+" .. points .. " " .. label, "#ff8fd0") end
end

function S.on_kill(inst, opts)
    local sh = S.st()
    local now = time.tick()
    if now - sh.combo_t < 300 then sh.combo = sh.combo + 1 else sh.combo = 1 end
    sh.combo_t = now
    if sh.fs and sh.combo > sh.fs.best_combo then sh.fs.best_combo = sh.combo end
    local T = inst.T
    local pts = 4 + (T.xp or 10) / 12
    local src = opts and opts.source
    local label = tr("show.kill")
    if T.boss then pts = pts + 120; label = tr("show.boss")
    elseif T.miniboss then pts = pts + 40; label = tr("show.miniboss") end
    if inst.affix then pts = pts + 10 end
    if src == "barrel" then pts = pts + 12; label = tr("show.barrel")
    elseif src == "boulder" then pts = pts + 15; label = tr("show.boulder")
    elseif src == "fire" then pts = pts + 6; label = tr("show.fire")
    elseif opts and opts.crit then pts = pts + 3 end
    if sh.combo >= 2 then
        pts = pts * (1 + min(sh.combo, 6) * 0.25)
        G.player.popup(tr("show.combo", sh.combo), "#ff8fd0", sh.combo >= 4)
        if sh.combo == 3 or sh.combo == 6 then G.announcer.say_key("show.combo", { prio = 0, key = "combo" .. sh.combo, cooldown = 600 }, sh.combo) end
    end
    S.score(floor(pts + 0.5), label)
end

function S.on_hit(amount) local sh = S.st(); if sh.fs and amount > sh.fs.best_hit then sh.fs.best_hit = amount end end
function S.on_hurt(amount, src)
    local sh = S.st()
    if sh.fs and amount > sh.fs.worst_hit then sh.fs.worst_hit, sh.fs.worst_src = amount, tostring(src) end
end

function S.viewers()
    local sh = S.st()
    local f = (G.run and G.run.floor_no() or 1)
    return floor((200000 + sh.followers * 12) * (1 + f * 0.15) * (1 + sh.buzz / 80) * G.contracts.viewers())
end

function S.tick(t)
    if not G.state or not G.state.class then return end
    local sh = S.st()
    if t % 30 == 0 then
        sh.buzz = sh.buzz * 0.985
        local target = S.viewers()
        sh.views = floor(sh.views + (target - sh.views) * 0.2)
        if sh.views > sh.peak then sh.peak = sh.views end
    end
end

-- ---------------------------------------------------------------------------------------------- the sponsors' boxes
-- called when the player is in a safe room: the favorites turn into boxes in that room
local SPOTS = { 0, 2.1, 4.2 }
function S.deliver(room)
    local sh = S.st()
    if sh.favorites <= 0 or not room then return end
    local F = G.floorgen
    local p = F and F.layout
    if not p then return end
    local placed = 0
    for _, b in ipairs(sh.boxes) do if b.room == room.id then placed = placed + 1 end end
    local n = min(3 - placed, sh.favorites)
    if n <= 0 then return end
    local f = p.floor
    local peak = max(sh.fs and sh.fs.points or 0, sh.prev_points or 0)
    local tier = (peak >= 260) and "gold" or ((peak >= 90) and "silver" or "bronze")
    for k = 1, n do
        local slot = placed + k
        local id = "f" .. f .. "spon" .. (sh.fav_total - sh.favorites + k)
        if not G.state.opened[id] then
            local lx, lz = room.x + 14.6, room.z + 6.8 + SPOTS[slot]
            local troll = G.hash(f, sh.fav_total, k) < 0.25
            sh.boxes[#sh.boxes + 1] = { id = id, room = room.id, tier = tier, x = lx, z = lz, troll = troll, sponsor = 1 + floor(G.hash(f, k, 9) * #S.SPONSORS) % #S.SPONSORS }
            S.declare(sh.boxes[#sh.boxes])
        end
    end
    sh.favorites = sh.favorites - n
    G.announcer.say_key("show.sponsor", { prio = 1 }, S.SPONSORS[sh.boxes[#sh.boxes].sponsor], n)
    G.sfx.play("crate_open", nil, nil, nil, 0.4, 1.4)
end

-- the box's voxels (when it is new) and its button (every start)
function S.declare(b)
    local T = G.traps
    if b.troll then T.crate_loot[b.id] = { S.TROLL[1 + floor(G.hash(#b.id, floor(b.x * 10), 3) * #S.TROLL) % #S.TROLL] } end
    T.build_crate_now(b.id, b.tier, b.x, 0, b.z, "-x")
    if not G.state.opened[b.id] then
        T.crate_hooks[b.id] = function()
            G.announcer.say_key(b.troll and "show.troll" or "show.thanks", { prio = 1 }, S.SPONSORS[b.sponsor])
        end
    end
end

-- a saved run: the boxes that were delivered and not opened are declared again
function S.redeclare()
    local sh = S.st()
    for _, b in ipairs(sh.boxes or {}) do
        if not G.state.opened[b.id] then
            local T = G.traps
            if b.troll then T.crate_loot[b.id] = { S.TROLL[1 + floor(G.hash(#b.id, floor(b.x * 10), 3) * #S.TROLL) % #S.TROLL] } end
            T.crate(b.id, b.tier, b.x, 0, b.z, "-x")
        end
    end
end

-- ---------------------------------------------------------------------------------------------- the recap
function S.open_recap()
    local s, sh = G.state, S.st()
    local fs = sh.fs or {}
    local r = {
        floor = G.run.floor_no(),
        secs = floor((time.tick() - (fs.t0 or 0)) / 60),
        kills = s.kills - (fs.kills or 0), gold = s.gold - (fs.gold or 0), deaths = s.deaths - (fs.deaths or 0),
        crates = (G.announcer.counters.crates or 0) - (fs.crates or 0),
        best_hit = fs.best_hit or 0, best_combo = fs.best_combo or 0, worst_hit = fs.worst_hit or 0, worst_src = fs.worst_src or "",
        points = fs.points or 0, followers = sh.followers - (fs.followers or 0), views = sh.views, views_gain = sh.views - (fs.views or 0),
        stains = (G.announcer.counters.cleaned or 0) - (fs.stains or 0),
    }
    local pts = r.points
    r.rank = (pts >= 450) and "S" or ((pts >= 250) and "A" or ((pts >= 120) and "B" or ((pts >= 50) and "C" or "D")))
    G.announcer.award("hello_world")
    r.line = tr("show.rank." .. r.rank)
    S.recap = r
    G.screen = "recap"
end
