#!/usr/bin/env python3
"""The region hook's cost (status.world.hook) while the player visits the rooms of a floor: tools/hook_cost.py [SEED] [--floor N] [--rooms N]
Prints regions computed, mean / max ms per region and the total; the budget is a few ms a region (the hook runs on the main thread)."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
args_ = [a for a in sys.argv[1:] if not a.startswith("--")]
def opt(n, d): return sys.argv[sys.argv.index(n) + 1] if n in sys.argv else d
seed = int(args_[0]) if args_ else 4242
FLOOR = int(opt("--floor", "1")); NR = int(opt("--rooms", "40"))
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    if FLOOR != 1:
        L(v, "Game.run.begin_floor(%d)" % FLOOR, 2); v.step(400); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0", 0)
    h0 = v.tool("status")["world"]["hook"]
    ids = L(v, "local P = Game.floorgen.layout; local t = {}; for _, id in ipairs(P.order) do t[#t+1] = id end; print(table.concat(t, ','))", 0)[0].split(",")
    step = max(1, len(ids) // NR)
    prev = 0
    for id in ids[::step][:NR]:
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; if c then player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true }) end" % id, 200)
        rm = v.tool("status")["world"]["hook"]["recent_max_ms"]
        if rm > prev + 0.5 and rm > 12:
            th = L(v, "local r = Game.floorgen.layout.rooms['%s']; print(r.theme, r.w, r.d)" % id, 0)
            print("  spike %.1f ms after the visit to %s (%s)" % (rm, id, th))
        prev = rm
    h = v.tool("status")["world"]["hook"]
    n = h["regions_computed"] - h0["regions_computed"]
    print("floor %d: %d regions, mean %.2f ms, total %.0f ms, max %.1f ms, recent_max %.1f ms, failed %d" % (FLOOR, n, (h["total_ms"] - h0["total_ms"]) / max(1, n), h["total_ms"] - h0["total_ms"], h["max_ms"], h["recent_max_ms"], h["failed"]))
