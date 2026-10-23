-- signs: the voxel text on the walls. A sign must fit on its wall (the first versions were longer than the room or the corridor they hang in, or hung behind a pillar, a pipe or the door's slot,
-- and half of the letters sank into the walls). tools/check_signs.py looks in front of every sign. The list below is what the floor has now; OLD is what earlier saved worlds contain
-- (erased once: the letters were burnt into a wall layer and one voxel in front of it).
Game = Game or {}
local G = Game
local W = G.world

local SIGNS = {
    { 6.8, 5.3, 0, "THE DESCENT", { facing = "+z", material = "lantern", size = 3, spacing = 1, depth = 2 } },
    { 8.7, 4.1, 0, "NOW WITH 40% MORE DEATH", { facing = "+z", material = "neon_red", size = 1, depth = 1 } },
    { 16.3, 1.9, 0, "STAFF ONLY", { facing = "+z", material = "hazard_y", size = 1, depth = 1 } },
    { 5.0, 6.4, 22, "GAUNTLET GATE - SCREAM IN AN ORDERLY FASHION", { facing = "-z", material = "hazard_y", size = 1, depth = 1 } },
    { 89.6, 4.6, 0, "DRAWBRIDGE: RAISED", { facing = "+z", material = "neon_red", size = 1, depth = 1 } },
    { 116.6, 3.6, 69.6, "FURNACE AHEAD", { facing = "-z", material = "neon_red", size = 1, depth = 1 } },
    { 114.8, 4.4, 20, "BELT IS ALWAYS ON", { facing = "+z", material = "hazard_y", size = 1, depth = 1 } },
    { 60.9, 13.2, 80.2, "SERVICE", { facing = "+z", material = "hazard_y", size = 1, depth = 1 } },
    { 57.5, 3.8, 124.0, "STAIRWELL 1 - SAFE ROOM", { facing = "+z", material = "lantern", size = 1, depth = 1 } },
    { 64.2, 2.4, 140.0, "FLOOR 2", { facing = "-z", material = "neon_red", size = 2, depth = 1 } },
}
local OLD = {
    { 4.2, 5.3, 0, "THE DESCENT", "+z", 3, 2 }, { 2.9, 4.1, 0, "SEASON 7 - NOW WITH 40% MORE DEATH", "+z", 1, 1 }, { 20.9, 3.4, 0, "STAFF ONLY", "+z", 1, 1 },
    { 7.4, 6.4, 22, "GAUNTLET GATE - PLEASE SCREAM IN AN ORDERLY FASHION", "-z", 1, 1 }, { 100, 7.0, 0, "THE DRAWBRIDGE IS THAT WAY (RAISED)", "+z", 1, 1 },
    { 115.2, 3.6, 69.6, "FURNACE OF CONSEQUENCES", "-z", 1, 1 }, { 114.4, 4.4, 20, "THE BELT IS ALWAYS ON", "+z", 1, 1 }, { 60.8, 13.2, 80.2, "SERVICE TUNNEL", "+z", 1, 1 },
    { 26.5, 3.3, 112, "THE FOREMAN IS IN", "+z", 1, 1 }, { 58, 3.7, 124.2, "STAIRWELL 1 - SAFE ROOM - NO MURDER (EXCEPT BY APPOINTMENT)", "+z", 1, 1 },
    { 64.1, -2.6, 139.4, "FLOOR 2", "-z", 2, 1 },
}
W.sign_list = SIGNS

function W.build_signs() for _, s in ipairs(SIGNS) do G.text(s[1], s[2], s[3], s[4], s[5]) end end

-- erase an old sign: the wall layers behind its letters go back to brick, the layer in front goes back to air
local function erase(o)
    local x, y, z, text, facing, size, depth = o[1], o[2], o[3], o[4], o[5], o[6], o[7]
    local w, h = #text * 6 * size / 16 + 0.1, 7 * size / 16 + 0.1
    local zf = 0.0625
    if facing == "+z" then
        G.fill(x, y, z - depth / 16 + 0.001, x + w, y + h, z, "dungeon_brick", "blocks")                -- the layers inside the wall
        G.clear(x, y, z, x + w, y + h, z + zf)                                                        -- the layer in front of it (and anything that floated there)
        if z > 100 and z < 125 and text:sub(1, 8) == "STAIRWEL" then G.clear(x, y, z - 0.01, x + w, y + h, z + 0.25) end
    else
        G.fill(x, y, z, x + w, y + h, z + depth / 16, "dungeon_brick", "blocks")
    end
end

W.builders[#W.builders + 1] = function() W.build_signs() end

-- worlds saved before this version: erase the old signs, write the new ones, restore what the letters had cut (the door's slot above the closet)
function W.repair_signs()
    if G.should_build() or G.state.flags.fix_signs_v4 then return end
    for _, o in ipairs(OLD) do erase(o) end
    G.clear(20.8, 2.9, -0.25, 23.4, 6.0, 0)
    W.build_signs()
    G.state.flags.fix_signs_v4 = true
end
