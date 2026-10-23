-- vnum: damage numbers made of voxel particles. A number is drawn with one glowing particle per pixel of a 3 x 5 font, in the plane facing the player, floating up for a moment, and then every
-- pixel bursts into sparks (docs/LUA_API.md fx.define / fx.play: effects are cosmetic, nothing here is in a hash).
Game = Game or {}
local G = Game
local V = {}
G.vnum = V
local floor = math.floor

local FONT = {
    ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" }, ["2"] = { "111", "001", "111", "100", "111" },
    ["3"] = { "111", "001", "111", "001", "111" }, ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
    ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "010", "010", "010" }, ["8"] = { "111", "101", "111", "101", "111" },
    ["9"] = { "111", "101", "111", "001", "111" },
}
local LAYERS = 3          -- the number is drawn again every STEP ticks, a little higher each time (in my tests a `spark` with a speed above 0 did not show in a picture, one with speed 0 did: ENGINE_FEEDBACK.md)
local STEP = 15           -- ticks between two drawings
local LIFT = 0.05         -- metres it rises per step

function V.define()
    for name, mat in pairs({ plain = "dmg_plain", crit = "dmg_crit", fire = "dmg_fire", boss = "dmg_boss" }) do
        fx.define{ name = "vn_" .. name, emitters = { { class = "spark", material = mat, count = 1, speed = 0, life = STEP / 60 + 0.02, size = 0.85, radius = 0, direction = { 0, 1, 0 } } } }
        fx.define{ name = "vn_pop_" .. name, emitters = { { class = "spark", material = mat, count = 2, speed = 22, speed_jitter = 0.6, spread = 3.14, life = 0.45, size = 0.6, radius = 0 },
                                                          { class = "debris", material = mat, count = 1, speed = 16, speed_jitter = 0.6, spread = 3.14, life = 0.5, size = 0.6, radius = 0 } } }
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
    local rx, rz = dz, -dx                        -- the player's right while he looks at it
    local pitch = 0.07 * (scale or 1) * math.max(1, math.min(1.8, n / 4.0))      -- metres between two pixels: bigger when far away, so that it can be read
    local width = (#text * 4 - 1) * pitch
    local pixels = {}
    for ci = 1, #text do
        local glyph = FONT[text:sub(ci, ci)]
        for row = 1, 5 do
            for col = 1, 3 do
                if glyph[row]:sub(col, col) == "1" then
                    local u = ((ci - 1) * 4 + (col - 1)) * pitch - width / 2
                    pixels[#pixels + 1] = { x + rx * u + dx * 0.5, y + (5 - row) * pitch, z + rz * u + dz * 0.5 }
                end
            end
        end
    end
    local name = "vn_" .. kind
    local function draw(layer)
        for _, p in ipairs(pixels) do fx.play(name, floor(units.vox(p[1])), floor(units.vox(p[2] + layer * LIFT)), floor(units.vox(p[3]))) end
    end
    after(1, function() draw(0) end)          -- (from a timer: the first picture taken straight after the call that played the effect did not show it, a later one did)
    for layer = 1, LAYERS - 1 do after(layer * STEP, function() draw(layer) end) end
    -- the burst, where the pixels have floated to
    after(LAYERS * STEP, function()
        for _, p in ipairs(pixels) do fx.play("vn_pop_" .. kind, floor(units.vox(p[1])), floor(units.vox(p[2] + LAYERS * LIFT)), floor(units.vox(p[3]))) end
    end)
end
