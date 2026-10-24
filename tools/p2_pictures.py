#!/usr/bin/env python3
"""Pictures of the big floors in the running game (HUD included): tools/p2_pictures.py [SEED] -> ~/share/big_floors_p2/*.png: the arrival with the HUD and the map, a fight, a hall, the stairwell,
and the numbers of the floor (agents, cells alive, lights drawn / cut by the budget, hook ms)."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
seed = int(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else 4242
SH = os.path.expanduser("~/share/big_floors_p2"); os.makedirs(SH, exist_ok=True)
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--seed", str(seed)]) as v:
    v.step(300)
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(120)
    path = L(v, """local P = Game.floorgen.layout; local plan = P.plan
local par, dist, q = {}, { [plan.arrival] = 0 }, { plan.arrival }
local qh = 1
while qh <= #q do local u = q[qh]; qh = qh + 1; for _, a in ipairs(plan.adj[u]) do if not a.edge.gate and not dist[a.to] then dist[a.to] = dist[u] + 1; par[a.to] = u; q[#q + 1] = a.to end end end
local best
for _, id in ipairs(plan.stairs) do if dist[id] and id:sub(1, 1) == 'c' and (not best or dist[id] < dist[best]) then best = id end end
local chain, n = {}, best
while n do table.insert(chain, 1, n); n = par[n] end
local out = {}
for _, id in ipairs(chain) do if P.rooms[id] then out[#out + 1] = id .. ':' .. P.rooms[id].theme end end
print(table.concat(out, ','))""", 0)[0].split(",")
    print("path", path)
    def shot(name, settle=90, **kw):
        v.screenshot(os.path.join(SH, name + ".png"), hud=True, settle=settle, **kw)
    shot("hud_arrival")
    shown = {"hall": False, "stairs_free": False}
    for i, e in enumerate(path):
        rid, theme = e.split(":")
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z)); Game.state.hp = Game.player.max_hp()" % rid, 200)
        if theme in ("hall", "crypt", "grotto", "library", "depot", "furnace", "flooded") and not shown.get("fight"):
            v.step(120)
            shot("hud_room_" + theme); shown["fight"] = True
        if i in (6, 12): shot("hud_map_%d" % i)
    print(L(v, "local G=Game; print(G.enemies.alive_count(), #G.floorgen.made_list)", 0))
    st = v.tool("status")
    shot("hud_last")
    st = v.tool("status")
    print("render", json.dumps(st["render"]), "hook", json.dumps(st["world"].get("hook")))
    print("sim", json.dumps(st["sim"]))
