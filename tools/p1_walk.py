#!/usr/bin/env python3
"""A walk on foot through the big floor's shells (P1 exit test): an agent walks (the engine's nav + agent code, the world streams around the player who is carried along) from the arrival room to the nearest free
stairwell along the plan's path (rooms, halls, artery strips), without teleporting. Pictures of the way in ~/share/big_floors_p1/walk_*.png.
usage: tools/p1_walk.py [SEED] [--floor N] [--shots]   (the world seed goes into projects/dc_p1/project.cfg; tools/p1_sync.sh first)"""
import os, sys, re, time, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
import glob as _g, shutil as _sh
def _fresh_scratch():
    for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
_fresh_scratch()   # (the engine of 2026-10-24 needs --save for a project with save=: a scratch file keeps the game's own world.vxs untouched)
ap = argparse.ArgumentParser(); ap.add_argument("seed", nargs="?", type=int, default=1); ap.add_argument("--floor", type=int, default=1); ap.add_argument("--shots", action="store_true")
ns = ap.parse_args()
fl, seed = ns.floor, ns.seed
SH = os.path.expanduser("~/share/big_floors_p1"); os.makedirs(SH, exist_ok=True)
BZ = fl * 1024.0 + 64.0
PATH = """
local CG = cellgen_make(cellgen_hash_from(worldgen.hash))
local ctx = CG.new(0, %d, 'small')
local plan = CG.plan(0, %d, 'small')
local P = plan.P
-- BFS with parents over the plan, gates closed
local par, dist, q = {}, { [plan.arrival] = 0 }, { plan.arrival }
local qh = 1
while qh <= #q do
  local u = q[qh]; qh = qh + 1
  for _, a in ipairs(plan.adj[u]) do
    if not a.edge.gate and not dist[a.to] then dist[a.to] = dist[u] + 1; par[a.to] = u; q[#q + 1] = a.to end
  end
end
local best
for _, id in ipairs(plan.stairs) do if dist[id] and id:sub(1, 1) == 'c' and (not best or dist[id] < dist[best]) then best = id end end
local chain = {}
local n = best
while n do table.insert(chain, 1, n); n = par[n] end
for _, id in ipairs(chain) do
  local x, z
  local nd = plan.nodes[id]
  if id:sub(1, 1) == 'c' then
    local c = plan.cells[id]; local r = c.room
    x = c.ci * 32 + r.x + r.w / 2 + ((id == best) and 4 or 0); z = c.cj * 32 + r.z + r.d / 2
  elseif id:sub(1, 2) == 'av' then local k, cj = id:match('av(%%d+)_(%%d+)'); x = tonumber(k) * 256; z = tonumber(cj) * 32 + 16
  elseif id:sub(1, 2) == 'ah' then local m, ci = id:match('ah(%%d+)_(%%d+)'); x = tonumber(ci) * 32 + 16; z = tonumber(m) * 256
  elseif id:sub(1, 2) == 'ap' then local k, m = id:match('ap(%%d+)_(%%d+)'); x = tonumber(k) * 256; z = tonumber(m) * 256 end
  if x then print('W', id, x, z) end
end
""" % (fl, fl)
with Voxelith(["--project", "projects/dc_p1", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed)]) as v:
    v.step(20)
    out = v.lua(PATH, ticks=0)["output"]
    wps = [(l.split("\t")[1], float(l.split("\t")[2]), float(l.split("\t")[3])) for l in out if l.startswith("W")]
    print("path:", " ".join(w[0] for w in wps))
    v.lua("Game.screen = nil; Game.frozen_at = nil; player.teleport(%f, 8.0, %f)" % (wps[0][1], BZ + wps[0][2]), ticks=1)
    v.step(120)
    v.lua("Game.walker = agent.spawn{ x = %f, y = 8.05, z = %f, speed = 6 }" % (wps[0][1], BZ + wps[0][2]), ticks=1)
    t0 = time.time(); ticks = 0; ok = True
    for i, (nid, x, z) in enumerate(wps[1:], 1):
        r = v.lua("local a = agent.info(Game.walker); player.teleport(a.x, a.y, a.z); local f, p = agent.walk(Game.walker, %f, 8.05, %f); print(tostring(f), tostring(p))" % (x, BZ + z), ticks=1)["output"]
        done = False
        for k in range(60):
            v.step(30); ticks += 30
            a = v.lua("local a = agent.info(Game.walker); player.teleport(a.x, a.y, a.z); print(a.x, a.z, a.mode)", ticks=0)["output"][0].split("\t")
            dx, dz = float(a[0]) - x, float(a[1]) - (BZ + z)
            if dx * dx + dz * dz < 2.0 * 2.0: done = True; break
            if a[2] == "idle": break
        if ns.shots and (i % 3 == 0 or i == len(wps) - 1):
            # temporary lights (the torches are P2's): two campfire lights over the walker
            v.lua("emitter.create{ name = 'wl%d', preset = 'campfire', pos = { %s, 12, %s }, light = { color = { 1, 0.85, 0.6 }, intensity = 40, reach = 24 } }; emitter.create{ name = 'wm%d', preset = 'campfire', pos = { %f, 12, %f }, light = { color = { 1, 0.85, 0.6 }, intensity = 40, reach = 24 } }" % (i, a[0], a[1], i, x, BZ + z), ticks=1)
            v.step(90)
            v.screenshot(SH + "/walk_%02d_%s.png" % (i, nid), eye=[float(a[0]) - 3, 10.0, float(a[1]) - 3], target=[x, 9.0, BZ + z], fov=85)
            v.lua("emitter.remove('wl%d'); emitter.remove('wm%d')" % (i, i), ticks=1)
        if not done:
            print("STUCK on the way to %s (%s): at (%s, %s), wanted (%.1f, %.1f), mode %s" % (nid, i, a[0], a[1], x, BZ + z, a[2])); ok = False; break
    print("walk %s: %d waypoints, %d ticks (%.0f s of game time), %.0f s real" % ("REACHED THE STAIRWELL" if ok else "FAILED", len(wps), ticks, ticks / 60, time.time() - t0))
sys.exit(0 if ok else 1)
