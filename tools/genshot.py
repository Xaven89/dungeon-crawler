#!/usr/bin/env python3
"""Builds a generated floor on a COPY of the project and takes a picture of every room (and the plan as text).
usage: tools/genshot.py SEED FLOOR [THEME]   (pictures into ~/share/gen/<seed>_<floor>/)"""
import os, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
seed, floor_n = int(sys.argv[1]), int(sys.argv[2])
theme = sys.argv[3] if len(sys.argv) > 3 else None          # a theme name: every plain room of the floor becomes that theme, only those are photographed
out = os.path.expanduser("~/share/gen/%d_%d%s" % (seed, floor_n, ("_" + theme) if theme else ""))
os.makedirs(out, exist_ok=True)
copy = os.path.join(ROOT, "projects", "dc_genshot")
shutil.rmtree(copy, ignore_errors=True)
shutil.copytree(os.path.join(ROOT, "projects", "dungeon_crawler"), copy)
OX, OY, OZ = 67.0, 8.0, 53.0
with Voxelith(["--project", copy, "--threads", "3"]) as v:
    v.step(30)
    v.lua("Game.player.pick_class('janitor'); Game.state.hp = 99999", ticks=200)
    if theme: v.lua("Game.floorgen.force = %r" % theme, ticks=0)
    v.lua("Game.floorgen.start(%d, %d)" % (seed, floor_n), ticks=1)
    t = time.time()
    while True:
        r = v.lua("print(Game.floorgen.job and Game.floorgen.job.i or 'done')", ticks=20)["output"]
        if r[0] == "done" or time.time() - t > 120: break
    print("built in %.1f s" % (time.time() - t))
    print("\n".join(v.lua("print(Game.gen.layout.ascii(Game.floorgen.layout))", ticks=0)["output"]))
    rooms = v.lua("""for _, id in ipairs(Game.floorgen.layout.order) do local r = Game.floorgen.layout.rooms[id]; print(id, r.x, r.z, r.w, r.d, r.h, r.role, r.theme, r.name) end""", ticks=0)["output"]
    for line in rooms:
        id, x, z, w, d, h, role, theme, name = line.split("\t")
        x, z, w, d, h = float(x), float(z), float(w), float(d), float(h)
        if theme and theme not in line.split("\t")[7]: continue
        eye = [OX + x + w * 0.5, OY + min(h - 1.5, 3.2), OZ + z + 1.0]
        tgt = [OX + x + w * 0.45, OY + 0.8, OZ + z + d * 0.75]
        v.screenshot(os.path.join(out, "%s_%s_%s.png" % (id, role, theme)), eye=eye, target=tgt, fov=80, settle=25)
        print(line)
    print([l for l in v.log().splitlines() if "gen:" in l or "[error]" in l][-8:])
shutil.rmtree(copy, ignore_errors=True)
