-- vnum: damage numbers made of voxel particles. A number is drawn with one `flame` particle per pixel of a 5 x 7 font, in the plane facing the player; a flame rises against gravity and shrinks, so the
-- whole number floats upwards and fades (a `spark` falls, a `puff` of 1 voxel is invisible, `debris` / `grain` settle into real voxels you can stand on), and when the flames are gone every
-- pixel bursts sideways in sparks. Effects are cosmetic: nothing here is in a hash. (Measured with the MCP screenshot's `settle`: a flame with speed 0 rises about 1.2 m in 0.7 s.)
Game = Game or {}
local G = Game
local V = {}
V.last = {}
G.vnum = V
local floor = math.floor

-- a 3 x 5 font: with one voxel (6 cm) per pixel a digit is 30 cm high, the smallest that stays readable (the flat HUD text is about 11 cm at the same distance; fx.play takes whole voxels)
local FONT = {
    ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" }, ["2"] = { "111", "001", "111", "100", "111" },
    ["3"] = { "111", "001", "111", "001", "111" }, ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
    ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "010", "010", "010" }, ["8"] = { "111", "101", "111", "101", "111" },
    ["9"] = { "111", "101", "111", "001", "111" },
}
local GW, GH = 3, 5
local LIFE = 0.75         -- seconds the number floats
local RISE = 1.0          -- metres a puff has risen at the end of its life (measured)
local SIZE = 1.0          -- the particle: voxels (a flame shrinks while it rises)

function V.define()
    for name, mat in pairs({ plain = "dmg_plain", crit = "dmg_crit", fire = "dmg_fire", boss = "dmg_boss" }) do
        fx.define{ name = "vn_" .. name, emitters = { { class = "flame", material = mat, count = 1, speed = 0, life = LIFE, size = SIZE, radius = 0, direction = { 0, 1, 0 } } } }
        fx.define{ name = "vn_pop_" .. name, emitters = { { class = "spark", material = mat, count = 2, speed = 18, speed_jitter = 0.6, spread = 3.14, life = 0.45, size = 0.7, radius = 0 } } }
    end
end

-- a number at a point (world metres); kind: plain | crit | fire | boss; scale > 1: bigger
function V.show(value, x, y, z, kind, scale, owner)
    kind = kind or "plain"
    local text = tostring(math.floor(value + 0.5))
    if #text > 4 then text = "9999" end
    local px, py, pz = player.pos()
    local dx, dz = px - x, pz - z
    local n = math.max(0.01, math.sqrt(dx * dx + dz * dz))
    dx, dz = dx / n, dz / n                       -- from the point to the player
        -- fx.play takes WHOLE voxels, so the pixel pitch is a whole number of voxels (1 = 6 cm: normal, 2: crits and far away); a finer pitch drops and doubles pixels
    local k = 1
    local width = (#text * (GW + 1) - 1) * k
    local vx, vy, vz = floor(units.vox(x) + 0.5), floor(units.vox(y) + 0.5), floor(units.vox(z) + 0.5)
    -- a second number of the same target while the first is still in the air starts one line higher (they used to overlap and look doubled)
    if owner then
        local now = time.tick()
        local last = V.last[owner]
        if last and now - last.t < LIFE * 60 then vy = math.max(vy, last.y + GH + 2) end
        V.last[owner] = { t = now, y = vy }
    end
    -- the number stands in a plane across the nearest axis (x or z) towards the player: whole-voxel steps, no gaps at any angle
    local rxv, rzv, fx_, fz_
    if math.abs(dx) >= math.abs(dz) then fx_, fz_ = (dx >= 0) and 1 or -1, 0; rxv, rzv = 0, (dx >= 0) and -1 or 1
    else fx_, fz_ = 0, (dz >= 0) and 1 or -1; rxv, rzv = (dz >= 0) and 1 or -1, 0 end
    local pixels = {}
    for ci = 1, #text do
        local glyph = FONT[text:sub(ci, ci)]
        for row = 1, GH do
            for col = 1, GW do
                if glyph[row]:sub(col, col) == "1" then
                    local u = ((ci - 1) * (GW + 1) + (col - 1)) * k - width / 2
                    for fy = 0, k - 1 do
                        for fu = 0, k - 1 do
                            local uu = u + fu
                            pixels[#pixels + 1] = { vx + rxv * uu + fx_ * 8, vy + (GH - row) * k + fy, vz + rzv * uu + fz_ * 8 }
                        end
                    end
                end
            end
        end
    end
    after(1, function()          -- (from a timer: the first picture taken straight after the call that played the effect did not show it)
        for _, p in ipairs(pixels) do fx.play("vn_" .. kind, p[1], p[2], p[3]) end
    end)
    -- the burst, where the pixels have risen to
    after(floor(LIFE * 60), function()
        for _, p in ipairs(pixels) do fx.play("vn_pop_" .. kind, p[1], p[2] + floor(units.vox(RISE)), p[3]) end
    end)
end
