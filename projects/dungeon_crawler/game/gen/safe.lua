-- gen/safe: the things of the safe room of a big floor (the ARRIVAL and the safe rooms of the quadrants): a fireplace, the check-in crystal, a vending machine, the sponsors' boxes. The fixtures
-- themselves are voxels of the region hook (gen/deco.lua `deco_room` theme "safe"); the plan (which fixtures are mirrored or dropped so that none stands in a doorway) is `deco_safe_plan`, the
-- same pure function in the hook and here. Canonical offsets (u east, v south, 0 .. 16) are in the 16 x 16 square in the middle of the 20 x 20 room.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local S = {}
G.gen.safe = S
local floor, min, max = math.floor, math.min, math.max

-- the things (every time the cell comes alive): lights, the save crystal, the vending machine
function S.things(r, ctx, opts)
    opts = opts or {}
    local F = G.floorgen
    local ox, oz = F.off(r)
    local plan = deco_safe_plan(F.lroom(r), F.local_doors(r), false)           -- (in the cell's own coordinates, exactly what the hook saw)
    local P = { X = function(u) return plan.X(u) + ox end, Z = function(v) return plan.Z(v) + oz end, face = plan.face }
    local id = r.id
    local T = G.traps
    local dk = G.gen.rules.dark()
    G.torch(P.X(8), 0.7, P.Z(0.8), { preset = "campfire", color = { 1, 0.55, 0.2 }, reach = 14, far = 26, name = id .. "_fire" })
    F.sconces(r, ctx)                                       -- (the wall lights of the room: the plan of deco.lua, plates in the hook)
    G.torch(P.X(13.1), 2.6, P.Z(1.7), { preset = "magic_sparks", color = { 0.7, 0.3, 1.0 }, reach = 10, name = id .. "_crystal" })
    G.dust(id .. "_dust", "dust_motes", { G.mx(r.x + r.w / 2), G.my(2.5), G.mz(r.z + r.d / 2) }, { 6, 2, 6 })
    local function wbox(u0, y0, v0, u1, y1, v1)        -- an event box (voxels) from canonical metres
        local xa, xb = min(P.X(u0), P.X(u1)), max(P.X(u0), P.X(u1))
        local za, zb = min(P.Z(v0), P.Z(v1)), max(P.Z(v0), P.Z(v1))
        return { G.wx(xa), G.wy(y0), G.wz(za), G.wx(xb) - 1, G.wy(y1), G.wz(zb) - 1 }
    end
    local btn = events.button{ name = id .. "_vending", box = wbox(13.55, 0.9, 5.1, 13.7, 1.2, 5.6), prompt = "Vending Machine of Mild Relief", on = "neon", off = "gold", press_ticks = 8 }
    events.on(btn, "pressed", function() if G.shop then G.shop.open("vending") end end)
    T.add_interact(id .. "_vending", P.X(13.6), 1.6, P.Z(4.4), "Use the Vending Machine", 2.8)
    T.add_interact(id .. "_crystal", P.X(13.1), 1.4, P.Z(1.7), "Touch the crystal (save)", 2.4)
    local crystal = events.button{ name = id .. "_save", box = wbox(12.8, 1.2, 1.4, 13.4, 1.9, 2), prompt = "Touch the crystal", on = "neon", off = "crystal", press_ticks = 8 }
    events.on(crystal, "pressed", function() G.save_now("crystal") end)
    -- where the sponsors' boxes go (gen/show.lua): the free strip along the east wall, mirrored with the room
    r.box_spots = {}
    for k = 1, 3 do
        local v = 6.8 + 2.1 * (k - 1)
        r.box_spots[k] = { x = min(P.X(14.6), P.X(15.35)), z = min(P.Z(v), P.Z(v + 1.25)), face = P.face("-x") }
    end
end
