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
    def mean_brightness(path):                  # a crude mean of an 8-bit RGB(A) PNG (a black picture is a view that was not ready, not a view of a black room)
        import zlib, struct
        d = open(path, "rb").read(); i = 8; idat = b""; w = h = ct = 0
        while i < len(d):
            n, = struct.unpack(">I", d[i:i + 4]); t = d[i + 4:i + 8]; c = d[i + 8:i + 8 + n]
            if t == b"IHDR": w, h, _, ct = struct.unpack(">IIBB", c[:10])
            if t == b"IDAT": idat += c
            i += 12 + n
        raw = zlib.decompress(idat); bpp = {2: 3, 6: 4}.get(ct, 3); stride = w * bpp + 1; tot = cnt = 0
        for y in range(0, h, 16):
            row = raw[y * stride + 1:(y + 1) * stride]; tot += sum(row[::bpp * 8]); cnt += len(row[::bpp * 8])
        return tot / max(1, cnt)
    EXPO = { "hall_f1": 5.2, "hall_f5": 4.8, "hall_f6": 6.1, "hall_f7": 7.4, "hall_f8": 4.1, "corridor_f2": 4.9, "borough_f2": 7.1, "hub_f4": 4.1,
             "square_f3_day": 0.9, "street_f3_day": 0.9, "meadow_f3": 0.9, "pub_f3_inside": 0.9, "square_f3_night": 5.6 }       # (voxel-art, palette/E19b_rules.md: from mean luminance, approximate) used with --fixed
    def shot(name, bz, y0, ex, ey, ez, tx, ty, tz, fov=85, settle=300):
        for attempt in range(3):               # (the first picture after a new binary or a cold start has come out black: wait and take it again)
            if "--fixed" in sys.argv and name in EXPO: L(v, "sky.set{ exposure = %s }" % EXPO[name], 2)          # (a fixed exposure per view so before / after are comparable; auto again afterwards)
            v.screenshot(os.path.join(SH, name + ".png"), hud=False, settle=settle + attempt * 200, eye=[ex, y0 + ey, bz + ez], target=[tx, y0 + ty, bz + tz], fov=fov)
            if "--fixed" in sys.argv and name in EXPO: L(v, "sky.set{ exposure = false }", 2)
            if mean_brightness(os.path.join(SH, name + ".png")) > 6: break
            print("  %s was black (attempt %d): again" % (name, attempt + 1))
    if "hall_f1" in only:                       # floor 1: the first hall, from its north-west corner toward the middle
        r = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.theme == 'hall' and r.w >= 14 and r.d >= 14 then print(id, r.x, r.z, r.w, r.d); break end end", 0)[0].split("\t")
        rid, x, z, w, d = r[0], *[float(t) for t in r[1:5]]
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 400)
        shot("hall_f1", 1 * 1024 + 64, 8, x + 2.2, 3.0, z + 2.2, x + w / 2, 0.9, z + d / 2, fov=90)
    if "dead_goblin_f1" in only:                # a goblin killed 90 ticks ago: lying (die clip), not standing in its gore (the player's own camera height, 3 m away)
        r = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.theme == 'hall' and r.w >= 14 and r.d >= 14 then print(id, r.x, r.z, r.w, r.d); break end end", 0)[0].split("\t")
        rid, x, z, w, d = r[0], *[float(t) for t in r[1:5]]
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 400)
        cx, cz = L(v, "local G=Game; local px, py, pz = player.pos(); local lx, ly, lz = G.to_local(px, py, pz); print(lx, lz)", 0)[0].split("\t")
        cx, cz = float(cx), float(cz)
        L(v, "local G=Game; G.dg = G.enemies.spawn('goblin', %f, 0, %f, { room = '%s' }); G.state.flags.god = true" % (cx + 3.0, cz, rid), 30)
        L(v, "local G=Game; G.enemies.kill(G.dg, { source = 'test' })", 90)
        shot("dead_goblin_f1", 1 * 1024 + 64, 8, cx, 1.7, cz, cx + 3.0, 0.4, cz, fov=70)
    for name, theme in (("ballroom_f1", "ballroom"), ("flooded_f1", "flooded"), ("library_f1", "library"), ("safe_f1", "safe"), ("rest_f1", "rest")):      # single-room materials (polished_marble, wet_flagstone): judged on their own rooms, from a corner
        if name in only:
            r = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.theme == '%s' then print(id, r.x, r.z, r.w, r.d); break end end" % theme, 0)
            if not r: print(name, "no such room on floor 1 of this seed"); continue
            rid, x, z, w, d = r[0].split("\t")[0], *[float(t) for t in r[0].split("\t")[1:5]]
            L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 400)
            shot(name, 1 * 1024 + 64, 8, x + 2.2, 1.9, z + 2.2, x + w / 2, 0.6, z + d / 2, fov=90)
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
    if "square_f3_day" in only or "pub_f3_inside" in only or "meadow_f3" in only or "street_f3_day" in only or "square_f3_night" in only:
        new_floor(v, 3); BZ = 3 * 1024 + 64
        vil = L(v, "local CG, H = Game.floorgen.cg(); local P = Game.floorgen.layout\nfor _, id in ipairs(P.order) do local r = P.rooms[id]\n  if r.theme == 'village' then local sup = CG.super_of(P.ctx, r.ci, r.cj); print(sup.ci, sup.cj); return end end", 0)
        oci, ocj = [int(x) for x in vil[0].split("\t")]; ox, oz = oci * 32, ocj * 32
        tp(ox + 31, oz + 30, wait=400)
        L(v, "Game.gen.overcity.fixed = %s" % opt("--time", "0.25"), 0); v.step(130)
        if "square_f3_day" in only: shot("square_f3_day", BZ, 25.06, ox + 28.5, 1.8, oz + 27.5, ox + 33, 1.2, oz + 34)
        if "meadow_f3" in only:                 # outside the village: the plain's grass (not one of the five fixed views)
            tp(8, 176, wait=400); v.step(60); shot("meadow_f3", BZ, 25.06, 3, 14.0, 176, -70, 1.0, 176, settle=200)       # over the west wall of the ruin onto the plain outside
        if "square_f3_night" in only:
            L(v, "Game.gen.overcity.fixed = 0.80", 0); v.step(200); shot("square_f3_night", BZ, 25.06, ox + 28.5, 1.8, oz + 27.5, ox + 33, 1.2, oz + 34); L(v, "Game.gen.overcity.fixed = %s" % opt("--time", "0.25"), 0); v.step(130)
        if "street_f3_day" in only: shot("street_f3_day", BZ, 25.06, ox + 32, 1.7, oz + 7, ox + 32, 1.6, oz + 30)       # the lane between two slots, looking at the square (voxel-art bucket D)
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
# (the views of the floors above run in the order of their floors: the sessions only ever go DOWN, except borough_f2 which begins floor 2 again)
    def hall_view(fl, name):                    # the first hall of the floor, from its north-west corner toward the middle
        r = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.theme == 'hall' and r.w >= 14 and r.d >= 14 then print(id, r.x, r.z, r.w, r.d); break end end", 0)[0].split("\t")
        rid, x, z, w, d = r[0], *[float(t) for t in r[1:5]]
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 400)
        shot(name, fl * 1024 + 64, 8, x + 2.2, 3.0, z + 2.2, x + w / 2, 0.9, z + d / 2, fov=90)
        if name + "_wall" in only: shot(name + "_wall", fl * 1024 + 64, 8, x + 3.0, 1.7, z + d / 2, x, 1.5, z + d / 2, fov=70)           # the bump reads within 2-6 m: a wall at 3 m
        if name + "_floor" in only: shot(name + "_floor", fl * 1024 + 64, 8, x + w / 2, 1.7, z + d / 2, x + w / 2 + 2.5, 0.0, z + d / 2, fov=70)   # and the floor
    def corridor_view(fl, name):                # an artery: the 6 m strip between blocks, looking along it
        a = L(v, """local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]
  for _, d in ipairs(P.doors[id] or {}) do if d.kind == 'artery' then print(id, r.ci, r.cj, d.side, d.pos); return end end end""", 0)[0].split("\t")
        rid, ci, cj, side, pos = a[0], int(a[1]), int(a[2]), a[3], float(a[4])
        if side in ("E", "W"):
            xb = (ci + (1 if side == "E" else 0)) * 32; ex, ez, tx, tz = xb, cj * 32 + pos - 12, xb, cj * 32 + pos + 30
        else:
            zb = (cj + (1 if side == "S" else 0)) * 32; ex, ez, tx, tz = ci * 32 + pos - 12, zb, ci * 32 + pos + 30, zb
        tp(ex, ez, wait=400)
        shot(name, fl * 1024 + 64, 8, ex, 1.7, ez, tx, 1.5, tz)
    for fl in (5, 6, 7, 8):
        if ("hall_f%d" % fl) in only or ("corridor_f%d" % fl) in only or ("hall_f%d_wall" % fl) in only:
            new_floor(v, fl)
            if ("hall_f%d" % fl) in only or ("hall_f%d_wall" % fl) in only: hall_view(fl, "hall_f%d" % fl)
            if ("corridor_f%d" % fl) in only: corridor_view(fl, "corridor_f%d" % fl)
    if "borough_f2" in only or "rotunda_f2" in only:     # the borough fortress of floor 2: the rings seen from the entrance, the rotunda in the middle
        new_floor(v, 2)
        pk = L(v, "local P = Game.floorgen.layout; local r = P.ring_list and P.ring_list[1]; if r then print(r.ox, r.oz) else print('none') end", 0)[0].split("\t")
        print("borough", pk)
        if pk[0] != "none":
            px, pz = float(pk[0]), float(pk[1])
            L(v, "Game.gen.rules.cur.night = false", 0)          # (the rule of the floor may be NIGHT SHIFT: this view judges the palette, not the rule)
            if "borough_f2" in only:                # inside the outer ring corridor (south side), looking along it at the lamp (g.c1 = 17.1 from the middle)
                tp(px + 22, pz + 49.1, wait=500); v.step(60)
                shot("borough_f2", 2 * 1024 + 64, 8, px + 22, 1.7, pz + 49.1, px + 40, 1.8, pz + 49.1, settle=200)
            if "rotunda_f2" in only:
                tp(px + 32, pz + 44, wait=500); v.step(60)
                shot("rotunda_f2", 2 * 1024 + 64, 8, px + 32, 1.7, pz + 44, px + 32, 1.5, pz + 32, settle=200)
print("pictures in", SH)
