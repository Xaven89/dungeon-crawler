-- gore: walk-through stains (materials with passable = 1, docs/GORE.md). Wounds and deaths splatter the surfaces around them, the janitor's mop cleans them up.
-- Every splat is remembered (G.state.stains, saved: x, y, z, radius, material) so that cleaning can pay a tip per spot, the world itself holds the voxels.
Game = Game or {}
local G = Game
local floor = math.floor
local R = {}
G.gore = R

local MATS = { "blood_stain", "goo_stain", "toxic_stain", "bone_stain" }
local BY_SPLAT = { splat_red = "blood_stain", splat_goo = "goo_stain", splat_toxic = "toxic_stain", splat_bone = "bone_stain", splat_spore = "toxic_stain" }
local MAX_REMEMBERED = 200

function R.material_for(splat) return BY_SPLAT[splat or "splat_red"] or "blood_stain" end

local function stains()
    local s = G.state
    if not s then return {} end
    s.stains = s.stains or {}
    return s.stains
end

-- a spatter around a world point (metres): `r` metres, remembered for the cleaning
function R.splat(x, y, z, mat, r)
    local list = stains()
    local seed = floor(G.hash(floor(x * 10), floor(z * 10), time.tick()) * 1000000)
    fx.splat(x, y, z, r, mat, seed)   -- world metres (not voxels, unlike fx.play / edit.*)
    list[#list + 1] = { x, y, z, r, mat }
    if #list > MAX_REMEMBERED then table.remove(list, 1) end
end

-- the stain of a wound / a death of an enemy instance at its body
function R.wound(inst, x, y, z, big)
    local T = inst.T
    local mat = R.material_for(T.splat)
    local r = big and (T.boss and 3.6 or (T.miniboss and 2.6 or 1.8)) or (T.miniboss and 1.0 or 0.7)
    R.splat(x, y, z, mat, r)
end

-- clean everything of the stain materials in a sphere around (x, y, z) metres; returns how many remembered spots were (mostly) in it and how many voxels were cleared
function R.clean(x, y, z, r)
    local list = stains()
    local n, keep = 0, {}
    for _, e in ipairs(list) do
        if G.dist3(e[1], e[2], e[3], x, y, z) <= r + e[4] * 0.5 then n = n + 1 else keep[#keep + 1] = e end
    end
    if n == 0 then return 0 end
    G.state.stains = keep
    local vx, vy, vz, vr = floor(x * 16), floor(y * 16), floor(z * 16), floor(r * 16)
    local cells = 0
    for _, m in ipairs(MATS) do cells = cells + (edit.sphere(vx, vy, vz, vr, m, "clear_if") or 0) end
    return n, cells
end

-- pay for it: gold per spot, the achievement after a shift's worth
function R.pay(n, cells)
    if n <= 0 then return end
    local s = G.state
    local gold = math.max(1, floor((cells or 0) / 60))      -- a spatter of a death is a few hundred voxels
    s.gold = s.gold + gold
    G.player.log("+" .. gold .. " gold (cleaning)", "#6fd0ff")
    if G.show then G.show.score(n * 2, nil) end
    local total = G.announcer.bump("cleaned", n)
    if total >= 40 then G.announcer.award("clean_sweep") end
    G.announcer.say_key("gore.clean", { key = "gore_clean", cooldown = 1800 })
end

-- the mop swung at nothing: a metre and a half in front of the feet
function R.mop(px, py, pz)
    local fx_, _, fz_ = player.forward()
    local n, cells = R.clean(px + fx_ * 1.4, py + 0.3, pz + fz_ * 1.4, 1.5)
    if n > 0 then local lx, ly, lz = G.to_local(px, py, pz); G.sfx.play("sweep", lx, ly, lz, 0.5, 1.3); R.pay(n, cells) end
    return n
end

-- the janitor's Mop Sweep ability: the whole room around
function R.sweep(px, py, pz)
    local n, cells = R.clean(px, py + 0.5, pz, 4.5)
    R.pay(n, cells)
    return n
end
