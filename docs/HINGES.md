# Hinges, swing doors, grab and weight

> **Status (2026-10-19): phase 1 (kinematic swing door) and phase 2 and phase 3 (grab) are built** (hinge to the world with spring / friction / breakaway / motor rows, the player collides with and pushes bodies (`push` actions: impulses logged by body id, the replay applies them), `min_weight` volumes, dynamic doors and trapdoors; differences below) (see docs/EVENTS.md "Swing doors" and docs/PREFABS.md for doors made of prefab parts); phases 2 and 3 are design only. Written by the fable session against commit f54160d; the user asked for swing doors, hinges you push open by walking against them, a grab mechanic, and mechanisms with a minimal needed force (trapdoors by weight along gravity).


Feasibility check and design for: swing doors, hinges the player can walk against, a grab mechanic, and mechanisms that need a minimum weight or force. Written against f54160d (read-only) in the same form as docs/EVENTS.md: verdict, model, data structures, signatures, tick order, Lua / MCP surface, phases, tests, risks.

> **Phase 2 as built, differences from the text:** a joint to the world is stored with the world as `a` and the body as `b` (so the hinge angle is the body's own rotation); a dynamic door is *always* a body (no latch / weld at the stops: `latch` was cut, a closed dynamic door does not occlude GI light); the player is moved out of every body it touches (a kinematic swing door pushes the player away instead of letting them through) and its push is an impulse of at most 600 N (10 N s per tick) at the touched point, its weight (80 kg along the pull) while standing on a body; bodies that touch a hinged body wake it and are woken by it (a sleeping door would not feel the load on it); a hinge with a spring or a motor never sleeps while it is being pulled. Round 12 (fable review) fixes: hinged contact pairs sleep together (no wake ping-pong), `hinged` only for hinge joints, a spring that pulls beyond its stop rests, the world stub is reset each step, joint state is in the physics hash, the turning kinematic door checks the player per step, a dynamic door removed at 40 degrees goes to the nearer stop. Grab numbers: lift < 61 kg (the pull is capped at 600 N and carries the weight), drag up to about 255 kg on a floor with friction 0.6 (a horizontal shove of at most 1,500 N, no lift), heavier bodies cannot be moved by the hand (the HUD says "too heavy to move", MCP `grab` answers `liftable` / `draggable`); the hold distance is at least the body's radius + the capsule's + 15 cm; standing on a body refuses the grab and lets go of a held body; the hand's reach is 3.5 m for Lua `body.grab` too. Grab as built: `src/sim/grab_system.*`, E grabs / releases (after buttons), the left mouse button throws while holding, MCP `grab` / `release` / `throw`, script tokens, Lua `body.grab`; the hold is a critically damped spring (12 rad/s) at the grabbed point capped at min(600 N, 3 m g) with the weight carried, a body that the hand cannot lift (m g > 600 N) is pulled horizontally only, a held body does not sleep or weld, the hand lets go when the body is 2 m from the hand and not moving for half a second; the grab / release / throw actions carry numbers, the pull is recomputed from the logged player pose (a replay reproduces it). Not built: `breakOnAnchorLoss` (a carved door falls apart with its joint: `carvable`), phase 3 (grab).

## 1. Verdict

| part | cost | verdict |
|---|---|---|
| Swing door driven by the event system (opens / closes on a signal, pushes crates, player blocked while it is at rest) | small: no physics change; a kinematic body posed from an angle curve, welded back as voxels at 0 / 90 degrees | **build first** (phase 1) |
| Real hinge in the solver: a dynamic body on a world-anchored hinge with limits, spring, friction / breakaway torque, motor | moderate: the joint solver gets a world anchor, infinite-mass partners and three new rows (about 150 lines in physics_world.cpp); the door is then a body that bodies, blasts and the grab can move | **build** (phase 2) |
| "Walk against it and it opens": the player collides with bodies and pushes them | moderate: the player probe today sees voxels only; add body voxels in the body's own frame to the capsule test and give the body an impulse (about 200 lines in player.cpp, a hook in main). This is the piece every "physical" interaction needs | **build** (phase 2, before the grab) |
| Grab: pick up light things, drag heavy ones, use handles | moderate: a CPU ray against bodies (none exists), a point impulse API, a spring hold with force limits, three logged actions | **build** (phase 3) |
| Weight-gated plates, trapdoors, doors that need a push | small once hinges exist: a weight filter on Volume (local gravity), a breakaway torque row on the hinge | **build** (phase 2) |
| Player standing on moving bodies (riding a platform, a trapdoor dropping under the feet) | large: a ground that moves under the capsule, inherited velocity, support from a body instead of voxels | **cut for now**; a trapdoor still works for crates and for a player who walks onto it only because the player falls through the hole once the slab swings away (see 4.3) |
| Vehicles, motors beyond doors, sliders | out of scope; the hinge rows make a motorised hinge possible later | cut |
| GI occlusion by body doors (a lamp behind a closed dynamic door leaks light) | GI probe rays march the world only; adding bodies to them is a GPU change | **built**: door-sized hinged or driven bodies (and trapdoors) go to the GI probe rays as oriented boxes (nearest 16, `gi_update.comp` `giOccHit`; a hit lights from the sun and the probes like a world hit, a box blocks lamps and the sun) |

Honest notes. (a) Weights exist already and they are large: a voxel's mass is its material density, and a 1 m wooden crate (`body.box(..., 16, 16, 16, "wood")`) is 768 kg, a stone one 2.7 t. "Blocks need weight" is done; what the levels need is **smaller or lighter props** (a 0.5 m crate of wood is 96 kg, a `crate` material of density 10 gives 20 kg) so that a human can lift anything at all. (b) The player has no mass in the engine; the push and the grab give them an effective mass (80 kg) and force caps. (c) The hinged door is a body, and bodies are not saved: the door's angle is event state, the body is rebuilt from the door's definition at start, so a swing door must be defined (`material` box or a model file), never captured from the world.

## 2. What the engine does today (the facts the design rests on)

- Bodies: `VoxelBody` (physics/body.hpp): bricks in the shared pool, mass and inertia from per-voxel density (`density * 16 kg/m³`), surface samples for contacts, `pos / rot / vel / ang`, `owned` (never welded), `kinematic` (posed by the game: no gravity, no integration, never sleeps, pushes dynamic bodies, is not pushed, **does not collide with the world**: physics_world.cpp:643).
- Solver: sequential impulses, 4-10 iterations, graph-coloured parallel solve, thread-count independent; speculative contacts; contact caching per body and pair; resting damping that grows with `lowTicks` (integrateVelocities); forced sleep after 4 s of creeping; welding of un-owned sleepers after 10 s to one of 24 rotations (`tryWeld`, `bodyToModel` + `set_model`).
- Joints (physics/joint.hpp): Ball and Hinge **between two bodies only** (`addJoint` needs both to exist); hinge axes aligned by two angular rows, optional angle limits; no spring, no friction, no motor; jointed bodies do not collide with each other and sleep as a group; a kinematic partner is treated like any body (its `invMass` is real), so a hinge to a kinematic anchor would move the anchor.
- Player: capsule of four spheres vs **world voxels only** (`WorldProbe`); nothing in `Player` knows bodies (docs/EVENTS.md section 10). The player neither blocks on, stands on, nor pushes bodies.
- Rays: `raycastWorld` hits world voxels only (MCP `raycast`, `use`, the editor); no CPU ray against bodies exists. The GPU marches bodies for the picture (`marchBody` in raymarch, shade's sun shadow via tile lists, particles), bodies cast shadows and get AO and TAA reprojection; GI probe rays march the world only.
- Impulses: `applyImpulse(id, J)` at the centre of mass; `blast` radial; nothing applies an impulse at a point.
- Hash: `PhysicsWorld::stateHash` mixes pose, velocity and `awake` of every body in id order; the session hash includes it. Bodies are not saved; the events state file saves per-node integers.
- Event doors: a slab of voxels moved by `setVoxels` steps along one axis, blocked by the player capsule and body AABBs (EVENTS.md 4.2).

## 3. Model: three kinds of door, one data path

A swing door is a `Door` node with `hinge = {...}`. Its lifecycle has two representations, chosen per phase of motion:

1. **At rest at a stop (closed, or fully open at 90 degrees)**: voxels in the world, placed by `set_model` of the door's model rotated by 0 or 90 degrees about the hinge axis. The player is blocked (voxels), GI occludes, undo and the LOD see a normal structure. This is exactly what today's sliding door does with its slab.
2. **In motion**: a `VoxelBody` built from the door's model (`buildModelBody`), the world voxels cleared by the same two ops as a slide step (`ClearIfEqual` of the model's cells, then nothing to put), the body `owned`, at the pose of the current angle. Two drives:
   - **kinematic** (phase 1): the body is `kinematic`, posed each tick from an angle curve `theta(t)` by the event system, like `AnimatedModels::pose` sets `pos / rot / vel / ang`. It pushes crates, nothing pushes it, the player passes through it for the duration of the swing (0.5-1.5 s; the door swings away from a walking player). When the curve reaches a stop the body is welded back (`weldAt(id, rotation)`: `bodyToModel` + `set_model` with the 0 / 90 degree rotation, the body removed) and the node is at rest again.
   - **dynamic** (phase 2): the body is dynamic with a world-anchored hinge joint (limits at the stops, spring toward a rest angle, friction, optional breakaway torque, optional motor). Bodies, blasts, the player's push and the grab move it. When it sleeps at a stop it is welded; when it sleeps elsewhere (ajar, held by friction) it stays a body and its angle is saved.

Why not "always a body"? Because the player would walk through a closed door until the player-vs-body collision exists, and because bodies are neither saved nor GI-occluding. Why not "always voxels, rotated in steps"? Because the 24 axis rotations give only 0 / 90 degree poses: no swing to see, no crates pushed. The hybrid gives the correct state at rest and real motion in between, and the dynamic drive is a drop-in later.

Comparison the user asked for:

| | kinematic body (events drive) | dynamic body + world hinge | voxel steps |
|---|---|---|---|
| solver change | none | world anchor, infinite-mass partner, spring / friction / motor rows | none |
| what the door does to world voxels | cleared while moving, welded at the stops | same, plus "ajar" stays a body | the slab is rewritten every step |
| pushes crates | yes (kinematic pushes dynamic) | yes, and is pushed back | waits for them (blocked) |
| player walks against it | passes through while moving; blocked at rest (voxels) | blocked and pushes it once phase 2 player collision exists | blocked (voxels) |
| angle | f(tick), exact | physics state (float), saved quantised | 0 / 90 only |
| determinism | f(tick) | the solver is deterministic already | edit queue |

## 4. Pieces

### 4.1 Physics additions (`physics/joint.hpp`, `physics/physics_world.*`)

```cpp
struct JointDesc {
    u32 a = 0, b = 0;            // b may be kWorldBody: a hinge or ball joint to the static world (anchor / axis fixed in world space)
    ...                          // as today
    // new rows (Hinge only)
    float springTarget = 0;      // rad; spring pulls theta toward it
    float springK = 0;           // N m / rad (0: no spring)
    float springDamping = 0;     // N m s / rad
    float friction = 0;          // N m: a constant torque opposing motion (kinetic)
    float breakaway = 0;         // N m: the torque needed to start moving from rest (static friction); 0: none
    float motorSpeed = 0;        // rad/s target (0 with motorMaxTorque 0: off)
    float motorMaxTorque = 0;    // N m
    bool  breakOnAnchorLoss = false; // remove the joint when the voxel under the anchor on body a is gone (carved hinge)
};
struct Joint { ... float jMotor = 0, jFriction = 0, theta = 0, omega = 0; bool stuck = false; ... };

u32  addJoint(const JointDesc& d);                        // accepts b == kWorldBody
bool setJoint(u32 jointId, const JointDesc& d);           // retarget spring / motor / limits at run time (the event commands)
bool jointState(u32 jointId, float& thetaRad, float& omegaRadPerS, float& lastTorqueNm) const;
void removeJoint(u32 jointId);
void applyImpulseAt(u32 id, const Vec3& impulseNs, const Vec3& pointM); // linear + angular, wakes
void applyAngularImpulse(u32 id, const Vec3& LNs);
struct BodyHit { bool hit = false; u32 id = 0; IVec3 cellLocal; Vec3 pointM, normalM; float distanceM = 0; u16 material = 0; };
BodyHit raycastBodies(const Vec3& originM, const Vec3& dir, float maxM) const; // OBB slab test per body (sorted by id), then a DDA over solidAtLocal
bool weldAt(u32 id, int rotation, std::vector<EditOp>& ops);  // the body as a set_model at one of the 24 rotations at its current position, body removed
```

Solver changes, all inside the existing deterministic loop:
- `prepJoints` / `solveJoint`: a partner that is `kWorldBody` or `kinematic` gets `invMass = 0`, `invInertia = 0` and a fixed `rB` from the world anchor (`j.lb` is then a world position). Today a kinematic partner has real inverse mass; this fix also makes rigs usable as hinge anchors.
- Hinge angle `theta` and rate `omega` are computed in `prepJoints` already (for limits); store them in the joint for `jointState` and the rows below.
- Spring: an angular row with target rate `-(springK * (theta - springTarget) + springDamping * omega) / I_eff * dt`, applied as a soft constraint (one impulse per iteration clamped to the spring's torque times dt). Friction: an accumulated impulse clamped to `friction * dt` opposing `omega` (exactly like contact friction). Breakaway: while `stuck`, the clamp is `breakaway * dt`; the joint leaves `stuck` when the accumulated impulse hits the clamp (the load exceeded the static torque) and enters it again when `|omega| < 0.05 rad/s` for 30 ticks. Motor: an accumulated impulse toward `motorSpeed` clamped to `motorMaxTorque * dt`. All four are standard sequential-impulse rows: 20-30 lines each.
- `breakOnAnchorLoss`: after `carveBodies`, if body `a` no longer has a solid voxel within one voxel of `la`, the joint is removed (the door falls; design section 7: "destroying the hinge voxels destroys the joint").
- Resting damping (`integrateVelocities`: `touching` damping and `settledForGood`) fights a door that swings against its frame. Give `VoxelBody` a `bool hinged` (set when a joint references it) that halves the resting damping and disables the forced sleep; the hinge's own friction row provides the settling.

### 4.2 Player vs bodies (phase 2, `sim/player.*`, a hook in main)

```cpp
// Player
struct BodyContact { u32 body; Vec3 point, normal; float depth; };
void setBodyProbe(std::function<void(const Vec3& lo, const Vec3& hi, std::vector<const VoxelBody*>&)> probe); // bodies whose AABB overlaps a box (the app passes phys.bodies() through the events' grid or a plain scan)
const std::vector<BodyContact>& bodyContacts() const;   // this tick's pushes (the app converts them to impulses)
static constexpr float kPlayerMassKg = 80.0f, kPushForceN = 600.0f;
```
In `resolve()`, after the voxel candidates: for each candidate body, transform the four sphere centres into the body's voxel frame (`localVoxelFromWorld`), test against `solidAtLocal` in a 3-voxel neighbourhood (axis-aligned there), compute the deepest penetration and its normal in local space, rotate back. Walkable contacts (within 45 degrees of `up_`) stop the fall like voxels do; wall contacts clip the velocity. Then the push: for a **dynamic, awake-able** body the player is moved out by `depth * mB / (mB + 80 kg)` and the body gets `BodyContact{depth, normal}`; the app applies `applyImpulseAt(id, -normal * min(kPushForceN, depth / dt * 80 kg) * dt, point)` before `sys.tick()`. A 50 kg door swings away, a 1 t crate hardly moves and the player is pushed back. Kinematic bodies and sleeping heavy bodies (the player cannot wake something above `kPushForceN / g`) push the player out fully. The impulse is applied in the same tick order every time (events, player contacts in body id order, physics) so it replays.
Not done here: standing *on* a body as ground (the walkable contact stops the fall but the body does not carry the player along; a moving platform slides out from under the feet). That is the cut.

### 4.3 Swing doors in the event system (`sim/event_system.*`)

```cpp
struct HingeDesc {                       // Door, when present: a swing door
    IVec3 axisCell{0};                   // voxel cell the hinge axis passes through (a corner column of the door box)
    int axis = 1;                        // 0 x, 1 y, 2 z (a trapdoor hinges about x or z)
    int openDeg = 90;                    // the open stop: +90 or -90 (the swing direction)
    float openSeconds = 0.8f;            // kinematic drive: swing time (ease in / out)
    // dynamic drive (phase 2), all optional
    bool dynamic = false;
    float springToDeg = 0, springK = 0, springDamping = 0;   // a door that falls shut (spring to 0) or stays where it is (0 K)
    float friction = 0, breakaway = 0;                        // N m
    float motorMaxTorque = 0;                                 // open / close commands drive the motor instead of the curve
};
// NodeDesc gets: HingeDesc hinge; bool hasHinge; std::string doorModel (a .vxm: the door as data; else `material` + box)
// Node gets:     u32 bodyId; u32 jointId; i32 angleMilli (the saved / kinematic angle in 1/1000 degree); u32 moveStart; i8 restStop (0 closed, 1 open, -1 ajar)
```
Commands: `open`, `close`, `toggle`, `stop` as today; level = open (at the open stop). Kinematic drive, per tick in `stepDoors`:
1. At rest and commanded: build the body from the model at the rest rotation (`buildModelBody`, `owned = true`, `kinematic = true`), submit the clear of its cells (`ClearIfEqual` by value, as the slide does), set `moveStart = tick`, `restStop = -1`.
2. Moving: `theta(tick) = ease((tick - moveStart) / (openSeconds * 60))` between the stops (in 1/1000 degree integers), pose the body: `rot = axisRotation(theta)`, `pos = hingeWorld + rot * (comLocal - hingeLocal)`, `vel / ang` from the previous pose like `AnimatedModels::pose`. A blocked swing (a crate against the door, detected as the body's contacts pushing it: the kinematic body cannot be pushed, so detect the crate's penetration through `phys.contactViews()` or simply "a body overlaps the door's next-pose OBB") pauses the curve (`moveStart` shifts), like the slide waits.
3. At a stop: `weldAt(bodyId, rotation)` (0 or the 90 degree rotation about the axis), `restStop` set, level edge emitted. The weld's `set_model` goes through the edit queue at `tick`.
Dynamic drive: step 1 builds a dynamic body and `addJoint` with `b = kWorldBody`, anchor at the axis cell's centre, limits `[0, openDeg]`, the spring / friction / breakaway from the desc; `open` / `close` set `motorSpeed` (if `motorMaxTorque > 0`) or just release the latch; the node polls `jointState` each tick, emits `opened` / `closed` when the angle reaches a stop and the body sleeps, then welds **only when the latch is set** (`latchAtStops = true`, default): a door that is meant to swing freely stays a body. `trapdoor = true` is a hinge about x or z with `breakaway` and no spring: it holds until the load on it exceeds the torque, then falls open to the limit and stays (no latch).

Weight on a trapdoor: the crates on it are body-vs-body contacts (dynamic door vs crate), their weight reaches the hinge as torque through the solver; `breakaway` is compared against the accumulated hinge impulse. A player on it needs 4.2 (the push gives the player's weight as a contact impulse of 80 kg along local gravity); until then a player opens nothing by standing.

### 4.4 Weight sensors (`VolumeFilter`)

```cpp
float minWeightN = 0;   // sum over what is inside of m * max(0, dot(g(p), -n)) >= this, with n the sensor's up (the box's +y face rotated by nothing: use the gravity's up at the box centre), the player counting 80 kg
bool  weightUsesPlayer = true;
```
`evaluateSources` already walks the bodies inside; add the weight sum with the body's `gAcc` (sampled last step; for sleepers `gravity_(pos)`), so a plate on the habitat tube's wall or in a flipped room weighs along the local down. `min_mass` stays (it is "a body of at least this mass is inside"); `min_weight` is new ("at least this much presses on it"). The Lua volume takes `min_weight = 500` (N).

### 4.5 Grab (phase 3, `sim/grab_system.*` or inside `Player`: a `Hold`)

Input: **E** on a body (the use key, same reach 3.5 m: `raycastBodies` first, then `raycastWorld` for buttons; the nearer hit wins), E again or **the dig button** to release, **RMB** to throw (an impulse of `throwSpeed * mass`, capped by `kThrowForceN`). Actions, logged by id and numbers, never by view: `grab <bodyId> <holdDist>`, `release`, `throw <speed>`. Script tokens `grab`, `grab:ID`, `release`, `throw:S`; MCP `grab {id|name-of-spawner}`, `release`, `throw {speed}`.
Hold: each tick (after the player step, before physics: the same slot as the push contacts) the target point is `eye + forward * holdDist`, clamped by `raycastWorld` so it never sits inside a wall; the body gets a critically damped spring impulse at its centre of mass toward the target (ω = 12 rad/s, damping 2·ω) and an angular damper toward "keep the grabbed orientation relative to the view" (weak, so a crate turns with the player), both clamped: `|F| <= min(kCarryForceN = 600, 3 * m * g)` (a light thing follows crisply, a heavy one is dragged slowly and cannot be lifted against gravity: `m * g > 600 N` means above 60 kg the hold slides it along the floor and cannot raise it). Nothing is kinematic: contacts always win, the held body cannot be pushed through walls or into the player (the player's own push contact from 4.2 keeps it out of the capsule). Release when the body is farther than `holdDist + 1 m` from the target for 30 ticks (torn away), on `release`, on a throw, when the player flips (the hold keeps working through a flip: the target follows the eye; the spring just pulls it along; no special case), when gravity changes (nothing to do: the spring is relative to the eye), when the body is destroyed (`find` fails) or welded (never: held bodies are marked `owned` while held and restored after).
Handles: a door's body is grabbable like any body (the hold applies the impulse at the grab point via `applyImpulseAt`, so pulling a door's edge swings it); a sliding event door is voxels and not grabbable (its button is).
What the player can lift: by mass, through the force cap: a 0.5 m wooden crate (96 kg) is dragged, a 0.375 m one (40 kg) is carried; level authors see the numbers in LUA_API ("a 16-voxel wooden crate is 768 kg: use 8-voxel crates or the `crate` material").

### 4.6 Rays, picture, describe

- `raycastBodies` makes `use`, the grab, MCP `raycast` (`body: id` in the answer when a body is nearer than the world hit) and `describe` (`pressable` / `grabbable` with the body id and mass) see bodies.
- The picture needs nothing: a body at any angle is ray-marched in its own frame, shadowed, AO'd, reprojected by TAA with its previous pose, pushes particles. The welds at the stops go through the edit queue like any set_model (LOD, GI, undo see voxels).
- GI: hinged or driven bodies of at least 0.2 m are boxes for the probe rays (so a closed door keeps a lamp's light and the sun out of the next room); other bodies (crates, rubble) are still invisible to GI. A GPU test: `the lava's light`.

## 5. Determinism, replay, save

- Kinematic doors are `f(tick)`; dynamic doors and the hold are solver state, which is thread-count independent already; the new rows run inside the same coloured iteration loop (a joint touches one body and the world: it is its own colour group like today's joints).
- Actions: `use` on a door body, `grab`, `release`, `throw` carry ids and numbers. The push contacts come from the player's recorded state and the bodies' state: recomputed.
- Session hash: `phys.stateHash()` already covers body poses; add the joints (id, theta, omega, stuck, accumulated impulses are rebuilt: not needed) and, in `events.stateHash()`, `angleMilli / moveStart / restStop / bodyId / jointId`; the hold's `heldBody / holdDist / tornTicks` in the player state hash (new: the player is not hashed today, the hold must be).
- Save: `.events/state.txt` gets `angleMilli restStop` per door; at start a door at a stop is placed as voxels (as the slide door is placed today from `material` / `doorModel`), a door that was ajar is rebuilt as a dynamic body at `angleMilli` with its joint (the world shows air there: the door's own cells are cleared by the save). Bodies that are not doors are not saved (as today).
- The weld at a stop uses `rotation` 0 or the 90 degree rotation about the axis from the 24; `bodyToModel` of a body that was built from the same model at that rotation is voxel-exact, so the voxels at the stop are identical on every path (live, replay, reload): the world hash agrees.

## 6. Lua and MCP

```lua
d = events.door{ name = "front", model = "models/door.vxm", pos = {x, y, z}, rotation = 0,          -- or material = "wood", box = {...}
                 hinge = { axis = "y", at = {x, y, z}, open = 90, seconds = 0.8 } }                    -- kinematic swing
d = events.door{ name = "cellar", material = "wood", box = {...},
                 hinge = { axis = "x", at = {...}, open = -90, dynamic = true, breakaway = 400, friction = 20, latch = false } }   -- a trapdoor: 400 N m to open
d = events.door{ name = "saloon", ..., hinge = { axis = "y", at = {...}, open = 100, dynamic = true, spring_to = 0, spring_k = 30, spring_damping = 6, limits = {-100, 100} } }  -- swings both ways, falls shut
events.connect(plate, "enter", d, "open")          -- as today; dynamic doors with motor_torque take open / close as motor commands, without one `open` releases the latch
a = events.state(d).angle_deg                      -- also: omega, body, at_stop
plate = events.volume{ ..., bodies = true, min_weight = 500 }   -- newtons along the local down
h = hinge.add{ a = bodyA, b = bodyB or "world", anchor = {x, y, z}, axis = {0, 1, 0}, limits = {lo, hi}, spring_to = 0, spring_k = 0, friction = 0, breakaway = 0, motor = {speed, torque} }
hinge.set(h, { motor = {2, 50} })   hinge.state(h) --> { angle, omega, torque }   hinge.remove(h)
body.push(id, ix, iy, iz [, px, py, pz])           -- the impulse at a point (new optional point)
id = body.grabbed()   body.grab(id)   body.release()   body.throw(speed)
```
MCP: `events` lists `angle_deg / omega / body / at_stop` for swing doors; `trigger` / `event_command` as today; `push {id, impulse, point?}`; `grab {id}`, `release`, `throw {speed}`; `hinge_state {name}`; `raycast` answers `body`; `describe` adds `grabbable` / `held`; `step_until` gets `hinge:<name>:open` / `:closed` / `:angle>=N`. The determinism script gets a case `swing` (a plate opens a kinematic door, a crate is pushed by it, a dynamic trapdoor is loaded with two crates, `grab:ID,idle:60,throw:6`).

## 7. Tick order

In `tickTail`: `luaTick()` -> `events.tick()` (door state machines: build / pose / weld requests, weight sums, joint commands) -> `player push contacts -> impulses` (new, from the player step that ran before `tickTail`) -> `hold impulse` (new) -> `animated.tick()` -> `sys.tick()` (edit flush incl. door clears and welds, physics step with the joints) -> as today. The weld requests of `weldAt` are edit ops submitted at `tick` like the slide steps.

## 8. Phases and tests

**Phase 1 (swing door, kinematic):** `HingeDesc`, `doorModel`, kinematic build / pose / weld (`weldAt`), angle state and save, Lua `hinge = {...}`, MCP fields, demo: the arena gate becomes a swing door, the cove house door swings. Tests (`tests/test_events.cpp`, headless): a door swings open in 48 ticks and its voxels are at the 90 degree model afterwards (voxel-exact against `rotateModel`); the world is air where it was; a crate in the swing path is pushed (its position changes) and a crate against the door pauses the swing; `close` at mid-swing reverses; save / load at a stop and at mid-swing (restarts the curve from the saved angle); hash changes with the angle; `trigger` and `step_until event:front:on`.
**Phase 2 (hinge physics, player push, weight):** world anchor and infinite-mass partners in the joint solver, spring / friction / breakaway / motor rows, `jointState`, `applyImpulseAt`, `hinged` damping flag, player-vs-body collision and push, `min_weight`, the trapdoor. Tests: a hinge to the world holds a body against gravity with the anchor error under 1 mm; limits hold under a blast; spring settles to the target within 2 s and the rest is bit-identical on 1 and 6 threads; breakaway: one 20 kg crate on a 400 N m trapdoor does not open it, two 300 kg ones do; the player walking into a 50 kg door swings it and into a 1 t crate is stopped; a plate with `min_weight` 500 N ignores a 20 kg crate and fires on the player + crate in the flipped room (gravity up) measured along the local down.
**Phase 3 (grab):** `raycastBodies`, actions, the hold, throw, MCP tools, LUA_API notes on masses. Tests: grab a 40 kg crate, walk 5 m, it follows within 0.3 m; a 96 kg crate is dragged along the floor and never lifted above its start height + 5 cm; the hold cannot pull a crate through a wall (the crate stays on the far side); release on tear; throw gives `speed * mass` clamped; replay of a grab / throw session matches on another thread count.

## 9. Risks and the parts of the engine that fight this

- **Tunnelling**: a kinematic door poses jump up to `openDeg / (openSeconds * 60)` per tick (1.9 degrees at 0.8 s): the door's edge moves 2 cm per tick at 0.6 m from the hinge, well under the speculative reach; crates are pushed, not skipped. A dynamic door is an ordinary body: speculative contacts cover it.
- **Crushing**: a kinematic door cannot be pushed, so a crate between the door and the frame would be squeezed: the pause rule in 4.3 (a body overlapping the next pose stops the curve) avoids it; the dynamic door simply stops (the crate's contact wins). The player is not crushed because the kinematic door passes through them (phase 1) or pushes with a capped force (phase 2).
- **Jitter**: the user saw capsule jitter on voxel steps (fixed by the standing hold). Against a body, the same hold applies (no input, supported: stay put), and the push impulse is applied only while the player has input or the body is moving; a resting body touching a resting player gets no impulse. A dynamic door against its frame jitters through resting damping and sleep: the `hinged` flag and the friction row (4.1) replace the pile logic for doors.
- **Performance**: a swing door costs one body (drawn and simulated like a crate: tens of microseconds); 100 hinged bodies are 100 joints in the solve (joints are a few hundred nanoseconds per iteration each); the player's body probe tests at most the bodies whose AABB overlaps the capsule's box (a scan of `bodies()` is 1,000 AABB tests per tick: 2 µs; the events grid can serve it later). `raycastBodies` is an OBB test per body plus one DDA: 1,000 bodies in about 20 µs.
- **The solver fights you** in two places: the resting damping and forced sleep (4.1: `hinged` flag), and the kinematic partner's real inverse mass in the joint rows (4.1: zero it). Both are small, local changes.
- **Welding exactness**: the weld at a stop is voxel-exact only because the body was built from the same model at the same rotation; a body that lost voxels (a blast) welds what is left, which is right.
- **The player on top of a door** (standing on a trapdoor) is the cut: the slab swings away under the feet and the player falls through the hole: the trapdoor "works" for the player by accident, and a rising door lifts nobody.

## 10. Ball joints and chains: `joint.ball`, `chain.add` (E13)
A lantern on a chain that swings when the player runs into it, with its light.
```lua
j = joint.ball{ a = body, b = otherBody | nil (the world), anchor = {x, y, z} (m), axis = {x, y, z} (default down),
                cone = 60 (degrees the two bodies' axes may part, 0 = free, at most 180), damping = 0 (N m s / rad), friction = 0 (N m) }
joint.state(j) --> { angle = degrees between the two axes }      joint.remove(j)

c = chain.add{ anchor = {x, y, z} (m, where the top link hangs from), body = id (hang it from a body instead of the world), links = 3 (1 .. 12),
               link = { length_voxels = 4, radius = 1, material = "metal" },
               tip = { material = "glass", size = {4, 6, 4} } (a lantern body at the end; false: none; `end` is a Lua keyword, so `tip`, or ["end"] ),
               cone = 60, damping = (default: a share of what stops the whole chain), friction = 0 }
--> { links = {ids}, tip = id, joints = {ids}, group = n, bottom = {x, y, z} }       chain.remove(group)
emitter.create{ name = "flame", preset = "torch", body = c.tip, offset = {0, 0.15, 0} }   -- the flame and its light swing with the lantern (docs/EMITTERS.md)
```
- A ball joint holds two anchor points together (to the world: the anchor stays where it was made) and may limit the angle between the two bodies' axes (`cone`). The two bodies never collide with each other (jointed). **Damping** is a soft row on the relative spin, solved with the anchor constraint (`gamma = 1 / (c dt)`, as the hinge's spring row), so a chain does not swing for ever: `chain.add`'s default is 1.5 x mass x hang length x its square root (about a third of critical for a pendulum of that mass and length): a push dies away in a few swings and the chain sleeps within about seven seconds. **Friction** is a constant torque against the relative spin. Twist is not limited (a link is round).
- `chain.add` builds N boxes on ball joints from the anchor, hangs the lantern body (a box) on the last, and makes **none of its bodies collide with each other** (a folded chain does not catch itself); they do collide with the player (it pushes them: the usual 10 N s a tick, so a few ticks of walking into a lantern swing it), with other bodies and with the world. Bodies are not saved: a script that makes the chain at its start makes it again. At most 4 chains per cell and 2 to 3 links are the game's budget (a floor stays under about 60 extra bodies; they sleep after settling and a touch wakes them).
- The lantern's mass comes from its voxels and material (a 4 x 6 x 4 glass box is 34 kg, a link of metal 16 kg): `link = { material = "wood" }` makes a lighter chain. A swinging lantern does not occlude light (the probes see no bodies).
- Tests: `chain.add: ...` (a pushed three-link lantern swings, settles and sleeps, bit for bit the same in two runs with another history of bodies), `joint.ball and chain.add refuse ...`, `emitters: an emitter that follows a body ...`, and the MCP smoke test (three chains, the player walks through them, the recording replays to its hash).

## 11. Bodies that leave the world, and `body.list()`
- A body whose centre of mass is below **-64 m** (a world's lowest chunk is at 0 m: nothing there can come back) is removed in the tick, with a log line, and so is a rigged model (a ragdoll) whose first part is: they fell through ground that was not there (a hook that had not made the chunk yet, a teleport) and would otherwise fall for ever, 25 m/s and more, in every hash. Not removed: kinematic and hidden bodies (agents' own), a vehicle's parts, the body in the player's hand. An agent whose ragdoll falls out of the world (-25 m) is removed with its model as a walking one is (`on_agent(id, "fell")`).
- `body.list()` returns `{ { id, x, y, z (metres, centre of mass), awake, kinematic, mass (kg), owner }, ... }` in creation order; `owner` is "script" (made with `body.box` / `body.ball` / `chain.add`), "model" (a part of a rigged model), "vehicle", "agent" (an agent's own box) or "debris" (what a blast or a collapse made). A script can audit what is alive and `body.remove(id)` what it does not want.
- Tests: the MCP smoke test (bodies at -70 m and -100 m go, the one at 10 m stays, the recording replays to its hash).
