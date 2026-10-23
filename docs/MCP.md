# Working with the engine as an AI: the MCP server

`voxelith --mcp` runs the engine as a [Model Context Protocol](https://modelcontextprotocol.io) server on stdin / stdout (JSON-RPC 2.0, one message per line; the log goes to stderr).
An AI client (Claude Code, Claude Desktop, any MCP client) can then build worlds, run and watch the simulation, and test level scripts without a window or a person.

```
claude mcp add voxelith -- build/release/voxelith --mcp --project projects/demo_level      # Claude Code
voxelith --mcp [--project dir] [--seed N] [--world N] [--render 960x540] [--record log] [--threads N]
```
The repository has a `.mcp.json` with this server for Claude Code (it asks for approval the first time).
A packaged build (`cpack`) has `./voxelith --mcp ...` (the launcher sets the library path; docs are found next to it).

## How it behaves
- **Deterministic and one request at a time.** Nothing runs between two calls. The simulation is the same fixed 60 Hz tick as everywhere (`step` advances it); the GPU's frame timing never changes the world. Screenshots and every query are neutral:
  they never change what happens next. `math.random` in Lua is seeded with a constant, so a Lua call that rolls dice rolls the same numbers in a replay.
- **Replayable.** Start with `--record session.log` and every call that changes something (`lua`, `run_script`, `look_from`, `step`, `undo`, `save_world`) is in the log: `voxelith --replay session.log` ends with the hash `state_hash` reported.
  The log also holds the Lua code you ran (`lua_adhoc`). `state_hash` values are only comparable between sessions started with the same options (`--seed`, `--world`, `--project`, ...).
- **A clean world, no persistence.** The session starts from the generated world (or the project's level script); it does **not** read or write the project's save file or prefab registry unless you pass `--save file.vxs`
  (then it loads that file and writes it at exit; `save_world` writes it earlier). A session that builds and blasts never changes the developer's own demo save.
- **Headless.** The renderer draws offscreen; `screenshot` returns a PNG (960x540 unless `--render WxH`; no crosshair, daylight unless `time_of_day` says otherwise).
- **After a long jump** (`eye:` / `tp:` / `look_from` hundreds of metres away) the world around the new place streams in over the next ticks (about 16 columns per tick, the whole 144 m radius needs roughly 400): `step` that many ticks before a `screenshot`, or the picture shows flat pale slabs where chunks are not there yet (`status.world.loaded_radius_m` and `deferred_edit_chunks` tell).
- **Units and axes.** Lua edits are in voxels (16 per metre, 1 voxel = 6.25 cm); bodies, gravity and positions in `status` / `screenshot` / `raycast` / `look_from` are metres. y is up; `turn` is positive to the right; `pitch` is positive upward.
- **The world is as far as it is loaded.** Around the player the world exists within `status.world.loaded_radius_m` (144 m by default); farther cells read as `"unloaded"` (`query_voxels`, `slice`, `world.material_at`), and edits there wait (`status.world.deferred_edit_chunks`)
  until the chunk loads: put the player near first (`look_from`, `player.teleport`).
- **Limits.** A call runs at most one minute of wall-clock time (`partial: true` in the result when it stopped early); `ticks` is at most 36,000; Lua code is at most 1 MB and is time limited like a level script; a Lua call with `ticks: 0` changes the world only on the next tick (queries do not see it yet).
  Prints of timers and `on_tick` code go to `log`, not into the result of the `lua` call that was running when they happened.

## Tools
| tool | what it does |
|---|---|
| `status` | tick, player (feet / eye / up / forward, walk or fly), world (chunks, bricks, pool), sim (bodies, awake, burning voxels, liquid cells, gravity fields) |
| `step {ticks}` | advance the simulation (60 ticks = 1 s); fire spreads, water flows, bodies fall, Lua timers and `on_tick` run |
| `lua {code, ticks=1}` | run Lua (the level API, `docs/LUA_API.md`): a single expression returns its value, `print` output is returned, errors come back with the line. Edits apply on the tick(s) that follow |
| `run_script {script, max_ticks}` | the player's control language: `idle:60,turn:90,fwd:120,dig:14,boom:40,tp:2` (`read_docs script`) |
| `screenshot {eye, target, fov, time_of_day}` | a PNG of the player's view, or of a free camera: `eye` / `target` in **metres**, `fov` in degrees (20..120), `time_of_day` 0..1 (0.25 noon, 0.5 sunset, 0.75 midnight); a free camera is level (its up is the gravity's up at the eye) |
| `raycast {origin, direction, max_distance, through_passable?}` | first solid voxel along a ray: `origin` in **metres**, `direction` any length, `max_distance` in metres; answers the cell (voxels), the empty cell in front, the normal, the distance (metres) and the material. No hit within `max_distance` is `hit: false`; `through_passable = true` steps through walk-through voxels (stains, docs/GORE.md) |
| `query_voxels {points, units}` | material and solidity at points: `units` is `voxels` (default) or `metres`; `loaded: false` outside the streamed area |
| `describe` | a text picture around the player: distance and material along ten rays, what it stands on, the nearest bodies, fire |
| `bodies {limit}` | the loose physics bodies, largest first |
| `agents` | the walking agents (mode, position, path left) and the vehicles (position, speed, throttle, seat) |
| `gravity_fields` | the gravity fields (id and every key of `gravity_add`) and the pull at the player |
| `gravity_add {type, ...}` / `gravity_set {id, ...}` / `gravity_remove {id}` / `gravity_enable {id, enabled}` | **gravity zones** as logged actions (`gravity_define`): `type` uniform / point / line / plane / torus / spline / box / surface / null and the keys of Lua `gravity.add` (`pos half dir strength inner outer priority blend falloff ref reverse pin_camera_up round radius a b two_sided points ups mode smoothing`, `rot` as a quaternion [w, x, y, z] or `rot_deg` [x, y, z]); `gravity_set` changes only the keys given. Metres. Answers the field. Recipes below |
| `gravity_sample {points}` | the gravity at up to 64 points (metres): acceleration, strength, up, the field that dominates: check a zone by standing points inside and outside |
| `undo` / `redo` | the Z / X keys |
| `count_voxels {min, max, material}` | count the voxels of a box (**voxel** coordinates, inclusive corners, at most 8,000,000 cells) by material (assert that the wall appeared, the lava is contained, the blast reached) |
| `list_projects {root?}` / `duplicate_project {from, name, dir?}` | the project folders next to the running one (name, description, last played, valid, preview) and a copy of one under a new name (the in-game Projects window does the same) |
| `new_project {dir, name?}` | scaffold a project (project.cfg + a small level.lua), checked like `check_project`; start it with `reload_level {project: dir}` (until then `status.project` is empty). The scaffold's `project.cfg` has `terrain = flat`: an empty plain, no tower, planetoids or rooms; delete the line (or write `terrain = demo`) for the island of the demo |
| `reload_level {project?, force?}` | start over (`force: true` reloads although `--check-project` reports errors in the project: the report comes back as a warning and the level may be half built): the world is rebuilt in a fresh process with the same arguments (tick 0; unsaved edits are gone; `project` switches the project, `""` the plain demo world); the next call waits for the build |
| `export_region {min, max, name}` | save a box (**voxel** coordinates, inclusive, at most 512 per axis) as `name.vxm` in the project's models folder: a structure as data; the answer has the path, size, material counts and the Lua line that places it again (`edit.model("models/name.vxm", x, y, z [, rotation])`, minimum corner) |
| `list_models` | the model files of the models folder with their sizes |
| `define_prefab {min, max, name, parts}` | a box of the world -> a prefab: `name.vxm` with named parts (box / material / seed selectors, pivots for sockets) + a manifest skeleton `name.prefab.lua` (docs/PREFABS.md) |
| `place_prefab {name, pos, rotation?, slots?, variant?, params?, instance?}` | place a prefab (an action in the log): stamps its voxels with the slot materials and runs its `build` (nodes `INSTANCE.*`) |
| `scatter {models, box, spacing, ...}` | trees / bushes / rocks by rule over the loaded ground (docs/FOLIAGE.md); an action in the log; answers the count placed and why cells were rejected |
| `prefabs` | the placed prefabs with their slots and nodes |
| `grab {id?}` / `release` / `throw {speed?}` | the player's hand (recorded actions): hold the body in the crosshair (3.5 m, nothing in between) or the body `id`; a light body follows the view, a heavy one is dragged; throw is capped at a 500 N s impulse. `raycast` reports a body nearer than the world hit as `body` |
| `camera {mode?, focus?, pan?, zoom?, pitch?, yaw?, distance?, lift?, fov?, local_up?, climb_rate?, ticks?}` | the view camera (docs/CAMERAS.md): `mode` first / third / editor (a god view: the player stays where it is, no gravity or wall touches it, the world streams around its focus through the logged action `view_centre`); screenshots without `eye` / `target` show it |
| `select {min?, max?, units?, clear?, grow?}` | the editor's box selection (voxel corners): set, clear or grow it; with no arguments it reports size, volume and the solid voxels by material |
| `region {op, min?, max?, material?, mode?, from?, to?, clipboard?, rotation?, origin?, offset?, copy?, axis?, quarter_turns?, ticks?}` | operate on a box (the selection when `min` / `max` are left out) with logged, undoable actions: fill / delete / replace (`region_fill`, `region_replace`), copy / paste (`clip_copy`, `paste`), **move** (`offset` or `origin`; `copy: true` duplicates), **rotate** (`quarter_turns` about `axis`, or a `rotation` index; about the box's centre), **mirror** (`axis`), **array** (`count` copies, each `offset` after the one before or along `axis` x / -x / y / -y / z / -z one box length plus `gap` voxels; `region_array`, one undo step, at most 256 copies and 64 M voxels); move / rotate / mirror clear the old box and set the content into the new one, air included, and the selection follows; answers the (new) box, its hash and the solid voxels by material afterwards |
| `prefab_array {id or name, count, offset or axis + gap}` | `count` copies of a placed prefab along a direction as instances of their own (`prefab_array`, ONE undo step); hallway pieces, fence posts, floors; answers the new instances |
| `clipboards` | the session's clipboards (index, size, solid voxels) |
| `stamp {shape, material, mode?, centre, size?, seed?, up?}` | a brush stroke of the editor (the same action as a click) |
| `editor {tool?, material?, shape?, brush_size?, rotation?, selection_height?, active?}` | the editor's state (what the Tools panel shows) |
| `text {text, pos, facing?, material?, size?, spacing?, depth?, align?, mode?, color?, texture?}` | **voxel text** (docs/TEXT.md): a 5 x 7 font stamped into voxels on any face, a recorded undoable action; a letter is 31 x 44 cm at size 1 |
| `model_play {id, clip, speed?, loop?, fade?}` / `model_stop {id}` / `model_graph {id, graph, save?}` / `model_param {id, name, value}` / `model_trigger {id, name}` / `model_clips {id}` / `model_clips_edit {id, ops, save?}` | **clips, state machines and clip editing of animated models** (docs/ANIMATION.md): play a clip with a cross-fade, give a model an animation graph (states, blend spaces, transitions with conditions, layers on part of the body), set its parameters and fire its triggers, read the clips (summary, whole JSON, events, graph, state), and edit them as text: create / copy / mirror / reverse / retime clips, set and delete keys, add and delete events. Recorded actions. |
| `model_text {model}` / `model_from_text {name, spec}` / `model_check {model}` / `model_diff {a, b}` / `model_copy {model, as}` / `model_rename {model, to}` / `model_from_prefab {name, instance}` | **workspace models as text** (docs/MODEL_WORKSPACE.md "Text form"): read and write a model as a legend and layers of rows, find floating voxels and enclosed pockets, diff two models, copy, rename, and take a placed prefab into the workspace. |
| `animated_list` / `animated_spawn {file, pos, rotation?}` / `model_rig {id}` / `model_rig_set {id, roles?, joints?, clear_joints?, save?}` / `model_procedural {id, rules}` / `model_look_at {id, x, y, z \| clear}` | **animated (rigged) models and their rules** (docs/ANIMATION.md): list and spawn them, read the rig description (parts, joint limits, roles, the procedural rules that run), set roles (`"infer"` guesses from the part names) and joint limits, give a model walk / look / spring / IK rules in the JSON form of the Lua `model.procedural` table (`from_roles` starts from the roles), make its head look at a point. Recorded actions. |
| `foliage_list`| `foliage_list` / `foliage_set {name, <columns>}` / `foliage_add` / `foliage_delete {name}` / `foliage_save` / `foliage_shot {name, eye?, target?, size?, full_density?, wet?, season?, wind?, time_of_day?}` | the **ground cover table** (docs/FOLIAGE.md "Configurator"): types as JSON with the CSV column names, changed by recorded actions (the picture follows at once, the state hash does not change), saved as `foliage.csv` with the project (comments and untouched lines kept); `foliage_shot` draws one type on any ground in a box around the target and returns the PNG; `foliage_list` also names the `problems` (a material the table does not have) |
| `foliage_mask_brush`| `foliage_mask_brush {points, radius?, hardness?, opacity?, mode, type?, value?}` / `foliage_mask_fill {box, mode, type?, value?}` / `foliage_mask_info {at?}` / `foliage_mask_undo` / `foliage_mask_redo` | **painting the foliage mask** (docs/FOLIAGE.md "Painting"): strokes are recorded actions (`foliage_mask_stroke`, `foliage_mask_fill`, undo = `foliage_mask_rect`); modes `type` (the named type grows on any ground), `height`, `density`, `erase`; the first stroke of a project makes a typed mask (`foliage_mask.png`, 2048 x 2048 texels of 0.5 m) saved with the project; the state hash does not change |
| `wear_info` | `wear_info` / `wear_clean {box}` / `snow {amount, falling}` | **wear** (docs/WEAR.md): the setting, the table rows, the cell / track counts and caps; `wear_clean` (recorded action) restores the tracks in a metre box and forgets its worn cells; `snow` (recorded action, like `rain`) sets the weather snow (render only) and whether it is falling (the wear system refills trodden snow while it does) |
| `biome_map` | `biome_map {centre, size_m, pixels}` | the **world generator** (docs/WORLD_GEN.md): a top-down PNG of what it makes (biome colours, slope shading, lakes and rivers, snow) and the share of each biome as JSON, from the pure functions: nothing is loaded, no GPU |
| `gen_preview` | `gen_preview {expr, centre, size_m, pixels, seeds}` | a rule (an expression like `slope > 0.3 && moist < 0.4`) compiled in the project's context and evaluated over a square for up to eight seeds: a picture strip and per seed min, max, mean, percentiles, share of non-zero values; for choosing noise wavelengths and thresholds without a GPU |
| `gen_histogram` | `gen_histogram {expr, centre, size_m, samples, bins}` | the distribution of a rule's values (how often does it fire) |
| `gen_cost` | `gen_cost {}` | per biome row and rule cell: ops, noise calls, estimated ns; the worst row in ms per column against the 4 ms budget |
| `worldgen_info` | `worldgen_info {x_m, z_m}` | everything the generator decides at one column: ground before and after the water, biome and weights, climate, slope, water, the materials the rules gave and each rule's value ("why is this sand") |
| `gen_reload` | `gen_reload {}` | re-reads the project's generator keys, biomes.csv (rules, mask) and features.csv, compiles them first (a problem refuses and changes nothing), evicts and regenerates the world around the player (docs/WORLD_GEN.md "Hot reload"); refused while recording, replaying, in a net session, for a non-biomes world and when the world would get taller |
| `biome_mask_brush` | `biome_mask_brush {centre, radius_m, biome, relief_m}` / `biome_mask_undo` / `biome_mask_redo` / `biome_mask_info` | the **biome painter** (docs/WORLD_GEN.md): paints a disc of the world with a biome (or the climate) and optionally a base height, saved in the `@mask` PNG of biomes.csv; the columns under the stroke are made again; refused in recordings, replays and net sessions |
| `emitter_list` / `emitter_create {name, preset?, pos?, shape?, kind?, rate?, ...}` / `emitter_set` / `emitter_delete` / `emitter_enable` / `emitter_burst` | **emitters** (docs/EMITTERS.md): particles by rule (flames, smoke, steam, sparks, grains) with an optional light, from presets (torch, campfire, chimney_smoke, steam_vent, fireflies, dust_motes, magic_sparks, embers, sand_fall) or every key; recorded actions, kept in the project's `emitters.json` |
| `texture_list`| `texture_list`| `texture_list` / `texture_define {name, kind, scale?, width?, seed?, color?, color2?, pixels?, palette?}` / `texture_delete {name}` | the per-voxel **textures** (docs/TEXTURES.md): the project's table (built-ins: smooth brick planks tiles blocks stripes speckle noise checker big_tiles big_bricks fine_planks hazard heart grid), a texture is a procedural pattern or an 8 x 8 pixel tile, kept in `textures.json` at the next save; `paint` and `region {op: paint}` take `texture` (a name, an id or `none`), `query_voxels` shows it |
| `paint {shape?| `paint {shape?, centre, to?, size?, up?, color?, texture?, ticks?}` / `paint_palette {named_only?}` | **paint** (docs/PAINT.md): colour solid voxels (a sphere, cube, disc or box) with one of 255 palette colours, by name, `#rrggbb` or index (`none` clears); the material's pattern stays; a recorded, undoable action. `region` has `op: "paint"` too |
| `model_new {name, size, replace?}` / `model_edit {model, ops}` / `model_view {model, size?, turns?, layers?}` / `model_info` / `model_undo` / `model_remove` | the **model workspace** (docs/MODEL_WORKSPACE.md): small voxel models in memory, apart from the world; boxes, spheres, cylinders, lines, mirror, symmetrize, rotate, paste, flood ...; a picture and a text view; one process per agent builds prefabs in parallel |
| `model_define {model, file?, parts, manifest?, overwrite?}` / `move_model {file, to, overwrite?}` | a workspace model becomes a **prefab with parts and a manifest without being stamped** (docs/MODEL_WORKSPACE.md); models and manifests live in folders (`nature/oak`): `move_model` sorts them (docs/PREFABS.md) |
| `model_save {model, file?, overwrite?}` / `model_load {file}` / `model_from_region {name, min, max}` / `model_to_world {model, origin, rotation?}` | a workspace model to a `.vxm` in the models folder (it shows in the Prefabs gallery), back from a file or a box of the world, and into the world (a recorded `paste`) |
| `prefab_pick {cell}` | the placed prefab that owns a world cell (what clicking it selects): the outermost instance whose stamped voxels include it; its box (`min` / `max`), rotation, variant, slots and parameter overrides |
| `prefab_move {id or name, offset? / origin?, quarter_turns? / rotation?, copy?}` | move, turn (about the box's centre) or copy a placed prefab as a whole: it is placed again with what it was placed with, its nodes are declared again; one recorded action, one undo step (undo and redo bring the registry back with the voxels) |
| `prefab_set {id or name, variant?, slots?, params?}` | change a placed manifest prefab where it stands (another variant, slot materials, parameters); placed again with the result |
| `prefab_delete {id or name}` | delete a placed prefab with the prefabs inside it and the nodes they declared |
| `events` | the event system: every node (kind, level, state), the connections and the waiting deliveries |
| `event_create {kind, name, ...}` / `event_set {name, ...}` / `event_delete {name}` / `event_connect {from, signal, to, command, arg?, delay?}` / `event_disconnect {from, to}` | **authored events** (docs/EVENTS.md "Authoring"): create buttons, levers, volumes, timers, logic, lamps, doors, gravity targets, spawners, effects, emitters and conveyor belts (`kind: "belt"`, `dir`, `speed`, `texture`: docs/CONVEYOR.md) as objects and connect them, as logged actions; kept in the project's `events.json` and declared again at every start. Same keys as the Lua `events.*` calls (`box` in voxels, materials by name) |
| `trigger {id or name, signal?}` | press a button (signal on), or inject an edge (on off pulse stay) into any node: a door opens / closes, a lever or lamp switches on / off, pulse flips a lever; a volume takes only pulse and stay; a recorded action, takes effect on the next tick |
| `event_command {id or name, command, arg?}` | open / close / toggle / on / off / press / enable / disable a node; a recorded action |
| `verify_gpu {radius?}` | debug: uploads everything, then compares the GPU's copy of the world (directory, chunk records, bricks) with the CPU world around the player |
| `particles {limit?}` | debug: the live voxel particles read back from the GPU: counts by class, and the slow debris / grains (where they hang, what is below them, the gravity there) |
| `region_hash {min, max}` | a hash of a box's voxels (**voxel** coordinates, inclusive, at most 8,000,000 cells): a level's regression test (`hash == N`) |
| `find_material {material, near, radius, limit}` | the voxels of a material nearest to a point, with distances: `near` in **voxels**, `radius` 1..100 **voxels** (an error outside, not clamped), `limit` 1..1000 results (default 10); where is the lava, is there metal left |
| `slice {axis, at, min, max, step}` | a character map of a plane (letters per material, `.` air, `?` unloaded): `axis` is the axis held fixed at voxel `at` (`y` = a top view), `min` / `max` are the two *other* coordinates `[u, v]` in voxels (for `y`: x, z; for `x`: z, y; for `z`: x, y; at most 160 x 100 cells, `step` takes every n-th); a picture a text-only model can read |
| `step_until {condition, max_ticks}` | run until `bodies_asleep`, `fire_out`, `liquid_settled` or a `tick`; says why it stopped |
| `look_from {eye, target, mode}` | put the player at a point looking at another (**metres**; `mode` walk or fly): where `dig` / `boom` / `fire` act and what the player's `screenshot` shows |
| `list_materials` | the material table (id, name, liquid, transparent, anchor, flammability, density) |
| `state_hash` | the simulation hash (what a replay ends with); takes a second or two |
| `log {lines}` | the engine's recent log lines: Lua prints, warnings and errors |
| `save_world` | save the edited chunks (an action in the log) |
| `read_docs {topic}` | `mcp`, `lua_api`, `script`, `guide` |
| `check_project {dir}` | validate a project directory (the report of `--check-project`, with a dry run of its level script) |

The same documents are MCP resources: `voxelith://docs/mcp`, `lua_api`, `guide`, `script`.

## A first session
1. `status`: where is the player (metres), how far is the world loaded. `read_docs lua_api` once.
2. `screenshot`: the player's view. A free camera: `screenshot {eye: [x, y+6, z-14], target: [x, y+2, z]}` with the player's feet (x, y, z) from `status` (the player does not move).
3. Build a hollow brick hall on flat ground (voxels, 16 per metre): `lua "local x, y, z = world.flat_spot(12, 12); edit.box(x+32, y, z+32, x+160, y+48, z+160, 'brick'); edit.clear(x+40, y, z+40, x+152, y+40, z+152); return x .. ' ' .. y .. ' ' .. z"`
   (`world.flat_spot(w, d)` returns the corner of a flat, dry, free area of w x d metres near the player). Look at it with a free-camera `screenshot`.
4. Break it. Blasts act where the player looks: `look_from {eye: [(x+8)/16, (y+20)/16, (z+96)/16], target: [(x+34)/16, (y+20)/16, (z+96)/16], mode: "fly"}` puts the player next to the hall's west wall looking at it, `raycast` confirms (`material: brick`),
   `run_script "boom:60,idle:120"` blasts it. `count_voxels {min: [x+32, y, z+60], max: [x+39, y+40, z+130], material: "brick"}` before and after says how much wall is gone; `bodies` lists the pieces; `screenshot` shows them.
5. `step_until bodies_asleep`, `screenshot`, `state_hash`.
Level scripts: edit `projects/<name>/level.lua` with the file tools, `check_project`, restart the server with `--project`. (A changed script file also hot-reloads while the server runs, except in a replay; while recording the reload is logged with a copy of the file.)
This sequence is what `tools/mcp_smoke.py` runs, so the guide cannot drift from the server.

## From Python
`tools/voxelith_client.py` is a dependency-free client with one method per tool:
```python
from voxelith_client import Voxelith
with Voxelith(["--project", "projects/demo_level"]) as v:
    v.lua("local x, y, z = world.flat_spot(10, 10); edit.sphere(x + 80, y + 40, z + 80, 24, 'brick')")
    v.run_script("turn:90,boom:40,idle:120")
    v.screenshot("shot.png", time_of_day=0.25)
    print(v.state_hash())
```

## Limits and notes
- One call advances at most ten minutes of simulation (36,000 ticks). A Lua call is time limited like a level script.
- The world is whatever the session started with (`--seed`, `--world`, `--project`); there is no reset call yet (TASKS.md): restart the server for a fresh world. The server's default `--threads` is 7 workers (`.mcp.json` asks for 3).
- The screenshot camera does not move the player; far terrain shows as the distant levels of detail. Ask for `time_of_day` 0.25 for daylight.
- Checks: `tools/mcp_smoke.py` (part of the test suite) speaks the protocol to a real server, runs a session, takes screenshots and replays a recorded session.

## Gravity zone recipes
The three arrangements of the demo, as tool calls (a field is read back with `gravity_fields`, checked with `gravity_sample`):
- **Flip room** (gravity up inside a box): `gravity_add {type: "uniform", name: "flip room", pos: [30, 12, 50], half: [5, 3.5, 5], dir: [0, 1, 0], strength: 9.81, outer: 0.6, priority: 20}`; `gravity_set {id, dir: [0, -1, 0]}` flips it back.
- **Habitat tube** (walk on the inside of a cylinder): `gravity_add {type: "line", name: "habitat tube", a: [97, 20, 40], b: [143, 20, 40], reverse: true, inner: 6.5, outer: 7.0, strength: 9.81, priority: 20}`: the pull points away from the axis (reverse), full strength out to the wall at 6.5 m, none beyond 7.0.
- **Twist tube** (the floor turns while you walk along): `gravity_add {type: "spline", mode: "up", pin_camera_up: true, points: [[10, 20, 70], [20, 20, 70], ...], ups: [[0, 1, 0], [0, 1, 1], [0, 0, 1], [0, -1, 0]], inner: 3, outer: 4.2, strength: 9.81, priority: 20}`: `ups` is the up direction at each control point, interpolated along the spline.
- **Weightless pocket**: `{type: "null", pos, half, outer: 2}`; **a small planet**: `{type: "point", pos, strength: 5, inner: radius, outer: radius + 6, falloff: "inverse_square", ref: radius, blend: "add"}`.
In the editor the Gravity window makes a box, sphere, tube or weightless zone from the selected box (docs/EDITOR_MODE.md "Gravity zones").


### Pictures: `hud`, `settle`
`screenshot {hud: true}` draws the level script's `on_hud` over the picture (an idle input; docs/HUD.md). `screenshot {settle: N}` (0..600) is how many frames the lighting gets before the picture: the global illumination traces a few thousand probes a frame and an MCP session renders only the frames of its pictures, so the default is 90 after the camera moved more than 6 m since the last picture and 6 when it stayed (a first picture of a room is otherwise lit by the sky and a torch's light has not spread). `input_action {name, down, player}` presses a custom input action (docs/INPUT.md).
