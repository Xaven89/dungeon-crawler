#!/usr/bin/env python3
"""Pictures of floor 4, the Iron Tangle -> ~/share/big_floors_p7/. usage: tools/p7_pictures.py [SEED] [--tag NAME]
Each view: (name, eye, target) in floor metres (x, y above the floor of level 0, z)."""
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
seed = int(args_[0]) if args_ and args_[0].isdigit() else 4242
tag = opt("--tag", "")
BZ = 4 * 1024 + 64
SH = os.path.expanduser("~/share/big_floors_p7"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
VIEWS = [
    ("hub_s_arrival", (80, 1.7, 138), (80, 1.2, 100), (80, 138)),
    ("hub_s_platform_side", (68, 1.7, 137), (92, 1.2, 145), (68, 137)),
    ("tunnel_west", (60, 1.7, 143), (20, 1.2, 144), (60, 143)),
    ("corner_sw", (28, 2.0, 138), (10, 1.0, 152), (28, 138)),
    ("hub_w", (10, 1.7, 70), (16, 1.2, 100), (10, 70)),
    ("yellow_y1", (36, 1.7, 73), (62, 1.0, 80), (36, 73)),
    ("centre_lower", (72, 1.7, 72), (90, 1.0, 86), (72, 72)),
    ("centre_upper", (74, 9.7, 90), (84, 9.5, 68), (74, 90)),
    ("blue_b1_stair", (80, 1.7, 34), (80, 6, 46), (80, 34)),
]
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 100000; Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0", 0)
    for name, eye, target, standat in VIEWS:
        ex, ey, ez = eye; tx, ty, tz = target
        L(v, "local G=Game; player.hand_model(nil); player.model(nil); player.teleport(G.mx(%f), G.my(%f), G.mz(%f), { wait = true })" % (standat[0], 0.1 if ey < 5 else 8.1, standat[1]), 200)
        v.screenshot(os.path.join(SH, "%s%s.png" % (tag, name)), hud=False, settle=30, eye=[ex, 8 + ey, BZ + ez], target=[tx, 8 + ty, BZ + tz], fov=85)
    print("hook", json.dumps(v.tool("status")["world"].get("hook")))
