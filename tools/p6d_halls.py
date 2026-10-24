#!/usr/bin/env python3
"""Pictures of the halls (P6d part 3) -> ~/share/big_floors_p6d/halls/: a main corridor (tree), a side hall, an alley and an artery street of a floor, looking along them from near the room.
usage: tools/p6d_halls.py [SEED] [--floor N] [--tag NAME]"""
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
FLOOR = int(opt("--floor", "1")); tag = opt("--tag", "")
BZ = FLOOR * 1024 + 64
SH = os.path.expanduser("~/share/big_floors_p6d/halls"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    if FLOOR != 1:
        L(v, "Game.run.begin_floor(%d)" % FLOOR, 2); v.step(400); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 100000; Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0", 0)
    def find(kind, skip=0):
        o = L(v, """local P = Game.floorgen.layout; local n = 0
for _, id in ipairs(P.order) do local r = P.rooms[id]
  if r.info.room and r.w >= 10 then
    for _, d in ipairs({ 'E', 'S', 'W', 'N' }) do local k = r.info.open[d]
      if k == '%s' and r.info.door and r.info.door[d] then
        local rr = r.info.room
        local u0, len
        if d == 'E' then u0, len = rr.x + rr.w, 32 - rr.x - rr.w elseif d == 'W' then u0, len = rr.x, rr.x elseif d == 'S' then u0, len = rr.z + rr.d, 32 - rr.z - rr.d else u0, len = rr.z, rr.z end
        local hw = ({ tree = 6, loop = 6, side = 4, alley = 3 })['%s']
        if len > 12 then n = n + 1; if n > %d then print(id, d, r.ci, r.cj, r.info.door[d], u0, len, hw); return end end
      end
    end
  end
end print('none')""" % (kind, kind, skip), 0)[0].split("\t")
        return None if o[0] == "none" else o
    for kind in ("tree", "side", "alley"):
        o = find(kind, 1 if kind == "tree" else 0)
        if not o: print(kind, "none"); continue
        rid, d, ci, cj, c, u0, ln, hw = o[0], o[1], int(o[2]), int(o[3]), float(o[4]), float(o[5]), float(o[6]), float(o[7])
        print(kind, rid, d, "len", ln, "hw", hw)
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 300)
        def XZ(u, vv):
            if d == "E": return ci * 32 + u0 + u, cj * 32 + c + vv
            if d == "W": return ci * 32 + u0 - u, cj * 32 + c + vv
            if d == "S": return ci * 32 + c + vv, cj * 32 + u0 + u
            return ci * 32 + c + vv, cj * 32 + u0 - u
        ex, ez = XZ(1.5, 0); tx, tz = XZ(ln - 2, 0)
        L(v, "local G=Game; player.teleport(G.mx(%f), G.my(0.1), G.mz(%f), { wait = true })" % (ex, ez), 120)
        v.screenshot(os.path.join(SH, "%s%s_f%d_%s.png" % (tag, kind, FLOOR, rid)), hud=False, settle=40, eye=[ex, 8 + 1.7, BZ + ez], target=[tx, 8 + 1.5, BZ + tz], fov=80)
        ex2, ez2 = XZ(ln * 0.5, 0)
        L(v, "local G=Game; player.teleport(G.mx(%f), G.my(0.1), G.mz(%f), { wait = true })" % (ex2, ez2), 120)
        v.screenshot(os.path.join(SH, "%s%s_f%d_%s_mid.png" % (tag, kind, FLOOR, rid)), hud=False, settle=40, eye=[ex2, 8 + 1.7, BZ + ez2], target=[tx, 8 + 1.5, BZ + tz], fov=80)
    # an artery street: a cell on a block border
    o = L(v, """local P = Game.floorgen.layout
for _, id in ipairs(P.order) do local r = P.rooms[id]; local i = r.info
  if i.room and i.ci % 8 == 7 and i.ci > 0 and i.cj % 8 == 3 then print(id, i.ci, i.cj); return end end print('none')""", 0)[0].split("\t")
    if o[0] != "none":
        ci, cj = int(o[1]), int(o[2])
        w = 3 if FLOOR == 2 else 4
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.hand_model(nil); player.model(nil); player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % o[0], 300)
        ex, ez = ci * 32 + 32 - w / 2, cj * 32 + 2
        L(v, "local G=Game; player.teleport(G.mx(%f), G.my(0.1), G.mz(%f), { wait = true })" % (ex, ez), 120)
        v.screenshot(os.path.join(SH, "%sstreet_f%d_%s.png" % (tag, FLOOR, o[0])), hud=False, settle=40, eye=[ex, 8 + 1.7, BZ + ez], target=[ex, 8 + 1.8, BZ + ez + 20], fov=80)
        v.screenshot(os.path.join(SH, "%sstreet_f%d_%s_side.png" % (tag, FLOOR, o[0])), hud=False, settle=10, eye=[ex + 1.2, 8 + 2.0, BZ + ez + 4], target=[ex - 2, 8 + 1.6, BZ + ez + 14], fov=80)
    st = v.tool("status"); print("hook", json.dumps(st["world"].get("hook")))
