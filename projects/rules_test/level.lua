-- Rules test level: nothing to build, the world is the level. The player starts in the forest and plains to the south east of the origin (the origin itself is a desert), where the creatures live.
function on_start()
    player.teleport(300, 50, 300)
end

-- The region hook (docs/WORLD_GEN.md "The region hook"): called once for every 512 voxel region the world needs, in a restricted environment (worldgen.ground / biome / hash / noise, no edit or world);
-- it answers with static placements. Here: a ring of standing stones in about a third of the regions, on dry ground, and a lone pillar in the middle of them.
function on_region(rx, rz)
    local out = {}
    if worldgen.hash(rx, rz, 7) > 0.33 then return out end
    local cx, cz = rx * 512 + 150 + math.floor(worldgen.hash(rx, rz, 8) * 200), rz * 512 + 150 + math.floor(worldgen.hash(rx, rz, 9) * 200)
    local h, biome, water = worldgen.ground(cx, cz)
    if water > 0 or biome == "tundra" then return out end
    for i = 0, 7 do
        local a = i * math.pi / 4
        local x, z = cx + math.floor(math.cos(a) * 40), cz + math.floor(math.sin(a) * 40)
        local hh = worldgen.ground(x, z)
        out[#out + 1] = { kind = "box", lo = { x - 2, hh - 3, z - 2 }, hi = { x + 2, hh + 24 + i % 3 * 6, z + 2 }, material = "stone" }
    end
    out[#out + 1] = { kind = "box", lo = { cx - 3, h - 3, cz - 3 }, hi = { cx + 3, h + 44, cz + 3 }, material = "brick" }
    return out
end
