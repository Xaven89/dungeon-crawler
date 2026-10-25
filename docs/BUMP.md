# Surface bump and gloss (E18)

Flat brick, plank, tile and stone faces read as surfaces: **seams are recessed, planks are grooved, stone is slightly pitted**, and materials with a low roughness get a sun highlight and a Fresnel reflection of the light around them. Both are **render only** (the shading pass; no state, no hash, nothing in a recording) and both are switched off by a scale of 0, which gives the picture from before they existed.
Design note: `~/share/e18/bump-design.md` (the reasoning, the numbers, what traced reflections would cost). Pictures: `~/share/e18/` (`bump0_*`, `bump50_*`, `bump100_*`, `gloss100_*`: four walls at 2, 6 and 12 m, a wet tile floor with metal, marble and gold).

## What to set
| where | key | meaning |
|---|---|---|
| `materials.csv`, last column | `bump` 0..255 | how deep the pattern's seams and specks are cut in this material. Hot reloads with the colours. A line with 30 columns (older files) leaves it alone. |
| `textures.json`, per texture | `"bump": -1..255` | -1 (default): the material's strength; a number: this texture's own (0 = flat). Procedural kinds only (brick planks tiles blocks stripes speckle noise); a pixel tile and `flat` have none. MCP `texture_define {bump}`, the texture window has a slider. |
| `project.cfg` | `bump = 0..1`, `gloss = 0..1` | the project's scale of all bump / all gloss. 0 = off (the shader code for it is not even compiled). |
| settings / `--setting` | `bump`, `gloss` | the person's scale (multiplies the project's), e.g. an accessibility or a low preset. |
| `materials.csv` | `roughness` 0..255, `metalness` | the gloss reads these (they were uploaded and unused before). |

**Built-in strengths** (the table every project starts from): brick 110, wood 70 (planks), stone 60 (speckle), concrete 40 (tiles); everything else 0. **Existing projects therefore see recessed seams on brick, wood, stone and concrete walls** and a faint pitting on stone and dirt-like speckles. `bump = 0` in `project.cfg` gives the old flat look back. There is no built-in material with the `blocks` pattern: a game's own materials set it (the Descent's flagstone and dungeon brick are the usual candidates: 70 to 110).

## How it looks, by kind
A pattern's seams are grooves **0.45 voxel deep with a soft 0.30 voxel shoulder**, so a normal changes over at least two pixels where the bump is still on. The strength `s = bump / 255` scales the slope: bump 255 is a shoulder slope of about 2 (63 degrees), 110 about 0.9, 40 about 0.3.
- `brick`, `blocks`, `tiles`, `planks`: the seam (the same 0.22 / 0.24 / 0.2 / 0.16 voxel as the colour pattern's mortar, times the texture's `width`) is a groove; each brick, block, tile or board gets a tilt of at most 0.05 to 0.10 (they catch the light a little differently); planks add grain lines along the board (3 per voxel of height). The ambient light is darkened inside a groove (the cavity term, up to 55 % x strength).
- `speckle` (stone, dirt, sand): each third-of-a-voxel speck is a dome, the second-colour specks are pits. `noise`: value noise on the unit grid (0.12 voxel). `stripes`: a V-groove where two stripes meet. `checker`, `flat`, pixel tiles: none.
- **No pattern, bump > 0**: a faint pitting (noise of 1.5 voxels at a third of the strength).
- **Fade**: by the size of a voxel on the screen, not by distance: the bump is full strength while a pixel covers less than 0.08 voxel and gone at 0.20 (about 5 m to 12 m at 1080p and 60 degrees. **It is by screen footprint, not distance**: at the desktop's 4K (3840 x 2160) a pixel covers half as much surface, so the bump reaches about twice as far, 10 to 24 m; a lowered render scale (dynamic resolution) shortens it again). Beyond that the colour pattern's seams (which fade at 24 to 56 m) carry the look. This also keeps the temporal anti-aliasing quiet: a groove is never narrower than about two pixels where it is drawn, and the pattern is a function of the surface's position, so reprojection finds the same surface.
- Used by the sun term, the sky gradient and the GI probe lookup (the diffuse terms). The shadow ray's origin, the ambient occlusion and the far tints keep the face's own normal. Only world voxels at the finest level and bodies get it (not particles, glass, water, or the coarse far levels).

## Gloss
A GGX highlight of the sun (`D G F / 4 n.v`, Smith-Schlick, F0 = 0.04 mixed toward the albedo by the metalness) and a Fresnel reflection of the light around (the probes' ambient in the direction of the reflection, else the sky gradient) on the bumped normal; a metal's diffuse is halved. **Matte materials get none**: the weight is `1 - smoothstep(0.50, 0.85, roughness / 255)` and a material at or above 217 skips the code entirely, so a dungeon is not glossy by default.

**What to put in the roughness column** (of 255):
| roughness | what it reads as |
|---|---|
| 220 to 255 | matte: stone, brick, dirt, plaster, wood, cloth. No highlight at all. (All of the built-ins and the Descent's stone, brick and wood are here.) |
| 150 to 215 | a faint sheen at grazing angles: worn wood, clay, rubber, painted metal. Subtle. |
| 90 to 140 | polished: marble, glazed tile, lacquer, a metal plate. A clear highlight and a reflection that brightens at grazing angles. |
| 40 to 80 | gold, obsidian, wet stone: a small sharp highlight and a strong reflection of the light around. |
| below 30 | mirror-like for the highlight (very small, bright) and the reflection is only of the probes' light, never of the scene: use sparingly, it will look odd next to matte walls. |
`metalness` 255 with a roughness of 60 to 100 makes a bright metal (its colour is the reflection's colour). A material that is wet (a puddle on a floor) wants a *separate* material with a low roughness: roughness is per material, not per voxel.
- **Not built**: traced reflections (reflections of the scene: a half-resolution pass, estimated 0.4 to 2 ms, see the design note), pixel-tile relief (`"bump": "pixels"`), bump on the coarse far levels, per-voxel roughness.

## Cost
Measured on the RTX 3070 Laptop, 1080p internal, headless, a brick hall (the `shade` pass; the machine was shared with another session, so each figure is the median / minimum of 6 to 10 runs alternating the variants):
| | shade pass |
|---|---|
| before E18 | 3.14 ms |
| E18 code in, `bump = 0` and `gloss = 0` (the variants compiled out) | 3.13 - 3.22 ms (**no difference**) |
| bump only | 3.24 - 3.32 ms (**+0.10 ms**) |
| gloss only | 3.49 ms (+0.35 ms) |
| both | 3.56 - 3.61 ms (**+0.45 ms**) |
The renderer compiles the shade pass four times (bump in or out, gloss in or out: specialization constants) and picks the one the scales ask for, so a project with `bump = 0` and `gloss = 0` pays nothing and its picture is the old one (a 1080p hall compared with the build before E18: mean difference 0.005 levels, the same as the old build against itself, 0.004). The gloss costs more than its work because the code, even when no pixel takes it, takes registers from the big shading kernel. A project with no glossy material can set `gloss = 0` and keep +0.10 ms.

## Tests
`bump: the built-in strengths, the CSV column ...` (defaults, dump and read, hot reload keeps / sets the strength, the GPU packing `pattern + 256 * bump`), `texture: bump is -1 ...` (JSON, flags and bits in the GPU table, clamping), and in `tools/mcp_smoke.py` a brick wall with bump 0 (twice: equal within noise) and bump 1 (differs by more than 8 times that).
