#!/usr/bin/env python3
"""The soak: the bot plays N floors on several world seeds, each recorded and replayed, and the numbers of every run go into one table (ticks, live / replay hash, agents, cells, bodies, lights, hook ms).
usage: tools/p5_soak.py [--seeds 4242,7,99,12345,31337] [--floors 6] [--out ~/share/big_floors_p5/soak.md]; extra bot flags go after `--` (e.g. -- --borough)"""
import os, sys, re, subprocess, time, json
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.chdir(ROOT)
a = sys.argv[1:]
def opt(name, default):
    return a[a.index(name) + 1] if name in a else default
seeds = [int(x) for x in opt("--seeds", "4242,7,99,12345,31337").split(",")]
floors = int(opt("--floors", "6"))
out = os.path.expanduser(opt("--out", "~/share/big_floors_p5/soak.md"))
extra = a[a.index("--") + 1:] if "--" in a else []
os.makedirs(os.path.dirname(out), exist_ok=True)
rows = []
for seed in seeds:
    t0 = time.time()
    cmd = ["python3", "tools/p2_playthrough.py", str(seed), "janitor", str(floors)] + extra
    r = subprocess.run(cmd, capture_output=True, text=True)
    txt = r.stdout + r.stderr
    row = {"seed": seed, "secs": round(time.time() - t0)}
    m = re.search(r"state hash: (\w+)", txt); row["live"] = m.group(1) if m else "?"
    m = re.search(r"replayed (\d+) ticks in [\d.]+ s: session hash (\w+)\s+(==|!=)", txt)
    row["ticks"], row["replay"], row["equal"] = (m.group(1), m.group(2), m.group(3) == "==") if m else ("?", "?", False)
    m = re.search(r"max agents seen at the end of a fight: (\d+)", txt); row["agents_fight"] = m.group(1) if m else "?"
    m = re.search(r"hook: (\{.*\})", txt)
    h = json.loads(m.group(1)) if m else {}
    row["hook_mean"], row["hook_max"], row["placements"], row["hook_failed"] = h.get("mean_ms"), h.get("max_ms"), h.get("placements"), h.get("failed")
    m = re.search(r"render: (\{.*\})", txt)
    rd = json.loads(m.group(1)) if m else {}
    row["lights"] = (rd.get("lights") or {}).get("authored"); row["gpu_ms"] = rd.get("gpu_ms"); row["cpu_ms"] = rd.get("cpu_ms")
    m = re.search(r"sim: (\{.*?\}) agents (\d+) cells (\d+)", txt)
    if m:
        sm = json.loads(m.group(1)); row["bodies"] = sm.get("bodies"); row["agents_end"], row["cells_end"] = m.group(2), m.group(3)
    m = re.search(r"engine errors / warnings: (.*)", txt); row["errors"] = m.group(1).strip() if m else "?"
    row["floors_seen"] = ",".join(re.findall(r"^FLOOR (\d+)", txt, re.M))
    rows.append(row)
    print(json.dumps(row)); sys.stdout.flush()
cols = ["seed", "floors_seen", "ticks", "live", "replay", "equal", "agents_fight", "agents_end", "cells_end", "bodies", "lights", "gpu_ms", "cpu_ms", "hook_mean", "hook_max", "placements", "hook_failed", "errors", "secs"]
with open(out, "w") as f:
    f.write("| " + " | ".join(cols) + " |\n|" + "---|" * len(cols) + "\n")
    for r in rows: f.write("| " + " | ".join(str(r.get(c, "")) for c in cols) + " |\n")
print("wrote", out)
