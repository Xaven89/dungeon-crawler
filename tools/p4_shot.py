#!/usr/bin/env python3
"""Pictures of floor 3 (the open-air over-city) from the hook alone (projects/dc_p1): tools/p4_shot.py SEED NAME EX EY EZ TX TY TZ [--time T] [--fov F]
Coordinates are floor-local metres (x east, z south) with y the world height in metres (the ground is at 25 m); --time is the sky clock (0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight)."""
import os, sys, glob, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
for p in glob.glob('/tmp/descent_scratch.vxs*'): (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
a = [x for x in sys.argv[1:] if not x.startswith("--")]
seed, name = a[0], a[1]
ex, ey, ez, tx, ty, tz = [float(x) for x in a[2:8]]
t = float(sys.argv[sys.argv.index("--time") + 1]) if "--time" in sys.argv else 0.3
fov = float(sys.argv[sys.argv.index("--fov") + 1]) if "--fov" in sys.argv else 80
BZ = 3 * 1024 + 64
out = os.path.expanduser("~/share/big_floors_p4"); os.makedirs(out, exist_ok=True)
with Voxelith(["--project", "projects/dc_p1", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", seed]) as v:
    v.step(20)
    v.lua("Game.screen = nil; Game.frozen_at = nil; sky.set{ time = %f, speed = 0, tint = {1.15, 0.85, 0.8}, fog = 1.5 }; player.teleport(%f, 27, %f)" % (t, ex, BZ + ez), ticks=1)
    v.step(300)
    v.screenshot(os.path.join(out, name + ".png"), eye=[ex, ey, BZ + ez], target=[tx, ty, BZ + tz], fov=fov, settle=200)
