# Textures per occurrence

> **Status (2026-10-21): built: the layout (stage A), the table and the shader (B), the tools (C: Paint tool, MCP, Lua) and the editor window (D).** The decision was asked for before anything else grows on paint (docs/TASKS.md item 9).

## The question
A pattern belongs to the *material* today (all concrete is tiles, docs/PAINT.md). Wanted: choose the material, then a texture for *this* occurrence, so one concrete wall is tiled and the next is smooth, a floor is checkered and a sign has pixel art. Where do the bits live?

## What the voxel has
`Voxel` is a `u32`: bits 0..15 the material, bits 16..23 the **state byte** (a liquid's fill, a solid's **paint colour** 1..255), **bits 24..31 are unused** (`world/voxel.hpp`). Bricks keep voxels as `u32` palette entries (`world/brick.hpp`), so a whole `u32` already travels through edits, the journal, copies, bodies, the chunk store and the net actions unchanged.

## Decision
**The texture index is the top byte of the voxel (bits 24..31): `voxelTexture(v)`, 0 = the material's own pattern, 1..255 = an entry of the project's texture table.**
- It is *per voxel* (so it works for a brush stroke, a box, a prefab part and a pasted model, like paint), costs no new storage (a brick palette entry is already 32 bits; a wall with one texture adds no palette entries, a wall with two adds one) and no new edit op (`setVoxels` and `PaintState`-like ops already carry the whole word).
- It is **independent of paint**: the colour comes from the paint byte (or the material), the texture says *what is drawn in it* (which pattern, which scale, which seams). Paint stays where it is; nothing about the 255-colour palette changes.
- Air stays `0` (`makeVoxel` returns `0` for material 0; `withTexture` leaves air alone). Liquids and glass take no texture (like paint).

Alternatives considered and left: (a) a second per-voxel byte plane next to the bricks (a new array on CPU and GPU, a new edit path, a new save format: a week of plumbing for the same information); (b) a per-brick attribute (8 x 8 x 8 voxels: too coarse for "this wall tiled, the next smooth"); (c) a per-region / per-prefab-part layer (a second structure to keep in step with edits, destruction and rubble); (d) a texture index inside the paint palette entry (would cut the 255 colours to a few dozen or multiply the table; the two choices are independent).

## What must hold (the places that assumed 24 bits)
1. **Uniform bricks.** An inline uniform brick ref keeps 24 bits (`brickUniformRef`): a uniform brick whose voxel has a texture must *not* be inlined (it becomes a one-entry palette brick, width 0). Encoders and `brickEncodeUniform` check `(v >> 24) != 0`.
2. **Vote / LOD.** The coarse levels vote on the *material*; they draw no patterns beyond ~24 to 56 m, so they carry no texture (the vote result is built without the top byte).
3. **Equality.** Code that compares whole voxels (`==`) to mean "same material" (journal diffs are fine; fire, liquids, connectivity use `voxelMaterial`): audited, listed in the stage A commit.
4. **GPU.** The march passes the texture byte on: world hits through `gVox.w` bits 24..30 (the body index uses the low bits, bit 31 is the foliage cube flag), body hits the same. `shade.comp` reads it where it reads the paint index.
5. **Files.** A texture *index* means nothing outside its project, so files store **names**, like materials: `.vxm` gets a texture-name table (new magics `VXM3` = model + textures, `VXM4` = rig + textures; written only when a voxel has a texture; every reader accepts 1..4), and loading maps names to the project's ids (an unknown name: no texture, with a warning). The chunk store (`.vxs`) stores raw words: ids are per project, the table is saved with the project.
6. **Prefabs, rubble, paste, undo, nets**: unchanged (whole words).

## The table (stage B)
`textures.json` of the project (built-ins when absent, so ids 1..N mean the same in every project that does not change them; every entry has its `"id"`: voxels carry ids, so a file that names ids is the whole table, holes included, and a deleted texture never moves the others. A file without ids, written by an older version, adds to the built-ins in order): up to 255 entries
```
{ "name": "tiles_big", "kind": "tiles", "scale": 8, "width": 1, "color": "#c8c8c8", "color2": "#707070", "seed": 3 }
{ "name": "heart",     "kind": "tile",  "pixels": "........" , "palette": ["#00000000", "#cc2233", ...] }   // 8 x 8, 4 colours
```
- procedural kinds `brick planks tiles blocks stripes speckle noise checker` with `scale` (1..16 voxels per unit), `width` (seam width in 1/8 voxel), two colours (empty: the material's own and its darkened second colour), `seed`;
- a **pixel tile**: 8 x 8 pixels of 2 bits each (4 colours; colour 0 may be transparent: the material shows through), repeated over the face in voxel units, so a pixel is one voxel (6.25 cm): pixel art for signs, floors and walls.
- Each entry packs into 32 bytes (`vec4 x 2`) of a storage buffer next to the material table (`gpu_world.cpp`); a pixel tile's 64 x 2 bits and 4 colours fill exactly 8 words.

## Tools (stage C)
Paint tool: a texture choice next to the colour (colour only, texture only, both); MCP `paint` / `region` `texture`; Lua `edit.texture_sphere / box`; workspace shape ops `"texture": name`; a small texture editor window (kind, scale, width, colours, an 8 x 8 pixel grid, a library list, save to `textures.json`), the texture of the voxel under the pointer on the middle button (eyedropper).

## `textures.json`: a file to copy
```json
{ "textures": [
  { "name": "skull", "kind": "tile", "palette": ["#00000000", "#e0e0e0ff", "#101010ff", "#000000ff"],
    "pixels": "00111100/01111110/11211211/11111111/01122110/00111100/00122100/00000000" },
  { "name": "mossy_brick", "kind": "brick", "color": "#556b2f", "color2": "#8a8a7a", "scale": 2 }
] }
```
`kind` is a procedural kind (`flat brick planks tiles blocks stripes speckle noise ...`) or `tile`: an 8 x 8 picture, `pixels` is 8 rows of 8 digits `0..3` joined by `/`, `palette` the four colours (`#rrggbbaa`, digit 0 is usually clear). A file **without** ids adds to the built-ins (a new one gets the next free id, the file is rewritten with ids at the next save); a file **with** ids is the whole table. A bare JSON array is not the format (`{"textures": [...]}`). `--check-project` reads the file, so a level that uses `edit.texture_box(..., "skull")` checks clean.

## Order of work
A. data (this note's items 1 to 6 for the voxel, bricks, `.vxm`, helpers, tests) -> B. the table and its GPU upload, the shader reading it -> C. paint tool / MCP / Lua / workspace -> D. the editor window. The conveyor belt (docs/CONVEYOR.md) scrolls a texture along a face: it needs B.

## What is built (2026-10-21)
- **Data**: `voxelTexture` / `withTexture` (`world/voxel.hpp`), uniform bricks of a textured voxel are stored (`world/brick.cpp`), `.vxm` `VXM3` / `VXM4` with texture names (`world/vxm.cpp`, resolved against `activeTextures()`), edits: `EditMode::TextureState` ops (`EditOp::textureBox / textureSphere`, decided when applied), `paintEdits(..., colour, texture)` (colour -1 and texture 0 leave them alone).
- **Table**: `world/texture.*` (`TextureTable`: 16 built-ins (with "belt"), ids by order, `toJson` / `fromJson`, `gpuData`); the project's `textures.json` is read at start (a recording keeps a copy, a replay reads it) and written with the other saves when it changed; actions `texture_define` (the texture as JSON) and `texture_delete` (the name).
- **Shader**: `shade.comp` reads the top byte of the hit voxel (`textureAt`: the world through `voxelAt`, a body through its brick refs) and the table at vec4 index 262400 + 6 * id; a texture's pattern replaces the material's, fades with distance the same way, the voxel's own colour or paint is the base unless the texture has colours (`color`, `color2`); a tile pixel is one voxel (times `scale`), a clear pixel shows the voxel.
- **Tools**: the Paint tool (and a selection's "paint" buttons) take colour / texture / both; MMB picks both; MCP `texture_list / texture_define / texture_delete`, `paint {texture}`, `region {op: paint, texture}`, `query_voxels` shows `texture`; Lua `edit.texture_sphere / box`; the **Textures** window (menu bar): the list, kind, scale, seam width, seed, colours, an 8 x 8 pixel grid with a four-colour palette, save and delete.
- **Not built**: workspace shape ops with a texture (a model gets textures by `region` / `paint` in the world, or `model_from_region`), a live preview strip in the window (it is the world that shows the result), textures on the coarse far levels, a texture on the particles of rubble, texture-aware GI.
- **Scrolling** (built with the conveyor belt, docs/CONVEYOR.md): a `scroll` field (voxels per second along the face's two axes, 3 numbers) moves the pattern with the frame time in `shade.comp`; the table is 6 vec4 per texture.
