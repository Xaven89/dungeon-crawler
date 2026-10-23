# Converted art catalogue

Art packs the owner supplied (`Upload/`), converted into starter-kit models (`assets/prefabs`, docs/PREFABS.md) with the tools of docs/GUIDE.md "Converting art". Every model is placed by its plain name
(`prefab.place("chair_dark_brown.vxm", x, y, z)`) or from the Prefabs panel's starter kit; the colours are the kit's own materials (`assets/prefabs/materials.csv`, ids from 1000, one prefix per pack).
`projects/asset_gallery` places all of them in rows with their names (start it with `voxelith --project projects/asset_gallery`).

**Licences.** None of the packs has a known licence for redistribution: the Stylized Voxel Forest pack says in its own `LICENSE_STATUS.txt` that "owner distribution and license terms are pending" and that the preparation package "does not grant a license";
the others carry no licence text at all (the Voxel Magic pub set's ReadMe only names its author, Maria Starko). The models are in the repository because the owner asked for them: clear the licences before the engine or a game is published.

**Round 29: finer voxels.** The figures, the furniture, the kitchen things, chests, fences and the pub set are now stored **at their own voxel size** (a one-part rig with a voxel scale of 0.6: `--convert-vox ... --vox-unit 0.6`, palettes of up to 64 colours),
not resampled: stamped into the world (`prefab.place`, the Prefabs panel) they are resampled to the world's voxel and look as before, drawn as a body (`player.model`, `model.spawn{ visual = true }`, `agent.spawn{ collision = "proxy" }`) they keep every detail
(docs/ANIMATION.md "Voxel scale"). The sizes in the tables below are the file's voxels; the metres column is at the world's voxel (multiply a scaled model by its scale: a human of 49 voxels is 1.8 m).

## Packs and categories

| pack (Upload/) | what it is | kit folder | how it was converted | scale |
|---|---|---|---|---|
| `Characters.zip` | 9 chibi characters (5 humans, 4 monsters), one mesh each, T pose, no rig | `figures/humans`, `figures/monsters` | `.vox` as they are, palette cut to 32 colours (`tools/vox_palette.py`), `--vox-factor 0.6` | the source voxel is 3.75 cm, so a human of 49 voxels is 29 here (1.8 m) |
| `Furniture and props.zip` | 31 props: beds, chairs, tables, couch, drawer, wardrobe, oven, kitchen things, pots, statue, lamp post, campfire, 5 chests, 5 fence parts | `props/furniture`, `props/kitchen`, `props/decor`, `props/chests`, `props/fences` | as the characters (40 colours, factor 0.6: assumed to be drawn at the characters' scale, which gives a chair back of 1 m and a table of 0.5 m; they look right beside the figures) | 0.6 |
| `Voxel Magic PUB.rar` | a pub set: bar (a 48-voxel block, a wall with windows), table, stool, lamp, bottles, potted tree | `buildings/pub` | as the characters (24 colours, factor 0.6) | 0.6 |
| `mushroom/` | 4 giant fantasy mushrooms, thousands of shades | `nature/mushrooms` | 24 shared colours; `_l` as drawn (4 to 6 m), `_m` at 1/2 | 1/1 and 1/2 |
| `VoxelGraveyard_Assets.zip` | 12 OBJ meshes exported from MagicaVoxel (no `.vox`): ground plate, dead tree, ghost, 3 tombs, raven, fence, pillar, gravedigger in T pose and with a spade, spade | `graveyard` | `tools/mesh_to_vox.py --per-model-palette` on the exact voxel grid, then 24 shared colours, factor 1 | as drawn (the gravedigger is 28 voxels, 1.75 m) |
| `Stylized_Voxel_Forest_Full.zip` | 25 vegetation and rock models, true metre scale, vertex colours, LOD0 to LOD4 meshes (3.9 million triangles at LOD0) | `nature/forest/...` | LOD2 GLB through `tools/mesh_to_vox.py` (vertex colours, metres) at 6.25 cm, 48 shared colours; trees at 1/1 (`_xl`), 1/2 (`_l`), 1/3 (`_m`) | true scale |

The forest models are shells (the mesh is hollow); only the graveyard models were filled. Names were translated from Portuguese (`arvore_copa_larga_hero` is `broad_crown_hero_tree`, `moita_seca` `dry_shrub`, `samambaia` fern, `pedra` rock).

## Use and limits

- **Figures are statues.** They are single meshes in a T pose with no parts: the engine's animated models (docs/ANIMATION.md) need a rig of parts, so they cannot walk. Splitting one into head, torso, arms and legs and giving it a rig is a model-workspace job per figure (the part boundaries are obvious at 29 voxels).
- **Sizes**: at 1/1 the forest trees are 7.8 to 21.6 m tall (`tall_eucalyptus_xl` is 346 voxels high, the tallest model of the kit, over the 256 a `.vox` model holds, so it is stored from a scene of several parts and cannot be a physics body); `_l` and `_m` are the sizes for a village or a small world. Shrubs, plants and rocks are 0.2 to 3.6 m.
- **Weight**: `broad_crown_hero_tree_xl` has 324,000 voxels, `giant_purple_mushroom_1_l` 316,000, `graveyard_ground` 139,000: place the big ones sparingly.
- **Materials** were classified by colour (`tools/vox_materials.py classify --kind trees|props|stone`): green and teal are foliage, dark brown bark and wood (both burn like the engine's wood and leaves), the forest's rocks are all stone, grey is stone or iron, yellow-orange gold, other saturated colours cloth. Look at the table and edit it where the guess is wrong (a green painted chair is "foliage" to the classifier).
- **Looks**: in a flat grass world the lighting tints everything slightly cool and green; the same models in a biome world look as drawn.

## How a pack is converted

1. A `.vox` pack: `tools/vox_palette.py K OUT *.vox` (fewer colours, fewer materials), then `voxelith --convert-vox IN.vox OUT.vxm --materials TABLE.csv --vox-prefix xx --vox-factor F` per model (the same TABLE for the whole pack), then `tools/vox_materials.py classify TABLE.csv --prefix xx --kind ...`.
2. A mesh pack (OBJ with a palette or texture, GLB with vertex colours, FBX): `tools/mesh_to_vox.py` (reads all three, docs/GUIDE.md) makes `.vox` files, then as above. A scene `.vox` (one file, many named objects) is split with `tools/vox_split.py`.
3. Copy the `.vxm` files into `assets/prefabs/<folder>/` and merge the table: `tools/vox_materials.py merge assets/prefabs/materials.csv TABLE.csv --prefix xx`. The kit test (`starter kit: every model...`) loads every model against the built-in and the kit's materials.

## Models

### Humans (static T-pose figures) (`assets/prefabs/figures/humans/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `human_demon_girl` | 46 x 49 x 12 | 1.7 x 1.8 x 0.4 m |
| `human_man_adventurer` | 50 x 49 x 14 | 1.9 x 1.8 x 0.5 m |
| `human_man_samurai` | 50 x 51 x 11 | 1.9 x 1.9 x 0.4 m |
| `human_man_warrior` | 52 x 54 x 13 | 1.9 x 2.0 x 0.5 m |
| `human_woman_adventurer` | 46 x 50 x 12 | 1.7 x 1.9 x 0.4 m |

### Monsters (static T-pose figures) (`assets/prefabs/figures/monsters/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `monster_cyclop_pink` | 68 x 49 x 16 | 2.5 x 1.8 x 0.6 m |
| `monster_gold_golem` | 117 x 85 x 25 | 4.4 x 3.2 x 0.9 m |
| `monster_orc_captain_green` | 58 x 55 x 15 | 2.2 x 2.1 x 0.6 m |
| `monster_troll_blue` | 68 x 49 x 16 | 2.5 x 1.8 x 0.6 m |

### Furniture (`assets/prefabs/props/furniture/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `bed` | 15 x 19 x 29 | 0.6 x 0.7 x 1.1 m |
| `chair_dark_brown` | 14 x 27 x 14 | 0.5 x 1.0 x 0.5 m |
| `chair_dark_green` | 14 x 27 x 15 | 0.5 x 1.0 x 0.6 m |
| `chair_light_brown` | 14 x 27 x 14 | 0.5 x 1.0 x 0.5 m |
| `couch` | 32 x 21 x 18 | 1.2 x 0.8 x 0.7 m |
| `drawer_light_brown` | 21 x 19 x 14 | 0.8 x 0.7 x 0.5 m |
| `table_dark_green` | 35 x 13 x 14 | 1.3 x 0.5 x 0.5 m |
| `table_light_brown` | 35 x 13 x 14 | 1.3 x 0.5 x 0.5 m |
| `wardrobe_light_brown` | 33 x 34 x 19 | 1.2 x 1.3 x 0.7 m |

### Kitchen and tableware (`assets/prefabs/props/kitchen/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `glass_water` | 6 x 9 x 6 | 0.2 x 0.3 x 0.2 m |
| `glass_wine` | 8 x 18 x 8 | 0.3 x 0.7 x 0.3 m |
| `mug` | 7 x 7 x 5 | 0.3 x 0.3 x 0.2 m |
| `oven` | 24 x 24 x 24 | 0.9 x 0.9 x 0.9 m |
| `oven_glassless` | 24 x 24 x 24 | 0.9 x 0.9 x 0.9 m |
| `pan` | 7 x 3 x 12 | 0.3 x 0.1 x 0.4 m |
| `pot_silver` | 11 x 8 x 7 | 0.4 x 0.3 x 0.3 m |

### Decor (`assets/prefabs/props/decor/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `campfire_large` | 46 x 22 x 43 | 1.7 x 0.8 x 1.6 m |
| `designy_statue` | 7 x 37 x 22 | 0.3 x 1.4 x 0.8 m |
| `lamppost` | 16 x 62 x 10 | 0.6 x 2.3 x 0.4 m |
| `pot_cactus` | 8 x 14 x 8 | 0.3 x 0.5 x 0.3 m |
| `pot_flower` | 8 x 13 x 8 | 0.3 x 0.5 x 0.3 m |

### Chests (`assets/prefabs/props/chests/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `chest_light_brown` | 19 x 9 x 8 | 0.7 x 0.3 x 0.3 m |
| `chest_mysterious_blue` | 18 x 18 x 13 | 0.7 x 0.7 x 0.5 m |
| `chest_mysterious_dark` | 18 x 18 x 13 | 0.7 x 0.7 x 0.5 m |
| `chest_shining_green` | 12 x 11 x 8 | 0.4 x 0.4 x 0.3 m |
| `chest_skeleton` | 19 x 9 x 8 | 0.7 x 0.3 x 0.3 m |

### Wooden fence parts (`assets/prefabs/props/fences/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `wood_fence_corner` | 20 x 18 x 20 | 0.8 x 0.7 x 0.8 m |
| `wood_fence_middle` | 2 x 13 x 16 | 0.1 x 0.5 x 0.6 m |
| `wood_fence_part_1` | 4 x 18 x 20 | 0.1 x 0.7 x 0.8 m |
| `wood_fence_part_2` | 4 x 18 x 20 | 0.1 x 0.7 x 0.8 m |
| `wood_fence_pole` | 4 x 18 x 4 | 0.1 x 0.7 x 0.1 m |

### Pub set (`assets/prefabs/buildings/pub/`) (voxel scale 0.6: voxels of 3.75 cm)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `pub_bar` | 80 x 80 x 80 | 3.0 x 3.0 x 3.0 m |
| `pub_bottles` | 15 x 14 x 5 | 0.6 x 0.5 x 0.2 m |
| `pub_lamp` | 12 x 18 x 6 | 0.4 x 0.7 x 0.2 m |
| `pub_stool` | 14 x 17 x 14 | 0.5 x 0.6 x 0.5 m |
| `pub_table` | 18 x 25 x 42 | 0.7 x 0.9 x 1.6 m |
| `pub_tree` | 21 x 57 x 17 | 0.8 x 2.1 x 0.6 m |

### Giant mushrooms (`assets/prefabs/nature/mushrooms/`)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `giant_blue_shroom_l` | 62 x 79 x 62 | 3.9 x 4.9 x 3.9 m |
| `giant_blue_shroom_m` | 31 x 40 x 31 | 1.9 x 2.5 x 1.9 m |
| `giant_large_blue_shroom_l` | 95 x 88 x 101 | 5.9 x 5.5 x 6.3 m |
| `giant_large_blue_shroom_m` | 48 x 44 x 51 | 3.0 x 2.8 x 3.2 m |
| `giant_purple_mushroom_1_l` | 100 x 101 x 93 | 6.2 x 6.3 x 5.8 m |
| `giant_purple_mushroom_1_m` | 50 x 51 x 47 | 3.1 x 3.2 x 2.9 m |
| `giant_purple_mushroom_2_l` | 98 x 90 x 101 | 6.1 x 5.6 x 6.3 m |
| `giant_purple_mushroom_2_m` | 49 x 45 x 51 | 3.1 x 2.8 x 3.2 m |

### Forest trees (`assets/prefabs/nature/forest/trees/`)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `australian_acacia_l` | 62 x 57 x 88 | 3.9 x 3.6 x 5.5 m |
| `australian_acacia_m` | 41 x 38 x 59 | 2.6 x 2.4 x 3.7 m |
| `australian_acacia_xl` | 124 x 114 x 176 | 7.8 x 7.1 x 11.0 m |
| `broad_crown_hero_tree_l` | 125 x 99 x 130 | 7.8 x 6.2 x 8.1 m |
| `broad_crown_hero_tree_m` | 83 x 66 x 87 | 5.2 x 4.1 x 5.4 m |
| `broad_crown_hero_tree_xl` | 250 x 198 x 260 | 15.6 x 12.4 x 16.2 m |
| `broadleaf_tree_l` | 60 x 74 x 68 | 3.8 x 4.6 x 4.2 m |
| `broadleaf_tree_m` | 40 x 49 x 45 | 2.5 x 3.1 x 2.8 m |
| `broadleaf_tree_xl` | 119 x 148 x 136 | 7.4 x 9.2 x 8.5 m |
| `rough_bark_tree_l` | 92 x 123 x 107 | 5.8 x 7.7 x 6.7 m |
| `rough_bark_tree_m` | 61 x 82 x 71 | 3.8 x 5.1 x 4.4 m |
| `rough_bark_tree_xl` | 184 x 246 x 214 | 11.5 x 15.4 x 13.4 m |
| `tall_eucalyptus_2_l` | 71 x 168 x 81 | 4.4 x 10.5 x 5.1 m |
| `tall_eucalyptus_2_m` | 47 x 112 x 54 | 2.9 x 7.0 x 3.4 m |
| `tall_eucalyptus_2_xl` | 142 x 336 x 162 | 8.9 x 21.0 x 10.1 m |
| `tall_eucalyptus_l` | 64 x 173 x 69 | 4.0 x 10.8 x 4.3 m |
| `tall_eucalyptus_m` | 43 x 115 x 46 | 2.7 x 7.2 x 2.9 m |
| `tall_eucalyptus_xl` | 128 x 346 x 138 | 8.0 x 21.6 x 8.6 m |
| `twisted_forest_tree_l` | 81 x 87 x 79 | 5.1 x 5.4 x 4.9 m |
| `twisted_forest_tree_m` | 54 x 58 x 53 | 3.4 x 3.6 x 3.3 m |
| `twisted_forest_tree_xl` | 162 x 174 x 158 | 10.1 x 10.9 x 9.9 m |

### Forest shrubs and ferns (`assets/prefabs/nature/forest/shrubs/`)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `bush_broadleaf_1` | 21 x 21 x 25 | 1.3 x 1.3 x 1.6 m |
| `bush_irregular_1` | 44 x 34 x 42 | 2.8 x 2.1 x 2.6 m |
| `bush_round_1` | 32 x 31 x 33 | 2.0 x 1.9 x 2.1 m |
| `dense_low_fern_1` | 19 x 5 x 19 | 1.2 x 0.3 x 1.2 m |
| `dry_shrub_1` | 28 x 23 x 32 | 1.8 x 1.4 x 2.0 m |
| `medium_fern_1` | 24 x 10 x 21 | 1.5 x 0.6 x 1.3 m |
| `tree_fern_1` | 70 x 74 x 67 | 4.4 x 4.6 x 4.2 m |
| `wide_fern_hero_1` | 67 x 26 x 76 | 4.2 x 1.6 x 4.8 m |

### Forest ground plants (`assets/prefabs/nature/forest/plants/`)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `ground_foliage_1` | 17 x 3 x 21 | 1.1 x 0.2 x 1.3 m |
| `low_grass_1` | 11 x 5 x 11 | 0.7 x 0.3 x 0.7 m |
| `medium_grass_1` | 16 x 11 x 15 | 1.0 x 0.7 x 0.9 m |
| `rotated_plant_1` | 16 x 16 x 14 | 1.0 x 1.0 x 0.9 m |
| `tall_grass_1` | 25 x 23 x 23 | 1.6 x 1.4 x 1.4 m |

### Forest rocks (`assets/prefabs/nature/forest/rocks/`)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `rock_1` | 26 x 16 x 20 | 1.6 x 1.0 x 1.2 m |
| `rock_2` | 22 x 12 x 16 | 1.4 x 0.8 x 1.0 m |
| `rock_3` | 44 x 12 x 29 | 2.8 x 0.8 x 1.8 m |
| `rock_4` | 16 x 40 x 15 | 1.0 x 2.5 x 0.9 m |
| `rock_5` | 58 x 36 x 46 | 3.6 x 2.2 x 2.9 m |

### Graveyard (`assets/prefabs/graveyard/`)

| model | voxels (x, y up, z) | metres |
|---|---|---|
| `graveyard_dead_tree` | 66 x 51 x 44 | 4.1 x 3.2 x 2.8 m |
| `graveyard_fence` | 21 x 20 x 3 | 1.3 x 1.2 x 0.2 m |
| `graveyard_ghost` | 10 x 20 x 14 | 0.6 x 1.2 x 0.9 m |
| `graveyard_ground` | 80 x 30 x 80 | 5.0 x 1.9 x 5.0 m |
| `graveyard_igor_tpose` | 38 x 28 x 11 | 2.4 x 1.8 x 0.7 m |
| `graveyard_igor_with_spade` | 32 x 28 x 18 | 2.0 x 1.8 x 1.1 m |
| `graveyard_pillar` | 5 x 23 x 4 | 0.3 x 1.4 x 0.2 m |
| `graveyard_raven` | 8 x 5 x 3 | 0.5 x 0.3 x 0.2 m |
| `graveyard_spade` | 2 x 9 x 32 | 0.1 x 0.6 x 2.0 m |
| `graveyard_tomb_1` | 12 x 20 x 12 | 0.8 x 1.2 x 0.8 m |
| `graveyard_tomb_2` | 11 x 7 x 12 | 0.7 x 0.4 x 0.8 m |
| `graveyard_tomb_3` | 16 x 15 x 12 | 1.0 x 0.9 x 0.8 m |
