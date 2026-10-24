#!/usr/bin/env python3
"""A bot that plays a run on the BIG floors through the MCP server (P2): starts a generated run (skipping the Orientation), and on every floor follows the plan's path from the arrival to the
nearest free stairwell (teleporting from room to room: the walking is tools/p1_walk.py's), fights the rooms on the way with the game's own functions (Game.autoaim, heal items), opens their crates,
equips better gear, takes the stairs. It records the session (--record) and replays it at the end to check the hash; it prints the agent and light counts of every floor.
usage: tools/p2_playthrough.py [SEED] [class] [floors] [--no-replay] [--project P] [--borough]
  --borough: on floor 1 the bot goes to the nearest borough, kills its boss in the rotunda and takes ITS stairwell (the forcefield falls with the boss); the other floors use the free stairwells.
  The floor clock of the bot is 24000 ticks (400 s) so that every threshold (30 / 80 / 95 / 100 %) can be reached; the stairs are waited for if the clock has not opened them."""
import os, subprocess, sys, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith
args = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args[0]) if args else 4242
cls = args[1] if len(args) > 1 else "janitor"
floors = int(args[2]) if len(args) > 2 else 3
project = sys.argv[sys.argv.index("--project") + 1] if "--project" in sys.argv else "projects/dungeon_crawler"
log = "/tmp/descent_big_%d.log" % seed
if os.path.exists(log): os.remove(log)

def L(v, code, ticks=1):
    return v.lua(code, ticks=ticks).get("output", [])

def wait_floor(v, limit=240):
    t = time.time()
    while time.time() - t < limit:
        o = L(v, "print(Game.screen, Game.floorgen.job and Game.floorgen.job.i or 'done')", 20)
        if o and o[0].endswith("done") and not o[0].startswith("loading"): return round(time.time() - t, 1)
    return None

PATH = """
local G = Game
local P = G.floorgen.layout
local plan = P.plan
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
local chain, n = {}, best
while n do table.insert(chain, 1, n); n = par[n] end
local out = {}
for _, id in ipairs(chain) do if P.rooms[id] then out[#out + 1] = id .. ':' .. P.rooms[id].theme end end
print(P.floor, #P.order, table.concat(out, ','))
"""

def fight(v, room, max_ticks=1800, step=60):
    L(v, "Game.autoaim = true; Game.state.mp = Game.player.max_mp()", 1)
    v.tool("input_action", name="attack", down=True, player=0)
    t = 0
    start = L(v, "local G=Game; print(G.state.kills, math.floor(G.state.hp))", 0)[0].split("\t")
    while t < max_ticks:
        out = L(v, """
local G = Game
if G.player.dead then return end
local px, py, pz = player.pos(); local lx, ly, lz = G.to_local(px, py, pz)
local r = G.floorgen.layout.rooms['%s']
if lx < r.x - 8 or lx > r.x + r.w + 8 or lz < r.z - 8 or lz > r.z + r.d + 8 then local c = G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z)) end
if G.state.hp < G.player.max_hp() * 0.45 then G.player.quick('heal') end
print(G.enemies.alive_in('%s'), math.floor(G.state.hp), G.state.deaths)""" % (room, room, room), step)
        v.tool("input_action", name="ability", down=True, player=0)
        t += step
        if t >= 240 and t % 240 == 0:        # (the bot cannot search a room: it goes to the nearest enemy that is still alive)
            L(v, """local G=Game; local best, bd
local px, py, pz = player.pos()
for _, i in pairs(G.enemies.list) do if not i.dead and i.room == '%s' then local x, y, z = G.enemies.position(i); if x then local d = G.dist2(x, z, px, pz); if not bd or d < bd then best, bd = { x, y, z }, d end end end end
local r = G.floorgen.layout.rooms['%s']; local cx, cz = G.mx(r.x + r.w / 2), G.mz(r.z + r.d / 2)
if best and bd > 6 then local dx, dz = cx - best[1], cz - best[3]; local n = math.max(0.1, math.sqrt(dx*dx + dz*dz)); player.teleport(best[1] + dx / n * 2.2, best[2] + 0.1, best[3] + dz / n * 2.2) end""" % (room, room), 1)
        if out and out[0].split("\t")[0] == "0": break
    v.tool("input_action", name="attack", down=False, player=0)
    L(v, "Game.autoaim = false", 0)
    end = L(v, "local G=Game; print(G.state.kills, math.floor(G.state.hp), G.state.deaths, G.state.level)", 0)[0].split("\t")
    return t, int(end[0]) - int(start[0]), end

def counts(v):
    st = v.tool("status")
    n = L(v, "print(Game.enemies.alive_count(), #Game.floorgen.made_list, Game.gen.track.count and 0 or 0)", 0)[0].split("\t")
    return "agents %s cells %s lights %s" % (n[0], n[1], json.dumps(st["render"].get("lights", {})))

def borough_run(v):
    """go to the borough of the floor, kill its boss, take the stairwell behind the forcefield"""
    info = L(v, "local P = Game.floorgen.layout; local r = P.ring_list[1]; if not r then print('none') return end; print(r.id, r.origin, r.pit.x0, r.pit.z0, r.pit.x1, r.pit.z1)", 0)[0].split("\t")
    if info[0] == "none": print("   no borough on this floor"); return False
    rid, origin = info[0], info[1]
    print("  borough", rid, "origin", origin)
    L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z))" % origin, 200)
    L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z)); Game.state.hp = Game.player.max_hp()" % rid, 400)
    print("   current room:", L(v, "print(Game.current_room, Game.boss.started)", 0))
    v.step(500)
    for k in range(6):
        t, kills, end = fight(v, rid, 4800)
        print("   fight", k, "ticks", t, "kills", kills, "hp", end[1], "deaths", end[2], "boss dead:", L(v, "print(Game.state.flags['boss_dead_%s'])" % rid, 0))
        if L(v, "print(Game.state.flags['boss_dead_%s'])" % rid, 0)[0].startswith("true"): break
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z)); Game.state.hp = Game.player.max_hp()" % rid, 300)
    v.step(400)
    print("   forcefield:", L(v, "print(Game.state.flags['ff_%s'])" % rid, 0))
    # into the pit
    L(v, "local G=Game; local r = G.floorgen.layout.rings['%s']; local p = r.pit; player.teleport(G.mx((p.x0 + p.x1) / 2), G.my(-1.1), G.mz((p.z0 + p.z1) / 2))" % rid, 60)
    print("   screen after the pit:", L(v, "print(Game.screen)", 0))
    L(v, "Game.run.descend(true)", 2)
    print("floor %d built in" % 2, wait_floor(v), "s")
    v.step(200)
    L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
    return True

def main():
    maxagents = 0
    with Voxelith(["--project", project, "--threads", "3", "--seed", str(seed), "--record", log]) as v:
        v.step(400)
        L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2)
        L(v, "Game.player.pick_class('%s')" % cls, 2)
        print("floor 1 built in", wait_floor(v), "s")
        v.step(200)
        L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        for fl in range(1, floors + 1):
            L(v, "Game.run.cur().floor_ticks = 24000", 0)
            if "--borough" in sys.argv and fl == 1 and borough_run(v): continue
            info = L(v, PATH, 0)[0].split("\t")
            print("FLOOR", info[0], "cells", info[1], "path", info[2])
            rooms = [x.split(":") for x in info[2].split(",")]
            for rid, theme in rooms:
                L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z))" % rid, 150)
                if theme == "stairs_free": break
                t, kills, end = fight(v, rid, 2400)
                n = int(L(v, "print(Game.enemies.alive_count())", 0)[0]); maxagents = max(maxagents, n)
                # the crates of the room, in a sorted order (`pairs` over string keys differs between processes)
                L(v, "local G=Game; local ids = {}; for id, c in pairs(G.traps.crates) do if c.cell == '%s' then ids[#ids+1] = id end end; table.sort(ids); for _, id in ipairs(ids) do G.traps.open_crate(id) end" % rid, 60)
                L(v, """local G=Game
for _, s in ipairs(G.items.inv.bag) do
  if s then local d = G.items.defs[s.id]
    if d and d.kind == 'weapon' and d.dmg and (d.dmg[1] + d.dmg[2]) > (G.player.weapon().dmg[1] + G.player.weapon().dmg[2]) then G.player.equip(s.id) end
    if d and d.kind == 'armor' and (d.def or 0) > ((G.items.defs[G.state.equip.armor or ''] or {}).def or -1) then G.player.equip(s.id) end
  end
end""", 5)
                print("  %-6s %-11s ticks %4d kills %2d  hp %s deaths %s level %s   %s" % (rid, theme, t, kills, end[1], end[2], end[3], counts(v))); sys.stdout.flush()
            print("  at the stairwell: the recap, then down")
            if fl < floors:
                L(v, "local G = Game; local F = G.floorgen; local P = F.layout; local id = P.free_list[1]; if id and not F.stairs_open(id) then G.run.cur().fclock = math.floor(F.floor_ticks() * F.AT_OPEN) + 60 end", 120)    # (the clock opens the stairs)
                L(v, "local G = Game; local F = G.floorgen; local P = F.layout; local best; for _, id in ipairs(P.plan.stairs) do if id:sub(1, 1) == 'c' and (not best) then best = id end end; local r = P.rooms[best]; F.stairs_enter(best)", 3)    # (the pit does this when the player steps down)
                if not L(v, "print(Game.screen == 'recap')", 0)[0].startswith('true'):
                    L(v, "Game.run.descend()", 3)
                print("   screen:", L(v, "print(Game.screen)", 0))
                L(v, "Game.run.descend(true)", 2)
                print("floor %d built in" % (fl + 1), wait_floor(v), "s")
                v.step(200)
                L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        errs = [l.strip() for l in v.stderr_tail(2000).splitlines() if "[error]" in l or "[warn" in l or "failed" in l]
        print("engine errors / warnings:", errs[-8:] if errs else "none")
        print("max agents seen at the end of a fight:", maxagents)
        print("hook:", json.dumps(v.tool("status")["world"].get("hook")))
        print("state hash:", v.state_hash())
    if "--no-replay" not in sys.argv:
        print("replaying the recording ...")
        r = subprocess.run([os.path.join(ROOT, "voxelith"), "--replay", log, "--threads", "3"], capture_output=True, text=True, cwd=ROOT)
        print([l for l in (r.stdout + r.stderr).splitlines() if "hash" in l.lower() or "replay" in l.lower()][-4:])
main()
