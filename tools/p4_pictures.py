#!/usr/bin/env python3
"""Pictures of floor 3 (the over-city) in the running game -> ~/share/big_floors_p4/: a village square by day, at dusk, at night and at dawn, a pub, a locator stone, a ruin street, the park,
the map with the clock and the quest. usage: tools/p4_pictures.py [SEED]"""
import os, sys, json, glob, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
for p in glob.glob('/tmp/descent_scratch.vxs*'): (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
seed = sys.argv[1] if len(sys.argv) > 1 else "1"
SH = os.path.expanduser("~/share/big_floors_p4"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
BZ = 3 * 1024 + 64
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", seed]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.run.begin_floor(3)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.run.cur().floor_ticks = 10000000; Game.state.hp = 99999", 0)
    def tp(x, z):
        L(v, "player.teleport(Game.mx(%f), Game.my(0.1), Game.mz(%f))" % (x, z), 400)
    def shot(name, ex, ey, ez, tx, ty, tz, hud=False, settle=300, fov=85):
        v.screenshot(os.path.join(SH, name + ".png"), hud=hud, settle=settle, eye=[ex, 25.06 + ey, BZ + ez], target=[tx, 25.06 + ty, BZ + tz], fov=fov)
    def sky_at(t):
        L(v, "Game.gen.overcity.fixed = %f" % t, 0); v.step(130)
    # the first village
    vil = L(v, """local CG, H = Game.floorgen.cg(); local P = Game.floorgen.layout
for _, id in ipairs(P.order) do local r = P.rooms[id]
  if r.theme == 'village' then local sup = CG.super_of(P.ctx, r.ci, r.cj); print(sup.ci, sup.cj); return end end""", 0)
    print("village", vil)
    oci, ocj = [int(x) for x in vil[0].split("\t")]
    ox, oz = oci * 32, ocj * 32
    tp(ox + 31, oz + 30)
    plan = L(v, "local H = select(2, Game.floorgen.cg()); local pl = deco_village_plan(function(salt) return deco_rng(H, 3, %d, %d, salt or 1) end); for _, b in ipairs(pl.buildings) do print(b.kind, b.x0, b.z0, b.x1, b.z1, b.door.side, b.door.pos) end" % (oci, ocj), 0)
    print(plan)
    for name, t in (("day", 0.25), ("dusk", 0.49), ("night", 0.80), ("dawn", 0.03)):
        sky_at(t)
        shot("village_square_" + name, ox + 28.5, 1.8, oz + 27.5, ox + 33, 1.2, oz + 34)
        if name == "night": shot("village_square_night_hud", ox + 28.5, 1.8, oz + 27.5, ox + 33, 1.2, oz + 34, hud=True)
    sky_at(0.25)
    # the pub (the building of kind pub)
    for line in plan:
        k = line.split("\t")
        if k[0] == "pub":
            x0, z0, x1, z1 = [float(a) for a in k[1:5]]
            side = k[5]
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            ex = (x1 + 3.5) if side == "E" else (x0 - 3.5)
            tp(ox + ex, oz + cz)
            shot("village_pub_door", ox + ex, 1.8, oz + cz + 1.5, ox + (x0 + x1) / 2, 1.2, oz + cz)
            tp(ox + cx, oz + cz + 1)
            shot("village_pub_inside", ox + cx + (3 if side == "W" else -3), 1.9, oz + z1 - 1.2, ox + cx, 1.0, oz + z0 + 1.5)
    # a gate and a guard, a locator stone
    shot("village_stone", ox + 30, 1.6, oz + 29.5, ox + 25.8, 1.4, oz + 25.8)
    # the park
    pk = L(v, "local P = Game.floorgen.layout; local r = P.ring_list[1]; if r then print(r.ox, r.oz) else print('none') end", 0)[0].split("\t")
    if pk[0] != "none":
        px, pz = float(pk[0]), float(pk[1])
        tp(px + 32, pz + 56)
        shot("park_gate", px + 24, 1.7, pz + 56, px + 32, 1.4, pz + 50)
        shot("park_rotunda_day", px + 32, 1.7, pz + 40, px + 32, 1.0, pz + 27)
    # a ruin street at night
    st = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.cellrole == 'room' then print(id, r.x, r.z, r.w, r.d) return end end", 0)[0].split("\t")
    rx, rz, rw, rd = [float(x) for x in st[1:5]]
    sky_at(0.8); tp(rx + rw / 2, rz + rd / 2 - 3)
    shot("ruin_room_night", rx + 2, 1.8, rz + 2, rx + rw / 2, 1.0, rz + rd / 2)
    sky_at(0.3)
    shot("ruin_room_day", rx + 2, 1.8, rz + 2, rx + rw / 2, 1.0, rz + rd / 2)
    st = v.tool("status")
    print("render", json.dumps(st["render"]), "hook", json.dumps(st["world"].get("hook")))
    lg = json.dumps(v.tool("log"))
    print([x[:300] for x in lg.split("\\n") if "failed" in x or "rror" in x][:6])
