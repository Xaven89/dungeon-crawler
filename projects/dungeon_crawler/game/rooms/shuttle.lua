-- the Complimentary Shuttle: a vehicle (docs/VEHICLES.md) parked in the Hall of Mild Peril. Press E at it, W / S / A / D drive. Fast enough, it runs enemies over (the engine has no damage for vehicles: this is ours).
Game = Game or {}
local G = Game
local W, T = G.world, G.traps
local S = {}
W.shuttle = S

W.things[#W.things + 1] = function()
    S.id = vehicle.spawn{ x = G.mx(34), y = G.my(0.55), z = G.mz(15.5), heading = 90, width = 34, thickness = 6, length = 60, cab = 22, cab_material = "glass",
                          chassis = "dark_wood", wheel_material = "metal", wheel_radius = 6, max_speed = 11 }
    T.add_interact("shuttle", 34, 0.8, 15.5, "Drive the Complimentary Shuttle (E, then W A S D)", 3.2, function() return not vehicle.seated() end)
end

-- getting out: the engine puts the player at the side of the vehicle, which next to a wall is inside the wall or outside the dungeon: find a free standing place around the vehicle instead
local function free_spot(cx, cy, cz)
    for _, r in ipairs({ 2.2, 3.0, 1.6, 4.0 }) do
        for k = 0, 11 do
            local a = k * math.pi / 6
            local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
            local fy = nav.floor(x, cy + 0.6, z)
            if fy and math.abs(fy - cy) < 1.2 then
                local ok = true
                for _, h in ipairs({ 0.3, 1.0, 1.7 }) do if world.solid(math.floor(units.vox(x)), math.floor(units.vox(fy + h)), math.floor(units.vox(z))) then ok = false end end
                local lx, ly, lz = G.to_local(x, fy, z)
                if ok and lx > 0.5 and lz > 0.5 and G.world.room_at(lx, lz) then return x, fy, z end
            end
        end
    end
end

local hit_at = {}
local was_seated = false
function S.tick(t)
    local seated = vehicle.seated()
    if was_seated and not seated and S.id then
        local info = vehicle.info(S.id)
        if info then
            local x, y, z = free_spot(info.x, info.y - 0.4, info.z)
            if x then player.teleport(x, y + 0.05, z) end
        end
    end
    was_seated = seated
    if not S.id or t % 6 ~= 0 then return end
    local info = vehicle.info(S.id)
    if not info then
        if t % 120 == 0 then   -- it fell into something: a new one in the lobby
            S.id = vehicle.spawn{ x = G.mx(12), y = G.my(0.55), z = G.mz(17), heading = 90, width = 34, thickness = 6, length = 60, cab = 22, cab_material = "glass", chassis = "dark_wood", wheel_material = "metal", max_speed = 11 }
        end
        return
    end
    if info.occupied and not G.state.flags.drove then
        G.state.flags.drove = true
        G.announcer.say_key("shuttle.first", { prio = 1 })
    end
    if math.abs(info.speed) > 3.2 then
        for _, inst in pairs(G.enemies.list) do
            if not inst.dead and not inst.T.boss then
                local x, y, z = G.enemies.position(inst)
                if x and G.dist3(x, y + 0.5, z, info.x, info.y, info.z) < 2.4 and (t - (hit_at[inst.id] or -999)) > 30 then
                    hit_at[inst.id] = t
                    G.enemies.damage(inst, 25 + math.abs(info.speed) * 6, { source = "shuttle", stun = 40, crit = true })
                    do local lx, ly, lz = G.to_local(x, y, z); G.sfx.play("slam", lx, ly, lz, 0.6, 1.4) end
                    G.announcer.say_key("shuttle.hit", { key = "shuttle_hit", cooldown = 1500 })
                end
            end
        end
    end
end
