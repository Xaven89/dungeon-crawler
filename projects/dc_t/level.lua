-- THE DESCENT: Season 7, Floor 1. The entry point: includes the modules and wires the engine callbacks. See GAME.md.
include("game/core.lua")
include("game/gen/layout.lua")
include("game/gen/track.lua")
include("game/items.lua")
include("game/announcer.lua")
include("game/skills.lua")
include("game/player.lua")
include("game/vnum.lua")
include("game/gore.lua")
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
include("game/signs.lua")
include("game/shop.lua")
include("game/boss.lua")
include("game/companion.lua")
include("game/music.lua")
include("game/gen/safe.lua")
include("game/gen/rules.lua")
include("game/gen/floor.lua")
include("game/gen/contracts.lua")
include("game/gen/run.lua")
include("game/gen/validate.lua")
include("game/gen/themes.lua")
include("game/gen/themes_more.lua")
include("game/show.lua")
include("game/hud.lua")
include("game/hud_run.lua")

local G = Game

function on_start()
    G.load()
    G.items.init()
    if G.state.class then G.state.flags.gate_lobby = true end          -- a contestant who has checked in is let through, whatever happened to the 5 s timer before
    G.enemies.define_fx()
    G.vnum.define()
    G.run.ensure()
    local resumed = G.run.resume()
    if not resumed then
        G.world.build()
        G.world.populate()
    end
    G.music.load_settings()
    G.setup_player_models()
    G.sfx.preload({ "voice_blip", "swing", "hit", "hurt", "honk", "coin", "levelup", "achievement" })
    local s = G.state
    if not s.class then
        local x, y, z = G.world.start_position()
        player.teleport(x, y, z)
        G.screen = "title"
        after(330, function() if not G.state.class and G.screen == "title" then G.screen = "run" end end)
        after(360, function() G.announcer.say_key("intro", {}) end)
        after(660, function() G.announcer.say_key("intro", {}) end)
        after(960, function() G.announcer.say_key("intro", {}) end)
    else
        local cp = G.world.checkpoints[s.checkpoint] or G.world.checkpoints.lobby
        if not cp and G.floorgen.layout then local r = G.floorgen.layout.rooms[G.floorgen.layout.start]; cp = { x = r.x + r.w / 2, y = 0.1, z = r.z + r.d / 2 } end
        if cp then player.teleport(G.mx(cp.x), G.my(cp.y), G.mz(cp.z)) end
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
include("engine/equipment.lua")
-- the contestant's body by class: the kit's rigged figures (finer voxels than the world, docs/ANIMATION.md "Voxel scale"); the Hero model before a class is chosen.
-- What is equipped (items.lua) is drawn on it (docs/EQUIPMENT.md): the kit's item models, merged into the body, no extra bodies.
local BODIES = { janitor = "human_man_warrior", pyro = "human_demon_girl", bard = "human_woman_adventurer", accountant = "human_man_adventurer" }
local WEAPON_LOOK = { mop = "mop.vxm", torch_used = "torch.vxm", lute = "lute.vxm", stapler = "stapler.vxm", sword_mild = "iron_sword.vxm", excalibur = "iron_sword.vxm", dagger_cd = "iron_sword.vxm", spoon = "iron_sword.vxm",
                      mace_pa = "battle_axe.vxm", axe_ot = "battle_axe.vxm", rolling = "battle_axe.vxm" }
local HAND_FROM_FILE = { ["mop.vxm"] = true, ["torch.vxm"] = true, ["lute.vxm"] = true, ["stapler.vxm"] = true }
local CLASS_HAT = { pyro = "wizard_hat.vxm" }
function G.kit()
    local s, kit = G.state, {}
    local w = s.equip.weapon and WEAPON_LOOK[s.equip.weapon]
    if w then kit.main_hand = { file = w, hand = HAND_FROM_FILE[w] or false } end      -- (first person: the item's own `hand` block for the tools, the game's own sword.vxm for blades)
    local a = s.equip.armor
    if a == "potlid" then kit.shoulders = { file = "pauldron.vxm", mirror = true }
    elseif a == "tux" or a == "bathrobe" then kit.back = { file = "cape.vxm" }
    elseif a == "cardboard" then kit.head = { file = "iron_helmet.vxm" } end
    if not kit.head and CLASS_HAT[s.class or ""] then kit.head = { file = CLASS_HAT[s.class] } end
    return kit
end
function G.setup_player_models()
    local body = G.state and BODIES[G.state.class or ""]
    local kit = body and G.kit() or {}
    player.model(body and ("models/figures/" .. body .. ".vxm") or "models/hero.vxm", { idle = body and kit.main_hand and "ready" or "idle", walk = "walk", attack = "attack" })
    equipment.state.p0 = nil                                          -- (a new player.model starts bare)
    if body then equipment.apply(equipment.player(0), kit) end
    if not (kit.main_hand and kit.main_hand.hand) then player.hand_model("models/sword.vxm", { offset = { 0.35, -0.05, 1.0 }, turn = 0, idle = "idle" }) end
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
    elseif name == "interact" then
        -- E: a chest anywhere on it (the engine's own use handles the levers and buttons it is aimed at)
        if not G.screen and not G.player.dead then
            local c = G.traps.crate_in_front(3.0, 0.2)
            if c then G.traps.open_crate(c.id)
            else G.traps.use_door() end
        end
    elseif name == "ability" then G.player.ability()
    elseif name == "quick_heal" then G.player.quick("heal")
    elseif name == "quick_mana" then G.player.quick("mana")
    elseif name == "quick_throw" then G.player.quick("throw") end
end

function on_anim(m, event, clip)
    if G.enemies.on_anim(m, event, clip) then return end
    if G.companion and G.companion.on_anim then G.companion.on_anim(m, event, clip) end
end
