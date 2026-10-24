#!/usr/bin/env python3
"""The fixed set of views for the art and polish pass (reviewer's audit ~/share/polish-audit.md): floor-1 hall, floor-2 corridor (an artery), over-city square by day, pub inside, floor-4 hub (the game's own choice).
Every bucket takes the same views before and after: usage: tools/polish_pictures.py BUCKET [--seed 4242] [--only a,b]  -> ~/share/polish/BUCKET/<view>.png (BUCKET = before, A_palette, B_light, C_detail ...)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
def opt(n, d): return sys.argv[sys.argv.index(n) + 1] if n in sys.argv else d
bucket = [a for a in sys.argv[1:] if not a.startswith("--") and a != opt("--seed", "") and a != opt("--only", "")][0]
seed = opt("--seed", "4242"); only = opt("--only", "hall_f1,corridor_f2,square_f3_day,pub_f3_inside,hub_f4").split(",")
SH = os.path.expanduser("~/share/polish/" + bucket); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
def new_floor(v, fl):
    L(v, "Game.run.begin_floor(%d)" % fl, 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 10000000; Game.state.flags.god = true; Game.state.hp = 99999; Game.floorgen.ENEMY_CAP = 0", 0)
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", seed]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 10000000; Game.state.flags.god = true; Game.state.hp = 99999; Game.floorgen.ENEMY_CAP = 0", 0)
    def tp(x, z, y=0.1, wait=300): L(v, "local G=Game; player.hand_model(nil); player.model(nil); player.teleport(G.mx(%f), G.my(%f), G.mz(%f), { wait = true })" % (x, y, z), wait)
    def shot(name, bz, y0, ex, ey, ez, tx, ty, tz, fov=85, settle=300):
        v.screenshot(os.path.join(SH, name + ".png"), hud=False, settle=settle, eye=[ex, y0 + ey, bz + ez], target=[tx, y0 + ty, bz + tz], fov=fov)
    if "hall_f1" in only:                       # floor 1: the first hall, from its north-west corner toward the middle
        r = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.theme == 'hall' and r.w >= 14 and r.d >= 14 then print(id, r.x, r.z, r.w, r.d); break end end", 0)[0].split("\t")
        rid, x, z, w, d = r[0], *[float(t) for t in r[1:5]]
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 400)
        shot("hall_f1", 1 * 1024 + 64, 8, x + 2.2, 3.0, z + 2.2, x + w / 2, 0.9, z + d / 2, fov=90)
    if "corridor_f2" in only:                   # floor 2: an artery (the 6 m wide strip between blocks), looking along it
        new_floor(v, 2)
        a = L(v, """local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]
  for _, d in ipairs(P.doors[id] or {}) do if d.kind == 'artery' then print(id, r.ci, r.cj, d.side, d.pos); return end end end""", 0)[0].split("\t")
        rid, ci, cj, side, pos = a[0], int(a[1]), int(a[2]), a[3], float(a[4])
        if side in ("E", "W"):
            xb = (ci + (1 if side == "E" else 0)) * 32; ex, ez, tx, tz = xb, cj * 32 + pos - 12, xb, cj * 32 + pos + 30
        else:
            zb = (cj + (1 if side == "S" else 0)) * 32; ex, ez, tx, tz = ci * 32 + pos - 12, zb, ci * 32 + pos + 30, zb
        print("artery", rid, side, ex, ez)
        tp(ex, ez, wait=400)
        shot("corridor_f2", 2 * 1024 + 64, 8, ex, 1.7, ez, tx, 1.5, tz)
    if "square_f3_day" in only or "pub_f3_inside" in only:
        new_floor(v, 3); BZ = 3 * 1024 + 64
        vil = L(v, "local CG, H = Game.floorgen.cg(); local P = Game.floorgen.layout\nfor _, id in ipairs(P.order) do local r = P.rooms[id]\n  if r.theme == 'village' then local sup = CG.super_of(P.ctx, r.ci, r.cj); print(sup.ci, sup.cj); return end end", 0)
        oci, ocj = [int(x) for x in vil[0].split("\t")]; ox, oz = oci * 32, ocj * 32
        tp(ox + 31, oz + 30, wait=400)
        L(v, "Game.gen.overcity.fixed = 0.25", 0); v.step(130)
        if "square_f3_day" in only: shot("square_f3_day", BZ, 25.06, ox + 28.5, 1.8, oz + 27.5, ox + 33, 1.2, oz + 34)
        if "pub_f3_inside" in only:
            plan = L(v, "local H = select(2, Game.floorgen.cg()); local pl = deco_village_plan(function(salt) return deco_rng(H, 3, %d, %d, salt or 1) end); for _, b in ipairs(pl.buildings) do print(b.kind, b.x0, b.z0, b.x1, b.z1, b.door.side, b.door.pos) end" % (oci, ocj), 0)
            for line in plan:
                k = line.split("\t")
                if k[0] == "pub":
                    x0, z0, x1, z1 = [float(a) for a in k[1:5]]; side = k[5]; cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
                    tp(ox + cx, oz + cz + 1, wait=400)
                    shot("pub_f3_inside", BZ, 25.06, ox + cx + (3 if side == "W" else -3), 1.9, oz + z1 - 1.2, ox + cx, 1.0, oz + z0 + 1.5)
                    break
    if "hub_f4" in only:                        # floor 4: the arrival hub from the platform (the game's choice: the floor with the most prop colours)
        new_floor(v, 4)
        tp(100, 201, wait=400)
        shot("hub_f4", 4 * 1024 + 64, 8, 100, 1.7, 201, 124, 1.2, 209, settle=300)
print("pictures in", SH)
