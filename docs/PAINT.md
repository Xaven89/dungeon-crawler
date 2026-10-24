# Surface patterns and paint

Two things make a flat colour read as a *thing*: a **pattern** a material draws over its voxel faces (a brick wall has courses and mortar, planks have boards), and **paint**, a colour you put on single voxels (the pattern stays under it).
(A third thing, a **texture per voxel** that replaces the material's pattern for that voxel, is in docs/TEXTURES.md.) Both are render-only: they change what the voxel face looks like, never what the voxel is (collision, burning, destruction and the material's physics are untouched).

## Patterns (per material)

`materials.csv` has four more columns, after the earlier ones (they are optional; a file without them keeps the built-in look):

| column | meaning |
|---|---|
| `pattern` (24) | `none`, `brick`, `planks`, `tiles`, `blocks`, `stripes`, `speckle` |
| `r2`, `g2`, `b2` (25-27) | the second colour (0..255): mortar, board gaps, grout, the other stripe. Empty: the base colour darkened |

Built in: brick = brick (light mortar), wood = planks, concrete = tiles, stone / dirt / sand / planet = speckle. A pattern is drawn in **voxel units** on the face (a brick is 4 x 2 voxels = 25 x 12.5 cm; planks run along the longer face axis), fades out beyond about 24 to 56 m (the same distance the eye cannot see it), and also works on moving bodies. A hot reload of `materials.csv` re-reads the patterns.

## Paint (per voxel)

The **state byte** of a solid, non-liquid voxel is its paint: palette index 1..255 (0 = none). The palette is fixed so a number means the same colour in every project, every `.vxm` and every net peer:

- 1..16 greys (1 white ... 16 black), 17..112 twelve hues x 8 tones (`red`, `pale_red`, `dark_blue`, `shadow_yellow` ...), 113.. earth, skin, wood and a few others. `paint_palette` lists them with sRGB values and names.
- A colour is given as a **name** (`brown`, `dark red`), **`#rrggbb`** (the nearest palette entry), an **index** or `none` (clears).
- A painted voxel keeps its material, so a painted brick wall is still bricks, in another colour (the mortar becomes a darker shade of the paint).
- Liquids and **glass** take no paint (a liquid's state byte is its fill level; glass is drawn by the transparency pass, which does not read the palette), and neither does air.
- Paint survives: save and load, `.vxm` files (it is the voxel's state byte), rotate / mirror, copy / paste / move, prefabs and their instances. The coarse far-LOD voxels keep the most common paint of the material that wins the vote. It is **not** seen by the GI bounce light and the flying debris particles (a broken painted wall crumbles into unpainted grains; a grain that settles lands with the paint it came with). Replacing or filling with a *material* (`region replace`, `region fill`, an event lamp's material swap) makes new voxels without paint: paint is applied after. A sphere, cube or disc dab is at most 127 voxels in radius (a bigger one is refused / clamped with a warning); a box is as large as a region may be.

## Painting

| where | how |
|---|---|
| Editor | `Q` cycles select, brush, **paint**. Tools panel: a palette and a radius (0 is exactly one voxel, 1 is the voxel and its six neighbours). **LMB** paints a sphere at the surface voxel under the pointer (a stroke is one undo step, a fast stroke is filled in), **RMB** clears paint, **MMB** picks the colour under the pointer. With a box selected the panel has "paint the selection" / "clear its paint". |
| MCP | `paint {shape?, centre, to?, size?, up?, color?, texture?, ticks?}` (sphere, cube, disc, box), `paint_palette {named_only?}`, `region {op: "paint", color}` over the selection or a box. All recorded actions: undoable, replayable, the same on every peer |
| Lua | `edit.paint_sphere(x, y, z, r, color)`, `edit.paint_box(x0, y0, z0, x1, y1, z1, color)` (decided when the edit is applied, so `edit.box(...)` then `edit.paint_box(...)` in one script paints the new wall) |
| Workspace models | every shape op (`box`, `sphere`, `cylinder`, `line`, `set`) takes `"paint": "red"`: the voxels it writes carry that colour; without `material` the shape only paints what is already there. `{"op":"paint","color":..., "min"?, "max"?, "only"?: "wood"}` paints a box (default: the whole model; `only` filters by material). A model with paint saves it in the `.vxm` and stamps it with the prefab |
| Actions | `paint` (shape, colour, centre, size, up, second corner, join) in the action log |

## For a player's paintbrush

Nothing in the engine is editor-only: a game gives its player a paintbrush by calling `edit.paint_sphere` at the look point (or sending the `paint` action) with the colour the player picked from the palette; the editor's stroke code is the model (dabs a radius apart, one undo step per stroke). There is no in-game item yet.

**Bump (E18)**: the `bump` column of `materials.csv` (0..255) cuts a material's pattern into its normal: recessed seams, grooved planks, pitted stone (docs/BUMP.md; the built-ins brick, wood, stone and concrete have it, `bump = 0` in `project.cfg` turns it off).
