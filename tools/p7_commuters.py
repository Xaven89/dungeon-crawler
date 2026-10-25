#!/usr/bin/env python3
"""The commuters of floor 4: the player waits on the platform of Y1 (Yellow station 1), the crowd waits with him, the car comes, those within 6 m board; the player rides to Y3 and the riders get off
there. Prints per second the riders, the car's state and where the player is; pictures in ~/share/big_floors_p7/. usage: tools/p7_commuters.py [SEED] [SECONDS=100]"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
args_ = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args_[0]) if args_ else 4242
secs = int(args_[1]) if len(args_) > 1 else 100
BZ = 4 * 1024 + 64
SH = os.path.expanduser("~/share/big_floors_p7"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.state.flags.god = true; Game.run.cur().floor_ticks = 1000000; Game.state.hp = 99999", 0)
    L(v, "local G = Game; player.hand_model(nil); player.teleport(G.mx(38), G.my(0.2), G.mz(105), { wait = true })", 200)
    shots = 0
    killed = False
    L(v, 'Game.gen.trains.dbg = true', 0)
    for s in range(secs):
        o = L(v, """local G = Game; local T = G.gen.trains; local c = T.cars.orange; local st = events.state(c.id); local x, y, z = T.where('orange'); local px, py, pz = player.pos()
local rid = {}; for _, r in ipairs(T.riders.orange or {}) do local ex, ey, ez = G.enemies.position(r.inst); local cx_, cy_, cz_ = T.where('orange'); rid[#rid + 1] = string.format('%s>%s (%.2f,%.2f,%.2f)', r.inst.kind, r.dest, (ex or 0) - cx_, (ey or 0) - cy_, (ez or 0) - cz_) end
local crowd = 0; for id, i in pairs(G.enemies.list) do if i.room == 'c1_3' and not i.dead and not i.riding then crowd = crowd + 1 end end
print(string.format('car %.0f,%.0f moving=%s | player %.0f,%.0f,%.0f | crowd at Y1: %d | riders: %s', x - G.mx(0), z - G.mz(0), tostring(st.moving), px - G.mx(0), py, pz - G.mz(0), crowd, table.concat(rid, ' ')))""", 0)
        if s % 3 == 0: print("t+%3d" % s, o[0])
        if os.environ.get("KILL_RIDER"):               # a rider dies on the moving deck: it must lie on the deck (die clip) and ride on with it, not fall through or stand
            if not killed and "riders: " in o[0] and "(" in o[0].split("riders: ")[1]:
                L(v, "local G = Game; local T = G.gen.trains; local r = (T.riders.orange or {})[1]; if r then G.rider_k = r.inst; G.enemies.kill(r.inst, { source = 'test' }) end", 2); killed = True
            if killed:
                print("   corpse:", L(v, "local G = Game; local i = G.rider_k; if i then local x, y, z = G.enemies.position(i); local cx, cy, cz = G.gen.trains.where('orange'); print(string.format('dead %s rel (%.2f, %.2f, %.2f) riding %s', tostring(i.dead), (x or 0) - cx, (y or 0) - cy, (z or 0) - cz, tostring(i.riding))) end", 0))
        if shots == 0 and 'goblin' in o[0] + 'bandit' + 'imp' + 'rat' and 'riders: ' in o[0] and o[0].split('riders: ')[1].strip() and 'moving=false' in o[0].replace('moving=nil', 'moving=false'):
            cx, cz = [float(t) for t in o[0].split('car ')[1].split(' ')[0].split(',')]
            L(v, "local G = Game; local x, y, z = G.gen.trains.where('orange'); player.hand_model(nil); player.teleport(x - 4.5, y + 0.4, z - 1.0)", 30)
            v.screenshot(os.path.join(SH, "commuters_on_deck.png"), hud=False, settle=20, eye=[cx - 12, 8 + 3.0, BZ + cz - 4], target=[cx, 8 + 1.2, BZ + cz], fov=70)
            shots = 1
        v.step(60)
    for l in v.stderr_tail(300).splitlines():
        if "DBG" in l: print(l.strip()[-220:])
    errs = [l.strip()[:200] for l in v.stderr_tail(300).splitlines() if "error" in l.lower() or "warn" in l.lower()]
    print("log:", errs[-4:])
