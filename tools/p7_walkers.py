"""The den walkers of floor 4: the monsters of the den (5,1) (door to the Yellow station (5,2), its east end) walk to the platform after the Yellow car has left it and board at its next arrival. Recorded, replayed.
Prints every 10 s the den's and the platform's monsters (kind, place, walker_to, riding) and the car's x. usage: tools/p7_walkers.py [SEED] [SECONDS=480]"""
import os, sys, math, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith, state_dir_args, state_dir_args
import glob as _g, shutil as _sh
for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 4242
log = "/tmp/descent_walkers.log"
for p in (log, log + ".clip"):
    if os.path.isdir(p): _sh.rmtree(p)
    elif os.path.exists(p): os.remove(p)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
secs = int(sys.argv[2]) if len(sys.argv) > 2 else 480
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
TRACE = """local G = Game; local cx, cy, cz = G.gen.trains.where('yellow'); local t = {}
for _, i in pairs(G.enemies.list) do if (i.room == 'c5_1' or i.room == 'c5_2' or i.walker_to) and not i.dead then local x, y, z = G.enemies.position(i); t[#t + 1] = string.format('%d:%s %s(%.0f,%.0f)%s%s', i.id % 1000, i.kind, i.room, (x or 0) - G.mx(0), (z or 0) - G.mz(0), i.walker_to and ' ->' .. i.walker_to or '', i.riding and ' RIDING' or '') end end
table.sort(t); print(string.format('kills %d dead %s cells %d player (%.0f,%.0f) hp %.0f | yellow x %.0f | ', G.state.kills, tostring(G.player.dead), #G.floorgen.made_list, select(1, player.pos()) - G.mx(0), select(3, player.pos()) - G.mz(0), G.state.hp, cx - G.mx(0)) .. table.concat(t, ' | '))"""
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed), "--record", log]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(30)
    L(v, "Game.state.flags.god = true; Game.state.hp = 99999; Game.run.cur().floor_ticks = 1000000", 0)
    L(v, "local G = Game; G.companion.tick = function() end; if G.companion.id then pcall(agent.remove, G.companion.id) end", 2)       # (the goose and the player must not kill the walkers: this test watches them)
    L(v, "local G = Game; player.hand_model(nil); player.teleport(G.mx(134), G.my(0.2), G.mz(75.5), { wait = true })", 120)
    for s_ in range(secs):
        v.step(60); L(v, "Game.state.hp = 99999", 0)
        if s_ % 10 == 0: print("t+%3d s" % s_, L(v, TRACE, 0)[0])
    print("log:", [l.strip()[:200] for l in v.stderr_tail(300).splitlines() if "error" in l.lower()][-5:])
    v.step(5); live = v.state_hash(); print("state hash:", live)
for p_ in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p_) else os.remove)(p_)
r = subprocess.run([os.path.join(ROOT, "voxelith"), *state_dir_args(), "--replay", log, "--threads", "3", "--save", "/tmp/descent_scratch.vxs"], capture_output=True, text=True, cwd=ROOT)
print([l for l in (r.stdout + r.stderr).splitlines() if "replayed" in l.lower()][-1:], "live:", live)
