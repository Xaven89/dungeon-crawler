# Ground cover v2 (discussion with the fable session)

> Status (2026-10-19): **phases A and B built** (A: far-field tint, patch noise, taper / lean / splay, the gradient for every type, dithered LOD, tour GPU mean unchanged at 12.3 ms; B: sprites, wetness, season); phase C: the trample + scorch map, 32 disturbers, blast gusts (built; the toroidal persistent cell records were NOT built: the ground pass costs 0.14 ms of the 12.3 ms tour mean, the splat 0.98 ms, so they would save almost nothing), phase D (second ring, kelp, painted masks) not. Written against d0f5e37.
>
> **Phase D built (2026-10-19):** under-water cover (`under_water`: the ground pass marches on through a water surface, blades stop below it; GPU test + a Cove kelp row), painted masks (`@mask` line + `mask` column, a PNG read by `world/png_read.*` into the type buffer, sampled bilinearly in the ground pass), and the second ring for tall types (`far_ring`: cells of 4 voxels, blades x2, layer 1 of the ground pass, ids `cell << 7 | k` with cells past N x N). Not built from the plan: the toroidal persistent records.



Written against d0f5e37 (read-only): `shaders/foliage.glsl`, `foliage_ground.comp`, `foliage_splat.comp`, `particle_resolve.comp`, the foliage parts of `shade.comp`, `raymarch.comp`, `renderer.cpp`, `particle_gpu.cpp`, `world/ground_cover.*`, docs/FOLIAGE.md, the Cove's `foliage.csv`. Numbers are from the shaders and HANDOVER's "0.7-2 ms GPU", not from a fresh profile (I did not run the GPU).

## 1. Recommendation

**Do the far field first.** The thing that makes a meadow read as a meadow is not better blades: it is that beyond 24 m the ground is a flat green voxel field with a hard line where the tufts stop. One pass over `shade.comp` (tint the top faces of cover-bearing materials toward the type's cover colour with a density noise, fading in where the blades fade out) buys more at 150 m than any blade shape buys at 3 m, costs a few ALU per pixel, touches no CPU and no buffer layout. With it, the 24 m pop becomes a soft transition and the radius setting stops being a quality knob people notice.

**Then variety through the table, not through new geometry:** taper, lean, a second octave of patch noise (glades, tall patches, flower fields), a wetness and a season input. All of these are columns plus a few lines in `foliageCube()` / `foliage_ground.comp`.

**Then sprites:** small voxel models per cell (fern, mushroom, flower, pebble, litter) through the same id-keyed cube path. Feasible, the id has 8 spare bits, but it is the one item that changes the record and id layout, so it goes after the cheap wins and gets its own golden image.

**Then persistent trampling and scorch** as one small GPU map (no CPU, no save). **Cut** for now: collision, regrowth that survives a restart, cover on walls and ceilings, curved blades beyond a lean, per-cell slope and shade inputs, painted masks (until there is a level that needs one).

Ranked by visual gain per cost (gain / GPU cost / risk, 1 low .. 5 high):

| | item | gain | cost | risk | phase |
|---|---|---|---|---|---|
| 1 | far-field tint of cover materials (2.1) | 5 | 1 | 1 | A |
| 2 | second-octave patch noise: density, height, type mix per world position (3.1) | 4 | 1 | 1 | A |
| 3 | taper and lean per type (1.1) | 3 | 1 | 1 | A |
| 4 | fix: the root-to-tip gradient is keyed to material ids 16..18 (7) | 2 | 0 | 0 | A |
| 5 | wetness / rain input, season tint (4.2, 4.6) | 3 | 1 | 1 | B |
| 6 | sprites: small models as cover (1.3) | 4 | 3 | 3 | B |
| 7 | persistent trampling + scorch map (4.1, 4.3) | 3 | 1 | 2 | C |
| 8 | toroidal cell records: march only new / dirty cells (6) | perf | 2 | 2 | C |
| 9 | second ring with 4-voxel cells to ~48 m, tall types only (2.2) | 2 | 2 | 2 | C, only if the tint leaves reeds popping |
| 10 | underwater cover (kelp) (5) | 2 | 2 | 3 | D, after a screenshot test |
| 11 | painted masks (3.3) | 2 | 2 | 1 | D, when a level needs one |
| 12 | slope / shade / water-distance inputs per type (3.2) | 1 | 3 | 2 | cut |
| 13 | curved blades, clump shapes beyond lean + taper + sprites (1.1, 1.2) | 1 | 2 | 2 | cut |
| 14 | collision, regrowth saved with the world | 1 | 4 | 4 | cut |

## 2. The far field (item 1): what and where

`shade.comp:215` computes `albedo = m0.rgb * (0.93 + 0.14 * hash)` for the world hit. Add, for a hit whose face is the top face (`face == 2`) and whose material has cover (`coverMap[mat].x != 0`):

```
float d = hit distance (already there);
float w = smoothstep(16 m, 26 m, d);                       // where the blades thin out (LOD: 1 blade at 10 m, half the cells at 19 m, none at 24 m)
uint h = hash of (cell.xz >> 1)  (the same folHash + cell key the ground pass uses, so the far field's grain matches the near field's tufts);
float dens = type density * patch noise(cell >> 3) (the same `cls` noise as the ground pass: tall patches are greener/darker far away too);
vec3 cover = type.main colour, darkened toward `dark` by the patch class;
albedo = mix(albedo, cover, w * dens * 0.8);
```
Also a cheap "fuzz": at the far field the top face's shading normal can be tilted by a tiny hash (the blades' silhouette): skip unless it is free.

Where the data comes from: `shade.comp` binds only set 0 (no `coverMap`, no `ftypes`). Two ways: (a) bind the foliage type buffer (binding 10 of the particle set) into shade's set, or (b) pack a per-material `coverTint` (rgb + density, 32 bits) into the material table shade already reads, computed by `packCover` from the material's first type. (b) is cleaner and costs nothing per pixel; (a) gives the per-type mix. Take (b).

The hard line also exists in reverse: tufts appear at 24 m from nothing. With the tint the blades fade *into* the tinted ground; make the LOD cull in `foliage_splat.comp` (`zc > 300` half cells) dither by hash over 20..24 m instead of a step.

Planetoids: the ground pass marches along -Y, so a planetoid's sides have no blades; the tint keyed to `face == 2` has the same limit. Keying it to "the face whose normal is within 45 degrees of the local up" is one dot product if shade has the gravity up at the hit (`gravity.glsl` exists); the blades stay -Y only. Say so in FOLIAGE.md.

Test: a golden image from 100 m over the Cove meadow with foliage on, compared with foliage off: the meadow is visibly greener and grainier, the lake shore and the paths are not. Second image at 20 m: no visible line.

## 3. Variety by table (items 2, 3, 5)

**Patch noise (item 2).** `foliage_ground.comp:40-43` already has an 8-cell (0.8 m) patch class. Add a second, larger octave per type: `patch_scale` (cells, e.g. 48 = 4.8 m) and three amounts: `patch_density` (glades: cells skipped where the noise is low), `patch_height` (tall patches), `patch_type` (where the noise is high the *second* type of the surface wins: flower fields in a clover meadow). The value noise is two `folHash` lookups and a bilinear mix (the scatter planner's `valueNoise` is the CPU twin; keep the same formula so a Lua rule and the shader agree if a level ever wants to). Cost: one more hash per cell in the ground pass. The 4-bit `cls` in the record stays; the glade decision is made in the ground pass (the cell is dropped), the tall decision modulates `cls`, the type decision replaces `ct`. Nothing new in the record.

**Taper and lean (item 3).** In `foliageCube()`: `half_ *= mix(1.0, taper, u)` (taper 0.4 for grass, 1.0 for reeds and moss) and a per-type base lean direction from the blade hash plus a `lean` column (`centre.xz += leanDir * lean * uu * H`; the wind already uses `uu * H * 0.35`, lean is the same term at rest). A curved blade is this lean with `uu` replaced by a quadratic in u: already the shape. Clump shapes (item 13): a tuft with blades radiating from the centre is `spread` plus a lean that points *away* from the tuft centre (`leanDir = normalize(root - tuftCentre)`): one line, call it `splay`. That is as far as cube stacks go; anything else is sprites.

**Wetness and season (item 5).** Two floats in `fwind` (zw hold the wind direction; add a vec4 for wet, season and two spares): `wet` (0..1, from the rain system: raining now, decaying over a minute after) and `season` (0..1, a Lua-settable render parameter). Per type: `wet_dark` (albedo multiplier at wet = 1, 0.75 for grass), `wet_lean` (extra lean, rain beats the blades down), `season_colour` (a material: autumn yellow, winter grey) mixed by `season`. Snow needs nothing: snow voxels on top take the top face (the cover rule). CPU touch: the rain flag and the season value are sim-to-render parameters, one way, never read back: fine. A Lua `world.season(x)` must be a logged action only if anything in the sim ever reads it; keep it render-only and document that.

## 4. Sprites (item 6): small models as cover

Feasible in the splat pass, with one layout change:
- Id today: `FOL_BASE | cell << 5 | blade << 3 | cube`. `kFoliageCells` = 384, so `cell` needs 18 bits; bits 23..30 are free (8 bits). Change to `FOL_BASE | cell << 7 | k` with `k` = 0..127 the cube index: for blade types `k = blade * 8 + cube` (unchanged meaning, 24 of 128 used), for sprite types `k` indexes the model's *solid cube list*. 128 cubes is enough for a 5x5x4 fern or a 3x3x6 flower as half-voxel cubes if the model is hollow-culled (interior cubes contribute nothing; cull at pack time); a solid 8x8x8 would be 512, so cap sprites at 128 surface cubes and reject bigger ones in `packCover`. No change to `kFoliageCells` is needed; the id stays under bit 31.
- Sprite data: per type up to 128 entries of `x | y << 4 | z << 8 | half << 12 | colourSlot << 14` (16 bits each: 256 bytes per type, 2 KB for 8 types) appended to `FoliageTypeBuf`. `foliageCube(id)` branches on the type's kind: blade (today's code) or sprite (`entry = sprites[type][k]`; centre = root + entry.xyz * 0.5 voxel, turned by one of four yaw rotations from the cell hash, scaled by `sprite_scale` from the table, leaning with the wind at the top only: `lean * (y / height)^2` as today). Colours: 4 slots per sprite (`colourSlot`) mapped to table materials (`main`, `dry`, `dark`, `flower`), so a mushroom is cap + stem, a fern is frond + stem, a flower is petals + stem, and the dry / dark hash variation keeps working.
- Authoring: the sprite model is a `.vxm` in the project (`sprite = "models/fern_small.vxm"` column); `packCover` voxelises it to the cube list with the model's materials mapped to the four slots by name (unknown materials go to `main`). At most 8x8x8 voxels, read at load, so `check_project` can report "sprite fern_small.vxm has 190 surface cubes (max 128)".
- Cost: a sprite cell costs its cube count instead of up to 24; a fern at density 0.3 on dirt is about the same as grass on grass; a dense mushroom lawn is not. The guard is `density` and the 48-pixel cap per cube. Risk: the splat's `break` on the first missing cube ("blades are contiguous") must become `continue` for sprites (or the list is contiguous by construction: it is).
- The resolve pass needs nothing but the new `foliageCube`; the shade's `isParticle && matId 16..18` special case is item 4 (fix it first: key it on the id's `FOL_BASE` bit in `gVox.w`, see 7).

Test: a golden image with the Cove's `ferns` type as a sprite; a `vx_gpu_tests` case that packs a 9x9x9 model and expects the error.

## 5. Interaction and the one small map (items 7, 10)

**Trampling with memory and scorch.** One R8G8 image of 512 x 512 cells in *absolute toroidal* addressing (`texel = cell & 511`): no scrolling, no copy when the camera moves, 512 KB. Channel R = press (0..1), G = scorch. Written by a tiny pass after the ground pass: for each disturber (`fdist`, already uploaded: player and moving bodies) `press = max(press, f)` over its radius; for each cell whose surface material is Ember or Char (the ground pass knows the hit material) `scorch = 1`. Decayed every frame by `dt / recover` (press recovers in ~20 s, scorch in ~5 minutes). Read in `foliageCube()`: `press = min(press, 1 - 0.7 * map.r)` and the lean keeps the last push direction? No: direction is not stored; a pressed blade lies toward its own hash direction (lean += hashDir * map.r), which reads as flattened grass well enough. Scorch: colour toward `dark` and height halved; it also means grass next to a burnt patch is singed, which the voxel state cannot say. Fire itself already works: a burning grass voxel is the Ember material, `coverMap[Ember]` is empty, the tufts vanish with it, Char grows nothing. If `fire_cover = "burn"` is wanted (tufts that flame), it is the Flame colour on the top cubes for cells whose neighbour cell is Ember: one neighbour lookup in the ground pass of the *previous* frame's record, which needs the toroidal records of item 8. Do scorch first, flaming tufts with item 8.
CPU touch: none. The disturbers come from the same list the wind already gets; nothing is read back; a restart loses the map (grass stands up again): acceptable and documented. Determinism: pure rendering. The only trap is the trample write being frame-rate dependent (press per frame, not per tick): write `max`, not `+=`, and decay by wall time.

**Mowing / blasts** need nothing: the voxel goes, the cover goes.

**Wind gusts from explosions**: a disturber with a large radius and a short life pushed into `fdist` by the blast (CPU side knows the blast; it is a render hint, fine). One entry in the disturber list.

## 6. Performance and the record (item 8)

Where the time goes today: the ground pass is 147k vertical `marchWorld` calls of up to 900 voxels (from 400 voxels above the camera) every frame, about 60 % of the cells taken; the splat is up to 1.3 M cube tests near the camera, each a pixel box loop, bounded by the 48-pixel cap; the resolve is one `foliageCube` per pixel that won. HANDOVER's 0.7-2 ms is mostly ground + splat; a second and third type do not change that (the per-cell cost is a few more lookups), so the table scales fine. What scales badly: sprites with many cubes at high density, and the second ring (another 147k marches).

The one structural change worth making: **persistent cell records**. The window is camera-relative (`slot = g.y * N + g.x`, origin moves with the camera), so every frame re-marches everything. With `slot = (cell.y & 383) * 384 + (cell.x & 383)` (toroidal, absolute), a cell's record survives until the camera moves 384 cells; per frame only the rows / columns that entered the window need marching, plus a round-robin refresh (1/8 of the cells per frame) that picks up edits within 130 ms, plus an immediate refresh of cells inside chunks the CPU edited this frame (the edit queue knows them; a list of up to 64 chunk keys in the params). That cuts the ground pass by 5-8x and is what the trample map and flaming tufts want anyway (same addressing). The splat and resolve are unchanged (they read records by slot; the id's `cell` becomes the slot: fine). Risk: a stale cell after a dig for up to 8 frames; the dirty list fixes the common case.

The record: `fcells` is a uvec4 of x, y, z as float bits plus the packed word. x and z are *derived* (cell centre + hash jitter); storing them wastes 64 bits that items 4 and 5 want (sprite yaw and variant, press/scorch cache, the surface material for the far tint / flaming neighbour test, a slope byte). Rebuild x and z in `foliageCube()` from the cell index and keep y, the packed word and two free words. The packed word has no spare bits now (valid 1, type 3, class 4, hash 24); the peer's "3 spare bits" are the type bits since d0f5e37. The 24-bit hash is plenty (blade hash, colour, flower, jitter are all derived from it with `folHash(hc * 4 + blade + 77)`); a sprite yaw needs 2 bits of it, fine.

## 7. Traps in the current shaders

- `shade.comp:216`: the root-to-tip gradient (`albedo *= mix(0.45, 1.15, state)`) applies only to `matId 16..18` (tuft, tuft-dry, tuft-dark). The Cove's reed, moss, fern and clover types get no gradient (flat colour), and flower heads of those ids would get it wrongly. Fix without a new bit (`gData` has none free: 28..29 are the LOD level, 30 body, 31 particle): shade already loads `gVox`, whose w is the particle id, and foliage ids have bit 31 set (`FOL_BASE`), so the test is `isParticle && (vx.w & 0x80000000u) != 0u`. One line.
- `foliage_ground.comp:27`: `hit.face != 2` and the -Y ray: no cover on planetoids and flipped rooms (the blades grow toward world +Y however gravity points). Document; the local-up version (a march along -up, blades along up) is a day of work and is not the next thing.
- The LOD in `foliage_splat.comp:18-19` is by `zc` (camera depth), a hard step at 160 and 300 fine voxels: dither it by hash over a 40-voxel band (see 2).
- TAA (`taa_resolve.comp:48`): blades have no reprojection, so they get the "moving" treatment (less history, more shimmer under wind). The far tint is static geometry and gets full history: another reason to let the tint carry the distance.
- `forg.w` disturbers: 16; a crowd of crates in the grass drops the later ones silently. The trample map removes the need for persistence but the per-frame press still reads `fdist`; raise to 32 or sort by distance on the CPU (it already picks the nearest moving bodies).
- `foliage_ground.comp:18`: `maxDensity` is recomputed per cell from the 8 types (trivial, but it is a loop per cell: hoist it into the params).
- `uint(maxDensity * 256.0)` vs `h >> 24`: density 1.0 gives 256, so every cell passes; a density above 1 is meaningless: clamp in `packCover`.
- The Cove's reeds: `stiffness 0.45` and `blades 2, half 0.18`: at 0.18 the cube is 1.1 cm; at 1080p that is sub-pixel beyond 5 m and the atomicMin pixel loop still runs per cube. A minimum half of 0.22 beyond 8 m (`half_ = max(half_, zc * 0.0004)`) keeps thin types visible and the loop short.
- Underwater (item 10): `raymarch.comp:66-71` stores up to two see-through layers and the opaque hit behind them; `particle_resolve.comp:18` writes a particle whenever `t < gDepth` (the opaque hit), so a cube between the water surface and the lake bed becomes the opaque hit and the water layer is composited over it. Kelp then needs only the ground pass to continue through liquids: set `gSkipT = 2` for a second march when the first hit is a liquid top (`isLiquidVoxel`) and the surface material under it has a type with `under_water = 1`. Likely works as is; verify with one screenshot of a reed type on the lake bed before building the table column. Risk: the under-water tint of the layer may already be right for free, or may double-tint; one screenshot tells.

## 8. Which alternatives need shader work (item 5 of the questions)

| type | table row | needs |
|---|---|---|
| reeds, cattails (sand / mud at the shore) | yes (Cove has reeds) | cattail head = flower column with a tall `flower_half`; "near water" = the surface material (sand, mud) as the proxy, no distance test |
| moss, lichen (stone) | yes (Cove has moss) | nothing; lichen = moss with `half 0.5, h_max 1` (flat pads) |
| ferns (dirt, under trees) | yes, as blades (Cove) | real fronds = sprites (phase B); "under trees" = `avoid`-style shade is cut: use the dirt material scatter leaves under trees |
| flower meadows | yes (`flower_mask`, patch_type for fields in phase A) | nothing |
| desert shrubs | sprite | sprites |
| pebbles, twigs, leaf litter | sprite with `stiffness 0`, lying flat | sprites; litter under trees = a type on the `dirt` / leaf-litter material the tree scatter could stamp as a 1-voxel ring under each tree (a scatter `floor` option: cheap, CPU side, deterministic) |
| seaweed, kelp | table + `under_water` | the second march through liquid (7) |
| mushrooms | sprite | sprites |
| snow | nothing | the top-face rule |

## 9. Phases and tests

**Phase A (one day, do this if you get one):** far-field tint via a per-material cover tint in the material table (2); second-octave patch noise with `patch_scale / patch_density / patch_height / patch_type` columns (3); `taper`, `lean`, `splay` columns (3); the foliage bit in `gData` and the gradient keyed on it (7); dithered LOD bands. Tests: two golden images (100 m meadow, 20 m seam), the existing foliage golden stays within its tolerance with the default table, `check_project` reports the new columns' ranges, tour GPU mean within +0.3 ms.

**Phase B (two days):** wetness + season params; sprites (id `cell << 7 | k`, sprite table, `packCover` voxelisation with the 128-cube cap, four colour slots); Cove ferns and a mushroom type as sprites. Tests: golden image with sprites; a pack test for the cap; tour GPU mean within +0.5 ms with the Cove table.

**Phase C (two days):** toroidal persistent records with round-robin refresh and the edited-chunk list; the trample + scorch map; flaming tufts next to Ember; disturber cap to 32 and an explosion gust. Tests: a dig removes tufts within 8 frames (a GPU test that edits and counts cover pixels); a walk through grass leaves a visible track that is gone after 30 s (two screenshots); GPU mean *lower* than phase B.

**Phase D (when needed):** the second ring for tall types; kelp after the screenshot check; painted masks as a project PNG sampled in the ground pass (1 texel per 8 voxels).

**Cut:** collision and saved regrowth (the cover is rendering, and the moment it has sim state every rule in CLAUDE.md about determinism applies to grass); curved blades beyond lean + taper; slope / shade / water-distance inputs per cell (3 extra marches per cell for a rule the material already approximates); cover on walls and ceilings for now.

## 10. Where CPU state would creep in (the determinism line)

Nothing above reads back from the GPU or changes what the sim does. The things that *look* like state and are not: the trample map (GPU-only, lost on restart), the scorch map (same), wetness (a render param derived from the rain system), the season (a render param; if a Lua API sets it, log it as an action anyway so a replay's screenshots match, the way `time_of_day` is handled). The thing that would be state: regrowth that persists, or cover that stops the player or burns on its own. If the user ever wants cut grass to stay cut after a reload, the honest answer is a world-side bit per surface voxel (the voxel state byte has room: "mown") written by an edit op, read by the ground pass, and saved with the chunk; that is a sim feature with an action log entry, not a render feature, and it is a day on its own. Say that when the question comes rather than growing it into the map.
