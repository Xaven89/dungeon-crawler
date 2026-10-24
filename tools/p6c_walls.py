#!/usr/bin/env python3
"""P6c: the moving walls of the rotunda (floors 2+). usage: tools/p6c_walls.py [SEED] [--floor N]
1. the phase check (deco_wall_check) for floors 2..8; 2. on floor N: the slabs shut / open on the clock (event states), a picture of each state, the player standing in the slot when it shuts."""
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
FLOOR = int(sys.argv[sys.argv.index("--floor") + 1]) if "--floor" in sys.argv else 2
BZ = FLOOR * 1024 + 64
SH = os.path.expanduser("~/share/big_floors_p6c"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(100)
    for fl in range(1, 9):
        print("floor", fl, "plan", L(v, "print(#deco_wall_plan(%d))" % fl, 0), "check (worst wait ticks, problems)", L(v, "local w, b = deco_wall_check(%d); print(w, #b, table.concat(b, '; '))" % fl, 0))
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    if FLOOR != 1:
        L(v, "Game.run.begin_floor(%d)" % FLOOR, 2); v.step(400); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 100000; Game.state.flags.god = true", 0)
    r = L(v, "local P = Game.floorgen.layout; local r = P.ring_list[1]; if not r then print('none') return end; print(r.id, r.origin, r.ox, r.oz)", 0)[0].split("\t")
    if r[0] == "none": print("floor %d has no fortress (boroughs: floors 1 and 2, the park: floor 3): no moving walls there" % FLOOR); sys.exit(0)
    rid, origin, ox, oz = r[0], r[1], float(r[2]), float(r[3])
    L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % origin, 200)
    v.step(120)
    def states():
        return L(v, "local P = Game.floorgen.layout; local r = P.ring_list[1]; local t = {}; for _, e in ipairs(r.walls or {}) do local s = events.state(e.id); t[#t+1] = e.w.id .. '=' .. (s.open and 'open' or 'shut') .. (s.moving and '~' or '') .. (s.blocked and '!' or '') end; print(Game.run.cur().fclock, table.concat(t, ' '))", 0)
    g = L(v, "local g = Game.floorgen.layout.ring_list[1].g; local w = deco_wall_plan(%d)[1]; print(g.cx, g.cz, w.x0, w.x1, w.z0, w.z1)" % FLOOR, 0)[0].split("\t")
    cx, cz, x0, x1, z0, z1 = [float(c) for c in g]
    sx, sz = ox + (x0 + x1) / 2, oz + (z0 + z1) / 2           # the middle of slab 1W (local metres)
    def look(name, ex, ey, ez, tx, ty, tz):
        L(v, "local G=Game; player.hand_model(nil); player.model(nil); player.teleport(G.mx(%f), G.my(0.1), G.mz(%f)); G.state.hp = G.player.max_hp()" % (ex, ez), 90)
        v.screenshot(os.path.join(SH, name + ".png"), hud=False, settle=60, eye=[ex, 8 + ey, BZ + ez], target=[tx, 8 + ty, BZ + tz], fov=85)
    L(v, "local E = Game.enemies; Game.floorgen.ENEMY_CAP = 0; for id in pairs(E.list) do pcall(agent.remove, id); E.list[id] = nil end; E.alive_count = function() return 0 end", 5)    # (no guards in the pictures: they stand in the slot)
    def set_clock(c): L(v, "Game.floorgen.walls_fixed = %d" % c, 0)
    def mat(y):
        return L(v, "print(world.material_at(Game.wx(%f), Game.wy(%f), Game.wz(%f)))" % (sx, y, sz), 0)[0]
    # slab 1W is open on clock 0..431 (phase 0), shut on 432..719
    set_clock(200); v.step(120); print("clock 200:", states(), "| material in the corridor at 2 m:", mat(2.0), "in the trench at -2 m:", mat(-2.0))
    look("wall_open", sx, 1.7, sz + 6, sx, 1.4, sz)
    set_clock(500); v.step(120); print("clock 500:", states(), "| material at 2 m:", mat(2.0), "at -2 m:", mat(-2.0))
    look("wall_shut", sx, 1.7, sz + 6, sx, 1.4, sz)
    look("wall_shut_side", sx + 1.2, 3.4, sz + 4, sx, 1.2, sz)
    # the player stands in the slot when the wall shuts: the slab is open (clock 200), the player stands ON it, the clock jumps to 500 (shut): the slab waits for him
    set_clock(200); v.step(120)
    L(v, "local G=Game; player.hand_model(nil); player.teleport(G.mx(%f), G.my(0.1), G.mz(%f), { wait = true })" % (sx, sz), 60)
    print("standing on the open slab:", states(), "player", L(v, "local x, y, z = player.pos(); print(string.format('%.2f %.2f %.2f', x, y, z))", 0))
    set_clock(500); v.step(240)
    print("wall wants to shut, 240 ticks later:", states(), "player", L(v, "local x, y, z = player.pos(); print(string.format('%.2f %.2f %.2f', x, y, z))", 0), "| material at his knees:", mat(0.4), "at 2 m:", mat(2.0))
    v.screenshot(os.path.join(SH, "wall_blocked_by_player.png"), hud=False, settle=10, eye=[sx + 1.6, 8 + 2.4, BZ + sz + 3.2], target=[sx, 8 + 0.8, BZ + sz], fov=85)
    # he steps off to the side (south): the slab shuts
    L(v, "local G=Game; player.teleport(G.mx(%f), G.my(0.1), G.mz(%f), { wait = true })" % (sx, sz + 3), 120)
    print("he stepped off:", states(), "| material at 2 m:", mat(2.0))
    L(v, "Game.floorgen.walls_fixed = nil", 0)
    print("hook", json.dumps(v.tool("status")["world"].get("hook")))
