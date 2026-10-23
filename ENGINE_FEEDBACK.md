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

## `events.on` several callbacks / `include_optional` / `gravity_target` in the check  — fixed in phase 1 
`include_optional("dev/boot.lua")` replaces the pcall(include); the dry run now passes `events.gravity_target` without my pcall (`--check-project`: 0 errors). Retested by hand: two `events.on(node, "pressed", ...)` on one button, one press: both ran (A = 1, B = 1). I kept my own `crate_hooks` table (it works).

## Textures: the CLI is fixed, the MCP server is not
`--check-project` and the headless CLI know `textures.json` now (no pcall needed there). But `voxelith --mcp --project projects/dungeon_crawler`: `texture_list` shows only the 16 built-ins (no `skull`, `rune_tile`, no `conveyor_on`), and with the pcall removed `on_start` stops at the first `edit.texture_box(..., "rune_tile")` ("unknown texture"), so the whole level is half built in an MCP session (and the running MCP server of this Claude Code session is still the old binary: `reload_level` of it answers with the old checker's errors). Same project in a windowed or headless CLI run: fine. I put the pcall around `edit.texture_box` back in game/core.lua for the MCP path only.
repro: `python3 -c "from voxelith_client import Voxelith; v = Voxelith(['--project', 'projects/dungeon_crawler']); print(len(v.tool('texture_list')['textures']))"` prints 16.

## The closed-room light at noon: no change seen
Launcher and .mcp.json no longer pass `--time 0.75`. MCP screenshots at the default (noon) time of the lobby, the Hall, the arena and the stairwell (`~/share/noon/*.png`) are still lit blue-grey all over, like the first test of this project (a closed room 8 m under the plain, no windows); the conveyor corridor, which has red lamps, looks the same as at night plus a blue fill. So rooms did not "become black unless lit". (In the windowed game without `--time` the lobby looked dark, so the clock there may start at another phase: I did not check which.) Torches and lamps still light their rooms, nothing got darker.

## Smaller things seen while retesting
- The bot's pictures still need `time_of_day: 0.75` to look right.
- `ui.input().actions` is a table keyed by name (documented), `held` was not tried.

# Phase 2 retest (engine update of 2026-10-23, second round)

Removed from the game: the `pcall` around `edit.texture_box` (game/core.lua), `--time 0.75` / `time_of_day=0.75` (play.sh, hudshot.sh, .mcp.json, playthrough.py; project.cfg has `time = 0.75` now), tools/hudshot.sh (deleted). Changed: every emitter light now normalises my colour to its largest part and passes `intensity = 11` (torch-like), as the new radiance scale needs.

## MCP + textures.json  — fixed in phase 2
`texture_list` in a fresh MCP session shows 22 entries (the 16 built-ins + my own incl. skull / rune_tile / gold_stars + the belt variants); the whole level builds with no pcall; the arena's skull floor and the lobby crystal's rune plinth are visible in the pictures.

## `status.game_mode`  — fixed in phase 2
`game_mode: true`, `save_read_only: false`.

## Closed rooms at noon and at midnight (~/share/phase2/*_noon.png, *_midnight.png)
At the default settle the pictures are lit properly now: at noon the rooms under stone are warm and dark with their own lamps (lobby, hall, conveyor, arena look right: no blue fill); at midnight (project.cfg `time = 0.75`, `sky.set{ time = 0.25 }` for the noon set) the same. `project.cfg time = 0.75` is applied from tick 0 in MCP and CLI. Two small observations: (1) the arena at noon has a pale hazy band at mid-height on the far wall and a faint bluish glow at the door at the right end of the conveyor corridor (the sky shows through the 2-voxel-thick shell where the corridor meets the plain's edge? I did not investigate); (2) with the new light scale my old values (radiance 1..2) became far too dim and the first guess after normalising (intensity 14) was washed out in the small rooms: the arena at midnight is almost uniformly orange with 8 pillar torches + a core campfire. The docs' "x14 torch" is right, it just surprised me that `reach = 14` gives so much fill in a room of 35 m.

## `screenshot {hud: true}`  — works; differences from my Xvfb grabs
Class select, bag, shop, the Hall with enemies, announcer, popups, minimap, crosshair: all drawn (`~/share/phase2/hud_*.png`, 960x540). Differences: (a) it is drawn at the picture's size, so my fixed pixel layout (1080 units high) scales down and text gets small (the announcer wraps at "Whichever of tho"... because the typewriter had not finished: same as live); (b) the typewriter and the "tick"-driven animations are frozen at the state of that tick, so a picture can show a half-typed sentence: a `settle`-like option for HUD time would help; (c) `ui.measure` widths seem right; (d) no mouse hover, as documented. Nothing was wrong that would not also be wrong in the live window. tools/hudshot.sh is retired; Xvfb + ffmpeg stays useful for keys (tools/xsend.py).

## Replay  — still exact
`tools/playthrough.py pyro` (22 rooms-worth of fights, the boss killed through `input_action`, shop, end screen): 19,733 ticks, `replayed ... session hash ff701e070979aa1f  == the recorded hash` (replay without --project).

# Phase 3 retest (engine update of 2026-10-23, third round: sound handles, player model)

Replaced in the game: the 2-second music chunks (tools/make_sounds.py `write_chunks`, the chunk scheduler of game/music.lua) by **one looping file per bed** with `sound.play{ file, loop = true, bus = "music", volume, fade_in = 2 }`; a bed change stops the old loop with a 2 s fade and starts the new one with a 2 s fade in; the fight layer is its own loop (fade in 0.6 s, out 2.5 s). The announcer's voice blips are 2D on the `voice` bus, sound effects without a position are 2D on `sfx`, positioned ones use `at`. The bag screen got a **Settings tab** (key O) with sliders for the three buses (`sound.bus`, saved in the run). The player has a **hero model** (third person, free-camera pictures) and a **sword in the hand** (first person) that swings with every attack: `player.model`, `player.hand_model`, `player.hand_play("swing")`, `player.model_play("attack")` called from `Player.attack()`.

## Sound handles, buses, 2D: works
Loops, fades, 2D and the buses behave as documented; `sound.bus` is accepted at start. (`sound.stop(h, 2)` of a handle that had already ended raised nothing: good.)

## `--audio-out` on a replay: found what I could not hear before  — works
`voxelith --replay /tmp/descent_playthrough.log --audio-out ~/share/phase3/playthrough_audio.wav` (tools/playthrough.py does it at the end): 328.9 s, stereo 48 kHz 16 bit, 63 MB, rendered in about the replay's own 15 s. Measured with a few lines of Python (no numpy here): peak 0.953, **0 clipped samples**, **0 silent seconds** (the music never drops out, also across all bed changes), DC -0.005, L/R rms 0.140 / 0.143 (balanced), no click larger than 0.57 full scale step. Level per 10 s: -13 to -20 dBFS rms. Things I saw and acted on: (1) the music beds sit 12-16 dB under the effects (about -20 dBFS rms against -9 for the level-up jingle and -11 for hits), so I raised the default music bus to 140 %; (2) the first second has a -62 dBFS pause and then a -9 dBFS burst (class pick: level-up chime + achievement jingle together), fine; (3) the biggest dB steps between half-second windows are at the boss's death roar (+12 dB at 289.5 s) and the end: expected. No glitches at the crossfades (a continuous -18..-20 dBFS series where the beds change). What I could not tell from numbers: whether the music *sounds* right (key, timbre, the loop seam of a 16 s file); the loop point is a hard wrap of a buffer that already wraps notes round the end, a seamless-loop check (cross-correlation at the seam) would be a nice tool.
idea: `--audio-out` could also write a per-bus stem (music / voice / sfx) so a mix can be checked per bus.

## Player model and hand model: works, two notes
Hero (13 parts, clips idle / walk / attack, generated by tools/make_dungeon_models.py): third-person walks with the clip following the player's speed, stands when still, the attack clip plays on `model_play`, the wooden mannequin with the yellow box is gone (`~/share/phase3/hero_*.png`). Sword in the hand (22 voxels long, an `idle` sway and a `swing` slash): seen in first person; a swing is a visible slash across the lower right of the view (`sword_swing_*.png`) and plays again on every attack. Notes: (1) `player.hand_model`'s `offset` is relative to the camera and the model is modelled pointing up, so the first guess ({0.3, -0.3, 0.55}, a 34 voxel sword) filled the view like a pillar: ended at {0.35, -0.05, 1.0} with a 22 voxel sword and a rest tilt in the idle clip; a "docs: a 1.4 m sword at 1 m forward looks like this" picture would save the guessing. (2) `player.model` raises "this session has no player models" in `--check-project`'s dry run (same kind of dry-run gap as gravity targets / textures before): I wrapped the calls in `pcall`. (3) The third-person camera at the lobby's west end (3.5 m from the wall) is pulled in so far that the camera is inside the hero's torso (a pink screen); `camera.set{ distance, lift }` clamps against walls but not against the player's own body.

## Arena at noon after a settle of 200
`~/share/phase3/arena_noon_settle200.png`: the pale horizontal band is still there: a lighter, slightly transparent-looking strip across the whole curved back wall at about mid-height (7-9 m), above the sign, with a darker wall above and below; the rest of the arena is lit right (warm braziers, no blue fill). It is not a glass voxel or a lamp of mine (the shell is dungeon_brick with the `blocks` texture; the sign is dark_wood). It looks like an artefact of the GI / sky occlusion at the top of the cylinder wall (the wall is 14 m high and its top row is the ceiling ring `G.pillar(CX, CZ, RAD + 0.25, 14, 14.4)`).

## Replay: still exact
`tools/playthrough.py pyro`: 19,733 ticks, `session hash 279c389efec672a7  == the recorded hash` (replay without --project, with the new hero, sword, loops and buses in the script).

# Phase 4 notes (follow-up build, 2026-10-23)

- `player.model` / `player.hand_model` / `model_play` / `hand_play`: no pcall needed any more; `--check-project` and the MCP session start clean. Fixed.
- Third person at the lobby wall (camera pulled closer than 0.9 m): `~/share/phase3/third_near_wall.png`, the body is no longer drawn, no pink screen. Fixed.
- Arena at noon (`~/share/arena_new.png` and my own settle 200 picture): the blue-grey fill is gone; the faint horizontal band stays and the curved back wall is mottled with soft blurry patches (low resolution GI on a curved surface). Acceptable for now: the game runs with `time = 0.75` (midnight, lit by its own torches), where the band is not visible. A lighting grid seam on a curved wall is a nice thing to fix later, not a blocker.

# Playtest feedback round (user, Moonlight session)

## `uikit.slots` reports `click` on the press AND on the release  (ui_kit.lua, also in the inventory sample)
kind: bug        severity: hurts
`if over and (i.clicked or i.released) then ev.click = ev.click or n end` in `K.slots`: a plain click gives `ev.click` in two frames (button down, button up). A game that uses it to equip or use an item does it twice: the user's "I changed my weapon and it switched back on mouse up" (the first equip swaps the old weapon into the bag, the second equips it again). The sample `inventory.hud` has the same shape (`evh.click` selects the hotbar slot twice: harmless there, but not in a game). Fix suggestion: `click` only on the release over the slot the press started on, with no drag (what the drag code already knows: `S.drag.moved`), and a separate `press` for the other meaning.
workaround: game/hud.lua reads `uikit.state.drag` and `input.released` itself.

## Doc / sample gap: nothing stops the player from walking while a full-screen menu is up
kind: missing        severity: annoying
`uikit.open_screen()` frees the pointer (so the view does not turn) but WASD still walks the player: a class-select screen at the start of the game can be walked away from. No `player.freeze(true)` / `input.block_movement`. workaround: teleport the player to where he stood every tick while the menu is up (game/world.lua), which works but is crude (physics, a vehicle, a moving platform would fight it).

## The mouse pointer starts free, the engine's OS cursor can be invisible, and a game cannot capture the pointer itself
kind: missing        severity: hurts (user report, Moonlight session)
In a windowed game the pointer is *free* at the start (`ui.input().free == true` in play, seen under Xvfb as well) and only a click in the window captures it for looking; after a menu closes it is free again. The user could not steer ("my mouse did not get caught") and, on the class screen, could not see a cursor until Esc. A game has no way to say "capture now" (`ui.cursor(true)` only asks for it to be FREE), and the OS cursor is not reliably visible when a script menu is up (Moonlight's absolute pointer). workaround: the HUD draws its own arrow at `ui.input().x, y` whenever `free`, and a banner "Click in the window to capture the mouse" in play while `free` (game/hud.lua). idea: `ui.cursor(false)` / `input.capture(true)` to ask for capture, and an engine-drawn cursor when a script screen has asked for the pointer.

## Pointer capture in game mode, the OS arrow, `ui.capture()`  — fixed in the build of 2026-10-23 (evening)
Retested with real XTEST input (tools/xdrive.py) in Xvfb with the game (`game = on`): the first click captured the pointer (`ui.input().captured = true`, `cursor_visible = false`), moving the mouse turned the view (forward vector 1.00 / 0.0 -> 0.98 / 0.20), the second click attacked (swings = 1), Esc released it and opened the game's settings (`captured = false`, one arrow). The game removed its own drawn cursor, closes menus with `ui.capture()` (the look takes the mouse back without an extra click) and shows a "click to capture" banner (with the Moonlight relative-mouse tip) while the pointer is free in play. Pictures: ~/share/feedback/capture_*.png.

## `fx.define` particle classes: which one does what is not in the Lua docs (found by experiment, `screenshot {settle: N}` steps the particle clock)
kind: unclear docs        severity: annoying
For floating damage numbers (game/vnum.lua) I tried every class with `count = 1, speed = 0, direction = {0,1,0}` at a point, 25 pictures: `spark` falls with gravity and lands (so numbers "float down"), `flame` rises and shrinks and is visible at size 1 (the right one), `puff` at 1 voxel is invisible (soft; wants size >= 3), `debris` and `grain` **settle into the world as real voxels** after resting (design.md "Settling": my sword-hit chips turned into little blocks on the floor that the player could stand on and that stay in the saved world). The Lua docs (LUA_API.md fx.define) list the classes (`debris, grain, spark, puff, flame, drop`) but not that two of them build voxels, that `spark` is affected by gravity, or that `flame` is the one that rises. Also: `fx.play` takes whole voxels (a sub-voxel pitch drops or doubles pixels), a particle's age counts rendered frames (in an MCP session a short effect is over before the next screenshot unless `settle` is used), and a first picture taken in the same call batch as the `fx.play` may not show it.
idea: a table of the classes (gravity? settles? collides? visible size) in docs/LUA_API.md, and a `settle = false` flag for debris.

## Voxel particles as text: no control over the size on screen and nothing that keeps a label readable
kind: missing        severity: annoying (user: "the particles are not good readable")
Damage numbers made of one `spark` particle per pixel (game/vnum.lua): at 1.7 voxels (10 cm) per particle and 11 cm between pixels the glyphs smear into blobs through bloom and the emissive material, and at a distance the pixel grid vanishes. Smaller particles (0.85 voxel) and a lower emission make them clearer but then they are tiny / hidden at 5 m. What is missing for "floating text in the world": (1) a billboard / text effect (`fx.text` or an emitter shape that is a lit quad with a texture), (2) a particle size in screen-space or a minimum size, (3) `emitter` / `fx` particles with a velocity that actually show up (see the entry above), (4) an emission control per effect (bloom is a property of the material's emissive intensity, so my numbers need four extra materials). The game offers "Damage numbers as flat text" in its settings as a fallback.

# Phase 5 notes (playtest round with the user, 2026-10-23)

## T (the orbit autopilot) still works in game mode and flies the camera out of the dungeon
kind: bug        severity: hurts (user pressed T for a game action and "got teleported")
Windowed under Xvfb, `game = on`, class chosen: pressing `t` starts "autopilot tour" (log: `autopilot tour: 779 m, 82 s per cycle`): the picture jumps to the demo's orbit camera (the sky, stars); the player's position does not change, the view does; `t` again returns. docs/INPUT.md "Game mode" lists M, F1..F10 and the number keys as off, but T is not in the list. Workaround: the game's mana key is X now. Please add T (and any other demo key, e.g. K demolish is an action and is off, but T / the tour is not) to the game-mode list.

## Door nodes keep their saved state when the world is rebuilt: a gate can be "open" while its bars stand in the corridor
kind: bug / unclear docs        severity: blocks the player
`.events/state.txt` stores `lobby_gate door 1 1 72 0` (open); when the world save is deleted and the level builds its voxels again (first run), the door adopts the saved state ("open") and the new bars are never moved: `events.command(door, "open")` does nothing because it is already open, `close` would move the missing slab. The player is walled in. Happened in the user's streamed session after test runs deleted `world.vxs` but not `.events` (an easy mistake that any author makes). The game replaced the event doors by plain voxel gates (`W.gate_apply`). idea: when a door's box does not contain what its saved state says (a slab of `material` / solids at the closed position), re-sync the state; or save the events state inside the world save so the two cannot get out of step.

## Request: smaller particles, finer positions, and a world-space label effect  (see also the entries on particle classes and text above)
kind: missing        severity: annoying (the game's damage numbers are held back by it)
- `fx.play(name, x, y, z)` takes whole voxels (1 voxel = 6.25 cm), `size` of a particle is in voxels and the smallest readable thing is one voxel: a 5 x 7 font is 44 cm tall, 3 x 5 is 31 cm (what the game uses: the user finds even that too big, "like the standard text" would be about 10 cm). Wanted: (1) `fx.play` with fractional voxel / metre positions (or `fx.play_at(name, xm, ym, zm)`), (2) particles smaller than a voxel (size 0.25 .. 0.5 that really render as 1/4 .. 1/2 voxel; the design says sparks are 1/4 voxel, the size key seems to be clamped), (3) a "billboard" particle or `fx.text{ text, pos, size, color, rise, life }` that draws a short string as lit pixels in world space facing the camera: damage numbers, pickup labels and "+1 gold" are the standard use and every game has them.
- Particle motion: `flame` rises, `spark` falls with gravity, `puff` of one voxel is invisible, `debris` / `grain` settle into the world; a class with a plain constant velocity and no gravity, no settling and no shrink (a "mote") would make floaty labels trivial.
- Ghosting: a moving 1-voxel particle with temporal anti-aliasing may leave a double image (the user saw numbers "split in two"): an option to exclude particles from TAA history, or a per-effect `taa = false`.

## No way to ask "is this voxel on fire"
kind: missing        severity: annoying
Fire hurts nobody in the engine; to make flames hurt enemies and the player the game reads `world.material_at` for `ember` / `flame` cells around the feet (ember is what a burning voxel shows). A `world.burning(x, y, z)` (or `fire.at(x, y, z)`) and an `on_fire(x, y, z)` event for the cells that catch fire would make this exact and cheap. Also: `fx.fire(x, y, z, r)` with r 28 voxels burned a whole 12 x 14 m carpet; the material column 24 `fire_spread` (3..10 for a carpet) is what keeps a fire to a patch: that column is documented in GUIDE.md "Materials" but not in LUA_API / the CSV header comment of `--dump-materials`.

## Phase 5 retest (build of 2026-10-23, late)
- `world.burning(x, y, z)`: used by the game now instead of the ember scan; an intern standing in a fireball's patch loses 5 to 6 HP every half second (44 -> 25 in 3 s), same numbers as before: fixed, thank you.
- T in game mode: the engine ignores it now; the game keeps X for mana anyway (a key a player presses by habit for something else is a bad mana key; changing back is a one-line change in input.cfg).
- Doors / `.events` without a world save: the log line is the right behaviour for the case that blocked the user; the saved-world mismatch stays open (docs/TASKS.md).
- Particles: not built, the request is in docs/TASKS.md. Priority from the game's side: `fx.text` first (it removes game/vnum.lua's pixel font and the one-voxel limit), fractional positions second.

# Phase 6 notes (fx.text, motes, particle_taa; build of 2026-10-23, evening)
- `fx.text` for the damage numbers: works. game/vnum.lua lost its font and its position arithmetic (down to about 40 lines); a number is `fx.text{ text, at, size = 0.11 (crits 0.17, boss 0.2, scaled up to 2.2x with the distance from the player), material = "dmg_plain" / "dmg_crit" / "dmg_fire" / "dmg_boss" (my emissive materials), rise = 0.7, life = 0.85, align = "center" }` and a ring of eight `fx.mote` pairs at the end of its life. Pictures in ~/share/feedback/ft_*.png (MCP, settle 3 .. 14): four numbers (137 gold, 412 purple, 58 white, 9 orange) at 3 to 6 m are legible, crisp, clearly smaller than before (about the height of the HUD's own text at that distance), coloured by the material, and rise and vanish with a small burst. The colour comes through the emissive materials well; a stronger glow for the white one would still be welcome but is a material setting.
- Stacking: numbers of the same target start one letter-height higher while the first is in the air (the game's own bookkeeping); `fx.text` itself does not avoid overlaps.
- `particle_taa = off` in project.cfg: accepted (no warning from --check-project). I cannot judge the double image from MCP pictures (they render a handful of frames, no history to ghost); the user will tell. 
- Not tried yet: `fx.mote` as a replacement for the sword-hit sparks, emitters with `kind = "mote"` for the torches; sub-voxel emitter particles for blood spray (the gore still uses 1-voxel debris on purpose).

## `edit.text`: the depth goes BEHIND the text plane, and there is no way to erase text
kind: unclear docs        severity: annoying
`edit.text(x, y, z, s, { facing = "+z", depth = 3 })` writes the letters on the layers z, z-1, z-2 (into the wall behind, the front layer at z): found by building a "T" in free air and reading the voxels; the docs (TEXT.md) say what `facing` means but not where the depth goes. For `facing = "-z"` my probe found nothing at the expected place (I did not chase it). To remove a sign from a saved world the game has to compute the letters' bounding box and fill it, because `edit.text` refuses `material = "air"` ("the letters need a material"). A `mode = "erase"` (or accepting "air") would make sign changes in saved worlds trivial. Also a sign longer than its wall silently continues through the side walls; a returned width (`edit.text` -> voxels used) would let a game check the fit (the game now has tools/check_signs.py that looks in front of every sign instead).

## Playtest round 4 (vent, red specks, damaged chest)
- **Presets that are really `spark` particles fall and lie around.** The emitter presets `magic_sparks`, `dust_motes`, `fireflies` and `embers` use the falling-spark class: with a floor below they pile up as glowing specks (a player reported "red glowing particles lying around" next to the braziers/embers). The preset names promise floating motes. Repro: `emitter.create{ preset = "embers", ... }` over a floor, wait 20 s. We now build our own `fx.mote` based emitters (`G.as_motes`, `G.embers`, `G.dust` in game/core.lua). Suggestion: say in docs/EMITTERS.md which presets fall/settle, or make those four mote-like.
- Chests: a tough material (`toughness 255`, not flammable) makes a chest survive a 1.5 m blast next to it with 97 % of its voxels; the default wood material did not. Nothing to fix in the engine, but a "props" material hint in docs/WEAR.md or MATERIALS would have saved the round trip.
- Gravity flip + tunnel: a flipped (up) field plus a corridor wall that was not opened made a one-way trap; a connectivity check tool (`world.reachable(a, b)`) would find such dead ends in authored levels.

## Phase 7 notes (walk-through voxels, docs/GORE.md)
Used in the game: `blood_stain`, `goo_stain`, `toxic_stain`, `bone_stain` (materials 96-99, `passable = 1`, `drag` 60/120/90/0), `fx.splat` per wound (r 0.7 m) and per death (1.8 m, miniboss 2.6, boss 3.6), the Janitor's mop cleans (swing at nothing: r 1.5 m in front, Mop Sweep: r 4.5 m) with `edit.sphere(..., "clear_if")` and pays 1 gold per remembered spot, achievement "Clean Sweep". Works: the splat is a believable spatter, the corpse of the Floor Manager lies in it, walking through is free, the bot playthrough replays to the same hash (`c011f021e4ed5871`).
- **`fx.splat` takes its position in world METRES, `fx.play` / `edit.*` take VOXELS.** docs/GORE.md only says "(metres)" next to the radius; I passed voxels first and nothing happened and no error was logged (the splat landed 1264 m away, out of the world). Repro: `fx.splat(floor(x*16), ..., 2.0, "blood_stain")` -> silently nothing. Please say "x, y, z in world metres" in the signature line, and log a warning when the point is outside the streamed world.
- **No count of what was cleaned.** `edit.sphere(..., "clear_if")` returns nothing, and there is no `world.count_material(x0..z1, name)` in Lua (the MCP has `count_voxels`). For a cleaning mechanic (pay per stain) I keep my own list of splats (`G.state.stains`) and pay per list entry. A return value (number of cells cleared) would make the payment exact and the list unnecessary.
- **Log size / replay time:** one `fx.splat` per wound is one logged edit: the 20 k tick bot run went from 3612 to 6860 recorded events and the replay from 14.5 s to 22.5 s. Fine here, but a stain-heavy game will feel it; maybe `fx.splat` could be a cosmetic (not recorded) edit like the settling particles, if stains do not matter for the simulation (they do slow the walk with `drag` > 0, so probably not).
- Colour: stains must be darker than the floor to read: blood of the particles (170,12,22) vanished on the red hall carpet; the stain material is darker (84,2,10, rough 18) and reads on stone and on carpet. A "wet -> dried" colour change over time (age based, darker after a minute) would be a nice option of the material.
- Not checked: `drag` (the walk speed through a stain), `world.top(.., true)`, fire burning stains, water washing them away, the `footsteps.csv` squelch rows (added `blood_stain` / `goo_stain` rows, no sound check possible without a speaker).
