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
