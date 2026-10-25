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

## Phase 8 notes (fine voxels, figures, gore update)
- Gore update used: `edit.sphere(..., "clear_if")` now returns the cleared voxels; the mop pays 1 gold per 60 cleared voxels (`game/gore.lua`), no more guessing. Thanks. Not used: the cosmetic splat (`fx.splat(..., true)`), because the stains slow the walk (`drag`) and an unrecorded stain would desync a recording of a windowed session; for a game whose stains have `drag = 0` it is the right choice.
- Kit figures (`assets/prefabs/figures`) tried on a copy of the project (models/figures/): `model.spawn(file, x, y, z, 0, { visual = true })`, `agent.spawn{ model = ... }` and `player.model(...)` all work and look good (faces, straps, gear at 3.75 cm); `--check-project` lists the scale. Pictures: ~/share/gore/12_try.png, 14_player_walking.png.
- Missing for a game: (1) **no clips and no rig parts**: the figure stands in a T pose when the player walks (`player.model` accepts `{ idle, walk, attack }` but the file has none, `player.model_play('attack')` -> "the model has no clip 'attack'"), an agent slides over the floor in the T pose; a rest pose with the arms down (or an A pose) and idle/walk/attack/hit clips with parts head/torso/arm L/R/leg L/R are what makes them usable as the player and as enemies. (2) The figures cannot go limp (documented), so a death is a pose clip or a drop of the hidden box: a `die` clip (fall over) would replace the ragdoll. (3) `model.spawn` takes **voxels** (`G.wx`), `agent.spawn` takes **metres** and `fx.splat` metres: same family, three conventions. The first spawn with metres produced no model and no warning (a drawn-only model 1296 m... away; a log line "model.spawn: outside the loaded world" would have helped).
- Did not integrate the figures into the game: our own rigged `hero.vxm` has the clips the combat needs. They would replace it once the clips exist.

## Phase 9 notes (rigged figures)
Retest of the nine rigged kit figures: arms at the sides, 15 parts, idle/walk/attack/hit/die all play. `agent.spawn{ model, animation = "clip" }` walks with the walk clip (note: `animation = "walk"` is an error: "auto", "clip" or "procedural"), `model.play(mdl, "die", 1, false, 5)` leaves the orc lying on the floor, `player.model(...)` with idle/walk/attack works. Now used as the player's body per class (docs in GAME.md). Pictures: ~/share/gore/16_roster.png, 18_attack.png, 22_die.png, 24_janitor_swing.png. Playthrough replays to the same hash.
- Wish: `run` (a faster gait for the player's sprint), `block` and `cast` clips (the Pyro's Fire Bolt and the Bard's Power Chord could use a cast pose), and a way to tint/swap a material of a figure (all four player bodies share the same rig; a team colour per class would be a palette swap).
- Not tried: the monsters as enemies in the game (the existing enemies have their own clips with `spit`/`slam` events); the `hit` event of the `attack` clip with `on_anim`.

## Phase 10 notes (run / cast / block clips)
Retest on a copy: the four player bodies now play `cast` for the Pyro / Bard / Accountant abilities (`player.model_play("cast")` in `P.ability`, the Janitor's Mop Sweep plays `attack`); `run` is picked by the engine above 5 m/s without any option. Pictures ~/share/gore/25_pyro_idle.png, 26_pyro_cast.png. Both arms come up and push; idle arms hang from the shoulders at the hips now. Nothing in the log. Replay hash unchanged (`14e372d14e0f8b96`).
- `player.model_play('block')` right after `cast` did not change the picture (the cast was still playing: a one-shot with the same priority is not interrupted), so a guard needs `model.stop` first, or a priority argument on `player.model_play`: `player.model_play(clip, speed, priority)` would help (a block for a dodge/guard key).
- Not tried: palette swap (`swap = {...}`: I did not need it, the four classes already look different), the `cast` event in on_anim (the cast has no gameplay hook in our abilities: they fire at the key press; a delay to the 0.5 s event would feel more like a cast but make the Bard's stun late).

## Phase 11 notes (model_play hold; equipment wish list)
- Correction to Phase 10: `player.model_play` does replace the playing clip; the `block` I saw was the 0.25 s one-shot ending. `player.model_play(clip, speed, player, hold)` + `player.model_release()` is what a guard key needs (not used yet: the game has no block key).
- Equipment wish list (answer to the engine's question): slots = main hand (weapons: 11 in items.lua, from a mop to a spoon), head (hat/helmet, new), torso/back (armor pieces: cardboard, hi-vis vest, bathrobe, pauldrons, tux; a cape/robe as a spring chain), off hand (a lantern or shield, optional). Trinkets (duck, monocle, trophy) are stats only, but a monocle on the face and a duck on the shoulder would be nice. At most 4-5 attachments on one body (hand, head, back, shoulders); the same items on the player in third person and as the hand model in first person: ONE model file per item should serve both (the first-person hand model and the third-person hand socket take the same file). A Lua helper like `player.equip(slot, file | nil)` and `agent.equip(id, slot, file)`, a `hide_parts` list per item (a helmet hides the hair, a bathrobe hides the torso), and enemies carrying weapons (the Foreman with a clipboard, the goblin with a calculator). Items and stats stay in the game.

## Phase 12 notes (equipment)
Used: `equipment.apply` with main_hand (staff / sword / axe), shoulders (mirrored pauldrons), back (cape), head (hat / helmet); pictures ~/share/gore/30..35. Weapons, pauldrons, cape and hat show on all four class bodies, follow the attack clip, the log is clean, the replay hash is unchanged.
- **`--check-project` warns about the engine's own socket `head_top`** on every kit figure ("named like a body part ... name it grip_r, head_top, back"), although `head_top` is the name in docs/EQUIPMENT.md and the helper. The warning's text even lists it as a good name. False positive: the check seems to match the `head` prefix.
- The project copies of the figures have to be refreshed by hand (as warned): a `--check-project` note "figures/X.vxm differs from the kit's X (older: no sockets)" would catch it.
- Our weapons without a kit model (lute, firecracker) show nothing in the hand, and the mop is a wooden staff: the kit lacks a few tools (broom/mop, torch, lute, stapler). Not an engine problem; we may generate them with tools/make_prefabs.py later.
- The idle clip has to be set by the game when something is held (`ready`): `equipment.stance` exists but I bypassed it (the helper's state is reset after `player.model`, because `reapply` needs the old kit).
- Not tried: `torso` (replace slot), `off_hand` (shield), agents with `equipment.agent` (enemies carrying things).

## Phase 13 notes (mop, torch, lute, stapler in the kit)
All four look right on the four bodies (third person, ~/share/gore/40_*, 42_mop_side.png) and, through their `hand` block, in first person (41_*): the mop is big and bright on screen (about a third of the width), the torch's flame glows, fine.
- **`player.hand_model("mop.vxm")` does not resolve kit plain names** (`player.hand_model: .../projects/X/mop.vxm: cannot read`), while `model.attach` does (docs/EQUIPMENT.md: "a kit model by its plain name"). `equipment.apply` passes the same file to both, so a main_hand with `hand = true` fails for a kit name. Workaround: copy the files to `models/items/`. Please let `player.hand_model` resolve them too.
- The enemies' own models (intern, goblin_sales, ...) have no sockets, so the clipboard and calculator cannot be given to them without a rig edit (`model_rig_set { sockets }`): not tried.
- **First-person hand model of the new tools: no `swing` clip, and a replay mismatch.** With `hand = true` for mop/torch/lute/stapler the bot playthrough logged `player.hand_play: the model has no clip 'swing'` (the game plays `swing` on every attack, our own sword.vxm has it; the kit items have only the `hand` block), the run played differently from the one with our sword (more deaths, no boss kill, 3763 recorded events instead of 9986) AND **the recording did not replay to its hash** (`session hash 82ab5f4f75b3b4b4 != the recorded hash`, twice, reproducible: 17:56 and 17:57 runs). Going back to `models/sword.vxm` as the hand model (everything else unchanged: the same bodies and items on the body) replays to its hash again (`75bfb979542e5a6a`). The hand model is documented as render only, so a different hand model must not change the simulation, and a missing clip must not either. Please look at it: repro = `player.hand_model("models/items/mop.vxm", {})` (copy of the kit's mop) in on_start, then the bot playthrough (`tools/playthrough.py pyro`; `Game.player.attack()` calls `player.hand_play("swing")` every swing).
- Wish: a `swing` clip (and `idle`) on the kit's tools, like the sword's, so that the hand block is usable as it is. Until then first person keeps our sword for all weapons.

## Phase 14 retest
Visual-body id counter, generic item `swing`/`idle`, kit names in `player.hand_model`: all verified. The mop/torch/lute/stapler are the first-person hand models now (kit names, no copies), `swing` works without a warning, and the bot playthrough replays to its hash with them: new baseline `437bfd517be4a9e9` (the old baselines are void after the update, as announced). Picture ~/share/gore/44_lute_first_swing.png. (The earlier mismatch may also have come from the erroring `hand_play` aborting the rest of `P.attack`; it was deterministic script behaviour but changed the run.)

## Phase 15 notes (a seeded procedural dungeon in one volume)
Built on the engine as it is: all floors share the old floor's volume; generator, teardown, wipe, a flood-fill validator and a recorded multi-floor bot (replay hash equal over 4 floors). What was in the way or surprising:
- **An edit reaches at most 640 voxels radius (40 m) and 16384 per axis**: `edit refused: a 3151 voxels radius / extent is beyond the limits (640 radius, 16384 per axis)` is only a *warning in the log*, the Lua call returns normally and nothing happens. A wipe of the dungeon volume (134 x 162 m) has to be tiled. A return value (false, or an error) would have saved a debugging round. Large uniform fills are slowish: 60 x 60 m x 14 m stone box = 1.5 s, the whole volume ~12 s: a `world.reset_region(box)` (drop the chunks back to the generator's terrain) would be instant and also shrink the append-only save.
- **`world.vxs` is an append-only log**: every floor that is wiped and rebuilt adds its edits (several MB); there is no compaction from a script. A `world.compact()` / "save with the current chunks only" action would make roguelike worlds practical.
- **`project.store` is saved with the world** (good: state and voxels are consistent after a restart). But the MCP's `save_world` only works when the server was started with `--save FILE` (answer: "saved in memory only"): `.mcp.json` should pass `--save` if the project has `save = ...` in project.cfg, or the tool should use the project's save.
- **No date / entropy for a "daily seed" or a random seed**: there is no `os`, no clock. I used the tick and the mouse position at the click (logged, so replays agree). A HUD-only `ui.date()` (not part of the simulation, passed into `ui.run(...)` as an argument) would give a daily seed without breaking determinism.
- **Unloaded chunks**: `world.top / blocks / material_at` return `unloaded` / nil beyond ~144 m from the player. A generator that edits the whole dungeon at once edits far chunks that load later (works: "deferred_edit_chunks"), but a script that wants to *read* the floor (my validator, the placement of enemies) has to bring the player to the middle first. A `world.preload(box)` for scripts would help.
- **Tracking what a script made**: there is no "give me everything my script created" (events, emitters, gravity fields, bodies, vehicles, prefabs): I wrapped the constructors to remember ids per floor. A `scope` / `session` for these (remove all at once) would be a small engine feature; `events.remove` of a node with `events.on` handlers: handlers seem to go with it, not verified against leaks.
- Kit figures as agents: `agent.spawn{ model = "models/figures/x.vxm", animation = "clip" }` + `equipment.apply(equipment.agent(id), ...)` works for 10+ enemies in a room; idle shows the rest pose, `die` holds the last pose (the body lies there until removed). Elites (speed) via `agent.speed`. No frame-time counter in `status` (only `seconds`, bodies...): I could not measure the cost of 30 figures in view; a `frame_ms` / `gpu_ms` in `status` would make perf findings possible.
- `G.hash` (and any `~ >>` operator) errors on non-integer floats: "number has no integer representation" is a *warning in the log* and the handler is aborted: easy to hit when positions are floats. (Lua 5.4 semantics, but worth a note in docs/LUA_API.md next to the determinism notes.)
- The doc of `world.top(x, z, fromY, true)`: it returns the voxel y of the highest solid at or below `fromY` (not y+1); a stain is skipped with the 4th argument. Not obvious from the table row.

## Phase 16 notes (what else the seeded dungeon met)
- `uikit.text_input(..., { filter = P })`: `filter` is a Lua pattern of characters to REMOVE (`typed:gsub(filter, "")`), not a pattern of what to keep; docs/UI_KIT.md says only `{hint, max, filter}`. I wrote `filter = "digits"` first (it removes the word "digits"). One sentence in the docs ("a Lua pattern; what matches is removed, e.g. `%D` keeps digits only").
- `G.hash`-style integer mixing (`~`, `>>`) on a float errors with a *warning* ("number has no integer representation") and aborts the handler: my sponsor boxes had float positions in a hash. A hint in docs/LUA_API.md ("use math.floor before bit operations") would have saved the round.
- Agents with kit figures (`animation = "clip"`) + `equipment.apply(equipment.agent(id), ...)` + `model.play(mdl, "die", 1, false, 6)`: all fine. `agent.speed(id, v)` takes effect on the next move. The kit figures' `cast` event on `cast` is used by our imps for a projectile; `attack`'s `hit` event does the melee damage. No ragdoll, so a corpse stays as the last `die` pose until removed: good enough.
- `world.top(x, z, fromY, true)` as the "floor finder" for a flood fill works and is cheap enough (50 000 columns in about a second of Lua), `world.blocks` for headroom. A built-in `nav.reachable(a, b)` / `nav.flood(from, box)` would make "can this procedural level be walked?" a one-liner (the agents' navmesh already knows).
- `edit.*` inside `on_tick` slices (one slice per tick) is replayed exactly: a 48 000-tick recording with 5 generated floors (each ~25 000 edits) replayed to the same hash (18 minutes of play in 90 s). 
- Floor teardown: `events.remove(id)` + `emitter.remove(name)` + `gravity.remove(id)` + `body.remove(id)` + `vehicle.remove(id)` + `prefab.remove(id)` through wrapped constructors worked; no leaks seen in `status.sim.events.nodes` (45 nodes per floor, stable over 8 floors in the soak run).
- Daily seed again: the one thing the player expects from a seeded roguelike ("today's dungeon") cannot be built: no date in the engine, not even in the HUD. `ui.date()` returning `{year, month, day}` (HUD-only, to be passed through `ui.run` as an argument) would fix it without touching determinism.

## Phase 17: merged items on agents break replays
Found with the bot (`tools/gen_playthrough.py`, seed 99, 2 floors, janitor): live run hash `a7d2c66a793c92dc`, replay of its own recording `ca3b55f166f3d579` (every time; the live run is reproducible run to run, the replay too, they just differ). Bisected by code (a boss hp factor changed the course of the fight, so the problem only showed in some runs) and then by feature: with `T.kit = nil` for every enemy type (no equipment on the kit-figure enemies) live and replay agree, with the weapons attached as `equipment.apply(equipment.agent(id), { main_hand = ... })` (merge mode) they do not, with `model.attach(id, file, socket, { mode = "attach" })` (the item as a model of its own) they agree again. docs/EQUIPMENT.md says items are in no hash; for a *proxy agent* a merged item changes the part's body and with it, apparently, the agent's hidden collision box, which is used by the simulation (the proxy "stands in nav as the figure's body does"). Why live and replay differ then is not clear to me (the box should be the same in both); the evidence is that it matters whether the item is merged. Suggestion: the hidden box of a proxy agent should come from the model file's rest pose WITHOUT items (so items are really render-only), or the docs should say that merging into an agent's model changes the agent. Repro: `cd /mnt/data/projects/dungeon-crawler && git stash; git checkout 6d9827f && GEN_PROJECT=projects/dungeon_crawler python3 tools/gen_playthrough.py 99 janitor 2` (needs the bot's options; at HEAD the enemy weapons are attached, not merged).

### Phase 17, probe results (hash probes every 300 ticks, 6 floors of seed 99, threads 3)
With `VX_HASHEVERY=300 VX_HASHCHEAP=1` live and replay agreed at the end (`5cc5fa1d77f213b1`); without the probes the same run mismatched every time. Across 218 probes only two things differed: the player position (9 probes, transient, e.g. y 7.97275 vs 7.95913 at t=7800, and 8.10000 vs 8.09728 at t=0) and the `edited` hash for t=39900..41400 (then equal again). `phys`, `drops`, `vapor`, `fire`, `grav`, `stream`, `deferred`, `liquid` never differed. The reviewer session's reading: the edit path depends on chunk residency (an edit on a chunk that is loaded in one run and still streaming in the other is applied now versus deferred), also visible in the t=0 player y. Next step for whoever continues: `VX_HASHEVERY=30` around t=39900 plus the chunk load log; files were `/tmp/live_probe.txt`, `/tmp/replay_probe.txt`, `/tmp/probe_run.log` (temporary).

## Phase 18: big floors by the region hook (P0/P1): what worked, what was missing
Setup: a copy of the game with `world = endless`, `terrain = biomes`, a one-row biome table (grass/dirt, base 400, amplitude 0) and `on_region` building one 32 m cell per region (a brick mass over the whole cell, then clears for rooms, halls, artery strips; `hook_globals = { "cellgen_make", "cellgen_hash_from", "shell_region" }`).
- **Worked on the first try**: the one-row table makes the old Orientation save load unchanged (region hashes of the Orientation equal to the flat project, 4 x 200 x 120 x 200 voxels); `hook_globals` with functions from an `include`d file; list-order placements (E1b) with a box carved by clears of the same region; `flood_region {source: "generated"}` over a pair of cells in 0.1 s (a 64 x 32 m box with the whole shell, no player); `status.world.hook` (mean 0.22 ms, max 4.7 ms per region over 648 regions, 873 placements, failed 0) is exactly the number a hook author needs; a walk of 16-22 waypoints on foot (agent + the player carried along so the world streams) from the arrival to a free stairwell, 77-108 s of game time.
- ## `--seed` on the command line does not override the project's `seed =`
kind: unclear docs        severity: annoying
what I tried: `voxelith --mcp --project projects/dc_p1 --seed 7` and `--seed 8`, then `worldgen.hash(1, 2, 3)` in the level script.
expected: the world seed from the command line (docs/MCP.md and `--help` list `--seed S`), so a validator can run 10 world seeds without editing files.
happened: the same value for both (the project's `seed = 4471902` wins); `worldgen.seed` is `nil` in the level script (the hook has it, docs/WORLD_GEN.md).
workaround: rewrite the `seed =` line of project.cfg before each launch (tools/p1_validate.py). A `--seed` that wins over project.cfg, and `worldgen.seed` in the script, would make it a one-liner.
- ## flood_region: the limit is 4096 columns of 64 x 64 voxels (a 256 m square), a whole big floor needs several calls
kind: unclear docs        severity: nice to have
Floor 1 is 256 x 512 m. A per-edge flood (two cells with 4.5 m trimmed off every side that touches an artery strip) answers "does the shell realise the plan's edge?" and costs 0.1 s per call, 170 calls per floor; an island list that names the plan's own artery strips as islands was the only noise (an island's `min`/`max` is its bounding box, an L-shaped artery corner covers a room-sized rectangle, so a bounds test cannot tell it from a room: I trim the box instead). If `islands` carried a `standable-cells-in-box-of-material` filter, or `flood_region` accepted a list of `ignore` boxes, the trimming would not be needed.
- ## Hook regions need `min_h`: placements are limited to 192 voxels beyond the region; a 32 m cell = one region fits, but a hall that jogs past the border needs the neighbour's region
kind: idea        severity: nice to have
My workaround is that each cell carves its OWN half of every shared hall and jog (both cells compute both door positions), so no placement crosses a region border and the order between regions does not matter. It works (0 problems over 10 seeds x 167 edges); worth saying in docs/WORLD_GEN.md as the recommended pattern: "build everything of a region inside the region, let the neighbour build its half".

## Phase 19: big floors at runtime (P2)
- **Worked**: the floors are only the region hook's now (about 38,000 placements for three floors, mean 0.9 ms / max 8.5 ms per region, 0 failed); a recording of three floors (24,280 ticks, bot) replays to the recorded hash; a saved run resumes in its band (`worldgen.seed` from the save's sidecar, `--seed` only for a new world); `status.render.lights` shows authored / drawn / cut and the light budget is enough for nine cells around the player (17 authored lights in a typical spot because of `light.far`).
- ## `status.render.lights` and `cpu_ms / gpu_ms` are zero until a picture has been rendered
kind: unclear docs        severity: nice to have
what I tried: `status` after 200 ticks of a floor with ~100 emitter lights; expected `authored` > 0. happened: `{"authored": 0, ...}` and `gpu_ms 0`; after one `screenshot` the same call said `authored 17, probe_lights 17, gpu_ms 4.6`. A one-line note in docs/MCP.md ("render numbers are those of the last rendered frame: take a screenshot first") would do.
- ## A player that is teleported (or resumed) into a region the hook has not generated yet ends up inside the rock
kind: unclear docs        severity: annoying
what I tried: `player.teleport` to a checkpoint on a hook floor in `on_start` of a saved run. happened: the player stood at y 6.6 inside the brick mass (the plain was there when the teleport happened, the hook's floor came after the world was made again). workaround: a loading veil that holds the player (`player.teleport` every tick) until `world.material_at` of the floor under the target is not `unloaded` and not `air`, then teleports. A `world.preload(box)` / "teleport waits for its chunks" option would remove the veil logic.
- ## `save_world` needs `--save FILE` even when the project has `save = world.vxs`
kind: unclear docs        severity: annoying. `saved in memory only (no --save file / project save)` for a project whose project.cfg names a save file; the MCP server did not take it from there. workaround: pass `--save projects/X/world.vxs`.
- Observation: `status.sim.bodies` was 191 awake bodies on a floor with about 15 cells alive (loot, gore and the floating orbs): not a problem yet, worth watching in P5.

## Phase 20: a stale clip folder makes a replay start from the wrong state (RETRACTS the first version of this entry: it blamed `edit.text`)
kind: bug (recorder) / unclear docs        severity: hurts
what I tried: the same bot recording (`tools/p2_playthrough.py 4242 janitor 3 --borough`, `--record /tmp/descent_big_4242.log`) many times in a row, replaying each.
happened: replays differed from their live runs on some runs and not on others (live 4d5fa8dc601c5f96 vs replay 7049d73de07e2a39; after that a replay that did not even start: `on_start failed ... player.attach: the model has no part or socket 'grip_r'` and `replay: the level script ... is not the one the session was recorded with`). I first blamed `edit.text` at run time (switching it off helped); that was a coincidence of the order of runs. Cause: `--record LOG` writes into `LOG.clip/` and does NOT clear an existing folder; `store_0.json` (the persisted game state at the start of the recording) is written only when the store is not empty at the start, so a fresh-state run keeps the `store_0.json` of an earlier run in the same folder, and the replay starts from THAT state (with a class: `setup_player_models` then runs in `on_start` at tick 0). A run that starts with a store gets its own `store_0.json` and replays fine. The same applies to every other file of the clip (prefabs, events).
expected: a recording folder holds exactly the files of its recording (the recorder removes the old ones), or a replay refuses a clip with files that are not from the recording.
workaround: remove `LOG` and `LOG.clip` before `--record` (tools/p2_playthrough.py does now). With it: commit 9665969 (graffiti and plaza signs written by `edit.text` at run time) on a fresh state replays to its hash (live 942aa1cb0dde002d, 19,715 ticks, the same on the builder's machine), so `edit.text` is NOT the cause. The Phase 17 mismatches ("6 floors of seed 99") used the same clip name for every run (`/tmp/descent_gen_99.log`) and may have been this too.
Also seen: the live hash depends on the project's persisted store (`.state/store.json`, rewritten at the end of every run): the same code gave 942aa1cb0dde002d (fresh), 7ce44779f7026fee and b70efb6cfd97c4f7 (store left by earlier runs). That is expected, but a replay needs the store of the START: `store_0.json` does that when it is there.

## Phase 21: a player placed inside solid voxels falls through the world, and differently in a replay
kind: bug (determinism)        severity: hurts (found by the soak: 1 of 5 recordings did not replay)
what I tried: `player.teleport(x, 8.1, z, { wait = true })` into a spot that is inside a bookshelf (solid dark wood from voxel 128 to 179; the column below is the native stone of the plain).
happened: the player is not pushed out: it falls straight down THROUGH the shelf, the floor layer, the brick mass and the native stone to y = 0.0625 (the bottom of the world), 19 ticks of free fall. In a recording the fall differs between the live run and its replay by a fraction of a voxel (live y 7.90738 / 6.63009 / 4.26280 / 0.80551, replay 7.86941 / 6.53761 / 4.11582 / 0.60403 at ticks 3820 .. 3880 of `tools/p2_playthrough.py 12345 janitor 6`), which is the whole difference of that recording (hash probes every 20 ticks: every other category equal until then). Not a game bug (a player cannot walk into a shelf), but an input the engine should either refuse (teleport refuses a spot inside solid voxels, or lifts the player to the nearest free spot, deterministically) or integrate the same way in both runs.
repro: floor 1 of seed 12345 (`--seed 12345`), `Game.run.start(0, true)`, `player.teleport(56.5, 8.1, 1294, {wait = true})`, then `player.teleport(45.5, 8.1, 1291.87, {wait = true})`: the player is at y 0.0625 100 ticks later. The bot now checks `world.solid` at the target before it teleports.
Soak of five seeds x 6 floors (P5, table in ~/share/big_floors_p5/soak.md): all five replay to their hashes after that fix; the only engine log line was `fx.splat: the point (18.5, 8.15, 5610) m is not in the loaded world` (a death far from the player: harmless).

## Phase 22: a new run in one session (P5b test on 79095c1)
kind: unclear docs / slow        severity: annoying
what I tried: `tools/p5b_runs.py`: run 1 (floor 1 played, floor 2 entered), then `world.reset_region` of the eight bands + `worldgen.run_seed(2)` in one tick, the new floor built, compared with a fresh session of run 2.
worked: the bands hash as empty right after the reset, the new floor's voxels equal a fresh start's (15 boxes), the replay of the whole session equals the live hash. The order fix of cc78cc5 holds.
- **The save grows by about 2 MB per run until a compaction**: 3.35 -> 5.37 -> 7.38 -> 3.31 MB (seed 7: 5.24 -> 7.26 -> 3.35 -> 5.35). Bounded, but the reset's dead chunks stay in the file for two runs. Would a `reset_region` rewrite the records at once? (not a problem for a player: a run is 30+ minutes.)
- **`region_hash` is limited to 8,000,000 cells**, a floor band is 10752 x 700 x 9728: a regression test of a whole band needs ~10,000 calls. A `region_hash` over the chunks that EXIST (a sparse hash) would make "this band is empty / equal" one call.
- **A `save_world` after the last tick is not replayed** (the recording ends at the last tick, the recorded end hash comes after the save): a recording whose last action is `save_world` shows `!= the recorded hash`. Not an engine bug, but it looks like a determinism failure; a note in docs/MCP.md (or the replay ignoring a trailing `save`) would save the next developer an hour. The test steps 5 ticks after its last save now.
- **Unclear, not chased**: in one flow, screenshots taken while the loading screen was up (hud on) were followed by `Game.screen == nil` at tick +110 instead of "class" at +150; without the screenshots (same calls otherwise) the screen is "loading" until +150. A screenshot with `hud=True` settles ticks; I could not tell whether it touches the game's screen. Pictures during a veil are test-only, so no player is hurt.

## Phase 23: replays of boroughs: three things that break them (binary a17ab8a)
kind: bug (determinism, unclear)        severity: hurts
what I tried: `tools/p2_playthrough.py SEED janitor 1 --first-floor 2 --borough --borough-floor 2` (the bot teleports into the borough, kills its boss, takes the stairwell; recorded and replayed).
happened: (1) **on the committed code f004e04 (no moving walls) seeds 4242 and 12345 replay to another hash, seeds 7 and 99 replay equal**: live 20ab273b8dd618e6 vs replay c69c140341f8dd9a (4242, 6068 ticks); the probes (VX_HASHEVERY=20 VX_HASHCHEAP=1) agree until tick 4960, where only `phys` differs, later `edited`. Log, clip and both probe files: ~/share/replay_break_borough2/ (the live probe is the file base_live.txt).
(2) A change that made the borough's guards spawn 120 or 300 ticks after their cell (instead of at once) gave `replay: the file read as number 403 is monster_troll_blue.vxm, the recording read honk.vxm there ... the session did not start the way it was recorded`, although my own debug prints of the spawn ticks (make_cell, spawn_room, the goose's spawn every 10 ticks) were identical in the live and the replay log. The order of file reads in the recording is therefore not a function of the script's ticks alone.
(3) A script that removes an agent which has fallen below the floor (`agent.remove` when `agent.info().y` is 6 m under the floor, every 10 ticks) broke the replay of the floor-1 borough (live 36bb7d5913940d36 vs replay 9465f8dec4109f4e); the removal ticks and ids were identical in both logs (86 debug lines, diff empty), the first `phys` difference came 3,000 ticks later. Without the sweep the same run replays equal (888a76fb92b4cc9c).
cause (my guess only): agents / bodies that fall through ground the hook has not made yet; their fall (and the ragdoll body that stays when the engine removed the agent at the bottom) seems to be sensitive to how fast the chunk threads were.
workaround: both script-side fixes are off (`F.GROUND_TICKS = 0`, `F.SWEEP = false`); a player who walks never spawns enemies on missing ground, only teleports do.
Also: a ragdoll body whose agent the engine already removed at the world bottom stays for ever (id below the world, 25 m/s), 13 of them after one borough fight; `bodies` is MCP-only (no Lua list), so a script cannot find and remove them.

**Phase 23 CLOSED (2026-10-24, binary 7026177 / 244a755):** the cause was the recorder (a script `player.teleport` in on_tick settled a step later in the live run than in the replay), fixed by the builder (E14). On the new binary the floor-2 borough repro replays equal for seeds 4242, 12345, 7, 99 (and the floor-1 borough, the park, the plain 3-floor bot), and so do the two script-side changes that broke it before: a 120-tick delay before spawning a cell's enemies and a sweep that removes agents below the floor. The game keeps the rule the reviewer asked for: enemies of a room are spawned when `world.material_at` under every entry is neither air nor unknown (`F.ground_ready`); the delay in ticks is gone, the sweep (`F.SWEEP`) stays off because the engine now removes bodies and models below -64 m itself. 0 bodies below the world after a borough fight now (13 before).

## Phase 24: ground cover does not draw on the floors of carved rooms (binary 07ea9f3)
kind: unclear docs / missing        severity: nice to have
what I tried: a `foliage.csv` with types on `flagstone;cobble` (density 0.7 for the test), `cavestone;mossy` (moss) and the built-in `grass`; `foliage_list` says 3 types, no problems. A hall of floor 1 (flagstone floor at y = 8 m, 6 m of air, 14 m of dungeon brick above it, the camera inside the room 2 m from the floor), `screenshot` and `foliage_shot {name = "crack" | "grass", eye, target, size = 6, full_density = true}`.
expected: tufts on the floor (docs/FOLIAGE.md: "Caves: a second ray goes straight down from the camera's own height, for cells within 20 m, if the cell is open there").
happened: no blade at all, not even the built-in `grass` in `foliage_shot`; `world.material_at` under the target is `flagstone`.
repro: `tools/p6d_pictures.py 4242 --themes hall --tag coverT_` with `crack`'s density at 0.7 (projects/dungeon_crawler/foliage.csv), or the foliage_shot call above after teleporting to room c3_3 of floor 1.
workaround: none; the rows stay in foliage.csv (0.05 density) and will show when the engine draws them. If the cover only works for the first surface under open sky or a cave found by the world generator, a line in docs/FOLIAGE.md would say so.

Other small things met in P6d: a Lua call (`lua` tool) has an instruction limit per call that a plan check with the layouts hit at 4 seeds (one seed a call now); the hook state keeps globals between regions (tables memoised in a global are fine: `deco_catalogue_memo`); `model` ops need `hook_models` (the warning says so, good); the kit's materials are merged into every project's table by the engine (no copying needed).

## Phase 25: an agent that falls to the bottom of the world leaves its body behind (binary 168a8d7)
kind: bug        severity: annoying (a few thousand kg of kinematic body for ever, the cause of the "13 falling guards" of Phase 23)
what I tried: `Game.enemies.spawn('orc', 0, -6, 0, { room = 'c0_0' })` = an agent spawned 6 m under the floor, inside solid rock (the Blue station crowd of floor 4 did the same by mistake: its spawn height was the level 0 floor, the room is at +8 m); 240 ticks later; then `agent.remove(id)`.
happened: after the fall `agent.info(id)` is nil (the agent system has forgotten the agent: y about -23.9, the bottom of the world), `agent.remove(id)` does nothing, and the agent's BODY (7,128 voxels, kinematic, owner "agent" in `body.list()`) stays at y = -23.8 for ever; the engine's rule removes bodies below -64 m only. `bodies` still lists it after any number of floors.
expected: the agent's body goes with the agent when the agent system drops it (or `agent.remove` of a gone id removes the body of that id).
repro: a session with the project, `lua`: `local E = Game.enemies; local i = E.spawn('orc', 0, -6, 0, {room='c0_0'})`, step 240, `bodies`: one body at y -23.8 with 7128 voxels; `agent.info(id)` -> nil; `agent.remove(id)`; `bodies` unchanged.
workaround: the game must never spawn an agent into rock (the Blue station crowd spawns at its level's height now); `bodies` per floor (`BODY_TABLE=1 tools/p2_playthrough.py`) shows no stale bodies after the fix except 3-4 `debris` bodies of floor 2 (sleeping chunks of a destroyed wall: not removed with their floor).

## Replay guard (2026-10-24, binary 168a8d7)
Eight recordings of the floor-4 flows (`tools/replay_guard.py`: `--first-floor 4` on seeds 7, 99, 12345 twice each, and the bot from floor 1 through floor 4 on seeds 4242 and 99) all replay to their hash with hash probes on. Earlier the same day a first soak and several `--first-floor 4` runs between 18:15 and 18:31 UTC replayed to other hashes: the cause that could be shown was the bot's own replay using the live run's `--save` world (fixed: the scratch file is deleted before the replay); ONE run at 18:31 after that fix still differed and could not be reproduced with a changed `.events` state, 4 busy cores, older commits or 8 repeats. Noted, not explained.

## Phase 26: foliage.csv `density` is not a cover fraction (binary 168a8d7, floor 3 / floor 1 flagstone)
kind: unclear docs        severity: hurts (a test value of 0.04 looked like a thin scatter in a corridor and like a dense field in a village square)
what I tried: a ground-cover row `crack` (surfaces flagstone;cobble;ruin_stone) at density 0.04, then 0.02, then 0.006, and a plain row `grass` at 0.61 / 0.45.
expected: `density` as a share of the surface (0.02 = 2 % of the voxels carry a tuft), so 0.02 is a few tufts.
happened: 0.02 on a village square (paved flagstone, 20 x 30 m in view) shows hundreds of tufts; with the row at 0 the paving is clean; only about 0.006 gives "a few tufts in the joints". The number scales some per-column blade count, not a cover fraction, and the same value looks different on a bright open floor (auto exposure) than in a dark corridor.
repro: projects/dungeon_crawler/foliage.csv row `crack` density 0.02, `tools/polish_pictures.py X --only square_f3_day --time 0.12` (floor 3, village square), then the same with 0.0 and 0.006: ~/share/polish/D_probe/ and D_house/.
workaround: tuned by picture (0.006 for the dark cracks); tools/precommit.sh keeps every non-meadow row at or below 0.3.
ask: docs/FOLIAGE.md should say what `density` is (blades per what area, at which `spread`, how `share` and `patch_density` combine) so a developer can pick a value without a picture loop.

## Phase 27: two live runs of one seed differed: the cause was the project folder's persisted state, not input timing (binary d0bc0a5; cause found by the builder in 6a8e1fe)
kind: unclear docs / missing option (fixed: `--state-dir`)        severity: hurts (every "fight outcome in the usual band" check was noise for a day)
what I tried: tools/p2_playthrough.py 4242 janitor 1 --no-replay run twice in a row: the runs agreed until the first fight and then parted (crypt: hp 97 vs 88), though each recording replayed to its own hash.
what I first believed (wrong): an MCP `input_action` landing on tick T or T+1 by thread timing. A `state_hash` call before every input action made the runs equal and I filed that as the cause and the workaround (act()).
the real cause (the builder's): the tick path is synchronous; what differed is the project folder's persisted state (.state/store.json, .prefabs/, .events/state.txt, .state/wear.bin), read at the start of a run and written at its end: run 2 started from what run 1 left (the sync call only changed how much of that was read). `--save` scratch does not cover it. Engine 6a8e1fe: `--state-dir DIR` moves those four paths; an empty dir = a session from nothing; `input_action` returns `tick` and `applies_at_tick`.
now: tools/voxelith_client.py starts every engine with a fresh `--state-dir` (removed at exit; replays too), act() no longer syncs; two live runs of floor 1 seed 4242 with fresh dirs and no sync: identical in every room line (final hash 96a461655d80a9eb); seed 99's borough fight (the "stall"): the boss engages and dies in fight 0 on a fresh dir.
docs ask: docs/MCP.md should say that a project folder keeps state between sessions (a test harness must pass --state-dir) next to "Nothing runs between two calls".

## Phase 28: a one-voxel ridge in the middle of a floor is a wall for the nav flood (binary d1d2c7b; found by p1_validate floor 4)
kind: bug or unclear docs        severity: hurts (an agent could not cross a 3.5 m rail bed with one glowing line along it; the validator reported 92 problems on two seeds)
what I tried: the artist's live rail: a line of `live_rail` voxels one voxel (6 cm) high along the middle of every rail bed of floor 4 (the bed is a 3.5 m wide strip, floor at y 125, the line at y 125 too). `flood_region` over the cell, from a spot on one side of the line.
expected: AGENTS.md says steps up to 0.5 m are walked; a 1-voxel ridge is a step of 0.06 m, the whole bed is one island.
happened: (1) a `from` that lies exactly on the ridge column: "the standing spot at `from` (y 125) is not a cell of the box (outside it, or the body does not fit)", whatever y is given (125 .. 129 all answer with y 125: the answer snaps the height, the ridge column is not a standable cell); (2) from either side of the ridge the OTHER half of the bed is `unreached` (islands of 1024 cells = 3.5 x 63 m): the ridge is not crossed. A player walks over it (body physics), only the nav grid does not.
repro: any floor strip of 3 m or more with a line of solid voxels one voxel high across or along its middle (`edit.box(x, y, z0, x, y, z1, "stone")` on a flat floor at y - 1), `flood_region` from a spot 1 m beside the line to a spot 1 m beyond it.
workaround: the line is FLUSH with the bed floor (the live_rail voxels replace the top row of the ballast instead of sitting on it): the same glowing line seen from above, no ridge, 0 problems.
ask: a ridge of one voxel should not change the nav cells (the cell height is the highest solid of its 0.5 m, then a 0.06 m step is nothing), or the docs should say which obstacles a 0.5 m cell cannot cross.
