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

local hit_at = {}
function S.tick(t)
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
                    G.sfx.play("slam", G.to_local(x, y, z), 0.6, 1.4)
                    G.announcer.say_key("shuttle.hit", { key = "shuttle_hit", cooldown = 1500 })
                end
            end
        end
    end
end
