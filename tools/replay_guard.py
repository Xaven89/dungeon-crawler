#!/usr/bin/env python3
"""Runs tools/p2_playthrough.py recorded and replayed several times with hash probes on; every run whose replay differs is kept for the engine's developer: the log, the whole clip, the project's state snapshot
(.state .events .prefabs) and the live and replay probe files go to ~/share/replay_f4_<time>/. usage: tools/replay_guard.py "SEED BOT ARGS..." [...]   (each argument = one run: e.g. "7 janitor 1 --first-floor 4")"""
import os, sys, subprocess, shutil, time, glob, re
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.chdir(ROOT)
bad = 0
for n, spec in enumerate(sys.argv[1:]):
    args = spec.split()
    seed = args[0]
    live = "/tmp/rg_live_%d.txt" % n
    if os.path.exists(live): os.remove(live)
    env = dict(os.environ, VX_HASHEVERY="20", VX_HASHCHEAP="1", VOXELITH_STDERR=live, PROBE_OUT="/tmp/rg_%d" % n)
    t0 = time.time()
    r = subprocess.run([sys.executable, "tools/p2_playthrough.py"] + args, capture_output=True, text=True, env=env, cwd=ROOT)
    out = r.stdout + r.stderr
    ok = "== the recorded hash" in out
    m = re.search(r"replayed (\d+) ticks.*session hash (\w+)", out)
    snap = (re.search(r"state snapshot: (\S+)", out) or [None, None])[1]
    print("run %d  %-34s %s  ticks %s  hash %s  (%.0f s)" % (n, spec, "EQUAL" if ok else "DIFFERENT", m.group(1) if m else "?", m.group(2) if m else "?", time.time() - t0)); sys.stdout.flush()
    if not ok:
        bad += 1
        d = os.path.expanduser("~/share/replay_f4_%s_%d" % (time.strftime("%H%M%S"), n)); os.makedirs(d, exist_ok=True)
        log = "/tmp/descent_big_%s.log" % seed
        for p in (log, live, "/tmp/rg_%d_replay.txt" % n, "/tmp/rg_%d_live.txt" % n):
            if os.path.exists(p): shutil.copy(p, d)
        if os.path.isdir(log + ".clip"): shutil.copytree(log + ".clip", os.path.join(d, os.path.basename(log) + ".clip"), dirs_exist_ok=True)
        if snap and os.path.isdir(snap): shutil.copytree(snap, os.path.join(d, "state_snapshot"), dirs_exist_ok=True)
        open(os.path.join(d, "RUN.txt"), "w").write(spec + "\n" + out[-3000:])
        print("   kept in", d)
print("different:", bad, "of", len(sys.argv) - 1)
