# Emitters: particles by rule

> **Status (2026-10-21): built** (`src/sim/emitter_system.*`, `src/app/emitter_json.*`, tests/test_emitters.cpp). A torch or a campfire burns without setting anything on fire.

The engine's particles (flames, smoke and steam puffs, sparks, grains: docs/HANDOVER.md Phase 4) were made only by the simulation (explosions, burning voxels, pouring). An **emitter** is an authored object that makes them by rule: where, how often, which kind, how fast, in which cone, in what colour, with or without a light. The particles are the same GPU particles: an emitter only decides when and where a spawn record is made, so everything the particle system does (gravity, buoyancy, collision, water, settling) applies.

## What an emitter has
| key | meaning |
|---|---|
| `name` | unique; `<instance>.<name>` for a prefab's |
| `shape`, `pos`, `size` | `point`; `box` (half extents); `sphere` / `disc` (radius in x; a disc lies across the local up); `line` (`size` is the vector to the other end). Metres |
| `kind` | `flame` (rises against gravity, shrinks), `puff` (smoke, steam, dust: drifts up, grows soft), `spark` (a glowing speck), `grain` (a falling grain that settles into a voxel) |
| `rate` / `burst` | particles per second (0: bursts only), and how many a burst makes |
| `life`, `particle_size` | `[min, max]` seconds, `[min, max]` voxels (a puff: its radius) |
| `direction`, `speed`, `speed_var`, `spread` | `"up"` (against the local gravity) or `[x, y, z]`; voxels per second and how much of it varies; the cone's half angle in radians (3.14: every way) |
| `material`, `darkness` | the particle's material (empty: the kind's own: flame / ember, stone grey, neon, sand); a puff's darkness 0..1 |
| `light` | `{color: [r, g, b], intensity: 14, reach: metres, far: metres, flicker: true}`: a point light at the emitter while it is on (it lights the probes of the GI like a lamp: a torch lights its surroundings). **`color` is a radiance, not a 0..1 colour**: the presets use (1, 0.55, 0.2) x 14 (torch), x 26 (campfire) and (0.4, 0.7, 1) x 10 (magic sparks); a light of 1 is a faint glow. `intensity` multiplies the colour (`color = {1, .55, .2}, intensity = 14` is a torch's light; given alone it scales the preset's). Any kind of emitter can carry a light, particles or not. **`far`** (metres, 0: none) is the distance from the camera beyond which this light is not given to the probes. **Light budget**: the probes have 256 places for point lights in all; lamps and emitter lights share `light_budget` of them (project.cfg, default 128, 0..256), cut to the nearest to the camera, and the fire and lava samples fill what is left (they used to take it all, so a torch could get no place). A game need not switch lights by hand: `status.render.lights` shows `authored` (candidates), `authored_drawn`, `budget`, `probe_lights` and `probe_lights_cut`. Culling is render only (never the state hash or a replay). `reach` only has to be above 0 for the light to exist (the lighting decides how far it goes). The light shows at once on the probes near the camera and spreads over the grid within a second or two in the window; a picture from an MCP session needs frames: `screenshot {settle: N}` |
| `enabled`, `seed` | on / off; varies the random numbers of two emitters |

**Presets** (a starting point; any key can then be changed): `torch`, `campfire`, `chimney_smoke`, `steam_vent`, `fireflies`, `dust_motes`, `magic_sparks`, `embers`, `sand_fall`.

## Making them
| where | how |
|---|---|
| Editor | the **Emitters** window (menu bar): the list, kind, shape, rate, speed, spread, life, size, light, material, position, on / burst / delete, and **new from a preset at the look point**; with the window open the shapes are drawn in the world (box, sphere, disc, line, an arrow along the direction; the picked one white, an off one grey) |
| MCP | `emitter_list`, `emitter_create {name, preset?, pos, ...}`, `emitter_set`, `emitter_delete`, `emitter_enable`, `emitter_burst` (recorded actions: `emitter_define`, `emitter_delete`, `emitter_enable`, `emitter_burst`) |
| Lua | `emitter.create{ name = "chimney", preset = "chimney_smoke", pos = {x, y, z} }` (metres; the keys of the JSON form), `emitter.enable(name, on)`, `emitter.burst(name [, n])`, `emitter.remove(name)`, `emitter.find(name)`; a script's emitters are made again by the script and are not saved |
| Prefab manifests | `ctx.emitter{ name = "flame", preset = "torch", at = {x, y, z}, enabled = p.lit }` in `build`: `at` is a cell of the model (it turns and moves with the placement), the emitter is named `<instance>.flame` and goes with the prefab (also when it is moved: `build` makes it again). The kit's `props/torch` and `props/campfire` do this, with a `lit` parameter |
| Events | an event node of kind `emitter` (Lua `events.emitter{ name = "brazier.switch", emitter = "<emitter name>" }`, MCP `event_create {kind: "emitter", name, emitter}`, the Events window) takes the commands `on`, `off`, `toggle` and `spawn` (a burst): a plate lights a brazier, a lever starts a fountain |

Emitters made with the editor or the MCP tools are **authored**: kept in the project's `emitters.json` at every save and read again at every start (a recording keeps a copy, a replay reads it and never writes the project's file).

## Determinism
A definition is a logged action or a script's call, the spawn records come from a seeded generator keyed by (emitter seed, tick) and the rate is an integer accumulator (`rate * 1000 / 60` thousandths of a particle per tick), so the same session makes the same spawn records. The particles themselves are **cosmetic**: the GPU simulates them frame-timed, nothing in the simulation reads them (a `grain` emitter's grains become voxels the way any settling grain does, which is the same documented coupling as explosion debris). The definitions and which emitters are on are mixed into the session hash. At most 400 particles come from one emitter in one tick and 256 emitters exist.

## Not built
Emitters attached to a moving body or an agent (a position follows a prefab, not a body), a size or colour curve over a particle's life (a flame shrinks, a puff grows, as the particle classes do), water drops and fountains (a `drop` kind that falls and splashes: the rain particles are the engine's `DropSystem`), a live preview strip (the world is the preview), collision on / off per emitter, wind.


## What the particle kinds do (and what they leave behind)
`flame` rises and shrinks, `spark` flies and falls, `puff` drifts up and grows (a 1 voxel puff is hard to see), `grain` and the debris of digging and blasts are **real matter**: they fall, and where they come to rest they **settle into the world as voxels** (sand piles up, a blast leaves rubble, a corpse that crumbles leaves gore): deliberate, and the reason none of these can be used for floating labels. **`mote`** is the kind for that: it flies straight on its velocity for its life: **no gravity, no collision, no settling, no shrinking**. A particle may be a **fraction of a voxel** (`particle_size` 0.1 and up, in voxels of 6.25 cm; below about a third of a voxel it flickers beyond a few metres: a pixel of the picture is about a tenth of a voxel at 3 m) and its position is a real number (the Lua calls below take metres).

## Motes and text in the world (Lua)
```lua
fx.mote{ at = {x, y, z}, vel = {0, 1, 0}, life = 1, size = 0.03, material = "neon", count = 1, spread = 0 }   -- metres, m/s, seconds; `spread` is a box around `at`
fx.text{ text = "-12", at = {x, y, z}, size = 0.12, material = "neon", rise = 0.5, life = 1.2, toward = {x, y, z}, align = "center" }
```
`fx.text` is a **label made of motes**: one cube per lit pixel of the 5 x 7 font of `edit.text`, `size` metres tall (a seventh of that per font pixel: 0.12 m is about the size of the HUD's small text), laid in the plane that **faces the viewer** at the moment it is made (`toward`, by default the player's eye; the label does not turn afterwards, which is right for a number that rises for a second) and rising along the viewer's up at `rise` m/s. `material` gives the colour (any material, the project's too: make `crit_red`, `heal_green` in `materials.csv`; a bright emissive one like `neon` reads best); at most 40 characters. A label is a few dozen to a couple of hundred particles of the 256,000 the GPU keeps.
`fx.particle_taa(false)` (project.cfg `particle_taa = off`) keeps particles out of the temporal anti-aliasing history: a small fast particle then leaves no double image of itself (its edges are not smoothed; foliage is not affected).
