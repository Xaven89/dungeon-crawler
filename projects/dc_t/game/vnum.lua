-- vnum: damage numbers. The engine's `fx.text` makes a label out of motes (one lit cube per pixel of its 5 x 7 font) that faces the viewer and rises; at the end of its life every
-- pixel bursts sideways (`fx.mote`: cubes that fly straight, no gravity, no settling). Letter height in metres, the HUD's own text is about 10 cm at the distances of a fight.
-- (The first versions drew the pixels by hand with `flame` particles in a 3 x 5 font, one voxel per pixel: too big, and gaps from whole-voxel positions.)
Game = Game or {}
local G = Game
local V = {}
G.vnum = V
V.last = {}
local floor, max, min = math.floor, math.max, math.min

local LIFE = 0.85         -- seconds the label floats
local RISE = 0.7          -- metres per second
local MATERIAL = { plain = "dmg_plain", crit = "dmg_crit", fire = "dmg_fire", boss = "dmg_boss" }
local SIZE = { plain = 0.11, crit = 0.17, fire = 0.11, boss = 0.2 }       -- the height of the letters (metres) at 3 m

function V.define() end        -- (nothing to define: fx.text and fx.mote need no effect table)

local DIRS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0.7, 0, 0.7 }, { -0.7, 0, 0.7 }, { 0.7, 0, -0.7 }, { -0.7, 0, -0.7 } }

-- a number at a point (world metres); kind: plain | crit | fire | boss; owner: an id (a second number of the same target while the first floats starts higher)
function V.show(value, x, y, z, kind, scale, owner)
    kind = kind or "plain"
    local text = tostring(math.floor(value + 0.5))
    local px, py, pz = player.pos()
    local dist = math.max(1, math.sqrt((px - x) ^ 2 + (pz - z) ^ 2))
    local size = SIZE[kind] * min(2.2, max(1, dist / 3)) * (scale or 1)
    if owner then
        local now = time.tick()
        local last = V.last[owner]
        if last and now - last.t < LIFE * 60 then y = max(y, last.y + size * 1.7) end
        V.last[owner] = { t = now, y = y }
    end
    local mat = MATERIAL[kind] or MATERIAL.plain
    fx.text{ text = text, at = { x, y, z }, size = size, material = mat, rise = RISE, life = LIFE, align = "center" }
    -- the burst: where the label has risen to
    after(floor(LIFE * 60), function()
        local ey = y + RISE * LIFE
        for _, d in ipairs(DIRS) do
            fx.mote{ at = { x, ey + size * 0.5, z }, vel = { d[1] * 0.9, 0.4, d[3] * 0.9 }, life = 0.4, size = size * 0.12, material = mat, count = 2, spread = size * 1.5 }
        end
    end)
end
