#!/usr/bin/env python3
"""The contract of the big floors (game/gen/contract.lua) over many seeds and floors, in the engine's Lua through the MCP (no world is touched).
usage: tools/plan_check.py [SEEDS=200] [--floors 1,2,3,5,6,7,8] [--setting small|large] [--first N] [--hash mixer|world] [--run N]  (world = the engine's worldgen.hash through the adapter, as in the hook)
Prints violations by item (with a few examples) and the statistics (largest distance to a safe room, dead ends, stairwells ...)."""
import os, sys, time, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
args = [a for a in sys.argv[1:] if not a.startswith("--")]
seeds = int(args[0]) if args else 200
def opt(name, default):
    if name in sys.argv:
        i = sys.argv.index(name); return sys.argv[i + 1]
    return default
floors = [int(x) for x in opt("--floors", "1,2,3,5,6,7,8").split(",")]
setting = opt("--setting", "small")
run = int(opt("--run", "0"))
maker = "Game.gen.cell.make_cellgen(Game.gen.cell.hash_from(worldgen.hash, %d))" % run if (opt("--hash", "mixer") == "world" or run) else "Game.gen.cell.make_cellgen()"
first = int(opt("--first", "1"))
by_item, examples, stats = collections.Counter(), collections.defaultdict(list), collections.defaultdict(list)
t0 = time.time()
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3"]) as v:
    v.step(5)
    for fl in floors:
        batch = 3 if setting == "large" else 10
        for s0 in range(first, first + seeds, batch):
            code = """
local CG = %s
for seed = %d, %d do
  local plan = CG.plan(seed, %d, '%s')
  if plan then
    local r = Game.gen.contract.check(plan, CG)
    for _, x in ipairs(r.violations) do print('V', x.item, seed, x.text) end
    local s = r.stats
    print('S', seed, s.safe_max or 0, s.safe_over3 or 0, s.dead or 0, s.rooms or 0, s.stairs or 0, s.free or 0, s.alleys or 0, string.format('%%.2f', s.threat_worst or 0), s.courtyard_exits_min or -1, s.nodes or 0)
  end
end""" % (maker, s0, min(s0 + batch - 1, first + seeds - 1), fl, setting)
            out = v.lua(code, ticks=0)["output"]
            for line in out:
                p = line.split("\t")
                if p[0] == "V":
                    by_item[(fl, int(p[1]))] += 1
                    if len(examples[(fl, int(p[1]))]) < 3: examples[(fl, int(p[1]))].append("seed %s: %s" % (p[2], p[3]))
                elif p[0] == "S":
                    stats[fl].append([float(x) for x in p[2:]])
print("seeds %d..%d, floors %s, setting %s, %.0f s" % (first, first + seeds - 1, floors, setting, time.time() - t0))
total = 0
for k in sorted(by_item):
    total += by_item[k]
    print("floor %d item %2d: %5d   e.g. %s" % (k[0], k[1], by_item[k], " | ".join(examples[k])[:300]))
print("violations:", total)
for fl in floors:
    st = stats[fl]
    if not st: continue
    n = len(st)
    col = lambda i: [r[i] for r in st]
    print("floor %d: n=%d  safe_max max %d avg %.1f  >3 steps avg %.1f  dead ends avg %.1f of %.0f rooms  stairs min %d  free min %d  alleys avg %.1f  threat worst %.2f  courtyard exits min %d  nodes %d" % (
        fl, n, max(col(0)), sum(col(0)) / n, sum(col(1)) / n, sum(col(2)) / n, sum(col(3)) / n, min(col(4)), min(col(5)), sum(col(6)) / n, max(col(7)), min(col(8)), col(9)[0]))
