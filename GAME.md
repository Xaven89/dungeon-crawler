# THE DESCENT — a dungeon crawler game show (made with the Voxelith engine)

**THE DESCENT™: Season 7, Floor 1 — "The Welcome Back Basement".** A playable vertical slice, and the first outside test of the engine: every problem found on the way is in `ENGINE_FEEDBACK.md`.

You are **Contestant #4,471,902**. You did not sign up. *The Descent* is a game show broadcast to eleven galaxies in which contestants go down a bottomless dungeon floor by floor. The show is hosted by **GLEE**
(General Logistics & Entertainment Engine), a cheerful, sardonic AI that comments on everything you do through the HUD and a synthesised "voice". Your companion is **Admiral Honk**, a goose with a naval rank and a grudge.
All names, jokes and texts are original (inspired by the tone and structure of a cruel, cheerful game-show dungeon, not by any text).

## How to run
```
./voxelith --manual --project projects/dungeon_crawler --hud 0                       # the game (needs a display and a Vulkan GPU); project.cfg has `game = on` (the sandbox keys are off)
./voxelith --mcp --project projects/dungeon_crawler --threads 3                      # the AI's way (.mcp.json is set up): screenshots do not contain the Lua HUD yet
# MCP: screenshot {hud: true} draws on_hud over the picture (no display needed); project.cfg has `time = 0.75` (the sky must not light the dungeon)
tools/playthrough.py janitor                                                        # a bot plays the whole floor through the MCP server, takes pictures into ~/share/tour, records and replays the session (hash check)
./voxelith --check-project projects/dungeon_crawler
python3 tools/make_dungeon_models.py ; python3 tools/make_sounds.py                 # regenerate the creatures (models/*.vxm) and the sounds (sounds/*.wav)
```
Damage numbers are the engine's `fx.text` labels (letters 11 cm, crits 17 cm, at 3 m) that rise and burst into motes (`game/vnum.lua`; `particle_taa = off` in project.cfg keeps them free of ghost images); `debris` / `grain` particles settle into the world as real voxels: used on purpose for the gore of deaths (stains, bones and lumps that stay and are saved), never for hit effects. The lobby and arena gates are plain voxels removed by the script (`W.gate_open`), not event doors.

**Testing:** windowed test runs write the project's save (`world.vxs`, `.state`, `.events`): run them on a copy of the project (`cp -r projects/dungeon_crawler /tmp/x/dc` and `--project /tmp/x/dc`), not on the folder that is streamed to be played.

A new run: `tools/play.sh new [SEED]` (it deletes `projects/dungeon_crawler/world.vxs*`, `.state`, `.events`, `.prefabs` and starts the engine with the seed; the Orientation builds its voxels only when `project.first_run()`; the progress is in `.state/store.json`).

**Streaming (Sunshine / Moonlight):** click once in the window to capture the mouse for looking (Esc lets it go: it also opens the settings). In Moonlight use the *relative mouse mode* (Ctrl+Alt+Shift+M, or turn off "optimize mouse for remote desktop"), otherwise the absolute virtual mouse fights the engine's pointer warp. `tools/stream-descent.sh` is the Sunshine launcher (two app entries: continue / new run).

### Keys (`game = on` switches the engine's sandbox keys off; the game's own actions are in `input.cfg`)
| key | |
|---|---|
| WASD, Shift, Space, mouse | walk, run, jump, look |
| **LMB or F** | attack, hold to keep swinging (the equipped weapon: reach, damage and speed differ) |
| **RMB or Q** | the class ability (Mop Sweep / Fire Bolt / Power Chord / Audit; costs mana, has a cooldown) |
| **E** | use what the crosshair is on (levers, crates, vending machine, crystal, stairs, vehicles) |
| **R / T / G** | quick: heal item / mana item / throw a firecracker |
| **I / C / J** | bag + equipment / character sheet (spend stat points) / achievements; Esc closes |
| **0** | camera: first person / third person; **F5** screenshot to ~/share; **F11** save the world |
(Before the engine's game mode the level had to defend itself against Z / number keys / Y; that code is gone.)

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
* **Sound and music**: all synthesised by `tools/make_sounds.py` (voice blips, ~40 effects, music beds per area and a fight layer). Music is one looping file per bed (`sound.play{ loop = true, bus = "music" }`) with 2-second crossfades between areas, the announcer's voice is 2D on the voice bus, and the bag screen's Settings tab (O) has sliders for the three buses (saved). The mix of a recorded playthrough was rendered offline with `--audio-out` and analysed (no clipping, no silence, music continuous).
* **Player body and weapon**: a hero model for the third-person camera and a sword in the first-person view that swings with every attack (`player.model`, `player.hand_model`; render only).
* **HUD** (`game/hud.lua`, UI kit): HP / MP / XP, ability cooldown, quick keys, announcer panel with typewriter and face, achievement toasts, boss bar, hit marker, damage numbers, interaction prompts, minimap, viewers counter, class / bag / character / achievements / shop / death / end screens.
* **Save**: progress (`project.store`: class, stats, inventory, flags, cleared rooms, opened crates, achievements, checkpoint) every 30 s and on exit, the world (voxels) on exit / F11; checkpoints at the Lobby, Hall end, Boiler exit, Ballroom door, Arena door, Stairwell; death costs 20 % gold.
* **Replay**: `tools/playthrough.py` records a whole run and replays it to the same hash (without the prefab dressing, see below).
* **Footsteps** per creature (`footsteps.csv`), a title screen, a German UI.

Engine systems used: voxel building and carving, prefabs (door with hinge, sign board, props) and `prefab.place`, textures (built-in and `textures.json` pixel art), paint, voxel text, materials.csv, emitters with lights (torches, braziers, fireflies), GI, fire / explosions / destruction (barrels, secret wall, boss slam), liquids (lava, toxic water, scripted flood), physics bodies (boulder, projectiles, loot, crates), gravity fields (null, uniform, events.gravity_target), agents + nav + rigged models + clips + events + ragdoll, events (buttons, levers, volumes, doors, belt, gravity target), vehicles, cameras (first, third, editor cutscene), audio (WAV playback), HUD + UI kit + inventory sample, `project.store`, localization (`tr`, plural-free), recordings.
Not used: world generation by biomes (the floor is carved into a flat plain; see "What is next"), wear / foliage ground cover, networking, hinges beyond doors, packs.

**Signs:** every voxel sign is registered by `G.text`; `tools/check_signs.py` looks in front of each one for pillars / pipes. A sign must fit its wall (width = characters x 6 x size / 16 m). Earlier saved worlds are repaired once on start (`fix_*` flags in the saved state).

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
tools/              make_dungeon_models.py make_sounds.py playthrough.py xsend.py
```
The dungeon is described in metres in a local frame (x east, z south, y up from the lobby floor); `Game.OX/OY/OZ` place it in the world (flat terrain, everything is carved into the stone under the plain).

## Testing without a keyboard
`on_hud` is not called in MCP / headless runs, so every action is a plain global function (`Game.player.attack()`, `Game.player.pick_class("pyro")`, `Game.shop.buy(1)`, ...) that the HUD calls through `ui.run`; the bot and the MCP `lua` tool call the same.
`Game.autoaim = true` makes attacks ignore where the view points (the MCP cannot turn the view during a fight). `tools/xsend.py` sends key events to a windowed session in Xvfb (keys work, the mouse does not).

## Test log (what was run and seen)
* `./voxelith --check-project projects/dungeon_crawler`: 0 errors (1 warning: the German file has fewer keys than the English one, they fall back).
* Every area was loaded through the MCP server and looked at with free-camera screenshots (`~/share/tour/*.png`, `~/share/*.png`); the HUD screens with MCP `screenshot {hud: true}` (the earlier ones with an Xvfb grab) (class select, main HUD in the Hall with enemies and an announcer line, bag, shop, boss intro and bar, death, German).
* `tools/playthrough.py janitor`: class pick, the gate opens, the bot fights through Hall → Boiler → Conveyor → Gutter → Ballroom → Grotto (not every enemy is reachable for a bot that cannot aim), reaches the boss, dies and respawns at checkpoints, buys at the vending machine and finishes the floor; the **recording replays to the same hash** (the pyromaniac run: `9fc4235cf96063fd`, 20,213 ticks, `== the recorded hash`; the bot writes `dev/flags.lua` so that the set dressing made with `prefab.place` is skipped, because the engine cannot replay prefabs: ENGINE_FEEDBACK.md).
* Tested by hand through MCP: boulder trap (releases and crosses the hall in about 3 s), barrels chain-explode and crack the secret wall, drawbridge lowers, belt carries crates (1.6 m/s), gutter floods to 1.3 m, gravity flip carries the player up through the vent, vent tunnel and steps, closet door, death and respawn, save / load across two process runs (class, gold, level, checkpoint, inventory, opened crates, cleared rooms, achievements, world voxels), boss phases 1-3 and death (gate opens, achievement, keycard, platinum crate).
* Performance (headless 1080p, 3 threads): the tick costs about 3 ms (budget 16.7); the GPU 9-15 ms in the busiest scenes on the RTX 3070 Laptop.
* **Not checked**: how the sounds and music *sound* to a human (the offline render was only measured: levels, clipping, silences, continuity), the mouse (the engine reads the pointer in a way synthetic X events do not reach, so click-driven screens were only checked by their keyboard path and by drawing), a human playing the boss fight, the German text in the game (checked on the class screen), long-run memory.

## Pictures
`~/share/descent/` has the title, the class screen, the HUD in the Hall, the bag, the vending machine, the boss intro, the death screen, the German UI and a tour picture of every area (`tour_*.png`).

## What is next
* Floor 2 ("The Smaller Basement"): the stairs lead nowhere yet; the stairwell door is the end of the slice.
* A generated outdoor "plaza" with `terrain = biomes` above the dungeon, and caves from the generator instead of carved spheres (the engine's `caves = on` would have punctured the hand-built rooms; see WORLD_GEN.md).
* Mouse buttons in play mode for attacks (needs an engine feature, ENGINE_FEEDBACK.md), a weapon in the first-person view, knockback, a proper third-person player model.
* More enemy types with real behaviours (the Mimic crate), a skill tree, crafting, a second companion.


## Round 4 fixes
- Ballroom vent: the service tunnel exit into the corridor was walled (opening `60.6,0,110.7 .. 63.4,4.6,111.4`, repair flag `fix_v5` for old saves). Verified: flip lever, ride up, walk the tunnel down and out.
- Emitters: floating dust/fireflies/embers use `fx.mote` (`G.as_motes`, `G.embers`, `G.dust`), nothing glows on the floor any more.
- Chests are `chest_wood` (tough, not flammable) and `T.redraw_all_chests()` repairs damaged ones when a saved world loads.
- Playthrough (pyro) replays to hash `0b615730ca570529`.

## Gore (walk-through stains)
- `game/gore.lua`: `G.gore.splat/wound/clean/mop/sweep`; materials 96-99 (`passable = 1`); every wound and death splatters, `G.state.stains` remembers the spots (cap 200).
- Cleaning: the Janitor's mop swung at nothing cleans 1.5 m in front, Mop Sweep (ability) 4.5 m around; 1 gold per spot, achievement `clean_sweep` after 40 spots, GLEE comments (`gore.clean.*`).
- `fx.splat` position is in world METRES (see ENGINE_FEEDBACK Phase 7).

## Player bodies
The contestant's third-person body is a kit figure by class (`BODIES` in level.lua; files in `models/figures/`): janitor = human_man_warrior, pyro = human_demon_girl, bard = human_woman_adventurer, accountant = human_man_adventurer. Before a class is chosen the Hero model is used. Playthrough (pyro) replays to hash `437bfd517be4a9e9`.

## Equipment on the body
`G.kit()` in level.lua maps what is equipped to the kit's item models (docs/EQUIPMENT.md): weapons (mop, torch, lute, stapler -> their own kit models, also the first-person hand model via their `hand` block (the engine gives items a generic idle/swing); swords, dagger, spoon -> iron sword; mace, axe, rolling pin -> battle axe) in the right hand (the idle clip is `ready` while holding something), Pot-Lid Pauldrons -> pauldrons, Tux/Bathrobe -> cape, Cardboard Breastplate -> iron helmet, the Pyromaniac always a wizard hat. `G.setup_player_models()` rebuilds it on class choice and on every equip/unequip. The first-person hand keeps `models/sword.vxm`. The project's `models/figures/*.vxm` are copies of the kit figures: copy them again after an engine update that changes the figures.

## Seeded dungeon (round 2: PLAN.md; the floors themselves are replaced by the big floors below, the rest stands)
A run is a seed. `G.state.run = { mode = "orientation" | "gen", seed, floor }`. The hand-built first floor is the **Orientation**; every other floor is generated from `(seed, floor)` into the same volume (the old floor is wiped to stone, ~3 s for a generated floor, ~15 s the first time after the Orientation) behind a loading veil. The floor above "collapses": there is no way back up.
- **Run flow** (`game/gen/run.lua`, `hud_run.lua`): title -> the *run screen* (seed field, "Roll", ORIENTATION / STRAIGHT DOWN) -> class -> play. Stairs in the exit stairwell -> the recap screen -> next floor. Settings tab: seed shown, "Leave this run: new seed". A save from before the seeds is an Orientation run.
- **(Replaced by the big floors; kept for the story)** Plan (`gen/layout.lua`, now only `make_rng`): 3 x 4 cells of 40 x 37 m, 8..10 rooms, a random spanning tree + 1..2 loops, start (arrival safe room) in the top row, the exit stairwell hangs behind the boss room. `L.check` asserts it (200 seeds x 3 floors in the test).
- **(Replaced)** Build (`gen/floor.lua`, rewritten for P2): tear down (`gen/track.lua` wraps the engine constructors and remembers events / emitters / bodies / gravity per floor), wipe in 40 m tiles (an edit may reach 40 m: ENGINE_FEEDBACK), rooms (themes), corridors (lining first, air after; 0.3 m into the rooms or the doors are walled shut: found by the validator), boss gate, things. One step per tick. `F.load` redoes only the things after a restart (the voxels are in world.vxs, the store is saved with it).
- **Rooms** (`gen/themes.lua`, `themes_more.lua`): hall, furnace (lava pool + stepping stones to a crate), flooded (toxic pool), ballroom (low gravity), grotto, crypt, library, depot (barrels), prize room (three chests, one is a mimic), warlord (a miniboss and retinue), arrival, stairwell, lair (boss). Rules for themes: 4 m along the walls stay free, decor comes from a pure `plan()` that the population also reads (no world queries: the population must be a pure function of the seed).
- **Enemies**: the old eight plus the rigged kit figures (orc, bandit, samurai, imp (casts embers), troll, cyclops miniboss, golem boss) with weapons attached (`equipment`), clips `attack` (event `hit`) / `cast` / `hit` / `die`; elites (swift, armored, volatile); hp +20 % and damage +10 % per floor. Bosses: Floor Manager, Golden Parachute (kit golem, phase moves mapped onto `cast` / `attack`).
- **Rules per floor** (`gen/rules.lua`): night shift, the DTs (3 stages by time), quiet floor (muted rooms), crowd pleaser. **The show** (`game/show.lua`): spectacle -> viewers / followers / favorites; favorites become sponsor boxes in the next safe room (a quarter are jokes), recap with a rank S..D. **Skills by use** and **conditions** (bleed, septic) in `game/skills.lua` (K = skills tab).
- **Tools** (the old floor tools genshot / gen_validate / gen_playthrough are gone: p1_validate, p2_playthrough, p2_pictures replace them): `tools/playthrough.py` (the Orientation).
- **Known limits**: the bot teleports between rooms (walking is the validator's job); `world.vxs` is an append-only log, every floor adds a few MB; the seed screen has no daily seed (the engine has no date: ENGINE_FEEDBACK Phase 15).

### Round 2, later additions
- **Contracts** (`gen/contracts.lua`): at every arrival the show offers three of eight deals (a boon and a price; "Exclusive Broadcast Rights" = permanent death: the run ends, `runover` screen). Held ones are in `state.contracts` and listed on the character sheet. Hooks: max hp / mp, stats, damage, gold, enemy damage, spectacle, viewers, shop prices, heal on room clear, union dues per floor.
- **Captive room + allies** (`game/ally.lua`): a caged monster in the middle, guards around; the lock (E) frees it and it fights for you and follows you down the stairs (one at a time, cannot be hurt). Achievement "Animal Rights Enthusiast".
- **Corridors**: marble door frames, torches every 9 m, from floor 2 some long straight corridors have a boulder plate (hazard-yellow tile, the boulder comes from one end).
- **Safe rooms mirror** (`gen/safe.lua`): fixtures are drawn in canonical offsets and mirrored so that none stands in a doorway (the validator found six seeds whose exit was walled by a bookcase or the vending machine).
- **Cut-off builds**: `state.run.building` is saved before a floor is built; a start that finds it wipes and builds the floor again.
- Gen run: respawn is just inside the first door of the room you cleared last, never in the middle (the middle can be lava).
- Tests that ran at the end: `gen_validate` over seeds 1..28 x up to 4 floors (0 problems), `gen_playthrough` 5 floors (replay hash equal), `playthrough` of the Orientation (replay hash equal).

### Replays (state at the end of round 2)
- The Orientation bot (`tools/playthrough.py pyro`) replays to its hash (`357537bcdbc523a8` at the last run). `tools/gen_playthrough.py SEED CLASS N` replays to its hash for N up to 5 floors (seed 99: 1 to 5 floors verified); **6 floors of seed 99 do not** (live `f9362e3a0c2d96cc`, replay `ec7ee81ff4c742a9`, recording kept in /tmp/repro_replay while the session lasts). Reported to the engine side (ENGINE_FEEDBACK Phase 17); the cause is not known. Found and fixed on the way: merged weapons on enemy agents changed the simulation (now `mode = "attach"`).
- The bot opens crates in sorted order (a `pairs` over string keys is not the same order in two processes: never let that order decide anything in the game's own logic either).

## Big floors, P0 (the plan, no world yet)
Plan: `~/share/big-floors-plan.md`. `game/gen/cell.lua` (`Game.gen.cell.make_cellgen(hash)`) is the pure plan of a floor from (seed, floor): blocks of 8x8 cells with 8 m arteries, 4x4 quadrants (binary-tree maze), side halls, alleys, roles, boroughs (2x2 super-cell), free stairwells. `game/gen/contract.lua` checks items 1-13. `tools/plan_check.py [SEEDS] [--floors ..] [--setting small|large]` runs it over many seeds (0 violations over 2000 seeds x floors 1,2,3,5,6,7,8; 300 seeds large); `tools/plan_dump.py SEED FLOOR [DIR]` writes ASCII dumps. Deviations from the plan: two safe rooms per quadrant (k-center), the distance limit is 6 steps (plan: 3; average 4.9), two free stairwells on every floor. Next: P1 (hook shells) after the engine's E1b (ordered hook ops).
Review fixes (M1-M4): `cellgen_make(H)` and `cellgen_hash_from(wh)` are global functions with no file locals (they run in the region hook via `hook_globals`; tested in a scratch project: the hook built boxes from `CG.cell`); the adapter folds the five hash arguments into worldgen.hash's (x, z, salt) without collisions (1e5 tuples, 0 duplicates); a fresh-context cell costs about 1.6 ms (was 3.4: the free stairwells no longer look at quadrants; tree distances are memoised); run = world seed (design M1 a), `plan_check --hash world` runs the contract through worldgen.hash.

## Big floors, P1 (the hook builds the shells)
- `game/gen/shell.lua`: global `shell_region(rx, rz, worldgen.hash)` (the level script's `on_region` calls it): one 32 m cell per region, floor n in the band z = n * 1024 m + 64 m (regions rz = n * 32 + 2 + cj, ring regions at -1 and W / H carry the outer halves of the rim arteries). Every region: a brick mass over the cell, clears for the room, its half of every hall (+ the jog to the neighbour's door; both cells carve their own half, no placement crosses a region), the 4 m artery strips on block borders (9 m high), floor layer by theme, lantern voxels on the ceilings. Super-cells (boroughs) have a quarter courtyard (26 x 26, 6 m margin outside) per cell (`cell.lua`).
- The scratch project: `tools/p1_sync.sh` makes `projects/dc_p1` (git-excluded) from the game with `dev/p1/project.cfg` + `dev/p1/biomes.csv` (endless, one-row table). The real project stays `terrain = flat` (the hook is idle there) until the run flow moves to bands (P2).
- Tools: `tools/p1_validate.py SEEDS --floor N` (flood_region over every edge pair and every artery door, 0 problems for floor 1 x 10 world seeds at 159-181 checks each, floors 2, 5, 6 x 3 seeds), `tools/p1_walk.py SEED --shots` (an agent walks from the arrival to the nearest free stairwell along the plan path; pictures), `tools/p1_shot.py FLOOR CI CJ` (room pictures with temporary lights). Pictures: `~/share/big_floors_p1/`.
- Numbers (`status.world.hook`, floor 1 around the arrival): mean 0.22 ms, max 4.7 ms per region, 873 placements over 648 regions, 0 failed. Cell plan about 1.6 ms for a fresh context.
- Not in P1 (by plan): lights are lantern voxels only (rooms are dark without the P2 torches; the pictures use temporary emitters), no props, no doors/gates, floor 3 (open air) and 4 are skipped by the hook, the borough courtyards are plain quarter rooms (the spiral is P3), the stairwell is a dais and a gold pillar.

## Big floors, P2 (the runtime: the game plays on them)
- **The world**: the real project is `world = endless`, `terrain = biomes`, one biome row (`biomes.csv`; the old flat config is `dev/flat.project.cfg`). The Orientation stays where it was (band 0, frame `OX, OZ = 1072, 848` voxels); floor n is the band z = (n * 32 + 2) * 512 voxels with the frame `OX = 0`; `Game.floorgen.frame(n)` sets `G.OX / G.OZ`, so every local-metre helper of the game works on any floor. `G.bigfloor` (true on a generated floor) switches `G.should_build()` off: voxels of a big floor are the region hook's only.
- **Run = world seed** (design M1 a): `tools/play.sh new [SEED|words]` deletes the save and starts the engine with `--seed`; the run screen shows `worldgen.seed` and says so; "Leave this run: new seed" shows the same hint. Floors of a run: 1 (Orientation = Floor 1), 2, 5, 6, 7, 8 (`G.run.FLOORS`; 3 is the open-air city of P4, 4 the transit floor of its own plan); after the last the end screen.
- **`game/gen/floor.lua`** (the cells): `F.enter(n)` (frame, plan `CG.plan(0, n)` = the hook's own pure code, tables of the world, the player into the arrival room behind the loading veil until its floor is generated), `F.load(n)` (a saved run: the same, the player wakes at the checkpoint after the veil), `F.tick` (every 5 ticks the cell of the player; cells within 1 come alive (two per tick: things, population, lights), cells beyond 2 go (`track.teardown` of their scope, `traps.drop_cell`, enemies despawned)), `F.sync_enemies` (the cell and its neighbours; at most 56 agents), `F.room_at` by cell index. Radius 1 / 2 instead of the plan's 2 / 3: nine cells of lights fit the engine's budget of 128 (`status.render.lights`: 17 authored in a typical spot) and the hook makes the cells ahead anyway.
- **Things of a cell** (`gen/themes.lua`, `themes_more.lua`, `safe.lua`): lights (sconce flames, lamps, a torch in the middle of every hall, torches along artery strips; `light.far` 24-30 m), the plan's population (`CG.population`: the budget by distance from the arrival, one mob theme per quadrant) placed with each theme's own `allow()` (it asks the same `deco_*_plan` functions the hook draws with), hazards (lava, toxic), chest buttons (`deco_crates` list = voxels in the hook, buttons here: opened chests carve the lid by edits), barrels, the safe room's crystal / vending machine, the free stairwell (an `events.volume` in the pit: entering it opens the recap, then the next floor), the arena's neighbourhood boss (a troll or cyclops with guards and a gold crate when the room is cleared). Wall plates of sconces and the chains of lamps are not built (flames only).
- **Decoration in the hook** (`gen/deco.lua`): every theme's old `voxels()` as pure global functions on a builder `B`; the plans (`deco_hall_plan`, `deco_crypt_plan`, ...) are shared with the things through `deco_rng` (a hashed counter, the same stream in the hook and the game).
- **Safe rooms**: the arrival and the quadrants' safe rooms are 20 x 20 (the 16 x 16 fixture set in the middle, mirrored by `deco_safe_plan`); the second safe place of a quadrant is a 12 x 12 rest stop (three cots, a fountain, a campfire; no vending machine, no crystal).
- **Map**: a window of 260 px around the player (`G.minimap_cells`): visited rooms, the halls between them, safe rooms and stairwells within two cells even in the fog.
- **Tools**: `tools/p2_playthrough.py [SEED] [class] [floors]` (a bot follows the plan path from the arrival to the nearest free stairwell, fights the rooms on the way, opens crates, takes the stairs; records and replays: floors 1 -> 2 -> 5 of seed 4242 replay to `8c812e38a980c39e`), `tools/p2_pictures.py` (HUD pictures + numbers), `tools/p1_validate.py` (flood per edge; now with the decoration: 0 problems over floors 1, 2 seeds 1-5), `tools/p1_walk.py`.
- **Numbers** (3 floors of seed 4242): agents at the end of a fight 15-32 (cap 56), cells alive 6-16, hook mean 0.9 ms / max 8.5 ms per region over 1263 regions (0 failed), 38,393 placements; an arrival floor needs 0.3 s behind the veil.
- **Not yet** (P3+): the lair template and the ringed borough boss with its stairwell, the three timer thresholds, the sign posts, bathroom doors, quest floors, floor 3 and 4. Neighbourhood bosses are minibosses (the Floor Manager is not placed on big floors).

## Big floors, P3 (lairs, the borough fortress, the floor clock)
- **Lairs** (`F.lair_of`, `F.STAGING` in `gen/floor.lua`, `boss.lua`): the arena behind its antechamber (a gold door frame and a red notice in the hook) holds the **neighbourhood boss** (the Floor Manager on floors 1-2, by hash Manager / Golden Parachute / Auditor from floor 3; hp x1.0 and +18 % per floor); the **borough boss** (hp x1.8) stands in the rotunda of the fortress. Each lair has its own flag `boss_dead_<id>` (`boss.lua` takes `lair.flag`; a boss whose room is dropped or despawned starts over when the player comes back; a dead one stays dead). A killed boss drops a gold (borough: platinum) crate; the borough boss also takes down the forcefield. Staging is data (`F.STAGING`: hp, crate tier, guards); bars that close behind the player, a versus card and the lights going out are not built.
- **The borough fortress** (`deco_borough_geom`, `deco_borough` in `gen/deco.lua`, hook-built, 64 x 64 m over the four quarter rooms of the courtyard): three walls (gaps S, N, S) with two ring corridors of 3.8 m between them, a roof over the rings, a gold gate frame and a red rug at the outer gap, the arena (21.6 m) with a gold ring in the floor and the stairwell pit (4 x 4 m) under a glowing `neon_red` slab, the forcefield. `F.make_ring` (made with the origin cell): torches in the rings, braziers in the arena, 4 ring guards + 4 arena guards (the ring has its own room id `r<bi>_<bj>`, `F.room_at` finds the arena first), the pit's `events.volume` (enters only when the boss's flag `ff_<ring>` is set; the slab is cleared by `F.ff_clear`, re-applied on every activation). The flood validator walks the whole courtyard in `strict` mode: every ring up to the arena is reachable, 0 problems.
- **The free stairwell** is the stairwell of the books: a round hole (3.3 m) with a lit rim and a wide stair (5 steps of 0.45 m) on its west side, 2.25 m down; the volume at the foot of the stair opens the recap.
- **The floor clock** (`F.timer_step`, `run.fclock`, runs only while the player plays; `F.FLOOR_TICKS` 108,000 = 30 min, `run.floor_ticks` overrides): **30 %** the stairwells open (until then a glowing slab over the pit, an edit that is re-applied from the state), **80 %** going down is free (before it: viewers -25 %, followers -5 %, and the contract "Stasis Fee" is forced into the next offer) and on floors 5+ the SERVICE stairwell (the second free one) opens, **95 %** the safe rooms close (the player inside is put out at a door), **100 %** the floor collapses: gold -30 %, health to at most half, teleported to the nearest stairwell and taken down after 4 s; under the hardcore contract the collapse kills. The clock is under the map (`1:13 stairs open (leaving now costs viewers)`).
- **Safe room rules**: enemies that walk into a safe room, rest stop, guild room or the arrival are taken away (`E.exile`) and come back at their place after 75-120 s (`E.tick_exiled`); sponsor boxes only in the safe rooms, not the rest stops. NOT built: the door that stays shut while an enemy is within 6 m.
- **Signs**: graffiti (hashed lines, voxel text on a wall of ~22 % of the rooms) and the block names at the corners of the arteries (`BLOCK A1`), written once as edits (`state.signs`); bathroom doors (a dark plate and a lit sign at the middle of ~30 % of the east / south halls, in the hook).
- **Fixes with it**: the enemy cap (`F.sync_enemies`: nearest first, a room only when all of it fits; `E.despawn_room` keeps what never spawned owed), the rest stop's cots go to a wall without a door, the prize room's chests sit on its dais, hall pillars keep clear of doors.
- **Tests**: `tools/p2_playthrough.py 4242 janitor 3 --borough` (the bot kills the borough boss of floor 1 in 2700 ticks, takes its stairwell, then floors 2 and 5 by the free ones; the replay hash of 19,594 ticks equals the recorded one); the clock stages by script (sealed pit -> 30 % open -> 70 % early flag -> 95 % ejected out of the arrival -> exile of a rat in the arrival -> 100 % collapse to floor 2). `tools/p3_pictures.py` makes the pictures in `~/share/big_floors_p3/`.
