#!/usr/bin/env python3
"""ASCII dumps of the big-floor plan (game/gen/cell.lua) through the MCP: tools/plan_dump.py SEED FLOOR [OUTDIR] [--setting small|large]
Writes quadrant.txt (4x4 cells), block.txt (8x8), floor.txt (the whole floor) and stats.txt."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
args = [a for a in sys.argv[1:] if not a.startswith("--")]
seed, floor_ = int(args[0]), int(args[1])
out = args[2] if len(args) > 2 else os.path.expanduser("~/share/big_floors_p0")
setting = sys.argv[sys.argv.index("--setting") + 1] if "--setting" in sys.argv else "small"
os.makedirs(out, exist_ok=True)
LEGEND = """legend: one cell = 4 chars x 2 lines. @ arrival, S safe room, G guild, L lair, a antechamber, $ free stairwell, P prize, B borough ring, V village, K park,
. room (second letter = theme), c connector (hall), '::' alley (3 m, loop edges only), '##' artery (8 m) door, '--' / '|' wall, blank = hall opening (tree or loop or side hall)
"""
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3"]) as v:
    v.step(5)
    code = """
local CG = Game.gen.cell.make_cellgen()
local plan = CG.plan(%d, %d, '%s')
local r = Game.gen.contract.check(plan, CG)
print('Q'); print(CG.ascii(plan, 4, 0, 7, 3))
print('B'); print(CG.ascii(plan, 0, 0, 7, 7))
print('F'); print(CG.ascii(plan, 0, 0, plan.W - 1, plan.H - 1))
print('S'); for k, x in pairs(r.stats) do print(k, tostring(x)) end
for _, x in ipairs(r.violations) do print('V', x.item, x.text) end
""" % (seed, floor_, setting)
    lines = v.lua(code, ticks=0)["output"]
parts, cur = {}, None
for ln in lines:
    if ln in ("Q", "B", "F", "S"): cur = ln; parts[cur] = []
    elif cur: parts[cur].append(ln)
hdr = "seed %d floor %d setting %s\n%s\n" % (seed, floor_, setting, LEGEND)
for k, name in (("Q", "quadrant.txt"), ("B", "block.txt"), ("F", "floor.txt"), ("S", "stats.txt")):
    open(os.path.join(out, name), "w").write(hdr + "\n".join(parts.get(k, [])) + "\n")
print("wrote", out)
