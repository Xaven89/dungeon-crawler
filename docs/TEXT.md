# Text in the world

> **Status (2026-10-21): voxel text is built** (option (a) of the idea: real geometry). Painted text and a decal / label render are not.

Letters are voxels: a 5 x 7 bitmap font, one voxel per font pixel times `size`, so a letter is 5 x 7 voxels (31 x 44 cm) at size 1 and a sign 3 m wide holds 8 letters. Being voxels the text survives destruction, saves, undo, the far levels, copy / paste and prefabs, and costs no new system.

## Writing it
| where | how |
|---|---|
| Lua | `edit.text(x, y, z, "HELLO", { facing = "+z", material = "brick", size = 1, spacing = 1, depth = 1, align = "left", mode = "replace", paint = "red", texture = "heart" })` |
| MCP | `text {text, pos, facing?, material?, size?, spacing?, depth?, align?, mode?, color?, texture?}`: a recorded, undoable action; answers the box it covers |
| Workspace models | `{"op": "text", "text": "HELLO", "pos": [x, y, z], "facing": "+z", "material": "brick", "size": 1, "paint": "red"}` in model coordinates (text past the model's edge is cut) |
| Prefab manifests | `labels = { { text = "HELLO", at = {x, y, z}, facing = "+z", material = "brick", size = 1, align = "center" } }`, or `labels = function(p) return {...} end` with the merged parameters: the text is written into the model **before** it is stamped, so it turns with the placement, moves with `prefab_move` and goes when the prefab goes (an empty text is no label) |
| Action | `text` (x, y, z, facing code, size, spacing, depth, align, mode, material id, paint, texture; the words are the action's text) |

`pos` / `at` is the bottom of the line: its left end (`align = "left"`, default), its middle (`"center"`) or its right end (`"right"`). `facing` is the way the text looks: a viewer standing on that side reads it. `+z` is read along +x with +y up, `-z` along -x, `+x` along -z, `-x` along +z; `+y` lies on a floor (read from the south, north is up) and `-y` on a ceiling. `depth` layers go from the face layer into the surface (against `facing`): 1 replaces one layer of the wall, 3 engraves it. `mode = "fill_air"` writes only into empty voxels (letters standing in front of a wall). ASCII 32..126 is drawn, anything else as `?`; at most 200 characters; `size` 1..8, `spacing` 0..8, `depth` 1..16.

## The sign
The kit's `props/sign_board` (a 66 x 18 voxel board on a post) has a manifest with the parameters `text` (default "WELCOME"), `material`, `color` (a paint colour) and `size` (1: ten letters, 2: six): `prefab.place("props/sign_board", x, y, z, { params = { text = "TAVERN", color = "dark_red" } })`; the Prefabs panel shows them as fields, and changing the text there places it again. The older `props/signpost` is plain voxels with three unreadable bars.

## What is not built
- **Painted text** (colour a letter shape on a face with the paint byte, no geometry) and **a decal / label render** (crisp small print at a resolution finer than a voxel, drawn in `shade.comp`): the options (b) and (c) of the idea. Voxel text with a texture (docs/TEXTURES.md) covers colours and pixel-art lettering.
- A **Text tool in the editor** (a ghost of the words that follows the pointer): use the MCP / Lua / panel `text` for now.
- Other fonts, lower case small caps, kerning, text along a curve.
