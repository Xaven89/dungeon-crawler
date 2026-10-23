# Walk-through voxels (gore, stains, webs)

A material with `passable = 1` in `materials.csv` is a voxel you move through. It is stored, drawn, lit, saved, painted and edited like any solid voxel, but it never gets in the way: the player, bodies, agents,
vehicles, rays that look or move, and sound walk, fall and pass through it. It is no structure: it holds nothing up, never anchors and never falls as a piece, and a liquid that flows into its cell washes it away.
It does not flow, float or move by itself. The dungeon game's blood, a spider web, a patch of slime on the floor are this.

```
# id,name,r,g,b,rough,metal,er,eg,eb,ei,density,tough,rest,fric,anchor,liquid,transparent,visc,flam,burn,char,pclass,fire_spread,pattern,r2,g2,b2,passable,drag
70,blood,120,8,8,60,0,0,0,0,0,50,10,20,60,0,0,0,1,0,0,0,0,255,none,0,0,0,1,0
```
Columns 28 and 29 are new (`passable` 0/1 and `drag` 0..255); older files without them load as solid and 0. Like `anchor` and `liquid` the flag is read at start, not on a hot reload.
`flammability` / `burn_ticks` work as for any material: a stain with `flammability 40, burn_ticks 60, char_chance 0` burns off in a fire, one with 0 does not.

## Putting it down
- `edit.sphere(x, y, z, r, "blood", "coat")` and `edit.box(x0, y0, z0, x1, y1, z1, "blood", "coat")` (voxels): a **coat** writes the material into every *air* cell of the shape that touches a voxel that blocks (a floor, a wall, a
  ceiling, a crate): a one-voxel shell on the surfaces around a point, never into a stored voxel, and twice is the same. At most 4 million cells of box per call.
- `fx.splat(x, y, z, radius, "blood" [, seed])` (**metres**, radius up to 4 m): the same shell speckled towards the rim (a cell is kept when `hash(cell, seed) < 1 - distance / radius`), so the edge looks like a
  spatter; the same seed gives the same spatter, another seed another. It is an edit (undoable, in the log, replayed): the dungeon game's hit is one `fx.splat` per wound.
- `edit.sphere(..., "blood", "clear_if")`, `edit.box(..., "blood", "clear_if")`: clears the voxels of that material (cleaning up), whatever their paint, and nothing else.
- Any other edit (`edit.box(..., "blood")`, the editor's brush, a prefab, a model) places it like a solid.
- **Particles**: a grain or debris particle of a passable material that comes to rest becomes a voxel (as sand does, cosmetic: not in recordings). A grain that falls on a stained floor passes through the stain, rests in
  the stain's cell and replaces it: a stain never grows a second layer and never holds a pile up. Rain falls through it to the floor.
- Material `drag` (0..255, default 0): while the legs are in it the walking speed is cut by up to `drag / 255` (two probe points at 0.25 m and 0.75 m, half each). 0 means not at all.

## What it does and does not do
| | passable voxel |
|---|---|
| player, bodies, agents, vehicles, nav | pass through (it is not collidable); a crate dropped on it rests on the floor under it |
| structure and destruction | not structure; after a carve the bricks around it are swept (256 a tick) and a stain with nothing blocking on any of its six sides is cleared, so gore never hangs in the air |
| liquids | flow into its cell and replace it: water and lava wash it away |
| gravity (the field's surface) | does not count as ground |
| rays that look or move (camera, grab, sound, foot IK, getting up) | pass through |
| rays that pick (dig, paint, place, the editor's pick) | stop at it: a stain can be picked, dug and painted like any voxel |
| `world.solid(x, y, z)` | true (it is stored); `world.blocks(x, y, z)` false; `world.passable(x, y, z)` true |
| `world.top(x, z, fromY, true)` | skips it (the 4th argument); the plain form stops at it, as before; scatter, spawns, wear prints and the teleport use the floor under it |
| MCP `raycast` | `through_passable = true` steps through it |
| renderer | drawn, lit, shadowed (a one-voxel sliver) and in the GI like a solid; the ground cover under it is gone while it lies there |
| fire | burns by its own flammability |
| wear (footprints) | the print lands on the floor under it; dust never piles on it |
| footsteps | the feet's own cell first: with a passable voxel there the sound is that material's row (`blood` in `footsteps.csv`) |
| a body's own voxels | a stained crate keeps the stain as an ordinary solid voxel of its body |

## For authors
The two words in the code are `voxelSolid` (the voxel exists: bricks, saves, edits, drawing) and `voxelBlocks(v, flags)` (it is in the way: collision, support, rays that move). `MaterialTable::structuralFlags()` bit 2 (`kFlagPassable`)
and the GPU kind bit +8 in the material's last channel carry the flag; the four gates that read it are `WorldProbe::collidable`, `ConnectivityAnalyzer::isStructural`, the gravity surface grid and the liquid solver's free
cell test. Tests: `tests/test_passable.cpp` (flag, probe, structure, liquids, crate, player, rays, coat, splat, settling) and the GPU test "passable: ..." in `tests_gpu/test_gpu.cpp`.
