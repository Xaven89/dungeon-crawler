# Voxelith guide

## Running
```
source env.sh && cmake --preset release && cmake --build --preset release -j6
build/release/voxelith --project projects/demo_level                  # windowed, a level with its script, materials and save file
build/release/voxelith --manual --spot 1 --quality medium           # fly / walk around the generated world
build/release/voxelith --headless --manual --spot 7 --script "idle:60,boom:40,idle:200" --frames 60 --screenshot out.png
```
`--help` lists every option. There is no separate editor program: the world editor, the gravity tools and the scripting are part of the running game.

## Controls (manual mode)
| keys | |
|---|---|
| WASD, Shift, Space / Ctrl, C | move, run, jump / up / down, jetpack · V walks or flies · mouse looks (+/- sets its speed) |
| LMB / RMB | dig / build (in editor mode: place / erase) · wheel changes the brush size |
| F, B, K | explode where you look · torch (set it alight) · demolish the tower |
| E | press the button or lever the crosshair is on (walk mode, within 3.5 m; the hint `[E] ...` shows at the top of the HUD); on a loose body (crate, door panel) **grab** it, E again lets go, the left mouse button throws it while it is held. A light body (under about 60 kg) follows the view, a heavy one is only dragged along the ground |
| E, W S A D (in a vehicle) | look at a vehicle (or stand within arm's reach) and press **E** to get in (`[E] Drive`), W / S throttle, A / D steer, **E** gets out (docs/VEHICLES.md) |
| Z, X | undo, redo (one user action each; liquids and fire that followed it come back with it) |
| 1 … 8 | teleport: tower, planet A, planet B, flip room, twist tube, A→B launch pad, liquid yard, habitat tube (walk round the inside of the tube; a level's own `player.teleport` in `on_start` wins over `--spot`: press the key afterwards) |
| G, R, Y | flip-room switch · ragdoll · rain on / off |
| F1 F2 F4 F6 F7 F8 F9 F10 | shadows · AO · step-count heat map · gravity view · GI · foliage · TAA · light shafts |
| 0 (or Home) | the camera: first person, third person, **editor camera** (a god view: the player stays where it is, nothing pushes it, WASD pans, wheel zooms, middle button turns, clicks act at the pointer), docs/CAMERAS.md |
| N, M | advance the clock · stop the clock · `--time 0..1` starts at a phase (0 sunrise, .25 noon, .5 sunset, .75 midnight) |
| F3, F5, F11, F12 | HUD · screenshot to ~/share · save the world edits · quit |

## The world editor (Tab)
Tab turns the editing keys on; the HUD shows the brush. Everything is an ordinary edit, so Z / X undo it and a recording replays it.

| keys | in editor mode |
|---|---|
| LMB / RMB / MMB | place the material / erase / paint (recolour solid voxels only) |
| `[` `]` | previous / next material · `L` picks the material under the cursor |
| `,` `.` | brush shape: sphere, cube, disc (flat across the local up), rough sphere (the noisy bite of a blast) |
| wheel | brush size |
| `H` `J` | set the region corners A and B at the cursor · `O` copies the region to the clipboard (also written to `clip_N.vxm`) |
| `P` / `I` | paste the clipboard at the cursor / turn it by 90° steps (24 orientations) |
| `Q` | cycles the tools: selection, brush, **paint** (docs/PAINT.md: a palette of 255 colours, LMB paints a stroke, RMB clears, MMB picks the colour under the pointer; a material's pattern stays under the paint). The **selection tool** (docs/EDITOR_MODE.md): LMB drag draws a box on the ground (Shift + wheel: its height), RMB clears it. **Handles**: click a corner of the box, a small coordinate system appears (x red, y green, z blue): drag an arrow to move that corner along the axis; drag a face along its own axis; the **centre** handle moves the box's *content* (drag it over the ground, or pick it and drag an arrow; a ghost shows where it lands, the move is one action when you let go; Ctrl: a copy, Shift: only the frame, RMB cancels). `R` turns the content a quarter about the vertical axis (Shift: the other way), `M` mirrors it left-right (Shift: front-back), `Delete` empties the box, `F` fills it with the material, `Ctrl+C` / `O` copy it (the copy then follows the pointer as a ghost: a click puts it down, as often as you like; `R` turns it, `Esc` or the right button stops; `Ctrl+V` / `P` do the same later), the Prefabs panel's gallery (a picture per prefab: the project's manifests and models, the engine's starter kit, the workspace's small models) carries a prefab on the pointer in the same way (the editor starts with this tool: a click selects, `Q` is the digging brush), `H` / `J` set the corners by hand. **A click on a placed prefab selects it as a whole** (Shift: a box that starts on it): the centre handle moves it (Ctrl copies), `R` turns it, `Delete` removes it, the Prefabs panel shows its settings (docs/PREFABS.md). The same things are MCP tools: `select`, `region` (fill / delete / replace / copy / paste / move / rotate / mirror), `clipboards`, `stamp`, `editor`, `camera` |
| `U` | gravity drop test: 1,000 debris particles from the cursor fall for 5 s under the real field (tune a gravity transition) |

Models: `.vxm` is the engine's own format (materials stored by name, LZ4); MagicaVoxel `.vox` files import with colour matching (`--vox file.vox`, or `edit.model` in Lua). **To convert files**: `voxelith --convert-vox in.vox out.vxm --materials table.csv --vox-prefix dk` writes the model (`--vox-factor 0.6` any other ratio (a pack drawn with 3.75 cm voxels), `--vox-up 2` draws every voxel as a 2 x 2 x 2 block (art made on a coarser grid: a 34-voxel house is 2 m wide at 6.25 cm, at 2 it is 4 m), `--vox-scale 2` makes it half the size, `3` a third: blocks of that many voxels become one, solid when a quarter of the block is, the commonest material; for art made on a finer grid than 6.25 cm: a 256-voxel tree is 16 m tall, at 1/3 it is the size of the engine's oak) and, for colours that match no material (only palette entries some voxel uses), new ones named `dk-RRGGBB` into `table.csv` (the next conversion with the same table reuses them); `tools/vox_materials.py classify table.csv` gives those rows the physics of what the colour probably is (stone, metal, cloth; `--kind trees` with the prefix of a tree set: bark, foliage, snow), `merge` copies them into a project's table. **Meshes** (textured FBX: a modular kit, props) are voxelized first: `tools/mesh_to_vox.py out_dir texture_dir *.fbx` samples the surface of every triangle at the engine's 6.25 cm, takes the colour from the texture and quantises all models to one shared palette (needs ffmpeg), writing `.vox` files; then `--convert-vox` each. `tools/vox_palette.py K OUT_DIR *.vox` cuts the colours of a set to K shared ones first (art with gradients has hundreds of shades, one material each); `tools/mesh_to_vox.py` reads FBX, OBJ (with a palette or texture) and GLB (vertex colours, metres); `--kind trees|desert|props|stone` of `vox_materials.py classify` picks the guess for a kind of art; the packs converted so far are in docs/ASSET_CATALOG.md. A `.vox` that is a whole scene (a kit or town laid out with named objects) splits into one file per named object with `tools/vox_split.py IN.vox OUT_DIR` (`--list` just lists them). Check the licence of art you convert before you ship it.

## The tool UI (Tab, then the mouse)
Tab also opens the tool panels (Dear ImGui) and releases the mouse for them; a click in the world takes the mouse back (the click only grabs it), Esc releases it,
Tab closes the panels. Panels never swallow keys unless a text field has the focus (Esc leaves the field). Everything they do goes through the same actions as the
keys, so it is undoable and recorded. `--ui` starts with the panels open, `--ui-panels tools,view,...` picks them (also for headless screenshots).

| panel | what it does |
|---|---|
| Tools | brush shape, mode and size, a grid of material swatches with a filter, the clipboard (copy around the look point, rotate, paste), undo / redo with the depth, drop test, save |
| View and debug | every renderer toggle (shadows, AO, GI, TAA, shafts, foliage, heat map, gravity view), bloom / GI budget / foliage radius / exposure, rain, the clock, and the **overlays** |
| Settings | quality preset and the live values; "save settings" writes the ini; render scale and stream radius apply at the next start |
| Gravity fields | every field of the running world with its enable switch, position, strength, direction, shells, priority: edited live; "new point field / room at the camera" |
| Console | the log, the last script error, a Lua line (`edit.sphere(...)`, `fx.explosion(...)`) and a reload button (off while recording: it would not be in the log) |
| Frame graph | every pass of the frame in order with its GPU time, what it reads and writes, culled passes greyed, the resources of the frame. `--dump-graph` prints the same as text |
| Prefabs | the tracked prefabs (follow the file, re-stamp, remove) and the models folder with "place at the look point" |
| Effects | the defined effects: edit every emitter's numbers and replay the burst at the look point (loop to watch it) |
| Models | the model editor, see below |

**Overlays** (View and debug, or `--overlay physics,gizmos,arrows,streams`) are lines drawn over the picture with a depth test (hidden parts faint):
*physics* = bounds of the bodies (green awake, blue asleep, orange about to weld back into the world), each body's gravity vector (magenta), velocity (cyan), contact
points and normals (red, brighter with the impulse); *gravity field shells* = the primitive and its inner / outer shells (grey when the field is disabled);
*arrows* = the gravity vector on a grid around you; *streamlines* = the paths a dropped object would follow.

### Models: parts, pivots, clips
A rigged model is a `.vxm` ("VXM2") whose voxels are tagged with parts (part 0, "root", takes every untagged voxel). A part has a parent, a pivot on the voxel grid and
an optional material override; clips are keyframes of rotation (degrees about X, then Y, then Z) and offset (voxels) per part, relative to the parent, with linear
interpolation (rotations by slerp). No skeletal weighting: parts move rigidly. In the world every part is a **driven body**: it has no gravity, never sleeps, pushes
crates and ragdolls, and is carried by the same renderer as any body.
1. Copy a region (`O`, or `copy:` in a script) or open a `.vxm` / `.vox` file's copy from the models folder; "new from the clipboard" starts a rig.
2. In the Models panel add parts, tag voxels (a box, one material, or everything connected to a voxel), set pivots (by hand or "centre of its voxels"), pick a parent.
3. Add a clip, scrub the time slider, "add a key at this time" for the selected part and drag its rotation / offset: the pose is drawn at the anchor ("anchor here" = the look point).
4. Save, then "preview as a body" to put it in the world with the clip playing; or `model.spawn` / `model.play` from a script.
Clips also import from / export to JSON (`{"clips":[{"name":"walk","duration":1,"loop":true,"tracks":{"leg_l":[{"t":0,"rot":[0,0,0]},{"t":0.5,"rot":[35,0,0]}]}}]}`, tracks keyed by part name).
`voxelith --make-demo-rig out.vxm` writes the sample character (torso, head, arms, legs, "walk" and "wave"); `voxelith --rig file.vxm` opens a file in the editor.

### Prefabs
A prefab is a model placed into the world and tracked. When its file changes the old stamp is removed voxel by voxel (only voxels that are still the stamp's: what you carved or
built into it since stays) and the new version is stamped. `prefab.place` in a script or "place at the look point" in the panel; with a project the tracked list and a snapshot
of each stamp are kept in `<project>/.prefabs/`, so a restart adopts what the saved world already holds and re-stamps only what changed while the game was closed.

### Effects
`fx.define{...}` in the level script (docs/LUA_API.md) defines named bursts and streams of particles; saving the script redefines them, so editing the file is the live loop, and the
Effects panel edits the same numbers with sliders. Effects are cosmetic (particles only): they are not part of a replay.

## Checking a project
`voxelith --check-project dir` (no GPU needed) reads everything a level author can get wrong and prints one line per finding, with the file and line where there is one: the
project file (ranges, unknown keys), the level script's syntax, the material CSV (bad lines, duplicate / renamed / unnamed ids), the settings, every model in the models folder
(readable, materials known, rigs consistent), the tracked prefabs' sources and the world save. Exit code 1 when there are errors.

`--check-project` also **runs the level script** on a flat stone world for ten seconds of ticks (`project.first_run()` is true there), so a wrong material name or a nil call in
`on_start` is reported with its line before you start the game.

## Writing a level: files and units
- `voxelith --dump-materials` writes the table and prints where (the absolute path). A `materials.csv` may list only the ids you add or change (ids 70 and up are free).
- Where things end up: `world.vxs` (the `save =` file, edited chunks), `<project>/.prefabs/` (tracked prefab state, regenerated), a recording's `.clip` folder (copies of the models and
  the materials it used), screenshots (F5) in `~/share`.
- Lengths: edits are in voxels (1 voxel = 6.25 cm = `units.vox(0.0625)`), `units.vox(m)` / `units.m(v)` convert; bodies and gravity are in metres. Effect sizes are in voxels too:
  3 to 6 is clearly visible.
- With `save =` set, the second run starts from the saved world and runs `on_start` again: build the world only when `project.first_run()` is true, set up everything that is not a voxel
  (gravity fields, timers, bodies, models) every time. `projects/demo_level/level.lua` does exactly that.
- `voxelith --script list` prints the scripted-input grammar (`idle:60,turn:90,fwd:120,...`; numbers inside one token are separated by `/`; a positive `turn` is right, a positive
  `pitch` is up; the tower spot faces +x).
- Asset kit (`voxelith --make-demo-assets dir`, shipped in `projects/demo_level/models/`): `walker.vxm` (rigged, clips walk / wave), `crate` 16^3, `lantern_post` 7x44x7, `tree_small`
  23x31x23, `arch` 32x24x6, `bench` 24x10x8 (voxels).

## Profiling
The HUD and the Frame graph panel show per-pass GPU times and the CPU zones are in the log at exit. `cmake --preset tracy && cmake --build --preset tracy` builds with
Tracy: every zone becomes a Tracy zone, frames are marked and the GPU / record times are plotted; the profiler connects to port 8086.

## Projects
A project is a directory with `project.cfg`:
```
name = Moon pool         seed = 1337        world = 250
lua = level.lua          materials = materials.csv      settings = settings.ini
spot = 1                 save = world.vxs      terrain = demo | flat | biomes
```
`--project dir` runs it. Edited chunks are written to the `save` file when you press F11 and when the game exits; the next run loads them back. **A headless run (`--headless`) reads the save and the project's files and never writes them** (give `--save file` to write one); an MCP session does neither unless `--save` says so.
`time = 0.75` (0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight) starts the day at that phase and keeps it (`time_speed = 1` lets it run: 1 is a day in ten minutes, 0 to 60), `fog = 2` multiplies the fog density; the script can change both while the game runs: `sky.set{ time, speed, fog }`, `sky.get()` (render only: nothing in the simulation reads them). Precedence: the `time_of_day` of one screenshot, `sky.set`, the project's keys (`--time` on the command line stands in for `time`), the usual clock.
`particle_taa = off` keeps particles out of the temporal anti-aliasing history (no double image of a fast small one).
`game = on` makes the project a game, not the sandbox (no digging, undo, rain, clock, fly, teleports or debug keys: docs/INPUT.md "Game mode"); `--game` does the same from the command line, `--debug-keys` brings back F1 to F10 / the number keys / M for the author.
`terrain = flat` starts the level on an empty grass plain (`world` chunks of 4 m on a side, ground at 25 m, the player in the middle, only the ground's gravity): none of the demo's tower, planetoids, flip room, tubes and liquid yard, so `world.flat_spot` and fixed coordinates just work. The default, `demo`, is the island of the demo level. `terrain = biomes` makes the world from a climate and a biome table (plains, forest, desert, mountain, tundra), with trees by region and optional caves: docs/WORLD_GEN.md.
`--check-project` runs the level script for ten seconds on a flat stone world, not on the world the project will have: take a building site from `world.top` / `player.pos()`, not from fixed coordinates.
Level scripts: see `docs/LUA_API.md`.

**The project picker.** The **Projects** window (menu bar after Tab, or start with `--ui-panels projects`) lists the folders with a `project.cfg` next to the running project (or `./projects`): name, folder, the first comment line of `project.cfg` as the description, when the world was last saved ("last played"), and a picture if the folder has a `preview.png`. **open** saves the running world (its `save` file) and restarts the engine on the chosen project (the same re-exec `reload_level` uses; the other command line options stay, `--project` and `--save` are replaced). A world that has edits and no save file asks for confirmation first. **duplicate** copies a folder (saved world included) under a new name, **create and open** scaffolds a new project like the MCP tool `new_project`. A replay, a recording or a networked session cannot switch. MCP: `list_projects`, `duplicate_project`, `reload_level {project}`. For a streaming launcher one entry with `--manual --ui-panels projects` replaces one entry per project.

## Materials
`voxelith --dump-materials --materials materials.csv` writes the table. Edit a line while the game runs: colours, roughness, emission, density, toughness,
restitution and friction **hot reload** within half a second. The flags (anchor, liquid, transparent, viscosity, flammability, burn time, fire spread) are read at start.
`fire_spread` (column 24, 0..255, default 255) is how much of the spread chance a fire between two materials keeps (the larger of the two counts):
grass has 15, so a grass fire stays a patch of about a hundred cells (up to a few hundred) and goes out (16 and 17 can creep on for minutes, 19 can run away over a whole meadow, 21 takes
it all), while a tree or a house burns through and lights the grass around it (expect a halo of a few burnt voxels of grass around every burning tree, and a house still catches from a meadow fire). Lines may name only the first 15 columns to change just those; new ids add materials.

`passable` (column 28, 0 or 1) makes a voxel you move through (blood, a web: stored, drawn and lit like a solid, blocks nothing, no structure, liquids wash it away) and `drag` (column 29, 0..255, default 0) slows the player while wading through it; both are read at start: docs/GORE.md.

## Settings and quality
`--quality low|medium|high|ultra` picks a preset; `~/.config/voxelith/settings.ini` (or `--settings file`) and `--setting key=value` override single values:
`render_scale gi gi_budget god_rays taa shadows ao foliage foliage_radius bloom stream_radius fps_cap mouse_sens hud_scale audio volume autosave language subtitles ui_scale colorblind reduce_motion` (the last five: docs/LOCALIZATION.md, docs/ACCESSIBILITY.md; also `--lang de`).
Low renders at 60 % resolution without GI, shafts and AO; ultra adds draw distance. (`--render WxH` sets the internal resolution directly.)

`dynamic_res = on|off` (default on), `target_ms` (default 14.5) and `min_scale` (default 0.5): while the GPU frame is over `target_ms`, the render size shrinks in 5 % steps (down to
`min_scale` of the window) and grows back when there is room; the upscale pass (`sharpen`) fills the window, the UI stays at full resolution. `spawn_cap` is the number of
particle spawns taken per frame (a spawn rate cap: the ring of 262,144 live particles is fixed) (8192 / 24576 / 65536 / 65536 on low / medium / high / ultra). The simulation never reads any of these: a recording replays to the same hash
under every quality (the determinism script checks it).

## Budgets, the performance gate and memory (design sections 13 and 15)
- `voxelith --perf-gate [--world N] [--render WxH] [--threads N] [--report-only]` runs the tour (every system at work) headless at 2560x1440 (or `--render`) with a frame per tick and holds the result
  against the budgets: CPU per tick by stage (edits + connectivity 2.0 ms, physics + solver 3.5, gravity 0.5, gameplay + Lua 2.0, liquids + fire 3.0, collapse 6.0, culling / upload / record 2.0,
  everything else 2.0: a stage fails when its mean is over the budget or its p99 over three times it), the whole tick (p99 under 16.7 ms), the **raw** GPU frame at that fixed size (mean under 16.7 ms,
  p99 under 25 ms: dynamic resolution is off in the gate unless `--setting dynamic_res=on` is given, and then a mean render scale of 80 % is held instead) and the memory plan. It prints the table,
  `FAIL` lines and exits 4 when something is over (`--report-only`: exit 0). On this dev laptop (RTX 3070 Laptop) the tour passes at 1920x1080 (GPU mean 12.3 ms) and misses 60 fps at 1440p
  in the open planet scenes (the ray march is 8-14 ms there): there dynamic resolution holds the frame at a mean render scale of about 73 %.
- `voxelith --soak [--script soakstill]` is a long run (15,000 ticks at 1280x720) of digging, blasts and fires: `soak` walks on (new ground, floods), `soakstill` is back at the start every eighth round. Every 300 ticks the resident
  set, the brick pool, the undo journal, the liquid bricks, the burning voxels and the loose bodies are sampled; over the last 60 % of the run memory may not keep growing (least-squares slope: over the last 60 % of the run it may be above the limit, in the second half of that it may not;
  limits 5 MB per 1,000 ticks for the resident set and 3 for the pool, 25 for both in the walking run) and the capped counters (journal 250,000 bricks, burning voxels, loose bodies, liquid bricks) may not go above their caps. The CPU stage table and the GPU time are printed, not held.
- Hard caps and what they do when hit: the brick pool is 1 GB; when it runs out of pages the edit flush drops the edits of the chunks it cannot allocate for (a warning), the streamer gives the column back and asks again later (no new column
  above 90 % of the pool, no new bodies above 95 %), a body that cannot be built leaves its voxels in the world, liquids stop flowing above 95 %.
- `--memory-report` prints the GPU allocations grouped into the rows of the design's memory plan against their budgets, the device heap and the resident set (the perf gate does that, too).
- Hard caps that degrade quality, not frame time: burning voxels looked at per tick (about 1,500: a forest fire of 60,000 embers burns and spreads more slowly), liquid sub-steps by
  active cells, particle spawns per frame, probe updates (`gi_budget`), bodies awake, collapse pieces per tick (a fixed voxel count), GPU upload bytes per frame, edit radius / volume.
- `tools/nightly.sh` is the nightly run: build, unit and GPU tests, the determinism script, the tour recorded and replayed for three seeds, check-project, the perf gate (1080p strict, 1440p report only),
  the scenes `aerial` and `valley` (held) and `storm` (report only), both soaks and a package test (cpack, unpack, render headless); with `NIGHTLY_DISPLAY=:90` also two live random-play sessions
  (`tools/xfuzz.py`: real X input into the window, recorded, replayed on another thread count, same hash); it writes `nightly/<date>.log`.

## Packaging
`cmake --build --preset release && cpack --config build/release/CPackConfig.cmake` writes `Voxelith-1.0.0-Linux-x86_64.tar.gz` (binary, shaders, the C++ runtime, docs, the demo level);
unpacked, `./voxelith --version` and `./voxelith --project projects/demo_level` run from the package folder (the launcher sets the library path). `cmake --install build/release --prefix dist`
does the same into a folder. Needs a Vulkan 1.3 driver (and an X server for the window; the engine loads libX11 at run time).

## Recording, replay and crash capture
```
voxelith --manual --spot 1 --record session.log          # play; the log is appended and flushed line by line
voxelith --replay session.log                            # headless: replays it and checks the end state hash
tools/determinism.sh                                     # record the demo level (a blast session and a far flight), replay each on other thread counts, compare (also a ctest)
```
The log holds the player's state each tick and every action with the numbers it was resolved to (cells, seeds). If the game crashes the log ends in a `crash`
line and replays up to the moment before it: attach it to a bug report. While recording / replaying, the effects that depend on GPU frame timing (grains that
settle into voxels, particle pushes on bodies) are off, and the world streams **by tick** instead of by wall clock (a column requested at tick T is adopted at
tick T + 30, however fast the machine generates it), so a replay is exact, also for a session that flew far beyond the streamed area. The hash covers every
resident chunk (`--hash-radius N` narrows it to N chunks around the start), the saved chunks of the world store, bodies, gravity fields, liquids, fire entries,
steam parcels, drops in flight and edits waiting for unloaded chunks. What it cannot see: the Lua script's own variables (they act through the world, so their
effects are in the hash) and the undo journal.

A recording remembers what it needs to be replayed: the level script (a copy as it was at the start, `session.log.clip/script_0.lua`, and a hash of it and of everything it
`include`s: a replay with another script given by `--lua` is refused with a message), the world save it started from (`--project` / `--save`: a copy up to 256 MB is kept as `session.log.clip/store_0.vxs` and the replay works on a temporary copy of it, so the exit save of the session does not matter), and every hot reload of the script during the session
(the new text is kept next to the log in `session.log.clip/script_N.lua`). Clips copied with O / `copy:` are kept there too. Replays need the same build
format (`# voxelith replay 2`); logs of older builds are refused. While recording, T (the orbit autopilot) does nothing: it would fire charges outside the log.

## Tests
`build/release/vx_tests` (unit), `build/release/vx_gpu_tests` (golden image, transparency, GI, TAA, particles), `ctest --test-dir build/release` (everything including the determinism replay).

## Other things to try
- **Sound** (docs/AUDIO.md), **key and controller bindings** (docs/INPUT.md), **saves and `project.store`** (docs/SAVES.md), **a game HUD from Lua** (docs/HUD.md), **mod packs** (docs/PACKS.md), **vehicles** (docs/VEHICLES.md), **walking agents and `nav.path`** (docs/AGENTS.md), **languages and subtitles** (docs/LOCALIZATION.md, docs/ACCESSIBILITY.md), **crash reports and autosave** (docs/RESILIENCE.md).
- **Playing together** (docs/NETWORK.md): `voxelith --net-host 7777 --net-players 2` on one machine and `voxelith --net-join HOST:7777` on the other (same build, same project); `--net-open --net-min 1` lets people join while it runs. Over the internet use an SSH tunnel (`ssh -L 7777:localhost:7777 host`).
- **Testing the window without a screen**: `Xvfb :95 &` then `DISPLAY=:95 voxelith --windowed ...` and `DISPLAY=:95 tools/xdrive.py key e 0.3 key F5 0.3` (ctest `window` does this; the packaged engine has `tools/xdrive.py` too).


## The packaged engine (a folder you got as a tar.gz or `cmake --install`)
```
./voxelith --project projects/demo_level          # the launcher sets the library path; bin/voxelith is the program, bin/shaders its shaders
./voxelith --mcp --project projects/mygame --threads 3    # the MCP server (docs/MCP.md); tools/voxelith_client.py talks to it from Python
./voxelith --check-project projects/mygame        # what is wrong with a project, with the line numbers
```
`assets/prefabs` (the starter kit of models), `assets/lib` (the Lua library: `include("engine/ui_kit.lua")`, `include("engine/inventory.lua")`), `docs/`, `projects/demo_level` and `tools/` (`voxelith_client.py`, `make_prefabs.py`, `make_creatures.py`: how models are generated from code; `xdrive.py`, `xin.py`, `xfuzz.py`, `window_test.sh`: driving a windowed session in Xvfb) live next to `bin/`. `--dump-materials [--materials file.csv]` writes the built-in material table (to `materials.csv` in the current directory when no file is named; it says where first).
