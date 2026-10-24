#!/usr/bin/env python3
"""Pictures of the big floors' shells in the scratch project projects/dc_p1 (tools/p1_sync.sh copies the game there; project.cfg: terrain = biomes + the one-row table).
usage: tools/p1_shot.py FLOOR CI CJ [NAME] [--lights]  -> ~/share/big_floors_p1/NAME_*.png: from the room's corner toward its middle, and toward each open side. Temporary lights stand in for the P2 torches."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
args = [a for a in sys.argv[1:] if not a.startswith("--")]
fl, ci, cj = int(args[0]), int(args[1]), int(args[2])
name = args[3] if len(args) > 3 else "f%d_c%d_%d" % (fl, ci, cj)
SH = os.path.expanduser("~/share/big_floors_p1"); os.makedirs(SH, exist_ok=True)
BX, BZ = ci * 32.0, fl * 1024.0 + 64.0 + cj * 32.0
with Voxelith(["--project", "projects/dc_p1", "--threads", "3"]) as v:
    v.step(30)
    out = v.lua("""
local CG = cellgen_make(cellgen_hash_from(worldgen.hash))
local ctx = CG.new(0, %d, 'small')
local c = CG.cell(ctx, %d, %d)
local r = c.room
print('room', c.role, c.theme, r and r.x, r and r.z, r and r.w, r and r.d, r and r.h)
local s = {}
for d, k in pairs(c.open) do s[#s + 1] = d .. '=' .. k .. '@' .. tostring(c.door and c.door[d]) end
table.sort(s); print(table.concat(s, ' '))
""" % (fl, ci, cj), ticks=0)["output"]
    print("\n".join(out))
    p = out[0].split("\t")
    rx, rz, rw, rd, rh = [float(x) for x in p[3:8]]
    cx, cz = BX + rx + rw / 2, BZ + rz + rd / 2
    v.lua("Game.screen = nil; Game.frozen_at = nil; player.teleport(%f, 8.5, %f)" % (cx, cz), ticks=1)
    v.step(200)
    lights = "".join("emitter.create{ name = 'dbg%d', preset = 'campfire', pos = { %f, %f, %f }, light = { color = { 1, 0.85, 0.6 }, intensity = 30, reach = 18 } } " % (i, cx + dx, 12, cz + dz)
                     for i, (dx, dz) in enumerate([(-rw / 3, -rd / 3), (rw / 3, -rd / 3), (-rw / 3, rd / 3), (rw / 3, rd / 3)]))
    v.lua(lights, ticks=1)
    v.step(120)
    v.screenshot(SH + "/%s_corner.png" % name, eye=[BX + rx + 1.2, 10.5, BZ + rz + 1.2], target=[cx, 9, cz], fov=85)
    v.screenshot(SH + "/%s_corner2.png" % name, eye=[BX + rx + rw - 1.2, 10.5, BZ + rz + rd - 1.2], target=[cx, 9, cz], fov=85)
    print("pictures in", SH)
