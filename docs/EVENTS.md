# Events and triggers

> **Status (2026-10-19): phase 1 is built** (`src/sim/event_system.*`, `tests/test_events.cpp`, the determinism case `events`, the MCP tools). Implemented: Button, Lever, Volume (player and bodies, box and sphere, filters), Lamp, Door, LuaCallback, connections with delays, `reconcile`, the saved state, the session hash, the E key, `use` / `use:ID`, Lua `events.*`, MCP `events` / `trigger` / `event_command` / `status.sim.events` / `describe` hint / `step_until event:NAME:on`. Phase 2 is partly built: Timer, Logic (all eight ops), GravityTarget, Spawner and Effect (the flip room keeps its own `flip` action; the lever conversion is not done). Not built: Region, GravityWatch, Prefab, the panel / overlay, `stay` rate limit; phase 3. Their kinds exist in the enums and `add()` refuses them.
> **Decisions on the open questions (section 11):** `stay` is delivered every tick (no rate limit yet); a button cannot be pressed through glass (the raycast stops at glass); the hint and the E key exist in walk mode only (E stays the lift key in fly mode and while swimming); a door waits for what stands in its way and does not push it.
> **Round 11 (fable review of phase 1), implemented:** door slab captured at the right time/place (see below); a Lua callback may change the graph during a tick (nodes are a deque, removals and disconnects wait until the tick is over, deliveries are copied); `trigger` on a door opens/closes it, on a lever switches it on/off (pulse flips it), on a button presses it, a volume takes only pulse and stay; edges beyond the 8-generation cap go on next tick; a close blocked for 30 ticks reverses to open when `auto_close` is set; a door checks that its slab is where it left it before each step (waits, adopts after 2 s); `noteChangedChunks` is a stub (reserved for regions).
> **Swing doors (docs/HINGES.md phase 1, built):** `hinge = {axis, at, open = +-90, seconds}` on a door with `material` or `model`: the slab is data, voxels at the closed and the 90 degree stop (the open slab is the closed one turned about the axis through the cell centre: voxel exact), a kinematic body posed from the tick number while it turns (integer angle in 1/1000 degree, ease in / out, reversal at mid swing, `stop` is ignored), the voxels of the stop it leaves are cleared when it starts and the target stop's are put when it ends; at the end it waits while the player or a body stands where it closes. Nothing pushes a kinematic door; the player is moved out of it by the player's body collision, and a sweep that would squeeze the player (between the panel and a wall) holds the door where it was (the `blocked` pulse, the timeline waits) and after 30 ticks sends it back to the stop it came from.
> **Limits worth knowing:** a door is whole again after it moves (each step writes the whole slab at the new position, so a hole blasted into a door whose first / middle / last voxel survive is filled by the next move); a door whose slab is gone altogether (those three voxels missing) stops moving after 2 s and waits for a later command or an undo; a node's box holds only its own voxels (a button/lamp/lever repaint (`PaintSolid` with `onlyMaterial`) also repaints foreign voxels of the `off`/`on` material inside the box, so keep the box tight); `use`, the E hint and `describe` cannot reach a button behind glass or liquid (the raycast stops at the first solid, glass and water included); `events.on(id, "on", f)` called twice for the same node and signal replaces the first function (one callback per node + signal; use `events.connect` to a second Lua node if you need two); injected commands and signals (`fire`, `command`, MCP `trigger`) run in call order at the next tick, and one injected from a callback waits for the tick after.
> **Differences from the text below:** edits are submitted with the tick number of the tick being simulated (ordering only; they flush with that tick's batch); a node adopts what the voxels show once, two ticks after it was declared (`reconciled`: the declaring call's own edits are in the world by then; a door finds its slab, a lamp its look); a door with `material = "wood"` has the whole box of that material as its slab and places it (at the saved position, closed on a first run) when the world does not show it, a door without it takes the solids found in its box (at the saved, the closed or the open position) and is refused above 65,536 box cells; there are no dormant nodes; edits are not tagged with the node; `lit = true` on a lamp (or lever) declares it as already on, for voxels that are built lit; the lamp's default radiance is the glow of its `on` material times 24.

Buttons, levers, pressure plates and volumes that send signals to lamps, doors, gravity fields, spawners, effects and Lua. This document is the implementable design: data structures, signatures, tick order, persistence, replay, Lua / MCP surface, budget, phases and tests. It was written against commit 03c3c56 (read-only); where it names a trap in the existing structure it says so.

## 1. Summary of the decisions

- One new sim-layer module, `src/sim/event_system.hpp/.cpp` (`EventSystem`), in `vx_sim`. It depends on world, physics, gravity and `sim/player.hpp` only. The app wires it (actions, keys, HUD hint, MCP tools, recorder, persistence), the Lua host binds it. Nothing below sim knows about it.
- Everything is a **node** with an integer id, a name, a kind and a boolean **level**. Sources compute their level from authoritative CPU state every tick; targets execute **commands**. A **connection** maps a source's edge signal (`on`, `off`, `pulse`, `stay`) to a target's command with an optional delay in ticks. Logic nodes are both.
- Evaluation happens **once per tick at one point** (`EventSystem::tick`, in `tickTail` right after `luaTick()`, before `animated.tick()` and `sys.tick()`), in **node id order**; deliveries are ordered by `(due tick, source id, seq)`. No wall clock, no frame state, no GPU state.
- **Replay**: a button press by the player or by MCP is an **action** (`use <id>`, `trigger <id> <signal>`) logged with the resolved node id, like `flip` and `doll`. Everything else (volumes, timers, logic, region watches, gravity watches, Lua `events.fire` from a script) is **recomputed**. The node states are mixed into the session hash.
- **Lamps** are voxels: a lamp target swaps the material of its voxels between an `off` and an `on` material through the normal edit queue (`PaintSolid` with `onlyMaterial`), and while on it also contributes a CPU point light to the renderer's extra-light list (the mechanism fire and lava use). No new light object type.
- **Doors** are voxels: a door target moves a remembered slab of voxels along a travel vector through the edit queue, `speed` voxels per tick (0 = instant), after checking that the slab's next position is free of the player capsule and of bodies. A kinematic body is not an option today because the player does not collide with bodies at all (trap, section 10).
- Event edits use a **system source id** (`kSourceEvents = kSimulationSourceBase + 0x10`): they never clear the redo stack, and `EventSystem::reconcile()` after undo / redo makes every lamp and door adopt what the world shows (the same pattern as `PrefabSystem::reconcile`).
- Persistence: node definitions come from the level script every run (declared by name in `on_start`, adopted by name like prefabs); node **state** is saved as a small text file `<project>/.events/state.txt` with the project save and copied into `<log>.clip/` by the recorder.

## 2. Model

### 2.1 Node kinds

| kind | role | level means | emits | commands it accepts |
|---|---|---|---|---|
| `Button` | source | pressed this tick (a pulse of `pressTicks`, default 1) | `on` (= `pressed`), `off` | `press` |
| `Lever` | source | switched on | `on`, `off` | `on`, `off`, `toggle`, `press` (= toggle) |
| `Volume` | source | something matching the filter is inside (box or sphere) | `on` (= `enter`), `off` (= `exit`), `stay` (every tick while on) | `enable`, `disable` |
| `Timer` | source | running and not yet due | `on` (= `fired`, a pulse when due) | `start`, `stop`, `reset` |
| `Region` | source | the box still holds at least `keep` of its initial solid voxels | `off` (= `destroyed`), `on` (repaired above `keep`) | `rearm` (take the current count as the initial one) |
| `GravityWatch` | source | the watched field is enabled | `pulse` (= `changed`: direction / strength / enabled changed), `on`, `off` | none |
| `Logic` | both | op over its inputs' levels (`and`, `or`, `not`, `xor`, `toggle`, `one_shot`, `counter`, `delay`) | `on`, `off`, `pulse` | `set <input> <0/1>`, `reset` |
| `Lamp` | target | on | `on`, `off` (mirrors its state for chaining) | `on`, `off`, `toggle` |
| `Door` | target | open (the slab is at its open position) | `on` (= `opened`), `off` (= `closed`), `pulse` (= `blocked`) | `open`, `close`, `toggle`, `stop` |
| `GravityTarget` | target | the field is enabled | none | `enable`, `disable`, `toggle`, `retarget <preset>` |
| `Spawner` | target | - | `pulse` (= `spawned`) | `spawn` |
| `Effect` | target | - | none | `play` |
| `LuaCallback` | target | - | none | `call` (any signal name is passed through) |
| `Prefab` | target | placed | `on`, `off` | `place`, `remove`, `toggle` |

Edge signals are the uniform vocabulary: a source whose level goes false -> true emits `on`, true -> false emits `off`; a pulse source (button, timer, spawner) emits `on` and, `pressTicks` later, `off`. Aliases (`pressed`, `enter`, `exit`, `fired`, `destroyed`, `opened`) are accepted by `connect` and by Lua and map to `on` / `off`. `stay` is emitted by volumes only, every tick while on (for "while the plate is held, keep the field on" patterns and for Lua).

### 2.2 Data structures (`src/sim/event_system.hpp`)

```cpp
namespace vx {

using EventId = u32;              // 1-based, sequential, never reused in a session
enum class NodeKind : u8 { Button, Lever, Volume, Timer, Region, GravityWatch, Logic, Lamp, Door, GravityTarget, Spawner, Effect, LuaCallback, Prefab };
enum class Signal : u8 { On, Off, Pulse, Stay };
enum class Command : u8 { Press, On, Off, Toggle, Enable, Disable, Start, Stop, Reset, Rearm, Set, Open, Close, Retarget, Spawn, Play, Call, Place, Remove };

struct VoxBox { IVec3 lo{0}, hi{0}; };           // inclusive voxel corners

struct VolumeFilter {                            // what counts as "inside"
    bool player = true;
    bool bodies = false;                         // any body
    u16 material = 0;                            // 0: any material; else the body's dominant material
    float minMassKg = 0;                         // bodies lighter than this do not count
    std::vector<u32> tags;                       // event tags given with events.tag(bodyId, tag) (see 2.5); empty: no tag filter
    bool kinematic = false;                      // animated parts count too
};

struct NodeDesc {
    NodeKind kind = NodeKind::Button;
    std::string name;                            // unique per session; the handle for adoption and MCP
    std::string prompt;                          // crosshair hint of a Button / Lever ("Light the lamp")
    VoxBox box;                                  // Button, Lever, Volume (box), Region, Lamp, Door: voxels
    Vec3 centreM{0}; float radiusM = 0;          // Volume (sphere), Effect, Spawner: metres
    VolumeFilter filter;
    u32 pressTicks = 20;                         // Button: pulse length and the time the pressed look is shown
    u16 matOff = 0, matOn = 0;                   // Button / Lever / Lamp / plate look: materials swapped on the node's voxels (0: no swap)
    Vec3 radiance{0}; float reachM = 8;          // Lamp: CPU point light while on (0: voxel emission only)
    IVec3 travel{0}; u32 speed = 2;              // Door: open position = box + travel (voxels); voxels per tick (0: instant)
    bool autoClose = false; u32 autoCloseTicks = 180; // Door: close again after this time open (a blocked close retries every tick)
    u32 delayTicks = 60, periodTicks = 0; bool autostart = false; // Timer: one shot after delay; period > 0 repeats
    float keep = 0.5f;                           // Region: level stays on while solid voxels >= keep * initial
    FieldId field = ~0u;                         // GravityWatch, GravityTarget
    std::vector<std::pair<Vec3, float>> presets; // GravityTarget: retarget presets (dir, strength) by index
    std::string op = "and"; std::vector<EventId> inputs; u32 count = 2; u32 delay = 0; // Logic
    std::string spawnKind = "box"; IVec3 spawnSize{16}; u16 spawnMaterial = 0; float spawnImpulse = 0; // Spawner
    std::string effect; float effectScale = 1;   // Effect
    std::string prefabFile; int rotation = 0;    // Prefab
};

struct Connection {
    EventId from = 0; Signal sig = Signal::On;
    EventId to = 0; Command cmd = Command::On; i32 arg = 0;   // arg: preset index, logic input index, 0/1 for Set
    u32 delayTicks = 0;
};

struct PendingDelivery { u32 due; EventId from; u32 seq; EventId to; Command cmd; i32 arg; Signal sig; };

struct Node {
    EventId id = 0;
    NodeDesc d;
    bool level = false, prevLevel = false, enabled = true;
    u32 changedTick = 0;                          // when level last changed
    // per kind state (kept small; everything here is hashed)
    u32 pulseUntil = 0;                           // Button / Timer pulse end, Door blocked flag
    u32 dueTick = 0;                              // Timer
    u32 counter = 0;                              // Logic counter / one_shot fired / Spawner count
    std::vector<u8> inputLevels;                  // Logic
    IVec3 slabAt{0}; i32 target = 0; bool moving = false; u32 blockedTicks = 0, openedTick = 0; // Door: slab offset along travel (0 closed .. |travel| open), direction
    std::vector<VoxelEdit> slab;                  // Door: the slab's voxels relative to box.lo (captured at declaration)
    u32 initialSolid = 0, lastSolid = 0; bool dirty = true; // Region
    std::vector<u32> insideBodies;                // Volume: sorted body ids inside last tick (exit detection for bodies that fell asleep / were removed)
    bool playerInside = false;
    u32 bodyId = 0, prefabId = 0;                 // Spawner's last body, Prefab target's placement
    int luaRef = 0;                               // LuaCallback: the host's registry key (0: none); not hashed
};

struct LampLight { Vec3 posM; Vec3 radiance; float reachM; };

struct EventStats { size_t nodes = 0, connections = 0, pending = 0, signalsThisTick = 0, volumeTests = 0; double ms = 0; };

class EventSystem {
  public:
    EventSystem(World& world, EditQueue& edits, PhysicsWorld& phys, GravitySystem& gravity, const MaterialTable& mats);

    // Declaration (Lua / MCP / app). A name that exists is adopted: the existing node is returned and its desc updated (kind must match; else an error).
    EventId add(const NodeDesc& d, std::string* error = nullptr);
    bool remove(EventId id);
    EventId find(const std::string& name) const;             // 0: none
    bool connect(EventId from, Signal sig, EventId to, Command cmd, i32 arg = 0, u32 delayTicks = 0, std::string* error = nullptr);
    bool disconnect(EventId from, EventId to);
    void setEnabled(EventId id, bool on);

    // Actions (logged by the app): the player pressed what they look at / MCP fired a node. Queued, handled in tick() in id order.
    bool press(EventId id);                                   // Button / Lever only
    bool signal(EventId id, Signal s);                         // any node: inject an edge (MCP `trigger`, Lua `events.fire`)
    bool command(EventId id, Command c, i32 arg = 0);          // direct command (Lua `events.command`)

    // The tick: sources, logic, deliveries, door motion. `player` is the state after this tick's step. Edits go to tick + 1.
    void tick(u32 tick, const Player& player);

    // Queries
    const Node* get(EventId id) const;
    const std::vector<Node>& nodes() const;                    // id order
    const std::vector<Connection>& connections() const;
    const Node* lookAt(const IVec3& cell) const;               // the Button / Lever whose box holds `cell` (HUD hint, `use`)
    std::vector<LampLight> lampLights() const;                 // lamps that are on (the app merges them into the renderer's extra lights)
    EventStats stats() const;

    // Undo / redo / world reload: lamps and doors adopt the voxels (a door's slab is searched along its travel), regions recount.
    void reconcile();
    // Streaming: a node whose box has unloaded chunks is dormant (level frozen, door waits, region holds); re-evaluated when loaded.
    u64 stateHash() const;                                     // every field of every node except luaRef and prompts, plus pending deliveries
    std::string saveState() const;                             // text, one node per line: name kind level slabAt counter dueTick ...
    void loadState(const std::string& text);                   // applied at add() by name (adoption), kept until then

    // Hooks set by the app / Lua host (never called by lower layers)
    std::function<void(EventId node, const std::string& signal, EventId from)> luaCall;   // LuaCallback delivery
    std::function<u32(const NodeDesc&, u32 tick)> spawnBody;                               // Spawner: the app builds the body (buildBoxBody / buildBallBody) and adds it
    std::function<void(const std::string& name, const Vec3& posM, float scale, u32 tick)> playEffect;
    std::function<u32(const std::string& file, const IVec3& origin, int rot, u32 tick)> placePrefab;
    std::function<void(u32 prefabId, u32 tick)> removePrefab;
    std::function<void(EventId, bool levelNow)> onLevelChanged;                            // UI / log

    static constexpr u32 kSourceEvents = kSimulationSourceBase + 0x10;
    u32 budgetVolumeTests = 200000;                            // per tick; above it the remaining volumes keep last tick's level (logged once)

  private:
    void evaluateSources(u32 tick, const Player& player);
    void evaluateLogic(u32 tick);
    void deliver(u32 tick);
    void stepDoors(u32 tick, const Player& player);
    void applyCommand(Node& n, Command c, i32 arg, Signal sig, EventId from, u32 tick);
    bool slabFree(const Node& door, const IVec3& at, const Player& player) const;
    void lampSet(Node& n, bool on, u32 tick);
    void swapLook(const Node& n, bool on, u32 tick);           // Button / Lever / plate look
    // state
    World& world_; EditQueue& edits_; PhysicsWorld& phys_; GravitySystem& gravity_; const MaterialTable& mats_;
    std::vector<Node> nodes_;                                  // index = id - 1 (removed nodes keep a tombstone: ids are never reused)
    std::vector<Connection> conns_;                            // in declaration order
    std::vector<PendingDelivery> pending_;                     // kept sorted by (due, from, seq)
    std::vector<std::pair<EventId, Signal>> injected_;         // press / signal since the last tick, in call order
    std::vector<std::pair<EventId, std::pair<Command, i32>>> injectedCmds_;
    std::unordered_map<std::string, EventId> byName_;          // lookup only, never iterated
    std::unordered_map<u32, std::vector<u32>> bodyTags_;       // body id -> tags (lookup only)
    std::map<std::string, std::string> savedState_;            // from loadState, by name
    u32 seq_ = 0;
    EventStats stats_;
};

} // namespace vx
```

Everything that decides behaviour is in `Node` and `pending_`; `stateHash()` walks `nodes_` in index order and `pending_` in its sorted order (no unordered container is ever iterated for an outcome).

### 2.3 Tick order (inside `EventSystem::tick(tick, player)`)

1. **Injected actions**: `press` / `signal` / `command` calls since the last tick are applied in call order (they come from `applyAction`, which the replay applies in log order before the tick, or from Lua inside `luaTick`, which ran just before). A press sets the button's level for `pressTicks`, toggles a lever; a signal injects an edge for step 4; a command is applied at once.
2. **Sources** in id order: Volume (player capsule: feet .. feet + 1.8 m along `player.up()`, tested as a capsule vs box / sphere; bodies: see 6), Timer (`dueTick`), Region (recount only when `dirty`, set by `noteChangedChunks()` from `sys.changedChunks()` of the previous tick), GravityWatch (compare the field's `desc` to the stored copy), Button / Lever pulses ending. Each level change appends `(tick, id, seq++)` edges to a local list `edges`.
3. **Logic** in id order, one pass: a logic node reads the *current* levels of its inputs (an input with a higher id contributes last tick's level: one tick of latency on back edges, documented; no fixed-point iteration, so no cycle can spin). `delay` holds a level change for `delay` ticks; `counter` turns on at the n-th rising input; `one_shot` emits once until `reset`; `toggle` flips on every rising input.
4. **Deliveries**: for each edge in `edges` order and each connection with matching `(from, sig)` in declaration order: if `delayTicks` is 0 the command is applied now, else a `PendingDelivery` is inserted with `due = tick + delayTicks`. Then every pending delivery with `due <= tick` is applied in `(due, from, seq)` order (deliveries scheduled this tick with delay 0 do not exist: they were applied directly). A command on a target that changes its level appends to `edges` too (so a lamp turning on can trigger the next connection in the same tick), with a cap of 8 generations per tick to bound chains (the ninth generation is deferred to the next tick, logged once).
5. **Doors**: every moving door advances `speed` voxels toward its target if the slab's next position is free (section 4.2); a blocked door stays, counts `blockedTicks`, and with `autoClose` reverses after 30 blocked ticks (elevator behaviour). Auto-close timers are checked here.
6. `stats_` is filled; `signalsThisTick` and `ms` go to the HUD line.

Edits submitted during the tick use `edits_.submit(tick + 1, kSourceEvents, op)`: the same convention as scripts (they flush in the next `sys.tick()`), so a lamp lit on tick T shows its new voxels after tick T+1's flush. Bodies spawned via `spawnBody` are added before this tick's physics step.

### 2.4 Where it sits in the main loop

`tickTail` today: `streamer.tick` -> rain -> prefab polling -> `effects.tick` -> `luaTick()` -> `animated.tick` -> `sys.tick()` -> gravity notify -> LOD -> freeze. Insert `events.noteChangedChunks(sys.changedChunks())` right after `sys.tick()` of the previous tick (i.e. at the top of `tickTail`, before `luaTick`) and `events.tick(sys.tickNumber() + 1, player)` right after `luaTick()`. Reasons: the player's step of this tick is done (volumes see the post-step feet, the same the recorder wrote before any action); Lua `on_tick` ran first, so a script that calls `events.fire` in `on_tick` is handled the same tick; physics has not run yet, so bodies are where last tick left them (one tick of latency, identical in replay); `animated.tick` after it lets a Lua callback `model.play` a thing for this tick; `sys.tick()` after it flushes nothing of ours (ours are for tick + 1) but spawns our bodies into this step.

Session hash: add `mix(events.stateHash())` next to `gravity.stateHash()` in `sessionHash` and the `hashprobe` line.

### 2.5 Tags on bodies

Bodies have no gameplay identity beyond id and material. `events.tag(bodyId, "key")` stores a small tag list per body id in the event system (`bodyTags_`), `VolumeFilter::tags` matches it. A body that is removed (welded, undone, carved away) drops its tags when the volume code finds no body with that id (lazy). Tags are part of the hash (sorted by body id when hashing).

## 3. Sources in detail

**Button / Lever.** A box of voxels in the world (the author builds it: a 4 x 4 x 1 metal plate on a wall). Pressing: the app's `use` key path raycasts the view (`raycastWorld`, reach 3.5 m = 56 voxels) and asks `events.lookAt(h.cell)`; a hit produces the action `use <id>` (logged with the id, never with the direction: a replay must not re-raycast). `applyAction("use")` calls `events.press(id)`. Script / MCP: `events.fire(id)` in Lua (inside a logged Lua call or a script tick: recomputed), MCP `trigger` (an action). Look: while the level is on the voxels of the box that are `matOff` are painted `matOn` (`EditOp::box(box, matOn, PaintSolid)` with `onlyMaterial = matOff`), and back when the pulse ends; a lever stays. A box whose voxels are gone (blasted) still works as a trigger volume for `use` only if at least one voxel remains in it; else `lookAt` cannot find it and the HUD shows nothing: a destroyed button is a dead button (desired).

**Volume.** Box (voxels) or sphere (metres). Level = player inside (capsule overlap) or any body passing the filter overlaps (its `aabbMin/aabbMax`, the sweep-and-prune AABB, is cheap and conservative; an exact OBB test is not needed for plates). Enter / exit edges from level changes; `stay` every tick while on. Bodies: per tick the volume walks the candidates (section 6) and rebuilds `insideBodies` (sorted ids); the player and the bodies are separate contributions, the level is their OR. A body that falls asleep inside stays inside (it is still tested: sleeping bodies are not skipped, see 6).

**Timer.** `start` sets `dueTick = tick + delayTicks` (a `period` restarts it on firing); `stop` clears; `reset` = stop + start. `autostart` starts at declaration (adoption restores the remaining time from the saved state: `dueTick - tick` is saved, not the absolute tick).

**Region.** On declaration count the solid voxels of the box (`World::getVoxel`, unknown cells counted as solid and the node marked dormant while any chunk is unloaded); level = `count >= keep * initial`. Recount when a changed chunk overlaps the box (from `noteChangedChunks`), so a quiet region costs nothing. "When this wall is blown up" = `destroyed` (an `off` edge).

**GravityWatch.** Stores the field's `FieldDesc` (dir, strength, enabled, pos); a difference emits `pulse` (= `changed`) and the enabled edges. Cheap (one struct compare per tick).

**Logic.** `inputs` are node ids; input levels are read directly from those nodes (no connection needed), or set by a `Set` command from a connection (for wiring a far signal). `and / or / xor / not` over the levels; `toggle` (flip on each rising input), `one_shot`, `counter n`, `delay n`.

## 4. Targets in detail

### 4.1 Lamp

A lamp is a box of voxels with two materials: `matOff` (dark glass, e.g. a new `lantern_off` row in the material CSV: same albedo, emissive 0) and `matOn` (the existing `lantern`, emissive). `on`: `EditOp::box(box, matOn, PaintSolid, onlyMaterial = matOff)` at tick + 1; `off`: the reverse. The GPU shows the voxel glow as soon as the brick uploads (one frame), the GI probes converge within about two seconds (118 frames after round 9), and while the lamp is on `lampLights()` lists it as a CPU point light (`radiance`, `reachM`) that `gatherEmissive` merges into `Renderer::setEmissiveLights` so the ambient reacts reliably and not by probe-ray chance. Budget: the extra-light list is 256 entries shared with fire and lava; the app takes lamps nearest to the player first and fire / lava after (cosmetic choice, not state). A lamp whose voxels were blasted away stays "on" logically (its state is not the voxels) but `reconcile()` after undo marks the voxel part absent; the point light follows the state, so a broken lantern still lights: acceptable in phase 1, phase 2 can tie the light to "at least one lamp voxel left" (a Region check on its own box).

Trap: there are no per-instance emissive intensities (the material row carries them), so brightness levels need more material rows (`lantern_dim`). Fine for buttons and lamps; a dimmer needs a material per step.

### 4.2 Door

Declaration captures the slab: the solid voxels in `box` (relative to `box.lo`, with their values) at declaration time; the open position is `box + travel` and the pocket (the union of every intermediate slab position) must be air or the door's own slab, which `add()` verifies and reports (`"door 'gate': the pocket holds 48 foreign voxels"`), as a warning, not a refusal. Closed: `slabAt = 0`; open: `slabAt = |travel|` (travel is axis-aligned, one axis non-zero, so positions are integers along it). Moving: each tick `step = min(speed, remaining)`; the next position `p' = p + dir * step`; if `slabFree(p')` then submit two ops for tick + 1: `EditOp::setVoxels(oldCells -> air, mode ClearIfEqual with each voxel's own value)` and `EditOp::setVoxels(newCells -> values, Replace)` in that order (same source, consecutive seq, so the clear applies first). `speed = 0` moves in one step. `slabFree`: no body AABB (dynamic or kinematic, awake or asleep) overlaps the slab's new voxels' bounds except where the body is the door's own... doors have no bodies; and the player capsule does not overlap the new bounds (capsule vs AABB, using `Player::kRadius` and the four sphere centres). While blocked: `blockedTicks++`, emit `pulse` (`blocked`) once per block, keep trying every tick; with `autoClose` a close that stays blocked 30 ticks reverses to open.

What stands in the doorway therefore never gets crushed or embedded: the door waits. A sliding door hits nothing; a rising portcullis under a crate waits until the crate is pushed off.

Structural analysis: every step is a flush with removed voxels, so the connectivity analyzer runs a bounded search from the cleared cells each step; a door slab touching its frame is anchored, the frame is unchanged, so the search ends at the first anchored neighbour. Cost per step is well under a millisecond; a 32-voxel travel at speed 2 is 16 steps over 16 ticks. Things resting on a door that opens fall (correct). The LOD updater sees the chunk as edited (correct). The door's voxels are *not* journaled as a user action (system source), see section 7.

Phase 2 can add a swing door as a model with 24-rotation steps (quarter turns only) using the same slab mechanism with a rotation per step; a smooth swing needs player-vs-body collision (section 10).

### 4.3 GravityTarget

`enable` / `disable` -> `GravitySystem::setEnabled`; `retarget k` -> `setUniform(field, presets[k].dir, presets[k].strength)` (uniform fields; for others `update` with the preset applied to `dir` and `strength`). The field's version bump wakes sleepers as today. The flip room's switch becomes: a Lever node on the neon switch voxels connected to a GravityTarget with presets `{down}`, `{up}`; `toggleRoom` stays for the G key / `flip` action for compatibility.

### 4.4 Spawner, Effect, Prefab, LuaCallback

Spawner: `spawn` -> `spawnBody(desc, tick)` (the app builds a box / ball body of `spawnMaterial` at `centreM`, `owned = true`, optional upward impulse) and remembers the id (`bodyId`) and `counter`. Effect: `play` -> `playEffect(name, centreM, scale, tick)` (cosmetic, like `fx.play`, excluded from the hash by nature). Prefab: `place` / `remove` through the app's `PrefabSystem` with the normal `beginAction` grouping (it is a user-visible structural change; it keeps its own id). LuaCallback: `call` -> `luaCall(node, signalName, from)`; the Lua host looks up the function stored for the node (a registry ref), calls it as a protected call under the instruction limit, logs errors with the line and continues with the next delivery (one failing callback never stops the dispatch). Callbacks are dropped on a script hot reload, exactly like timers; `on_reload()` re-registers them.

## 5. Authoring

### 5.1 Lua API (`events.*`, bound in `lua_host.cpp`; `ScriptEnv` gets `EventSystem* events`)

```lua
id = events.button{ name = "lamp_button", box = {x0, y0, z0, x1, y1, z1}, prompt = "Light the lantern", on = "metal_lit", off = "metal", press_ticks = 20 }
id = events.lever{ name = ..., box = {...}, prompt = ..., on = ..., off = ... }
id = events.volume{ name = "plate_a", box = {...}, player = true, bodies = true, material = "wood", min_mass = 100, tags = {"key"} }
id = events.volume{ name = "glade", sphere = {x, y, z, r} }                 -- metres
id = events.timer{ name = "fuse", delay = 120, period = 0, autostart = false }
id = events.region{ name = "west_wall", box = {...}, keep = 0.5 }
id = events.gravity_watch{ name = "room_watch", field = flip }
id = events.logic{ name = "both", op = "and", inputs = {plate_a, plate_b} }  -- ops: and or xor not toggle one_shot counter delay (count = n / delay = ticks)
id = events.lamp{ name = "lantern_1", box = {...}, on = "lantern", off = "lantern_off", radiance = {1.0, 0.8, 0.5}, reach = 8 }
id = events.door{ name = "gate", box = {...}, travel = {0, 40, 0}, speed = 2, auto_close = false }
id = events.gravity_target{ name = "room_field", field = flip, presets = { {{0,-1,0}, 9.81}, {{0,1,0}, 9.81} } }
id = events.spawner{ name = "crate_drop", pos = {x, y, z}, kind = "box", size = {16, 16, 16}, material = "wood", impulse = 0 }
id = events.effect{ name = "pop", effect = "sparks", pos = {x, y, z}, scale = 1 }
id = events.prefab_target{ name = "bridge", file = "models/bridge.vxm", pos = {x, y, z}, rotation = 0 }
events.connect(from, "on", to, "open")                 -- signal: on off pulse stay (+ aliases pressed enter exit fired destroyed changed opened closed blocked)
events.connect(from, "off", to, "close", { delay = 30 })
events.connect(from, "on", to, "retarget", { arg = 1 })
events.on(id, "on", function(ev) ... end)              -- ev = { id, name, signal, from, tick }; a LuaCallback node is created implicitly
events.fire(id [, "on"])                               -- inject an edge (recomputed in a replay: it runs inside a script tick or a logged Lua action)
events.command(id, "open")                             -- direct command
events.state(id)      --> { name, kind, level, enabled, ... kind fields: open, moving, remaining, count, due_in }
events.find("gate")   --> id or 0       events.remove(id)     events.enable(id, false)      events.tag(body_id, "key")
```
Units follow the rest of the API: boxes in voxels, positions of spheres / spawners / effects in metres, times in ticks.

Example 1, a lantern post lit by a button:
```lua
function on_start()
    local x, y, z = world.flat_spot(6, 6)
    edit.box(x + 20, y, z + 20, x + 22, y + 50, z + 22, "metal")              -- the post
    edit.box(x + 18, y + 51, z + 18, x + 24, y + 57, z + 24, "lantern_off")   -- the lantern, dark
    edit.box(x + 40, y + 16, z + 20, x + 43, y + 19, z + 21, "metal")         -- a button plate on a plinth
    local lamp = events.lamp{ name = "post_lamp", box = {x + 18, y + 51, z + 18, x + 24, y + 57, z + 24}, on = "lantern", off = "lantern_off", radiance = {1, 0.8, 0.5} }
    local btn  = events.button{ name = "post_button", box = {x + 40, y + 16, z + 20, x + 43, y + 19, z + 21}, prompt = "Light the lantern", on = "metal_lit", off = "metal" }
    events.connect(btn, "pressed", lamp, "toggle")
end
```
Example 2, a door opened by a pressure plate (and closed when the plate is left, 1 s later):
```lua
function on_start()
    local x, y, z = world.flat_spot(10, 10)
    edit.box(x, y, z + 60, x + 100, y + 60, z + 64, "brick")                  -- a wall
    edit.clear(x + 40, y, z + 60, x + 59, y + 39, z + 64)                     -- the doorway
    edit.clear(x + 40, y + 40, z + 60, x + 59, y + 79, z + 64)                -- the pocket above it (air inside the wall / lintel)
    edit.box(x + 40, y, z + 60, x + 59, y + 39, z + 64, "metal")              -- the door slab, closed
    edit.box(x + 44, y, z + 30, x + 55, y, z + 41, "brick")                   -- the plate
    local door  = events.door{ name = "gate", box = {x + 40, y, z + 60, x + 59, y + 39, z + 64}, travel = {0, 40, 0}, speed = 2 }
    local plate = events.volume{ name = "gate_plate", box = {x + 44, y, z + 30, x + 55, y + 8, z + 41}, player = true, bodies = true, min_mass = 50 }
    events.connect(plate, "enter", door, "open")
    events.connect(plate, "exit", door, "close", { delay = 60 })
end
```
Example 3, an AND of two plates opens a vault and plays an effect:
```lua
function on_start()
    local a = events.volume{ name = "plate_a", box = {...}, player = true, bodies = true }
    local b = events.volume{ name = "plate_b", box = {...}, player = true, bodies = true }
    local both = events.logic{ name = "both_plates", op = "and", inputs = {a, b} }
    local vault = events.door{ name = "vault", box = {...}, travel = {-48, 0, 0}, speed = 3 }
    local fx = events.effect{ name = "vault_fx", effect = "sparks", pos = {vx, vy, vz} }
    events.connect(both, "on", vault, "open")
    events.connect(both, "on", fx, "play")
    events.on(both, "off", function(ev) print("plate released at tick " .. ev.tick) end)
end
```

### 5.2 Keys and HUD

The use key is **E** in walk mode when the player is not swimming and `lookAt` finds a button within reach; otherwise E keeps its lift meaning (fly / swim). The hint is a HUD line at the crosshair: `[E] Light the lantern` (the app renders it through the existing HUD line list; `fp.crosshair` stays as is). While a button is in its pressed pulse the hint shows `[E] Light the lantern  (pressed)`. The ScriptDriver gets the tokens `use` (press what is aimed at, like `dig`) and `use:ID`; `--script list` and `docs/SCRIPT.md` document them.

### 5.3 Editor / UI (optional, phase 2)

A "Events" panel in `tool_ui`: the node list with kind, level, enabled, a Press / Fire button per node (through `act("trigger", ...)`: logged), the connections as `from.signal -> to.command (+delay)`, and the pending deliveries with their due tick. Gizmos: node boxes in the debug overlay (`--overlay events`): green level on, grey off, blue doors with the slab's position.

### 5.4 MCP

| tool | |
|---|---|
| `events {}` | the nodes (id, name, kind, level, enabled, state fields) and connections; `pending` deliveries with due ticks |
| `trigger {id or name, signal = "on"}` | an action `trigger <id> <sig>` (logged): injects the edge; for a button it is a press |
| `event_command {id, command, arg}` | an action `event_cmd <id> <cmd> <arg>` (logged) |
| `status` | `sim.events = {nodes, pending, signals_last_tick}` |
| `describe` | adds "a button 'post_button' 2.1 m ahead (trigger it with run_script use)" when `lookAt` hits within reach |
| `step_until {condition = "event:<name>:on"}` | run until a node's level becomes on / off (deterministic, cheap) |

### 5.5 What is saved and hashed

- The **level script** declares the nodes on every run (`on_start`); `add()` adopts by name. Declaring with a different kind under an existing name is an error in the log.
- **State file** `<project>/.events/state.txt` (written by `saveAll` next to the prefab state; read at start into `savedState_`, applied at `add()` by name): per node `name kind level enabled slabAt moving target counter dueIn pulseLeft initialSolid`. A door adopts `slabAt` only if the voxels agree (the slab is found by scanning the travel range for its voxels; the world wins on disagreement, logged). Not read or written in MCP sessions without `--save`, like the prefab registry.
- **Recordings**: the recorder copies `state.txt` to `<log>.clip/events_0.txt` and the replay reads that copy (the same path as `store_0.vxs`); `use` / `trigger` / `event_cmd` are logged actions with the resolved ids.
- **Session hash**: `events.stateHash()` (node states, pending deliveries, tags). Lua callback functions, prompts and names are not hashed.

## 6. Performance

Budget: 0.2 ms per tick for 500 nodes (`Gameplay` stage, printed in the HUD events line and in `EventStats::ms`).

- Volumes vs the player: one capsule test per volume: nothing.
- Volumes vs bodies: candidates are **every body whose AABB overlaps the volume**, found with a uniform grid the event system builds once per tick from `phys.bodies()` (cell 8 m, `aabbMin / aabbMax` already maintained by the broadphase; building the grid is one pass over the bodies, about 10 µs per 1,000 bodies). Sleeping bodies are included (a crate asleep on a plate keeps it pressed; the exit of a removed body is detected by `insideBodies` ids that no longer exist). Cost: volumes x bodies in their cells; 200 plates with a 500-body pile on one of them is 500 AABB tests. `budgetVolumeTests` caps a pathological tick (every volume keeps last tick's level beyond it, logged once per session): deterministic because the cap is a count.
- Regions: recount only on overlap with changed chunks; a 64^3 box is 262 k `getVoxel` reads (about 1 ms single-threaded): regions larger than 32^3 use `World::forEachBrick`-style counting per brick mask (phase 2); phase 1 limits a region to 2^18 voxels (`add()` refuses more).
- Doors: one `slabFree` per moving door per tick (bodies from the same grid, one capsule test) plus two edit ops.
- Lamps: one op per change; the point light list is rebuilt per frame by the app from `lampLights()` (on lamps only; it walks the nodes, 500 is nothing).
- Memory: a node is about 300 bytes plus the door slab (voxel list, a 20 x 40 x 5 door is 4,000 entries x 16 bytes = 64 KB; cap 2^16 voxels per door).

## 7. Interaction with undo, the journal, streaming and the action layer (traps)

1. **Journal groups.** `sys.beginAction()` opens an undo group for every user action and every flushed batch joins the newest group. Event edits (lamps, doors, button looks) use `kSourceEvents >= kSimulationSourceBase`, which makes their transactions `system` ones (they do not clear the redo stack, like welds). They still land in the open group: undoing the player's last dig also takes back the door motion that followed it. That is the engine's rule ("everything the action triggered undoes together") and it is consistent as long as the node state follows the voxels: `EventSystem::reconcile()` is called from `doUndoRedo` (after `prefabs.reconcile()`): a lamp reads whether its box holds `matOn` or `matOff`, a door searches its slab along the travel and sets `slabAt` / `moving` from it, a region recounts, buttons and levers read their look. The prefab system already has this pattern.
2. **Undo removes spawned bodies** (`txnBodies_`) only for bodies born from journal transactions; a spawner's body is `owned` and not tied to a transaction, so undo leaves it. Document; phase 2 can register spawner bodies with the open group through a new `DestructionSystem::adoptBody(txn, id)`.
3. **The Action layer** is a string `if` chain in `applyAction` with positional doubles; events add `use`, `trigger`, `event_cmd`. Log the resolved **node id** and the signal / command as small integers (the `flip` / `doll` lesson: never log what has to be re-resolved from the player's view). The "Action registry struct" left open since round 4 would be the right moment: a table of `{kind, arity, handler}` that the recorder, the replay, the ScriptDriver and MCP share; at least put the three new kinds in one place.
4. **Streaming.** A node whose box touches an unloaded chunk is **dormant**: a region holds its level, a door does not move (its ops would be deferred and applied with no occupancy check when the column streams in: refuse to move instead), a lamp still submits its op (deferred, fine: the voxels catch up). Volumes do not depend on residency (the player and bodies are always known; far bodies are frozen by `freezeOutside`). Residency is tick-driven in lockstep mode and timing-driven in plain live play, so a dormant door in live play is as nondeterministic as the live streaming itself; recorded sessions are exact.
5. **Lua callbacks and hot reload.** Function values captured at declaration belong to the old chunk; drop them on reload like timers and say so in LUA_API.md (`on_reload` re-registers with `events.on`). The instruction limit covers a callback (it is a call into Lua); a runaway callback is stopped with the usual error line.
6. **MCP `lua` calls** that declare nodes are logged as `lua` actions with their text, so a replay re-declares them; a node declared by an ad-hoc call and pressed by `trigger` replays. Node ids are sequential in declaration order, so a replay gets the same ids as long as the declarations happen in the same order (they do: scripts and actions are both tick-ordered).
7. **Lamp light vs GI.** The emissive voxel is the real light; the probe ray finds it by chance within 30 m, the CPU point light makes it reliable. Both are cosmetic; the hash does not care. The 256-entry cap is shared: with 300 lamps on, far ones are not point-lit (nearest first, per frame).
8. **Bodies and the player.** The player collides with voxels only (`WorldProbe`), so any door that is a body (kinematic part, animated model) lets the player walk through it. Voxel doors in phase 1; a `WorldProbe` that includes kinematic bodies is the enabling change for model doors and moving platforms (phase 3, physics work).
9. **Edits beyond limits.** `EditQueue::submit` refuses absurd ops; door and lamp boxes are validated at `add()` (`kMaxEditExtent`, voxel caps) so the system never submits something the queue drops silently.
10. **Pool exhaustion.** A door op that cannot allocate is dropped by the flush with a warning (existing behaviour); the door would then believe it moved. `stepDoors` verifies on the next tick that the previous step's voxels are in place (read one voxel of the slab) before taking the next step; a mismatch sets `moving = false` and logs once, `reconcile()` recovers it.

## 8. Files and module placement

| file | layer | content |
|---|---|---|
| `src/sim/event_system.hpp/.cpp` | sim (`vx_sim`) | everything in section 2; depends on `world/edit.hpp`, `world/world.hpp`, `physics/physics_world.hpp`, `gravity/gravity_system.hpp`, `sim/player.hpp` |
| `src/sim/event_state.hpp/.cpp` | sim | `saveState` / `loadState` text format (kept out of the system file for testability) |
| `src/script/lua_host.cpp` | tools | `events.*` bindings, `ScriptEnv::events`, callback registry (sol refs by node id), dropped on reload |
| `src/app/main.cpp` | app | construction, `tickTail` call, actions `use` / `trigger` / `event_cmd`, the E key, HUD hint, `lampLights` -> `gatherEmissive`, `reconcile` in `doUndoRedo`, `saveAll` writes the state, recorder copies it, `sessionHash` mix, MCP tools, ScriptDriver tokens |
| `src/app/script.hpp` | app | `use`, `use:ID` tokens (`Host::use`) |
| `src/app/replay.cpp` | app | nothing new (actions are generic); `events_0.txt` copy in the clip dir |
| `src/app/tool_ui.*` | tools | phase 2 panel |
| `docs/EVENTS.md`, `docs/LUA_API.md`, `docs/MCP.md`, `docs/SCRIPT.md` | docs | this document, the API table, the tools, the tokens |
| `projects/demo_level/level.lua`, `projects/lantern_cove/level.lua` | content | a lamp button at the start, a plate door on the quay |
| `materials.csv` (built-in table) | content | `lantern_off`, `metal_lit` rows (ids in the free range) |

The dependency direction holds: sim never includes app or render; the app passes callbacks for prefabs, effects, bodies and Lua.

## 9. Phases

**Phase 1 (minimal, one commit per bullet):**
1. `EventSystem` with Button, Lever, Volume (player + bodies, box and sphere), Lamp, Door; connections without delay; `tick`, `reconcile`, `stateHash`, `lookAt`, `lampLights`. Unit tests (section 10, tests 1-8).
2. Main loop wiring: `tickTail` call, hash, undo reconcile, HUD hint, E key, actions `use` / `trigger`, ScriptDriver `use`, recorder state copy, `saveAll` state file. Determinism script case.
3. Lua bindings (`events.button / lever / volume / lamp / door / connect / on / fire / state / find / tag`), callbacks dropped on reload, docs.
4. MCP tools `events`, `trigger`, `status.sim.events`, `describe` hint, smoke test.
5. Demo content: the lantern button in `demo_level`, the quay door in `lantern_cove`; `lantern_off` / `metal_lit` materials.

**Phase 2:** Timer, Region, GravityWatch, Logic (all ops), GravityTarget (the flip switch becomes a lever), Spawner, Effect, Prefab targets, delays on connections, `stay`, auto-close, `event_command`, `step_until event:`, the UI panel and the overlay, the per-brick region count, spawner bodies in undo groups.

**Phase 3 (needs physics work):** player vs kinematic bodies in `WorldProbe` (moving platforms, swing doors as animated models), volume filters by body tag set from fracture (pieces inherit tags), damage sources (a Region with per-material thresholds).

## 10. Test plan

Unit (`tests/test_events.cpp`, `vx_tests`, no GPU; a World + EditQueue + PhysicsWorld + GravitySystem + Player like `test_gravity.cpp` builds them; flushing through `EditQueue::flush` directly, the destruction system is not needed):
1. Button -> lamp: declare both, `press`, `tick`, flush tick + 1: the lamp box holds `matOn`; press again: `matOff`. The button's look swaps for `pressTicks` and back.
2. Volume enter / exit / stay with the player: feet moved into the box, one `on` edge, `stay` each tick, one `off` on leaving; a body (`buildBoxBody`) dropped into a plate: `on`; removed: `off`; filters: material, min mass, tag.
3. Door open / close: 16 steps at speed 2 (the slab's voxels at the expected cells after each flush, nothing else changed in the pocket); speed 0 instant; `close` while a crate body sits in the doorway: blocked (`pulse`), no edit submitted, the crate removed: closes; the player in the doorway: blocked.
4. Order: two volumes (ids 1 and 2) entered in the same tick deliver to one lamp with `toggle` twice: the lamp ends off; swapping the declaration order changes nothing about the outcome but the logged edge order is (1, 2) (checked through `onLevelChanged`).
5. Logic: and / or / not / xor / toggle / one_shot / counter / delay with scripted input levels; the back-edge latency (input id > logic id sees last tick's level) asserted explicitly.
6. Timer: delay, period, stop, reset; the saved `dueIn` restores after `saveState` / `loadState`.
7. Region: a wall counted, a blast's carve flushed, `noteChangedChunks`, `off` below `keep`; a region with an unloaded chunk is dormant (World::residency stub as in `test_particle_settle.cpp`).
8. Reconcile: open a door, undo the flush with a `Journal` (`EditQueue::flush(world, jobs, &journal)` then `journal.undo`), `reconcile()`: `slabAt == 0`; lamp likewise.
9. Hash: `stateHash()` differs after a press, equals after `saveState` / `loadState` round trip, is independent of names / prompts / callback refs.
10. Budget: 500 volumes and 1,000 sleeping bodies in a pile: `stats().ms < 0.5` (release only, like the other timing tests, with a generous ceiling).

Determinism (`tools/determinism.sh`, a new scripted case `events`): the demo level with the lantern button and a plate door; script `tp:1,idle:30,turn:..,fwd:..,use,idle:120,fwd:..,idle:200,use,idle:60`; recorded on 6 threads, replayed on 1 and 3, same end hash; a second run of the recording with `--setting quality=low` identical (the GPU does not matter).

MCP (`tools/mcp_smoke.py`): `events` lists the demo's nodes; `trigger post_button` then `step 3` and `count_voxels` of the lantern box by material `lantern` = the box's voxel count; `status.sim.events.pending == 0`; a recorded session with `trigger` replays to the same `state_hash`; `trigger` with an unknown name is -32602.

GPU (optional, `tests_gpu`): a lit lantern lights a closed room's floor more than the unlit one (the same shape as the lava-room GI test), with the point light on and off.

## 11. Open questions for the implementer (decide, then write the choice into docs/EVENTS.md)

- Whether `stay` should be rate-limited (every tick is 60 deliveries per second into Lua; a `stay_every = n` on the volume is cheap to add).
- Whether buttons should be pressable through glass (the raycast stops at glass today: `raycastWorld` has no see-through mode); probably not.
- The E key conflict in fly mode (E is lift): the hint shows only in walk mode, which settles it for phase 1.
- Whether a door should push a sleeping crate instead of waiting (a `push = true` option that applies an impulse along `travel` to blocking bodies, through `phys.applyImpulse`): nice for portcullises, phase 2.

## Authoring (2026-10-21)
Nodes and connections can be made without Lua. An **authored** node is a normal node whose description is kept as text in the project's `events.json` (written at every save: F11, the autosave, the exit save; removed when the last one is deleted) and declared again at every start, **before** the script's `on_start`, so a script can `events.find` it. A node the script makes is not authored (`authored: true` in the `events` tool marks the others); deleting one of those only lasts for the session.
- **Text form** (`app/event_json.*`, the keys follow the Lua calls): `{kind, name, ...}` with `kind` button, lever, volume, timer, logic, lamp, door, gravity_target, spawner, effect, emitter or **belt** (`dir`, `speed`, `texture`, `lit`: docs/CONVEYOR.md); `box` is `[x0, y0, z0, x1, y1, z1]` in voxels (inclusive); materials are names; a logic node's `inputs` are node names; a gravity target's `field` is a field's name or id. A connection is `{from, signal, to, command, arg?, delay?}` by names. Everything is range-checked and all-or-nothing; `EventSystem::pairFits` says which commands a target takes (a lamp: on / off / toggle, a door: open / close / toggle / stop ...).
- **Actions** (logged, so a replay and a networked session do the same): `event_define` (text: the node JSON; a name that exists is changed), `event_delete` (the name), `event_connect` (the connection JSON), `event_disconnect` (`{from, to}`). A recording keeps a copy of `events.json` (`authored_events_0.json`), a replay reads that copy and never writes the project's file.
- **MCP**: `event_create`, `event_set` (only the keys given change), `event_delete`, `event_connect`, `event_disconnect`; `events` lists nodes (with `authored`) and connections (`arg`, `delay_ticks`). Example: `event_create {kind: "button", name: "plate", box: [100, 32, 100, 103, 33, 101], on: "neon", off: "metal"}`, `event_create {kind: "door", name: "gate", box: [130, 32, 100, 133, 40, 101], material: "wood", travel: [0, 9, 0]}`, `event_connect {from: "plate", signal: "on", to: "gate", command: "open"}`.
- **Editor**: the **Events** window (menu bar). *Nodes*: the list, "select its box" (the editor's selection becomes the node's box, so the handles resize it and `event_set` can write it back), "trigger", "delete", and **new node**: a kind, a name, the selection as the box (door: slide direction and length, slab material, close again; lamp: the materials and the reach; timer: the delay; logic: the op), spawners and effects at the camera. *Connections*: the list with remove, and from / signal / to / command / delay / number to connect (a pair that does not fit is refused with the reason). *Graph*: sources, logic and targets in three columns with a line per connection. With the window open the boxes of the nodes are drawn in the world (sources orange, targets blue, the picked one white).
- The conveyor belt is the *pusher* node: kind `belt` (docs/CONVEYOR.md), commands on / off / toggle / reverse.
- Not built: region / gravity-watch nodes, a door from a model or a prefab part (made by a prefab manifest), clicking a node in the 3D view, dragging links in the graph, a gravity target whose field is made later than the first pass (it is retried once after `on_start`).
