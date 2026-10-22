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
| `light` | `{color: [r, g, b], reach: metres, flicker: true}`: a point light at the emitter while it is on (it lights the probes of the GI like a lamp: a torch lights its surroundings) |
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
