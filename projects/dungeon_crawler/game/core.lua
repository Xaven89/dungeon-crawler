-- core: constants, unit helpers, builders and the deterministic random numbers.
-- The dungeon is described in METRES in a local frame (x east, z south, y up from the floor of the lobby) and built in voxels (16 per metre) around the origin below.
Game = Game or {}
local G = Game

G.V = 16
G.OX, G.OY, G.OZ = 1072, 128, 848      -- voxel of local (0, 0, 0): the south-west corner of the lobby; y = the first free voxel above the floor
G.hash_salt = 4471902

local floor = math.floor
local function vox(m) return floor(m * G.V + 0.5) end
G.vox = vox

-- local metres -> world voxels / world metres
function G.wx(xm) return G.OX + vox(xm) end
function G.wy(ym) return G.OY + vox(ym) end
function G.wz(zm) return G.OZ + vox(zm) end
function G.mx(xm) return units.m(G.OX) + xm end        -- world metres (bodies, emitters, agents, player)
function G.my(ym) return units.m(G.OY) + ym end
function G.mz(zm) return units.m(G.OZ) + zm end
function G.to_local(wxm, wym, wzm) return wxm - units.m(G.OX), wym - units.m(G.OY), wzm - units.m(G.OZ) end

-- voxels are built on the first run only (the save keeps them), or when the guard finds the world undone (Z is the engine's undo key and cannot be unbound)
G.rebuilding = false
function G.should_build() return G.rebuilding or project.first_run() end

-- ---------------------------------------------------------------------------------------------- random numbers (an LCG: the engine's own determinism, not the C library's)
local rng_state = 12345
function G.seed(n) rng_state = (n or 12345) % 2147483648 end
function G.rand()          -- 0 <= r < 1
    rng_state = (rng_state * 1103515245 + 12345) % 2147483648
    return rng_state / 2147483648
end
function G.range(a, b) return a + G.rand() * (b - a) end
function G.irange(a, b) return a + floor(G.rand() * (b - a + 1)) end
function G.pick(t) return t[G.irange(1, #t)] end
-- a pure hash of integers (for choices that must not depend on how often something was asked)
function G.hash(a, b, c)
    local h = (a or 0) * 374761393 + (b or 0) * 668265263 + (c or 0) * 2147483647 + G.hash_salt
    h = (h ~ (h >> 13)) * 1274126177
    h = h ~ (h >> 16)
    return (h & 0xffffff) / 0x1000000
end

-- ---------------------------------------------------------------------------------------------- builders (metres, local; boxes are half open: [x0, x1) x [y0, y1) x [z0, z1))
function G.fill(x0, y0, z0, x1, y1, z1, mat, tex)
    local ax, ay, az, bx, by, bz = G.wx(x0), G.wy(y0), G.wz(z0), G.wx(x1) - 1, G.wy(y1) - 1, G.wz(z1) - 1
    if bx < ax or by < ay or bz < az then return end
    edit.box(ax, ay, az, bx, by, bz, mat)
    if tex then pcall(edit.texture_box, ax, ay, az, bx, by, bz, tex) end     -- (pcall: --check-project's dry run does not know the project's own textures)
end
function G.clear(x0, y0, z0, x1, y1, z1)
    local ax, ay, az, bx, by, bz = G.wx(x0), G.wy(y0), G.wz(z0), G.wx(x1) - 1, G.wy(y1) - 1, G.wz(z1) - 1
    if bx < ax or by < ay or bz < az then return end
    edit.clear(ax, ay, az, bx, by, bz)
end
function G.paint(x0, y0, z0, x1, y1, z1, color)
    edit.paint_box(G.wx(x0), G.wy(y0), G.wz(z0), G.wx(x1) - 1, G.wy(y1) - 1, G.wz(z1) - 1, color)
end
-- voxel-exact variants (arguments in voxels relative to the local origin: 1 m = 16)
function G.vfill(x0, y0, z0, x1, y1, z1, mat, tex)
    edit.box(G.OX + x0, G.OY + y0, G.OZ + z0, G.OX + x1, G.OY + y1, G.OZ + z1, mat)
    if tex then edit.texture_box(G.OX + x0, G.OY + y0, G.OZ + z0, G.OX + x1, G.OY + y1, G.OZ + z1, tex) end
end
function G.vclear(x0, y0, z0, x1, y1, z1) edit.clear(G.OX + x0, G.OY + y0, G.OZ + z0, G.OX + x1, G.OY + y1, G.OZ + z1) end
function G.sphere(xm, ym, zm, rm, mat) edit.sphere(G.wx(xm), G.wy(ym), G.wz(zm), vox(rm), mat) end
function G.text(xm, ym, zm, s, opts) opts = opts or {}; edit.text(G.wx(xm), G.wy(ym), G.wz(zm), s, opts) end

-- a cylinder (vertical) of a material, metres, centre and radius
function G.pillar(cx, cz, r, y0, y1, mat, tex)
    local R = vox(r)
    local x, z, ya, yb = G.wx(cx), G.wz(cz), G.wy(y0), G.wy(y1) - 1
    for dz = -R, R do
        local w = floor(math.sqrt(R * R - dz * dz) + 0.5)
        edit.box(x - w, ya, z + dz, x + w, yb, z + dz, mat)
    end
    if tex then edit.texture_box(x - R, ya, z - R, x + R, yb, z + R, tex) end
end

-- a vertical disc of air (a round room), and a ring of a material between two radii (metres)
function G.cyl_clear(cx, cz, r, y0, y1)
    local R = vox(r)
    local x, z, ya, yb = G.wx(cx), G.wz(cz), G.wy(y0), G.wy(y1) - 1
    for dz = -R, R do
        local w = floor(math.sqrt(R * R - dz * dz) + 0.5)
        edit.clear(x - w, ya, z + dz, x + w, yb, z + dz)
    end
end
function G.ring(cx, cz, r0, r1, y0, y1, mat, tex)
    local R0, R1 = vox(r0), vox(r1)
    local x, z, ya, yb = G.wx(cx), G.wz(cz), G.wy(y0), G.wy(y1) - 1
    for dz = -R1, R1 do
        local w1 = floor(math.sqrt(R1 * R1 - dz * dz) + 0.5)
        if math.abs(dz) >= R0 then
            edit.box(x - w1, ya, z + dz, x + w1, yb, z + dz, mat)
        else
            local w0 = floor(math.sqrt(R0 * R0 - dz * dz) + 0.5)
            edit.box(x - w1, ya, z + dz, x - w0 - 1, yb, z + dz, mat)
            edit.box(x + w0 + 1, ya, z + dz, x + w1, yb, z + dz, mat)
        end
    end
    if tex then pcall(edit.texture_box, x - R1, ya, z - R1, x + R1, yb, z + R1, tex) end
end

-- A room: carves the interior and lines it (floor, ceiling and four wall skins, 25 cm thick). r = { x, z, w, d, h, y = 0, floor, wall, ceil, ftex, wtex, ctex }
function G.room(r)
    local y = r.y or 0
    local x0, z0, x1, z1 = r.x, r.z, r.x + r.w, r.z + r.d
    local t = 0.25
    G.clear(x0, y, z0, x1, y + r.h, z1)
    local fl, wl, cl = r.floor or "flagstone", r.wall or "dungeon_brick", r.ceil or r.wall or "dungeon_brick"
    G.fill(x0 - t, y - 0.5, z0 - t, x1 + t, y, z1 + t, fl, r.ftex)
    G.fill(x0 - t, y + r.h, z0 - t, x1 + t, y + r.h + 0.4, z1 + t, cl, r.ctex)
    G.fill(x0 - t, y, z0 - t, x0, y + r.h, z1 + t, wl, r.wtex)
    G.fill(x1, y, z0 - t, x1 + t, y + r.h, z1 + t, wl, r.wtex)
    G.fill(x0, y, z0 - t, x1, y + r.h, z0, wl, r.wtex)
    G.fill(x0, y, z1, x1, y + r.h, z1 + t, wl, r.wtex)
end

-- A corridor between two points along x (or z): opens the walls of the rooms it joins. c = { x, z, len, w, h, axis = "x" | "z", y = 0, ... } (x, z = start of the centre line)
function G.corridor(c)
    local y = c.y or 0
    local fl, wl = c.floor or "flagstone", c.wall or "dungeon_brick"
    local hw = c.w / 2
    local x0, z0, x1, z1
    if (c.axis or "x") == "x" then x0, z0, x1, z1 = c.x, c.z - hw, c.x + c.len, c.z + hw
    else x0, z0, x1, z1 = c.x - hw, c.z, c.x + hw, c.z + c.len end
    local t = 0.25
    G.clear(x0, y, z0, x1, y + c.h, z1)
    G.fill(x0, y - 0.5, z0, x1, y, z1, fl, c.ftex)
    G.fill(x0, y + c.h, z0, x1, y + c.h + 0.4, z1, wl, c.wtex)
    if (c.axis or "x") == "x" then
        G.fill(x0, y, z0 - t, x1, y + c.h, z0, wl, c.wtex); G.fill(x0, y, z1, x1, y + c.h, z1 + t, wl, c.wtex)
    else
        G.fill(x0 - t, y, z0, x0, y + c.h, z1, wl, c.wtex); G.fill(x1, y, z0, x1 + t, y + c.h, z1, wl, c.wtex)
    end
end

-- ---------------------------------------------------------------------------------------------- lights (emitters with a light: the GI lights the probes of the room with them)
local torch_n = 0
G.torches = {}
function G.torch(xm, ym, zm, opts)
    opts = opts or {}
    torch_n = torch_n + 1
    local name = opts.name or ("torch_" .. torch_n)
    local col = opts.color or { 2.0, 1.05, 0.4 }
    emitter.create{ name = name, preset = opts.preset or "torch", pos = { G.mx(xm), G.my(ym), G.mz(zm) },
                    light = { color = col, reach = opts.reach or 14, flicker = opts.flicker ~= false } }
    G.torches[#G.torches + 1] = name
    return name
end
-- a wall sconce: (xm, zm) is the point ON the wall's inner face, `face` the way the wall looks into the room ("+x" = the west wall, "-x" = the east wall, "+z" = the north wall, "-z" = the south wall)
-- (everything must touch the wall: a voxel that floats is cut loose by the engine's connectivity and falls as a body)
function G.sconce(xm, ym, zm, face, opts)
    opts = opts or {}
    local fx = ({ ["+x"] = 1, ["-x"] = -1 })[face] or 0
    local fz = ({ ["+z"] = 1, ["-z"] = -1 })[face] or 0
    if project.first_run() then
        local cx, cz, y = G.wx(xm), G.wz(zm), G.wy(ym)
        local function cell(d, k) return (d > 0) and k or (-1 - k) end         -- k voxels out from the wall along d
        local function B(k0, k1, hw, y0, y1, mat)
            local xa, xb, za, zb
            if fx ~= 0 then xa, xb = cx + cell(fx, k0), cx + cell(fx, k1); za, zb = cz - hw, cz + hw
            else za, zb = cz + cell(fz, k0), cz + cell(fz, k1); xa, xb = cx - hw, cx + hw end
            edit.box(math.min(xa, xb), y + y0, math.min(za, zb), math.max(xa, xb), y + y1, math.max(za, zb), mat)
        end
        B(0, 1, 1, -2, 2, "metal")            -- the plate on the wall
        B(2, 3, 0, -2, 1, "dark_wood")        -- the torch handle
        B(2, 3, 1, 2, 2, "metal")             -- the cup
    end
    return G.torch(xm + fx * 0.22, ym + 0.45, zm + fz * 0.22, opts)
end
-- a hanging lamp: a chain from the ceiling (y_ceil) and a glowing lantern with a light; the cube touches the chain, the chain the ceiling
function G.lamp(xm, zm, y_ceil, drop, opts)
    opts = opts or {}
    if G.should_build() then
        G.fill(xm - 0.04, y_ceil - drop, zm - 0.04, xm + 0.04, y_ceil, zm + 0.04, "metal")
        G.fill(xm - 0.2, y_ceil - drop - 0.4, zm - 0.2, xm + 0.2, y_ceil - drop, zm + 0.2, opts.mat or "lantern")
        G.fill(xm - 0.25, y_ceil - drop - 0.05, zm - 0.25, xm + 0.25, y_ceil - drop, zm + 0.25, "metal")
    end
    return G.torch(xm, y_ceil - drop - 0.2, zm, { preset = opts.preset or "torch", color = opts.color or { 2.4, 1.6, 0.8 }, reach = opts.reach or 15, flicker = true })
end

-- a floor brazier / standing fire bowl
function G.brazier(xm, zm, opts)
    opts = opts or {}
    if G.should_build() then
        local cx, cz, y = G.wx(xm), G.wz(zm), G.wy(opts.y or 0)
        edit.box(cx - 2, y, cz - 2, cx + 2, y + 10, cz + 2, "metal")
        edit.box(cx - 5, y + 11, cz - 5, cx + 5, y + 13, cz + 5, "metal")
        edit.box(cx - 4, y + 14, cz - 4, cx + 4, y + 14, cz + 4, "ember")
    end
    return G.torch(xm, (opts.y or 0) + 1.1, zm, { preset = "campfire", reach = opts.reach or 16, color = opts.color or { 1.0, 0.5, 0.15 } })
end

-- ---------------------------------------------------------------------------------------------- small helpers
function G.dist2(ax, az, bx, bz) local dx, dz = ax - bx, az - bz; return math.sqrt(dx * dx + dz * dz) end
function G.dist3(ax, ay, az, bx, by, bz) local dx, dy, dz = ax - bx, ay - by, az - bz; return math.sqrt(dx * dx + dy * dy + dz * dz) end
function G.clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
function G.lerp(a, b, t) return a + (b - a) * t end
function G.format_int(n)
    local s = tostring(floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return out
end
