#!/usr/bin/env python3
"""The recordings for the sound audit's mix report (voxel-audio step 5): a live session with Game.sfx.log(true) as its first call (SFXLOG / SAYLOG / SFXBAD lines in the live log), recorded with --record, then
replayed with --project and --audio-out for the WAV. usage: tools/audio_recordings.py floor1|floor3|floor4 [OUTDIR=~/share/audio/final] [SEED=4242]
Files: <name>.log (+ .log.clip/), <name>_live.txt (the whole stderr of the live session), <name>.wav (the audio-out render of the replay), <name>_replay.txt (the replay's own output: hashes, SFXLOG)."""
import os, sys, shutil, glob, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
os.chdir(ROOT)
from voxelith_client import Voxelith, state_dir_args
what = sys.argv[1]
out = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else "~/share/audio/final"); os.makedirs(out, exist_ok=True)
seed = sys.argv[3] if len(sys.argv) > 3 else "4242"
name = "descent_%s_seed%s" % (what, seed)
log = "/tmp/%s.log" % name
def L(v, code, ticks=1): return v.lua(code, ticks=ticks).get("output", [])
def clean():
    for p in glob.glob('/tmp/descent_scratch.vxs*') + glob.glob(log + "*"): (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
clean()
live = os.path.join(out, name + "_live.txt")
if os.path.exists(live): os.remove(live)
os.environ["VOXELITH_STDERR"] = live
def fight(v, rid, ticks):
    L(v, "local G=Game; local c=G.world.checkpoints['%s']; player.teleport(G.mx(c.x), G.my(0.1), G.mz(c.z), { wait = true })" % rid, 200)
    L(v, "Game.autoaim = true", 1)
    v.tool("input_action", name="attack", down=True, player=0)
    for i in range(ticks // 60):
        v.step(60)
        v.tool("input_action", name="ability", down=True, player=0)
    v.tool("input_action", name="attack", down=False, player=0); L(v, "Game.autoaim = false", 1)
def room_of(v, theme):
    r = L(v, "local P=Game.floorgen.layout; for _, id in ipairs(P.order) do if P.rooms[id].theme=='%s' then print(id); break end end" % theme, 0)
    return r[0] if r else None
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--seed", seed, "--record", log]) as v:
    v.step(300)
    L(v, "Game.sfx.log(true)", 1)                                         # the first call: a recording keeps it, so the replay logs too
    L(v, "Game.screen = 'run'; Game.run.start(0, true)", 2); L(v, "Game.player.pick_class('janitor')", 2); v.step(300)
    L(v, "Game.contracts.sign(nil)", 2); v.step(60)
    L(v, "Game.run.cur().floor_ticks = 10000000; Game.state.flags.god = true; Game.state.hp = 99999", 0)
    if what == "floor1":
        for theme in ("crypt", "hall", "furnace", "library", "depot"):
            rid = room_of(v, theme)
            if rid: v.step(120); fight(v, rid, 900)
        v.step(300)
    elif what == "floor3":
        L(v, "Game.run.begin_floor(3)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
        L(v, "Game.run.cur().floor_ticks = 10000000; Game.state.flags.god = true; Game.state.hp = 99999", 0)
        L(v, "Game.gen.overcity.fixed = 0.25", 2); v.step(900)                    # day
        for theme in ("village", "hall", "depot"):
            rid = room_of(v, theme)
            if rid: v.step(60); fight(v, rid, 900)
        L(v, "Game.gen.overcity.fixed = 0.75", 2); v.step(900)                    # night
        for theme in ("village", "hall", "depot"):
            rid = room_of(v, theme)
            if rid: v.step(60); fight(v, rid, 900)
        v.step(300)
    elif what == "floor4":
        L(v, "Game.run.begin_floor(4)", 2); v.step(500); L(v, "Game.contracts.sign(nil)", 2); v.step(60)
        L(v, "Game.run.cur().floor_ticks = 10000000; Game.state.flags.god = true; Game.state.hp = 99999", 0)
        v.step(900)
        L(v, "local G = Game; player.teleport(G.mx(112), G.my(0.2), G.mz(208), { wait = true })", 30)       # the Red car's deck at HUB S: the ride
        v.step(3600)
        for rid in ("c5_4", "c4_5"):
            fight(v, rid, 900)
        v.step(300)
    print("state hash:", v.state_hash())
clean_sc = [p for p in glob.glob('/tmp/descent_scratch.vxs*')]
for p in clean_sc: (shutil.rmtree if os.path.isdir(p) else os.remove)(p)
shutil.copyfile(log, os.path.join(out, name + ".log"))
dst_clip = os.path.join(out, name + ".log.clip")
if os.path.isdir(dst_clip): shutil.rmtree(dst_clip)
shutil.copytree(log + ".clip", dst_clip)
wav = os.path.join(out, name + ".wav")
r = subprocess.run([os.path.join(ROOT, "voxelith"), *state_dir_args(), "--replay", os.path.join(out, name + ".log"), "--project", "projects/dungeon_crawler", "--threads", "3", "--save", "/tmp/descent_scratch.vxs", "--audio-out", wav],
                   capture_output=True, text=True, cwd=ROOT)
open(os.path.join(out, name + "_replay.txt"), "w").write(r.stdout + r.stderr)
print([l for l in (r.stdout + r.stderr).splitlines() if "replayed" in l.lower() or "audio out" in l.lower()][-2:])
