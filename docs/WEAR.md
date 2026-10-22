# Wear: paths, tracks, trodden snow (setting `wear`, `tracks`)

Walking, driving and lying on the ground changes it. This is the **simulation** side of a path (the render side, the grass that bends under a foot, is `docs/FOLIAGE.md` "Paths" and is always on): when a
cell of ground has been trodden enough, its voxels really change (grass to a path material), and the walkers carry dirt that they leave as prints on hard floors. Design: `docs/WORLD_WEAR_DESIGN.md` (Fable,
2026-10-22).

**Off by default.** A game that wants it says so in `project.cfg` (or `--setting` for a test):

```
wear = on            # the built-in table (below); or  wear = wear.csv  (a table next to project.cfg); or  wear = off
tracks = on          # walkers pick dirt up and leave it as prints on hard floors (needs wear)
wear_rate = 1         # also track_fade, track_distance: multipliers, see "Tuning" below
```
`--setting wear=on|off|file.csv` and `--setting tracks=on|off` override the project; `--setting wear_cells=N` changes the cap of the map of worn cells. With `wear` off nothing below happens, the hash and
the saves are what they were. These are gameplay switches, so they are never written to a person's `settings.ini`.

## What it does
- **Stamps.** Each tick the game stamps the ground under every walker that is on the ground and moving: the players (by slot), the agents (by id) and the awake bodies in contact with the world and faster
  than 0.2 m/s (a vehicle's wheels and chassis are bodies, so a truck wears like a heavy body). A stamp counts 1 at the middle of a foot and less toward its edge (`radius` metres of the row), heavier
  bodies count more (up to three).
- **Cells.** The counters are per cell of 2 x 2 voxels (12.5 cm, the cover's cell), in one ordered map (at most 65,536 cells: a full map first sweeps out the cells that are nearly nothing, then drops the
  stamp; at most 256 stamps and 64 changed voxels a tick; the rest waits its turn in key order).
- **The change.** A cell that reached its `threshold` stamps changes the top solid voxel of each of its (up to four) columns: `to = <material>` swaps the material (the paint and the texture of the voxel
  stay); `to = sink` removes the voxel (snow that is trodden down, one voxel per `threshold` stamps). Nothing grows on a material that has no cover type, so a path loses its blades and its far tint at
  once (a **painted** foliage type would still grow there: `@bare,path` in `foliage.csv` says that a path is bare ground).
- **Decay and regrowth.** A cell nobody steps on loses `decay` stamps a second and is forgotten at 0. A changed cell goes back (`regrow_to`, default the `from` material) `regrow` ticks after its last
  stamp. While it snows (`fx.snow(amount, true)` or the `snow` action with `falling`) a sunk snow cell (`falling_refill = 1`) gets a voxel back every `threshold` ticks.
- **Tracks** (`tracks = on`). A walker carries a load (mud, snow, sand, 0..1). Walking on a surface with `pickup` gives load (dirt always, snow and sand always, mud from other ground only while it is wet:
  the system counts the rain itself, it rises in 6 s and dries over a minute); walking on a surface with `deposit` leaves a print there and uses up `deposit` of the load as a share (0.06: the load is 0.94 after one print, 0.08 after about 40, then it is empty: about 17 m of tracks from a full load). A print gets **sparser and lighter
  as the load falls**, like dirt falling off the foot: the share of its voxels that are painted is `load^0.6` (a fixed dither, the same on a replay; no print below 0.08 load) and `track` may list several colours (`dark_brown;brown;light_brown`, the fullest load first). The print
  is a **paint colour on the top voxel** (docs/PAINT.md: the state byte, so it is in the hash, the save, the replay and the renderer for free): a foot is an ellipse of 5 x 8 voxels along the heading, a wheel
  or a body a disc of 3. It remembers the paint it covered and **fades back** after `fade` ticks, `wash` times faster while it rains. The ring holds 32,768 painted voxels; when it is full the oldest print
  goes back first. A voxel somebody painted since is left alone when its track fades.
- **Cleaning.** `wear_clean` (action, MCP tool, Lua `wear.clean(x0, z0, x1, z1)` in metres): the tracks in the box go back at once and the worn cells in it are forgotten. The voxels that already changed stay
  (a path that is dirt stays dirt until it regrows).

## The table (`wear.csv`)
```
# from, to, who, radius, threshold, decay, regrow, regrow_to, falling_refill, pickup, deposit, track, fade, wash
grass,  dirt, players;agents;vehicles;bodies, 0.20, 60,  0.02, 36000, grass, 0, 0.0, 0.0, none,       0,    1
snow,   sink, players;agents;vehicles;bodies, 0.25, 6,   0.00, 0,     ,      1, 0.8, 0.0, none,       0,    1
dirt,   ,     ,                               0,    0,   0,    0,     ,      0, 0.6, 0.0, none,       0,    1
concrete, ,   ,                               0,    0,   0,    0,     ,      0, 0.0, 0.06, dark_brown;brown;light_brown, 18000, 8
```
That is the built-in table (`wear = on`). One row per surface material (`from` = the top solid voxel under the walker); trailing columns may be left out. `who` is a `;` list of `players`, `agents`,
`vehicles`, `bodies` (empty: the row only picks up and deposits); `to` is a material name, `sink`, or empty; `radius` metres; `threshold` stamps (for a refill: ticks per voxel); `decay` stamps a second;
`regrow` ticks (0: never); `pickup` / `deposit` 0..1 per step; `deposit` the share of the load one step leaves; `track` a paint colour (a name like `dark_brown`, docs/PAINT.md) or several joined by `;`, fullest load first; `fade` ticks (60 a second; the built-in table: 5 minutes); `wash` the factor while it rains. A row with a material the
project does not have is reported and skipped (`voxelith --check-project dir` and the log say so). A project makes its own path material in `materials.csv` (the Lantern Cove has `path`; there is no
built-in one, so that no saved world's material ids move); the built-in table turns grass into dirt, which in a project whose foliage table grows ferns on dirt is not a bare path: give the project its own
`wear.csv`. Ranges are checked (`wearColumns()` in `src/sim/wear_table.cpp`).

## Tuning: how hard, how long, how far
Every row has its own numbers (`threshold` is how many stamps turn a cell, about 60 for one foot to wear a spot in a minute of standing there; `deposit`, `fade`), and three multipliers tune the whole table without editing the rows:

| | `@line` in wear.csv | project.cfg | `--setting` | meaning |
|---|---|---|---|---|
| `rate` 0.05..20 | `@rate 1.5` | `wear_rate = 1.5` | `wear_rate=1.5` | every stamp counts that many times: 2 turns grass to path in half the steps, 0.5 needs twice as many |
| `fade` 0.05..20 | `@fade 2` | `track_fade = 2` | `track_fade=2` | tracks stay that many times as long (`fade` of every row) |
| `distance` 0.1..20 | `@distance 2` | `track_distance = 2` | `track_distance=2` | a walker's tracks reach that many times as far (a step uses up `deposit / distance` of the load) |

The project and the setting override the table's `@` lines (the setting wins), and none of them is kept in a person's settings file. A recording writes the result as `@` lines at the end of its copy of the table, the table's hash includes them (so peers and replays must agree), `wear_info` shows them.

## State, saving, replay, net
- **Deterministic**: the inputs are simulated positions (never the live local player in a networked session), integer cell keys in an ordered map, fixed visiting orders and caps, the tick instead of a
  clock. The hash (`WearSystem::stateHash`) is mixed into the session hash only when there is any wear state, so a project with wear off hashes exactly as before.
- **Saved** with the world: `<project>/.state/wear.bin` (magic `VXWR`, a version, the cells, the tracks, the walkers' loads; ages are saved, not ticks, so a loaded session continues where it was; a newer
  version is refused and the file is left as it is).
- **Recording / replay**: a recording copies the table to `<clip>/wear_0.csv` and the saved state to `wear_0.bin` and writes `wear` / `wear_hash` / `tracks` into its header; a replay reads the copies. Nothing
  else is logged (the counters follow from the logged movement), except the actions `wear_clean` and `snow`.
- **Networked sessions**: the descriptor carries the table's hash and the tracks switch, so peers must agree; every peer starts with no worn ground (the saved file is not loaded in a session; a late joiner
  replays the log).
- **Undo**: wear is never in the undo history (its edits bypass the journal and the side recorder). An undo that swaps bricks back makes the system forget the cells and tracks in them (the same hook the
  fire has); a dig next to a path takes the path's wear in that brick back with it.
- **Limits**: wear works on surfaces that face world +y (a planetoid's other "downs" are not worn); a column that is not loaded is skipped (a path pauses while nobody is near).

## Real snow and weather snow
Two kinds that never share state. **Real snow** is voxels (`snow`, from a biome or built by hand: collision, diggable, saved, in the hash). **Weather snow** (`fx.snow(amount[, falling])`, the `snow` MCP tool
and action, docs/FOLIAGE.md "Snow") is the render-only layer of the ground cover. They meet in two places: the layer is drawn on top of real snow voxels at **half depth** (powder on packed snow), and the
`snow, sink` row of the wear table makes real snow compress under a foot and fill back while it falls. The amount of weather snow stays render-only; only the `falling` flag is read by the simulation.

## Tools
MCP `wear_info` (the setting, the rows, the counts, the caps, the cost of the last step), `wear_clean {box}`, `snow {amount, falling}`; Lua `wear.clean(x0, z0, x1, z1)`, `wear.cells()` (-1: off),
`wear.enabled()`. Cost: well under 0.1 ms a tick (8 walkers x 9 cells, 64 edits at most).

## Not built
A "Wear" panel in the Settings window (the project decides); several surface classes per row for dirt (one track colour per surface); wear on planetoid surfaces; a window to edit the table (it is a file).
