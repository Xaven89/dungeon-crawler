#!/usr/bin/env python3
"""The Red car of floor 4: the player stands on its deck at HUB S and rides: prints once a second the car's place, the player's place and their difference (it must stay the same while the car
moves: R1 carries him) and the car's stops. usage: tools/p7_ride.py [SEED] [SECONDS=70]"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh, subprocess
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
args_ = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args_[0]) if args_ else 4242
secs = int(args_[1]) if len(args_) > 1 else 70
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
RECORD = "--record" in sys.argv
log = "/tmp/descent_p7_ride_%d.log" % seed
project = "projects/dungeon_crawler"
STATE_DIRS = [".state", ".events", ".prefabs"]
snap = "/tmp/descent_state_snapshot_p7_%d" % os.getpid()
if RECORD:
    for p_ in [log]:
        if os.path.exists(p_): os.remove(p_)
    if os.path.isdir(log + ".clip"): _sh.rmtree(log + ".clip")
    if os.path.exists(snap): _sh.rmtree(snap)
    os.makedirs(snap)
    present = []
    for d in STATE_DIRS:
        src = os.path.join(ROOT, project, d)
        if os.path.isdir(src): _sh.copytree(src, os.path.join(snap, d)); present.append(d)
with Voxelith(["--project", project, "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)] + (["--record", log] if RECORD else [])) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0; Game.run.cur().floor_ticks = 1000000", 0)
    print("cars:", L(v, "for n, c in pairs(Game.gen.trains.cars) do print(n, events.state(c.id).open and 'moving' or 'stopped') end", 0))
    L(v, "local G = Game; player.hand_model(nil); player.teleport(G.mx(112), G.my(0.2), G.mz(208), { wait = true })", 30)
    for s in range(secs):
        o = L(v, "local G = Game; local cx, cy, cz = G.gen.trains.where('red'); local px, py, pz = player.pos(); local st = events.state(G.gen.trains.cars.red.id); print(string.format('%.2f %.2f %.2f | %.2f %.2f %.2f | d %.2f %.2f %.2f | %s', cx, cy, cz, px, py, pz, px - cx, py - cy, pz - cz, tostring(st.moving)))", 0)
        if s % 2 == 0: print("t+%2d s" % s, o[0])
        v.step(60)
    errs = [l.strip()[:200] for l in v.stderr_tail(300).splitlines() if "error" in l.lower() or "warn" in l.lower()]
    print("log:", errs[-5:])
    v.step(5)
    live = v.state_hash(); print("state hash:", live)
if RECORD:
    for d in STATE_DIRS:
        dst = os.path.join(ROOT, project, d)
        if os.path.isdir(dst): _sh.rmtree(dst)
        if d in present: _sh.copytree(os.path.join(snap, d), dst)
    for p_ in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p_) else os.remove)(p_)
    r = subprocess.run([os.path.join(ROOT, "voxelith"), "--replay", log, "--threads", "3", "--save", "/tmp/descent_scratch.vxs"], capture_output=True, text=True, cwd=ROOT)
    print([l for l in (r.stdout + r.stderr).splitlines() if "replayed" in l.lower()][-1:], "live:", live)
