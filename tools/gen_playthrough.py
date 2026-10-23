#!/usr/bin/env python3
"""A bot that plays a SEEDED run through the MCP server: starts a generated run (skipping the Orientation), and on every floor visits every room (teleports, because walking is checked
apart by tools/gen_validate.py), fights with the game's own functions (Game.autoaim, the ability, heal items), opens the crates, equips better gear, kills the boss, takes the stairs.
It records the session (--record) and replays it at the end to check the hash.
usage: tools/gen_playthrough.py SEED [class] [floors] [--no-replay]"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
args = [a for a in sys.argv[1:] if not a.startswith("--")]
seed = int(args[0]) if args else 4242
cls = args[1] if len(args) > 1 else "janitor"
floors = int(args[2]) if len(args) > 2 else 2
log = "/tmp/descent_gen_%d.log" % seed
if os.path.exists(log): os.remove(log)

def L(v, code, ticks=1):
    r = v.lua(code, ticks=ticks)
    return r.get("output", [])

def wait_floor(v, limit=180):
    t = time.time()
    while time.time() - t < limit:
        o = L(v, "print(Game.screen, Game.floorgen.job and Game.floorgen.job.i or 'done')", 20)
        if o and o[0].endswith("done"): return round(time.time() - t, 1)
    return None

def fight(v, room, max_ticks=2400, step=60):
    L(v, "Game.autoaim = true; Game.state.mp = Game.player.max_mp()", 1)
    v.tool("input_action", name="attack", down=True, player=0)
    t = 0
    start = L(v, "local G=Game; print(G.state.kills, math.floor(G.state.hp))", 0)[0].split("\t")
    while t < max_ticks:
        out = L(v, """
local G = Game
if G.player.dead then return end
if G.state.hp < G.player.max_hp() * 0.45 then G.player.quick('heal') end
print(G.enemies.alive_in('%s'), math.floor(G.state.hp), G.state.deaths)""" % room, step)
        v.tool("input_action", name="ability", down=True, player=0)
        t += step
        if out and out[0].split("\t")[0] == "0": break
    v.tool("input_action", name="attack", down=False, player=0)
    L(v, "Game.autoaim = false", 0)
    end = L(v, "local G=Game; print(G.state.kills, math.floor(G.state.hp), G.state.deaths, G.state.level)", 0)[0].split("\t")
    return t, int(end[0]) - int(start[0]), end

def main():
    report = []
    with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--record", log]) as v:
        v.step(400)
        L(v, "Game.screen = 'run'; Game.run.start(%d, true)" % seed, 2)
        L(v, "Game.player.pick_class('%s')" % cls, 2)
        print("floor 1 built in", wait_floor(v), "s")
        v.step(60)
        for fl in range(1, floors + 1):
            info = L(v, """local p = Game.floorgen.layout
local ids = {}
for _, id in ipairs(p.order) do ids[#ids + 1] = id .. ':' .. p.rooms[id].role .. ':' .. p.rooms[id].theme end
print(p.floor, p.n, table.concat(ids, ','))""", 0)[0].split("\t")
            print("FLOOR", info[0], "rooms", info[1], info[2])
            rooms = [x.split(":") for x in info[2].split(",")]
            order = [r for r in rooms if r[1] == "room"] + [r for r in rooms if r[1] == "boss"] + [r for r in rooms if r[1] == "exit"]
            for rid, role, theme in order:
                L(v, "local G=Game; local r=G.floorgen.layout.rooms['%s']; player.teleport(G.mx(r.x+r.w/2), G.my(0.1), G.mz(r.z+r.d/2))" % rid, 150)
                if role == "exit": break
                if role == "boss": v.step(500)
                t, kills, end = fight(v, rid, 3600 if role == "boss" else 2400)
                if role == "boss":
                    v.step(300)
                # the crates of the room
                L(v, "local G=Game; local ix=G.floorgen.layout.rooms['%s'].index; for id, c in pairs(G.traps.crates) do if id:match('^f%%dc'..ix..'_') or id:match('^f%%dboss$') then G.traps.open_crate(id) end end" % rid, 60)
                L(v, """local G=Game; local best
for _, s in ipairs(G.items.inv.bag) do
  if s then local d = G.items.defs[s.id]
    if d and d.kind == 'weapon' and d.dmg and (d.dmg[1] + d.dmg[2]) > (G.player.weapon().dmg[1] + G.player.weapon().dmg[2]) then G.player.equip(s.id) end
    if d and d.kind == 'armor' and (d.def or 0) > ((G.items.defs[G.state.equip.armor or ''] or {}).def or -1) then G.player.equip(s.id) end
  end
end""", 5)
                line = "  %-6s %-6s %-9s ticks %4d kills %2d  hp %s deaths %s level %s" % (rid, role, theme, t, kills, end[1], end[2], end[3])
                print(line); sys.stdout.flush(); report.append(line)
            print("  descending ...")
            if fl < floors:
                L(v, "Game.run.descend()", 2)
                print("floor %d built in" % (fl + 1), wait_floor(v), "s")
                v.step(60)
        errs = [l.strip() for l in v.stderr_tail(600).splitlines() if "[error]" in l or "[warn" in l]
        print("engine errors / warnings:", errs[-6:] if errs else "none")
        print("state hash:", v.state_hash())
    if "--no-replay" not in sys.argv:
        print("replaying the recording ...")
        r = subprocess.run([os.path.join(ROOT, "voxelith"), "--replay", log, "--threads", "3"], capture_output=True, text=True, cwd=ROOT)
        print([l for l in (r.stdout + r.stderr).splitlines() if "hash" in l.lower() or "replay" in l.lower()][-4:])
main()
