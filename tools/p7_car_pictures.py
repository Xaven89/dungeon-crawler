#!/usr/bin/env python3
"""Pictures of the railed car (E16) -> ~/share/polish/E16_cars/: from the platform of Y1 (Orange, west end) as the car arrives and stands, and from the Red car's deck at player height while it moves.
usage: tools/p7_car_pictures.py [SEED]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 4242
BZ = 4 * 1024 + 64
SH = os.path.expanduser("~/share/polish/E16_cars"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0; Game.run.cur().floor_ticks = 1000000", 0)
    # from the deck of the Red car at HUB S (it waits 25 s there): at player height, standing, then moving
    L(v, "local G = Game; player.hand_model(nil); local cx, cy, cz = G.gen.trains.where('red'); player.teleport(cx, cy + 0.5, cz - 3.0, { wait = True })".replace("True", "true"), 60)
    for k in range(4):
        L(v, "local G = Game; local cx, cy, cz = G.gen.trains.where('red'); local px, py, pz = player.pos(); print(cx - G.mx(0), cz - G.mz(0))", 0)
        v.screenshot(os.path.join(SH, "deck_red_%d.png" % k), hud=False, settle=60, eye=None) if False else None
    # the platform of Y1 for the Orange car's arrival (the car comes back to its first stop after about 4 minutes)
    L(v, "local G = Game; player.teleport(G.mx(38), G.my(0.2), G.mz(105), { wait = true })", 120)
    n = 0
    for s in range(320):
        v.step(60)
        w = L(v, "local G = Game; local x, y, z = G.gen.trains.where('orange'); print(x - G.mx(0), z - G.mz(0), events.state(G.gen.trains.cars.orange.id).moving and 'moving' or 'still')", 0)[0].split("\t")
        x = float(w[0])
        if s > 150 and x < 100 and n < 3 and (x < 66 or x < 52 or x < 49):
            v.screenshot(os.path.join(SH, "platform_arrival_%d.png" % n), hud=False, settle=40, eye=[38, 8 + 1.7, BZ + 104], target=[x, 8 + 1.2, BZ + 112], fov=75); n += 1
        if n >= 3: break
    v.step(120)
    v.screenshot(os.path.join(SH, "platform_stopped.png"), hud=False, settle=60, eye=[38, 8 + 1.7, BZ + 104], target=[56, 8 + 1.2, BZ + 112], fov=75)
    # the deck, player height, the Red car moving: the player rides it (carried) and looks along the car
    L(v, "local G = Game; local cx, cy, cz = G.gen.trains.where('red'); player.teleport(cx + 1.0, cy + 0.5, cz + 0.5, { wait = true })", 30)
    for k in range(3):                          # the player's own camera, standing on the moving deck (carried), looking two ways along the car
        v.step(420)
        v.screenshot(os.path.join(SH, "deck_moving_%da.png" % k), hud=False, settle=40)
        v.run_script("turn:180")
        v.screenshot(os.path.join(SH, "deck_moving_%db.png" % k), hud=False, settle=40)
print("pictures in", SH)
