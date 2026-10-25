#!/usr/bin/env python3
"""A bot that plays THE DESCENT through the MCP server (no display, no keyboard): picks a class, walks (teleports) from room to room, fights with the game's own functions (Game.player.attack with
`Game.autoaim`, which ignores where the player looks: the MCP cannot turn the view during a fight), heals, opens crates, pulls the levers, fires the boss, buys something and finishes the floor.
It records the session (`--record`), takes a free-camera picture of every room into ~/share/tour/ and replays the recording at the end to check the hash.
usage: tools/playthrough.py [class] [--no-replay]"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("VOXELITH", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "voxelith"))
from voxelith_client import Voxelith, state_dir_args

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SHARE = os.path.expanduser("~/share/tour")
os.makedirs(SHARE, exist_ok=True)
cls = next((a for a in sys.argv[1:] if not a.startswith("--")), "janitor")
log = "/tmp/descent_playthrough.log"
for f in (log,):
    if os.path.exists(f): os.remove(f)

OX, OY, OZ = 67.0, 8.0, 53.0       # local (0,0,0) in world metres (game/core.lua)

def L(v, code, ticks=1):
    r = v.lua(code, ticks=ticks)
    return r.get("output", []), r

def room_shot(v, name, eye, target, fov=80):
    v.screenshot(os.path.join(SHARE, name + ".png"), eye=[OX + eye[0], OY + eye[1], OZ + eye[2]], target=[OX + target[0], OY + target[1], OZ + target[2]], fov=fov)

def fight(v, room, max_ticks=2400, step=60):
    """Attack with auto-aim, heal when low, until nobody of that room is alive or the time is up. Returns a summary line."""
    L(v, "Game.autoaim = true; Game.state.mp = 100", 1)
    v.tool("input_action", name="attack", down=True, player=0)          # held: the game swings whenever its cooldown allows
    t = 0
    while t < max_ticks:
        out, _ = L(v, """
local G = Game
if G.player.dead then return end
if G.state.hp < G.player.max_hp() * 0.45 then G.player.quick('heal') end
print(G.enemies.alive_in('%s'), G.state.hp, G.state.deaths)""" % room, ticks=step)
        v.tool("input_action", name="ability", down=True, player=0)      # the real path: a logged input action (docs/INPUT.md "Custom actions")
        t += step
        if out and out[0].split("\t")[0] == "0": break
    out, _ = L(v, "local G = Game; return nil; ", 0)
    L(v, "Game.autoaim = false", 0)
    o, _ = L(v, "local G=Game; print(G.state.level, G.state.kills, G.state.deaths, math.floor(G.state.hp), G.state.gold)", 0)
    return "%-10s %s  (ticks %d)  level/kills/deaths/hp/gold %s" % (room, "cleared" if t < max_ticks else "NOT cleared", t, o[0] if o else "?")

def main():
    run_all()

def run_all():
    with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--record", log]) as v:
        print("status:", v.status()["project"])
        v.step(30)
        print(L(v, "return Game.player.pick_class('%s')" % cls)[0])
        v.step(350)
        room_shot(v, "01_lobby", (3, 3, 20), (18, 2, 6))
        report = []
        route = [
            ("hall", (32, 0.1, 11), ((36, 3, 3), (60, 1, 12))),
            ("boiler", (79, 0.1, 12), ((78, 5, 24), (100, 1, 8))),
            ("conveyor", (118, 0.6, 24), ((115, 4, 21), (118, 0, 50))),
            ("gutter", (118, 0.1, 73), ((119, 5, 71), (100, 0, 85))),
            ("ballroom", (40, 0.1, 82), ((40, 4, 68), (60, 3, 88))),
            ("grotto", (30, 0.1, 82), ((33, 3, 82), (20, 2, 72))),
        ]
        for room, pos, shot in route:
            L(v, "local G=Game; player.teleport(G.mx(%f), G.my(%f), G.mz(%f))" % pos, 200)
            room_shot(v, "02_" + room, *shot[:2]) if False else room_shot(v, "02_" + room, shot[0], shot[1])
            report.append(fight(v, room))
            print(report[-1])
            sys.stdout.flush()
        # the grotto's Foreman is in its own corner of the same room: go there
        L(v, "local G=Game; player.teleport(G.mx(20), G.my(0.1), G.mz(100))", 200)
        report.append(fight(v, "grotto", 1800)); print(report[-1])
        # the boss
        L(v, "local G=Game; player.teleport(G.mx(30), G.my(0.1), G.mz(121))", 300)
        room_shot(v, "03_arena", (30, 5, 118), (30, 2, 140))
        out, _ = L(v, "local G=Game; print(G.boss.started, G.boss.active)", 0)
        print("boss intro:", out)
        L(v, "Game.autoaim = true", 0)
        v.tool("input_action", name="attack", down=True, player=0)
        ok = False
        for i in range(80):
            o, _ = L(v, """local G=Game
if not G.player.dead then
  if G.state.hp < G.player.max_hp() * 0.5 then G.player.quick('heal') end
  -- (the moat and the boss: keep the player on the platform)
  local px,py,pz = player.pos(); local lx,ly,lz = G.to_local(px,py,pz)
  if G.dist2(lx,lz,30,132) > 11 then player.teleport(G.mx(30), G.my(0.1), G.mz(128)) end
end
print(G.state.flags.boss_dead and 1 or 0, G.boss.inst and math.floor(G.boss.inst.hp) or -1, G.boss.phase, math.floor(G.state.hp), G.state.deaths)""", ticks=60)
            if o and o[0].split("\t")[0] == "1": ok = True; break
            if i % 10 == 0: print("  boss:", o)
        print("boss dead:", ok)
        v.step(400)
        room_shot(v, "04_arena_after", (30, 6, 118), (30, 2, 140))
        # the stairwell: buy something, touch the crystal, go down
        L(v, "local G=Game; player.teleport(G.mx(60), G.my(0.1), G.mz(130))", 200)
        room_shot(v, "05_stairwell", (56, 3, 138), (64, 1.5, 128))
        print(L(v, "local G=Game; G.state.gold = G.state.gold + 100; print(G.shop.buy(1), G.state.gold); G.save_now(); G.finish_floor(); print(G.screen, G.state.ach_count)", 5)[0])
        o, _ = L(v, """local G=Game; local names = {}; for _, id in ipairs(G.announcer.order) do if G.state.ach[id] then names[#names+1] = id end end; print(table.concat(names, ' '))""", 0)
        print("achievements:", o)
        errs = [l.strip() for l in v.stderr_tail(400).splitlines() if "[error]" in l or "[warn" in l]
        print("engine errors / warnings in the log tail:", errs[-8:] if errs else "none")
        print("state hash:", v.state_hash())
        print("\n".join(report))
    if "--no-replay" not in sys.argv:
        print("replaying the recording ...")
        r = subprocess.run([os.path.join(ROOT, "voxelith"), *state_dir_args(), "--replay", log, "--threads", "3", "--audio-out", os.path.join(SHARE, "playthrough_audio.wav")], capture_output=True, text=True, cwd=ROOT)
        print([l for l in (r.stdout + r.stderr).splitlines() if "hash" in l.lower() or "replay" in l.lower()][-6:])

main()
