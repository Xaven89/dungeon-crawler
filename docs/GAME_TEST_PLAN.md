# Fixes after the first game test (the dungeon crawler "The Descent")

Source: `/mnt/data/projects/dungeon-crawler/ENGINE_FEEDBACK.md` (18 findings) and the "not checked" list of its `GAME.md`. The game (9 areas, boss, HUD, save, bot playthrough, a recording that replays) was built with the packaged engine and the docs only,
so every finding is a real author's wall. **Revision 2** (after the Fable plan review, `r27/plan-review.md`: 8 M, 11 L, all taken in): two diagnoses were wrong (the underground light leak is in the shading pass, the prefab replay only looks in the wrong folder), three fixes shrank to a line,
and the save decision got a read side. Each package says what is wrong **in the engine** (checked against the source, today's file names), the fix, the effort and how to know it is done.

**Decisions taken (by the user):** `--headless` stops *writing* the save (it still reads it, see WP5); game mode switches the F1 to F10 toggles off (`--debug-keys` brings them back; F3, F5, F11, Esc and `--hud 1` stay); the Fable session reviews the input and replay changes (WP2, WP8) but implements nothing.

**The acceptance test for every package is the game itself**: its `tools/playthrough.py` plays the whole floor through the MCP server and replays the recording to the same hash. When a package lands, the game deletes the workaround named under it and the playthrough still has to pass.
After each phase a fresh engine package is installed into `/mnt/data/projects/dungeon-crawler` (`cmake --install`) and the game session is told which workarounds to remove.

## Phase 1: stop blocking authors (about 3 days)

### WP1 Game mode: the raw keys must be switchable off (finding "sandbox keys", blocks)
Wrong: K / F / B and the mouse buttons are already input actions (`input_map.hpp:16`, `input_map.cpp:85, 252`: `explode = none`, `dig = none` stop them; the game already does that). What is **not** an action, and read raw in `main.cpp` (about 8250 to 8265 and 8600 to 8665): Z / X (undo, redo), Y (rain), N / M (clock), F1 to F10 (debug toggles), the number keys (teleports), R (ragdoll), V (walk / fly), Plus / Minus (look sensitivity), End (mute), F5, F11 and the editor block (L, H, J, U, P, I, O, Ctrl+C / V, Delete: only with the editor on).
Fix: `project.cfg` `game = on` (CLI `--game`) sets `opt.gameMode`: in game mode the raw sandbox keys do nothing: Z X Y N M, the number keys, R, V, F1 to F10 (with `--debug-keys` they work), the editor block; **F3 (HUD text), F5 (screenshot), F11 (save), End (mute), Plus / Minus, Esc and `--hud 1` stay**. Tab and the tool panels stay off unless `--ui`. `status` reports `game_mode`.
For a sandbox project that wants them anyway, `undo`, `redo`, `rain`, `clock`, `teleport`, `doll` and `walk_toggle` become input actions (rebindable in `input.cfg`; `teleport`, `doll`, `undo` and `redo` are already logged actions, so replays are untouched; nothing in this package touches determinism).
Effort: S (0.5 day). Done when: a windowed Xvfb session with `game = on` ignores Z, 1, Y, N (a case in `tools/window_test.sh` with `xdrive.py`); `docs/INPUT.md` lists which keys exist in game mode (it says the editor keys "are not remapped": wrong after this). Game workaround to delete: the undo shield, the sentinel voxel, the teleport guard, `fx.rain(false)` in `game/world.lua`.

### WP2 Custom input actions: the mouse and the pad for game actions (finding "LMB / RMB cannot be read", hurts)
Wrong: `ui.input().down / clicked` exist only while the pointer is free; `pressed` lists keys only; the left button's only consumer is `dig`.
Fix: `input.cfg` lines `action.attack = mouse:left, key:f, pad:rt` define named actions (today's source syntax). **Read from the raw input and the pad state, not from the mapped `in`** (the mapper clears `in.pressed[MouseLeft]` when `dig = none`, `input_map.cpp:252`). The edges become a logged action `input_action name down player`:
- **It carries the player**: logged actions have no player (`ReplayEvent`; net frames in `netTick`, `main.cpp:3353` to 3400, apply "states, then actions" per player), so the id goes in the vector like `withPlayer` (1767) does for the clipboards; the callback is `on_action(name, down, player)`.
- **`input.down(name [, player])`** in the tick is a per-player bitset **owned by the simulation**, set only by the logged actions (so a replay and a late joiner derive it; it is never read from `Input`). A focus loss or a released pointer logs an `up` for every held action (the raw input drops keys silently: an attack held across an alt-tab must not stay down in the log).
- `ui.input().actions` gives the HUD the **edges of the same logged events**, not a second reading of the raw input (the HUD and the tick would disagree by a frame).
Effort: M (1.5 days). Done when: a mapper unit test, a `tools/determinism.sh` case that records and replays an action (and a two-player net case in `tools/net_test.sh` if cheap), the game attacks with the left button. Game workaround to delete: attack on F. **Fable reviews this one.**

### WP3 `events.on` and `include` (findings "events.on replaces", "include noise")
- `events.on`: `lua_host.cpp` about 989: each call adds a LuaCallback node named `lua:<node>:<signal>`; the second call gets the same node back and `eventFns[cb]` is overwritten. Number the nodes (`...#2`) so that all callbacks run in connect order; `events.off(handle)` is `es->remove(cb)` plus erasing `eventFns[cb]`. LuaCallback nodes are not saved but are in the event graph the session hash covers: levels with two callbacks on one node change their hash (they never replayed correctly anyway).
- `include`: **a compile switch, not a binding change**: `lua_host.cpp:32` defines `SOL_ALL_SAFETIES_ON`, which turns `SOL_PRINT_ERRORS` on, so sol2 prints `[sol2] An exception occurred` for every C++ exception that becomes a Lua error, inside a `pcall` too. `#define SOL_PRINT_ERRORS 0` fixes every binding at once (the message still reaches Lua). Add `include_optional(file)` and `file_exists(file)`.
Effort: S (0.3 day), a unit test with two callbacks on one node and one with a failing `pcall(include, ...)` that prints nothing.

### WP4 The dev loop: `--check-project` and `reload_level` must agree with the real run (findings "textures.json", "gravity system", "dry run differs", hurts)
Wrong, each a line: `check_project.cpp:105` `dryRunLevel` builds its own empty `TextureTable` (the kit check at 189 to 206 loads the project's `textures.json` into another one; `edit.texture_box` resolves through `env.textures`), and the `events` at line 93 never gets `events.setGravity(&gravity)` (`main.cpp:2668` does it; `event_system.cpp:118` is the check that fails).
Fix: both lines (20 minutes); `reload_level {force: true}` (`main.cpp` 7692 to 7712 runs `checkProject` and refuses) reloads anyway and returns the report as warnings, with the note that a script that throws in `on_start` leaves a half-built level; `docs/TEXTURES.md` gets the `textures.json` format as a copy-paste example (with and without ids) and a bare JSON array becomes an error that shows the right shape.
Effort: S (0.5 day). Done when: a `test_check_project` case with a textures.json and a `gravity_target`; the game drops its `pcall`s around `texture_box` and `gravity_target`.

### WP5 Docs, package and the save (findings "xdrive.py", "--dump-materials", "headless writes the save", "unattached voxels fall")
- **Package**: `CMakeLists.txt:137` to 149 installs the prefab `.vxm` files, shaders, docs, `demo_level` and the launcher only. Add `assets/lib` (`ui_kit.lua`, `inventory.lua`: `findEngineAssets`, `project.cpp:171`, walks up from the binary and finds `assets/lib` next to `assets/prefabs`, no code change) and the Python tools (`voxelith_client.py`, `make_*.py`, `xdrive.py`, `xin.py`, `xfuzz.py`). The game's folder lacks `xdrive.py` because my copy left it out: half my fault, the fix is the install rule plus a package check that starts the packaged binary on `demo_level` and includes the UI kit.
- **`--dump-materials`** (`main.cpp:480`): it already takes `--materials file` for the path; fix the doc line and print the path *before* writing.
- **Headless and the save** (`main.cpp:474`: `if (opt.save.empty() && !opt.mcp) opt.save = project.save`): the save path is also what the world is read from (`ChunkStore store(opt.save)`, 863), what `first_run()` reads (865, 2853) and what gates prefab state, node states, authored events, cover and textures.json (`!opt.mcp || !opt.save.empty()`). "Like MCP" would make a headless picture of a saved project show the *generated* world and stop reading its project files. So: a third state **`opt.saveReadOnly`**: headless reads the save and the project files like a normal run and **never writes** (the `save` action and the exit save go to memory; 1832 has the wording). Nothing in `tools/` relies on the implicit headless save (`determinism.sh`, `mcp_smoke.py` pass `--save`).
- **Unattached voxels fall as bodies**: say it in `LUA_API.md` (`edit.*`, `edit.text`) and `GUIDE.md`, name the anchor flag of the materials table, and log one warning line when a script edit in `on_start` makes a body.
- `GUIDE.md` says `build/release/voxelith` and `tools/xdrive.py`: add a "packaged engine" section with the right paths.
Effort: S (0.7 day).

### WP7b The light underground: two shader lines (finding "time of day", hurts; pulled forward)
**Diagnosis corrected**: it is not the probe update (`gi_update.comp:148` deliberately gives a ray that hits an untraced probe nothing). The sky reaches the walls through the **shading pass**: `shade.comp:442` to 446 mixes the constant sky ambient with the probe light by `giLookup`'s coverage, and `giLookup` (`gi.glsl:41` to 58) counts only probes with the "holds light" flag toward coverage; a probe inside stone is *solid* (flag bit 2 only, never traced) and is skipped, "a wall of solid probes fades back to the sky". With 1 m probes (`GI_SPACING 16`) every wall point of a 2 m corridor has half of its eight probes in stone: 20 % or more of the daylight sky ambient lands on every underground wall, blue-grey. At night `sunColor.w` is about 0, so it is black: exactly the finding.
Fix: in `giLookup`, a probe that was **traced and is solid** (bit 2 set, bit 1 clear) counts toward coverage with its weight and contributes no light; only never-traced probes and positions outside the grid fall back to the sky. Outdoors nothing changes (a cliff face still has traced air probes in front of it); keep the `0.06` floor.
Effort: 1 hour plus a GPU picture test (a closed room under 8 m of stone is black at noon; a cave mouth outdoors is unchanged). The `ambient` key of WP7 becomes optional.

### WP8a Replay without `--project` finds the manifest (finding "prefab.place cannot be replayed", hurts; the one-line half, pulled forward)
**Diagnosis corrected**: the recording already copies every manifest, model, plain file and agent model to `<log>.clip/prefab_N.<ext>` and a replay reads them from there (`main.cpp:2686` to 2706). What breaks: `main.cpp:2683` to 2686: `prefabs.baseDir` is the project's models folder only with `--project`; a replay started as the game does (`voxelith --replay log`) gets `~/share/voxelith-clips`, and `lua_host.cpp:1172` to 1178 tests `exists(mpath)` on the **original** path before `resolve` is asked: the "no prefab 'buildings/door'" error verbatim.
Fix: in a replay `prefabs.baseDir = luaBaseDir + "/models"` (the script path is already carried: `main.cpp:568` to 574), and `loadManifest` skips `exists(mpath)` / `last_write_time(mpath)` when `resolve` gives a copy (a replay must never need the original).
Effort: 1 hour.

## Phase 2: the things a game needs to look right (about 2.5 days)

### WP6 The script's HUD in headless and MCP pictures (finding 1, hurts)
Wrong: the HUD block in `main.cpp` (about 8750) runs `drawHud` only in the window loop; `takeShot` and `--headless --screenshot` never call it. The headless loop already has the UI draw path (`main.cpp:7959` `renderer.setUiDrawData`), and `takeShot` renders four frames (4889).
Fix: call `drawHud` once before them with a **neutral `HudInput`** (no keys, `mouseFree` false, the real size) and **drop the `hudCode` list** (the window loop turns it into `act("lua", ...)`; a picture of a HUD that pushes code every frame must not log an action in a recording); `screenshot {hud: true}` and `--hud-lua 1`. `on_hud` stays out of the simulation (unchanged; the doc keeps "on_hud never affects the simulation" as a rule for authors, the engine cannot enforce it).
Effort: M (1 day). Done when: `docs/HUD.md` loses "Not in MCP and headless runs", a GPU test compares a golden image with an `on_hud` text, the game's `hudshot.sh` is deleted.

### WP7a The clock and the fog from the project and from Lua
Wrong: the day phase comes only from `--time` or one screenshot; there is no project or Lua key.
Fix: `project.cfg` `time = 0.75`, `time_speed = 0` and Lua `sky.set{ time, speed, fog, ambient }`. `dayPhase` has no reader in the simulation (the reads are render, screenshot and the clock), so a Lua write is cosmetic and replays the same on every peer. **Precedence**: screenshot argument > Lua `sky.set` > project key > the clock (`--time` freezes the clock at 8667). `fog` and `ambient` multiply the biome mood value in a biomes world (the mood channel). `sky.set` is not in the session hash or the store; an `on_hud` call is allowed (two machines may show different skies: cosmetic).
Effort: S (0.5 day).

### WP7c Emitter lights (finding "dust_motes light", "torch needs five seconds", annoying)
`emitter_system.cpp:50` to 75: only `torch`, `campfire`, `magic_sparks` set `lightColor` / `lightReach`; `dust_motes` sets none. The GI gathers light from emissive particles (`gi_update.comp:160` to 175) and from the extra-light list: a `Spark` emitter of sand motes has no emissive particles, so even with `light` set the probes may get nothing. **Check which list `lightColor` feeds before promising "works on any preset"**; the fix may be that an emitter's light is a point light in `elData` regardless of its particles. "Torch light within a second": the probe refresh is a near box around the camera per frame and the rest at `giBudget` (`renderer.cpp:866` to 870), so a direct term for the flame presets is right; the doc says a screenshot after 30 ticks shows the near box only.
Effort: S-M (1 day).

### WP8b Replay: the missing copies (finding, the second half)
`prefab_1.vxm: cannot read` while `prefab_10.vxm` exists: the game's models folder holds exactly nine creature models and agents' models share the counter (`agent_system.cpp:77`, `animated_model.cpp:30`), so the first nine loads were not copied (or lost). The code skips a copy only with the warning `recording: cannot keep a copy of ...` (`main.cpp:2697`). **First read that line from one recording of the game and `ls` the clip**; the cause is one of: a source path the recording cannot open, the clip folder recreated by a restart (`gRestartArgs`, 7719), or loads while `recording` was still false. Then fix that cause. A `prefabs/` tree with a hash is over-built; a header line that lists the copied files with their sizes (so a replay names a missing one) is enough.
Effort: 0.5 to 1 day. Done when (WP8a and b): a `tools/determinism.sh` case that **replays without `--project`**, places a manifest prefab and a plain model and has an agent with a model; the game's `Game.no_prefabs` flag goes.

## Phase 3: depth (about 4 to 6 days, after the game has used phases 1 and 2)

### WP9 Sound: handles, 2D, buses, and hearing it without a device (finding, hurts)
Wrong: `sound.play(file, x, y, z, volume, pitch)` only, positional, fire-and-forget; music and the announcer's voice had to be cut into 2-second pieces.
Fix: `sound.play{ file, loop, bus = "music" | "voice" | "sfx", volume, pitch, at = {x, y, z} }` returns a handle (`stop`, `volume`, `pitch`, `fade`); no `at` is listener-relative (2D); bus volumes in the settings; a crossfade helper. The handle API is cosmetic (audio reads the simulation, `main.cpp:949` to 960) and the **handle table lives in the Lua host and is skipped by the hash** (a `stop` or `fade` from the tick must not be in the log: an audio-less peer has no handle).
**`--audio-out file.wav`** is the same sink as `--audio-demo` (`main.cpp:120, 942`) attached to a session (headless or a replay): `--replay log --audio-out x.wav` is how the game's sounds get heard, so it costs less than first thought.
Effort: M (1.5 days).

### WP10 The player's body and a weapon in hand (finding, nice to have)
`camera.mode("third")` shows the debug mannequin. Fix: `player.model(file)` (a rigged model driven by the walk rules and clips like agents, slots `idle / walk / run / jump / attack`) and `player.hand_model(file)` for the first-person view (attached to the camera with a sway and a swing clip triggered by an action: WP2). Effort: L (2 to 3 days). **Design first**: the player is not an `AgentSystem` agent and the model must follow the player's state without feeding back into the simulation.

## Order and effort
| phase | packages | effort |
|---|---|---|
| 1 | WP7b two shader lines, WP8a one line, WP1 game mode, WP3 events / include, WP4 dev loop, WP5 docs / package / save, WP2 input actions | about 3 days |
| 2 | WP6 HUD pictures, WP7a clock / fog, WP7c emitter lights, WP8b missing copies | about 2.5 days |
| 3 | WP9 sound, WP10 player model | 4 to 6 days |

Not in the list on purpose: "mouse in a headless X session" (the game could not click) is covered by `xdrive.py` shipping in the package (WP5) and by WP2, which gives tests a way to inject actions without a pointer; "long-run memory" is `--memory-report` / `--soak`; a human playing the boss fight cannot be automated.
