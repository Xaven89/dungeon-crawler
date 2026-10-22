# THE DESCENT — a dungeon crawler game show (made with the Voxelith engine)

**THE DESCENT™: Season 7, Floor 1 — "The Welcome Back Basement".** A playable vertical slice, and the first outside test of the engine: every problem found on the way is in `ENGINE_FEEDBACK.md`.

You are **Contestant #4,471,902**. You did not sign up. *The Descent* is a game show broadcast to eleven galaxies in which contestants go down a bottomless dungeon floor by floor. The show is hosted by **GLEE**
(General Logistics & Entertainment Engine), a cheerful, sardonic AI that comments on everything you do through the HUD and a synthesised "voice". Your companion is **Admiral Honk**, a goose with a naval rank and a grudge.
All names, jokes and texts are original (inspired by the tone and structure of a cruel, cheerful game-show dungeon, not by any text).

## How to run
```
./voxelith --manual --project projects/dungeon_crawler --time 0.75 --hud 0         # the game (needs a display and a Vulkan GPU). --time 0.75 matters: the sky must not light the dungeon
./voxelith --mcp --project projects/dungeon_crawler --threads 3 --time 0.75         # the AI's way (.mcp.json is set up): screenshots never contain the Lua HUD
tools/hudshot.sh out.png 14 --script idle:3000                                      # windowed in a private Xvfb + ffmpeg grab: the way to SEE the HUD without a display (BOOT=file.lua sets up a situation)
tools/playthrough.py janitor                                                        # a bot plays the whole floor through the MCP server, takes pictures into ~/share/tour, records and replays the session (hash check)
./voxelith --check-project projects/dungeon_crawler
python3 tools/make_dungeon_models.py ; python3 tools/make_sounds.py                 # regenerate the creatures (models/*.vxm) and the sounds (sounds/*.wav)
```
A new run: delete `projects/dungeon_crawler/world.vxs*`, `.state`, `.events`, `.prefabs` (the level builds its voxels only when `project.first_run()`; the progress is in `.state/store.json`).

### Keys (the engine's sandbox keys are switched off in `input.cfg`; see ENGINE_FEEDBACK.md for why combat is on the keyboard)
| key | |
|---|---|
| WASD, Shift, Space, mouse | walk, run, jump, look |
| **F** | attack (the equipped weapon: reach, damage and speed differ) |
| **Q** | the class ability (Mop Sweep / Fire Bolt / Power Chord / Audit; costs mana, has a cooldown) |
| **E** | use what the crosshair is on (levers, crates, vending machine, crystal, stairs, vehicles) |
| **R / T / G** | quick: heal item / mana item / throw a firecracker |
| **I / C / J** | bag + equipment / character sheet (spend stat points) / achievements; Esc closes |
| **0** | camera: first person / third person; **F5** screenshot to ~/share; **F11** save the world |
Do not press the number keys, Z, X, Y, N, M: they are the engine's teleports / undo / rain / clock and cannot be unbound. The game defends itself (GLEE scolds you).

## What the slice contains
* **Start**: the Intake Lobby (a hand-built hall of voxels, braziers, a reception desk, a save crystal, a janitor's closet behind a prefab door), a **class selection** screen (Janitor, Pyromaniac, Bard, Accountant), GLEE's intro.
* **Classes, stats, levels, items**: five stats (STR DEX INT CON CHARM), XP and levels to 12 (2 stat points each), 40 items in five rarities with absurd names (weapons, armour, trinkets, consumables, junk), equipment, **loot crates of four tiers** (bronze / silver / gold / platinum), a vending machine, **20 achievements** with absurd names.
* **Floor 1** — nine areas, each built differently:
  1. **Intake Lobby** (voxels, tiles, pillars, voxel text, portcullis gate that sinks into the floor).
  2. **Hall of Mild Peril**: tutorial combat; a pressure plate releases a **physics boulder**; a row of **explosive barrels** next to a speckled hollow wall = a **secret passage** to the Grotto (a gold crate in a closet on the way).
  3. **Boiler Gallery**: a **lava channel** (liquid), a raised **drawbridge** on a hinge (lever), tanks, steam, goblins, spitters across the water.
  4. **Conveyor of Consequences**: a real **conveyor belt** (events.belt) carrying crates and the player towards a **furnace pit**; ledges; an emergency-stop lever.
  5. **The Gutter**: a flooded sewer with walkways; opening the gold crate on the island **floods the room** (the water rises 1.5 m, the toxic water hurts).
  6. **Zero-G Ballroom**: **gravity fields** (weightless dance floor, a lever that flips gravity upward), floating loot, stained glass lighting; **the ceiling vent shortcut**: fall up through the hole into a service tunnel that skips the Grotto.
  7. **Mushroom Grotto**: **procedurally carved cave** (noisy spheres, a flat floor put back, stalactites, giant glowing mushrooms, pools, fireflies), the **Goblin Foreman** mini-boss.
  8. **The Floor Manager's Office**: the **boss** in a round arena with a lava moat: intro cutscene with the editor camera, three phases (clipboard throws; summons and floor slams; lava geysers), boss bar, ragdoll death, platinum crate.
  9. **Stairwell 1**: the safe room (fireplace, bookshelves, vending machine, save crystal, Honk's bed, the stairs down = the end of the slice with a summary screen).
* **Enemies** (agents + rigged models, 9 creatures generated by `tools/make_dungeon_models.py`): Gutter Slime, Toxic Slime, Skeletal Intern, Goblin Sales Associate, Cellar Rat, Mushroom Spitter (ranged), Goblin Foreman, the Floor Manager. They have idle / chase / attack / flinch behaviour, attack clips whose `hit` event is the damage frame, pack aggro, ragdoll deaths, drops.
* **Companion**: Admiral Honk follows, bites enemies, comments in his own voice, sits in his bed in the safe room, is put back if lost.
* **Announcer**: GLEE reacts to rooms, kills, deaths, loot, traps, level-ups, achievements, idle time (strings in `strings/en.csv`, ~250 lines in variants, German for the UI and a selection of lines in `strings/de.csv`).
* **Sound and music**: all synthesised by `tools/make_sounds.py` (voice blips, ~40 effects, music beds per area and a fight layer, as 2-second pieces played one after another because the engine can only start whole files).
* **HUD** (`game/hud.lua`, UI kit): HP / MP / XP, ability cooldown, quick keys, announcer panel with typewriter and face, achievement toasts, boss bar, hit marker, damage numbers, interaction prompts, minimap, viewers counter, class / bag / character / achievements / shop / death / end screens.
* **Save**: progress (`project.store`: class, stats, inventory, flags, cleared rooms, opened crates, achievements, checkpoint) every 30 s and on exit, the world (voxels) on exit / F11; checkpoints at the Lobby, Hall end, Boiler exit, Ballroom door, Arena door, Stairwell; death costs 20 % gold.
* **Replay**: `tools/playthrough.py` records a whole run and replays it to the same hash (without the prefab dressing, see below).
* **Footsteps** per creature (`footsteps.csv`), a title screen, a German UI.

Engine systems used: voxel building and carving, prefabs (door with hinge, sign board, props) and `prefab.place`, textures (built-in and `textures.json` pixel art), paint, voxel text, materials.csv, emitters with lights (torches, braziers, fireflies), GI, fire / explosions / destruction (barrels, secret wall, boss slam), liquids (lava, toxic water, scripted flood), physics bodies (boulder, projectiles, loot, crates), gravity fields (null, uniform, events.gravity_target), agents + nav + rigged models + clips + events + ragdoll, events (buttons, levers, volumes, doors, belt, gravity target), vehicles, cameras (first, third, editor cutscene), audio (WAV playback), HUD + UI kit + inventory sample, `project.store`, localization (`tr`, plural-free), recordings.
Not used: world generation by biomes (the floor is carved into a flat plain; see "What is next"), wear / foliage ground cover, networking, hinges beyond doors, packs.

## Code layout (`projects/dungeon_crawler/`)
```
project.cfg  level.lua  input.cfg  materials.csv  textures.json   the project; level.lua wires on_start / on_tick / on_anim / on_hud
game/core.lua       units, deterministic rng, builders (G.fill G.room G.corridor G.ring G.lamp G.sconce G.torch ...)
game/world.lua      the room table, neighbours, activation of enemies by room, housekeeping against the engine's debug keys, checkpoints, zones
game/rooms/*.lua    one file per area (builders = voxels on the first run, things = emitters / events / gravity / enemies on every run)
game/traps.lua      crates, barrels, boulder, hazards, interaction prompts     game/items.lua   items, loot tables, inventory
game/player.lua     state, classes, combat, abilities, levelling, death        game/enemies.lua enemy types, AI, damage, drops, projectiles
game/boss.lua       the Floor Manager                                           game/companion.lua  Admiral Honk
game/announcer.lua  GLEE + sfx helper + achievements                            game/music.lua   the music director
game/hud.lua        everything drawn                                            game/shop.lua    the vending machine
models/*.vxm        creatures (generated) and kit props      sounds/*.wav (generated)      strings/en.csv de.csv
tools/              make_dungeon_models.py make_sounds.py playthrough.py hudshot.sh xsend.py
```
The dungeon is described in metres in a local frame (x east, z south, y up from the lobby floor); `Game.OX/OY/OZ` place it in the world (flat terrain, everything is carved into the stone under the plain).

## Testing without a keyboard
`on_hud` is not called in MCP / headless runs, so every action is a plain global function (`Game.player.attack()`, `Game.player.pick_class("pyro")`, `Game.shop.buy(1)`, ...) that the HUD calls through `ui.run`; the bot and the MCP `lua` tool call the same.
`Game.autoaim = true` makes attacks ignore where the view points (the MCP cannot turn the view during a fight). `tools/xsend.py` sends key events to a windowed session in Xvfb (keys work, the mouse does not).

## Test log (what was run and seen)
* `./voxelith --check-project projects/dungeon_crawler`: 0 errors (1 warning: the German file has fewer keys than the English one, they fall back).
* Every area was loaded through the MCP server and looked at with free-camera screenshots (`~/share/tour/*.png`, `~/share/*.png`); the HUD screens with `tools/hudshot.sh` (class select, main HUD in the Hall with enemies and an announcer line, bag, shop, boss intro and bar, death, German).
* `tools/playthrough.py janitor`: class pick, the gate opens, the bot fights through Hall → Boiler → Conveyor → Gutter → Ballroom → Grotto (not every enemy is reachable for a bot that cannot aim), reaches the boss, dies and respawns at checkpoints, buys at the vending machine and finishes the floor; the **recording replays to the same hash** (the pyromaniac run: `9fc4235cf96063fd`, 20,213 ticks, `== the recorded hash`; the bot writes `dev/flags.lua` so that the set dressing made with `prefab.place` is skipped, because the engine cannot replay prefabs: ENGINE_FEEDBACK.md).
* Tested by hand through MCP: boulder trap (releases and crosses the hall in about 3 s), barrels chain-explode and crack the secret wall, drawbridge lowers, belt carries crates (1.6 m/s), gutter floods to 1.3 m, gravity flip carries the player up through the vent, vent tunnel and steps, closet door, death and respawn, save / load across two process runs (class, gold, level, checkpoint, inventory, opened crates, cleared rooms, achievements, world voxels), boss phases 1-3 and death (gate opens, achievement, keycard, platinum crate).
* Performance (headless 1080p, 3 threads): the tick costs about 3 ms (budget 16.7); the GPU 9-15 ms in the busiest scenes on the RTX 3070 Laptop.
* **Not checked**: sound (no audio device: the engine's output is a dummy device here, so the sounds and music were generated and loaded (`sound.load` finds every file) but never heard), the mouse (the engine reads the pointer in a way synthetic X events do not reach, so click-driven screens were only checked by their keyboard path and by drawing), a human playing the boss fight, the German text in the game (checked on the class screen), long-run memory.

## Pictures
`~/share/descent/` has the title, the class screen, the HUD in the Hall, the bag, the vending machine, the boss intro, the death screen, the German UI and a tour picture of every area (`tour_*.png`).

## What is next
* Floor 2 ("The Smaller Basement"): the stairs lead nowhere yet; the stairwell door is the end of the slice.
* A generated outdoor "plaza" with `terrain = biomes` above the dungeon, and caves from the generator instead of carved spheres (the engine's `caves = on` would have punctured the hand-built rooms; see WORLD_GEN.md).
* Mouse buttons in play mode for attacks (needs an engine feature, ENGINE_FEEDBACK.md), a weapon in the first-person view, knockback, a proper third-person player model.
* More enemy types with real behaviours (the Mimic crate), a skill tree, crafting, a second companion.
