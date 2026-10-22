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
include("game/hud.lua")

local G = Game

function on_start()
    G.load()
    G.items.init()
    G.enemies.define_fx()
    G.world.build()
    G.world.populate()
    G.sfx.preload({ "voice_blip", "swing", "hit", "hurt" })
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

function on_tick(t)
    G.announcer.tick(t)
    G.player.tick(t)
    G.enemies.tick(t)
    if G.world.tick then G.world.tick(t) end
end

function on_anim(m, event, clip)
    if G.enemies.on_anim(m, event, clip) then return end
    if G.companion and G.companion.on_anim then G.companion.on_anim(m, event, clip) end
end
