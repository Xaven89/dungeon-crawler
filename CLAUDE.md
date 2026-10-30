# Dungeon crawler — a game made with the Voxelith engine

This folder is a **packaged copy of the Voxelith engine** (a C++20 / Vulkan 1.3 voxel engine; everything is a 6.25 cm voxel) and the place where a **game** is made with it.
It is also a **test of the engine**: you are the first developer to use it from the outside, with the documentation and the tools only. Your game is the test. Use every system the engine has
(world generation and biomes, rooms built from voxels and prefabs, lighting and GI, fire, liquids, destruction, physics, gravity fields, agents and animation, events, vehicles, audio, particles, HUD and UI kit, inventory, saves, localization, cameras, replay).
Everything that does not work, is missing, is confusing or is slow is a **finding**: write it down in `ENGINE_FEEDBACK.md` (format at the top of that file) while you work, with a minimal reproduction. That list is worth as much as the game.

## What is here
```
voxelith              launcher (sets the library path): ./voxelith --help
bin/voxelith, bin/shaders, lib/   the engine (do not edit)
assets/prefabs/       the starter kit of voxel models (.vxm), assets/lib/ the engine's Lua library (include("engine/ui_kit.lua"), inventory.lua)
docs/                 the documentation: start with docs/GUIDE.md and docs/LUA_API.md, then docs/MCP.md; the rest are per system (SCRIPT, EVENTS, AGENTS, ANIMATION, AUDIO, HUD, UI_KIT, INPUT,
                      PREFABS, PACKS, TEXTURES, EMITTERS, CAMERAS, VEHICLES, HINGES, WORLD_GEN, FOLIAGE, WEAR, SAVES, LOCALIZATION, ACCESSIBILITY, TEXT, EDITOR_MODE, MODEL_WORKSPACE, NETWORK, RESILIENCE)
projects/             example projects to learn from: demo_level (a small level with a script), rules_test (biomes, rules, features, creatures, a region hook), endless_test, creature_test (rigged animals
                      with clips and events), animation_test, inventory_test, conveyor_test, wear_test, biome_test, lantern_cove (a bigger authored scene)
tools/                voxelith_client.py (a small Python client for the engine's MCP server), make_prefabs.py and make_creatures.py (how the starter models are generated: a model generator in Python)
```
Your game goes in **`projects/dungeon_crawler/`** (a project folder: `project.cfg`, `level.lua`, materials, models, tables ...; see docs/GUIDE.md "Projects"). Check it with `./voxelith --check-project projects/dungeon_crawler`.

## How to work with the engine
- **The MCP server** is the way to see and drive the game: `./voxelith --mcp --project projects/dungeon_crawler --threads 3` (`.mcp.json` is set up for Claude Code; docs/MCP.md lists every tool: screenshots from any camera,
  scripted play, Lua, status, editing, world generation tools, recordings ...). Without a client of your own, `tools/voxelith_client.py` does the same from Python (see its docstring).
- **No display on this machine**: the engine runs headless (`--headless`, offscreen rendering to PNG; the MCP `screenshot` tool). There is no window and no keyboard: you test play with scripts
  (`--script "fwd:300,turn:90,..."`, the MCP `run_script`) and look at screenshots. **Put the pictures you want the user to see in `~/share`** (any name; they are looked at from another machine).
- **Look at your work.** Take a screenshot after every visible change; a game that was never looked at is broken. Check the log (`status`, `log` tools) for script errors and warnings after every run.
- Level scripts are Lua (docs/LUA_API.md); content is data (CSV / JSON tables), models are `.vxm` (voxel models; `tools/make_prefabs.py` shows how to generate them from code, the MCP / editor can paint and
  build too; MagicaVoxel `.vox` files import). The world can be authored by hand (`edit.*`, prefabs) or generated (biomes, rules, features, creatures, caves: docs/WORLD_GEN.md) or both.
- The simulation is deterministic (fixed 60 Hz, integer world coordinates, seeded RNG): use the engine's own random / time, never the C library's. A recording (`--record`) replays to the same hash; a replay
  is the best regression test of a game, record one when something works.
- Performance matters: a frame is 16 ms. If a scene is slow, the `status` tool shows the numbers; that is a finding too.

## The machine
- User `claude`, no sudo, no docker, no system compiler. **Use at most 8 of the 16 threads and 14 GB RAM** (other services run here; `--threads 3` for the engine is plenty). No heavy parallel work.
- GitHub: the user permitted pushing to `git@github.com:Xaven89/dungeon-crawler.git` (private, SSH key of this machine); no token, no `gh`. Commit on `main`, small commits, one topic each, always with a commit message; push at milestones, fast-forward only; never add credentials. Keep `CHANGELOG.md` current: a section per version, tag `vX.Y.Z`.
- Do not touch `/mnt/data/projects/voxelith` (the engine's source), `/mnt/data/projects/voxel-game` or the workspace folder. You do not need the engine's source: if the engine is wrong, say so in `ENGINE_FEEDBACK.md`.
- Never use `pkill -f` or `pgrep -f` with a pattern that appears in your own command line (it kills your own shell).
- Never leave generated files in git: world stores (`*.vxs`), recordings, caches (`.gitignore` has them).

## How to report
Keep a running design doc of the game in `GAME.md` (what exists, how to run it, what is next) and update it as you go, so that another session can continue. When something is finished, say what you ran and saw, and what you did not check.
