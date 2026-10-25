-- announcer: GLEE (General Logistics & Entertainment Engine), the show's host. Everything that happens is commented on: a queue of messages, shown on the HUD with a typewriter
-- and "spoken" as a babble of blips. Also the sound helper (Game.sfx) that every other module uses, and the achievements (GLEE has opinions about those too).
Game = Game or {}
local G = Game
local A = {}
G.announcer = A

-- ---------------------------------------------------------------------------------------------- sounds
G.sfx = {}
local sfx_index = {}
-- an opt-in log of every sound the game starts (for the sound audit: exact counts from a recording): `Game.sfx.log(true)` (the MCP lua tool, at the start of the session: a recording keeps the call, so a replay logs too),
-- then every sound prints  SFXLOG <tick> <name> <bus> <volume> <pitch> <2d|3d>  to the engine log. Not part of the saved state, no effect on the simulation.
G.sfx.logging = false
function G.sfx.log(on) G.sfx.logging = on and true or false end
-- (wx, wy, wz: the world position of a 3D sound: SFXBAD marks one more than 64 m from the player, which would be a position passed in the wrong frame)
function G.sfx.logline(name, bus, vol, pitch, is3d, wx, wy, wz)
    if not G.sfx.logging then return end
    print(string.format("SFXLOG %d %s %s %.2f %.2f %s", time.tick(), name, bus, vol or 1, pitch or 1, is3d and "3d" or "2d"))
    if is3d and wx and wy and wz then
        local px, py, pz = player.pos()
        local dh = math.sqrt((wx - px) ^ 2 + (wz - pz) ^ 2)
        if dh > 64 or math.abs(wy - py) > 24 then print(string.format("SFXBAD %d %s at (%.1f %.1f %.1f), the player at (%.1f %.1f %.1f): %.0f m", time.tick(), name, wx, wy, wz, px, py, pz, dh)) end
    end
end
local function load_sound(name)
    local v = sfx_index[name]
    if v == nil then
        v = sound.load("sounds/" .. name .. ".wav")
        sfx_index[name] = v
    end
    return v
end
-- variation sets (voxel-audio step 2): name.wav, name_2.wav .. name_N.wav, played in turn. A counter, not a random number: the sound is cosmetic, the simulation and its hash are untouched and a replay
-- plays the same variants. Never the same variant twice in a row.
G.sfx.variants = { swing = 4, hit = 4, goblin_hit = 4, hurt = 4, hit_crit = 2, boss_hit = 2, bone = 3, honk_bite = 3, zap = 3, slab_move = 2, slab_stop = 2 }
local VORDER, vcount, vlast = { 1, 3, 2, 4, 3, 1, 4, 2 }, {}, {}
local function variant(name)
    local n = G.sfx.variants[name]
    if not n then return name end
    local c = (vcount[name] or 0) + 1; vcount[name] = c
    local k = (VORDER[(c - 1) % #VORDER + 1] - 1) % n + 1
    if k == vlast[name] then k = k % n + 1 end
    vlast[name] = k
    return k == 1 and name or (name .. "_" .. k)
end
-- play a sound: at a local position (metres) in the world, or, with no position, 2D at the listener (no distance, no pan) on the sfx bus. `bus` and `loop` can be given in opts (a table as the last argument).
function G.sfx.play(name, lx, ly, lz, vol, pitch)
    name = variant(name)
    local idx = load_sound(name)
    if idx < 0 then return false end
    G.sfx.logline(name, "sfx", vol, pitch, lx ~= nil, lx and G.mx(lx), lx and G.my(ly), lx and G.mz(lz))
    if lx then return sound.play{ file = "sounds/" .. name .. ".wav", at = { G.mx(lx), G.my(ly), G.mz(lz) }, volume = vol or 1, pitch = pitch or 1, bus = "sfx" } end
    return sound.play{ file = "sounds/" .. name .. ".wav", volume = vol or 1, pitch = pitch or 1, bus = "sfx" }
end
-- a voice blip: 2D on the voice bus
function G.sfx.voice(name, vol, pitch)
    if load_sound(name) < 0 then return false end
    G.sfx.logline(name, "voice", vol, pitch, false)
    return sound.play{ file = "sounds/" .. name .. ".wav", volume = vol or 1, pitch = pitch or 1, bus = "voice" }
end
function G.sfx.play_world(name, wx, wy, wz, vol, pitch)
    name = variant(name)
    if load_sound(name) < 0 then return false end
    G.sfx.logline(name, "sfx", vol, pitch, true, wx, wy, wz)
    return sound.play{ file = "sounds/" .. name .. ".wav", at = { wx, wy, wz }, volume = vol or 1, pitch = pitch or 1, bus = "sfx" }
end
function G.sfx.preload(names) for _, n in ipairs(names) do load_sound(n) end end

-- ---------------------------------------------------------------------------------------------- the world's loops and moving doors (voxel-audio step 2b): cosmetic, nothing here touches the simulation
-- G.sfx.loop(key, file, lx, ly, lz [, fade]): one 3D loop at a local position unless that key already plays; loop_stop(key [, fade]); drop(prefix): everything whose key starts with the prefix (a cell going away).
-- G.sfx.bed(room, key, file, lx, ly, lz): a loop that plays while the player is in that room (fade in 2 s, out 2 s). G.sfx.watch_door(key, id, lx, lz): a door's travel is a `slab_move` that ends in a `slab_stop`.
G.sfx.loops, G.sfx.beds, G.sfx.doors = {}, {}, {}
function G.sfx.loop(key, file, lx, ly, lz, fade)
    if G.sfx.loops[key] then return end
    G.sfx.logline(file, "sfx", 1, 1, true, G.mx(lx), G.my(ly), G.mz(lz))
    G.sfx.loops[key] = sound.play{ file = "sounds/" .. file .. ".wav", loop = true, at = { G.mx(lx), G.my(ly), G.mz(lz) }, bus = "sfx", fade_in = fade or 1 } or true
end
function G.sfx.loop_stop(key, fade)
    local h = G.sfx.loops[key]
    if h == nil then return false end
    G.sfx.loops[key] = nil
    if type(h) == "number" then pcall(sound.stop, h, fade or 0.5) end
    return true
end
local function has_prefix(k, prefix) return k:sub(1, #prefix) == prefix end
function G.sfx.drop(prefix)
    for k in pairs(G.sfx.loops) do if has_prefix(k, prefix) then G.sfx.loop_stop(k, 0.3) end end
    for k in pairs(G.sfx.beds) do if has_prefix(k, prefix) then G.sfx.beds[k] = nil end end
    for k, w in pairs(G.sfx.doors) do if has_prefix(k, prefix) then if type(w.h) == "number" then pcall(sound.stop, w.h, 0.1) end; G.sfx.doors[k] = nil end end
end
function G.sfx.reset() G.sfx.drop("") end
function G.sfx.bed(room, key, file, lx, ly, lz) G.sfx.beds[key] = { room = room, file = file, x = lx, y = ly, z = lz } end
function G.sfx.watch_door(key, id, lx, lz) G.sfx.doors[key] = { id = id, x = lx, z = lz } end
function G.sfx.tick(t)
    if t % 5 ~= 0 then return end
    if next(G.sfx.doors) then
        local px, py, pz = player.pos()
        local plx, _, plz = G.to_local(px, py, pz)
        for k, w in pairs(G.sfx.doors) do
            local ok, st = pcall(events.state, w.id)
            local mv = ok and st and st.moving
            if mv and not w.h then
                if plx and G.dist2(plx, plz, w.x, w.z) < 30 then w.h = G.sfx.play("slab_move", w.x, 1.5, w.z) or true end
            elseif not mv and w.h then
                if type(w.h) == "number" then pcall(sound.stop, w.h, 0.08) end
                G.sfx.play("slab_stop", w.x, 1.5, w.z); w.h = nil
            end
        end
    end
    if t % 30 == 0 then
        for k, b in pairs(G.sfx.beds) do
            if G.current_room == b.room then G.sfx.loop("bed:" .. k, b.file, b.x, b.y, b.z, 2)
            else G.sfx.loop_stop("bed:" .. k, 2) end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- messages
A.queue = {}
A.current = nil
A.history = {}
A.cooldowns = {}
A.counters = {}
A.muted_until = 0

local variant_count = {}
local function count_variants(key)
    local n = variant_count[key]
    if n then return n end
    n = 0
    while has_text(key .. "." .. (n + 1)) do n = n + 1 end
    variant_count[key] = n
    return n
end

-- text for a key: key.1 .. key.N are variants (taken in turn, shuffled by a hash so that two runs are not the same cycle), a plain key is used as it is
function A.line(key, ...)
    local n = count_variants(key)
    if n == 0 then
        if has_text(key) then return tr(key, ...) end
        return nil
    end
    local c = (A.counters[key] or 0) + 1
    A.counters[key] = c
    local start = math.floor(G.hash(#key, n, G.hash_salt) * n)
    return tr(key .. "." .. (((start + c - 1) % n) + 1), ...)
end

local voice_sets = { GLEE = { pitch = 1.0, spread = 0.35 }, HONK = { pitch = 1.9, spread = 0.2 }, SYSTEM = { pitch = 0.0 } }

-- say(text, { who = "GLEE", prio = 0, color = , dur = ticks, key = cooldown key, cooldown = ticks, silent = true })
-- prio 0: queued after the current one (dropped when the queue is long); 1: next in line; 2: replaces what is on screen now
function A.say(text, opts)
    if not text or text == "" then return false end
    opts = opts or {}
    local now = time.tick()
    if opts.key then
        local cd = A.cooldowns[opts.key]
        if cd and now < cd then return false end
        A.cooldowns[opts.key] = now + (opts.cooldown or 600)
    end
    local msg = { text = text, who = opts.who or "GLEE", prio = opts.prio or 0, color = opts.color, silent = opts.silent }
    if G.sfx.logging then print(string.format("SAYLOG %d %s prio %d %s | %s", now, msg.who, msg.prio, tostring(opts.key), text:sub(1, 48))) end
    msg.dur = opts.dur or math.max(150, math.min(520, 80 + #text * 3))
    if msg.prio >= 2 then
        A.queue = {}
        A.current = nil
        table.insert(A.queue, 1, msg)
    elseif msg.prio == 1 then
        table.insert(A.queue, 1, msg)
    else
        if #A.queue >= 4 then
            if msg.who == "GLEE" then table.remove(A.queue, 1) else return false end   -- a long queue: the oldest comment is stale
        end
        A.queue[#A.queue + 1] = msg
    end
    return true
end

function A.say_key(key, opts, ...)
    local text = A.line(key, ...)
    if text then return A.say(text, opts) end
    return false
end

-- the babble: a blip per couple of characters, pitch following the letters
function A.voice(msg)
    if msg.silent then return end
    local set = voice_sets[msg.who] or voice_sets.GLEE
    if set.pitch == 0 then return end
    local text = msg.text
    local n = math.min(#text, 90)
    local blip = (msg.who == "HONK") and "honk_blip" or "voice_blip"
    for i = 1, n, 3 do
        local c = text:byte(i) or 100
        local pitch = set.pitch * (0.78 + ((c * 7) % 40) / 100)
        after(math.floor(i * 1.9), function() G.sfx.voice(blip, 1.0, pitch) end)
    end
end

function A.tick(t)
    if A.current and t >= A.current.t_end then
        A.history[#A.history + 1] = A.current
        if #A.history > 6 then table.remove(A.history, 1) end
        A.current = nil
        A.gap_until = t + 20
    end
    if not A.current and #A.queue > 0 and t >= (A.gap_until or 0) then
        A.current = table.remove(A.queue, 1)
        A.current.t_start = t
        A.current.t_end = t + A.current.dur
        A.voice(A.current)
    end
end

-- ---------------------------------------------------------------------------------------------- achievements
-- id = { stars = xp }, text in strings: achievement.<id>.name / .desc / .line
A.defs = {
    check_in      = { xp = 20 },
    hello_world   = { xp = 20 },
    first_blood   = { xp = 25 },
    squeegee      = { xp = 60 },
    peta          = { xp = 60 },
    clean_sweep   = { xp = 50 },
    deep_three    = { xp = 60 },
    deep_five     = { xp = 120 },
    contractor    = { xp = 50 },
    rank_s        = { xp = 80 },
    mimic_food    = { xp = 40 },
    favorite      = { xp = 30 },
    reshuffle     = { xp = 90 },
    hardcore_two  = { xp = 150 },
    fashionably   = { xp = 30 },
    serial_victim = { xp = 60 },
    pyro          = { xp = 50 },
    zero_g        = { xp = 40 },
    soggy         = { xp = 40 },
    loot_goblin   = { xp = 50 },
    crate_exp     = { xp = 70 },
    goose         = { xp = 40 },
    fine_print    = { xp = 80 },
    hoarder       = { xp = 50 },
    shopper       = { xp = 30 },
    boss_down     = { xp = 200 },
    pacifist_ish  = { xp = 40 },
    overkill      = { xp = 45 },
    rolling_stone = { xp = 50 },
    speedrunner   = { xp = 150 },
}
A.order = { "check_in", "hello_world", "first_blood", "squeegee", "peta", "clean_sweep", "favorite", "contractor", "mimic_food", "deep_three", "deep_five", "rank_s", "reshuffle", "hardcore_two", "fashionably", "serial_victim", "pyro", "zero_g", "soggy", "loot_goblin", "crate_exp", "goose", "fine_print", "hoarder", "shopper", "overkill", "rolling_stone", "pacifist_ish", "speedrunner", "boss_down" }
A.toasts = {}      -- { id, t } shown on the HUD for a few seconds

function A.has(id) return G.state and G.state.ach and G.state.ach[id] end

function A.award(id)
    if not A.defs[id] or A.has(id) then return false end
    G.state.ach[id] = time.tick()
    G.state.ach_count = (G.state.ach_count or 0) + 1
    A.toasts[#A.toasts + 1] = { id = id, t = time.tick() }
    G.sfx.play("achievement")
    if G.show then G.show.score(25, nil) end
    A.say(tr("achievement." .. id .. ".line"), { prio = 1, key = "ach_" .. id, cooldown = 1 })
    if G.player and G.player.add_xp then G.player.add_xp(A.defs[id].xp, "achievement") end
    G.save()
    return true
end

-- counters of things the player did (saved): A.count("kills_slime") ...
function A.bump(counter, n)
    local c = G.state.counters
    c[counter] = (c[counter] or 0) + (n or 1)
    return c[counter]
end
