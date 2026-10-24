#!/usr/bin/env python3
"""The per-cell walkability validator of the big floors (P1): the shells of the region hook (game/gen/shell.lua) are generated into a scratch world by the engine's flood_region (no player, no streaming) and
every EDGE of the plan is flooded in a box of its two cells: nothing standable may stay unreached except pieces of artery strips (those belong to the artery); every cell with an artery door is flooded with the strip.
usage: tools/p1_validate.py [SEEDS ...] [--floor N] [--first-only]   (world seeds; default 1 2 3; runs projects/dc_p1: tools/p1_sync.sh first)"""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import argparse
ap = argparse.ArgumentParser(); ap.add_argument("seeds", nargs="*", type=int); ap.add_argument("--floor", type=int, default=1)
ns = ap.parse_args()
seeds, fl = ns.seeds or [1, 2, 3], ns.floor
Y0, Y1 = 100, 330
PLAN = """
local CG = cellgen_make(cellgen_hash_from(worldgen.hash))
local ctx = CG.new(0, %d, 'small')
local P = CG.params(%d, 'small')
print('P', P.W, P.H)
for cj = 0, P.H - 1 do for ci = 0, P.W - 1 do
  local c = CG.cell(ctx, ci, cj)
  local r = c.room
  local o = {}
  for _, d in ipairs({'E','S','W','N'}) do o[#o + 1] = tostring(c.open[d]) .. ':' .. tostring(c.door and c.door[d]) end
  print('C', ci, cj, c.role, tostring(c.theme), r and r.x or -1, r and r.z or -1, r and r.w or -1, r and r.d or -1, table.concat(o, ' '))
end end
""" % (fl, fl)

def flood(v, lo_m, hi_m, frm_m):
    """boxes in metres relative to the floor's origin (x = 0, z = floor band start) -> the engine's answer"""
    bz = (fl * 32 + 2) * 32.0
    lo = [int(lo_m[0] * 16), Y0, int((bz + lo_m[1]) * 16)]
    hi = [int(hi_m[0] * 16) - 1, Y1, int((bz + hi_m[1]) * 16) - 1]
    return v.tool("flood_region", min=lo, max=hi, **{"from": [int(frm_m[0] * 16), 128, int((bz + frm_m[1]) * 16)]}), lo, hi

def shrunk(lo, hi, W, H, keep=""):
    """a box (metres, x0 z0 / x1 z1) minus the 4.5 m next to every block border line it touches (the artery strips are checked by the artery door check), except on the sides in `keep`"""
    lo, hi = list(lo), list(hi)
    if lo[0] % 256 == 0 and "W" not in keep: lo[0] += 4.5
    if hi[0] % 256 == 0 and "E" not in keep: hi[0] -= 4.5
    if lo[1] % 256 == 0 and "N" not in keep: lo[1] += 4.5
    if hi[1] % 256 == 0 and "S" not in keep: hi[1] -= 4.5
    return lo, hi

bad_total = 0
for seed in seeds:
    t0 = time.time()
    if "cfg" not in globals(): cfg = open("projects/dc_p1/project.cfg").read()
    import re
    open("projects/dc_p1/project.cfg", "w").write(re.sub(r"(?m)^seed\s*=.*$", "seed = %d" % seed, cfg))   # the world seed is the project's (--seed does not override it)
    with Voxelith(["--project", "projects/dc_p1", "--threads", "3"]) as v:
        v.step(10)
        out = v.lua(PLAN, ticks=0)["output"]
        W, H = [int(x) for x in out[0].split("\t")[1:3]]
        cells = {}
        for ln in out[1:]:
            p = ln.split("\t")
            ci, cj = int(p[1]), int(p[2])
            sides = {}
            for d, tok in zip("ESWN", p[9].split(" ")):
                k, dr = tok.split(":")
                sides[d] = (None if k == "nil" else k, None if dr == "nil" else float(dr))
            cells[(ci, cj)] = dict(role=p[3], theme=p[4], room=[float(x) for x in p[5:9]], sides=sides)
        problems = []
        checks = 0
        def check(label, lo_m, hi_m, frm_m):
            global checks
            checks += 1
            r, lo, hi = flood(v, lo_m, hi_m, frm_m)
            if r["unknown_columns"]: problems.append("%s: %d unknown columns" % (label, r["unknown_columns"])); return
            if r["standable"] == 0: problems.append("%s: nothing standable" % label); return
            if r["unreached"] == 0: return
            bz = (fl * 32 + 2) * 32.0
            real = [(isl["cells"], (isl["min"][0] / 16, isl["min"][2] / 16 - bz, isl["max"][0] / 16, isl["max"][2] / 16 - bz)) for isl in r["islands"]]
            if real or r.get("islands_cut"): problems.append("%s: %d unreached, islands %s" % (label, r["unreached"], real[:3]))
        for (ci, cj), c in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
            rm = c["room"]
            if rm[2] < 0: continue
            frm = (ci * 32 + rm[0] + 1.5, cj * 32 + rm[1] + 1.5)
            for d, (dx, dz) in (("E", (1, 0)), ("S", (0, 1))):
                kind, dr = c["sides"][d]
                if kind in (None, "artery", "internal") and not (kind == "internal"): continue
                ni, nj = ci + dx, cj + dz
                if (ni, nj) not in cells: continue
                x0, z0 = ci * 32, cj * 32
                lo, hi = shrunk((x0, z0), (x0 + 32 * (1 + dx), z0 + 32 * (1 + dz)), W, H)
                check("c%d_%d -%s- c%d_%d (%s)" % (ci, cj, d, ni, nj, kind), lo, hi, frm)
            for d in "ESWN":
                kind, dr = c["sides"][d]
                if kind != "artery": continue
                x0, z0 = ci * 32, cj * 32
                lo = [x0, z0]; hi = [x0 + 32, z0 + 32]
                if d == "E": hi[0] += 5
                if d == "W": lo[0] -= 5
                if d == "S": hi[1] += 5
                if d == "N": lo[1] -= 5
                lo, hi = shrunk(lo, hi, W, H, keep=d)
                check("c%d_%d artery door %s" % (ci, cj, d), lo, hi, frm)
        print("seed %d floor %d: %d checks, %d problems, %.0f s" % (seed, fl, checks, len(problems), time.time() - t0))
        for p in problems[:12]: print("   ", p)
        bad_total += len(problems)
open("projects/dc_p1/project.cfg", "w").write(cfg)   # the seed of the project again
print("problems:", bad_total)
sys.exit(1 if bad_total else 0)
