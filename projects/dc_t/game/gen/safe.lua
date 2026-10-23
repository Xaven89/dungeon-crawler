-- gen/safe: the two safe rooms of a generated floor, 16 x 16 m: the ARRIVAL (where the stairs of the floor above end up: a fireplace, a sofa, the check-in crystal, a vending machine) and the
-- EXIT STAIRWELL (the same room with the stairs down, sealed by a door button). Drawn from the old Stairwell 1 in canonical offsets (u east, v south, 0..16) that are mirrored so that no
-- fixture stands in a doorway: the plan (mirror flags, dropped fixtures) is a pure function of the room and its doors.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local S = {}
G.gen.safe = S
local floor, min, max = math.floor, math.min, math.max

-- the fixtures that can be in the way, in canonical offsets { u0, v0, u1, v1 }; `must` ones decide the mirroring, the others are dropped when they block a door
local FIX = {
    fireplace = { 5, 0, 11, 1.8, must = true }, crystal = { 12, 0.6, 14.2, 2.8, must = true }, vending = { 13.4, 3, 16, 6, must = true },
    shelf_a = { 0, 2, 1.8, 5 }, shelf_b = { 0, 12.5, 1.8, 15.5 }, sofa = { 2, 12.2, 6.5, 14 }, table = { 8, 12.6, 10, 14 }, bed = { 2, 7, 4.4, 9.2 },
}
local STAIRS = { 10, 14.2, 15.6, 16 }

-- a door's zone in the room's world coordinates: the 4 m opening, 3 m deep
local function door_zone(room, d)
    if d.side == "E" then return { room.x + room.w - 3, d.pos - 2.8, room.x + room.w, d.pos + 2.8 }
    elseif d.side == "W" then return { room.x, d.pos - 2.8, room.x + 3, d.pos + 2.8 }
    elseif d.side == "S" then return { d.pos - 2.8, room.z + room.d - 3, d.pos + 2.8, room.z + room.d }
    else return { d.pos - 2.8, room.z, d.pos + 2.8, room.z + 3 } end
end
local function map_rect(room, mx, mz, r)
    local x0, x1 = room.x + (mx and 16 - r[3] or r[1]), room.x + (mx and 16 - r[1] or r[3])
    local z0, z1 = room.z + (mz and 16 - r[4] or r[2]), room.z + (mz and 16 - r[2] or r[4])
    return { x0, z0, x1, z1 }
end
local function hit(a, b) return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4] end

function S.plan(room, ctx, stairs)
    local zones = {}
    for _, d in ipairs(ctx.doors[room.id] or {}) do zones[#zones + 1] = door_zone(room, d) end
    local best
    for _, f in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
        local blocked, dropped = 0, {}
        for name, r in pairs(FIX) do
            local w = map_rect(room, f[1], f[2], r)
            for _, z in ipairs(zones) do if hit(w, z) then if r.must then blocked = blocked + 10 else dropped[name] = true; blocked = blocked + 1 end break end end
        end
        if stairs then local w = map_rect(room, f[1], f[2], STAIRS); for _, z in ipairs(zones) do if hit(w, z) then blocked = blocked + 10 end end end
        if not best or blocked < best.blocked then best = { mx = f[1], mz = f[2], dropped = dropped, blocked = blocked } end
        if blocked == 0 then break end
    end
    return best
end

-- the painter: canonical offsets -> world, with the mirror
local function painter(room, plan)
    local P = {}
    local mx, mz = plan.mx, plan.mz
    local function X(u) return room.x + (mx and 16 - u or u) end
    local function Z(v) return room.z + (mz and 16 - v or v) end
    P.X, P.Z = X, Z
    function P.fill(u0, y0, v0, u1, y1, v1, mat, tex) G.fill(min(X(u0), X(u1)), y0, min(Z(v0), Z(v1)), max(X(u0), X(u1)), y1, max(Z(v0), Z(v1)), mat, tex) end
    function P.clear(u0, y0, v0, u1, y1, v1) G.clear(min(X(u0), X(u1)), y0, min(Z(v0), Z(v1)), max(X(u0), X(u1)), y1, max(Z(v0), Z(v1))) end
    function P.paint(u0, y0, v0, u1, y1, v1, col) G.paint(min(X(u0), X(u1)), y0, min(Z(v0), Z(v1)), max(X(u0), X(u1)), y1, max(Z(v0), Z(v1)), col) end
    function P.face(f)         -- the way a wall looks into the room
        if mx then f = ({ ["+x"] = "-x", ["-x"] = "+x" })[f] or f end
        if mz then f = ({ ["+z"] = "-z", ["-z"] = "+z" })[f] or f end
        return f
    end
    return P
end

-- the voxels
function S.voxels(r, ctx, opts)
    opts = opts or {}
    local plan = S.plan(r, ctx, opts.stairs)
    local P = painter(r, plan)
    local x, z = r.x, r.z
    G.room{ x = x, z = z, w = r.w, d = r.d, h = r.h, floor = "dark_wood", wall = "dark_wood", ceil = "dark_wood", ftex = "planks", wtex = "fine_planks", ctex = "planks" }
    P.fill(4, 0, 4, 12, 0.05, 12, "carpet"); P.fill(3.9, 0, 3.9, 12.1, 0.05, 4, "gold"); P.fill(3.9, 0, 12, 12.1, 0.05, 12.1, "gold")
    -- the fireplace in the north wall
    P.fill(5, 0, 0, 11, 3.0, 1.2, "brick"); P.clear(6, 0, 0, 10, 1.8, 1.2); P.fill(6, 0, 0, 10, 0.2, 1, "obsidian"); P.fill(4.4, 3.0, 0, 11.6, 3.4, 1.6, "marble")
    if not plan.dropped.shelf_a or not plan.dropped.shelf_b then
        for name, dv in pairs({ shelf_a = 2, shelf_b = 12.5 }) do
            if not plan.dropped[name] then
                P.fill(0, 0, dv, 1.2, 3.6, dv + 3, "dark_wood")
                for sh = 0.4, 3.2, 0.7 do
                    P.fill(1.2, sh, dv + 0.1, 1.6, sh + 0.05, dv + 2.9, "dark_wood")
                    for b = 0, 9 do
                        local bz = dv + 0.15 + b * 0.27
                        P.fill(1.2, sh + 0.05, bz, 1.55, sh + 0.55, bz + 0.23, "dark_wood")
                        P.paint(1.2, sh + 0.05, bz, 1.55, sh + 0.55, bz + 0.23, ({ "red", "blue", "green", "yellow", "violet", "orange" })[1 + (b + floor(dv)) % 6])
                    end
                end
            end
        end
    end
    if not plan.dropped.sofa then
        P.fill(2, 0, 12.2, 6.5, 0.5, 14, "carpet"); P.fill(2, 0.5, 13.4, 6.5, 1.3, 14, "carpet")
        P.fill(2, 0.5, 12.2, 2.5, 0.9, 14, "carpet"); P.fill(6, 0.5, 12.2, 6.5, 0.9, 14, "carpet")
    end
    if not plan.dropped.table then P.fill(8, 0, 12.6, 10, 0.6, 14, "dark_wood") end
    -- the vending machine (east wall)
    P.fill(14, 0, 3, 16, 3.3, 6, "metal"); P.fill(13.6, 0.8, 3.2, 14, 2.6, 5.8, "lantern"); P.fill(13.55, 0.9, 5.1, 13.7, 1.2, 5.6, "gold")
    P.fill(13.55, 2.0, 3.4, 13.7, 2.4, 4.7, "neon_red")
    G.text(plan.mx and (x + 2.5) or (x + 13.5), 3.4, P.Z(3.2), "MILD RELIEF", { facing = P.face("-x"), material = "gold", size = 1, depth = 1 })
    -- the check-in crystal on a plinth
    P.fill(12, 0, 0.6, 14.2, 0.9, 2.8, "marble", "blocks"); G.sphere(P.X(13.1), 1.6, P.Z(1.7), 0.62, "rune")
    if not plan.dropped.bed then P.fill(2, 0, 7, 4.4, 0.4, 9.2, "dark_wood"); P.fill(2.2, 0.4, 7.2, 4.2, 0.6, 9, "sand") end
    if opts.stairs then
        -- the stairs down: a shaft against the south wall with steps, sealed by an obsidian door at the bottom
        P.clear(10, -6.4, 14.4, 15.6, 0, 16)
        for k = 0, 11 do P.fill(10, -k * 0.5 - 0.5, 14.4 + k * 0.1, 15.6, -k * 0.5, 14.5 + k * 0.1 + 0.4, "flagstone") end
        P.fill(10, -6.4, 15.4, 15.6, -0.5, 16.6, "obsidian")
    end
end

-- the things (every start): lights, the save crystal, the vending machine, the stairs
function S.things(r, ctx, opts)
    opts = opts or {}
    local plan = S.plan(r, ctx, opts.stairs)
    local P = painter(r, plan)
    local id = r.id
    local T = G.traps
    local dk = G.gen.rules.dark()
    G.torch(P.X(8), 0.7, P.Z(0.8), { preset = "campfire", color = { 1, 0.55, 0.2 }, reach = 14, name = id .. "_fire" })
    G.sconce(P.X(0) + (plan.mx and 0 or 0), 3.3, P.Z(2), P.face("+x"), { intensity = 11 * dk }); G.sconce(P.X(16), 3.3, P.Z(12), P.face("-x"), { intensity = 11 * dk })
    G.sconce(P.X(3), 3.3, P.Z(16), P.face("-z"), { intensity = 11 * dk }); G.sconce(P.X(13), 3.3, P.Z(16), P.face("-z"), { intensity = 11 * dk })
    G.torch(P.X(13.1), 2.6, P.Z(1.7), { preset = "magic_sparks", color = { 0.7, 0.3, 1.0 }, reach = 10, name = id .. "_crystal" })
    G.dust(id .. "_dust", "dust_motes", { G.mx(r.x + 8), G.my(2.5), G.mz(r.z + 8) }, { 6, 2, 6 })
    local function wbox(u0, y0, v0, u1, y1, v1)        -- an event box (voxels) from canonical metres
        local xa, xb = min(P.X(u0), P.X(u1)), max(P.X(u0), P.X(u1))
        local za, zb = min(P.Z(v0), P.Z(v1)), max(P.Z(v0), P.Z(v1))
        return { G.wx(xa), G.wy(y0), G.wz(za), G.wx(xb) - 1, G.wy(y1), G.wz(zb) - 1 }
    end
    local btn = events.button{ name = id .. "_vending", box = wbox(13.55, 0.9, 5.1, 13.7, 1.2, 5.6), prompt = "Vending Machine of Mild Relief", on = "neon", off = "gold", press_ticks = 8 }
    events.on(btn, "pressed", function() if G.shop then G.shop.open() end end)
    T.add_interact(id .. "_vending", P.X(13.6), 1.6, P.Z(4.4), "Use the Vending Machine", 2.8)
    T.add_interact(id .. "_crystal", P.X(13.1), 1.4, P.Z(1.7), "Touch the crystal (save)", 2.4)
    local crystal = events.button{ name = id .. "_save", box = wbox(12.8, 1.2, 1.4, 13.4, 1.9, 2), prompt = "Touch the crystal", on = "neon", off = "rune", press_ticks = 8 }
    events.on(crystal, "pressed", function() G.save_now() end)
    if opts.stairs then
        local down = events.button{ name = id .. "_down", box = wbox(12, -3.4, 15.4, 13.2, -2.6, 15.5), prompt = tr("ui.descend", opts.next_floor or 2), on = "neon", off = "neon_red", press_ticks = 10 }
        events.on(down, "pressed", function() if G.run and G.run.descend then G.run.descend() end end)
        T.add_interact(id .. "_down", P.X(12.6), -2.9, P.Z(15), tr("ui.descend", opts.next_floor or 2), 2.6)
    end
    -- where the sponsors' boxes go (gen/show.lua): the free strip along the east wall, mirrored with the room
    r.box_spots = {}
    for k = 1, 3 do
        local v = 6.8 + 2.1 * (k - 1)
        r.box_spots[k] = { x = min(P.X(14.6), P.X(15.35)), z = min(P.Z(v), P.Z(v + 1.25)), face = P.face("-x") }
    end
end
