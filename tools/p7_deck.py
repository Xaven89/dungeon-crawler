#!/usr/bin/env python3
"""The railed car of floor 4 (E16): recorded, then replayed. The player stands on the Red car's deck at HUB S (it waits 25 s there), WALKS along the deck between the benches (run_script fwd / turn: the
player's own control), stands in a boarding gap (the middle of the car, +-1.25 m along the way, at the side), and rides through the stop at W: prints the player's place in the car's frame every second and the
height above the deck. usage: tools/p7_deck.py [SEED]"""
import os, sys, math, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 4242
log = "/tmp/descent_deck.log"
for p in (log, log + ".clip"):
    if os.path.isdir(p): _sh.rmtree(p)
    elif os.path.exists(p): os.remove(p)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
FRAME = """local G = Game; local cx, cy, cz = G.gen.trains.where('red'); local px, py, pz = player.pos(); local st = events.state(G.gen.trains.cars.red.id)
print(string.format('car (%.1f, %.2f, %.1f) player in the car frame (%.2f, %.2f, %.2f) moving %s', cx - G.mx(0), cy, cz - G.mz(0), px - cx, py - cy, pz - cz, tostring(st.moving)))"""
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed), "--record", log]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0; Game.run.cur().floor_ticks = 1000000", 0)
    v.step(120)
    # on the deck, 2 m before the middle, facing the car's +z (the track's direction at HUB S is -x: the car's long axis is its z; the yaw is the engine's)
    L(v, "local G = Game; player.hand_model(nil); local cx, cy, cz = G.gen.trains.where('red'); player.teleport(cx, cy + 0.5, cz - 2.0, { wait = true })", 60)
    print("placed:", L(v, FRAME, 0)[0])
    for step_name, script in (("walk forward", "fwd:120"), ("turn round, walk back", "turn:180,fwd:240"), ("walk to the middle", "turn:180,fwd:60")):
        v.run_script(script)
        print(step_name, "->", L(v, FRAME, 0)[0])
    # into a boarding gap: the middle of the car, at the side (x +-1.2 m)
    L(v, "local G = Game; local cx, cy, cz = G.gen.trains.where('red'); player.teleport(cx + 1.15, cy + 0.5, cz, { wait = true })", 30)
    print("in the gap:", L(v, FRAME, 0)[0])
    for s in range(40):
        v.step(60)
        o = L(v, FRAME, 0)[0]
        if s % 4 == 0: print("t+%2d s" % s, o)
    print("log:", [l.strip()[:200] for l in v.stderr_tail(300).splitlines() if "error" in l.lower() or "warn" in l.lower()][-5:])
    v.step(5); live = v.state_hash(); print("state hash:", live)
for p_ in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p_) else os.remove)(p_)
r = subprocess.run([os.path.join(ROOT, "voxelith"), "--replay", log, "--threads", "3", "--save", "/tmp/descent_scratch.vxs"], capture_output=True, text=True, cwd=ROOT)
print([l for l in (r.stdout + r.stderr).splitlines() if "replayed" in l.lower()][-1:], "live:", live)
