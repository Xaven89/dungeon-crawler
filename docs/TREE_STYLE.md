# Tree style: how the pack's trees are built, and how to make more of them

The trees of the `Trees/*.vox` pack (Tree, Fall_Tree, Winter_Tree, Dead_Tree, PineFluffy, PineSnowy, Willow, Willow_single_color; converted into `projects/tree_garden`) are the look the project
wants for its foliage. This document is what was **measured** in those files (a script read every voxel, nothing here is a guess unless it says so), the recipe that follows from it, and how to
make a new species that sits next to them without anyone seeing the join. `tools/make_trees.py` is the recipe as code: it makes oak, pine, willow and their seasonal versions from the numbers
below, and a new species is a few lines in its table.

Units: **g-units** are voxels of the grid the pack was made on (a tree is 256 of them tall; the engine's voxel is 6.25 cm, so one g-unit is 6.25 cm when a tree is imported 1/1: 16 m).
Imported with `--vox-scale 2` or `3` a tree is half or a third of that (see "Sizes"). All numbers below are in g-units unless they say metres.

## The recipe in eight lines
1. A tree is **two models**: a thin **skeleton** (trunk and branches, one bark colour) and a **crown** (leaves, three shades). Snow, bare and autumn trees are the same skeleton with another crown.
2. The skeleton is **a stout straight trunk and then a spray of 1-3 voxel wide arching limbs**: it rises, levels out and droops at the ends. Nothing in the crown is solid wood.
3. A crown is **a union of balls** (radius about 9-14, bumps of 25-35 across) sitting on the limbs, each ball **stippled**: about a quarter of its voxels are set, none of the others.
4. Every leaf voxel gets one of **three shades of one hue, drawn at random per voxel**: no gradient by height, by distance to the edge or by ball. Neighbours match as often as chance says.
5. The three shades are **dark, mid, light** of one hue family (hue spread about 20 degrees, value ratio 1.3 to 1.5). The bark is one colour. A tree has 4 colours, a willow 7.
6. Snow is **the same shape moved up** (leaves 1 voxel, bare branches 3), painted white, with the original drawn over it so only the top edge is white.
7. Pines are the exception to the balls: **six tiers of drooping branches** round a tapering trunk, needles stippled in clumps along each branch.
8. Willows hang **strands**: vertical stippled capsules about 10 across and 55-95 long, one shade family per strand, from limbs that arch over and down.

## What was measured

### One skeleton for four trees
`Dead_Tree`'s skeleton (52,606 voxels, bark `#43341b`) is **identical** in Tree, Fall_Tree and Winter_Tree: those are the same model plus another crown. Tree's crown (376,133 voxels) is Fall_Tree's with
three other colours, and Tree uses it **twice** (the file places the crown model twice, turned +90 and -90 degrees about the vertical): two independent-looking stipples of the same blob layout, which is why Tree
is denser (interior fill 0.30 against 0.25) and 768,225 voxels against 423,841. Winter_Tree's crown is the skeleton again, 3 voxels higher, white.

Broadleaf proportions (256 tall): width 210-233 (0.82-0.91 of the height), depth 203; trunk 0-45 (17.6 % of the height) then crown from 43 to 255; the crown's widest layers are at 35-70 % of the height.

### Trunk and roots
- **Straight and untapered**: 10 voxels across (62-81 voxels per layer, a disc of radius 4.9) from z=4 to z=40, then it opens into the first limbs at z 40-60. No taper, no bark texture, no knots.
- **Roots** are only the lowest three layers: layer 0 is a thin irregular star about 30 across (279 voxels), layer 2 148 voxels, from layer 4 up the 10-wide disc. They are 1-2 voxels thin spokes.
- The willow's trunk is the same idea, thicker: 19 across (199 voxels per layer, bark `#563f2e`), nearly untapered to z=40, forking at 45-60, 80,398 voxels in all (47 % of the tree).
- The pine's trunk **tapers**: 6 across at the base, 5 at z=32-48, 4 at 64, 3 at 80, 2-3 at 96, up to the top tuft. Bare below z=14 (11 % of the height).

### Limbs
- **Thickness**: the distance from a branch voxel to the nearest empty voxel is 1 for 89 % of them (a one-voxel line), 1.5 for 7 %, 2 for 2 %. A few limbs are 3-5 wide near the fork (inscribed radius up to 2-3) and nowhere else. A limb looks thick in a picture because many 1-voxel lines run side by side.
- **Arch**: the direction of a limb, measured along it (outward, +up): about +35 degrees within 25 voxels of the trunk, +17 at 25-50, -3 at 50-75, **-19 at 75-100**. Limbs rise, level out and fall: no straight spokes.
- **Spread**: the mean distance of a branch voxel from the trunk axis is 22 at z=60-80, 32 at 80-100, then 38-44 all the way up to 240: the skeleton is a wide vase that fills a rounded envelope of radius about 100 and z 45-255, with tips out to 95-105. 15 % of the limb voxels are steeper than 45 degrees, 46 % within 20 degrees of horizontal, 23 % droop more than 20.
- **Count**: 52.6k voxels in a skeleton, in 970 separate pieces when connectivity is 26-neighbour (the main piece is 73 % of the voxels: many short fragments lie apart from it). Heights of the mass (voxels per 20 layers from the ground): 1948, 1446, 1081, 2673, 4426, 7181, 6210, 4421, 4587, 3110, 1126, 335, 30.
- The willow's limbs arch much higher and farther: from z=45 up to z=255, then down to z=0-120 at radius 70-100, and the heavy limbs are up to 3.6 (inscribed radius; 5 at the fork) near the trunk.

### Crown: balls, stippled
- **Solid or hollow?** Neither: the crown is a **shell of bumps with a full interior**: 15,003 interior 4-cells for one copy. In a horizontal section the leaves appear as separate speckled patches 40-60 across with gaps between them; from the outside it reads as a closed, lumpy mass.
- **Ball size**: the biggest sphere that fits in the crown has a radius of 17 and the typical one 12-15; the lumps on the silhouette are 25-35 across. The generator's balls are 9-14 and reproduce the bumps.
- **Fill**: **24 % of the voxels of a ball are set** (interior 4-cells hold 15.5 of 64 on average). The pack's Tree has two copies, so 30 % where they overlap.
- **Where leaves are**: 94 % of the leaf voxels are within 18 voxels of a branch voxel, the median is 9. Balls hang on limbs: **the crown follows the skeleton**, not an ellipsoid fitted around it.
- **Envelope**: leaf voxels, 5 / 50 / 95 percentile of the height: 76 / 154 / 231; of the distance from the crown's axis: 20 / 41 / 61 (median) / 76 / 94 (the 5th, 25th, 50th, 75th, 95th percentile). The crown's centre of mass is z=154, x,y = (-12, -11) (the pack's trunk is off the cube's middle by that much; the importer re-centres it).
- **Edge**: ragged on the voxel scale (a stipple has no clean surface), smooth on the scale of a ball. 5 % of the leaf voxels have at most one neighbour in their 3 x 3 x 3. A few holes of a ball's size show the sky and the branches.

### Colour
Three shades per crown, one bark. They are **independent per voxel**: the share of each is 0.33 +- 0.01 in every height band and every distance band, and a voxel has the same shade as its neighbour 0.335 of the time (chance for three shades is 0.333). **There is no shading in the voxel colours**: the engine's lighting does it.

| tree | role | RGB | hex | engine material | hue / sat / value |
|---|---|---|---|---|---|
| all broadleaf, dead, winter | bark | 67 52 27 | `#43341b` | `tr-43341b` | 37 / .60 / .26 |
| Tree | leaf dark | 45 109 75 | `#2d6d4b` | `tr-2d6d4b` | 148 / .59 / .43 |
|  | leaf mid | 27 129 62 | `#1b813e` | `tr-1b813e` | 141 / .79 / .51 |
|  | leaf light | 36 147 110 | `#24936e` | `tr-24936e` | 160 / .76 / .58 |
| Fall_Tree | dark | 202 122 44 | `#ca7a2c` | `tr-ca7a2c` | 30 / .78 / .79 |
|  | mid | 255 177 27 | `#ffb11b` | `tr-ffb11b` | 39 / .89 / 1.0 |
|  | light | 255 196 8 | `#ffc408` | `tr-ffc408` | 46 / .97 / 1.0 |
| pines | dark | 15 76 58 | `#0f4c3a` | `tr-0f4c3a` | 162 / .80 / .30 |
|  | mid | 9 97 72 | `#096148` | `tr-096148` | 163 / .91 / .38 |
|  | light | 32 96 79 | `#20604f` | `tr-20604f` | 164 / .67 / .38 |
| pines' trunk | bark | same as above | | | |
| willow | bark | 86 63 46 | `#563f2e` | `tr-563f2e` | 26 / .47 / .34 |
|  | teal dark (the pine's dark) | 15 76 58 | `#0f4c3a` | `tr-0f4c3a` | |
|  | teal mid | 0 137 108 | `#00896c` | `tr-00896c` | 167 / 1.0 / .54 |
|  | teal light | 0 170 144 | `#00aa90` | `tr-00aa90` | 171 / 1.0 / .67 |
|  | accent dark | 11 52 110 | `#0b346e` | `tr-0b346e` | 215 / .90 / .43 |
|  | accent mid | 0 92 175 | `#005caf` | `tr-005caf` | 208 / 1.0 / .69 |
|  | accent light | 58 143 183 | `#3a8fb7` | `tr-3a8fb7` | 199 / .68 / .72 |
| Willow_single_color | dark / mid / light | 11 52 110, 0 98 132, 125 185 222 | `#0b346e` `#006284` `#7db9de` | `tr-0b346e` `tr-006284` `tr-7db9de` | 215 / 195 / 203 |
| snow | white | 238 238 238 | | the engine's `snow` | 0 / 0 / .93 |

The rules behind the table, for choosing a new triad: **one hue family** (the greens run 141-171 degrees, the oranges 30-46, the blues 195-215), saturation .6-1.0, **value of the lightest 1.25-1.5 times the darkest**
(oak .43 / .51 / .58, autumn .79 / 1.0 / 1.0, pine .30 / .38 / .38; the willow's .30 to .67 is wider only because its dark is the pine's), the lightest shade moving a few degrees toward cyan (green) or yellow (orange).
Trees are **saturated and a little cold**: the greens are blue-greens, there is no yellow-green and no brown in a crown. The bark is the one warm dark: value .26-.34, saturation .5-.6.

### Autumn, winter, dead
- **Autumn** is the same crown layout with the orange triad. Nothing else changes.
- **Dead** is the skeleton alone.
- **Winter** = the skeleton moved **up 3 voxels**, all white (238,238,238), from the fork (z=45) up, with the skeleton drawn over it: 100 % of its 48,310 voxels have a branch voxel exactly 3 below, and the stem below the fork has none. Where a limb is wider than one voxel the white shows only on its upper edge: that is what a thin dusting is.

### Pines
- Height 128 (half the broadleaf's 256; at 1/1 it is 8 m, at 1/2 4 m: `tree_garden` imports the pines 1/1).
- **Six tiers** of branches: leaf layers at z = 14-30 (peak 20), 44-58 (46), 66-82 (70), 86-98 (90), 102-110 (106), 114-126 (120): as a share of the height 0.16, 0.36, 0.55, 0.70, 0.83, 0.94, **the gap shrinking** 26, 24, 20, 16, 14. Between tiers the trunk is bare.
- Leaf **radius per tier** 43, 36, 33, 25, 17, 10 (the lowest tier is the widest, 1/3 of the height on each side), about eight branches in the lowest tier at irregular angles (eight lobes in a 15-degree histogram; the upper tiers were not counted, the generator uses 8, 8, 7, 6, 5, 4), the layer is about 12 thick at the bottom and 8 at the top.
- Each branch **rises 2-3 then droops 8-11 at the tip**; the picture shows short bark side twigs, each with its own small clump. Needles: 7,228 voxels, **25-30 % fill**, three shades of one hue, independent. Bark: 5,264 voxels (44 % of the tree: pines show their branches).
- A tuft at the top (7-10 across, z=114-126) and a 2-3 wide leader up to z=127.
- **Snow** (`PineSnowy`): the needle set moved **up 1 voxel**, white, drawn over the needles (7,215 white voxels; 19 % of them replace a needle of the original, the rest are new voxels above it), the branches over everything. The result is a white cap on every clump with green showing underneath and at the front.

### Willows
- Trunk and limbs as above. **About 100 strands** (77 of more than 300 voxels, measured as connected pieces).
- A strand is **a vertical capsule**: circular cross-section of radius about 4.5-5 kept along its whole length (10 across, 8-14 for the fat ones), 52-95 long (median 64; the very long ones are neighbours merged), rounded ends, a slight lean. Fill 20-27 % overall, about 40 % on the axis. Its colours are drawn per voxel from the three shades of its family; **the family is chosen per strand**: about one strand in five is blue (19 % of the leaf voxels; of the 40 biggest pieces 33 were pure teal, the mixed ones are a teal and a blue strand that touch).
- They hang from the limbs and the tops of the strands are scattered from z=60 to z=255, the bottoms from 0 to 140: the tree's lower half is a curtain.
- `Willow_single_color` is the same strands with one triad (teal-blue, navy, pale blue): the variant is a **colour swap** (120,000 leaf voxels against 91,000: its strands are denser).

## Sizes at the engine's scale
Imported with `voxelith --convert-vox in.vox out.vxm --materials m.csv --vox-prefix tr --vox-scale N` (docs/GUIDE.md "Converting art"; a block of N^3 voxels becomes one that is solid when a quarter of it is).
The engine's own kit for comparison: oak 56 x 96 x 56 (3.5 x 6 x 3.5 m), birch 32 x 112, pine 40 x 118, willow 56 x 86, dead tree 40 x 80, bush 24 x 20.

| pack tree | 1/1 | 1/2 | 1/3 |
|---|---|---|---|
| Tree | 233 x 256 x 203 (14.6 x 16.0 x 12.7 m) | 117 x 128 x 102 (7.3 x 8.0 x 6.4 m) | 78 x 86 x 68 (4.9 x 5.4 x 4.3 m) |
| Fall_Tree | 225 x 256 x 203 | 113 x 128 x 102 | 75 x 86 x 68 |
| Winter_Tree | 210 x 259 x 203 | 105 x 130 x 102 | 70 x 87 x 68 |
| Dead_Tree | 210 x 256 x 203 | 105 x 128 x 102 | 70 x 86 x 68 |
| Willow | 188 x 256 x 188 | 94 x 128 x 94 | 63 x 86 x 63 |
| PineFluffy / PineSnowy | 77 x 128 x 79 (4.8 x 8.0 x 4.9 m) | 39 x 64 x 40 | 26 x 43 x 27 |

(width x height x depth in voxels.) Scaling keeps the stipple look: a block is solid when a quarter of its voxels are, so a 24 % crown becomes 61 % solid blocks at 1/2 and 48 % at 1/3 (the bumps stay, the
holes close), a 30 % crown 74 %. The voxel count falls with the cube: Tree is 768,000 voxels at 1/1, 222,000 at 1/2 and 55,000 at 1/3.
**1/3 is the engine oak's size and the right one for a forest, 1/2 a large tree, 1/1 a landmark** (a single Tree at 1/1 is 770k voxels).

## Making a new species: the checklist
1. **Pick the grid**: design on the pack's 256-tall grid (or 128 for something pine-sized) with the trunk at x = y = 0 and the ground at z = 0; the engine size follows from `--vox-scale`.
2. **Skeleton first**: a straight untapered trunk, 10 wide for a full tree (5 for a small one), 15-20 % of the height to the fork; limbs 1-3 voxels, arching (+35 degrees near the trunk, 0 in the middle, -20 at the tips), three generations, tips out to 0.8 of the height. No solid blobs of bark.
3. **Crown second**: balls (radius 9-14, or 1/8 to 1/5 of the crown's width) centred on the limbs and twigs, spaced so they overlap by a third; **never** fill the interior solid and never ellipsoid-fit.
4. **Stipple**: 24 % (21-30 % is the range the pack stays in) per voxel, decided once where balls overlap (the generator hashes the voxel's place), three shades drawn at random per voxel, **never by position**.
5. **Colour**: one hue family, three shades, value 1.25-1.5 between darkest and lightest, saturation .6-1.0; check it against the table above; the bark is `tr-43341b` (or `tr-563f2e` for the willow's cooler brown). A tree has 4 colours, not 40.
6. **Seasons** are crowns on the same skeleton (swap the triad) and white copies (+1 for needles, +3 for bare branches at 1/1 grid).
7. **Palette = materials**: every distinct colour becomes a material `tr-RRGGBB` (`--vox-prefix tr`; `tools/vox_materials.py classify TABLE.csv --prefix tr --kind trees` gives bark / foliage / snow the engine's wood / leaves / snow values: they burn, the white ones do not). The engine's `snow` takes the white.
8. **Check** against the pack: `tools/make_trees.py --stats new.vox pack.vox` prints the voxel count, bounding box, colours, the interior fill and whether the leaf shades are independent: the fill should be 0.24-0.35, the shade statistic equal to its chance value, the bounding box inside 0.8-0.9 of the height wide.

### Foliage that is not a tree (bushes, ferns, flowers, grass tufts, vines)
The same recipe, scaled: **stippled balls (or flat ellipsoids for ferns and ground cover) on a thin skeleton of 1-voxel lines, three shades per plant drawn per voxel, one bark colour, no shading in the colours.**
- A **bush** is a crown without a trunk: 3-6 balls of radius 8-12 g-units on 1-voxel stems, 24 % fill, the oak's triad or a close neighbour; at 1/3 it is about 20-30 voxels (the kit's bush is 24 x 20).
- A **fern** is a flat fan of 1-voxel ribs with a stippled ellipsoid (rz 2-3) round each rib: the pine's branch with the tier removed.
- A **flower** is a 1-voxel stem and 3-5 voxels of a fourth, saturated colour (the willow's blue accent is the model: a different hue on about a fifth of the voxels) in a stippled ball of the leaf triad.
- **Hanging things** (vines, moss, a weeping birch) are strands: vertical stippled capsules of radius 3-5 hanging from the limbs, one shade family per strand.
- A **new biome tree** keeps its own triad but the same value and saturation window and the same bark; a **palm** or a **cactus** can be a new skeleton (the cactus is a trunk that never forks) with the same stipple and triads.
- Never: solid leaf blocks, a gradient from dark at the bottom to light at the top, outlines, a 1-voxel dark rim, a fourth leaf shade in one crown, texture on the bark, a smooth sphere.

## The generator, and how close it gets
`tools/make_trees.py OUT_DIR [--only oak pine ...] [--seed N] [--preview DIR]` writes `oak`, `autumn_oak`, `bare_oak`, `winter_oak`, `pine`, `snowy_pine`, `willow`, `willow_ice` and `red_maple` as `.vox` files (the
last is not in the pack: the autumn recipe moved to red, as an example of adding a species; its three colours become new `tr-` materials). Deterministic: the same seed and the same species give the same bytes.
`--stats FILE.vox ...` reads any .vox (the pack's scene graph included) and prints counts, size, colours, interior fill and the leaf-shade randomness; `--preview DIR` writes front, side and top views as PNG.
To add a species: one line in `SPECIES` (`kind`, `triad`, and any of `crown`, `ball`, `balls`, `passes`, `snow` to override the kind's numbers) and a triad in `TRIADS`; see `red_maple`.

Compared with the pack, voxels per tree and bark voxels (seed 7; pack size in g-units width x depth x height):

| tree | pack voxels (bark) | generated (bark) | pack size | generated size |
|---|---|---|---|---|
| oak / Tree | 768,225 (52,606) | 758,013 (60,736) | 233 x 203 x 256 | 221 x 221 x 256 |
| autumn_oak / Fall_Tree | 423,841 (52,606) | 424,892 (62,308) | 225 x 203 x 256 | 200 x 207 x 248 |
| winter_oak / Winter_Tree | 92,855 (52,606) | 105,399 (61,345) | 210 x 203 x 259 | 189 x 206 x 256 |
| bare_oak / Dead_Tree | 52,606 | 63,206 | 210 x 203 x 256 | 187 x 202 x 248 |
| pine / PineFluffy | 12,038 (5,264) | 11,945 (3,755) | 77 x 79 x 128 | 78 x 79 x 128 |
| snowy_pine / PineSnowy | 17,555 (5,264) | 18,078 (3,731) | 77 x 79 x 128 | 85 x 78 x 128 |
| willow / Willow | 169,429 (80,398) | 160,912 (79,701) | 188 x 188 x 256 | 191 x 193 x 255 |
| willow_ice / Willow_single_color | 198,791 (80,398) | 168,118 (87,412) | 189 x 188 x 256 | 193 x 191 x 243 |

Crown statistics (autumn_oak against Fall_Tree): height percentile 5 / 50 / 95 of the leaf voxels 69 / 150 / 215 against 76 / 154 / 231, distance from the axis 5 / 25 / 50 / 75 / 95 percentile 18 / 38 / 57 / 73 / 91 against 20 / 41 / 61 / 76 / 94, interior
cells 16,796 against 15,003, interior fill 0.26 against 0.25, leaf-shade equality with the neighbour 0.33 against chance 0.33 (the pack: 0.33).

**What matches**: the voxel counts (within 15 %), the proportions (width 0.86-0.9 of the height, trunk to 17 % of it, crown from 0.17 to 1.0, its bulk from 0.30 to 0.90), the stipple (fill, independent shades, no
gradient), the palette (the exact colours), the one-voxel limbs, the pine's six tiers with the shrinking gaps and the droop, the willow's strands and its trunk, the snow as shifted copies.
**What does not**: (1) the pack's crowns have a **rounder, fuller outline** with fewer visible ball bumps; the generator's lumps are more regular and its lower crown is a little emptier at the very bottom. (2) The skeleton
is **more regular and more vase-shaped** than the pack's, which is a bushier, more tangled network with many short fragments (970 separate pieces; the generator's limbs are connected) and thicker limbs at the base; bark counts run 15-20 % high in the oaks
and 30 % low in the pines. (3) The generator's pine tiers are **evenly spaced angular fans**, the pack's are irregular (uneven lengths and heights, lopsided); the needle clumps are smaller and more uniform. (4) The willow's strands
hang a little less deep than the pack's and the limbs do not curl down to the ground as far; the `willow_ice` leaves are 30 % sparser (81k against 118k). (5) The oak's second crown pass is a new ball layout, not the first one turned 180 degrees as in the pack.
(6) The pack's trunk is off-centre in its cube by (-10, -11) and leans slightly; the generator's is exactly on the axis. None of these is visible at 1/3 next to the pack's trees; at 1/1 next to them the pack's crowns are a little rounder.
Pictures: `~/share/tree_style/cmp_*.png` (pack on top, generated below: front, side and top), `compare_pairs.png` (the engine, 1/3 scale, pack left of generated).

## Sources
The measurements come from reading `Trees/*.vox` voxel by voxel (scene graph applied) with scripts that are not kept: counts, connected components, the distance of every voxel to the nearest empty one, principal axes of the limbs, the stipple's
4-cell statistics, the colour shares per band. `tools/make_trees.py --stats` repeats the cheap ones (counts, fill, colour randomness). The pack's licence is unknown: its `.vox` sources are not in the repository (the converted models are in the starter kit, `assets/prefabs/nature/trees`, at the sizes below, because the owner asked for them; check the licence before the engine is shipped), and what was learned from them and
their colours.
