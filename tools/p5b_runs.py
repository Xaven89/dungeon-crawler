#!/usr/bin/env python3
"""P5b: a run ends and the next run starts in the SAME session (run 1 -> run 2), through the game's own run screen (Game.run.start(N, true)).
Checks: the floors differ (plan signatures), the band of floor 1 holds no voxel of run 1 after the reset (region_hash of the band: before, right after the reset, after the new floor, against a
fresh session that starts run 2 directly), the save file does not grow by a floor per run, the veil (pictures of the player's view during the loading screen), and the replay hash.
usage: tools/p5b_runs.py [SEED] [RUN_A=1] [RUN_B=2] [--no-replay]"""
import os, subprocess, sys, time, json, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g
args = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args[0]) if args else 4242
RA = int(args[1]) if len(args) > 1 else 1
RB = int(args[2]) if len(args) > 2 else 2
project = "projects/dungeon_crawler"
SCRATCH = "/tmp/descent_scratch.vxs"
SH = os.path.expanduser("~/share/big_floors_p5b"); os.makedirs(SH, exist_ok=True)
log = "/tmp/descent_p5b_%d.log" % seed
def fresh(keep_log=False):
    for p in _g.glob(SCRATCH + '*'): (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
    if keep_log: return
    if os.path.exists(log): os.remove(log)
    if os.path.isdir(log + ".clip"): shutil.rmtree(log + ".clip")
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
def wait_floor(v, limit=240):
    t = time.time()
    while time.time() - t < limit:
        o = L(v, "print(Game.screen, Game.floorgen.job and Game.floorgen.job.i or 'done')", 20)
        if o and o[0].endswith("done") and not o[0].startswith("loading"): return round(time.time() - t, 1)
    return None
def size(): return sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(SCRATCH) for f in fs) if os.path.isdir(SCRATCH) else os.path.getsize(SCRATCH)
SIG = """local P = Game.floorgen.layout; local t = {}
for _, id in ipairs(P.order) do local r = P.rooms[id]; t[#t + 1] = id .. ':' .. r.theme end
print(P.floor, P.plan.arrival, #P.order, worldgen.run_seed(), table.concat(t, ','))"""
def band_box(n, arr=None):
    """the voxel box of floor n's band (the whole band, or a window of +-48 m around a point given in metres of the floor frame)"""
    z0, z1 = (n * 32 + 1) * 512, (n * 32 + 21) * 512 - 1
    return [-1024, 0, z0], [9727, 700, z1]
STATE_DIRS = [".state", ".events", ".prefabs"]
def snapshot_state():
    snap = os.path.join("/tmp", "descent_state_snapshot_%d" % os.getpid())
    if os.path.exists(snap): shutil.rmtree(snap)
    os.makedirs(snap); present = []
    for d in STATE_DIRS:
        src = os.path.join(ROOT, project, d)
        if os.path.isdir(src): shutil.copytree(src, os.path.join(snap, d)); present.append(d)
    return snap, present
def restore_state(snap, present):
    for d in STATE_DIRS:
        dst = os.path.join(ROOT, project, d)
        if os.path.isdir(dst): shutil.rmtree(dst)
        if d in present: shutil.copytree(os.path.join(snap, d), dst)
def start_run(v, no, cls="janitor"):
    L(v, "Game.screen = 'run'; Game.run.start(%d, true)" % no, 2)
BOXES = {}       # floor -> list of (lo, hi) voxel boxes (the engine allows 8M cells per region_hash)
def box_around(x, y, z, r=80): return [x - r, max(0, y - r), z - r], [x + r - 1, y + r - 1, z + r - 1]
def hashes(v, n, label, out):
    t = time.time(); hs = []
    if "--no-hash" in sys.argv: return
    for lo, hi in BOXES[n]: hs.append(v.region_hash(lo, hi))
    out[label] = ",".join("%08x" % (int(h) & 0xffffffff) if not isinstance(h, str) else h[:8] for h in hs)
    print("  region_hash floor %d %-34s %s  (%d boxes, %.1f s)" % (n, label, out[label][:60], len(hs), time.time() - t)); sys.stdout.flush()
def arrival_window(v):
    """the arrival room's centre in world voxels"""
    o = L(v, "local G = Game; local P = G.floorgen.layout; local c = G.world.checkpoints[P.plan.arrival]; print(math.floor(units.vox(G.mx(c.x))), math.floor(units.vox(G.mz(c.z))))", 0)[0].split("\t")
    return [int(x) for x in o]

def session_a(res):
    snap, present = snapshot_state()
    fresh()
    with Voxelith(["--project", project, "--threads", "3", "--save", SCRATCH, "--seed", str(seed), "--record", log]) as v:
        v.step(400)
        s0 = size()
        start_run(v, RA)
        L(v, "Game.player.pick_class('janitor')", 2)
        print("run %d floor 1 built in" % RA, wait_floor(v), "s"); v.step(200)
        L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        sig1 = L(v, SIG, 0)[0].split("\t"); res["sig_a1"] = sig1
        print("run %d floor 1:" % RA, sig1[:4])
        # the boxes that are hashed: the arrival room's surroundings (3x3 tiles) and every spot where the bot blew a hole
        ax, az = arrival_window(v)
        BOXES[1] = [box_around(ax + 160 * i, 128 + 40, az + 160 * j, 80) for i in (-1, 0, 1) for j in (-1, 0, 1)]
        # play a little: walk through rooms and blow holes in them (edits in the band)
        rooms = [x.split(":")[0] for x in sig1[4].split(",")][:6]
        for rid in rooms:
            L(v, "local G=Game; local c=G.world.checkpoints['%s']; if c then player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true }) end" % rid, 150)
            o = L(v, "local px, py, pz = player.pos(); local x, y, z = math.floor(units.vox(px)) + 40, math.floor(units.vox(py)) + 20, math.floor(units.vox(pz)); fx.explosion(x, y, z, 24, 0.6); edit.box(x - 8, y - 30, z - 8, x + 8, y - 28, z + 8, 'marble'); print(x, y, z)", 40)[0].split("\t")
            BOXES[1].append(box_around(*[int(c) for c in o]))
        v.step(120)
        hashes(v, 1, "run A, floor 1 played", res)
        L(v, "Game.run.cur().floor_ticks = 24000", 0)
        L(v, "Game.run.begin_floor(2)", 2); print("run %d floor 2 built in" % RA, wait_floor(v), "s"); v.step(120)
        L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        BOXES[2] = [box_around(int(8 * 16), 128 + 40, (2 * 32 + 2) * 512 + 8 * 16, 80)]
        hashes(v, 2, "run A, floor 2", res)
        v.tool("save_world"); res["size_a"] = size(); print("save size: start %d, after run %d (2 floors): %d" % (s0, RA, res["size_a"]))
        # the next run, in the same session
        if "--trace-screen" in sys.argv:
            L(v, """local G = Game; local cur = G.screen; rawset(G, 'screen', nil)
setmetatable(G, { __index = function(t, k) if k == 'screen' then return cur end end, __newindex = function(t, k, val)
  if k == 'screen' then if cur == 'loading' and val ~= 'loading' then error('SCREEN ' .. tostring(cur) .. ' -> ' .. tostring(val) .. ' at ' .. time.tick()) end cur = val else rawset(t, k, val) end end })""", 0)
        start_run(v, RB)
        trace, last = [], None
        for tk in range(0, 170, 5):
            o = L(v, "print(Game.screen, Game.floorgen.job and 'job' or '-', Game.rebuilding)", 0)[0].replace("\t", " ")
            if "--trace-screen" in sys.argv:
                for l in v.stderr_tail(400).splitlines():
                    if "SCREEN" in l or "traceback" in l or l.strip().startswith(("[C]", "game/", "level")) or ".lua:" in l: print("  LOG", l.strip()[:200])
            if o != last: trace.append("tick +%d: %s" % (tk, o)); last = o
            if tk in (5, 30, 60) and "--no-shots" not in sys.argv: v.screenshot(os.path.join(SH, "veil_%03d.png" % tk), hud=True, settle=1)
            v.step(5)
        print("veil (screen, job, rebuilding):", "; ".join(trace)); res["veil"] = trace
        print("veil: run_no", L(v, "print(worldgen.run_seed(), Game.screen)", 0))
        hashes(v, 1, "right after the reset (band 1)", res)
        hashes(v, 2, "right after the reset (band 2)", res)
        v.step(200)
        L(v, "Game.player.pick_class('janitor')", 2)
        print("run %d floor 1 built in" % RB, wait_floor(v), "s"); v.step(200)
        L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        sig2 = L(v, SIG, 0)[0].split("\t"); res["sig_a2"] = sig2
        print("run %d floor 1:" % RB, sig2[:4])
        v.step(300)
        hashes(v, 1, "run B, floor 1 (session A)", res)
        hashes(v, 2, "run B, band 2 (untouched)", res)
        v.screenshot(os.path.join(SH, "run2_arrival.png"), hud=True, settle=30)
        v.tool("save_world"); res["size_b"] = size(); print("save size after run %d (floor 1): %d" % (RB, res["size_b"]))
        for k in range(3, 3 if '--two' in sys.argv else 5):
            RC = RB + k - 2
            start_run(v, RC); v.step(200); L(v, "Game.player.pick_class('janitor')", 2); wait_floor(v); v.step(300)
            L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
            v.tool("save_world"); res["size_%d" % k] = size(); print("save size after run %d (floor 1): %d" % (RC, res["size_%d" % k]))
        errs = [l.strip() for l in v.stderr_tail(3000).splitlines() if "[error]" in l or "[warn" in l or "failed" in l]
        print("engine errors / warnings:", errs[-8:] if errs else "none")
        print("hook:", json.dumps(v.tool("status")["world"].get("hook")))
        v.step(5)         # (a save_world after the last tick is not replayed: the recording ends at the last tick)
        res["state_a"] = v.state_hash(); print("state hash:", res["state_a"])
    return snap, present

def session_b(res):
    fresh(True)
    with Voxelith(["--project", project, "--threads", "3", "--save", SCRATCH, "--seed", str(seed)]) as v:
        v.step(400)
        start_run(v, RB)
        L(v, "Game.player.pick_class('janitor')", 2)
        print("fresh run %d floor 1 built in" % RB, wait_floor(v), "s"); v.step(200)
        L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        sig = L(v, SIG, 0)[0].split("\t"); res["sig_b"] = sig
        v.step(300)
        hashes(v, 1, "fresh start of run B", res)
        v.tool("save_world"); res["size_fresh"] = size(); print("save size of a fresh start of run %d: %d" % (RB, res["size_fresh"]))
        hashes(v, 2, "fresh start of run B (band 2)", res)
        v.screenshot(os.path.join(SH, "run2_arrival_fresh.png"), hud=True, settle=30)

res = {}
snap, present = session_a(res)
session_b(res)
try:
    print("--- verdict")
    print("floors differ:", res["sig_a1"][4] != res["sig_a2"][4], "(run %d: %s cells, arrival %s; run %d: %s cells, arrival %s)" % (RA, res["sig_a1"][2], res["sig_a1"][1], RB, res["sig_a2"][2], res["sig_a2"][1]))
    print("run B in session A same plan as a fresh start:", res["sig_a2"][1:] == res["sig_b"][1:])
    print("band 1 after the new floor == fresh start:", res["run B, floor 1 (session A)"] == res["fresh start of run B"], "| band 2 untouched == fresh:", res["run B, band 2 (untouched)"] == res["fresh start of run B (band 2)"])
    print("band 1 after the reset == band 2 after the reset == (empty):", res["right after the reset (band 1)"], res["right after the reset (band 2)"])
    print("save sizes:", {k: v for k, v in res.items() if k.startswith("size")})
    print("save size: after run A %d, after run B %d (%+d)" % (res["size_a"], res["size_b"], res["size_b"] - res["size_a"]))
except KeyError as e: print('(verdict incomplete:', e, ')')
if "--no-replay" not in sys.argv:
    restore_state(snap, present)
    for p in _g.glob(SCRATCH + '*'): (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
    print("replaying the recording ...")
    r = subprocess.run([os.path.join(ROOT, "voxelith"), "--replay", log, "--threads", "3", "--save", SCRATCH], capture_output=True, text=True, cwd=ROOT)
    print([l for l in (r.stdout + r.stderr).splitlines() if "hash" in l.lower() or "replay" in l.lower()][-4:], "live:", res["state_a"])
