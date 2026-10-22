-- music: the director. The engine can only start whole files at a place (docs/AUDIO.md: no streaming, no mixer), so the music is made of 2 second pieces (tools/make_sounds.py) that are played one
-- after the other at the player's head: a bed per area (lobby jingle, dungeon drone, ballroom waltz, cave bells, safe room music box, boss riff) and a drum layer on top while enemies are after you.
Game = Game or {}
local G = Game
local M = {}
G.music = M

M.beds = { lobby = { name = "m_lobby", n = 8, vol = 0.6 }, dungeon = { name = "m_dungeon", n = 8, vol = 0.8 }, ballroom = { name = "m_ballroom", n = 8, vol = 0.6 },
           cave = { name = "m_cave", n = 8, vol = 0.75 }, safe = { name = "m_safe", n = 8, vol = 0.6 }, boss = { name = "m_boss", n = 8, vol = 0.55 },
           victory = { name = "m_victory", n = 4, vol = 0.7, once = true } }
M.room_bed = { lobby = "lobby", hall = "dungeon", boiler = "dungeon", conveyor = "dungeon", gutter = "cave", ballroom = "ballroom", grotto = "cave", arena = "dungeon", stairwell = "safe" }
M.PIECE = 120          -- ticks per piece (2 s)
M.want = "lobby"
M.enabled = true

local piece_i, combat_i = 0, 0
local last_bed

function M.set(bed) M.want = bed end
function M.on_room(room)
    if G.boss and G.boss.active then return end
    M.want = M.room_bed[room] or "dungeon"
end

local function in_combat()
    local px, py, pz = player.pos()
    for _, inst in pairs(G.enemies.list) do
        if not inst.dead and (inst.state == "chase" or inst.state == "attack") and (inst.dist or 99) < 20 then return true end
    end
    return false
end

function M.tick(t)
    if not M.enabled or not G.state or not G.state.class then return end
    if t % M.PIECE ~= 0 then return end
    local bed = M.beds[M.want] or M.beds.dungeon
    if M.want ~= last_bed then piece_i = 0; last_bed = M.want end
    piece_i = piece_i % bed.n + 1
    if bed.once and M.done == M.want then
    else
        G.sfx.play(bed.name .. "_" .. piece_i, nil, nil, nil, bed.vol)
        if bed.once and piece_i == bed.n then M.done = M.want; after(M.PIECE, function() M.want = M.room_bed[G.current_room or "lobby"] or "dungeon" end) end
    end
    if in_combat() and not G.safe and M.want ~= "boss" then
        combat_i = combat_i % 4 + 1
        G.sfx.play("m_combat_" .. combat_i, nil, nil, nil, 0.7)
    else
        combat_i = 0
    end
end
