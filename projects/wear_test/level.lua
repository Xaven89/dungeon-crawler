-- Wear test level (docs/WEAR.md): a square stone platform, 31 m wide, with a grass top (the middle 15 m) and a stone ring around it; the player is put in the middle.
-- Walk back and forth on the grass and it turns to dirt; walk on to the stone and the dirt on the soles leaves prints. tools/determinism.sh records a walk over it
-- with the project's wear table (wear.csv, tracks on) and replays it.
function on_start()
    local x, y, z = player.pos()
    local vx, vy, vz = math.floor(x * 16), math.floor(y * 16), math.floor(z * 16)
    local gy = vy + 40
    edit.box(vx - 250, gy - 5, vz - 250, vx + 250, gy - 2, vz + 250, 'stone')
    edit.box(vx - 250, gy - 1, vz - 250, vx + 250, gy - 1, vz + 250, 'stone')
    edit.box(vx - 120, gy - 1, vz - 120, vx + 120, gy - 1, vz + 120, 'grass')
    player.teleport(vx / 16, (gy + 0.2) / 16, vz / 16)
end
