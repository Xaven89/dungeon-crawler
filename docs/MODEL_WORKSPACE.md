# The model workspace: small voxel models, made apart from the world

A **workspace model** is a small voxel model (up to 128 voxels an axis and 1 M voxels; 1 voxel = 6.25 cm) that lives in memory, **apart from the world**: editing it touches no world, no simulation, no recording. That is what makes it the tool for making prefabs in small scale, by hand or by agents in parallel (every `voxelith --mcp` process has a workspace of its own, up to 32 models; they save into the same models folder under different names).

```
new model -> edit with operations -> look at it (picture, layers) -> save .vxm -> it is in the Prefabs gallery -> place it, or define parts / a manifest on it
```

## MCP tools (docs/MCP.md)
| tool | |
|---|---|
| `model_new {name, size, replace?}` | an empty model (name: letters, digits, `_`, `-`) |
| `model_edit {model, ops}` | a list of operations, **one undo step**; an error stops at the failing one (its index is in the message) and keeps the ones before it |
| `model_view {model, size?, turns?, layers?, axis?}` | a PNG (isometric: the top and two sides lit differently, the materials' colours; `turns` 0..3 shows the other corners) and with `layers: true` a text picture, one block per layer from the top down, a letter per material, a legend |
| `model_info {model?}` | size, solid voxels by material, bounds, undo steps, the file it was saved as |
| `model_undo {model, redo?}` / `model_remove {model}` | |
| `model_save {model, file?, overwrite?}` | `NAME.vxm` (`file` may name a folder: `props/lamp`) in the project's models folder (a session without a project: `~/share/voxelith-clips`) |
| `model_define {model, file?, parts, manifest?, overwrite?}` | a **prefab without stamping**: the model becomes `FILE.vxm` with named parts (material slots, sockets, pivots: `parts` as in `define_prefab`, but in the model's coordinates: `box [x0,y0,z0,x1,y1,z1]`, `material`, `seed [x,y,z]`, `pivot`) and a manifest skeleton `FILE.prefab.lua` (or the Lua text you pass as `manifest`); existing files only with `overwrite: true`; place it with `place_prefab` |
| `model_load {file, name?, replace?}` | a `.vxm` back into the workspace to change it |
| `model_from_region {name, min, max}` | a box of the world (128 an axis at most) becomes a workspace model |
| `model_to_world {model, origin, rotation?}` | stamps it into the world (a recorded, undoable `paste`: see the model in the level, or build a prefab with parts from it with `define_prefab`) |

## Operations (`model_edit`; voxel coordinates start at the model's minimum corner, y is up, materials are names, `"air"` carves)
`box {min, max, material, mode?}` · `sphere {centre, radius | radii [rx, ry, rz], material, mode?}` (a voxel is in when its centre is: use 4.5 for the middle of a 9 wide model) · `cylinder {base, axis, radius, height, material, mode?}` (`base` is the centre of the first end) · `line {from, to, radius?, material, mode?}` · `set {voxels: [[x, y, z, material], ...], mode?}` (checked first, then painted: a bad entry changes nothing) · `clear` · `replace {from, to, min?, max?}` · `shift {offset}` · `resize {size, anchor?}` · `crop {margin?}` · `mirror {axis}` · `symmetrize {axis, from?}` (copies one half onto the other: draw half a statue) · `rotate {quarter_turns, axis?}` or `{rotation: 0..23}` · `paste {model, at, rotation?, air?}` (another workspace model: build a house from a wall, a door frame and a window) · `flood {at, material}` (the connected voxels of the same material: fill a room, recolour a part).
`mode` is `replace` (default), `fill_air` (only into air) or `paint` (change the *material* of what is solid).

**Colour paint** (docs/PAINT.md): every shape op takes `paint` (a palette name, `#rrggbb` or index): the voxels it writes carry that colour (`material` may then be left out: the shape only paints what is already solid). `paint {color, min?, max?, only?}` paints a box (default: the whole model; `only`: just one material; `"none"` clears). Liquids take no paint. The paint is the voxel's state byte, so it is in the `.vxm` and in every stamp of the prefab.

## Lua and the panel
`workspace.new(name, sx, sy, sz [, replace])`, `workspace.edit(name, { {op = "box", ...}, ... })` (the same operations as tables; an error names the failing one), `workspace.info(name)`, `workspace.names()`, `workspace.remove(name)`, `workspace.place(name, x, y, z [, rotation])` (stamps it into the world as an ordinary edit: procedural prefabs in a level script). The **Prefabs panel** has a workspace section: new model (name, size), a picture per model (redrawn when it changes), a click carries it on the pointer like any prefab (a click puts it down), `save .vxm`, `undo`, `redo`, `remove`. The Lua console line of the Tools / Console panel can drive `workspace.edit` by hand.

## Parallel agents
Start one `voxelith --mcp --project DIR` per agent (add `--world 4 --terrain flat` for a small, quick world); each builds with `model_new` / `model_edit` / `model_view`, saves with distinct names (`model_save` refuses to overwrite without `overwrite: true`) and the files land in DIR/models. A coordinator then lists them (`list_models`), places them (`place_prefab` / `prefab.place`), and builds the manifests with `define_prefab` on a stamped copy. Nothing is shared between the processes but the folder.

## Limits
A thick long `line` is refused (radius and length together at most 30 M voxel writes); the undo snapshots of the whole workspace are bounded at 16 M voxels (the oldest of the biggest holder go first); `sphere` and `cylinder` visit only the box around them; a `flood` uses a byte per voxel. `workspace.place` (Lua) only stamps a model that a script made and changed alone (`scriptOnly`): a replay re-runs the script; an MCP tool or the panel clears the flag. In a networked session a workspace model cannot be stamped (the other machines do not have it).
A model is at most 128 per axis and 1 M voxels; 32 models; undo keeps 24 steps (and at most 8 M voxels of snapshots). The workspace is not saved with the project (save the models you want to keep); it is not in a recording: `model_to_world` and the panel's click write the model beside the log (`clip_N.vxm`) so a replay can paste it. Parts (named voxel groups, sockets) and manifests are made with `define_prefab` on a stamped copy: the workspace itself has no parts yet.

## Text form, check, diff, copy, rename (2026-10-21)
A model as text, both ways, for agents that read, write, share and diff models (`model_text`, `model_from_text`):
```json
{ "name": "tower", "size": [3, 2, 3],
  "legend": { "#": "stone", "g": { "material": "glass", "paint": 5, "texture": "heart" } },
  "layers": [ ["###", "#.#", "###"], ["ggg", "...", "ggg"] ] }
```
`layers[y]` is the layer at height y, **the bottom first**; each layer is a list of rows with **z = 0 first**; each row a string with **x = 0 first**; `.` or a space is air; rows and layers that are short are air; `size` may be left out (the extent of the text) or be larger than it. A legend entry is a material name, or an object with `paint` (1..255, the colour of a solid), `state` (a liquid's fill) and `texture` (a name of the project's texture table). `model_text` makes one letter per material and paint / texture combination (the first letter of the material when it is free). Everything is checked: unknown materials, textures and characters are named, the usual size limits hold. It round-trips every voxel word (`tests/test_model_workspace.cpp`).
- `model_check {model}`: separate pieces (6-connected), **floating** voxels (pieces that do not touch the bottom layer), single voxels, enclosed **pockets** of air, with boxes and notes in words.
- `model_diff {a, b}`: from the minimum corner, voxels only in a, only in b, changed (material, paint or texture), the box of the differences and the most frequent changes (`stone -> metal`).
- `model_copy {model, as}` (no undo history), `model_rename {model, to}` (the undo history comes along), `model_from_prefab {name, instance}` (the rotated model of a placed prefab as it was last stamped).
- `list_models` shows the size of each file in bytes and its write time.
