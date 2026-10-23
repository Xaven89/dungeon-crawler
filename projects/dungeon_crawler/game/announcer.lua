-- announcer: GLEE (General Logistics & Entertainment Engine), the show's host. Everything that happens is commented on: a queue of messages, shown on the HUD with a typewriter
-- and "spoken" as a babble of blips. Also the sound helper (Game.sfx) that every other module uses, and the achievements (GLEE has opinions about those too).
Game = Game or {}
local G = Game
local A = {}
G.announcer = A

-- ---------------------------------------------------------------------------------------------- sounds
G.sfx = {}
local sfx_index = {}
local function load_sound(name)
    local v = sfx_index[name]
    if v == nil then
        v = sound.load("sounds/" .. name .. ".wav")
        sfx_index[name] = v
    end
    return v
end
-- play a sound: at a local position (metres) in the world, or, with no position, 2D at the listener (no distance, no pan) on the sfx bus. `bus` and `loop` can be given in opts (a table as the last argument).
function G.sfx.play(name, lx, ly, lz, vol, pitch)
    local idx = load_sound(name)
    if idx < 0 then return false end
    if lx then return sound.play{ file = "sounds/" .. name .. ".wav", at = { G.mx(lx), G.my(ly), G.mz(lz) }, volume = vol or 1, pitch = pitch or 1, bus = "sfx" } end
    return sound.play{ file = "sounds/" .. name .. ".wav", volume = vol or 1, pitch = pitch or 1, bus = "sfx" }
end
-- a voice blip: 2D on the voice bus
function G.sfx.voice(name, vol, pitch)
    if load_sound(name) < 0 then return false end
    return sound.play{ file = "sounds/" .. name .. ".wav", volume = vol or 1, pitch = pitch or 1, bus = "voice" }
end
function G.sfx.play_world(name, wx, wy, wz, vol, pitch)
    if load_sound(name) < 0 then return false end
    return sound.play{ file = "sounds/" .. name .. ".wav", at = { wx, wy, wz }, volume = vol or 1, pitch = pitch or 1, bus = "sfx" }
end
function G.sfx.preload(names) for _, n in ipairs(names) do load_sound(n) end end

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
        after(math.floor(i * 1.9), function() G.sfx.voice(blip, 0.5, pitch) end)
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
    clean_sweep   = { xp = 50 },
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
A.order = { "check_in", "hello_world", "first_blood", "squeegee", "clean_sweep", "fashionably", "serial_victim", "pyro", "zero_g", "soggy", "loot_goblin", "crate_exp", "goose", "fine_print", "hoarder", "shopper", "overkill", "rolling_stone", "pacifist_ish", "speedrunner", "boss_down" }
A.toasts = {}      -- { id, t } shown on the HUD for a few seconds

function A.has(id) return G.state and G.state.ach and G.state.ach[id] end

function A.award(id)
    if not A.defs[id] or A.has(id) then return false end
    G.state.ach[id] = time.tick()
    G.state.ach_count = (G.state.ach_count or 0) + 1
    A.toasts[#A.toasts + 1] = { id = id, t = time.tick() }
    G.sfx.play("achievement")
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
