#!/usr/bin/env python3
"""The balance table: the bot through the Orientation and floors 1-8 on several seeds (fresh state dirs: the runs are repeatable), the game's own counters per floor (kills by type, damage taken by source,
gold and items picked, deaths, safe-room visits, the boss fight's length in ticks) and the ticks per floor; outliers flagged with numbers, no tuning. Written to ~/share/balance/balance_<date>.md.
usage: tools/balance.py [--seeds 4242,7,99,12345,31337] [--floors 8] [--class janitor] [--out FILE] [--reuse DIR]   (--reuse: parse the logs of an earlier run in DIR)"""
import os, sys, re, subprocess, time, collections, statistics, json
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.chdir(ROOT)
a = sys.argv[1:]
def opt(n, d): return a[a.index(n) + 1] if n in a else d
seeds = [int(x) for x in opt("--seeds", "4242,7,99,12345,31337").split(",")]
floors = int(opt("--floors", "8")); cls = opt("--class", "janitor")
out = os.path.expanduser(opt("--out", "~/share/balance/balance_%s.md" % time.strftime("%Y-%m-%d")))
logdir = opt("--reuse", "/tmp/balance_logs_%s" % time.strftime("%H%M%S")); os.makedirs(logdir, exist_ok=True); os.makedirs(os.path.dirname(out), exist_ok=True)
data = {}          # seed -> floor -> { ticks, group -> key -> n }
def parse(text, seed, orientation=False):
    for m in re.finditer(r"^TALLY (\d+) (\d+) ?(.*)$", text, re.M):
        fl, ticks, body = (0 if orientation else int(m.group(1))), int(m.group(2)), m.group(3)      # (the Orientation is floor 0: it was added to floor 1's row of its seed)
        d = data.setdefault(seed, {}).setdefault(fl, {"ticks": ticks})
        d["ticks"] = ticks if not orientation else ticks
        for item in body.split(";"):
            if item.count("|") == 2:
                g, k, n = item.split("|"); d.setdefault(g, {})[k] = d.setdefault(g, {}).get(k, 0) + float(n)
for seed in seeds:
    f = os.path.join(logdir, "p2_%d.txt" % seed)
    if not os.path.exists(f):
        r = subprocess.run([sys.executable, "tools/p2_playthrough.py", str(seed), cls, str(floors), "--no-replay"], capture_output=True, text=True, timeout=7200)
        open(f, "w").write(r.stdout + r.stderr)
    parse(open(f).read(), seed)
    f0 = os.path.join(logdir, "orient_%d.txt" % seed)
    if not os.path.exists(f0) and seed == seeds[0]:
        r = subprocess.run([sys.executable, "tools/playthrough.py", cls, "--no-replay"], capture_output=True, text=True, timeout=3600)
        open(f0, "w").write(r.stdout + r.stderr)
    if os.path.exists(f0): parse(open(f0).read(), seed, True)
# ---------------------------------------------------------------------------------------------- the table
L = ["# Balance table (%s), the bot (%s) through the Orientation and floors 1-%d, seeds %s, fresh state dirs" % (time.strftime("%Y-%m-%d"), cls, floors, seeds),
     "", "Source: the game's own counters (`G.tally`: kills, damage, gold, items, deaths, safe visits, boss ticks) per floor, written by the bot's TALLY lines; ticks = ticks the bot spent on the floor. One row per floor, medians over seeds in brackets where more than one seed reached the floor. No tuning: outliers only.", ""]
def agg(fl, group):          # key -> one value per seed that reached the floor (0 where the seed never saw the key: the mean is over the runs, not over the runs that had it)
    seeds_f = [s for s in data if fl in data[s]]
    keys = {k for s in seeds_f for k in data[s][fl].get(group, {})}
    return {k: [data[s][fl].get(group, {}).get(k, 0) for s in seeds_f] for k in keys}
allfl = sorted({fl for s in data for fl in data[s]})
L += ["## Per floor (mean over the seeds that reached it; n = seeds)", "", "| floor | n | ticks | kills | deaths | damage taken | gold | items | safe visits | boss ticks |", "|---|---|---|---|---|---|---|---|---|---|"]
rows = {}
for fl in allfl:
    seeds_f = [s for s in data if fl in data[s]]
    def tot(group): return statistics.mean(sum(data[s][fl].get(group, {}).values()) for s in seeds_f)
    ticks = statistics.mean(data[s][fl]["ticks"] for s in seeds_f)
    bt = [v for s in seeds_f for v in data[s][fl].get("boss_ticks", {}).values()]
    rows[fl] = dict(n=len(seeds_f), ticks=ticks, kills=tot("kills"), deaths=tot("deaths"), damage=tot("damage"), gold=tot("gold"), items=tot("items"), safe=tot("safe_visits"), boss=(statistics.mean(bt) if bt else None))
    r = rows[fl]
    L.append("| %d | %d | %.0f | %.1f | %.1f | %.0f | %.0f | %.1f | %.1f | %s |" % (fl, r["n"], r["ticks"], r["kills"], r["deaths"], r["damage"], r["gold"], r["items"], r["safe"], ("%.0f" % r["boss"]) if r["boss"] is not None else "-"))
L += ["", "## Kills by type per floor (mean)", ""]
kinds = sorted({k for s in data for fl in data[s] for k in data[s][fl].get("kills", {})})
L += ["| floor | " + " | ".join(kinds) + " |", "|---|" + "---|" * len(kinds)]
for fl in allfl:
    t = agg(fl, "kills"); L.append("| %d | " % fl + " | ".join(("%.1f" % statistics.mean(t[k])) if k in t else "-" for k in kinds) + " |")
L += ["", "## Damage taken by source per floor (mean)", ""]
srcs = sorted({k for s in data for fl in data[s] for k in data[s][fl].get("damage", {})}, key=lambda k: -sum(sum(data[s][fl].get("damage", {}).get(k, 0) for fl in data[s]) for s in data))[:14]
L += ["| floor | " + " | ".join(srcs) + " |", "|---|" + "---|" * len(srcs)]
for fl in allfl:
    t = agg(fl, "damage"); L.append("| %d | " % fl + " | ".join(("%.0f" % statistics.mean(t[k])) if k in t else "-" for k in srcs) + " |")
# ---------------------------------------------------------------------------------------------- the outliers
L += ["", "## Outliers (numbers, no tuning)", ""]
flag = []
fls = [fl for fl in allfl if fl >= 1]
for key, name in (("kills", "kills"), ("deaths", "deaths"), ("damage", "damage taken"), ("ticks", "ticks")):
    for fl in fls:
        neigh = [rows[x][key] for x in (fl - 1, fl + 1) if x in rows and x >= 1]
        if neigh and rows[fl][key] > 3 * statistics.mean(neigh) and rows[fl][key] > 5: flag.append("floor %d: %s %.1f is more than 3x its neighbours' %.1f" % (fl, name, rows[fl][key], statistics.mean(neigh)))
for fl in fls:
    if rows[fl]["boss"] is not None and rows[fl]["boss"] < 1200: flag.append("floor %d: the boss fight lasts %.0f ticks (%.0f s): under 20 s" % (fl, rows[fl]["boss"], rows[fl]["boss"] / 60))
    if rows[fl]["deaths"] >= 3 * max(1, statistics.mean(rows[x]["deaths"] for x in fls)): flag.append("floor %d: %.1f deaths per run, against %.1f on average" % (fl, rows[fl]["deaths"], statistics.mean(rows[x]["deaths"] for x in fls)))
    if rows[fl]["kills"] == 0: flag.append("floor %d: no kill at all" % fl)
# a creature that never lands a hit: kinds killed but never named as a damage source
dmg_src = {k for s in data for fl in data[s] for k in data[s][fl].get("damage", {})}
NAMES = {}                      # kind -> display name (the damage source string is the enemy's name, with "Armored " in front for an armoured one)
_txt = open("projects/dungeon_crawler/game/enemies.lua").read()
_chunks = re.split(r"\n    (\w+) = \{", _txt[_txt.index("E.types = {"):])
for _i in range(1, len(_chunks) - 1, 2):
    _m = re.search(r'name = "([^"]+)"', _chunks[_i + 1])
    if _m: NAMES[_chunks[_i]] = _m.group(1)
# one non-creature source that is most of a floor's damage, and the floors where the bot dies most
ENV = ("the lava", "the third rail", "bleeding", "a lava geyser", "falling", "poison")
for fl in fls:
    t = agg(fl, "damage"); total = sum(statistics.mean(v) for v in t.values()) or 1
    for k, v in sorted(t.items(), key=lambda kv: -statistics.mean(kv[1])):
        if any(e in k.lower() for e in ENV) and statistics.mean(v) / total > 0.3 and statistics.mean(v) > 20:
            flag.append("floor %d: %s is %.0f %% of the damage taken (%.0f of %.0f per run; in %d of %d runs)" % (fl, k, 100 * statistics.mean(v) / total, statistics.mean(v), total, sum(1 for x in v if x), len(v)))
    dt = agg(fl, "deaths")
    for k, v in dt.items():
        if statistics.mean(v) >= 1: flag.append("floor %d: %.1f deaths per run by %s" % (fl, statistics.mean(v), k))
dm = statistics.mean(rows[x]["deaths"] for x in fls)
for fl in fls:
    if rows[fl]["deaths"] > 2 * dm: flag.append("floor %d: %.1f deaths per run, more than twice the %.1f average of the floors" % (fl, rows[fl]["deaths"], dm))
for k in kinds:
    nm = NAMES.get(k, k)
    if not any(k.lower() in d.lower() or nm.lower() in d.lower() for d in dmg_src):
        flag.append("%s: killed %d times over the runs and never named as a damage source (check its attack or the source string)" % (k, sum(sum(data[s][fl].get("kills", {}).get(k, 0) for fl in data[s]) for s in data)))
L += ["- " + f for f in flag] if flag else ["- none over the thresholds (3x neighbours, boss under 20 s, a killed kind that never hurts)"]
_o = os.path.join(logdir, "orient_%d.txt" % seeds[0])
if os.path.exists(_o):
    rl = list(dict.fromkeys(l.rstrip() for l in open(_o) if re.match(r"^\w+\s+(cleared|NOT cleared)", l)))
    if rl: L += ["", "## The Orientation (floor 0, seed %d: tools/playthrough.py, one run): per room, level / kills / deaths / hp / gold at the end of the room" % seeds[0], ""] + ["    " + l for l in rl]
L += ["", "Damage sources seen: " + ", ".join(sorted(dmg_src)), "", "Runs: " + ", ".join("%d: floors %s" % (s, sorted(data[s])) for s in data), "Logs: " + logdir]
open(out, "w").write("\n".join(L) + "\n"); print("\n".join(L)); print("written", out)
