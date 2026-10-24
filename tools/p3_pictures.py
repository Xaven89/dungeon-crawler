#!/usr/bin/env python3
"""Pictures of the P3 features in the running game (HUD included) -> ~/share/big_floors_p3/: the sealed and the open stairwell, a graffiti wall, a bathroom door, the borough gate and rotunda,
the neighbourhood boss's door, the map with the clock. usage: tools/p3_pictures.py [SEED]"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
def _fresh_scratch():
    for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
_fresh_scratch()   # (the engine of 2026-10-24 needs --save for a project with save=: a scratch file keeps the game's own world.vxs untouched)
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 4242
SH = os.path.expanduser("~/share/big_floors_p3"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 10000; Game.state.flags.god = true", 0)
    def tp(x, z, y=0.1):
        L(v, "player.teleport(Game.mx(%f), Game.my(%f), Game.mz(%f))" % (x, y, z), 260)
    def look(name, ex, ey, ez, tx, ty, tz, settle=100):
        L(v, "local G=Game; player.teleport(G.mx(%f), G.my(0.1), G.mz(%f)); G.state.hp = G.player.max_hp()" % (ex, ez), 220)
        v.screenshot(os.path.join(SH, name + ".png"), hud=False, settle=settle, eye=[ex, 8 + ey, 1088 + ez], target=[tx, 8 + ty, 1088 + tz], fov=85)
    # the stairwell, sealed and open
    st = L(v, "local P = Game.floorgen.layout; local r = P.rooms[P.free_list[1]]; print(r.id, r.x + r.w / 2, r.z + r.d / 2)", 0)[0].split("\t")
    sx, sz = float(st[1]), float(st[2])
    look("stairs_sealed", sx - 7, 2.2, sz - 7, sx, 0, sz)
    L(v, "Game.run.cur().fclock = 3100", 0); v.step(150)
    look("stairs_open", sx - 7, 2.2, sz - 7, sx, 0, sz)
    look("stairs_open_inside", sx - 2.6, 1.7, sz, sx + 2.6, -1.8, sz)
    # a graffiti wall and a bathroom door: found by the same hash the game uses
    g = L(v, """local CG, H = Game.floorgen.cg(); local P = Game.floorgen.layout
for _, id in ipairs(P.order) do local r = P.rooms[id]
  if r.cellrole == 'room' and H(0, P.floor * 1000 + 720, r.ci, r.cj, 1) < 0.22 then local d = {}; for _, dd in ipairs(P.doors[id] or {}) do d[dd.side] = true end; print(id, r.x, r.z, r.w, r.d, tostring(d.N), tostring(d.S), tostring(d.W), tostring(d.E)); break end end""", 0)
    print("graffiti room", g)
    if g:
        p = g[0].split("\t")
        x, z, w, d = [float(c) for c in p[1:5]]
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z))" % p[0], 260)
        v.step(60)
        side = next((n for n, u in zip("NSWE", p[5:9]) if u != "true"), "N")
        cx, cz = x + w / 2, z + d / 2
        eye = {"N": (cx, 1.7, z + 7, cx, 1.7, z), "S": (cx, 1.7, z + d - 7, cx, 1.7, z + d), "W": (x + 7, 1.7, cz, x, 1.7, cz), "E": (x + w - 7, 1.7, cz, x + w, 1.7, cz)}[side]
        look("graffiti", eye[0], eye[1], eye[2], eye[3], eye[4], eye[5])
    # a bathroom door in a hall (the same hash as shell.lua)
    bd = L(v, """local CG, H = Game.floorgen.cg(); local P = Game.floorgen.layout
for _, id in ipairs(P.order) do local r = P.rooms[id]
  for _, d in ipairs(P.doors[id] or {}) do
    if d.side == 'E' and (d.kind == 'tree' or d.kind == 'loop') and H(0, P.floor * 1000 + 830, r.ci, r.cj, 1) < 0.3 then
      print(id, r.ci * 32 + (r.info.room.x + r.info.room.w + 32) / 2, d.pos, d.kind); return end end end
print('none')""", 0)[0].split("\t")
    print("bathroom door", bd)
    if bd[0] != "none":
        xm, c = float(bd[1]), float(bd[2])
        look("bathroom_door", xm, 1.7, c + 1.6, xm, 1.4, c - 3, settle=120)
    # the borough: the gate from outside and the rotunda
    b = L(v, "local P = Game.floorgen.layout; local r = P.ring_list[1]; if r then print(r.id, r.ox, r.oz, r.origin) else print('none') end", 0)[0].split("\t")
    if b[0] != "none":
        ox, oz = float(b[1]), float(b[2])
        look("borough_gate", ox + 24, 2.2, oz + 56, ox + 32, 1, oz + 50)
        look("borough_ring", ox + 26, 2.2, oz + 53, ox + 46, 1, oz + 53)
        look("borough_rotunda", ox + 32, 3, oz + 51, ox + 32, 0.3, oz + 28)
        # the boss fight itself (HUD on)
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z))" % b[0], 700)
        v.screenshot(os.path.join(SH, "borough_boss_hud.png"), hud=True, settle=60)
    st = v.tool("status")
    print("render", json.dumps(st["render"]))
    print("hook", json.dumps(st["world"].get("hook")))
