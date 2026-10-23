# Findings about the engine (written by the game's developer)
One entry per finding, newest last. Be exact: what you did, what you expected, what happened, how to reproduce it in a few lines (a script, a command, an MCP call), and how much it hurt.

```
## <short title>
kind: bug | missing | unclear docs | slow | idea        severity: blocks me | hurts | annoying | nice to have
what I tried:
expected:
happened:
repro:
workaround (if any):
```

## The Lua HUD cannot be seen through the documented tools
kind: missing        severity: hurts
what I tried: a level with `on_hud` drawing text and a bar; MCP `screenshot`, and `voxelith --headless --manual --script idle:200 --frames 200 --screenshot out.png` with `--hud 1`, `--hud 0 --ui`.
expected: CLAUDE.md says "look at your work: screenshot after every visible change"; a game's HUD (health, announcer text, inventory) is half of what the player sees, docs/HUD.md says "Not in MCP and headless runs (no picture)".
happened: the headless / MCP picture never contains `on_hud` drawing (`--hud 1` draws the debug text, `--ui` the tool panels, never the script's `ui.*`). A developer without a display has no way to look at the HUD.
repro: projects/dungeon_crawler/level.lua at commit "plan": `function on_hud() ui.text(600, 40, "HELLO", {size=40}) end`, run the headless command above: no "HELLO".
workaround: `Xvfb :95 &`, `DISPLAY=:95 voxelith --windowed --manual --project P --time 0.75 --script idle:900 &`, wait 9 s, `ffmpeg -f x11grab -video_size 1280x720 -i :95 -frames:v 1 out.png` (works, 13 fps with the GPU under Xvfb). Wrote tools/hudshot.sh for it. A `--screenshot` that includes the Lua HUD in headless mode (or an MCP `screenshot {hud: true}`) would fix it.

## docs/GUIDE.md names tools/xdrive.py, the package does not contain it
kind: unclear docs        severity: annoying
what I tried: "Testing the window without a screen: `Xvfb :95 &` then ... `DISPLAY=:95 tools/xdrive.py key e 0.3 key F5 0.3`".
happened: `tools/` has only voxelith_client.py, make_prefabs.py, make_creatures.py. There is no xdotool / libXtst on the machine either, so a windowed session can be looked at (ffmpeg x11grab) but not driven with keys or the mouse.
repro: `ls tools`.
workaround: HUD actions are plain global Lua functions that the tests call through the MCP `lua` tool.

## A headless CLI run writes the project's save file; the MCP server does not
kind: unclear docs        severity: annoying
what I tried: `voxelith --headless --manual --project projects/dungeon_crawler --script idle:200 --screenshot x.png` for a HUD test on a project with `save = world.vxs`.
happened: "saved 92 edited chunks to .../world.vxs" at exit, so the next start has `project.first_run() == false` and my level does not build. (MCP says it does not read or write the save unless `--save`; the CLI quietly does.) Easy to lose a morning to.
workaround: `rm projects/dungeon_crawler/world.vxs*` before every first-run test (the `.gen` folder next to it is a directory: `rm -rf`).

## `--dump-materials` writes `materials.csv` into the current directory
kind: unclear docs        severity: annoying
what I tried: `./voxelith --dump-materials` to read the built-in table (docs say "writes the table and prints where").
happened: it wrote `./materials.csv` in the repository root (the message names the path, but after the fact); easy to commit by accident. Only 24 built-in materials, `lantern` is only in the Lantern Cove's own table.

## No way to set the time of day (or fog / sky / ambient) from a project or from Lua
kind: missing        severity: hurts
what I tried: a dark dungeon carved into stone under a flat plain, 8 m under the surface.
expected: a closed stone room is dark, lit by torches.
happened: in the default daylight phase the whole closed room is lit blue-grey (sky ambient reaches probes under 7 m of stone); at night (`--time 0.75`, or the MCP screenshot's `time_of_day`) it is correctly black with the torch glow. The phase can only be given on the command line (`--time`) or per screenshot; the game cannot pick it, and no Lua / project.cfg key exists for the clock, the fog density or the ambient floor (only per biome with `terrain = biomes`).
repro: MCP `lua "edit.clear(1900,120,1900,2200,220,2200); player.teleport(128,7.6,128)"`, `screenshot` (blue room) vs `screenshot {time_of_day: 0.75}` (black).
workaround: the launcher script passes `--time 0.75`; `.mcp.json` too.

## Torch light needs about five seconds to show
kind: unclear docs        severity: annoying
what I tried: `emitter.create{name="t", preset="torch", pos=...}` and a screenshot 30 ticks later: a dim dot. After 330 more ticks the wall and floor are warmly lit.
expected: a light that is on is visible at once, or the docs say how long the GI needs (`gi_budget`).
happened: probes converge over several seconds; the preset's light is weak (reach?) until I gave `light = {color = {1, .55, .2}, reach = 14, flicker = true}`.

## The engine's sandbox keys cannot be turned off in a game: Z (undo) erases the dungeon, 1..8 teleport, Y rain, N / M clock
kind: missing        severity: blocks me (worked around with guards)
what I tried: a game project (`input.cfg` with dig / build / fly / explode / ... = none), played windowed (`--manual` or not: same). Pressed Z, Y and 1 in the running game (synthetic key events).
expected: a project can say "this is a game, not the sandbox": the editor / debug keys do nothing. docs/INPUT.md: "The editor and tool-panel keys that are not actions (F1..F12, the number keys, Z / X undo ...) are not remapped."
happened: Z undid my whole `on_start` build (it is one undo step: the lobby floor became stone, `world.material_at` says so); `1` teleported the player to the demo's spot 1 (the surface, outside the dungeon); Y switched rain on (particles inside the dungeon). A game cannot use the number keys for a hotbar (the inventory sample in docs/UI_KIT.md does: it would teleport the player).
repro: `projects/dungeon_crawler` at commit "HUD, input config...", `DISPLAY=:95 ./voxelith --windowed --project projects/dungeon_crawler`, `tools/xsend.py key z key 1`: the HUD (`dev/boot.lua`) prints `world.material_at(...)`: marble before, stone after.
workaround: game/world.lua `W.tick`: a hidden one-voxel edit every 0.75 s so that "the last action" is never the build (an undo shield), a sentinel voxel that rebuilds the dungeon if it was undone anyway, a teleport guard (player outside the dungeon bounds is put back), `fx.rain(false)` every 3 s. A `game = on` / `editor = off` key in project.cfg (or `input.cfg` entries for these keys) would remove all of this.

## LMB / RMB cannot be read from Lua in play mode (combat has to be on the keyboard)
kind: missing        severity: hurts
what I tried: `on_hud` reading `ui.input()` while the mouse looks around (pointer captured): `down`, `clicked`, `right_clicked`, `pressed`.
expected: some way to know "the player pressed the left button" for an attack; the engine's own `dig` action (LMB) is the only consumer.
happened: `down` / `clicked` / `right_clicked` are only reported while the pointer is free (docs/HUD.md says so: "nil while the look has the mouse"); `pressed` lists keys only. Keys work (`pressed.f`, `pressed.i` ... arrive in the frame they go down).
idea: custom actions in input.cfg (`attack = mouse:left, key:f`) readable as `input.action("attack")` in `ui.input()` and as an `on_action(name)` callback in the simulation, so that mouse and pad bindings work for game actions too.
workaround: attack = F, ability = Q / RMB-if-ever, quick items R / T / G.

## `include` of a file that does not exist prints a Lua exception line even inside pcall
kind: annoying        severity: nice to have
what I tried: `pcall(include, "dev/boot.lua")` as an optional scratch hook.
happened: "[sol2] An exception occurred: include: no such file ..." in the log (and in `--check-project` output); the pcall does catch it. A `include_optional` or `file_exists` would do.

## `events.on` keeps one callback per node: a second `events.on` on the same node and signal silently replaces the first
kind: unclear docs        severity: annoying
what I tried: a loot crate button with `events.on(node, "pressed", open_crate)` in the crate helper and, in the room file that owns the crate, a second `events.on(node, "pressed", start_flood)`.
expected: both run (or an error / warning that the node already has a callback).
happened: only the last one ran (the flood started, the crate never opened); no log line. docs/LUA_API.md: "a function called when the node sends the signal".
workaround: my own hook table (`Game.traps.crate_hooks`). The docs could say "one per node"; two would be easy with events.connect to a `Lua callback` node kind (docs/EVENTS.md lists it, but I found no Lua constructor for it).

## `--check-project` (and so MCP `reload_level`) does not know the project's own textures.json
kind: bug        severity: hurts
what I tried: `projects/dungeon_crawler/textures.json` with three pixel-art tiles (`{"textures": [{name, kind: "tile", pixels, palette}]}`, no ids: "a file without ids adds to the built-ins"), used by `edit.texture_box(..., "skull")` in `on_start`.
expected: the check's dry run (and the real run) knows "skull".
happened: the real engine run is fine (the file is read and rewritten with ids at exit), but `--check-project` fails the dry run with `unknown texture 'skull'`, and the MCP `reload_level` then answers "not reloaded, the project has errors", so the running session cannot be restarted until the script avoids the project's textures (or the check is satisfied). Also: the first guess at the file format (a bare JSON array) is a WARN, a file with ids replaces the built-in table (everything else becomes "unknown texture 'planks'"), and the format is only found in docs/TEXTURES.md prose (`{ "name": ..., "kind": "tile", "pixels": "00111100/...", "palette": [...] }`, 8 rows of 8 digits joined by `/`).
repro: any project with a textures.json that defines a name used in on_start; `./voxelith --check-project dir`.
workaround: `pcall(edit.texture_box, ...)` in my box helper.

## `--check-project` has no gravity system: `events.gravity_target` raises "this session has no gravity system"
kind: bug        severity: annoying
what I tried: a level that declares `events.gravity_target{ name, field = gravity.add{...} }` in `on_start`.
happened: `gravity.add` works in the dry run, `events.gravity_target` errors ("gravity_target 'x': this session has no gravity system") so the project "has errors" (and MCP `reload_level` refuses it). The real run is fine.
workaround: `pcall(events.gravity_target, ...)`.

## Two ways the dry run differs from the real run (textures, gravity targets) make `reload_level` unusable without workarounds
kind: unclear docs        severity: hurts
`reload_level` answers "not reloaded, the project has errors" with the check's report; an author who sees a green real run cannot restart it. Suggest: reload anyway with a warning when the failure is only in the dry run, or make the dry run use the project's textures and a gravity system.

## No non-positional sound: music is awkward
kind: missing        severity: hurts
`sound.play(file, x, y, z [, volume [, pitch]])` is positional (a sound stays where the player stood when it started, gain falls with distance), there is no stop / loop / volume change of a playing sound, and no "2D" / UI sound. Music and the announcer's voice have to be cut into 2-second pieces that are started one after another at the player's head (tools/make_sounds.py `write_chunks`, game/music.lua), so a track cannot change at once and a gap or click between pieces depends on the 60 Hz timer. idea: `sound.play{ file, loop = true, bus = "music", volume }` returning a handle with `stop` / `volume`, and a listener-relative flag.

## The player has no body in first person and the third-person figure is a debug mannequin
kind: missing        severity: nice to have
`camera.mode("third")` draws a wooden mannequin standing in the air with a yellow bounding box; there is no way to give the player a model (the rigged models and clips exist for agents). A game cannot show the hero or a weapon swing. idea: `player.model("models/hero.vxm")` driven by the walk rules, and a first-person "hands" model.

## Cosmetic emitter presets: the light of `dust_motes` did not light the room
kind: unclear docs        severity: annoying
`emitter.create{ preset = "dust_motes", light = { color = {...}, reach = 14 } }` as a hanging lamp's light left the hall as dark as before; the same `light` on `preset = "torch"` lights it. (I did not find out whether presets without a flame ignore `light`, or whether the speck particles are too few; the docs list `light` as a key of every emitter.)

## Unattached voxels fall as bodies without a warning: building props one voxel off a wall turns them into debris
kind: unclear docs        severity: annoying
Every prop that was a voxel away from its wall (sconces, sign letters, a crystal on a plinth) fell off at once as a loose body (the engine's connectivity analysis, docs/GUIDE.md "anchor" flags are only in the materials table docs). Easy to spot (`status` shows `bodies`), but the docs of `edit.*` / `edit.text` could say "voxels not connected to an anchor material fall".

## A recording of a level that uses `prefab.place` cannot be replayed
kind: bug        severity: hurts
what I tried: `tools/playthrough.py` records a whole session (`--record`) of THE DESCENT and replays it (`--replay`). The level places the kit's props (`prefab.place("models/props/crate.vxm", ...)`) and two manifest prefabs (`prefab.place("buildings/door", ...)`, `prefab.place("props/sign_board", ...)`).
expected: the replay ends with the recorded hash (it did, before the prefabs were added: `session hash ... == the recorded hash`, 23,693 ticks).
happened: `replay: ... not the one the session was recorded with`, preceded by `prefab.place: no prefab 'buildings/door' (there is no /home/claude/share/voxelith-clips/buildings/door.prefab.lua ...)` (the manifest is looked up in a folder that is not the clip's) and `prefab.place: /tmp/x.log.clip/prefab_1.vxm: cannot read` for the plain model form (the clip folder has prefab_10.vxm, prefab_11.vxm ... but the first one is not readable); on_start then stops and the hash differs. 
repro: any level with `prefab.place("models/props/crate.vxm", x, y, z)` in on_start, MCP `--record log`, one `step`, `voxelith --replay log`.
workaround: the test tools write `dev/flags.lua` (`Game.no_prefabs = true`) and the level skips its set dressing when recording; the replay is then exact.

# Phase 1 retest (engine update of 2026-10-23: game mode, input actions, replay and check fixes)

## Game mode (`game = on`)  — fixed in phase 1
Removed from the level: the undo shield, the sentinel, the teleport guard, `fx.rain(false)`, the `dig = none ...` lines of input.cfg. Windowed in Xvfb with synthetic key events (z, y, 1, n pressed): the player did not move (no teleport), the lobby floor stayed marble (no undo), no rain. F3 / F5 / F11 / 0 still work. Left: a small guard that puts the camera back to first person when the 0 key cycles into the free editor camera (a cheat view of the whole dungeon); a `camera = first, third` option for game mode would remove it.
Not fixed / unclear: MCP `status` has no `game_mode` key (docs say it reports it), with `game = on` in project.cfg and with `--game`; so I could not confirm the mode from the MCP side.

## Custom input actions  — fixed in phase 1 (mouse not confirmed)
`action.attack = mouse:left, key:f, pad:rt`, `action.ability = mouse:right, key:q, pad:x` and three quick-use actions in input.cfg; the level has `on_action(name, down, player)` and `input.down("attack")` (hold to keep swinging); the HUD's attack / ability / quick-key code is gone. Seen: pressing F in the windowed game fired `on_action("attack")` (swings = 1, `ui.input().actions.attack`); the MCP `input_action {name, down, player}` drives the same path: tools/playthrough.py now holds `attack` with it during fights and presses `ability`, and the pyromaniac bot killed the boss that way; the recording replays. Not confirmed: the real mouse buttons (synthetic X button events still do not reach the engine, so a click in Xvfb did nothing; keys do). A real mouse must be tried by a person.

## Replay of a level with `prefab.place` / manifest prefabs / rigged agents  — fixed in phase 1
Removed `Game.no_prefabs` and the `dev/flags.lua` dance. `tools/playthrough.py pyro` (class pick, the whole floor, the boss killed, the vending machine, the end screen) recorded 19,733 ticks with the closet door prefab, the sign board, the props and 17 kinds of agent; replayed with `voxelith --replay log --threads 3` (no `--project`): `session hash e3230cd343ca97e6 == the recorded hash`.

## `events.on` several callbacks / `include_optional` / `gravity_target` in the check  — fixed in phase 1 (not retested one by one)
`include_optional("dev/boot.lua")` replaces the pcall(include); the dry run now passes `events.gravity_target` without my pcall (`--check-project`: 0 errors). I kept my own `crate_hooks` table (it works); the several-callbacks change was not retested.

## Textures: the CLI is fixed, the MCP server is not
`--check-project` and the headless CLI know `textures.json` now (no pcall needed there). But `voxelith --mcp --project projects/dungeon_crawler`: `texture_list` shows only the 16 built-ins (no `skull`, `rune_tile`, no `conveyor_on`), and with the pcall removed `on_start` stops at the first `edit.texture_box(..., "rune_tile")` ("unknown texture"), so the whole level is half built in an MCP session (and the running MCP server of this Claude Code session is still the old binary: `reload_level` of it answers with the old checker's errors). Same project in a windowed or headless CLI run: fine. I put the pcall around `edit.texture_box` back in game/core.lua for the MCP path only.
repro: `python3 -c "from voxelith_client import Voxelith; v = Voxelith(['--project', 'projects/dungeon_crawler']); print(len(v.tool('texture_list')['textures']))"` prints 16.

## The closed-room light at noon: no change seen
Launcher and .mcp.json no longer pass `--time 0.75`. MCP screenshots at the default (noon) time of the lobby, the Hall, the arena and the stairwell (`~/share/noon/*.png`) are still lit blue-grey all over, like the first test of this project (a closed room 8 m under the plain, no windows); the conveyor corridor, which has red lamps, looks the same as at night plus a blue fill. So rooms did not "become black unless lit". (In the windowed game without `--time` the lobby looked dark, so the clock there may start at another phase: I did not check which.) Torches and lamps still light their rooms, nothing got darker.

## Smaller things seen while retesting
- The bot's pictures still need `time_of_day: 0.75` to look right.
- `ui.input().actions` is a table keyed by name (documented), `held` was not tried.
