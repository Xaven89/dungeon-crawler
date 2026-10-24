#!/usr/bin/env python3
"""Pictures of the furnished rooms (P6d) -> ~/share/big_floors_p6d/: the first room of each theme given (default hall library crypt depot) on a floor, from a corner and from the door side,
with the monsters on their spots and without. usage: tools/p6d_pictures.py [SEED] [--floor N] [--themes a,b] [--tag NAME]"""
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
seed = int(args_[0]) if args_ and args_[0].isdigit() and "--floor" not in sys.argv[1:2] else 4242
FLOOR = int(opt("--floor", "1")); themes = opt("--themes", "hall,library,crypt,depot").split(","); tag = opt("--tag", "")
BZ = FLOOR * 1024 + 64
SH = os.path.expanduser("~/share/big_floors_p6d"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    if FLOOR != 1:
        L(v, "Game.run.begin_floor(%d)" % FLOOR, 2); v.step(400); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 100000; Game.state.flags.god = true", 0)
    for th in themes:
        r = L(v, "local P = Game.floorgen.layout; for _, id in ipairs(P.order) do local r = P.rooms[id]; if r.theme == '%s' and r.w >= 14 and r.d >= 14 then print(id, r.x, r.z, r.w, r.d, #(P.doors[id] or {})); break end end" % th, 0)
        if not r: print(th, "no room"); continue_ = True; continue
        rid, x, z, w, d, nd = r[0].split("\t"); x, z, w, d = float(x), float(z), float(w), float(d)
        print(th, rid, x, z, w, d, "doors", nd)
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 400)
        lay = L(v, "local P = Game.floorgen.layout; local r = P.rooms['%s']; local ctx = { mk = function(salt) return deco_rng(Game.floorgen.cg and select(2, Game.floorgen.cg()), %d, r.ci, r.cj, salt or 1) end, floor = %d }; local lay = deco_layout(r.theme, r.info.room, Game.floorgen.local_doors(r), ctx.mk, %d); local c = {}; for _, it in ipairs(lay.items) do c[it.id] = (c[it.id] or 0) + 1 end; local t = {}; for k, n in pairs(c) do t[#t+1] = k .. '=' .. n end; table.sort(t); print(table.concat(t, ' '), #lay.spots .. ' spots')" % (rid, FLOOR, FLOOR, FLOOR), 0)
        print("  layout:", lay)
        cx, cz = x + w / 2, z + d / 2
        for name, (ex, ez) in {"corner": (x + 2.2, z + 2.2), "corner2": (x + w - 2.2, z + d - 2.2)}.items():
            L(v, "local G=Game; player.teleport(G.mx(%f), G.my(0.1), G.mz(%f))" % (ex, ez), 90)
            v.screenshot(os.path.join(SH, "%s%s_%s_f%d_%s.png" % (tag, th, rid, FLOOR, name)), hud=False, settle=40, eye=[ex, 8 + 3.0, BZ + ez], target=[cx, 8 + 0.9, BZ + cz], fov=90)
