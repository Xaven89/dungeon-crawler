# Lua API

Level and gameplay scripts are Lua 5.4. A project names one script (`lua = level.lua` in `project.cfg`, or `voxelith --lua level.lua`); the file runs once
at start and may define these functions:

| function | called |
|---|---|
| `on_start()` | once, after the world around the player is loaded |
| `on_tick(tick)` | every simulation tick (60 per second), before the tick runs |
| `on_reload()` | after the file changed on disk and was reloaded (scripts are hot reloaded: save the file while the game runs) |

A reload runs the file's top level again in the **same** Lua state: globals survive, timers are dropped (and kept if the new file has a syntax error), then
`on_reload()` runs. So create things in `on_start()` and keep the top level to definitions, or they are created twice.

Rules of the sandbox: `io`, `os`, `package`, `dofile`, `loadfile` and `string.dump` do not exist and `load` reads text only (no bytecode); every call into Lua is
limited to 20 million VM instructions in all its coroutines together (an endless loop is stopped with an error message in the log instead of freezing the
game) and the script's memory is capped at 256 MB (`string.rep('x', 4e8)` fails inside the script); errors are logged with the script line and the game keeps
running. An edit beyond sane limits (radius over 640 voxels, a box longer than 16384 voxels) is refused with a log line.
All edits a script makes in one call (`on_start`, `on_tick`, one timer) are **one undo step** (Z undoes the whole call). Scripts never touch voxels directly: they submit the same
edit operations the game does.

**Units.** Edits, world queries, liquids and effects use **voxels** (1 voxel = 1/16 m, integers; numbers are rounded). Gravity fields, the player and bodies
use **metres**. `units.vox(m)` and `units.m(v)` convert.

## Materials
```lua
material("stone")          --> 1 (error: unknown material 'x')
material_name(10)          --> "water"
```
The names are the ones in the project's `materials.csv` (`voxelith --dump-materials` writes the built-in table).

## edit: building and carving
```lua
edit.sphere(x, y, z, radius, "brick" [, mode])
edit.box(x0, y0, z0, x1, y1, z1, "glass" [, mode])     -- corners inclusive, any order
edit.paint_sphere(x, y, z, radius, "red")                -- paint (docs/PAINT.md): a name, "#rrggbb", an index 1..255 or "none"; the material stays
edit.paint_box(x0, y0, z0, x1, y1, z1, "#3366cc")
edit.text(x, y, z, "HELLO", { facing = "+z", material = "brick", size = 1, spacing = 1, depth = 1, align = "left", mode = "replace", paint = "red", texture = "heart" })  -- voxel text (docs/TEXT.md): a 5 x 7 font; (x, y, z) is the bottom of the line, `facing` the way the text looks
edit.texture_sphere(x, y, z, radius, "brick")          -- texture (docs/TEXTURES.md): what is drawn on the faces of the solid voxels, by the name of a texture (the built-ins, textures.json, `texture_define`); "none" clears it
edit.texture_box(x0, y0, z0, x1, y1, z1, "heart")       -- colour and material stay; liquids and glass take none
edit.clear(x0, y0, z0, x1, y1, z1)                      -- air
edit.voxel(x, y, z, "metal")
edit.carve(x, y, z, radius [, roughness, seed])         -- the noisy bite of an explosion, without the blast
edit.model("models/house.vxm", x, y, z [, rotation])    -- .vxm or MagicaVoxel .vox, relative to the script; rotation 0..23
```
`mode` is `"replace"` (default), `"fill_air"` (only write into empty voxels) or `"paint"` (only recolour solid voxels).

## world: queries
```lua
world.material_at(x, y, z)  --> "stone" / "air" / "unloaded" (outside the streamed area the world is not known; edits there wait until it loads)
world.solid(x, y, z)        --> true / false
world.top(x, z [, from_y [, skip_walk_through]])  --> y of the highest solid voxel of the column (the voxel's own y: stand on y + 1), -1 if none; the 4th argument `true` skips walk-through voxels (stains), still the voxel's y
world.reset_region(x0, y0, z0, x1, y1, z1)  --> chunks reset: the whole chunks the box touches (voxels) forget every edit and come back from the generator a moment later (edits made after the call wait for them); also forgotten in the save file; the undo history, prefabs wholly inside, loose bodies and fire there are cleaned up (docs/WORLD_GEN.md "Resetting a region")
```
Edits become visible one tick after the call, so a query right after `edit.*` still sees the old world.

Ground and first run:
```lua
x, y, z = world.flat_spot(width_m, depth_m [, max_step])   -- min corner (voxels) of dry flat ground near the player; y = the first free voxel above it. An error if there is none within 50 m
project.first_run()          -- false when the project's world save already existed (its edits are in the world): build voxels only when true
```

## gravity: fields (metres, m/s²)
```lua
id = gravity.add{ type = "uniform", name = "flip room", dir = {0, -1, 0}, strength = 9.81, priority = 20,
                  pos = {x, y, z}, half = {4, 4, 4} }     -- half = region (0 = everywhere)
gravity.add{ type = "point",   pos = {...}, strength = 4, inner = 2, outer = 30, falloff = "inverse_square", ref = 1 }
gravity.add{ type = "surface", pos = {...}, half = {...}, strength = 5, inner = 3, outer = 10 }   -- follows the voxels of a planetoid
gravity.add{ type = "null",    pos = {...}, half = {...} }                                        -- weightless box
gravity.retarget(id, {0, 1, 0}, 9.81)      -- turn a uniform field (the flip switch)
gravity.enable(id, false)   gravity.remove(id)   gravity.find("name") --> id or -1
ax, ay, az = gravity.sample(x, y, z)
```
Types: `uniform point line plane torus spline box surface null`. Common keys: `name enabled pos strength inner outer priority blend ("replace"|"add"|"max")
falloff ("constant"|"inverse_square") ref reverse pin_camera_up dir half round radius a b two_sided points mode ("toward"|"along"|"up") smoothing`.
Fields with a higher `priority` win where they overlap; `inner`/`outer` are the shell in which the field fades out.

## emitter: particles by rule (docs/EMITTERS.md)
```lua
emitter.create{ name = "chimney", preset = "chimney_smoke", pos = {x, y, z} }    -- metres; every key of the JSON form: shape, size, kind, rate, burst, life, particle_size, direction, speed, spread, material, light = { color = {r, g, b}, reach = 6 }
emitter.enable("chimney", false)   emitter.burst("chimney" [, n])   emitter.remove("chimney")   emitter.find("chimney") --> true / false
```
Presets: `torch campfire chimney_smoke steam_vent fireflies dust_motes magic_sparks embers sand_fall`. In a prefab manifest's `build`: `ctx.emitter{ name = "flame", preset = "torch", at = {3, 19, 3} }` (a model cell; named `<instance>.flame`, goes with the prefab).

## fx: effects
```lua
fx.explosion(x, y, z, radius [, strength])    -- voxels; carves, throws bodies, debris, sparks, smoke, sets flammables alight
fx.fire(x, y, z, radius)                      -- sets flammable voxels (grass, leaves, wood) alight
fx.rain(true)                                 -- rain around the player
wear.clean(x0, z0, x1, z1)                    -- metres: the dirt tracks in the box go back, the worn cells in it are forgotten (docs/WEAR.md); wear.cells() -> cells worn (-1: wear is off), wear.enabled()
fx.snow(0.8)                                  -- 0..1: a snow type of the ground cover table (docs/FOLIAGE.md "Snow") lies that deep; fx.snow(0.8, true): it is falling (trodden snow fills in faster). Render only
fx.pour(x, y, z, count [, "sand"])            -- grains falling from a disc
fx.steam(x, y, z [, amount])                  -- a parcel of steam (255 = one voxel of water)
```

## liquid
```lua
id = liquid.source(x, y, z, "water", rate)    -- fill units added per tick (a faucet: 12 is a trickle, 255 a flood)
liquid.remove_source(id)
```
Water and lava flow along the local gravity, lava and water make stone and steam, steam condenses and rains back.

## body: loose objects (physics bodies; metres for the position, voxels for the size)
```lua
id = body.box(x, y, z, sx, sy, sz, "wood")    id = body.ball(x, y, z, radius_voxels, "stone")
h = hinge.add{ a = body, b = otherBody (omit: the world), anchor = {x, y, z} (m), axis = {x, y, z}, limits = {lo, hi} (degrees from the pose now), spring_to, spring_k, spring_damping, friction, breakaway, motor = {rad/s, N m} }
hinge.set(h, {...})   s = hinge.state(h)   -- { angle (degrees), omega (rad/s), torque (N m) }    hinge.remove(h)   -- hinges between bodies (a drawbridge, a swinging sign, a gate)
j = joint.ball{ a = body, b = otherBody (omit: the world), anchor = {x, y, z} (m), cone = 60 (deg), damping, friction }  joint.state(j) --> { angle }  joint.remove(j)   -- a ball joint (docs/HINGES.md section 10)
c = chain.add{ anchor = {x, y, z} (m), links = 3, link = { length_voxels = 4, radius = 1, material = "metal" }, tip = { material = "glass", size = {4, 6, 4} }, cone = 60 }  -- N link bodies on ball joints from the anchor and a lantern body at the end: c.links, c.tip, c.joints, c.group; chain.remove(c.group). emitter.create{ body = c.tip, offset = {0, 0.15, 0}, ... } puts a flame and its light on the lantern
body.grab(id [, hold_distance_m])   body.release()   body.throw([speed])   id = body.grabbed()   -- the player's hand (docs/HINGES.md): a spring with force limits; light bodies follow the view, heavy ones are dragged
body.push(id, ix, iy, iz [, px, py, pz])   -- (with a point in metres the impulse acts there: a shove at a door's edge swings it) an impulse in N s (a 1,100 kg wooden crate needs about 5000 for a clear shove; momentum = mass x speed)  x, y, z, ok = body.pos(id)  body.remove(id)
```
Light materials (wood) float, heavy ones (stone, metal) sink.

## worldgen: the generator's hash
```lua
worldgen.seed                  -- the world's seed (a number; read-only; the same value as `worldgen.seed` inside on_region): the project's `seed =`, or `--seed N` when the command line gave one
worldgen.run_seed([n])        -- the run seed (0 .. 4294967295, an integer; 0 at the start): the third argument of `on_region(rx, rz, run)`. With a number it changes: the hook is asked again, the world around the player is made again (edited chunks keep their edits), the player waits for its ground (docs/WORLD_GEN.md "The run seed"). Without: the present one
worldgen.hash(x, z [, salt])   -- 0..1: the generator's pure hash of the integer position, the salt and the world's seed (in any world, with a region hook or without one); the same values as inside the region hook (docs/WORLD_GEN.md), so a script and its on_region agree on a cell without a copy of the hash. Read-only
```

## Scatter (trees, bushes, rocks by rule)
```lua
n, footprints, stats = scatter{ models = {{"models/oak.vxm", 4}, "models/bush.vxm"}, box = {x0, z0, x1, z1}, spacing = 112, density = 0.5, on = {"grass"}, slope_max = 0.7, avoid = {...}, clearings = {scale = 400, threshold = 0.35}, seed = 7 }
```
Voxels, deterministic from the parameters and the loaded ground, stamped as edits; docs/FOLIAGE.md has every option and what `stats` says.

## Prefabs
```lua
id = prefab.place("models/castle.vxm", x, y, z [, rotation [, name [, carve_air]]])   -- minimum corner, voxels; rotation 0..23; tracked
world.blocks(x, y, z)  world.passable(x, y, z)   -- stored voxel that is in the way / a walk-through voxel (docs/GORE.md); `world.solid` is true for both; world.top(x, z, fromY, true) skips walk-through voxels
edit.sphere(x, y, z, r, "blood", "coat")  edit.box(..., "blood", "coat" | "clear_if")   -- a one-voxel shell on the surfaces inside the shape / clear that material only
fx.splat(x, y, z, radius, "blood" [, seed])   -- metres: a speckled spatter of a walk-through material on the surfaces around a point (docs/GORE.md)
prefab.restamp(id)    prefab.remove(id)    id = prefab.find(name)   -- 0 when there is none; remove also takes the nodes "<name>.*" with it
id, h = prefab.place("door", x, y, z, { rotation = 0, name = "front", slots = { panel = "glass" }, variant = "wide", params = { open = -90 } })   -- a MANIFEST prefab (models/door.prefab.lua): parts, material slots, sockets, nodes: docs/PREFABS.md
```
Placing a name that is already tracked with the same file, spot and contents whose voxels are in the world (a saved project) adopts it instead of stamping again; a changed file is
re-stamped over the old version. The path is relative to the script. One undo step per call.

`workspace.new / edit / info / names / remove / place`: small models made apart from the world (docs/MODEL_WORKSPACE.md).

`prefab.at(x, y, z)` (voxels) is the placed prefab that owns that voxel, as `{ id, name, manifest, x, y, z, rotation, sx, sy, sz }`, or nil: what a script asks to react to what the player built (the editor's pick).

## Rigged models
```lua
-- units: model.spawn, edit.*, prefab.place, world.* take VOXELS (1/16 m); agent.spawn, fx.*, player.teleport, sound.*, camera and bodies take METRES
m = model.spawn("models/walker.vxm", x, y, z [, rotation [, { scale = 0.6, visual = true, swap = { ["from"] = "to" } }]])   -- voxel corner; every part becomes a driven body; `visual` draws it only, `scale` overrides the file's voxel scale (docs/ANIMATION.md "Voxel scale")
model.play(m, "walk" [, speed [, loop]])    model.stop(m)    model.move(m, x, y, z)    model.remove(m)
model.procedural(m, { walk = { legs = {"leg_l", "leg_r"}, arms = {"arm_l", "arm_r"} }, look = { part = "head" }, springs = {{ part = "tail" }} })   -- rules over the clip, by part name (docs/ANIMATION.md)
model.look_at(m, x, y, z)   model.look_at(m)    -- the head turns towards a point (world voxels) within its limits / looks ahead again (an error on a model without a look rule)
model.procedural(m, { ik = { legs = {{ upper = "thigh_l", lower = "shin_l", foot = "foot_l", pole = {0, 0, 1}, foot_height = 1 }} }, walk = { turn_smoothing = 15 } })   -- feet on the ground, planted feet, a smooth turn
model.procedural(m, { from_roles = true })   -- the rules the rig's roles imply
info = model.rig(m)   model.rig(m, { roles = "infer", joints = { head = { type = "ball", cone = 70, twist = 80 } } })   -- the rig description (parts, joints, roles, clips); the second form changes it first
model.rig(m, { sockets = { grip_r = { parent = "hand_r", pivot = {14.5, 20, 4}, rot = {180, 0, 0} } } })   -- add / move a socket (a part without voxels where an item sits); `{ sockets = { grip_r = false } }` removes one (docs/EQUIPMENT.md)
child = model.attach(m, "sword.vxm", "grip_r", { name, mode = "auto" | "merge" | "attach", offset = {x, y, z} metres, rot = {x, y, z} degrees, anchor = {x, y, z}, scale, swap, hide_parts = {..} })   model.detach(m [, name])   model.hide_part(m, part, on)   model.replace_part(m, part, file | nil)   model.sockets(m)   model.attachments(m)   -- equipment: items baked into a part's body (docs/EQUIPMENT.md); `m` may be an agent id
names = model.clips(m)
model.play(m, "walk", 1.0, true, 10)   -- the last number: ticks to cross-fade from what played before
model.graph(m, { start = "idle", states = {...}, transitions = {...}, layers = {...} })   model.param(m, "waving", 1)   model.trigger(m, "hit")   model.state(m)   -- a state machine over the clips (docs/ANIMATION.md)
function on_anim(m, event, clip) end   -- a clip event passed (a footstep, a hit frame)
```
Parts are made in the model editor (docs/GUIDE.md); clips are keyframed rotations and offsets per part. `speed` is clamped to +-100. The bodies push crates but nothing pushes them; a part that is destroyed is gone.

## Effects
```lua
fx.define{ name = "pop", emitters = {
    { class = "spark", material = "metal", count = 60, speed = 55, speed_jitter = 0.5, spread = 0.8, life = 1.4, size = 0.7, radius = 1 },
    { class = "puff", material = "stone", count = 12, size = 6, duration = 0.4, darkness = 0.5, direction = {0, 1, 0}, speed = 14, spread = 0.2 } } }
fx.play("pop", x, y, z [, scale [, age]])    -- voxels; scale multiplies radius, speed and size; age (s) joins the effect part way through (particles already along their path)
names = fx.effects()
```
Emitter fields: `class` (debris, grain, spark, puff, flame, drop), `material`, `count`, `life` / `life_jitter` (s), `size` / `size_jitter` (voxels; a puff's radius), `radius` (spawn sphere),
`direction` (+Y is the local up), `speed` / `speed_jitter` (voxels/s), `spread` (0 along `direction`, 1 every way), `delay`, `duration` (0: all at `delay`, else spread over it), `darkness` (puffs).
Sizes are in voxels (6.25 cm): 3 to 6 is clearly visible. Redefining a name replaces it (a script reload does that). Built in: `sparks`, `smoke_column`, `fountain`, `confetti`. Effects are cosmetic.

## player and time
```lua
player.teleport(x, y, z)      x, y, z = player.pos()     -- feet, metres
player.forward()             -- dx, dy, dz: the unit vector the player looks along
-- Players of a networked session (docs/NETWORK.md): ids are 0-based, 0 is the host; every call above and below takes an optional id (default 0), and the state is the same on every peer.
player.count(); player.present(i); player.name(i); player.eye(i); player.nearest(x, y, z)  -- { id =, distance = } of the nearest player in the world, or nil
player.teleport(x, y, z): a target INSIDE solid voxels (a wall, a shelf, the rock) is not accepted as it is: the player is lifted to the first height above it where its body's column (28 voxels, 1.75 m) is free, within 16 m, and the log says by how much (no room: it is left there, with a warning). The rule reads the voxels of the target column only, so it is the same on every machine; a target in a column that is not loaded yet is checked when the column is there (with { wait = true }) or not at all (without it)
player.teleport(x, y, z, i)  -- one player: only the machine that plays it moves it (without an id: every machine's own player, as before)
player.teleport(x, y, z, { wait = true [, player = i] })  -- a place whose ground has not been made yet (a far teleport, a hook-built floor): the player stands still there, no fall, until the chunk under its feet is resident (the streamer adopts columns at a fixed tick: the same on every peer; let go after 30 s with a log line). `status.player.held_for_column` says it is waiting. Without `wait` the player falls from the target at once, into rock if its column is not there
player.me()                  -- on_hud only: the id of the player this machine plays (it differs between machines, so the simulation must not use it)
-- vehicle.enter(id, i), vehicle.exit(i), vehicle.seated(i), body.grab(id, dist, i), body.release(i), body.throw(speed, i), body.grabbed(i) act for player i
time.tick()  time.seconds()   -- the tick being run (the same number on_tick(t) and the timers see)
after(ticks, fn) --> id       every(ticks, fn) --> id    cancel(id)       -- timers (60 ticks = 1 s)
include("other.lua")          -- relative to the script; `include_optional("dev/x.lua")` is the same but returns false for a file that is not there; `file_exists("x.lua")` asks
print(...)  log(...)          -- to the log
```

## A small level
```lua
function on_start()
    local px, py, pz = player.pos()
    local x, z = math.floor(units.vox(px)) + 160, math.floor(units.vox(pz))
    local y = world.top(x, z) + 1
    edit.box(x, y, z, x + 63, y + 40, z + 63, "brick")
    edit.clear(x + 3, y + 3, z + 3, x + 60, y + 40, z + 60)           -- a hollow room
    edit.box(x + 4, y, z + 4, x + 59, y + 8, z + 59, "water")           -- flooded
    flip = gravity.add{type = "uniform", dir = {0, -1, 0}, strength = 9.81, priority = 10,
                       pos = {units.m(x + 32), units.m(y + 20), units.m(z + 32)}, half = {2, 1.2, 2}}
    every(900, function() gravity.retarget(flip, {0, -1, 0}, 3) end)   -- the moon room every 15 s
end
```
`projects/demo_level/level.lua` is a bigger, commented example.

## Events: buttons, levers, volumes, lamps, doors (docs/EVENTS.md)
Nodes are declared by name (a name that exists is adopted: a script run again, or a hot reload, finds its nodes); boxes are voxels, spheres / positions metres, times ticks. Materials by name (`on` / `off` are the materials the node's voxels swap between).
```lua
id = events.button{ name = "b", box = {x0,y0,z0,x1,y1,z1}, prompt = "Light the lamp", on = "neon", off = "metal", press_ticks = 20 }   -- pressed with E / `use` when looked at within 3.5 m
id = events.lever { name = "sw", box = {...}, prompt = "...", on = "neon", off = "metal", lit = false }                              -- stays pressed until pressed again
id = events.volume{ name = "plate", box = {...}, player = true, bodies = true, material = "wood", min_mass = 50, tags = {"key"} } -- or sphere = {x, y, z, radius_m}
-- min_weight = 500 (N): the volume is on while what stands in it weighs at least that much along the local gravity (the player counts 80 kg, a 1 m wooden crate is 7.5 kN); events.state(id).weight_n
id = events.lamp  { name = "l", box = {...}, on = "neon", off = "stone", radiance = {30, 28, 24}, lit = false }                    -- swaps the voxels; a lit lamp also lights the probes like fire
id = events.door  { name = "gate", box = {...}, travel = {0, 40, 0}, speed = 2, material = "wood", auto_close = false }   -- the slab slides along travel (one axis) 2 voxels per tick; it waits for the player and bodies in its way. material: the slab is the whole box of it (placed if the world does not show it: first run, saved open door, blasted); without it the slab is the solids found in the box (at most 65,536 cells)
id = events.door  { name = "front", material = "wood", box = {...}, hinge = { axis = "y", at = {x, y, z}, open = 90, seconds = 0.8 } }   -- a SWING door: the slab turns about the axis through the voxel cell `at` (open = 90 or -90, right-hand rule); voxels at the stops, a kinematic body while it turns (it pushes crates, waits at the end for what stands where it closes)
id = events.door  { name = "front", model = "models/door.vxm", pos = {x, y, z}, rotation = 0, hinge = {...} }                         -- the slab from a model file (minimum corner at pos, one of the 24 rotations first)
id = events.door  { name = "front", material = "wood", box = {...}, hinge = { axis = "y", at = {x, y, z}, open = 90, dynamic = true, friction = 6, spring_to = 0, spring_k = 80, spring_damping = 20, breakaway = 0, motor_torque = 0, motor_speed = 1.5, limits = { -100, 100 } } }
-- DYNAMIC swing door: a real body on a hinge to the world, always (the player walks against it and it opens, crates and blasts move it; a trapdoor is axis "x" with `breakaway` = the torque that holds it, it falls open under load). friction holds it where it is left, spring_* pulls it back to spring_to (a saloon door: limits {-100, 100}),
-- motor_torque > 0: open / close drive it (without a motor they do nothing: it is pushed). The node's level is "open" (|angle| >= 85 degrees); events.state(id).angle_deg. A closed one is a body: it does not occlude GI light.
id = events.timer { name = "t", delay = 120, period = 0, autostart = false }            -- sends `on` (fired) when due; period > 0 repeats; commands start / stop / reset
id = events.logic { name = "both", op = "and", inputs = { a, b }, count = 3, delay = 30 }  -- ops: and or xor not toggle one_shot counter (count) delay (ticks); reads its inputs' levels
id = events.gravity_target { name = "room", field = flip, presets = { {{0, -1, 0}, 9.81}, {{0, 1, 0}, 9.81} } }   -- commands enable disable toggle retarget (arg = preset index)
id = events.spawner { name = "drop", pos = {x, y, z}, kind = "box", size = {16, 16, 16}, material = "wood", impulse = 0 }   -- spawn: a body at pos (metres), `impulse` = upward speed m/s
id = events.effect  { name = "pop", effect = "sparks", pos = {x, y, z}, scale = 1 }                                        -- play
events.connect(from, "on", to, "toggle" [, { delay = 30, arg = 0 }])     -- (logic `set`: arg = +(input index + 1) sets that input on, -(index + 1) off)     -- signals: on off pulse stay (aliases pressed enter exit opened closed blocked); commands: on off toggle open close stop press enable disable
local h = events.on(id, "on", function(ev) print(ev.name, ev.signal, ev.tick) end)  -- a function called when the node sends the signal (dropped on a hot reload: declare it in on_start / on_reload); several on one node and signal all run, in the order they were made; the handle goes to `events.off(h)`
events.fire(id [, "on"])   events.command(id, "open")   events.enable(id, false)   events.remove(id)   id = events.find("name")   events.tag(body_id, "key")
st = events.state(id)      -- { name, kind, level, enabled; doors: open, moving, position, remaining, blocked (swing doors: angle_deg, body, at_stop; position is 0 or 90); volumes: player, bodies }
```
Build the voxels of a lamp, door or button in `on_start` with `edit.*` (first run), declare the node on every run. A door with `material = "wood"` is the whole box of that material (the engine places it where the saved state says, so a door survives a reload, a blast or being declared over terrain); a door without it is whatever is solid in its box two ticks after it was declared. The pocket it slides into (`box` + `travel`) has to be air or the slab itself. A button, lever or lamp box should hold only its own voxels.


## sound (docs/AUDIO.md)
```
sound.tone(hz, seconds [, x, y, z])          -- positions are metres; omitted: at the player's head
sound.click([pitch [, x, y, z]])
sound.boom(radius [, strength [, x, y, z]])
sound.hit("metal", speed [, size [, x, y, z]])
sound.step(creature, material [, speed [, x, y, z]])   -- one footstep of that creature (footsteps.csv, docs/AUDIO.md "Footsteps")
sound.load("sounds/door.wav")  --> index      -- WAV, relative to the project; -1 when unreadable
sound.play("sounds/door.wav" | index, x, y, z [, volume [, pitch]])  --> true / false
sound.play{ file, loop, bus = "sfx" | "music" | "voice", volume, pitch, at = {x, y, z}, fade_in }  --> handle   -- no `at`: 2D; sound.stop(h [, fade]) / sound.volume(h, v [, fade]) / sound.pitch(h, p [, fade]) / sound.bus(name, v)  (docs/AUDIO.md)
```
Cosmetic: nothing is logged or hashed; there is no sound in headless runs, recordings, replays or MCP sessions.


## project.store / project.fetch / project.keys (docs/SAVES.md)
```
project.store("quest", { stage = 2, items = { "key", "lamp" } })   -- numbers, booleans, strings, tables of them; nil removes
local q = project.fetch("quest")            --> the table, also after a restart (it is saved with the world)
project.fetch("gold", 0)                    --> the default when there is no such key
project.keys()                              --> { "gold", "quest" }
```
Saved with the world (`save`, F11, exit), part of the session hash, kept in recordings. Functions cannot be stored; at most 12 levels, 1 MB.


## ui (docs/HUD.md): the game's HUD, valid inside `on_hud(dt)`
```
ui.size() -> w, h          ui.text(x, y, s [, {size, color, align, shadow}])      ui.rect(x, y, w, h, color [, {radius, outline, thickness}])
ui.bar(x, y, w, h, fraction, color [, background])      ui.line(x1, y1, x2, y2, color [, thickness])      ui.circle(x, y, r, color [, {outline, thickness}])
ui.button(label, x, y, w, h) -> clicked      ui.mouse() -> {x, y, down, clicked} | nil      ui.run(code)   -- as a logged action at the next tick
```

## Text in the player's language
`tr(key, args...)`, `trn(key, count, args...)`, `lang()`, `has_text(key)`: see docs/LOCALIZATION.md (`strings/<lang>.csv`, `{1}` arguments, plural forms, fallback to `en` and to the key). Presentation only: do not branch the simulation on the text.

## camera (docs/CAMERAS.md)
`camera.mode("first" | "third" | "top")` switches and returns the mode (no argument: just returns it); `camera.set{ distance, lift, zoom, pitch (deg), yaw (deg), pan_speed, fov }`; `camera.focus(x, y, z)`. Render and input only: the simulation does not depend on it, except that the top camera flies the player along (a level that wants a strategy view calls `camera.mode("top")` in `on_start`).

## Vehicles, agents, navigation
`vehicle.spawn / drive / enter / exit / info / list / seated / remove` (docs/VEHICLES.md), `agent.spawn{..., creature = "horse"} (whose feet sound like footsteps.csv says) / walk / follow / wander / stop / speed / info / list / remove`, the callback `on_agent(id, what)`, `nav.path / nav.floor / nav.flood` (docs/AGENTS.md; `flood` says which standable cells of a box a walker reaches, in islands: the check that a built floor is walkable). In a networked session these act for the host's player (`vehicle.enter`, `body.grab`) because the script runs identically on every peer.


### Custom input actions (docs/INPUT.md)
`on_action(name, down, player)` is called in the simulation when a custom action of `input.cfg` (`action.NAME = ...`) goes down or up; `input.down(name [, player])` is true while that player holds it. Both follow the logged actions, so they replay and agree between players.

### Props that touch nothing fall
A voxel (or a group of voxels) that is not connected through solid voxels to an **anchor** material (the `anchor` flag of `materials.csv`: stone, the ground and the like) becomes a loose body and falls when the tick starts, so a sconce, a sign letter or a crystal built one voxel away from its wall drops to the floor. Build props touching their support, or give the support an anchor material. `status` shows the `bodies` count (a jump after `on_start` is this).

### The sky
`sky.set{ time = 0.75, speed = 0, fog = 2 }` sets the clock (0..1: 0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight), how fast it runs (0 stands still, 1 is a day in ten minutes, up to 60) and a multiplier of the fog density; every key is optional (`time` alone keeps a running clock running and stands still otherwise). `sky.get()` gives `{time, speed, fog, tint, fog_tint, sun, ambient}` (and `zenith`, `horizon`, `ground` while they are set).
**Palette** (a place with its own sky, e.g. a red dusk for a band of the world): `sky.set{ tint = {r, g, b}, fog_tint = {r, g, b}, sun = {r, g, b}, ambient = 0.8, zenith = {r, g, b}, horizon = {r, g, b}, ground = {r, g, b}, blend = 3 }`. `tint`, `fog_tint` (the horizon and so the fog), `sun` and `ambient` are **multipliers** of the day's colours (1 = unchanged, 0 to 8); `zenith`, `horizon` and `ground` **replace** the day's sky colours whatever the time of day (radiance, a plain sky is about 0.2 to 0.9: a red dusk is `zenith = {0.35, 0.06, 0.07}, horizon = {1.1, 0.35, 0.2}, ground = {0.3, 0.12, 0.1}`, with `time = 0.5, speed = 0` and `sun = {1.3, 0.6, 0.35}`). `false` for a key puts it back. `blend` seconds (0 at once, counted in ticks) is how long the sky takes to move to the new palette from where it is now. Keys not named stay as they were. Pictures: ~/share/sky_palette_red_dusk.png. Render only: nothing in the simulation reads the sky, so it is the same on every peer and in a replay (counted in ticks). `project.cfg` has `time`, `time_speed` and `fog` for the start; a biome's mood multiplies the fog again.

### The player's body and hands
`player.model(file | nil [, { idle, walk, run, jump, swim, attack }])` gives the player a rigged model (drawn in the third-person view and free pictures), `player.model_play(clip [, speed])` plays a one-shot over it, `player.attach(file, socket [, opts [, player]])` / `player.detach([name])` / `player.hide_part(part, on)` / `player.replace_part(part, file | nil)` put equipment on that body (docs/EQUIPMENT.md), `player.hand_model(file | nil [, { offset = {right, up, forward}, idle, turn }])` and `player.hand_play(clip [, speed])` the same for a model in the first-person view. Render only, not simulated: docs/ANIMATION.md "The player's model".

### Fire
`world.burning(x, y, z)` is true while the voxel is on fire (the fire system's own list: exact and cheap, unlike looking for ember voxels with `world.material_at`). `fx.fire(x, y, z, radius)` lights flammable voxels in the radius; **how far a fire spreads is the material's `fire_spread` column** (column 24 of `materials.csv`, 0..255, default 255; grass has 15, so a grass fire stays a patch, docs/GUIDE.md "Materials"): a carpet made of a material with a high `fire_spread` burns through whatever the radius was, so give floor coverings a low one.

### Motes, labels and particle history
`fx.mote{ at, vel, life, size, material, count, spread }` (small cubes that fly straight: no gravity, no collision, no settling), `fx.text{ text, at, size, material, rise, life, toward, align }` (a label that faces the viewer, made of motes) and `fx.particle_taa(false)`: docs/EMITTERS.md "Motes and text in the world". Positions and sizes in metres. Emitters have `kind = "mote"`.


## Gotchas

- **An edit beyond the limits is an error.** `edit.box` / `edit.sphere` / `edit.carve` and the other shapes throw "the edit is beyond the limits: a sphere of radius 900 (the limit is 640); make it in pieces" (a box is at most 16384 voxels per axis and 2^30 in all); the engine logged it and carried on before, so the script never knew.
- **`~` and `>>` (and the other bitwise operators) on a float that is not a whole number raise an error** in Lua 5.4 ("number has no integer representation"): the handler stops with a warning. Use `math.floor(x)` or `//` first.
- **`uikit.text_input`'s `filter` is a Lua pattern of what to remove**: `%D` keeps only digits (docs/UI_KIT.md).
