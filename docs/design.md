

# Voxelith Engine — Design & Implementation Document

 · 

## 1. Vision & goals

Voxelith is a C++20 / Vulkan 1.3 engine in which everything that exists in the world is a small voxel: terrain, buildings, props, characters, debris and even particles. Nothing is a traditional polygon mesh, so every object can be broken, carved, welded or thrown without special cases. The second pillar is gravity as a first-class, composable field: planets, tubes, flipped rooms and point-wells in the style of Super Mario Galaxy, cheap enough to sample for tens of thousands of bodies and millions of particles per frame.

Design principles

One primitive. A voxel is 1/16 m (6.25 cm) in the world grid; characters and hand-held props use the same grid or a 1/32 m sub-grid. Everything in the renderer, physics and lighting operates on this one representation.

Edits are the common case, not the exception. Data structures are chosen for cheap, local mutation first and for rendering second. A single voxel write should cost microseconds, not a chunk remesh.

Gravity is data, not code. Levels compose gravity from a handful of field primitives; the solver never special-cases a level.

GPU-resident world. The visible world lives in GPU memory in the same layout the CPU edits, so rendering, lighting, particles and most collision queries never copy data across the bus.

Deterministic simulation. Fixed 60 Hz physics tick, integer voxel coordinates, seeded randomness. This makes replays, debugging and a future netcode layer possible.

Targets (v1.0)

Metric

Target

Frame rate

60 fps at 1440p on an RTX 4060 / RX 7600 class GPU, 120 fps at 1080p

Streamed world

2 km × 2 km × 512 m, fully editable, ~200 m detail radius around each camera

Voxel edits per second

1,000,000 sustained (explosions, digging, fluid-like debris) without a frame hitch

Dynamic voxel bodies

2,000 awake rigid bodies, 50,000 asleep

Particles

2,000,000 GPU particles, of which 100,000 may settle back into the world as voxels

Gravity samples

10,000,000 field evaluations per frame on GPU, 100,000 on CPU

Lighting

Dynamic global illumination with one bounce, emissive voxels as light sources, 4-cascade sun shadows, no baking

Foliage

500,000 visible ground-cover instances and 4,000 trees in the detail radius, all cuttable, burnable and wind-driven

Liquids

4,000,000 active liquid cells per tick flowing under any gravity field, at 1.5 ms GPU

Non-goals for v1

No skinned polygon meshes or imported triangle assets beyond editor gizmos and UI.

No networking (determinism keeps the door open for v2).

No mobile or console-specific backends; desktop Windows and Linux only.

No Navier-Stokes or ocean-scale fluid dynamics; liquids are the cellular-automaton voxel solver in Section 11.

## 2. Core architecture

The engine is a set of layered modules around one shared world store. Modules below never call modules above; the renderer, physics and particle systems all read the same GPU-resident voxel data and write edits through one edit queue.

Arrows run downward only: upper layers depend on lower ones, and the gravity module (accented) is the one piece sampled by physics, particles and gameplay alike.

Modules

Module

Responsibility

Depends on

core

Memory arenas, job system, math (integer-friendly), logging, profiling markers

—

world

Voxel storage, chunks, palettes, brickmaps, streaming, edit queue, undo journal

core

gravity

Field primitives, field compositor, baked field volumes, CPU and GPU samplers

core, world

physics

Fixed-step integrator, voxel-vs-voxel collision, rigid bodies, character controller

world, gravity

particles

GPU particle simulation, voxel-settling, emitters, collision against the brickmap

world, gravity

lighting

Sun cascades, voxel GI probes, emissive injection, atmosphere, exposure

world

render

Vulkan backend, frame graph, ray-marched brickmap pass, post stack

world, lighting, particles

sim

ECS, game systems, scripting (Lua), scene graph of voxel models

world, physics, gravity

tools

In-engine voxel editor, gravity field editor, profiler views, replay viewer

everything

Entity model

Gameplay state lives in a sparse-set ECS. A voxel model (a character, a crate, a door) is an entity with a 
VoxelBody
 component that references a dynamic brickmap: a small, independently addressed voxel volume with its own transform. The static world is itself one very large brickmap owned by 
world
. Static-to-dynamic promotion (a wall section becoming debris) is a copy of a brick range into a new 
VoxelBody
, then a clear of the source.

Threading model

A work-stealing job system with one worker per hardware thread, minus the render-submission thread.

Three pipelined stages per frame: simulate (physics tick, gravity, gameplay), prepare (edit flushing, chunk uploads, culling, light injection) and submit (command buffer recording). Each stage reads the previous frame's output, giving two frames of latency but full parallelism.

All world edits are appended to a per-thread edit queue and applied in one deterministic pass at the start of 
prepare
, ordered by (tick, source id). Nothing mutates voxel memory outside that pass.

GPU work is organised as a frame graph; passes declare the brickmap ranges and buffers they read or write, and barriers are derived automatically.

Data flow per frame

sim
 runs gameplay systems and the physics tick at a fixed 60 Hz; variable render rate interpolates transforms.

Edits from gameplay, destruction and settled particles are merged and applied to CPU brickmaps; dirty bricks are marked.

Dirty bricks are uploaded to the GPU brick pool through a persistent staging ring; the light-injection pass re-lights only dirty regions.

The renderer ray-marches the brickmap, composites particles, applies GI and post.

A background stream job pages chunks in and out based on camera distance and a priority queue of pending edits.

## 3. Voxel world representation

The world is a three-level hierarchy chosen for cheap local edits: chunks for streaming, bricks for GPU residency and ray-marching, and palettes for compression. There is no octree in the hot path; octrees are excellent for static scenes and terrible to mutate a million times per second.

Hierarchy

Level

Size

Role

Storage

World

2 km × 2 km × 512 m

Infinite-ish grid of chunk slots keyed by 
(cx, cy, cz)

Hash map of loaded chunks + disk pages

Chunk

64³ voxels = 4 m cube

Streaming, saving, LOD root, coarse occupancy

512 brick slots, one occupancy bitmask (uint64 × 8)

Brick

8³ voxels = 50 cm cube

GPU residency unit, ray-march leaf, edit granularity

512 palette indices (1, 2, 4 or 8 bits each) + 64-bit occupancy mask

Voxel

6.25 cm

A material id + up to 8 bits of per-voxel state

Index into brick palette

Voxel payload. A voxel resolves to a 16-bit material id and an 8-bit state byte. Material ids index a global material table of up to 65,536 entries holding albedo, roughness, metalness, emissive colour and intensity, density, fracture toughness and a sound/particle class. The state byte carries per-voxel damage, wetness or a colour-variation seed, so a brick wall does not need 10 materials to look varied.

Palettes. Each brick holds a small palette of distinct (material, state) pairs and stores one index per voxel at the smallest bit width that fits (1 bit for a two-material brick, 8 bits for up to 256). An empty brick is not stored at all; a solid single-material brick stores only the one palette entry. Measured on typical outdoor scenes this gives 0.6 to 1.2 bits per voxel against the 3 bytes of the naive layout.

Occupancy masks. Every brick carries a 64-bit mask with one bit per 2×2×2 sub-cell, and every chunk carries one bit per brick. Ray-marching and collision queries test these masks first and skip empty space in one instruction; this is the single most important optimisation in the engine.

GPU brick pool. Resident bricks live in one large device buffer (the brick pool, default 1.5 GB) managed as a slab allocator with four size classes matching the four palette bit widths. A per-chunk indirection table maps brick slot → pool offset, so moving or compacting a brick never touches the chunk data on the CPU. Uploads go through a persistently mapped 64 MB staging ring; a frame may upload up to 16 MB of dirty bricks before the uploader starts deferring low-priority edits.

Streaming. A chunk's full-resolution bricks load within a radius of 200 m of any camera; beyond that only a mip pyramid (one voxel per 2³, 4³, 8³ cells with the majority material) is kept, down to a single colour per chunk at 2 km. Chunks are stored on disk as LZ4-compressed brick runs in 4 MB pages; the save format is the in-memory format, so load is a memcpy plus pointer fix-up. Edits to unloaded chunks are journalled and replayed on load.

Edit model. All mutations are 
EditOp
 records: 
set_sphere
, 
set_box
, 
set_model
, 
clear_region
, 
carve_sdf
 and 
set_voxels(list)
. Ops are applied in one deterministic pass per tick, write to the CPU copy, append to the per-chunk undo journal, and push dirty brick ids to the uploader and the light-injection pass. A sphere carve of radius 2 m (≈ 130,000 voxels, 250 bricks) applies in ~0.4 ms on one core and uploads 60 KB thanks to palette compression.

Dynamic bodies. A 
VoxelBody
 is the same brick layout wrapped in a transform and an AABB, limited to 32³ bricks (16 m) per body. Bodies never merge with the static world while awake; a body that sleeps on the ground for 10 s and has no gameplay owner is welded back into the static brickmap, which keeps the awake body count bounded.

## 4. Rendering

The primary renderer ray-marches the brickmap directly in a compute pass; there is no meshing step. Meshing was rejected because at 6.25 cm voxels a destructible scene produces hundreds of millions of faces and every edit forces a remesh. Ray-marching makes an edit cost exactly the upload of the bricks it touched.

Primary visibility pass

A coarse pre-pass marches one ray per 8×8 pixel tile against chunk occupancy only, producing a conservative depth bound per tile and a list of chunks each tile touches.

The full-resolution pass marches one ray per pixel through the hierarchy: chunk mask → brick mask → 2×2×2 sub-cell mask → voxel. A 3-level DDA with 64-bit mask skipping averages 18 to 30 steps per ray in dense scenes, 6 to 10 outdoors.

Each ray writes a G-buffer: depth, material id, state byte, face normal (6 possibilities, 3 bits) and a 16-bit brick id for reprojection.

Dynamic bodies are rendered in the same pass: a per-frame BVH over body AABBs is built on the GPU, and a ray that enters a body AABB is transformed into body space and marched through the body's own bricks. Up to 4 overlapping bodies per ray are handled before falling back to depth-sorted splatting.

Why not an SVO? A sparse voxel octree compresses better and traverses faster for static content, but a single voxel edit rebalances the tree. The brickmap's flat tables keep edits O(1) and let the GPU and CPU share the exact same layout. Compression is recovered by palettes (Section 3).

Surface shading. Shading runs as a deferred full-screen compute pass over the G-buffer. Per-pixel material parameters come from the material table; the state byte modulates albedo variation, damage darkening and wetness. Normals are refined beyond the 6 face directions by a 3×3×3 occupancy kernel that bevels edges and softens internal corners, so tiny voxels do not read as a staircase at a distance.

Level of detail. Beyond 200 m the renderer marches the chunk mip pyramid instead of full bricks. The transition is dithered over 20 m so there is no pop. Because the mip stores a majority material per cell, far terrain keeps its colour and silhouette at about 1/64 of the memory. Characters smaller than 2 pixels switch to a splat.

Temporal reuse. Every pixel stores the brick id and voxel coordinate it hit last frame. If the brick is unchanged (a per-brick dirty epoch is checked) and reprojection lands within half a voxel, the march starts at that voxel instead of the camera; this cuts average steps by roughly 40 % in slow camera motion. Ray-marched depth is exact, so TAA and upscaling (FSR / DLSS inputs) are standard.

Transparency and water. Glass, ice and voxel-water materials are marched in a second pass that accumulates up to 4 layers per pixel (depth-peeled inside the DDA). Refraction uses the G-buffer depth of the opaque hit behind it.

Vulkan specifics. Bindless descriptor arrays for the brick pool, material table and GI probe atlas; timeline semaphores between the simulate, prepare and submit stages; 
VK_KHR_ray_query
 is optional and used only for shadow and GI rays against dynamic bodies when a hardware BVH is available, with a software fallback.

Frame budget at 1440p / 60 fps (16.6 ms)

Pass

Budget

Edit upload + light injection

1.0 ms

Coarse pre-pass + primary ray-march

4.4 ms

Sun shadow cascades (4 × 2048²)

1.5 ms

GI probe update + apply

2.0 ms

Deferred shading

1.5 ms

Particles (sim + composite)

1.5 ms

Transparency incl. liquid surfaces, volumetrics, post, UI

2.0 ms

Reserve

0.4 ms

Foliage (sim + splat)

0.8 ms

Liquid solver (active bricks)

1.5 ms

## 5. Destruction & manipulation

Destruction is three steps that can each be budgeted separately: carve (remove voxels), detach (find what is no longer supported) and debris (turn detached pieces into bodies or particles). The split keeps worst-case cost bounded even when a player levels a building.

Carve. Any 
EditOp
 can carve: explosions use 
carve_sdf
 with a noisy sphere so blast holes are not perfect balls, tools use 
set_sphere
 with a material filter (a pickaxe carves stone but not steel), and projectiles carve a capsule along their path. Material toughness in the material table scales the effective radius, so a grenade takes a 2 m bite from brick and a 0.4 m scratch from reinforced concrete.

Detach (connectivity). After carving, the engine must find voxel islands that no longer connect to an anchor (bedrock, or a brick flagged 
structural_anchor
 by the level designer). A full flood fill over a 4 m chunk is 262,144 cells, too slow per edit, so connectivity is cached at brick level:

Each brick keeps a 6-bit face connectivity summary: does solid material touch each face.

A chunk keeps a union-find over its 512 bricks, rebuilt only for bricks touched by the edit (typically 10 to 300).

Islands that are fully inside one chunk are resolved immediately. Islands that cross chunk boundaries are queued to a background job that resolves them within 3 ticks; until then they stay static, which the player never notices at 50 ms.

Islands larger than 32³ bricks are never detached as one piece; they are fractured first.

Fracture. A detached island larger than ~2,000 voxels is split by a cheap Voronoi over 4 to 12 seed points biased toward the carve centre, with the split planes jittered by brick-local noise so pieces look broken rather than sliced. Each piece becomes a 
VoxelBody
. Pieces smaller than 64 voxels become voxel particles instead (Section 8), which is where most of the visual richness comes from.

Debris budget. A global budget caps 2,000 awake bodies and 100,000 spawned debris particles per second. When exceeded, the smallest pieces are converted to particles and the smallest particles are dropped, oldest first. The player sees a dense cloud either way; the physics cost stays flat.

Manipulation (building and welding). The inverse operations use the same ops: 
set_model
 stamps a voxel model into the world or a body, 
weld
 merges two bodies that touch for one tick while a weld tool is active, and 
carve_sdf
 with a negative sign fills instead of cutting. Because bodies and world share one brick layout, a player can pick up a wall chunk, carry it under a different gravity field, and bolt it to a ceiling; it becomes static again by welding and is then lit, collided and rendered as world.

Persistence. Every applied 
EditOp
 is appended to a per-chunk journal with its tick. Saves write the current bricks plus the journal tail since the last full write; loads replay journal entries that arrived for chunks while they were unloaded. The journal also powers undo in the editor and replay in the debugger. Journals are compacted when they exceed the size of the chunk they describe.

Determinism rules. Fracture seeds derive from (tick, chunk id, edit id); flood fills iterate bricks in a fixed Morton order; no floating-point values enter the connectivity or fracture paths. Two machines applying the same edit stream produce identical worlds.

## 6. Gravity fields

Gravity is a function 
g(p) → (direction, strength, up)
 evaluated per body, per particle and per character, composed from a small set of analytic field primitives placed by the level designer. The performance design rests on one idea: the composition is baked into a coarse 3D texture wherever fields overlap, and evaluated analytically wherever a single field dominates, so the common case costs one texture fetch or one dot product.

Field primitives

Primitive

Behaviour

Typical use

Uniform

Constant direction and strength

Normal ground, flipped rooms, sideways corridors

Point

Toward a centre; strength constant or 1/r² inside a radius

Small planets, asteroids

Line

Toward the nearest point on a segment or capsule axis

Cylindrical planets, tube corridors

Plane

Toward a plane, from either side (two-sided option)

Flat planetoids walkable on both faces

Torus

Toward the ring's circle

Ring worlds, donut planets

Spline

Toward or along a Catmull-Rom spline

Twisting paths, launch tubes, roller-coaster gravity

Box

Toward the nearest face of a rounded box

Cube planets with soft edges

Surface

Toward the nearest world voxel surface, from a distance field

Walk on any destructible shape

Null

Zero gravity

Space sections

Each primitive has a transform, a priority, a falloff shell (inner radius full strength, outer radius zero) and a blend mode (
replace
, 
add
, 
max
).

Composition. Fields are stored in a bounding-volume list sorted by priority. For a point p, all fields whose outer shell contains p are gathered; the highest-priority 
replace
 field wins, lower fields of equal priority are blended by their falloff weights, and 
add
 fields are summed afterwards. Blending direction vectors through the falloff shells is what makes a Galaxy-style jump from one planetoid to another feel smooth rather than snapping at a boundary.

The 
Surface
 field and destructible planets. This is the primitive that lets gravity follow destruction. Each chunk maintains a coarse signed distance field at 1 cell per brick (50 cm), updated incrementally from the brick occupancy masks when bricks change; the gradient of that field is the gravity direction. Carve a tunnel into a planetoid and gravity inside the tunnel points toward the tunnel walls, exactly as the player expects. A smoothing radius (default 4 m) stops single-voxel bumps from flipping the up vector.

Baked field volume. Where two or more fields overlap, or where a 
Surface
 field is active, the compositor bakes the result into a 3D texture of 1 m cells (RGBA16F: direction × strength in xyz, blend confidence in w) covering the loaded region. Baking is incremental: only cells inside changed shells or near changed bricks are recomputed, on the GPU, at about 2 million cells per millisecond. Everywhere else the volume stores a sentinel that means evaluate analytically with field N.

Samplers

GPU sampler: one trilinear fetch from the baked volume; on a sentinel, one analytic evaluation of the named field. Used by particles, debris and the renderer (for gravity-aligned effects such as falling dust). Cost is ~10 ns per sample; 10 M samples per frame fit in 1 ms.

CPU sampler: the same algorithm in SIMD over batches of 8 bodies; sleeping bodies sample once when woken. Characters sample once per tick plus a second predictive sample at their position next tick to anticipate field transitions.

Gravity shenanigans this enables

Walking around a 6 m planetoid, jumping to its moon, and landing head-down on the moon's far side (two 
Point
 fields with overlapping shells).

A corridor whose floor becomes the wall over 10 m (
Spline
 field with rotating up vector).

A room where the player flips gravity with a switch (
Uniform
 field with runtime re-targeting; bodies and debris all react on the next tick).

Launching through a tube that curves (
Spline
 with along-axis mode; strength acts as thrust).

Blowing a crater in a planet and watching rubble roll into it (
Surface
 field re-baked around the carve within 2 ticks).

Local gravity wells from gameplay items (
Point
 fields with 
add
 blend, pulling debris and particles into a vortex).

Character up-vector handling. The character controller keeps a smoothed up that slerps toward the sampled gravity at 720°/s when grounded and 180°/s when airborne, so transitions feel intentional rather than twitchy. Camera up follows the smoothed up with an additional 0.3 s lag. Designers can pin the camera up to a field's own up (for tubes and corridors) via a per-field flag.

Interaction with the physics solver. Gravity enters the integrator as a per-body acceleration; nothing in the contact solver assumes a global down. Rest detection uses velocity relative to the local gravity direction, and the sleep threshold is scaled by local strength so bodies in weak fields still sleep.

Determinism. Analytic fields use fixed-point math for the CPU sampler; the baked volume is sampled on the CPU only for debris that has already been promoted to particles, which are not part of the deterministic state.

## 7. Physics & characters

The physics module is a custom fixed-step (60 Hz) rigid-body solver whose only collision shape is a brickmap. There are no convex hulls, capsules or meshes to keep in sync with the voxels; a body collides as exactly the voxels it is made of, which is what makes destructible objects feel solid.

Broad phase. Dynamic bodies are inserted into a uniform grid of 16 m cells (matching the maximum body size); body-vs-world pairs are found by testing the body AABB against chunk occupancy masks. Sleeping bodies live in a separate list and are only tested when a chunk they overlap is edited.

Narrow phase (voxel vs voxel). For a body-vs-world pair, the body's occupied surface voxels (precomputed: voxels with at least one empty neighbour, typically 20 % of the volume) are transformed into world space and tested against the world's 2×2×2 sub-cell masks. Each hit produces a contact at the voxel centre with the world face normal; contacts are clustered per brick to keep the count below 64 per body. Body-vs-body uses the same test with the smaller body's surface voxels against the larger body's masks. All of this is SIMD over 8 voxels and runs on the job system; 2,000 awake bodies with ~150 surface tests each cost about 2 ms across 8 cores.

Solver. Sequential impulses with 8 velocity iterations and 2 position iterations, warm-started from the previous tick. Friction and restitution come from the material table of the voxels in contact (the pair's values are combined by geometric mean). Gravity enters as a per-body acceleration from the gravity sampler, so nothing in the solver has a global down. Bodies sleep after 1 s below the local velocity threshold, scaled by local gravity strength.

Mass and inertia. Computed from the voxel volume using per-material density. For a 
VoxelBody
 under 4³ bricks this is recomputed on every edit; larger bodies update incrementally by subtracting the removed voxels' contribution, which keeps carving a chunk out of a floating ship cheap.

Character controller. Characters are voxel models (a 1/32 m sub-grid, typically 16 × 48 × 16 voxels for a 1.5 m humanoid) rigged as a small hierarchy of parts: pelvis, torso, head, two arms, two legs. Animation rotates parts about voxel-grid pivots, with each part re-rasterised into the character's brickmap only on frames where its rotation crosses a 15° boundary, so a walk cycle costs a handful of brick uploads per second.

Movement model: a kinematic capsule-like probe built from the character's own voxels tests the ground along the local gravity direction with a 1-voxel step tolerance for stairs and a 20-voxel (0.6 m) step-up for ledges when sprinting.

Up vector: the smoothed up from Section 6; movement input is projected onto the plane perpendicular to it, so "forward" is always along the surface the player is standing on.

Walking on bodies: standing on a moving 
VoxelBody
 inherits its velocity; standing on a rotating one inherits angular velocity about the contact point, so riding a tumbling asteroid or a rolling log works without special code.

Damage: characters are destructible like everything else. A carve that removes limb voxels disables that limb's input; losing the pelvis part kills the character and its remaining voxels become debris.

Ragdoll. On death, the part hierarchy becomes a chain of small 
VoxelBody
 instances joined by ball joints. Joints are solved in the same sequential-impulse loop as contacts.

Vehicles and machines. Hinges, sliders and motors are joints between 
VoxelBody
 instances, exposed to Lua. A door is a wall slab plus a hinge; a vehicle is a chassis body, four wheel bodies and four motorised hinges. Destroying the hinge voxels destroys the joint.

Continuous collision. Bodies faster than one brick (0.5 m) per tick are substepped up to 4×; projectiles faster than that are raycast against the brickmap instead of simulated as bodies.

## 8. Voxel particle system

Particles are the engine's main source of visual richness and they are voxels too: every particle is a single cube of one material, lit and shadowed like the world, and able to settle back into the world as a real voxel. The system runs entirely on the GPU and samples the same gravity volume as everything else, so an explosion under a planetoid throws dust up toward the sky and it falls back down around the curve.

Particle classes

Class

Size

Collides with world

Can settle

Typical count

Use

Debris

1 voxel, material of origin

Yes, bounces with material restitution

Yes

100,000

Rubble, splinters, shards

Grain

1 voxel, flows

Yes, slides on slopes, piles up

Yes

500,000

Sand, gravel, snow, ash

Spark

1/4 voxel, emissive

Yes, short life

No

200,000

Sparks, embers, magic

Puff

1 to 4 voxels, soft

No, drifts with wind

No

1,000,000

Smoke, dust clouds, steam

Drop

1 voxel, liquid material

Yes, splashes

Becomes wetness state byte

200,000

Rain, blood, paint

Simulation. One SoA buffer per class (position as int32 voxel coord + uint8 sub-voxel fraction, velocity as fp16, life, material, seed). A compute dispatch per class per frame does: gravity sample → integrate → collide against brick occupancy masks (the same 3-level mask test the renderer uses, so a particle never tunnels through a 1-voxel wall) → write back. Dead particles are compacted with a prefix sum every 4 frames. Emission is through a GPU append buffer fed by CPU emitter commands, so spawning 50,000 particles is one small upload.

Settling. When a 
Debris
 or 
Grain
 particle rests for 30 frames, the particle compute shader appends a 
set_voxel
 request to a GPU edit buffer. The CPU reads this buffer back one frame later and applies the requests through the normal edit queue, so settled particles enter the undo journal and the deterministic world state like any edit. Grains settle with an angle-of-repose rule (a grain will not settle on a cell whose lower neighbour is empty), which makes sand pour into convincing piles and snow drift against walls. The settle rate is capped at 20,000 voxels per frame; excess particles simply keep resting until there is budget.

Collision with bodies. Particles collide with dynamic bodies through the same body BVH the renderer uses; a particle inside a body AABB is transformed into body space and tested against that body's masks. Particles that hit a body apply a summed impulse to it once per frame, so a sand avalanche can push a crate.

Rendering. Particles are splatted as cubes in a dedicated pass after the opaque ray-march: each particle writes depth-tested into the G-buffer with its material and a 6-face normal, so it receives the same deferred shading, GI and shadows as the world. 
Puff
 particles instead accumulate into a low-resolution froxel volume (160 × 90 × 64) that is ray-marched for soft, lit smoke; this keeps a million puffs at a fixed cost. 
Spark
 particles inject emissive energy into the GI probes near them, which is how a spray of sparks lights a dark room.

Effect authoring. An effect is a small graph of emitters, each with a class, a shape (point, sphere, voxel-surface, body-surface), a rate or burst, and curves for velocity, life and colour over life. Material-driven effects are automatic: carving a material emits 
Debris
 of that material at a rate from the material table, so stone chips, wood splinters and glass shatters without per-object setup. The editor previews effects in-world with the real gravity field.

Signature effects the system should ship with

Explosion: shockwave 
Puff
 ring, 
Debris
 burst of the carved materials, 
Spark
 cloud with GI injection, lingering 
Puff
 smoke pulled by local wind.

Collapse: 
Grain
 dust pouring from fracture planes as a building separates, settling as a dust layer on the rubble below.

Gravity flip: every unsettled particle reverses within one frame; 
Grain
 piles on the old floor slide off and re-pile on the new one.

Planetoid landing: a ring of 
Grain
 thrown outward along the local surface, falling back on the curve.

## 9. Lighting engine

Lighting is fully dynamic with no baking, because a world that can change anywhere cannot have precomputed light. The design leans on the fact that the world is already a voxel grid: the brickmap is the acceleration structure for shadow rays and GI, so there is no second scene representation to keep in sync with destruction.

Light sources

Sun / moon: one directional light with a time-of-day curve and a physically based sky.

Emissive voxels: any material can emit; a lava floor, a neon sign or a torch is just voxels. There are no point-light objects in v1, which removes a whole class of light-leak and budget problems. Designers who want a lamp place an emissive voxel.

Particles: 
Spark
 and emissive 
Debris
 inject into the GI probes (Section 8).

Direct sun light. Four cascaded shadow maps (2048², covering 8, 32, 128 and 512 m) rendered by ray-marching the brickmap from the light's view in a compute pass, exactly like the primary pass. Because the depth is exact, contact hardening comes free from a 3×3 PCF with a kernel scaled by receiver-occluder distance. Dynamic bodies are included in the same march.

Global illumination: voxel probe grid. Indirect light is stored in a grid of probes at 1 m spacing covering the 200 m detail radius (about 8 million probes), each holding irradiance as 9 spherical-harmonic coefficients in RGB (fp16, 54 bytes) plus a mean-distance pair for visibility weighting, in the style of DDGI. Probes live inside the brick pool's indirection, so they stream with chunks and are dropped where there is solid rock.

Update: each frame a budget of 64,000 probes is updated (full grid every ~2 s; probes near edits, the camera and moving emissive sources are prioritised). Each probe traces 48 rays through the brickmap with the mask-skipping DDA; hits read the material's albedo and emissive and the previous frame's probe irradiance at the hit point, which gives multi-bounce light for free over a few frames.

Apply: the deferred shading pass samples the 8 surrounding probes with visibility weighting from the stored mean distances, which stops light leaking through 1-voxel walls, a problem naive voxel cone tracing has.

Edits: a carved brick invalidates the probes within 2 m, which are re-traced the same frame in the light-injection pass, so a new window lets light in on the next frame.

Emissive injection. Emissive voxels are found by a per-brick flag set at edit time; the GI probe rays simply read their radiance on hit. For small, bright emitters (a torch of 8 voxels) the 48-ray probe trace would flicker, so bricks with emissive voxels additionally splat their total emission into the nearest 27 probes directly each frame. Particles do the same from the particle buffer.

Ambient occlusion. A 3×3×3 occupancy kernel at the shading point gives a cheap, sharp AO that reads well on tiny voxels; a 16-sample screen-space pass adds medium-range occlusion. Both are modulated by the probe visibility so they do not double-darken.

Atmosphere and volumetrics. A Hillaire-style sky LUT drives sun colour and ambient. A froxel volume (the same 160 × 90 × 64 grid as 
Puff
 particles) accumulates fog density from the level, smoke from particles and emissive scattering, then is ray-marched with the shadow cascades for god rays through broken roofs.

Exposure and colour. Histogram-based auto exposure with designer-set bounds per gravity field (so the inside of a dark planetoid does not pin the exposure for the sunlit outside), ACES tone mapping, and a bloom that responds to emissive voxels so sparks and lava glow.

The look. The combination the engine is tuned for: tiny cubes with bevelled normals, hard sun shadows with soft contact, warm bounce from emissive materials, dust catching light shafts after a collapse. Every element above is chosen so that destruction and gravity changes never produce a lighting artefact: there is nothing precomputed to invalidate.

## 10. Foliage system

Foliage is voxels like everything else, but it is stored as instances of small voxel models rather than as world voxels, because a forest of 500,000 plants would otherwise cost more brick uploads per gust of wind than a building collapse. An instance is cheap to sway, cut, burn and regrow; it only becomes world voxels (a fallen trunk, a stump) when it stops being a plant.

Two tiers

Tier

What

Storage

Count target

Ground cover

Grass tufts, flowers, ferns, mushrooms, reeds: 1 to 8 voxels, 1/32 m grid

GPU instance buffer: int16 position, uint8 type, phase, health, flags (14 B packed, 96 B with transforms and history)

500,000 visible

Trees and shrubs

Trunk, branches and canopy as a 
.vxm
 with a part hierarchy; 20 to 400 bricks

Trunk and large branches are world voxels (destructible, collidable); canopy leaf clusters are instances attached to branch parts

4,000 trees in the detail radius

Placement. Ground cover is scattered procedurally per brick from a density map painted in the editor plus material rules (grass on soil, moss on north-facing stone, reeds within 1 m of water). Scatter is deterministic from (brick id, rule id, seed), so it is never saved; only designer overrides and runtime damage are stored, as a per-brick 64-bit kill mask. When a brick is edited, its cover is re-scattered on the surviving surface voxels, which is why digging a trench removes the grass with it.

Wind. A global wind field (direction, gust noise, local turbulence from explosions and moving bodies) is baked into the same 1 m volume as gravity, in a second RGBA16F texture. Instances bend as a rotation about their root driven by wind, local gravity (grass on a planetoid hangs outward from the surface) and a per-instance phase, evaluated in the splat shader. Nothing about wind touches voxel memory.

Rendering. Ground cover is splatted as cubes in the particle pass (Section 8), so it receives the same shading, GI and shadows; a 2-level LOD drops to a single cube at 40 m and to a ground-tint contribution at 100 m. Canopy clusters are rendered as instanced dynamic bricks through the body BVH, which gives real occlusion and lets light shafts pass through gaps in leaves. Trunks are world voxels and need nothing special.

Interaction

Cutting: any carve or body contact that intersects an instance sets its health; at zero it spawns 1 to 8 
Debris
 particles of its material and sets its kill bit. A scythe sweep through 2,000 tufts is one GPU dispatch and one 8 KB mask upload.

Trampling: characters and bodies flatten instances they stand on (a bend override that decays over 20 s), so paths through tall grass appear and fade.

Trees: carving a trunk uses the normal detach logic from Section 5; the canopy instances attached to a detached part ride along as a 
VoxelBody
 child and shed leaves (
Grain
 particles) on impact. Gravity applies to the fallen tree like any body, so a tree felled on a small planetoid topples around the curve.

Burning: a material flag 
flammable
 plus a per-brick fire state byte drives a cellular fire spread over instances and flammable world voxels, consuming them into ash 
Grain
 and emitting 
Spark
 and 
Puff
 particles and emissive heat into the GI probes. Fire spreads along the local up so it climbs a tree correctly on any planetoid.

Regrowth: killed cover regrows after a designer-set time (default 10 minutes of play) by clearing kill bits with a noise pattern, so forests heal between visits but a clear-cut field stays bare long enough to matter.

Authoring. Foliage types are 
.vxm
 models with a 
foliage
 part tag, a root pivot, a bend stiffness and a seasonal palette; density maps and rules are painted in the world editor and preview live. Trees are placed by hand or by a scatter rule with minimum spacing.

Budget. 0.8 ms GPU for sim and splat at 500,000 instances; 48 MB of instance buffers; ground-cover state is 8 bytes per brick in the chunk save.

## 11. Liquids

Liquids are a cellular-automaton volume solver that lives inside the brickmap: a liquid cell is a world voxel whose material is a liquid type and whose state byte is its fill level (0 to 255). There are no particle fluids for bulk water and no separate fluid grid; the same occupancy masks, edits, journal and renderer carry water, lava, oil and acid. The solver is a compute pass over active bricks only, and it flows along the local gravity direction, so a tank of water on a planetoid wraps around it and a gravity flip pours the lake onto the ceiling.

Liquid types

Type

Viscosity

Interactions

Water

Low

Extinguishes fire, wets voxels (state byte), floats low-density bodies, grows reeds nearby

Lava

High

Ignites flammables, melts ice into water, cools to stone where it touches water or after 60 s exposed

Oil

Medium

Floats on water, burns as a surface fire that spreads along the liquid

Acid

Low

Carves low-toughness materials at 1 voxel per second of contact

Mud / slime (custom)

Designer-set

Data-driven from the material table

Solver. Each tick, for every active brick, the solver runs a falling-sand style rule set on its 512 cells in 8 sub-steps: a cell first moves fill into the cell below along local gravity (quantised to the dominant axis per brick, with the two minor axes used for diagonal spreading), then equalises with its four side neighbours, then applies a small upward pressure transfer when fill exceeds 255 so sealed containers fill and lifted water finds its level. Flow rate is scaled by viscosity and by local gravity strength. Because every brick knows its gravity axis from the baked volume, a river on a cylindrical world simply runs along the cylinder. Bricks whose cells did not change for 8 ticks go inactive; an edit, a body or a particle touching them reactivates them and their neighbours.

Active set. The target is 4,000,000 active cells (≈ 8,000 bricks) per tick in 1.5 ms. A large lake at rest costs nothing; only its shoreline, inflows and whatever the player disturbs is active. Edits that open a path for liquid are the same 
EditOp
 records as everything else, so a dam breach is carving the dam, and the water does the rest.

Interaction with the rest of the engine

Bodies: buoyancy is computed per submerged voxel from the body's material density against the liquid's, with drag along the local gravity axis; a wooden crate floats, a stone one sinks, a hollow metal hull floats until it is holed. Moving bodies displace liquid by pushing fill into neighbours.

Characters: swimming is a controller mode entered when the pelvis is submerged; lava and acid deal damage per submerged voxel.

Particles: 
Drop
 particles that land on liquid add fill; 
Grain
 sinks through water at a viscosity-scaled rate and settles below it (sand poured into a pool forms an underwater pile); splashes spawn 
Drop
 and 
Puff
 from cells whose fill changed by more than 128 in one tick.

Fire and foliage: water cells adjacent to burning voxels extinguish them; lava ignites them; reeds and moss scatter near water through the foliage rules.

Gravity: no special code. Liquids read the baked gravity volume and the per-brick dominant axis; a gravity flip reactivates every liquid brick and the lake falls.

Destruction: a liquid cell has no toughness; carving removes it like any voxel, and the solver backfills from neighbours.

Rendering. Liquid surfaces are extracted in the transparency pass (Section 4) as the top liquid cell per column along the local gravity axis, with the fill level used as a sub-voxel height, so a half-full cell draws a half-height block and a settled surface is flat rather than stepped. The surface shader does screen-space reflection with a fallback to the sky LUT, refraction from the opaque G-buffer, depth-based absorption colour and a small normal ripple driven by neighbouring fill deltas. Lava is opaque and emissive, so it goes through the normal deferred path and lights its surroundings through the GI probes. Underwater, the froxel volume adds scattering and the sun cascades add caustic-like light shafts.

Persistence and determinism. Liquid is world voxels, so saves, journals, undo and replay already cover it. The solver runs on the GPU for speed but is written to be bit-exact against a CPU reference (integer fill, fixed sub-step order, Morton brick order); the nightly determinism test runs both and diffs them.

Authoring. Designers paint liquid volumes with the normal brush tools using a liquid material, place inflow and drain emitters (which add or remove fill at a rate), and tune viscosity, colour, absorption and reactions in the material table. The debug overlay shows active bricks and per-brick gravity axes.

Budget. 1.5 ms GPU per tick at 4 M active cells, 192 MB for sparse liquid tiles and active-set tables, plus the surface pass inside the transparency budget. Still open: whether v1 needs a true pressure solve for sealed containers (the current rule is an approximation that leaks slowly).

## 12. Content pipeline & tooling

All tools run inside the engine on the live world, because the editing operations are the same 
EditOp
 records the game uses. There is no separate editor build and no bake step; a designer carves a planetoid, sets its gravity and plays it in the same session.

Voxel models. Characters and props are authored in MagicaVoxel (
.vox
) or in the in-engine model editor and imported into the engine's 
.vxm
 format: palette-compressed bricks, a part hierarchy with pivots, per-part material overrides and optional emissive animation tracks. Import is lossless and takes milliseconds; a 16 × 48 × 16 character is about 6 KB. Materials are matched by palette colour against the material table with a manual override map per model.

Character rigging. The model editor lets an artist tag voxel regions as parts and place pivots on the voxel grid. Animation clips are keyframed part rotations and offsets, authored in-engine or imported from a simple JSON format; there is no skeletal weighting, which keeps the voxel look crisp.

World editor. Brush tools (sphere, box, SDF stamp, model stamp), material painting, terrain sculpting with noise layers, and a prefab system where a prefab is a 
.vxm
 placed into the world and tracked so it can be re-stamped after edits to the source. Undo uses the edit journal.

Gravity editor. Field primitives are placed as gizmos with their shells shown as translucent surfaces; the baked volume can be visualised as a streamline field or as arrows sampled on a grid. A "drop test" spawns 1,000 
Debris
 particles at the cursor and shows their paths for 5 s, which is the fastest way to tune a transition between two planetoids.

Effect editor. Live graph editing of emitters with the particle system running under the real gravity field; a scrub bar replays a burst.

Materials. The material table is a CSV in the project with hot reload: id, name, albedo, roughness, metalness, emissive colour and intensity, density, toughness, restitution, friction, particle class and sound class.

Scripting. Lua 5.4 through sol2 for gameplay, with a hot-reloading script per entity archetype. The API exposes entities, 
EditOp
 submission, gravity field creation and retargeting, effect spawning and joint creation. Heavy per-voxel logic is never exposed to scripts; scripts submit ops and the engine executes them.

Debug and profiling tools

Frame-graph viewer with per-pass GPU timings and the brick upload bandwidth of the frame.

Brick heat map: colours bricks by edit frequency, palette bit width or GI probe update age.

Physics overlay: contact points, sleep state, per-body gravity vector.

Replay: because the simulation is deterministic, a recorded input and edit stream replays a session bit-for-bit; the replay viewer scrubs the journal and shows the world at any tick.

Crash capture writes the last 600 ticks of the edit stream so a bug report reproduces itself.

Build and test. CMake, Clang on both platforms, vcpkg for dependencies (Vulkan-Hpp, VMA, glslang, LZ4, sol2, Dear ImGui for tool UI, Tracy for profiling). Unit tests for palettes, masks, connectivity and the gravity compositor; golden-image rendering tests on a fixed scene; a nightly determinism test that replays 10 minutes of recorded play on two machines and diffs the worlds.

## 13. Performance budgets & memory plan

The engine targets an 8 GB GPU and 16 GB of system RAM. The brick pool is the dominant cost; everything else is sized to leave it room.

GPU memory (8 GB card, 1440p)

Resource

Size

Notes

Brick pool (world + bodies)

1,536 MB

~200 m detail radius at 0.6 to 1.2 bits/voxel plus masks and indirection

Chunk mip pyramid (far world)

128 MB

2 km × 2 km × 512 m at 4 levels

GI probe grid

448 MB

8 M probes × 54 B irradiance + 2 B visibility

Gravity volume

24 MB

400 × 400 × 150 cells of RGBA16F over the detail region

Shadow cascades

64 MB

4 × 2048² depth + ESM copy

Particle buffers

96 MB

2 M particles × ~40 B, double-buffered

Froxel volume

36 MB

160 × 90 × 64 × 2 volumes RGBA16F

G-buffer, history, post

160 MB

1440p × 8 targets plus TAA history

Staging ring

64 MB

Persistently mapped

Total

~2.9 GB

Leaves headroom for 4 K and for a larger brick pool on 12 GB+ cards

Foliage instance buffers

48 MB

500 k instances × ~96 B with transforms and bend history, double-buffered

Liquid tiles + active set

192 MB

Sparse 8³ tiles over the detail radius, ~4 M active cells plus tile and gravity-axis tables

System memory

Resource

Size

CPU brick mirror of loaded chunks

1,536 MB (same layout as the GPU pool)

Edit journals (in-memory tails)

128 MB cap, compacted on overflow

Physics state, ECS, scripts

256 MB

Streaming cache (compressed pages)

512 MB

Audio, UI, tools

256 MB

CPU time per 60 Hz tick (8 cores)

Stage

Budget

Edit application + connectivity

2.0 ms

Physics broad + narrow phase

2.0 ms

Solver + character controllers

1.5 ms

Gravity CPU sampling + bake scheduling

0.5 ms

Gameplay systems + Lua

2.0 ms

Streaming + decompression (background)

1 core, continuous

Culling, upload packing, command recording

2.0 ms on the submit thread

Scaling rules

Settings scale the detail radius (100 / 200 / 300 m), probe spacing (2 / 1 / 0.5 m), particle cap and shadow resolution; the voxel size never changes, so gameplay is identical on every setting.

Every budget above is a hard cap enforced by its system (edits deferred, particles dropped, probes updated more slowly) so an exceptional event degrades quality rather than frame time.

The profiler asserts in debug builds when any stage exceeds 150 % of its budget for 10 consecutive frames.

## 14. Implementation roadmap

Five phases over about 19 months, each ending in a playable demo that gates the next. Order follows risk: the brickmap and ray-marcher are proven first, since every other system depends on their layout; gravity comes before beauty because it shapes the physics and camera code; tools come last so they wrap stable systems. A team of 6 to 8 (2 rendering, 2 simulation, 1 tools, 1 technical artist, 1 to 2 generalists) is assumed.

Gravity (accented) sits in the middle on purpose: it must be proven before the lighting and particle work is tuned around it, and it cannot start before the brick layout and physics it samples exist.

Phase deliverables

Foundation (Nov 2026 to Jan 2027): 
core
 job system and arenas, Vulkan frame graph, brick pool with palettes and masks, chunk loader, primary ray-march with the G-buffer and flat shading, 
.vox
 import. Gate: a static 1 km² scene at 60 fps / 1440p and a 1 M edits/s micro-benchmark on the CPU brick layout.

Living world (Feb to Apr 2027): edit queue and journal, streaming with mips, carve / detach / fracture, 
VoxelBody
, broad and narrow phase, sequential-impulse solver, welding and sleeping, first-person debug controller. Gate: level a 20-storey building with explosives at 60 fps with 2,000 awake bodies.

Gravity (May to Jul 2027): all nine field primitives, compositor, incremental baked volume, GPU and CPU samplers, 
Surface
 field with the brick-level SDF, character controller with smoothed up, camera, ragdoll, joints. Gate: a planetoid demo with a jump to a second planet, a gravity-flip room and a crater that rubble rolls into.

Beauty and nature (Aug 2027 to Jan 2028): particle classes and settling, sun cascades, GI probe grid with emissive injection, AO, atmosphere and froxels, exposure, bloom, TAA and upscaler inputs, transparency, then the foliage system (Section 10) and the liquid solver (Section 11). Gate: the four signature effects from Section 8 inside the frame budget on the target GPU, plus a flooded, burning forest valley on a planetoid.

Tools and ship (Feb to May 2028): world, gravity, model and effect editors, Lua API, replay and crash capture, golden-image and determinism tests, settings scaling, documentation. Gate: an external team builds a 10-minute level without engineering help; v1.0.

Parallel tracks. Materials and the look are iterated by the technical artist from Phase 1 onward on whatever renders; the determinism test runs nightly from Phase 2 so non-determinism is caught when it is introduced, not at the end.

## 15. Risks, open questions & references

Risks

Risk

Impact

Mitigation

Ray-march cost in dense interiors exceeds 4.4 ms at 1440p

Frame budget blown in the most common gameplay space

Temporal start-point reuse, 8×8 tile pre-pass, dynamic resolution on the primary pass only; fall back to half-rate secondary rays before touching voxel size

Brick pool fragmentation after hours of edits

Stalls on allocation, wasted VRAM

Slab allocator with four size classes, background compaction of 64 bricks per frame, indirection table so moves are invisible

Connectivity resolution across chunks lags visibly during huge collapses

Floating rubble for several ticks

3-tick cap on background resolution; islands still unresolved are fractured at chunk borders and treated as separate pieces

Gravity transitions feel bad even when the math is right

The core fantasy fails

Phase 2 gate is a feel test, not a benchmark; a tuning pass on falloff curves, up-vector slerp rates and camera lag is scheduled with the designer, not after

GI probe grid at 1 m is too coarse for 6.25 cm detail (light leaks through thin walls)

Visible artefacts in interiors

Visibility-weighted sampling, 3×3×3 occupancy AO at the shading point, optional 0.5 m probe spacing on high settings

Determinism broken by a GPU-side system

Replays and future netcode unusable

Only CPU-side state is authoritative; particles and GI are explicitly non-deterministic and never feed back into world state except through the settle queue, which is applied on the CPU in a fixed order

Characters at 1/32 m look blurry at a distance or jitter when rotated

Visual quality of the main actor

15° re-rasterisation threshold, bevelled normals, splat below 2 pixels; evaluate a per-part transform in the ray-marcher (no re-rasterisation) as a Phase 3 experiment

Open questions

Voxel size: 6.25 cm world grid is chosen for power-of-two math; should hero props and characters use 1/32 m everywhere, or only for characters?

Should Lua be replaced by a native C++ hot-reload module system for gameplay-heavy teams?

Do we support an SDF-defined 
Surface
 gravity field at full 6.25 cm resolution for small objects (a walkable asteroid the size of a car), or is 50 cm enough?

Is hardware ray tracing (
VK_KHR_ray_query
) worth maintaining as a second path for body shadows, or is the software march fast enough on the target GPU?

Water: v1 ships voxel 
Drop
 particles plus the cellular-automaton liquid solver (Section 11); still open is whether sealed containers need a true pressure solve in v1.

Networking: determinism is preserved, but should the edit journal be designed now as the replication stream (lockstep) to avoid a v2 rewrite?

References and prior art (techniques, not sources looked up for this document)

Brickmap voxel rendering: Brickmap by Wingerden / the "Voxel ray tracing with brickmaps" line of work, and Teardown's GDC talks on destructible voxel rendering.

Sparse voxel octrees for comparison: Laine & Karras, Efficient Sparse Voxel Octrees.

Dynamic diffuse GI with probe grids: Majercik et al., Dynamic Diffuse Global Illumination with Ray-Traced Irradiance Fields (DDGI).

Sky and atmosphere: Hillaire, A Scalable and Production Ready Sky and Atmosphere Rendering Technique.

Gravity design: Super Mario Galaxy's planetoid and spline-gravity design, as discussed in Nintendo's post-release talks.

Rigid-body solving: Catto, Iterative Dynamics with Temporal Coherence (sequential impulses).

Granular settling: cellular-automaton falling-sand rules (Noita's GDC talk on the Falling Everything engine).

