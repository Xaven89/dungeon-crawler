-- music: the director. One looping file per bed (tools/make_sounds.py) played as a 2D sound on the music bus (sound.play{ loop = true, bus = "music" }, docs/AUDIO.md): a bed per area (lobby jingle,
-- dungeon drone, ballroom waltz, cave bells, safe room music box, boss riff, victory) and a drum layer on top while enemies are after you. Changing the bed is a crossfade: the old loop is stopped with a
-- fade, the new one starts with a fade in. The volume of the three buses (sfx, music, voice) is the player's (settings in the bag screen, saved).
Game = Game or {}
local G = Game
local M = {}
G.music = M

M.beds = { lobby = { file = "m_lobby", vol = 0.6 }, dungeon = { file = "m_dungeon", vol = 0.8 }, ballroom = { file = "m_ballroom", vol = 0.6 },
           cave = { file = "m_cave", vol = 0.75 }, safe = { file = "m_safe", vol = 0.6 }, boss = { file = "m_boss", vol = 0.55 }, victory = { file = "m_victory", vol = 0.7, once = true } }
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
M.bus = { music = 1.4, sfx = 1.0, voice = 1.0 }
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
    if fighting and not M.combat then G.sfx.logline("m_combat", "music", 0.7, 1, false); M.combat = sound.play{ file = "sounds/m_combat.wav", loop = true, bus = "music", volume = 0.7, fade_in = 0.6 }
    elseif not fighting and M.combat then sound.stop(M.combat, 2.5); M.combat = nil end
end

-- (a game setting that lives next to the sound ones) damage numbers as voxel particles, or as flat text over the crosshair
function M.set_flat_numbers(on) G.state.flags.flat_numbers = on and true or false end
