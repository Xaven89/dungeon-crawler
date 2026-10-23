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
include("game/rooms/props.lua")
include("game/rooms/shuttle.lua")
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
    G.music.load_settings()
    G.setup_player_models()
    G.sfx.preload({ "voice_blip", "swing", "hit", "hurt", "honk", "coin", "levelup", "achievement" })
    local s = G.state
    if not s.class then
        local x, y, z = G.world.start_position()
        player.teleport(x, y, z)
        G.screen = "title"
        after(330, function() if not G.state.class then G.screen = "class" end end)
        after(360, function() G.announcer.say_key("intro", {}) end)
        after(660, function() G.announcer.say_key("intro", {}) end)
        after(960, function() G.announcer.say_key("intro", {}) end)
    else
        local cp = G.world.checkpoints[s.checkpoint] or G.world.checkpoints.lobby
        player.teleport(G.mx(cp.x), G.my(cp.y), G.mz(cp.z))
    end
    include_optional("dev/boot.lua")      -- a developer's scratch script (not in git): sets up a situation for a screenshot, see tools/hudshot.sh
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

-- the body (third person / pictures from outside) and the sword in the hand (first person); both are render only
function G.setup_player_models()
    player.model("models/hero.vxm", { idle = "idle", walk = "walk", attack = "attack" })
    player.hand_model("models/sword.vxm", { offset = { 0.35, -0.05, 1.0 }, turn = 0, idle = "idle" })
end

function on_tick(t)
    G.announcer.tick(t)
    G.player.tick(t)
    if input.down("attack") then G.player.attack() end        -- hold the button to keep swinging
    G.enemies.tick(t)
    G.companion.tick(t)
    G.music.tick(t)
    if G.world.tick then G.world.tick(t) end
    if t % 1800 == 900 and G.state.class then G.save() end        -- progress is kept every 30 s (the world itself is saved on exit / F11)
end

-- the game's own input actions (input.cfg `action.NAME = mouse / key / pad`): logged, so a recording replays them
function on_action(name, down, pl)
    if not down or not G.state.class then return end
    if name == "attack" then G.player.attack()
    elseif name == "ability" then G.player.ability()
    elseif name == "quick_heal" then G.player.quick("heal")
    elseif name == "quick_mana" then G.player.quick("mana")
    elseif name == "quick_throw" then G.player.quick("throw") end
end

function on_anim(m, event, clip)
    if G.enemies.on_anim(m, event, clip) then return end
    if G.companion and G.companion.on_anim then G.companion.on_anim(m, event, clip) end
end
