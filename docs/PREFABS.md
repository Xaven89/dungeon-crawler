# Prefabs

A prefab is a reusable structure with parts, material slots, sockets and the logic that goes with it (event nodes). It is a thin layer over the tracked prefabs
(`app/prefab.*`: voxel-exact stamp, adoption from a saved world, re-stamp when the file changes, undo), rig models (named parts), and the event system.
The design is in `docs/PREFABS_FOLIAGE.md` (part A); this page is how to use what is built.

## Two files in the models folder
`door.vxm` is a model with **parts** (made in the model editor, or by the MCP tool `define_prefab` from a box of the world). A part is a named group of voxels; a part without voxels is a
**socket**: its pivot is a place (a hinge, a plate, a spawn point). `door.prefab.lua` is the manifest (Lua, returns a table):

```lua
return {
    model = "door.vxm",
    variants = { wide = "door_wide.vxm" },                    -- other files with the same parts and pivots
    slots = { frame = "metal", panel = "wood" },              -- the material of each part (per placement overridable)
    moving = { "panel", "handle" },                           -- parts that move on their own afterwards (a door's panel): adopting a saved world does not look for them
    params = { open = 90, plate = true },                     -- free parameters with defaults
    build = function(ctx, p)                                  -- runs on every placement (also when the world already has the voxels): declares the nodes
        local door = events.door{ name = ctx.name("door"), prefab = ctx, part = { "panel", "handle" },
                                  hinge = { axis = "y", at = "hinge", open = p.open, seconds = 0.8 } }
        local plate = events.volume{ name = ctx.name("plate"), box = ctx.box_at("plate", 24, 4, 12), player = true, bodies = true }
        events.connect(plate, "enter", door, "open")
        return { door = door, plate = plate }
    end,
}
```
`models/door.prefab.lua` and `models/door.vxm` of the demo level and Lantern Cove are the worked example (a swing door in a metal frame with a plate).

## Folders
Models and manifests can be sorted into **folders** of the models folder: `nature/oak.vxm`, `buildings/door.prefab.lua` (a path is one to four segments of letters, digits, `_` and `-` joined by `/`; 120 characters at most; no `..`, no absolute paths). Everywhere a model or prefab name is taken, a folder path works: `prefab.place("buildings/door", x, y, z)` (an instance without a `name` is called after the whole path, `buildings_door_1`, so that `props/door` is another instance), `place_prefab`, `place_model {file: "props/bench.vxm"}`, `model_save {file: "props/bench"}`, `model_define`, `define_prefab`, `export_region`, `model_load`. A manifest's `model = "buildings/door.vxm"` is a path from the models folder, not from the manifest's folder. The Prefabs gallery groups its pictures by folder (a collapsible header per folder, what has no folder first); `list_models` shows the paths. **`move_model {file, to}`** moves a model (and its manifest, with its own `model = ...` line rewritten) to another path: it is refused while a placed prefab was made from the file, and it lists the *other* manifests that still name the old path. Hidden folders (`.name`) are not listed. The engine's starter kit is in folders too (nature, buildings, props, structures); a plain name still finds a kit model (`oak.vxm` finds `nature/oak.vxm`), and a kit model is copied into the project with its folder.

## Placing
```lua
id, h = prefab.place("door", x, y, z, { rotation = 0, name = "front", slots = { panel = "glass" }, variant = "wide", params = { open = -90 }, carve_air = false })
h.door --> the node id (what build returned);  prefab.remove(id)  -- the voxels, and every node called "front.*" (a door's slab where it stands)
```
`(x, y, z)` is the minimum corner of the (rotated) model. Without `name` the instance is called `door_1`, `door_2` ... in the order of the unnamed placements of that manifest in the script (the same on every run).
Placing again with the same name, spot, rotation and slots **adopts** what the world already holds (nothing is stamped) and runs `build` again; its nodes adopt by name with their saved state.
A changed model file or other slots/rotation/spot re-stamps (the old stamp's voxels go, only those that still are what the stamp put there). The plain form `prefab.place("models/x.vxm", x, y, z [, rotation [, name [, carve_air]]])` is unchanged.
Slots name parts: an unknown part is an error listing the model's parts.

## What `build` gets (`ctx`)
| | |
|---|---|
| `ctx.name("door")` | `"<instance>.door"`: node names of an instance never collide |
| `ctx.box("panel")` / `ctx.box({"panel", "handle"})` | the world box `{x0, y0, z0, x1, y1, z1}` around the part(s) after rotation |
| `ctx.cell("hinge")` | the world cell that holds a part's pivot (a socket's place) |
| `ctx.box_at("plate", sx, sy, sz)` | a box centred on the socket's cell in x and z, floor at its y |
| `ctx.place("door", dx, dy, dz [, opts])` | a prefab inside this one: `dx, dy, dz` voxels from this instance's origin (world axes), named `<instance>.<name>` (its nodes `<instance>.<name>.<suffix>`); `prefab.remove` of the parent takes the children with it |
| `ctx.dir({0, 0, -1})` | a model-space direction turned by the placement's rotation |
| `ctx.origin`, `ctx.size`, `ctx.rotation`, `ctx.instance`, `ctx.model` | where, how big (of the rotated model), which one |
| `events.door{ prefab = ctx, part = "panel" | {...}, hinge = { axis, at = "hinge" | {x, y, z}, open, seconds } }` | the swing door's slab is the part(s)' voxels (with the slot materials); the axis is the socket's cell |

## Tools (MCP)
`model_define {model, file?, parts, manifest?, overwrite?}` makes a prefab from a **workspace model** without stamping it into the world (docs/MODEL_WORKSPACE.md): the same parts as `define_prefab`, in the model's own coordinates, and optionally the Lua text of the whole manifest; `move_model {file, to}` sorts models into folders;
`define_prefab {min, max, name, parts}`: box of the world -> `name.vxm` with parts (`box` / `material` / `seed` selectors in world coordinates, `pivot` for sockets, tagged in order) + a manifest skeleton (never overwritten);
`place_prefab {name, pos, rotation?, slots?, variant?, params?, instance?}` (an action in the log); `prefabs` lists instances and their nodes. `check_project` places every manifest once on flat ground and runs its `build`.

## The door prefab
`door.prefab.lua` (demo level, Lantern Cove): params `open` (90 / -90), `seconds`, `plate`, `close_delay`, `auto_close`, and for a pushable door `dynamic = true` (+ `friction`, `spring_k` / `spring_damping` to fall shut, `two_way` for a saloon door, `motor_torque` so that open / close work). The frame is stamped voxels, the panel and its handles are the moving parts (`moving`).

## Placed prefabs as instances (the editor, docs/EDITOR_MODE.md phase 3)
A tracked prefab is an instance the editor can pick, move, turn, copy, change and delete **as a whole**. The registry keeps with each instance what it was placed with (`variant`, the parameter overrides as text `name:kind:value;...`, the slots, the manifest, the rotation); moving or turning it places it again with that (the same Lua `prefab.place`, so `build` declares the nodes at the new place), changing settings places it again where it stands. In the editor: with the selection tool (Q) a click on a placed prefab selects it (Shift: a box that starts on it), the centre handle moves it (Ctrl copies), `R` turns it a quarter about the middle of its box, `Delete` removes it with the prefabs inside it and their nodes; the **Instances window** (menu bar, or the button in the Prefabs panel) lists the placed prefabs as a collapsible tree (a group per manifest, or per folder for a plain file; an instance; nested prefabs `house.door` under their parent; its event nodes and parts below; a filter; click selects, "re-stamp" / "remove" / "follow the file" per instance), and the Prefabs panel shows the settings of the selected one (variant, slots, parameters, "apply (place it again here)"). Actions `prefab_move {id, x, y, z, rotation, copy}` and `prefab_delete {id}`; MCP `prefab_pick`, `prefab_move`, `prefab_set`, `prefab_delete`, and `select {prefab}`. A prefab inside another (`house.door`) is picked, moved and deleted with its parent. An instance cannot be mirrored (a model has no mirrored placement) and a region operation on a box that touches one is refused by name.
**Undo and redo**: an instance keeps up to 16 other placements of itself (`PrefabSystem` `alt`): when the undo of a move brings the old voxels back, `reconcile()` swaps the registry back to that placement (and a redo to the later one); the nodes of a manifest are declared again at the restored place. Loose bodies that stand in the instance's box are not moved; a door's panel is moved with the door (it is re-created by the node).
`tracked.txt` has two more fields per instance (variant, parameters); an older engine ignores them. Limits: an instance remembers its last 16 placements (after more moves the registry no longer follows an undo: the voxels still undo, the instance then shows as missing); an undo swaps back only to a placement whose voxels match at least 90 % (a real undo restores them exactly); a copy gets the name `NAME_2`, `NAME_3` ...; `edit.model` and `scatter` placements (the Cove's trees) are not instances, so clicking them selects nothing (docs/TASKS.md); the tracked registry loaded from a project is not part of the networked session's descriptor.

## The starter kit (`assets/prefabs/`)
The engine ships 48 models and one manifest (the door; in the folders nature, buildings, ruins, props, structures and creatures) so that the Prefabs panel is never empty: a torch, a barrel, two fences (4 and 8 wide), a bridge segment, a small house (walls, windows, a door opening, a pitched roof), a well, a shed, a stone wall, a pillar, a signpost, a campfire, a stone arch, a market stall, the Cove's bench, crate, lantern post, oak, birch, pine, bush, rock and small tree, and (round 28, for the world generator's feature rules) a dead tree, a willow with hanging strands, a fallen log, a stump, a log pile, a big red mushroom, a berry bush, a saguaro and a barrel cactus, a desert rock spire, a mossy boulder, a snowy rock, a dead shrub, a cairn, a round thatched hut, and ruins (a stone circle, a hollow broken tower with a door and windows, a broken pillar). `creatures/` holds the six rigged sample creatures of `tools/make_creatures.py` (docs/ANIMATION.md), which are not workspace models. **Converted art** (from the owner's `.vox` packs, `--convert-vox`, docs/GUIDE.md "Models"): `nature/trees/` has eight tree kinds (`tree`, `fall_tree`, `winter_tree`, `dead_tree`, `willow`, `willow_plain`, `pine_fluffy`, `pine_snowy`; each broadleaf kind at `_m` = 1/3, `_l` = 1/2 and `_xl` = full size of the original, 4.4 / 7 / 14 m wide; the pines come as they are) in the style of docs/TREE_STYLE.md, and `buildings/desert/` has nine desert houses and ten loose parts (market, street lamp, four wall pieces, stairs, pillar, arch, floor slab), each as `desert_<name>_x2` and `_x3` (the original drawn at 2 or 3 voxels per voxel; the full-size trees are 233 x 256 x 203 voxels, the x3 tall house 300 high). Their colours are the kit's own materials (`assets/prefabs/materials.csv`, ids from 1000: `tr-RRGGBB`, `bd-RRGGBB`), added to every project's table by name when it does not have them (`MaterialTable::loadKit`); a script places them by plain name: `prefab.place("desert_tall_building_2_x2.vxm", x, y, z)`. More converted packs (figures, furniture, kitchen things, chests, a pub set, giant mushrooms, a forest of 7 trees, 8 shrubs and ferns, 5 plants and 5 rocks, a graveyard): docs/ASSET_CATALOG.md. The licence of these source packs is not known. The other models are data made by `tools/make_prefabs.py` with the model workspace's MCP tools (docs/MODEL_WORKSPACE.md): every prefab is a short list of `model_edit` operations (`--view DIR` writes a picture of each); re-run it after editing the script and commit the files. The panel's **starter kit** section (a picture per model; the ones the project already has are left out) carries a model on the pointer; **the model is copied into the project's models folder when it is used**, so a project stays complete and a pack carries it. The engine finds the kit next to the program (`assets/prefabs` in a parent folder of the executable; `VX_KIT=dir` overrides; `cmake --install` puts it in `assets/prefabs`). MCP: `list_models` lists the kit (`installed`), `place_model {file, pos, rotation?}` places a model of the models folder or the kit as a tracked prefab (`bench`, `bench_1`, ...). The unit tests load every kit model against the built-in materials.

## Notes and limits
- State: `tracked.txt` has the file, spot, rotation, carve flag, auto-restamp, slots, moving parts and the manifest per instance; the snapshot is the voxels as stamped (slots applied).
- The manifest is re-read on every `prefab.place` (no cache: deterministic file loads, a recording keeps a copy). Size parameters are not supported: voxel models do not scale, use variants.
- The voxels of `moving` parts are never stamped (the node places the door: at the stop it stands at, or as a body) and never taken back by a re-stamp, so a re-stamp leaves an open door open. A sliding (box-scan) door cannot be a moving part: its slab is the solids found in its box, and nothing stamps them; make doors with `hinge`. Placing an instance again at another spot or with other slots removes its old nodes (`<instance>.*`) before `build` declares the new ones.
- Manifests run in their own environment (their globals do not leak into the level); a prefab name is letters, digits, `_` and `-`, a manifest's `model` is a file of the models folder (no `..`).
- A dot in a prefab instance name is reserved for nesting: a prefab named `a.b` is taken for a child of `a` by `prefab.remove(a)`.
- Nesting works through `ctx.place` (children are tracked prefabs named after the parent). Manifests are parsed once per file time stamp (the recording's copy counter still advances on every placement).
- Not built: UI for slots, a prefab browser.


## The Prefabs panel (Prefabs in the menu bar)
Beside the list of placed prefabs and the plain model files, the panel lists every manifest of the models folder (`NAME.prefab.lua`). A manifest opens to its model, a **variant** drop-down (the manifest's `variants`),
a drop-down per **slot** (the manifest's material, or any placeable material) and a field per **parameter** (numbers, switches and text, with the manifest's defaults); an instance name (blank: automatic) and the
rotation slider complete the request, and "place at the look point" sends it as the Lua `prefab.place(...)` action (so it is in the log, undoable and replays like a tool call). Only what you changed is sent. "re-read the manifest"
picks up an edited file (the panel reads a manifest when it first shows it). `PrefabSystem::manifestNames`, `LuaHost::describePrefab` and `prefabPlaceCode` are the pieces (a tool or a test can use them without the panel).

## Snap points (2026-10-21)
A manifest can say which faces of its model join other pieces, so a hallway, a fence or a bridge is built by carrying the next piece to the end of the last:
```lua
return {
    model = "structures/fence_4.vxm",
    snaps = {
        west = { at = {0, 10, 1},  dir = "-x", tag = "fence" },   -- `at`: a cell of the (unrotated) model on the face; `dir`: the way the face looks, away from the model
        east = { at = {63, 10, 1}, dir = "+x", tag = "fence" },   -- `tag`: what it joins; `mate = "tag2"` joins another tag instead (a plug and a socket)
    },
}
```
Two faces join when the cells next to each other along `dir` are the faces (`A.at + A.dir == B.at`), the directions are opposite and the tags fit (`a.mate` or `a.tag` is `b.tag`, and the other way round). The kit's `bridge_segment`, `fence_4`, `fence_8`, `stone_wall`, `wall_corner` (its two arms join the stone wall), `window_wall` (a thin brick wall with a framed window), `stairs` (a flight of 8 steps: its top meets the next flight's bottom, 15 voxels higher) and `path_tile` (four sides) have snaps. The newer pieces are an odd number of voxels wide (33, 7), so the middle cell of a face the snap names is the same cell in every turn; the older even-width pieces land a voxel to the side when one of them is turned half way round.
- **Placing**: with the gallery's "snap to the faces of placed prefabs" on (default), a manifest prefab carried with the pointer jumps to the nearest face it fits within 1.5 m of where the pointer would put it, in the quarter turn about the vertical axis that makes the faces meet; the ghost shows the place (its outline and the joining cell in green), a click puts it there (`prefab.place` with that origin and rotation: one action as any placement). `R` still turns the carried piece first: the search starts from that rotation.
- **MCP**: `prefab_snaps {name}` lists a placed instance's snap points in world voxels (`{manifest}`: a manifest's, unrotated); `place_prefab {name, snap_to: {instance, point?, own?}}` finds the place and the turn that join one of the new prefab's points to one of the instance's (`point` / `own` restrict which) and answers `snapped`; `define_prefab` and `model_define` take `snaps: [{name, at, dir, tag, mate?}]` for the skeleton they write.
- **Code**: `app/snap.*` (`worldSnaps`, `snapsFit`, `findSnap`, tests/test_snap.cpp); the manifest's `snaps` are read by `LuaHost::describePrefab` into `PrefabManifestInfo::snaps` (a bad entry is an error naming it).
- Not built: snapping along more than the vertical turns (a stair, a ramp: faces whose directions are not horizontal join with the pieces' own turn only), a snap preview for prefabs from the Prefabs panel's file gallery without a manifest, snap points for plain `.vxm` files, a drawn marker for every free face while carrying (only the match is shown), snapping of box arrays.

## Labels: text that goes with the prefab (2026-10-21)
A manifest can say `labels = { { text = "TAVERN", at = {33, 17, 4}, facing = "+z", material = "brick", size = 1, align = "center", paint = "dark_red" } }` (or a function of the merged parameters): voxel text (docs/TEXT.md) written into the model in the model's own coordinates before the model is stamped, so it turns with the rotation, moves with `prefab_move`, is part of the snapshot the editor ghosts and takes back, and survives a re-stamp (the registry keeps the labels as a field of `tracked.txt`). An empty `text` is no label. The kit's `props/sign_board` is the example.
