# PLAN v2: THE DESCENT as a seeded, procedural dungeon

Status at the end of the first session: A, B and C are done except what GAME.md lists as limits; D has no daily seed (no date in the engine). Written 2026-10-23 while the user was away for ~8 hours (autonomous work: small steps, a screenshot after every visible step, a commit after every working step, everything noted in ENGINE_FEEDBACK.md / GAME.md).
Inputs: the user's wish ("this setting and system as a procedural dungeon with different seeds"), the notes from the book (BOOK_NOTES.md, private), the engine's new features (rigged kit figures, equipment, walk-through gore).

## Goal
A run is a **seed**. The seed fixes everything about every floor: the layout, the rooms and their hazards, who lives where, what the crates hold, which boss waits at the stairs, what the show's sponsors want. Same seed = same dungeon (and a recording replays to the same hash). The authored floor stays as the **Orientation** (floor 1 of the old slice, with its set pieces and its Floor Manager); a run can start there or skip it.

## Architecture (decisions)
- **One volume, rebuilt per floor.** The world is 256 m wide and the old floor fills most of it, and the ground is only 25 m deep (stone from 0 to 23 m, the dungeon floor is at 8 m), so a new floor is built in the *same* volume: wipe it to stone (tiled edits, an edit is limited to 40 m radius; ~5 s) and carve the new floor. That fits the story: the floor above collapses behind you. No going back up.
- **Seed -> layout is a pure function** (`game/gen/layout.lua`, own LCG, no global state): 3 x 4 grid of cells, a connected random subset of 8..10 cells holds rooms, a spanning tree plus 1..2 loops joins them with corridors that stay in the gaps between cells (so corridors never cross rooms). The start cell and the farthest cell are fixed as the arrival safe room and the exit stairwell; the exit hangs behind the boss room (a gate that opens when the boss dies).
- **Rooms are theme builders** (`game/gen/themes/*.lua`): each gets the room rectangle and a seeded rng and returns (a) voxel dressing (built when the floor is generated), (b) `things` (emitters, events, gravity fields: made on every load), (c) population `{kind, x, z}`, (d) crates / barrels / hazards. They reuse `G.room`, `G.fill`, `G.torch`, `T.crate`, `T.barrel`, `T.hazard` and the engine's systems (fire, liquids, gravity, hinges, conveyors).
- **World tables are swapped, not rewritten.** `W.rooms / W.neighbors / W.room_order / W.populate_list / W.checkpoints / W.zones` are replaced by the generated floor's tables (room ids `f<floor>_<n>`), `W.room_at` keeps working, the music / announcer / minimap code reads the room's `kind`.
- **Teardown** of a floor: emitters (G.torches), events (tracked ids), gravity fields, interact points, hazards, barrels, crates, enemies, bodies are removed through a tracked registry (wrapped constructors), then the volume is wiped.
- **State**: `G.state.run = { seed, floor, mode, started, sponsors..., viewers }`; per-floor keys (`cleared`, `opened`, flags) are prefixed with the floor so nothing leaks. Saves: voxels in world.vxs, tables in the store; the layout is regenerated from the seed on load, voxels are rebuilt only when a probe voxel says the floor is missing.
- **Determinism**: generator and population use `G.hash` / their own LCG only; no `os`, no time. A recorded multi-seed bot run must replay to its hash.
- **Compatibility**: an existing authored save (no `state.run`) keeps working as the Orientation floor; its end screen offers "Descend to Floor 2" which starts a run with a seed derived from the world's.

## Phases (each ends with screenshots, a bot run, a commit)
**A. Seeded floors**
1. `gen/layout.lua` + ASCII dump of 30 seeds, connectivity asserts (no overlaps, graph connected, exit behind boss, corridor lengths).
2. Tracked registry + floor teardown + volume wipe + `gen/build.lua` (rooms, corridors, doors, arrival room, exit stairwell, plain themes). Floor 2 reachable by teleport; pictures.
3. World integration (room tracking, sync_active spawns, music/announcer fallbacks, checkpoints per floor, minimap from the layout), boss room generalisation (`boss.lua` takes a lair), exit gate.
4. Run flow: title screen: New Run (random / typed seed / daily), Orientation or Skip; descending from the stairwell builds the next floor with a loading veil; save/load of a run; death keeps the floor (checkpoint = arrival room or last safe room).

**B. Variety**
5. Themes (8): hall, furnace (lava + bridge), flooded (water, eels as slimes), zero-g ballroom, mushroom grotto, crypt (bones, sarcophagi), library maze (shelves as cover), vault (a guarded crate cluster behind a puzzle), conveyor run; each with 2..3 variants by seed. Hazards: boulder corridors, spike/fire jets on timers, barrels.
6. Enemies: the old 8 plus rigged kit figures as monsters (orc, troll, cyclops, golem, human bandits/samurai) with `attack` / `hit` / `die` clips, level-scaled stats, elites with an affix (fast, armoured, explosive), packs; bosses by seed (Floor Manager, Golem Foreman, Troll Chieftain, Cyclops Auditor) with the arena rules of `boss.lua`.
7. Loot: crate tiers by depth, a "troll" sponsor box, items scaled by floor, durability on volatile consumables, scratch-off consumable.

**C. The show (from the book)**
8. Viewer meter (views, followers, favourites) on the HUD: spectacle raises it (combo kills, trap kills, flashy deaths, cleaning); sponsors unlock boxes; the announcer reacts.
9. Recap episode at each stairwell (kills, best hit, deaths, lowlight, sponsor offer), run summary at death / victory.
10. Conditions (Bleed, Septic, Taint, Burn) with cures; skills by use (mop, fire, explosives, ...) with a skills tab; safe room quirks per floor; three-strike rule; floor collapse timer with the population counter; stat points banked until the first stairwell.

**D. Meta and quality**
11. Seeds on the title screen, daily seed, "copy seed" in the pause menu, best-run stats per seed.
12. QA: a validator that walks the layout (navmesh / voxel flood fill from the arrival room to every room and the exit), a multi-seed bot (`tools/playthrough_seeds.py`), perf budget (frame ms, agent count, edit time per floor), replay hash per seed, balancing pass from the bot's numbers.
13. Docs: GAME.md, ENGINE_FEEDBACK.md (phases), tools.

## Risks and fallbacks
- Floor build time (> 10 s): build in slices across ticks behind the loading veil; fewer decorative edits.
- 64 agents: rooms spawn by proximity as now; elite/pack sizes capped per room.
- Kit-figure monsters are proxy agents: no ragdoll, no limbs pushing crates; death = `die` clip then fade. Check cost with 12 figures in view (15 parts each).
- Replay hash of a run with floor builds in it: if edits during play break replays, build floors from `on_tick` slices that are replayed identically (same ticks), and note it in ENGINE_FEEDBACK.
- Anything unfinished is left disabled behind a flag, never half-working in the default path.
