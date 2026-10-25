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
M.combat = nil                        -- the handle of the drum layer

function M.set(bed) M.want = bed end
function M.on_room(room)
    if G.boss and G.boss.active then return end
    local r = G.world.rooms[room]
    M.want = M.room_bed[room] or (r and M.kind_bed[r.kind]) or "dungeon"
end

local function in_combat()
    for _, inst in pairs(G.enemies.list) do
        if not inst.dead and (inst.state == "chase" or inst.state == "attack") and (inst.dist or 99) < 20 then return true end
    end
    return false
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

function M.tick(t)
    if not M.enabled or not G.state or not G.state.class then return end
    if t % 20 ~= 0 then return end
    local want = M.want
    if want ~= M.cur_name and not (M.done == want) then M.crossfade_to(want) end
    local bed = M.beds[want]
    -- a "once" bed (the victory fanfare) plays one time through and then the room's own bed comes back
    if bed and bed.once and M.cur_name == want and not M.once_at then M.once_at = t + 480 end
    if M.once_at and t >= M.once_at then M.once_at = nil; M.done = want; M.want = M.room_bed[G.current_room or "lobby"] or "dungeon" end
    -- the fight layer
    local fighting = in_combat() and not G.safe and want ~= "boss"
    if fighting and not M.combat then G.sfx.logline("m_combat", "music", 1.0, 1, false); M.combat = sound.play{ file = "sounds/m_combat.wav", loop = true, bus = "music", volume = 1.0, fade_in = 0.6 }
    elseif not fighting and M.combat then sound.stop(M.combat, 2.5); M.combat = nil end
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
