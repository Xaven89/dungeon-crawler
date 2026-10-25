-- music: the director. One looping file per bed (tools/make_sounds.py) played as a 2D sound on the music bus (sound.play{ loop = true, bus = "music" }, docs/AUDIO.md): a bed per area (lobby jingle,
-- dungeon drone, ballroom waltz, cave bells, safe room music box, boss riff, victory) and a drum layer on top while enemies are after you. Changing the bed is a crossfade: the old loop is stopped with a
-- fade, the new one starts with a fade in. The volume of the three buses (sfx, music, voice) is the player's (settings in the bag screen, saved).
Game = Game or {}
local G = Game
local M = {}
G.music = M

M.beds = { lobby = { file = "m_lobby", vol = 1.0 }, dungeon = { file = "m_dungeon", vol = 1.0 }, ballroom = { file = "m_ballroom", vol = 1.0 },
           cave = { file = "m_cave", vol = 1.0 }, safe = { file = "m_safe", vol = 1.0 }, boss = { file = "m_boss", vol = 1.0 }, victory = { file = "m_victory", vol = 1.0, once = true } }
M.room_bed = { lobby = "lobby", hall = "dungeon", boiler = "dungeon", conveyor = "dungeon", gutter = "cave", ballroom = "ballroom", grotto = "cave", arena = "dungeon", stairwell = "safe" }
M.kind_bed = { village = "lobby", park = "dungeon", borough_arena = "dungeon", arrival = "safe", stairwell = "safe", safe = "safe", rest = "safe", stairs_free = "safe", guild = "lobby", grotto = "cave", flooded = "cave", crypt = "cave", ballroom = "ballroom", prize = "lobby" }      -- (generated rooms by theme)
M.want = "lobby"
M.enabled = true
M.cur, M.cur_name = nil, nil          -- the handle and the name of the bed that plays
M.combat = nil                        -- (retired: the old drum layer; the pieces carry their own combat stem)

function M.set(bed) M.want = bed end
function M.on_room(room)
    if G.boss and G.boss.active then return end
    local r = G.world.rooms[room]
    M.want = M.room_bed[room] or (r and M.kind_bed[r.kind]) or "dungeon"
end

-- who is after the player: "near" = an enemy chasing within 20 m; "fight" = an enemy attacking within 20 m, or the player was hurt in the last 3 s (the old combat test was both of these in one)
local function music_state()
    if G.safe then return "explore" end
    local near, fight = false, false
    for _, inst in pairs(G.enemies.list) do
        if not inst.dead and (inst.dist or 99) < 20 then
            if inst.state == "attack" then fight = true elseif inst.state == "chase" then near = true end
        end
    end
    if not fight and G.player.last_hurt and time.tick() - G.player.last_hurt < 180 then fight = true end
    return fight and "fight" or (near and "near" or "explore")
end

-- the buses: the saved settings (0..1.5, 1 = as made)
M.bus = { music = 1.0, sfx = 1.0, voice = 1.0 }
function M.apply_buses()
    for name, v in pairs(M.bus) do sound.bus(name, v) end
end
function M.set_bus(name, v)
    v = math.max(0, math.min(1.5, v))
    M.bus[name] = v
    sound.bus(name, v)
    if G.state then G.state.flags["bus_" .. name] = v end
end
function M.load_settings()
    for name in pairs(M.bus) do
        local v = G.state.flags["bus_" .. name]
        if type(v) == "number" then M.bus[name] = v end
    end
    M.apply_buses()
end

function M.crossfade_to(name)
    local bed = M.beds[name] or M.beds.dungeon
    if M.cur then sound.stop(M.cur, 2.0) end
    G.sfx.logline(bed.file, "music", bed.vol, 1, false)
    M.cur = sound.play{ file = "sounds/" .. bed.file .. ".wav", loop = true, bus = "music", volume = bed.vol, fade_in = 2.0 }
    M.cur_name = name
    M.done = nil
end

-- ---------------------------------------------------------------------------------------------- the pieces (voxel-audio step 4)
-- Up to four stems per piece (bed, lead, rhythm, combat) all started in ONE tick at volume 0 (E27: sample-locked, E29: silent) and never stopped while the piece plays: the director only moves their
-- volumes (sound.volume(h, v, fade)). explore = bed + lead; near (an enemy chasing within 20 m) adds the rhythm; fight ducks the bed / lead / rhythm by the table of the user's verdict (B2, the light duck)
-- and brings the combat stem up. The floor's stems are loaded when the piece starts and freed (E28) once the fade-out has ended. The room rule: a special room's piece (safe, boss) else the floor's.
M.VARIANT = "B2"
M.DUCK = {
    m_f1       = { B1 = { bed = 4, lead = 16, rhythm = 0 }, B2 = { bed = 1, lead = 11, rhythm = 0 } },
    m_lobby    = { B1 = { bed = 8, lead = 18, rhythm = 4 }, B2 = { bed = 6, lead = 12, rhythm = 1 } },
    m_f2       = { B1 = { bed = 8, lead = 12, rhythm = 5 }, B2 = { bed = 4, lead = 8, rhythm = 1 } },
    m_f3_day   = { B1 = { bed = 6, lead = 14, rhythm = 5 }, B2 = { bed = 2, lead = 10, rhythm = 0 } },
    m_f3_night = { B1 = { bed = 4, lead = 17, rhythm = 6 }, B2 = { bed = 0, lead = 13, rhythm = 2 } },
    m_f4       = { B1 = { bed = 9, lead = 15, rhythm = 4 }, B2 = { bed = 5, lead = 11, rhythm = 0 } },
    m_f5       = { B1 = { bed = 1, lead = 19, rhythm = 0 }, B2 = { bed = 0, lead = 13, rhythm = 0 } },
    m_f6       = { B1 = { bed = 0, lead = 21, rhythm = 3 }, B2 = { bed = 0, lead = 15, rhythm = 0 } },
    m_f7       = { B1 = { bed = 8, lead = 16, rhythm = 1 }, B2 = { bed = 4, lead = 12, rhythm = 0 } },
    m_f8       = { B1 = { bed = 1, lead = 18, rhythm = 0 }, B2 = { bed = 0, lead = 13, rhythm = 0 } },
    m_boss     = { B1 = { bed = 0, lead = 13, rhythm = 1 }, B2 = { bed = 0, lead = 8, rhythm = 0 } },
}
M.STEMS = setmetatable({ m_safe = { "bed", "lead" } }, { __index = function() return { "bed", "lead", "rhythm", "combat" } end })
M.h, M.piece, M.state, M.files = nil, nil, "explore", nil
M.pending, M.pending_n = nil, 0

local function vols(piece, state)
    if state == "explore" or not M.DUCK[piece] then return { bed = 1, lead = 1, rhythm = 0, combat = 0 } end
    if state == "near" then return { bed = 1, lead = 1, rhythm = 1, combat = 0 } end
    local d = M.DUCK[piece][M.VARIANT]
    return { bed = 10 ^ (-d.bed / 20), lead = 10 ^ (-d.lead / 20), rhythm = 10 ^ (-d.rhythm / 20), combat = 1 }
end

-- the piece for a bed name (the room rule's answer): nil for the old single-file beds that stay (the ballroom's waltz, the victory fanfare)
function M.piece_for(want)
    if want == "boss" then return "m_boss" end
    if want == "safe" then return "m_safe" end
    if want == "ballroom" or want == "victory" then return nil end
    local L = G.floorgen and G.floorgen.layout
    if not L then return "m_lobby" end                              -- the Orientation (gen/floor.lua:18)
    if L.floor == 3 then
        local OC = G.gen and G.gen.overcity
        return (OC and OC.is_night and OC.is_night()) and "m_f3_night" or "m_f3_day"
    end
    return "m_f" .. L.floor
end

function M.stop_piece(fade)
    if not M.h then return end
    local files = M.files
    for _, h in pairs(M.h) do pcall(sound.stop, h, fade) end
    M.h, M.piece, M.files = nil, nil, nil
    -- the samples stay resident until freed: once the fade-out is over (the engine refuses while a voice plays one, or within 3 ticks of a start)
    after(math.floor(fade * 60) + 30, function() for _, f in ipairs(files) do pcall(sound.unload, f) end end)
end

function M.start_piece(piece, fade)
    M.stop_piece(fade)
    local v = vols(piece, M.state)
    M.h, M.files = {}, {}
    for _, k in ipairs(M.STEMS[piece]) do
        local file = "sounds/" .. piece .. "_" .. k .. ".wav"
        M.files[#M.files + 1] = file
        G.sfx.logline(piece .. "_" .. k, "music", v[k], 1, false)
        M.h[k] = sound.play{ file = file, loop = true, bus = "music", volume = 0 }       -- silent (E29), then faded to the stem's volume in the same tick
        if M.h[k] then sound.volume(M.h[k], v[k], fade) end
    end
    M.piece = piece
end

function M.set_state(state)
    if state == M.state then return end
    M.state = state
    G.sfx.logline("state_" .. state, "music", 1, 1, false)
    if M.h and M.piece then
        local fade = ({ explore = 2.0, near = 1.5, fight = 1.0 })[state]
        for k, v in pairs(vols(M.piece, state)) do if M.h[k] then sound.volume(M.h[k], v, fade) end end
    end
end

function M.tick(t)
    if not M.enabled or not G.state or not G.state.class then return end
    if t % 20 ~= 0 then return end
    local want = M.want
    local piece = M.piece_for(want)
    if piece then
        -- a bed of the old kind that still plays goes away with the crossfade
        if M.cur then pcall(sound.stop, M.cur, 2.0); M.cur, M.cur_name = nil, nil end
        if piece ~= M.piece then
            -- a new piece is followed once it is wanted twice in a row (the moment between floors may show a stale layout); the first one starts at once
            if M.piece and piece ~= M.pending then M.pending, M.pending_n = piece, 1
            elseif M.piece then M.pending_n = M.pending_n + 1 end
            if not M.piece or M.pending_n >= 2 then M.start_piece(piece, 2.0); M.pending = nil end
        else
            M.pending = nil
        end
        M.set_state(music_state())
        return
    end
    -- the old single-file beds (the ballroom, the victory fanfare)
    if M.piece then M.stop_piece(2.0) end
    if want ~= M.cur_name and not (M.done == want) then M.crossfade_to(want) end
    local bed = M.beds[want]
    -- a "once" bed (the victory fanfare) plays one time through and then the room's own bed comes back
    if bed and bed.once and M.cur_name == want and not M.once_at then M.once_at = t + 480 end
    if M.once_at and t >= M.once_at then M.once_at = nil; M.done = want; M.want = M.room_bed[G.current_room or "lobby"] or "dungeon" end
end

-- ambience: the floor's bed under the music, and now and then one of its events far away (sounds/amb_*.wav, ev_*.wav; voxel-audio step 3). 2D loops on the sfx bus with 3 s crossfades; the choice, the
-- direction, the distance and the gap come from a counter and the tick, never the game's random numbers.
M.amb = {
    [0] = { bed = "amb_f0", ev = { "ev_f0_ding", "ev_f0_door" } },
    [1] = { bed = "amb_f1", ev = { "ev_f1_drip", "ev_f1_stone" } },
    [2] = { bed = "amb_f2", ev = { "ev_f2_pipe", "ev_f2_clang" } },
    [3] = { bed = "amb_f3_day", ev = { "ev_f3_bell", "ev_f3_bird" }, night = "amb_f3_night", ev_night = { "ev_f3n_owl", "ev_f3n_pub" } },
    [4] = { bed = "amb_f4", ev = { "ev_f4_train", "ev_f4_chime" } },
    [5] = { bed = "amb_f5", ev = { "ev_f5_drip", "ev_f5_splash" } },
    [6] = { bed = "amb_f6", ev = { "ev_f6_hiss", "ev_f6_clank" } },
    [7] = { bed = "amb_f7", ev = { "ev_f7_rattle", "ev_f7_gust" } },
    [8] = { bed = "amb_f8", ev = { "ev_f8_crack", "ev_f8_bloop" } },
}
M.amb_h, M.amb_name, M.amb_next, M.amb_n = nil, nil, 0, 0
M.amb_seen, M.amb_floor = nil, nil
function M.amb_tick(t)
    if t % 20 ~= 0 or not M.enabled or not G.state or not G.state.class then return end
    local L = G.floorgen and G.floorgen.layout
    local fl = L and L.floor or 0                               -- layout nil: the Orientation (gen/floor.lua:18)
    -- between floors layout can be stale or nil for a moment: follow a floor only once it is read twice in a row (40 ticks)
    if fl ~= M.amb_floor then
        if fl == M.amb_seen then M.amb_floor = fl else M.amb_seen = fl; return end
    end
    local A = M.amb[M.amb_floor]
    if not A then return end
    local OC = G.gen and G.gen.overcity
    local night = M.amb_floor == 3 and A.night and OC and OC.is_night and OC.is_night()   -- the over-city clock: only on floor 3
    local want = night and A.night or A.bed
    if want ~= M.amb_name then
        if M.amb_h then pcall(sound.stop, M.amb_h, 3) end
        G.sfx.logline(want, "sfx", 1, 1, false)
        M.amb_h = sound.play{ file = "sounds/" .. want .. ".wav", loop = true, bus = "sfx", fade_in = 3 }
        M.amb_name = want
        M.amb_next = t + 600                                    -- the first event 10 s after a floor starts
    end
    if t >= M.amb_next then
        local list = night and A.ev_night or A.ev
        M.amb_n = M.amb_n + 1
        local ang = (M.amb_n * 0.618034) % 1 * 2 * math.pi       -- golden-angle steps: every direction in turn
        local r = 12 + (M.amb_n * 7) % 19                       -- 12-30 m
        local px, py, pz = player.pos()
        G.sfx.play_world(list[M.amb_n % #list + 1], px + r * math.sin(ang), py + 1.5, pz + r * math.cos(ang))
        M.amb_next = t + 60 * (20 + (M.amb_n * 13) % 41)          -- 20-60 s to the next
    end
end

-- (a game setting that lives next to the sound ones) damage numbers as voxel particles, or as flat text over the crosshair
function M.set_flat_numbers(on) G.state.flags.flat_numbers = on and true or false end
