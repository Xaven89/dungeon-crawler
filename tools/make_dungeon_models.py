#!/usr/bin/env python3
"""The cast of THE DESCENT: rigged creature models (.vxm, docs/ANIMATION.md) generated with the engine's own sample generator (tools/make_creatures.py: Creature, biped, quad, K).
Every creature faces +z and stands on y = 0; part names follow the roles the rig infers (pelvis, torso, head, thigh_l / shin_l / foot_l, upper_arm_l / forearm_l, front_leg_*, tail1), so the
agents walk them by rule; clips are what the rules do not do: `idle`, `attack` (its `hit` event is the frame that hurts), `hit` (a flinch), and per creature `spit`, `slam`, `summon`, `honk`.
usage: tools/make_dungeon_models.py [OUT_DIR]   (default projects/dungeon_crawler/models)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_creatures as mc
from make_creatures import Creature, K, biped, quad

ROOT = mc.ROOT

def flinch(c, dur=0.35, torso="torso", head="head"):
    keys = {torso: [K(0), K(0.08, (-18, 0, 4)), K(dur, (0, 0, 0))]}
    if head in [p[0] for p in c.parts]: keys[head] = [K(0), K(0.08, (-22, 0, 0)), K(dur, (0, 0, 0))]
    c.clip("hit", dur, False, keys)

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ gutter slime
def slime(name, light, core, mouth, scale_eyes=True):
    c = Creature(name, (16, 12, 16))
    c.ellipsoid((8, 5, 8), (7.5, 5.5, 7.5), light)
    c.ellipsoid((8, 6.5, 8), (5.5, 4, 5.5), core)
    for x in (4, 10):
        c.box((x, 5, 13), (x + 1, 7, 14), "white")
        c.box((x, 5, 14), (x + 1, 6, 14), "black")
    c.box((6, 3, 14), (9, 3, 14), mouth)
    # a floating bit of trash inside, because it lives in a gutter
    c.box((7, 6, 6), (8, 7, 7), "yellow"); c.box((9, 4, 8), (10, 4, 9), "red")
    hop = {"root": [K(0), K(0.15, (-10, 0, 0), (0, 3, 0)), K(0.3, (0, 0, 0), (0, 6, 0)), K(0.45, (8, 0, 0), (0, 2, 0)), K(0.55), K(1.0)]}
    c.clip("walk", 1.0, True, hop, [(0.55, "land")])
    c.clip("idle", 2.0, True, {"root": [K(0, pos=(0, 0, 0)), K(1.0, pos=(0, 1, 0)), K(2.0, pos=(0, 0, 0))]})
    c.clip("attack", 0.55, False, {"root": [K(0), K(0.18, (-30, 0, 0), (0, 2, -2)), K(0.32, (20, 0, 0), (0, 3, 6)), K(0.55)]}, [(0.32, "hit")])
    c.clip("hit", 0.3, False, {"root": [K(0), K(0.08, (15, 0, 0), (0, -2, -2)), K(0.3)]})
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ skeletal intern
def intern():
    c = Creature("intern", (18, 38, 10))
    bone = "grey1"
    torso, head = biped(c, bone, pelvisY=18, legLen=9, shinLen=7, torsoH=12, headR=3.5, armLen=7, foreLen=7, width=5, limbR=0.9)
    c.vox = {k: v for k, v in c.vox.items() if not (5 <= k[0] <= 12 and 21 <= k[1] <= 29 and 3 <= k[2] <= 5)}
    for y in range(21, 30, 2): c.box((5, y, 3), (12, y, 5), bone, "torso")
    c.box((8, 20, 5), (9, 30, 5), "grey3", "torso")
    c.box((8, 21, 3), (9, 29, 3), bone, "torso")
    # skull: sockets, grin, a yellow hard hat (safety first) and a red tie, a lanyard badge
    for x in (7, 10): c.box((x, 35, 8), (x, 36, 8), "black", "head")
    c.box((7, 32, 8), (10, 32, 8), "grey6", "head")
    c.ellipsoid((9, 38, 5), (4.6, 2.2, 4.6), "yellow", "head"); c.box((4, 37, 5), (14, 37, 9), "yellow", "head")
    c.box((8, 22, 6), (9, 28, 6), "red", "torso"); c.box((7, 27, 6), (10, 28, 6), "red", "torso")
    c.box((6, 21, 6), (6, 27, 6), "white", "torso")
    # a clipboard in the left hand
    cb = c.part("clipboard", "forearm_l", (4, 22, 5))
    c.box((2, 13, 6), (6, 20, 6), "brown", cb); c.box((3, 14, 7), (5, 19, 7), "white", cb)
    c.clip("idle", 2.4, True, {"torso": [K(0), K(1.2, (0, 0, 3)), K(2.4)], "head": [K(0), K(1.2, (0, -12, 0)), K(2.4)]})
    c.clip("attack", 0.7, False, {"upper_arm_r": [K(0), K(0.25, (-160, 0, -20)), K(0.4, (-30, 0, 0)), K(0.7)],
                                  "forearm_r": [K(0), K(0.25, (-60, 0, 0)), K(0.4, (-10, 0, 0)), K(0.7)],
                                  "torso": [K(0), K(0.25, (-8, 0, 0)), K(0.4, (12, 0, 0)), K(0.7)]}, [(0.4, "hit")])
    flinch(c)
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ goblin sales associate
def goblin_sales():
    c = Creature("goblin_sales", (18, 28, 12))
    skin = "deep_green"
    torso, head = biped(c, skin, pelvisY=12, legLen=6, shinLen=5, torsoH=8, headR=4.5, armLen=6, foreLen=6, width=5, limbR=1.1, paint_torso="dusty_blue", cloth="dark_slate")
    c.line((3.5, 24, 6), (1.5, 28, 6), 0.9, skin, "head"); c.line((14.5, 24, 6), (16.5, 28, 6), 0.9, skin, "head")
    c.box((8, 23, 10), (9, 24, 10), skin, "head")
    for x in (6, 11): c.box((x, 25, 9), (x, 25, 9), "red", "head")
    c.box((7, 21, 9), (10, 21, 9), "dark_red", "head"); c.box((8, 20, 9), (8, 20, 9), "white", "head")
    # a headset with a microphone, a name badge and a tie
    c.box((4, 26, 4), (13, 26, 7), "black", "head"); c.box((4, 23, 6), (4, 25, 7), "black", "head"); c.box((5, 22, 9), (6, 22, 9), "black", "head")
    c.box((6, 15, 7), (7, 16, 7), "white", "torso"); c.box((9, 12, 7), (9, 19, 7), "red", "torso")
    # the briefcase of the right hand
    bc = c.part("briefcase", "forearm_r", (14.5, 8, 6))
    c.box((13, 4, 3), (16, 9, 10), "brown", bc); c.box((13, 9, 5), (16, 9, 8), "gold", bc)
    c.clip("idle", 2.0, True, {"torso": [K(0, (3, 0, 0)), K(1.0, (6, 0, 0)), K(2.0, (3, 0, 0))], "head": [K(0, (0, 15, 0)), K(1.0, (0, -15, 0)), K(2.0, (0, 15, 0))]})
    c.clip("attack", 0.6, False, {"upper_arm_r": [K(0), K(0.2, (-170, 0, -25)), K(0.35, (-20, 0, 0)), K(0.6)],
                                  "forearm_r": [K(0), K(0.2, (-40, 0, 0)), K(0.35), K(0.6)],
                                  "torso": [K(0), K(0.2, (-12, -10, 0)), K(0.35, (18, 10, 0)), K(0.6)]}, [(0.35, "hit")])
    flinch(c)
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ cellar rat
def rat():
    c = Creature("rat", (9, 11, 20))
    head, tail, (cx, hy, hz) = quad(c, "slate", "light_stone", bodyY=4.5, bodyR=(2.6, 2.4, 5.5), legH=0, lowerH=2, legR=0.7, headR=2.1)
    for sgn in (-1, 1):   # round ears, red eyes, buck teeth
        c.ellipsoid((cx + sgn * 1.7, hy + 3.4, hz + 0.8), 1.0, "rose", "head")
        c.box((int(cx + sgn * 1.2 - (0.5 if sgn < 0 else 0)), int(hy) + 2, int(hz) + 3), (int(cx + sgn * 1.2 - (0.5 if sgn < 0 else 0)), int(hy) + 2, int(hz) + 3), "red", "head")
    c.box((int(cx) - 1, int(hy), int(hz) + 4), (int(cx), int(hy), int(hz) + 4), "white", "head")
    c.line((cx - 0.5, 5, 1.5), (cx - 0.5, 3, -4), 0.5, "rose", "tail1")
    c.clip("idle", 2.0, True, {"head": [K(0), K(0.7, (0, 25, 0)), K(1.4, (0, -25, 0)), K(2.0)]})
    c.clip("attack", 0.5, False, {"head": [K(0), K(0.15, (-25, 0, 0), (0, 1, -1)), K(0.25, (30, 0, 0), (0, 0, 3)), K(0.5)], "root": [K(0), K(0.15, (-8, 0, 0)), K(0.25, (10, 0, 0), (0, 0, 3)), K(0.5)]}, [(0.25, "hit")])
    c.clip("hit", 0.3, False, {"root": [K(0), K(0.08, (-14, 0, 0), (0, 1, -2)), K(0.3)]})
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ mushroom spitter
def spitter():
    c = Creature("spitter", (14, 22, 14))
    cx, cz = 7, 7
    for side, sgn in (("l", -1), ("r", 1)):
        hx = cx + sgn * 2
        leg = c.part("leg_" + side, "root", (hx, 5, cz))
        c.line((hx - 0.5, 5, cz - 0.5), (hx - 0.5, 1, cz - 0.5), 0.9, "cream", leg)
        foot = c.part("foot_" + side, leg, (hx, 1, cz))
        c.box((int(hx) - 1, 0, int(cz) - 1), (int(hx), 0, int(cz) + 2), "tan", foot)
    c.ellipsoid((cx, 8, cz), (3, 4, 3), "cream")                    # stalk
    head = c.part("head", "root", (cx, 11, cz))
    c.ellipsoid((cx, 14, cz), (6.5, 4.5, 6.5), "red", head)       # the cap
    for p in ((4, 17, 7), (10, 16, 5), (7, 18, 10), (9, 15, 10), (5, 15, 3)): c.box(p, (p[0] + 1, p[1], p[2] + 1), "white", head)
    c.box((6, 11, 9), (6, 11, 9), "black", "root"); c.box((8, 11, 9), (8, 11, 9), "black", "root"); c.box((6, 9, 10), (8, 9, 10), "dark_red", "root")
    c.clip("idle", 2.0, True, {"head": [K(0), K(1.0, (0, 0, 6)), K(2.0)]})
    c.clip("attack", 0.9, False, {"head": [K(0), K(0.3, (-25, 0, 0), (0, -1, 0)), K(0.45, (20, 0, 0), (0, 1, 2)), K(0.9)], "root": [K(0), K(0.3, (-8, 0, 0)), K(0.45, (6, 0, 0)), K(0.9)]}, [(0.45, "spit")])
    c.clip("hit", 0.3, False, {"head": [K(0), K(0.08, (-20, 0, 8)), K(0.3)]})
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ the foreman (mini boss)
def foreman():
    c = Creature("foreman", (30, 46, 32))
    skin = "green"
    torso, head = biped(c, skin, pelvisY=17, legLen=8, shinLen=8, torsoH=13, headR=6, armLen=9, foreLen=9, width=8, limbR=2.0, paint_torso="orange", cloth="deep_brown" if False else "brown")
    c.line((5, 38, 10), (1.5, 43, 10), 1.3, skin, "head"); c.line((25, 38, 10), (28.5, 43, 10), 1.3, skin, "head")
    c.box((14, 36, 17), (16, 38, 17), skin, "head")
    for x in (11, 18): c.box((x, 40, 16), (x + 1, 40, 16), "red", "head")
    c.box((12, 34, 16), (17, 34, 16), "dark_red", "head"); c.box((12, 35, 16), (12, 35, 16), "white", "head"); c.box((17, 35, 16), (17, 35, 16), "white", "head")
    c.ellipsoid((15, 44, 10), (6.6, 3, 6.6), "orange", "head"); c.box((8, 43, 10), (22, 43, 17), "orange", "head")      # hard hat
    c.box((9, 22, 12), (20, 24, 12), "yellow", "torso")                                                                 # a hi-vis stripe
    hm = c.part("hammer", "forearm_r", (21.5, 20, 10))
    c.line((21.5, 11, 10), (21.5, 11, 21), 1.2, "brown", hm); c.box((18, 8, 21), (25, 15, 27), "dark_slate", hm)
    c.clip("idle", 2.0, True, {"torso": [K(0, (3, 0, 0)), K(1.0, (6, 0, 0)), K(2.0, (3, 0, 0))]})
    c.clip("attack", 0.9, False, {"upper_arm_r": [K(0), K(0.3, (-175, 0, -10)), K(0.5, (-20, 0, 0)), K(0.9)], "torso": [K(0), K(0.3, (-14, 0, 0)), K(0.5, (20, 0, 0)), K(0.9)]}, [(0.5, "hit")])
    c.clip("slam", 1.2, False, {"upper_arm_r": [K(0), K(0.5, (-185, 0, 0)), K(0.7, (10, 0, 0)), K(1.2)], "upper_arm_l": [K(0), K(0.5, (-185, 0, 0)), K(0.7, (10, 0, 0)), K(1.2)],
                                "torso": [K(0), K(0.5, (-20, 0, 0)), K(0.7, (28, 0, 0)), K(1.2)]}, [(0.7, "slam")])
    flinch(c, 0.3)
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ the floor manager (boss)
def manager():
    # the engine silently replaces a rigged model that is larger than 64 voxels along an axis by its demo mannequin (ENGINE_FEEDBACK.md): the boss is 62 voxels (3.9 m) tall
    c = Creature("manager", (44, 64, 26))
    skin = "dusty_blue"
    cx, cz = 22, 13
    torso, head = biped(c, skin, pelvisY=24, legLen=11, shinLen=11, torsoH=19, headR=6.5, armLen=12, foreLen=12, width=11, limbR=2.8, paint_torso="white", cloth="dark_slate")
    fz = cz + 1                     # the front face of the torso
    # a suit: dark jacket panels either side, a long red tie, a lanyard and a badge, a pair of small glasses on a big face
    c.box((cx - 8, 26, fz - 2), (cx - 5, 42, fz), "dark_slate", "torso"); c.box((cx + 4, 26, fz - 2), (cx + 7, 42, fz), "dark_slate", "torso")
    c.box((cx - 1, 25, fz + 1), (cx, 41, fz + 1), "red", "torso"); c.box((cx - 2, 38, fz + 1), (cx + 1, 41, fz + 1), "red", "torso"); c.box((cx - 2, 25, fz + 2), (cx + 1, 29, fz + 2), "red", "torso")
    c.box((cx - 6, 31, fz + 1), (cx - 4, 36, fz + 1), "white", "torso"); c.box((cx - 5, 32, fz + 2), (cx - 5, 34, fz + 2), "black", "torso")
    hy = 24 + 19 + 1 + 6.5                     # centre of the head
    for x in (cx - 4, cx + 2): c.box((x, int(hy) + 1, cz + 6), (x + 2, int(hy) + 2, cz + 6), "black", "head"); c.box((x + 1, int(hy) + 1, cz + 7), (x + 1, int(hy) + 1, cz + 7), "yellow", "head")
    c.box((cx - 2, int(hy) + 1, cz + 6), (cx + 1, int(hy) + 1, cz + 6), "black", "head")
    c.box((cx - 1, int(hy) - 3, cz + 6), (cx, int(hy) - 1, cz + 7), "dusty_blue", "head")
    c.box((cx - 3, int(hy) - 5, cz + 6), (cx + 2, int(hy) - 5, cz + 6), "dark_red", "head")
    for x in (cx - 3, cx - 2, cx + 1, cx + 2): c.box((x, int(hy) - 4, cz + 6), (x, int(hy) - 4, cz + 6), "white", "head")
    c.box((cx - 3, int(hy) + 6, cz + 3), (cx + 2, int(hy) + 7, cz + 6), "dark_slate", "head")                 # a severe fringe
    # the clipboard in the left hand (the arm hangs at x = cx - 8)
    hx = cx - (5.5 + 2.5)
    cb = c.part("clipboard", "forearm_l", (hx, 24 + 19 - 1 - 12, cz))
    c.box((int(hx) - 4, 16, fz + 3), (int(hx) + 4, 31, fz + 3), "brown", cb); c.box((int(hx) - 3, 17, fz + 4), (int(hx) + 3, 30, fz + 4), "white", cb); c.box((int(hx) - 1, 30, fz + 4), (int(hx) + 1, 32, fz + 5), "silver", cb)
    for yy in range(19, 29, 3): c.box((int(hx) - 2, yy, fz + 5), (int(hx) + 2, yy, fz + 5), "black", cb)
    c.clip("idle", 2.6, True, {"torso": [K(0, (2, 0, 0)), K(1.3, (5, 0, 0)), K(2.6, (2, 0, 0))], "head": [K(0, (0, 8, 0)), K(1.3, (0, -8, 0)), K(2.6, (0, 8, 0))]})
    c.clip("attack", 1.0, False, {"upper_arm_r": [K(0), K(0.35, (-170, 0, -10)), K(0.55, (-10, 0, 0)), K(1.0)], "torso": [K(0), K(0.35, (-14, 0, 0)), K(0.55, (24, 0, 0)), K(1.0)]}, [(0.55, "hit")])
    c.clip("slam", 1.6, False, {"upper_arm_r": [K(0), K(0.7, (-180, 0, 0)), K(0.95, (15, 0, 0)), K(1.6)], "upper_arm_l": [K(0), K(0.7, (-180, 0, 0)), K(0.95, (15, 0, 0)), K(1.6)],
                                "torso": [K(0), K(0.7, (-22, 0, 0)), K(0.95, (34, 0, 0)), K(1.6)], "head": [K(0), K(0.7, (-20, 0, 0)), K(0.95, (20, 0, 0)), K(1.6)]}, [(0.95, "slam")])
    c.clip("summon", 2.0, False, {"upper_arm_r": [K(0), K(0.5, (-150, 0, -40)), K(1.5, (-150, 0, -40)), K(2.0)], "upper_arm_l": [K(0), K(0.5, (-150, 0, 40)), K(1.5, (-150, 0, 40)), K(2.0)],
                                  "head": [K(0), K(0.5, (-25, 0, 0)), K(1.5, (-25, 0, 0)), K(2.0)], "torso": [K(0), K(0.5, (-10, 0, 0)), K(1.5, (-10, 0, 0)), K(2.0)]}, [(0.9, "summon")])
    c.clip("throw", 1.0, False, {"upper_arm_l": [K(0), K(0.3, (-160, 0, 0)), K(0.5, (-20, 0, 0)), K(1.0)], "torso": [K(0), K(0.3, (-12, 0, 0)), K(0.5, (14, 0, 0)), K(1.0)]}, [(0.5, "throw")])
    c.clip("roar", 1.4, False, {"head": [K(0), K(0.3, (-30, 0, 0)), K(1.1, (-30, 0, 0)), K(1.4)], "torso": [K(0), K(0.3, (-14, 0, 0)), K(1.1, (-14, 0, 0)), K(1.4)],
                                "upper_arm_r": [K(0), K(0.3, (-40, 0, -50)), K(1.1, (-40, 0, -50)), K(1.4)], "upper_arm_l": [K(0), K(0.3, (-40, 0, 50)), K(1.1, (-40, 0, 50)), K(1.4)]}, [(0.4, "roar")])
    flinch(c, 0.35)
    return c

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------ Admiral Honk (the companion goose)
def honk():
    c = Creature("honk", (14, 24, 22))
    cx, cz = 7, 9
    c.ellipsoid((cx, 8, cz), (4, 3.6, 6), "white")                        # body
    c.ellipsoid((cx, 7, cz - 4.5), (2.4, 2, 2.4), "white")               # tail end
    for side, sgn in (("l", -1), ("r", 1)):
        hx = cx + sgn * 1.8
        leg = c.part("leg_" + side, "root", (hx, 5, cz))
        c.line((hx - 0.5, 5, cz - 0.5), (hx - 0.5, 1, cz - 0.5), 0.6, "orange", leg)
        foot = c.part("foot_" + side, leg, (hx, 1, cz))
        c.box((int(hx) - 1, 0, int(cz) - 1), (int(hx), 0, int(cz) + 2), "orange", foot)
        wing = c.part("wing_" + side, "root", (hx + sgn * 2.2, 10, cz))
        c.ellipsoid((cx + sgn * 4.6, 8.6, cz - 0.5), (1.1, 2.2, 4.0), "grey2", wing)
    neck = c.part("neck", "root", (cx, 10, cz + 4))
    c.line((cx - 0.5, 10, cz + 4), (cx - 0.5, 17, cz + 5.5), 1.2, "white", neck)
    head = c.part("head", neck, (cx, 17, cz + 5.5))
    c.ellipsoid((cx, 18.5, cz + 6.5), 2.2, "white", head)
    c.box((cx - 1, 18, cz + 8), (cx, 18, cz + 11), "orange", head); c.box((cx - 1, 17, cz + 8), (cx, 17, cz + 10), "orange", head)    # the beak
    for x in (cx - 2, cx + 1): c.box((x, 19, cz + 7), (x, 19, cz + 7), "black", head)
    # the admiral's hat: a black bicorne with a gold band and a tiny anchor badge
    c.box((cx - 3, 20, cz + 4), (cx + 2, 20, cz + 9), "black", head); c.box((cx - 2, 21, cz + 5), (cx + 1, 22, cz + 8), "black", head)
    c.box((cx - 3, 20, cz + 6), (cx + 2, 20, cz + 6), "gold", head); c.box((cx - 1, 22, cz + 7), (cx, 22, cz + 7), "gold", head)
    tail = c.part("tail1", "root", (cx, 8, cz - 5))
    c.line((cx - 0.5, 8, cz - 5), (cx - 0.5, 9, cz - 8), 0.9, "grey3", tail)
    c.clip("idle", 2.0, True, {"head": [K(0), K(0.5, (0, 25, 0)), K(1.2, (0, -25, 0)), K(2.0)], "neck": [K(0), K(1.0, (6, 0, 0)), K(2.0)]})
    c.clip("attack", 0.5, False, {"neck": [K(0), K(0.15, (-35, 0, 0)), K(0.25, (40, 0, 0)), K(0.5)], "head": [K(0), K(0.25, (20, 0, 0)), K(0.5)]}, [(0.25, "hit")])
    c.clip("honk", 0.8, False, {"neck": [K(0), K(0.2, (-30, 0, 0)), K(0.6, (-30, 0, 0)), K(0.8)], "wing_l": [K(0), K(0.2, (0, 0, 40)), K(0.6, (0, 0, 40)), K(0.8)],
                                "wing_r": [K(0), K(0.2, (0, 0, -40)), K(0.6, (0, 0, -40)), K(0.8)]}, [(0.2, "honk")])
    return c

def all_models():
    return [slime("slime", "light_green", "green", "dark_green"), slime("slime_toxic", "lime", "deep_green", "black"), intern(), goblin_sales(), rat(), spitter(), foreman(), manager(), honk()]

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "projects", "dungeon_crawler", "models")
    os.makedirs(out, exist_ok=True)
    for c in all_models():
        n = c.write(os.path.join(out, c.name + ".vxm"))
        print("%-12s %2dx%2dx%2d  %5d voxels  %2d parts  clips: %s" % (c.name, *c.size, n, len(c.parts), ", ".join(k[0] for k in c.clips)))

if __name__ == "__main__":
    main()
