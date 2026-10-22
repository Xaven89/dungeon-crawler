# Prefabs and foliage

> **Status (2026-10-19): Part A phase 1 is built** (docs/PREFABS.md describes what exists; differences: no nesting, no `box_at` variants beyond the floor-at-pivot form, `ctx.box` takes a part list, `moving` parts and `part = {..}` lists for doors). **Part B: `scatter{}` is built (docs/FOLIAGE.md); the ground-cover type table is built too (docs/FOLIAGE.md).** Written by the fable session against commit f54160d, answering the user's questions: can a door be a prefab, is a general prefab system a good idea, can foliage be extended with rules and mixes. Order recommended: HINGES phase 1, prefabs phase 1, HINGES phase 2, foliage scatter, ground-cover table (see docs/HINGES.md).


Written against 4257889 (read-only). Part A answers the prefab questions, Part B the foliage ones, the end gives the order, the cut list and what changes in docs/HINGES.md.

## Verdict

- **Prefabs: yes, as a thin layer over four things that already exist** (tracked prefabs in `app/prefab.*`, VXM2 rigs whose *parts* are named voxel groups with a per-part material override, the event system's nodes by name, Lua). What is missing is small and well defined: a **manifest** next to the model (material slots, sockets, variants, the nodes the prefab brings), **per-instance material slots at stamp time**, **instance-scoped node names**, and the bookkeeping that removes a prefab's nodes with its voxels. A swing or sliding door with its button, lamp, plate and hinge is exactly such a prefab, in wood, metal or glass, by slots. **Cost: about a week**, no engine subsystem changes.
- **Not worth it: size parameters.** Voxel models do not scale; a "door 20 or 28 voxels wide" is two models (variants), and a stretchable door (a nine-slice of voxels) buys little for its complexity. Variants cover it.
- **Foliage: two different things.** Trees and bushes are **world voxels** (worldgen's `addTree`, or a model placed by Lua: Lantern Cove already does `edit.model("models/tree_small.vxm", ...)`), fully in the edit pipeline, destructible, flammable, in the far levels. New tree types **are already data** (a model file); what is missing is a **scatter rule** (where, how dense, which mix, what to avoid). Ground cover (tufts, flowers) is **GPU-only, stateless, rebuilt every frame from the top faces of grass voxels**: no CPU state, no collision, no fire, no determinism concern, and new types need shader work; a small type table makes it data-driven later. **Cost: scatter rules a few days; a ground-cover type table a few days of GPU work; biomes and painted density maps are a later phase.**
- **Unify?** A tree is a prefab (a model, later with trunk / canopy parts) placed by a scatter rule, so the *tree side* of foliage is Part A plus one placement API; **ground cover stays separate** (instances, not voxels, not prefabs).
- **Order:** HINGES phase 1 (the kinematic swing door) first: it fixes the shape of a door definition; then prefabs phase 1; then HINGES phase 2 and the foliage scatter in either order. Prefabs change one thing in HINGES.md: the door body should be one *part* of the model (the panel), the rest (frame, handle) stays stamped.

## Part A: prefabs

### A1. What exists, and what each piece gives

| piece | gives | lacks |
|---|---|---|
| `PrefabSystem` (`app/prefab.*`) | a named, tracked instance of a `.vxm` / `.vox` at an origin and rotation; voxel-exact re-stamp when the source changes; adoption from a saved world; removal that only takes back the stamp's own voxels (`ClearIfEqual`); state in `<project>/.prefabs/tracked.txt` + a snapshot per instance; the logged action `prefab` (file as text) so a placement replays; `reconcile` after undo; UI list | no parameters (the same file always stamps the same voxels), no logic, no points of interest, no variants |
| `.vxm` v2 rigs (`world/rig.hpp`) | **named parts** (a part map per voxel: a named voxel group), a **per-part material override**, **pivots** on the voxel grid, clips; tagging by box / material / connectivity in the model editor; validated and hot-reloadable | the override is used by the animated models only: `edit.model` and `prefab.place` ignore parts; pivots are animation pivots, not general sockets |
| `edit.model` / vxm loader | materials by name (a model made against one table loads into another) | no remap at placement |
| `export_region` (MCP) | a box of the world as a `.vxm` with the Lua line that places it | no parts, no manifest |
| event nodes (`events.*`) | nodes by name, adopted by name, saved state by name, connections de-duplicated | names are global: two doors from one script need two names by hand; nothing ties a node to the geometry it sits on |

So "a reusable door in wood, metal or glass with its button and hinge" is: a VXM2 with parts `frame`, `panel`, `handle` (material slots) and pivots `hinge`, `handle`, `plate` (sockets), plus a manifest that says which slots exist, what the defaults are, which variants there are, and a build function that declares the nodes with the instance's name as a prefix and the sockets as positions.

### A2. The recommendation

**One file pair in the models folder:** `door.vxm` (VXM2: parts and pivots made in the model editor or by `define_prefab`) and `door.prefab.lua` (the manifest: a Lua chunk returning a table; Lua because the logic half needs expressions anyway and the engine already has the sandbox, the hot reload, the hash and the instruction limit; a static text format would grow into a language).

```lua
-- models/door.prefab.lua
return {
    model = "door.vxm",                                  -- VXM2 with parts frame / panel / handle, pivots hinge / handle / plate
    variants = { wide = "door_wide.vxm" },               -- same parts and pivots, other sizes
    slots = { frame = "metal", panel = "wood", handle = "metal" },   -- material per part, overridable per instance
    params = { swing = true, open = 90, prompt = "Open the door" },  -- free parameters with defaults (numbers, strings, booleans)
    build = function(ctx, p)                             -- runs at placement; ctx is the instance: name, origin, rotation, boxes and cells in WORLD voxels
        local door
        if p.swing then
            door = events.door{ name = ctx.name("door"), model = ctx.model, part = "panel", hinge = { axis = "y", at = ctx.cell("hinge"), open = p.open } }
        else
            door = events.door{ name = ctx.name("door"), box = ctx.box("panel"), travel = ctx.dir({0, 1, 0}, ctx.height("panel")), speed = 2 }
        end
        local plate = events.volume{ name = ctx.name("plate"), box = ctx.box_at("plate", 20, 2, 20), player = true, bodies = true }
        events.connect(plate, "enter", door, "open")
        events.connect(plate, "exit", door, "close", { delay = 60 })
        return { door = door, plate = plate }            -- handles the level script may wire further
    end,
}
```
```lua
-- a level
id, h = prefab.place("door", x, y, z, { rotation = 1, slots = { panel = "glass" }, variant = "wide", params = { prompt = "Enter" }, name = "front_door" })
h.door --> the node id;  prefab.remove(id) also removes front_door.door and front_door.plate
```

What is voxel data and what is logic: the `.vxm` is voxels + parts + pivots (data; the model editor and `define_prefab` make it); the manifest's `slots / params / variants` are data; `build` is logic. The prefab system stamps the **voxels** (rotated, then remapped by slot through the part map: `partOf[i]` -> slot -> material), the manifest's `build` declares the **nodes**. The snapshot stored per instance is the remapped, rotated model, so re-stamp, removal and adoption work exactly as today with no change.

**Engine changes (small, all in app / script):**
- `PrefabSystem::place(..., const std::vector<std::pair<std::string, u16>>& slots, const std::string& variant)`: loads the rig (`loadRig`; a VXM1 is a one-part rig), applies the overrides by part name into a plain model, rotates, stamps as today. `tracked.txt` gets two more fields: `slots` (`panel=glass,frame=metal`) and `variant`; `PrefabInfo` too.
- `prefab.place(name, x, y, z, opts)` in Lua: resolves `<models>/<name>.prefab.lua` (no manifest: today's behaviour), runs it (cached per file, re-read on hot reload), merges `opts.slots / params`, calls the C++ placement, then `build(ctx, p)` with `ctx` = { name(suffix) -> "<instance>.<suffix>", model (the variant file), origin, rotation, box(part) (the part's world box after rotation), cell(pivot) (a pivot's world cell), box_at(pivot, sx, sy, sz), dir(v) (a model-space direction rotated), height(part) }. The returned table is given back to the caller.
- Instance naming: the instance name is `opts.name` or `<prefab>_<n>` (n from the tracked list, deterministic); node names are `<instance>.<suffix>`; `prefab.remove(id)` removes every node whose name starts with `<instance>.` (the event system gets `removePrefix`), and the tracked record remembers the suffixes it declared.
- Replay: the logged `prefab` action already carries the file as text and numbers; add `slots` and `variant` to the text (`door.vxm|panel=glass|wide`) and `params` as a short `k=v` list. The `build` function runs on the same action in the replay (the manifest file is copied into `<log>.clip/` like the models are). Node ids are sequential in declaration order on both sides.
- Undo: a placement is one undo group (voxels), as today; nodes are not undone (EVENTS.md section 7: `reconcile` after undo makes lamps / doors adopt the voxels). A removal is one group too; its nodes go at once and come back only through `prefab.place` again (the same as a removed prefab's voxels: an undo brings the voxels back and `reconcile` re-tracks the prefab, so let `reconcile` also call `build` again for a revived instance).
- Save and reload: the tracked record (file, origin, rotation, slots, variant, params) is enough to rebuild everything; the level script's `prefab.place` on a later run adopts by name (same spot, same snapshot) and re-runs `build`, whose nodes adopt by name with their saved state. Nothing new in the save format beyond the two fields.
- Determinism: the manifest runs under the Lua host (hashed into `lua_hash` together with the script: add manifest files to `sourceHash()` and to the recorder's copies); the stamp is an `EditOp::setModel` like today; the nodes are declared in a fixed order.
- The hinge in the prefab is a node of the door (HINGES.md), declared by `build` from a socket: nothing new in the physics layer.

**What stays out:** nesting (a prefab placing prefabs: easy later: `prefab.place` inside `build`, with the child's name prefixed), size parameters (variants instead), prefab-level undo of nodes, a prefab browser UI beyond the existing list.

### A3. The AI route

`export_region` already makes a model from a box; two additions make it a prefab:
- `define_prefab {min, max, name, parts = [{name, box | material | seed_cell}], pivots = [{name, cell}], slots?, params?}`: `copyRegion`, tag parts (the rig's `assignBox / assignMaterial / assignConnected`, the same calls the model editor makes), set pivots, save as VXM2, write a manifest skeleton with the slots defaulting to each part's majority material and an empty `build` with a comment listing the sockets. The answer is the Lua line that places it.
- `place_prefab {name, pos, rotation, slots, variant, params, instance}`: the `prefab` action; `prefabs {}` lists instances with their nodes. `check_project` runs every manifest in the dry run (as it runs the level script).

## Part B: foliage

### B1. What exists

- **Trees** (`worldgen.cpp:113` `addTree`, placed from a jittered 7 m grid on grass between sea level and base + 300 voxels, seeded by `hash3`): a wood box trunk and a leaves sphere, submitted as feature ops. They are world voxels: carving the trunk drops the canopy (detach analysis), fire spreads through `Leaves` (flammability in the material table), the far levels get them through `scaleOpToLevel` / `LodUpdater`, undo and the save see voxels. A project with `terrain = flat` has none; Lantern Cove places `tree_small.vxm` by `edit.model` from Lua: **a tree type by data exists today**.
- **Ground cover** (`shaders/foliage_ground.comp`, `foliage_splat.comp`, `foliage.glsl`): a camera-centred grid of 384 x 384 cells of 2 x 2 voxels (24 m radius, `foliageRadius`), one vertical ray per cell per frame, a tuft wherever the ray hits **the top face of material id 3 (Grass)**, 60 % of the cells, three blades of up to eight half-voxel cubes with heights from a patch hash, wind, disturbers (player, bodies). Nothing is stored; nothing is simulated on the CPU; nothing collides or burns (the grass voxel burns instead). Types are the materials Tuft / TuftDry / TuftDark / Flower*, chosen by hash in the shader.
- The design doc's two-tier plan (canopy clusters as instances, trampling, regrowth, kill masks) is not built; trees are plain voxels, which the handover decided to keep ("trees are voxels: fire, collision, AO, GI already work").

### B2. Answers

1. **New types by data?** Trees and bushes: yes, now: a model file (and, with Part A, a prefab with trunk / canopy parts and a `root` pivot). Ground cover: C++ / GLSL today. To make it data: a **type table** uploaded with the foliage params (16 entries: grows-on material, min / max height class, cube widths, blade count, material per cube band, density, wind stiffness) and the ground pass reading `type = rule(surface material, hash)`; a `foliage.csv` in the project next to `materials.csv`. Moderate GPU work, no CPU state.
2. **Placement rules: where they live.** Trees: a **scatter API in C++ with a Lua binding**, run by the level script on the first run (so the result is edits, saved as voxels, replayed as script): `scatter{ models = {{"models/oak.vxm", 5}, {"models/birch.vxm", 3}, {"models/bush.vxm", 2}}, box = {...}, spacing = 112, jitter = 0.6, density = 0.5, on = {"grass", "dirt"}, height = {sea + 6, sea + 300}, slope_max = 0.6, water_within = {0, 40} | nil, avoid = { {box}, {box} }, clearings = { scale = 400, threshold = 0.35 }, seed = 7, rotations = true }`. The C++ side walks the jittered grid like worldgen does (`hash3(gx, gz, seed)` decides, so the result depends only on the parameters and the world content it samples: `world.top`, the surface material, a slope from four neighbouring tops, the nearest water within N voxels from a column scan), and submits `setModel` ops. Biomes do not exist; "biome" in phase 1 is the `box` plus the predicates; a painted density mask (a `.vxm` slice or a PNG read as a mask) is the phase 2 way. Ground cover rules live in the type table (grows-on material, slope), not in Lua: the GPU decides per frame.
3. **Mixing:** a scatter call takes a weighted model list and `rotations` (the 4 upright axis rotations) as variants; several calls layer a forest (trees at 7 m spacing, bushes at 3 m with `avoid` the tree footprints, which the first call returns as boxes). Ground cover mixes by the type table's per-material weights.
4. **Determinism, LOD, destruction, pipeline:** trees are edits: deterministic from the seed and the world content, in the far levels, cut and burnt like any voxel; cost of a new type = a model file; a big forest is a large first-run build (20,000 trees of 5,000 voxels is 100 M voxel edits, about a second on six threads, and the edited columns go into the save: the whole plain becomes "edited", which the store compresses but stores). Ground cover is not voxels: no state, no save, no hash, no collision, no fire; cost of a new type is shader work once the table exists.
5. **Unified?** The tree side: yes, a scatter rule places prefabs / models, nothing else; ground cover: no.

### B3. Traps in the foliage code

- `foliage_ground.comp:28` tests `(hit.voxel & 0xffff) == 3u`: Grass by hard-coded id. A project's material CSV that renumbers or adds `moss` grows nothing; the type table replaces this with a per-material rule (the materials buffer can carry a `cover type` byte).
- The tuft shapes, heights and materials are hash constants in `foliageCube` (`foliage.glsl`): any new look is shader code until the table exists.
- Ground cover pops in at 24 m (`foliageRadius` 380 voxels, LOD to one blade at 10 m and every other cell at 19 m): forests of tufts are a near-field effect by design; do not promise a meadow to the horizon.
- Far levels are a majority vote: a canopy (a sphere of leaves, mostly air around thin branches in a real model) can vanish beyond 136 m; a bushy, solid canopy model survives, a sparse one does not. Make tree models with solid crowns.
- The worldgen trees are feature ops with source 1 at tick 0: a scatter from Lua on a `terrain = demo` world lands on top of them unless `avoid` lists them (worldgen does not export their positions; `scatter` could skip columns whose top is `Leaves` / `Wood`).
- A forest of models placed by `edit.model` is one `setModel` op each: thousands of ops in one flush are fine (ops are chunk-routed), but `kMaxEditVolume` and the per-call Lua instruction limit (20 M) bound one call: scatter in C++, not in a Lua loop.

## Order, phases, cuts

- **Order:** HINGES phase 1 -> prefabs phase 1 -> HINGES phase 2 -> foliage scatter -> ground-cover table.
- **Prefabs phase 1:** VXM2 parts honoured by `prefab.place` with slots; the manifest (`.prefab.lua`) with `slots / params / variants / build` and the `ctx` helpers; instance names and `removePrefix`; tracked fields; the `prefab` action text; `define_prefab` / `place_prefab` / `prefabs` tools; `check_project` dry-runs manifests; a door prefab (sliding, wood / metal / glass) in the demo and the cove. Tests: slot remap through the part map; a manifest that declares two nodes, placed twice (names `a.door`, `b.door`), removed (nodes gone), replayed; adoption on a second run with saved node state; `define_prefab` round trip.
- **Foliage phase 1:** `scatter` in C++ (`sim/scatter.*`, a pure function of parameters + world reads returning the ops) with the Lua binding and the MCP tool `scatter {}`; a forest in the cove; tests: same parameters twice give the same positions, predicates (water, slope, avoid), spacing, a determinism case.
- **Cut:** size-parametric prefabs; prefab nesting (later); canopy instances; ground-cover physics, fire and regrowth; painted biome maps (phase 2); a scatter that runs at stream time (worldgen integration: trees would then be procedural at every distance, but it needs the generator to read models and a per-level scaling of them: a bigger change, not needed while levels are built once and saved).

## What changes in HINGES.md because of prefabs

- The door definition takes `model` + `part = "panel"`: the moving body is one part of the model, the frame and the handle are stamped voxels that stay. Today the whole model is the slab; with parts a door prefab is one model. `buildBodyFromVoxels` over the part's voxels (the rig's `partModel`) gives the body.
- The hinge axis comes from a pivot (`ctx.cell("hinge")`) rather than a hand-typed cell; the handle socket is where the grab's `use` on the door body is expected (cosmetic: the body is grabbable anywhere).
- Nothing else: the hybrid at-rest / in-motion model, the solver additions and the player push are unchanged.
