#!/usr/bin/env python3
"""A bot that plays a run on the BIG floors through the MCP server (P2): starts a generated run (skipping the Orientation), and on every floor follows the plan's path from the arrival to the
nearest free stairwell (teleporting from room to room: the walking is tools/p1_walk.py's), fights the rooms on the way with the game's own functions (Game.autoaim, heal items), opens their crates,
equips better gear, takes the stairs. It records the session (--record) and replays it at the end to check the hash; it prints the agent and light counts of every floor.
usage: tools/p2_playthrough.py [SEED] [class] [floors] [--no-replay] [--project P] [--borough [--borough-floor N]] [--park] [--first-floor N]
  --borough: on floor 1 the bot goes to the nearest borough, kills its boss in the rotunda and takes ITS stairwell (the forcefield falls with the boss); the other floors use the free stairwells.
  --park: the same on floor 3 (the park boss and the stairwell behind its forcefield). --first-floor N: the run starts on floor N (2, 3, 5 ...).
  The floor clock of the bot is 24000 ticks (400 s) so that every threshold (30 / 80 / 95 / 100 %) can be reached; the stairs are waited for if the clock has not opened them."""
import os, subprocess, sys, time, json, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith, state_dir_args
import glob as _g, shutil as _sh
def _fresh_scratch():
    for p in _g.glob('/tmp/descent_scratch.vxs*'): (_sh.rmtree if os.path.isdir(p) else os.remove)(p)
_fresh_scratch()   # (the engine of 2026-10-24 needs --save for a project with save=: a scratch file keeps the game's own world.vxs untouched)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args[0]) if args else 4242
cls = args[1] if len(args) > 1 else "janitor"
floors = int(args[2]) if len(args) > 2 else 3
project = sys.argv[sys.argv.index("--project") + 1] if "--project" in sys.argv else "projects/dungeon_crawler"
log = "/tmp/descent_big_%d.log" % seed
if os.path.exists(log): os.remove(log)
if os.path.isdir(log + ".clip"): shutil.rmtree(log + ".clip")      # (the engine does not clear an old clip: a stale store_0.json of an earlier run made the replay start from the wrong state)

def L(v, code, ticks=1):
    return v.lua(code, ticks=ticks).get("output", [])

def wait_floor(v, limit=240):
    t = time.time()
    while time.time() - t < limit:
        o = L(v, "print(Game.screen, Game.floorgen.job and Game.floorgen.job.i or 'done')", 20)
        if o and o[0].endswith("done") and not o[0].startswith("loading"): return round(time.time() - t, 1)
    return None

TALLY_LUA = """local G = Game; local fl = G.run.floor_no(); local s = G.stats[fl] or {}; local out = {}
for group, g in pairs(s) do for key, n in pairs(g) do out[#out + 1] = group .. '|' .. key .. '|' .. n end end
table.sort(out); print(table.concat(out, ';'))"""
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

def act(v, **kw):
    """an input action. (It used to sync with a state_hash first: that masked a real cause, the project folder's persisted state that one run leaves for the next; every Voxelith() now starts with a fresh
    --state-dir (voxelith_client.state_dir_args) and two live runs of one seed agree without any sync: engine 6a8e1fe, ENGINE_FEEDBACK Phase 27.)"""
    return v.tool("input_action", **kw)

def fight(v, room, max_ticks=1800, step=60):
    if os.environ.get("HASH_TRACE"): print("   H", room, "start", v.state_hash())
    L(v, "Game.autoaim = true; Game.state.mp = Game.player.max_mp()", 1)
    act(v, name="attack", down=True, player=0)
    t = 0
    start = L(v, "local G=Game; print(G.state.kills, math.floor(G.state.hp))", 0)[0].split("\t")
    while t < max_ticks:
        out = L(v, """
local G = Game
if G.player.dead then return end
local px, py, pz = player.pos(); local lx, ly, lz = G.to_local(px, py, pz)
local r = G.floorgen.layout.rooms['%s']
if lx < r.x - 8 or lx > r.x + r.w + 8 or lz < r.z - 8 or lz > r.z + r.d + 8 then local c = G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true }) end
if G.state.hp < G.player.max_hp() * 0.45 then G.player.quick('heal') end
print(G.enemies.alive_in('%s'), math.floor(G.state.hp), G.state.deaths)""" % (room, room, room), step)
        act(v, name="ability", down=True, player=0)
        t += step
        if os.environ.get("HASH_TRACE"): print("   H", room, t, v.state_hash())             # (two live runs of one seed: the first line that differs says where they part)
        if os.environ.get("BOSS_TRACE") and t % 480 == 0:      # who is where: the player, then every living enemy of the room (kind, distance, height above the player, hp, its state)
            print("   trace t", t, L(v, """local G=Game; local px, py, pz = player.pos(); local t = {}
for _, i in pairs(G.enemies.list) do if not i.dead and i.room == '%s' then local x, y, z = G.enemies.position(i); if x then t[#t + 1] = string.format('%%s d%%.1f dy%%.1f hp%%.0f %%s', i.kind, G.dist2(x, z, px, pz), y - py, i.hp, tostring(i.state or i.mode or '')) end end end
table.sort(t); print(string.format('player (%%.1f,%%.1f,%%.1f) hp %%.0f | ', px, py, pz, G.state.hp) .. table.concat(t, ' | '))""" % room, 0))
            if os.environ.get("BOSS_TRACE") == "2":
                print("   boss/walls", L(v, """local G=Game; local P = G.floorgen.layout; local ring = P.rings and P.rings['%s']; local out = {}
local i0; for _, i in pairs(G.enemies.list) do if i.T and i.T.boss and not i.dead then i0 = i; local x, y, z = G.enemies.position(i); out[#out + 1] = string.format('boss at (%%.1f,%%.2f,%%.1f) hp %%.0f state %%s ai_is_boss %%s', x - G.mx(0), y, z - G.mz(0), i.hp, tostring(i.state), tostring(i.ai == G.boss.ai)) end end
if i0 then local x, y, z = G.enemies.position(i0); local col = {}; for k = 0, 12 do local m = world.material_at(math.floor(x * 16), math.floor((y + 1.0 - k * 0.5) * 16), math.floor(z * 16)); col[#col + 1] = (m and m ~= 'air') and m or '.' end; out[#out + 1] = 'column below (every 0.5 m from +1.0): ' .. table.concat(col, ' ') end
out[#out + 1] = string.format('safe %%s room %%s lair %%s started %%s active %%s', tostring(G.safe), tostring(G.current_room), tostring(G.boss.lair and G.boss.lair.room), tostring(G.boss.started), tostring(G.boss.active))
if ring and ring.walls then for _, w in ipairs(ring.walls) do out[#out + 1] = string.format('wall %%s %%s (%%.0f,%%.0f)', tostring(w.w.id), w.open and 'OPEN' or 'shut', w.x, w.z) end end
print(table.concat(out, ' | '))""" % room, 0))
        if os.environ.get("BODIES_TRACE"):
            bl = v.tool("bodies")["bodies"]; lowc = len([x for x in bl if x["pos_m"][1] < -5])
            if lowc != fight.last: print("   t %d: bodies below the world %d (alive in room: %s, first: %s)" % (t, lowc, out[0] if out else "?", [(x["id"], x["voxels"], [round(c) for c in x["pos_m"]]) for x in bl if x["pos_m"][1] < -5][:2])); fight.last = lowc
        if t >= 240 and t % 240 == 0:        # (the bot cannot search a room: it goes to the nearest enemy that is still alive)
            L(v, """local G=Game; local best, bd
local px, py, pz = player.pos()
for _, i in pairs(G.enemies.list) do if not i.dead and i.room == '%s' then local x, y, z = G.enemies.position(i); if x then local d = G.dist2(x, z, px, pz); if not bd or d < bd then best, bd = { x, y, z }, d end end end end
local r = G.floorgen.layout.rooms['%s']; local cx, cz = G.mx(r.x + r.w / 2), G.mz(r.z + r.d / 2)
if best and bd > 6 then local dx, dz = cx - best[1], cz - best[3]; local n = math.max(0.1, math.sqrt(dx*dx + dz*dz)); local tx, ty, tz = best[1] + dx / n * 2.2, best[2] + 0.1, best[3] + dz / n * 2.2; local function solid(h) return world.solid(math.floor(tx * 16), math.floor((ty + h) * 16), math.floor(tz * 16)) end; local ground = world.solid(math.floor(tx * 16), math.floor((ty - 0.2) * 16), math.floor(tz * 16)); if ground and not (solid(0.2) or solid(1.0) or solid(1.7)) then player.teleport(tx, ty, tz, { wait = true }) end end""" % (room, room), 1)
        if out and out[0].split("\t")[0] == "0": break
    act(v, name="attack", down=False, player=0)
    L(v, "Game.autoaim = false", 0)
    end = L(v, "local G=Game; print(G.state.kills, math.floor(G.state.hp), G.state.deaths, G.state.level)", 0)[0].split("\t")
    return t, int(end[0]) - int(start[0]), end

fight.last = -1
def counts(v):
    st = v.tool("status")
    n = L(v, "print(Game.enemies.alive_count(), #Game.floorgen.made_list, Game.gen.track.count and 0 or 0)", 0)[0].split("\t")
    return "agents %s cells %s lights %s" % (n[0], n[1], json.dumps(st["render"].get("lights", {})))

def body_summary(v, label):
    if not os.environ.get("BODIES_TRACE"): return
    st = v.tool("status")["sim"]; b = v.tool("bodies")
    low = [x for x in b["bodies"] if x["pos_m"][1] < -5]
    print("   BODIES %-22s total %s awake %s | listed %d, below the world %d, big (>2000 voxels) %d: %s" % (label, st["bodies"], st["awake_bodies"], len(b["bodies"]), len(low), len([x for x in b["bodies"] if x["voxels"] > 2000]),
          [(x["id"], x["voxels"], [round(c) for c in x["pos_m"]]) for x in b["bodies"] if x["voxels"] > 2000][:4]))

def below_world(v):
    return L(v, "local E = Game.enemies; local n = 0; for id, inst in pairs(E.list) do local x, y, z = E.position(inst); if y and y < -5 then n = n + 1; if n <= 6 then print(id, inst.kind, tostring(inst.dead), inst.room, string.format('%.1f %.1f %.1f', x, y, z)) end end end; print('below', n)", 0)

def body_table(v, label):
    """BODY_TABLE=1: the loose bodies of the session by owner and by floor band (a leak across floors shows as bodies in a band the player has left)"""
    if not os.environ.get("BODY_TABLE"): return
    o = L(v, """local rows, bands, mass = {}, {}, {}
local n = 0
for _, b in ipairs(body.list()) do
  n = n + 1
  local key = b.owner .. (b.kinematic and ':kin' or '')
  local r = rows[key] or { 0, 0 }; r[1] = r[1] + 1; if b.awake then r[2] = r[2] + 1 end; rows[key] = r
  local band = math.floor((b.z - 64) / 1024)
  local bb = bands[band] or { 0, 0 }; bb[1] = bb[1] + 1; if b.awake then bb[2] = bb[2] + 1 end; bands[band] = bb
  if b.owner == 'script' then local k = (b.mass < 20 and 'script<20kg') or (b.mass < 60 and 'script<60kg') or (b.mass < 400 and 'script<400kg') or 'script>=400kg'; mass[k] = (mass[k] or 0) + 1 end
end
local t = {}
for k, r in pairs(rows) do t[#t + 1] = k .. '=' .. r[1] .. '(' .. r[2] .. ' awake)' end; table.sort(t)
local tb = {}
for k, r in pairs(bands) do tb[#tb + 1] = 'band' .. k .. '=' .. r[1] end; table.sort(tb)
local tm = {}
for k, c in pairs(mass) do tm[#tm + 1] = k .. '=' .. c end; table.sort(tm)
print(n, table.concat(t, ' '), '|', table.concat(tb, ' '), '|', table.concat(tm, ' '))""", 0)
    print("   BODIES %-28s %s" % (label, o[0].replace("\t", " ") if o else "?"))

def borough_run(v):
    """go to the borough of the floor, kill its boss, take the stairwell behind the forcefield"""
    info = L(v, "local P = Game.floorgen.layout; local r = P.ring_list[1]; if not r then print('none') return end; print(r.id, r.origin, r.pit.x0, r.pit.z0, r.pit.x1, r.pit.z1)", 0)[0].split("\t")
    if info[0] == "none": print("   no borough on this floor"); return False
    rid, origin = info[0], info[1]
    print("  borough", rid, "origin", origin)
    L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % origin, 200)
    L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true }); Game.state.hp = Game.player.max_hp()" % rid, 400)
    print("   current room:", L(v, "print(Game.current_room, Game.boss.started)", 0))
    v.step(500)
    def arena_floor():          # solid voxels in the slab 1.5 m under the arena floor, 9 m round the middle of the ring (the pit is inside it: the same before and after): a slam that digs shows here
        c = L(v, "local G=Game; local r = G.floorgen.layout.rings['%s']; local g = r.g; print(G.wx(r.ox + g.cx), G.wy(0), G.wz(r.oz + g.cz))" % rid, 0)[0].split("\t")
        cx, cy, cz = int(float(c[0])), int(float(c[1])), int(float(c[2]))
        r_ = v.tool("count_voxels", min=[cx - 144, cy - 24, cz - 144], max=[cx + 144, cy - 1, cz + 144])
        c_ = r_.get("counts", {}); return "air %d solid %d" % (c_.get("air", 0), sum(n for m, n in c_.items() if m != "air"))
    floor_before = arena_floor()
    for k in range(6):
        t, kills, end = fight(v, rid, 4800)
        print("   fight", k, "ticks", t, "kills", kills, "hp", end[1], "deaths", end[2], "boss dead:", L(v, "print(Game.state.flags['boss_dead_%s'])" % rid, 0))
        if L(v, "print(Game.state.flags['boss_dead_%s'])" % rid, 0)[0].startswith("true"): break
        L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true }); Game.state.hp = Game.player.max_hp()" % rid, 300)
    v.step(400)
    print("   arena floor, solid voxels 1.5 m under it: before the fight", floor_before, "after", arena_floor(), "(equal = the slams dug nothing)")
    body_summary(v, "after the boss")
    if os.environ.get("BODIES_TRACE"):
        print("   enemies below the world:", below_world(v))
        ag = v.tool("agents"); print("   agents tool:", json.dumps(ag)[:700])
        print("   bodies tool keys:", [k for k in v.tool("bodies")["bodies"][0]])
    print("   forcefield:", L(v, "print(Game.state.flags['ff_%s'])" % rid, 0))
    # into the pit
    L(v, "local G=Game; local r = G.floorgen.layout.rings['%s']; local p = r.pit; player.teleport(G.mx((p.x0 + p.x1) / 2), G.my(-1.1), G.mz((p.z0 + p.z1) / 2), { wait = true })" % rid, 60)
    print("   screen after the pit:", L(v, "print(Game.screen)", 0))
    L(v, "Game.run.descend(true)", 2)
    print("next floor built in", wait_floor(v), "s")
    v.step(200)
    body_summary(v, "next floor, +200 ticks")
    L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
    return True

# The game's persisted state (project.store: `.state/store.json`, with the events and prefab registries) is NOT part of a recording: a replay starts from whatever is in the project folder NOW.
# After a live run that is the state at its END (class, achievements, flags), which makes on_start and the awards of the replay differ from the live run's (ENGINE_FEEDBACK Phase 20):
# the bot saves the project's state folders before it starts and puts them back before the replay.
STATE_DIRS = [".state", ".events", ".prefabs"]
def snapshot_state():
    snap = os.path.join("/tmp", "descent_state_snapshot_%d" % os.getpid())
    if os.path.exists(snap): shutil.rmtree(snap)
    os.makedirs(snap)
    present = []
    for d in STATE_DIRS:
        src = os.path.join(ROOT, project, d)
        if os.path.isdir(src): shutil.copytree(src, os.path.join(snap, d)); present.append(d)
    return snap, present
def restore_state(snap, present):
    for d in STATE_DIRS:
        dst = os.path.join(ROOT, project, d)
        if os.path.isdir(dst): shutil.rmtree(dst)
        if d in present: shutil.copytree(os.path.join(snap, d), dst)

def main():
    snap, present = snapshot_state()
    print("state snapshot:", snap)
    maxagents = 0
    with Voxelith(["--project", project, "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", str(seed), "--record", log]) as v:
        v.step(400)
        if os.environ.get("GEN_PRELUDE"): L(v, os.environ["GEN_PRELUDE"], 1)       # (switches for a bisect: Game.nosigns = true; Game.nocover = true)
        L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2)
        L(v, "Game.player.pick_class('%s')" % cls, 2)
        print("floor 1 built in", wait_floor(v), "s")
        if "--first-floor" in sys.argv:
            first = int(sys.argv[sys.argv.index("--first-floor") + 1])
            v.step(200); L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
            L(v, "Game.run.begin_floor(%d)" % first, 2)
            print("floor %d built in" % first, wait_floor(v), "s")
        v.step(200)
        L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        for fl in range(1, floors + 1):
            L(v, "Game.run.cur().floor_ticks = 24000", 0)
            cur = int(L(v, "print(Game.run.cur().floor)", 0)[0])
            if (("--borough" in sys.argv and cur == int(sys.argv[sys.argv.index("--borough-floor") + 1] if "--borough-floor" in sys.argv else 1)) or ("--park" in sys.argv and cur == 3)) and borough_run(v): continue
            info = L(v, PATH, 0)[0].split("\t")
            print("FLOOR", info[0], "cells", info[1], "path", info[2])
            t_floor0 = int(L(v, "print(time.tick())", 0)[0])
            rooms = [x.split(":") for x in info[2].split(",")]
            for rid, theme in rooms:
                L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 150)
                if theme == "stairs_free": break
                t, kills, end = fight(v, rid, 2400)
                n = int(L(v, "print(Game.enemies.alive_count())", 0)[0]); maxagents = max(maxagents, n)
                # the crates of the room, in a sorted order (`pairs` over string keys differs between processes)
                ids = L(v, "local G=Game; local ids = {}; for id, c in pairs(G.traps.crates) do if c.cell == '%s' then ids[#ids+1] = id end end; table.sort(ids); print(table.concat(ids, ','))" % rid, 0)[0].split(",")
                for cid in [x for x in ids if x]:        # (the bot stands at the crate when it opens it and waits for the loot to be picked up: a crate opened from across the room paid nothing)
                    L(v, "local G=Game; local c = G.traps.crates['%s']; local off = { ['+z'] = { 0, 1.4 }, ['-z'] = { 0, -1.4 }, ['+x'] = { 1.4, 0 }, ['-x'] = { -1.4, 0 } }; local o = off[c.face] or { 0, 1.4 }; player.teleport(G.mx(c.cx + o[1]), G.my(c.ly + 0.1), G.mz(c.cz + o[2]), { wait = true }); G.traps.open_crate('%s')" % (cid, cid), 150)
                L(v, "local G=Game", 30)
                L(v, """local G=Game
for _, s in ipairs(G.items.inv.bag) do
  if s then local d = G.items.defs[s.id]
    if d and d.kind == 'weapon' and d.dmg and (d.dmg[1] + d.dmg[2]) > (G.player.weapon().dmg[1] + G.player.weapon().dmg[2]) then G.player.equip(s.id) end
    if d and d.kind == 'armor' and (d.def or 0) > ((G.items.defs[G.state.equip.armor or ''] or {}).def or -1) then G.player.equip(s.id) end
  end
end""", 5)
                print("  %-6s %-11s ticks %4d kills %2d  hp %s deaths %s level %s   %s" % (rid, theme, t, kills, end[1], end[2], end[3], counts(v))); sys.stdout.flush()
            ticks_ = int(L(v, "print(time.tick())", 0)[0]) - t_floor0
            print("TALLY", cur, ticks_, L(v, TALLY_LUA, 0)[0])        # (the game's own counters of this floor, for tools/balance.py)
            body_table(v, "floor %d end" % cur)
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
                body_table(v, "floor %d, +200 ticks" % (fl + 1))
                L(v, "if Game.screen == 'contracts' then Game.contracts.sign(nil) end", 2)
        errs = [l.strip() for l in v.stderr_tail(2000).splitlines() if "[error]" in l or "[warn" in l or "failed" in l]
        print("engine errors / warnings:", errs[-8:] if errs else "none")
        print("max agents seen at the end of a fight:", maxagents)
        v.screenshot("/tmp/descent_soak_last.png", hud=True, settle=60)       # (the render numbers are those of the last drawn frame)
        st = v.tool("status")
        print("hook:", json.dumps(st["world"].get("hook")))
        print("render:", json.dumps(st.get("render")))
        print("sim:", json.dumps({k: st["sim"].get(k) for k in ("bodies", "awake_bodies", "gravity_fields")}), "agents", L(v, "print(Game.enemies.alive_count(), #Game.floorgen.made_list)", 0)[0].replace("\t", " cells "))
        body_table(v, "the end")
        print("agent spawns refused by the engine (inside solid voxels):", L(v, "print(Game.enemies.refused or 0)", 0))
        # the corpse audit (V_animation of the artist): a creature whose model has a `die` clip must die by it (die_clip), one that ragdolls must not have one (a drawn-only scale-0.6 model cannot ragdoll:
        # the rebuilt goblins stood upright in their gore for 40 s); every enemy type is spawned once at the player and its model asked for the clip
        ca = L(v, """local G=Game; local E=G.enemies; local px, py, pz = player.pos(); local lx, ly, lz = G.to_local(px, py, pz); local kinds = {}
for k in pairs(E.types) do kinds[#kinds + 1] = k end; table.sort(kinds)
local bad, n = {}, 0
for _, k in ipairs(kinds) do local T = E.types[k]; local i = E.spawn(k, lx, ly, lz, { room = G.current_room })
  if i then n = n + 1; local ok = pcall(model.play, i.mdl, 'die', 1, false, 6)
    if T.ragdoll and ok then bad[#bad + 1] = k .. ': ragdoll = true but the model has a die clip' elseif T.die_clip and not ok then bad[#bad + 1] = k .. ': die_clip = true but no die clip' end
    pcall(agent.remove, i.id); E.list[i.id] = nil; E.by_model[i.mdl] = nil end end
print(n, #kinds, table.concat(bad, '; '))""", 5)
        print("corpse audit (types spawned, types, problems):", ca)
        print("state hash:", v.state_hash())
        if os.environ.get("DUMP_BODIES"):
            b = v.tool("bodies")
            open(os.environ["DUMP_BODIES"], "w").write(json.dumps(b))
            print("bodies:", b.get("awake"), len(b.get("bodies", [])))
        if os.environ.get("PROBE_OUT"): open(os.environ["PROBE_OUT"] + "_live.txt", "w").write(v.stderr_tail(1000000))
    if "--no-replay" not in sys.argv:
        restore_state(snap, present)
        _fresh_scratch()          # (a replay with the same --save file would LOAD the live run's world: the scratch must not exist)
        print("replaying the recording ...")
        r = subprocess.run([os.path.join(ROOT, "voxelith"), *state_dir_args(), "--replay", log, "--threads", "3", "--save", "/tmp/descent_scratch.vxs"], capture_output=True, text=True, cwd=ROOT)
        print([l for l in (r.stdout + r.stderr).splitlines() if "hash" in l.lower() or "replay" in l.lower()][-4:])
        if os.environ.get("PROBE_OUT"): open(os.environ["PROBE_OUT"] + "_replay.txt", "w").write(r.stdout + r.stderr)
main()
