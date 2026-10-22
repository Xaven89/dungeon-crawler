function on_start()
    edit.clear(1900,120,1900,2200,220,2200)
    player.teleport(128, 7.6, 128)
end
function on_hud(dt)
    local w, h = ui.size()
    ui.text(w/2, 40, "HELLO FROM HUD", {size=40, align="center", color="#ffcc00"})
    ui.bar(20, h-40, 300, 14, 0.6, "red")
end
