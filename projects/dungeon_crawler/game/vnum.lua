-- vnum: damage numbers made of voxel particles. A number is drawn with one `flame` particle per pixel of a 5 x 7 font, in the plane facing the player; a flame rises against gravity and shrinks, so the
-- whole number floats upwards and fades (a `spark` falls, a `puff` of 1 voxel is invisible, `debris` / `grain` settle into real voxels you can stand on), and when the flames are gone every
-- pixel bursts sideways in sparks. Effects are cosmetic: nothing here is in a hash. (Measured with the MCP screenshot's `settle`: a flame with speed 0 rises about 1.2 m in 0.7 s.)
Game = Game or {}
local G = Game
local V = {}
G.vnum = V
local floor = math.floor

local FONT = {
    ["0"] = { "01110", "10001", "10011", "10101", "11001", "10001", "01110" }, ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
    ["2"] = { "01110", "10001", "00001", "00010", "00100", "01000", "11111" }, ["3"] = { "11110", "00001", "00001", "01110", "00001", "00001", "11110" },
    ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" }, ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
    ["6"] = { "00110", "01000", "10000", "11110", "10001", "10001", "01110" }, ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
    ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" }, ["9"] = { "01110", "10001", "10001", "01111", "00001", "00010", "01100" },
}
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
function V.show(value, x, y, z, kind, scale)
    kind = kind or "plain"
    local text = tostring(math.floor(value + 0.5))
    if #text > 4 then text = "9999" end
    local px, py, pz = player.pos()
    local dx, dz = px - x, pz - z
    local n = math.max(0.01, math.sqrt(dx * dx + dz * dz))
    dx, dz = dx / n, dz / n                       -- from the point to the player
        -- fx.play takes WHOLE voxels, so the pixel pitch is a whole number of voxels (1 = 6 cm: normal, 2: crits and far away); a finer pitch drops and doubles pixels
    local k = ((scale or 1) > 1.2 or n > 7) and 2 or 1
    local width = (#text * 6 - 1) * k
    local vx, vy, vz = floor(units.vox(x) + 0.5), floor(units.vox(y) + 0.5), floor(units.vox(z) + 0.5)
    -- the number stands in a plane across the nearest axis (x or z) towards the player: whole-voxel steps, no gaps at any angle
    local rxv, rzv, fx_, fz_
    if math.abs(dx) >= math.abs(dz) then fx_, fz_ = (dx >= 0) and 1 or -1, 0; rxv, rzv = 0, (dx >= 0) and -1 or 1
    else fx_, fz_ = 0, (dz >= 0) and 1 or -1; rxv, rzv = (dz >= 0) and 1 or -1, 0 end
    local pixels = {}
    for ci = 1, #text do
        local glyph = FONT[text:sub(ci, ci)]
        for row = 1, 7 do
            for col = 1, 5 do
                if glyph[row]:sub(col, col) == "1" then
                    local u = ((ci - 1) * 6 + (col - 1)) * k - width / 2
                    for fy = 0, k - 1 do
                        for fu = 0, k - 1 do
                            local uu = u + fu
                            pixels[#pixels + 1] = { vx + rxv * uu + fx_ * 8, vy + (7 - row) * k + fy, vz + rzv * uu + fz_ * 8 }
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
