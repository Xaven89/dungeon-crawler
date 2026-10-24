#!/usr/bin/env python3
"""T5: a recorded run on the Iron Tangle: the player rides the Red car from HUB S round to HUB N (it stops at W first), steps off, goes to the stairwell, the clock opens it and he descends to floor 5;
the recording is replayed. Prints the car's and the player's places and the hash pair. usage: tools/p7_run.py [SEED]"""
import os, sys, json, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
args_ = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args_[0]) if args_ else 4242
log = "/tmp/descent_p7_run_%d.log" % seed
project = "projects/dungeon_crawler"
STATE_DIRS = [".state", ".events", ".prefabs"]
snap = "/tmp/descent_state_snapshot_p7run_%d" % os.getpid()
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
for p_ in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p_) else os.remove)(p_)
if os.path.exists(log): os.remove(log)
if os.path.isdir(log + ".clip"): _sh.rmtree(log + ".clip")
if os.path.exists(snap): _sh.rmtree(snap)
os.makedirs(snap); present = []
for d in STATE_DIRS:
    src = os.path.join(ROOT, project, d)
    if os.path.isdir(src): _sh.copytree(src, os.path.join(snap, d)); present.append(d)
with Voxelith(["--project", project, "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed), "--record", log]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.state.flags.god = true; Game.floorgen.ENEMY_CAP = 0; Game.run.cur().floor_ticks = 24000", 0)
    L(v, "local G = Game; player.hand_model(nil); player.teleport(G.mx(112), G.my(0.2), G.mz(208), { wait = true })", 30)
    def where():
        return L(v, "local G = Game; local cx, cy, cz = G.gen.trains.where('red'); local px, py, pz = player.pos(); print(string.format('car %.0f,%.0f player %.0f,%.0f,%.0f d %.2f moving %s', cx - G.mx(0), cz - G.mz(0), px - G.mx(0), py, pz - G.mz(0), math.sqrt((px - cx)^2 + (pz - cz)^2), tostring(events.state(G.gen.trains.cars.red.id).moving)))", 0)[0]
    # ride: through the stop at W (about 40 s after the start) up to HUB N (stop 3), then step off
    arrived_n = False
    for s in range(240):
        v.step(60)
        w = L(v, "local G = Game; local cx, cy, cz = G.gen.trains.where('red'); print(math.floor(cx - G.mx(0)), math.floor(cz - G.mz(0)))", 0)[0].split("\t")
        if s % 15 == 0: print("t+%3d" % s, where())
        if abs(int(w[0]) - 112) < 2 and abs(int(w[1]) - 16) < 2 and s > 20:
            arrived_n = True; break
    print("arrived at HUB N:", arrived_n, where())
    v.step(120)
    L(v, "local G = Game; player.teleport(G.mx(102), G.my(0.2), G.mz(10.5), { wait = true })", 60)          # steps off onto the platform of HUB N
    print("on the platform:", where())
    # the stairwell: the clock opens it, the player goes in
    L(v, "local G = Game; local F = G.floorgen; G.run.cur().fclock = math.floor(F.floor_ticks() * F.AT_LATE) + 60", 60)
    st = L(v, "local F = Game.floorgen; local P = F.layout; local best = P.plan.stairs[1]; print(best, tostring(F.stairs_open(best)))", 0)[0].split("\t")
    print("stairwell", st)
    L(v, "local G = Game; local c = G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.2), G.mz(c.z), { wait = true })" % st[0], 200)
    L(v, "local G = Game; G.floorgen.stairs_enter('%s')" % st[0], 3)
    print("screen:", L(v, "print(Game.screen)", 0))
    L(v, "Game.run.descend(true)", 2)
    v.step(500); L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2); v.step(120)
    print("floor now:", L(v, "print(Game.run.cur().floor, Game.floorgen.layout.floor)", 0))
    errs = [l.strip()[:200] for l in v.stderr_tail(300).splitlines() if "error" in l.lower()]
    print("errors:", errs[-4:])
    v.step(5); live = v.state_hash(); print("state hash:", live)
for d in STATE_DIRS:
    dst = os.path.join(ROOT, project, d)
    if os.path.isdir(dst): _sh.rmtree(dst)
    if d in present: _sh.copytree(os.path.join(snap, d), dst)
for p_ in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p_) else os.remove)(p_)
r = subprocess.run([os.path.join(ROOT, "voxelith"), "--replay", log, "--threads", "3", "--save", "/tmp/descent_scratch.vxs"], capture_output=True, text=True, cwd=ROOT)
print([l for l in (r.stdout + r.stderr).splitlines() if "replayed" in l.lower()][-1:], "live:", live)
