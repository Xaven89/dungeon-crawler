-- THE DESCENT: Season 7, Floor 1. The entry point: includes the modules and wires the engine callbacks. See GAME.md.
include("game/core.lua")
include("game/items.lua")
include("game/announcer.lua")
include("game/player.lua")
include("game/enemies.lua")
include("game/traps.lua")
include("game/world.lua")
include("game/rooms/hall.lua")
include("game/rooms/boiler.lua")
include("game/rooms/conveyor.lua")
include("game/rooms/gutter.lua")
include("game/rooms/ballroom.lua")
include("game/rooms/grotto.lua")
include("game/rooms/arena.lua")
include("game/rooms/stairwell.lua")
include("game/shop.lua")
include("game/boss.lua")
include("game/companion.lua")
include("game/music.lua")
include("game/hud.lua")

local G = Game

function on_start()
    G.load()
    G.items.init()
    G.enemies.define_fx()
    G.world.build()
    G.world.populate()
    G.sfx.preload({ "voice_blip", "swing", "hit", "hurt", "honk", "coin", "levelup", "achievement" })
    local s = G.state
    if not s.class then
        local x, y, z = G.world.start_position()
        player.teleport(x, y, z)
        G.screen = "class"
        after(60, function() G.announcer.say_key("intro", {}) end)
        after(300, function() G.announcer.say_key("intro", {}) end)
        after(620, function() G.announcer.say_key("intro", {}) end)
    else
        local cp = G.world.checkpoints[s.checkpoint] or G.world.checkpoints.lobby
        player.teleport(G.mx(cp.x), G.my(cp.y), G.mz(cp.z))
    end
    pcall(include, "dev/boot.lua")      -- a developer's scratch script (not in git): sets up a situation for a screenshot, see tools/hudshot.sh
end

function G.save_now()
    G.save()
    G.player.popup(tr("ui.save_done"), "#a6ffcc", true)
    G.sfx.play("checkpoint")
    G.player.set_checkpoint(G.current_room == "stairwell" and "stairwell" or (G.state.checkpoint or "lobby"), true)
end

function G.finish_floor()
    if G.state.flags.floor_done then G.screen = "end"; return end
    G.state.flags.floor_done = true
    G.screen = "end"
    G.announcer.say_key("end.line", { prio = 2 })
    local mins = G.state.playtime / 3600
    if mins < 20 then G.announcer.award("speedrunner") end
    G.save()
end
function G.close_end() G.screen = nil end

function on_tick(t)
    G.announcer.tick(t)
    G.player.tick(t)
    G.enemies.tick(t)
    G.companion.tick(t)
    G.music.tick(t)
    if G.world.tick then G.world.tick(t) end
    if t % 1800 == 900 and G.state.class then G.save() end        -- progress is kept every 30 s (the world itself is saved on exit / F11)
end

function on_anim(m, event, clip)
    if G.enemies.on_anim(m, event, clip) then return end
    if G.companion and G.companion.on_anim then G.companion.on_anim(m, event, clip) end
end
