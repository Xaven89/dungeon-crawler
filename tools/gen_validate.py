#!/usr/bin/env python3
"""Builds generated floors on a COPY of the project and checks that they can be walked: rooms, crates and enemies must be reachable from the arrival room (the exit once the gate is open).
usage: tools/gen_validate.py SEED [SEED ...] [--floors N]      (a seed expands to floors 1..N, default 3)"""
import os, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
args = sys.argv[1:]
floors = 3
if "--floors" in args:
    i = args.index("--floors"); floors = int(args[i + 1]); del args[i:i + 2]
seeds = [int(a) for a in args] or [1]
copy = os.path.join(ROOT, "projects", "dc_validate")
shutil.rmtree(copy, ignore_errors=True)
shutil.copytree(os.path.join(ROOT, "projects", "dungeon_crawler"), copy)
problems = 0
with Voxelith(["--project", copy, "--threads", "3"]) as v:
    v.step(30)
    v.lua("Game.player.pick_class('janitor'); Game.state.hp = 99999", ticks=200)
    for seed in seeds:
        for fl in range(1, floors + 1):
            v.lua("Game.floorgen.start(%d, %d)" % (seed, fl), ticks=1)
            while v.lua("print(Game.floorgen.job and Game.floorgen.job.i or 'done')", ticks=20)["output"][0] != "done": pass
            v.lua("local G = Game; player.teleport(G.mx(62), G.my(0.1), G.mz(76))", ticks=240)        # (the middle of the volume: every chunk of the floor is streamed in)
            # the gate open: the exit is reachable then
            v.lua("local p = Game.floorgen.layout; if p.gate then Game.world.gate_apply(p.gate) end", ticks=3)
            v.lua("Game.gen.validate.start(Game.floorgen.layout)", ticks=0)
            while v.lua("print(Game.gen.validate.step(40000))", ticks=0)["output"][0] != "true": pass
            rep = v.lua("for _, l in ipairs(Game.gen.validate.report()) do print(l) end print('plan', Game.floorgen.layout.n, table.concat(Game.floorgen.layout.rules or {}, ','))", ticks=0)["output"]
            bad = [l for l in rep if not l.startswith("walkable") and not l.startswith("plan")]
            problems += len(bad)
            print("seed %-8d floor %d: %s | %s" % (seed, fl, "OK" if not bad else "%d PROBLEMS" % len(bad), rep[-1] + " " + [l for l in rep if l.startswith("walkable")][0]))
            for l in bad: print("    " + l)
            sys.stdout.flush()
print("problems:", problems)
shutil.rmtree(copy, ignore_errors=True)
