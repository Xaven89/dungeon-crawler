#!/usr/bin/env python3
"""Builds the starter prefab kit (assets/prefabs/*.vxm) with the model workspace's MCP tools (docs/MODEL_WORKSPACE.md): every prefab is a short list of
`model_edit` operations, so the kit is data made by the same tools an agent uses, not code in the engine.
usage: tools/make_prefabs.py [--view DIR] [--only NAME ...]   (--view writes a PNG per prefab into DIR to look at them; --only rebuilds just those, and copies nothing)
Needs the built engine (build/release/voxelith, a GPU)."""
import json, os, shutil, sys, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from voxelith_client import Voxelith

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "prefabs")

def box(a, b, m, mode=None):
    o = {"op": "box", "min": a, "max": b, "material": m}
    if mode: o["mode"] = mode
    return o
def cyl(base, r, h, m, axis="y"): return {"op": "cylinder", "base": base, "axis": axis, "radius": r, "height": h, "material": m}
def sph(c, r, m): return {"op": "sphere", "centre": c, "radius": r, "material": m}

def gable(x0, x1, z0, z1, y0, height, m, along="x"):
    """A pitched roof over the box x0..x1, z0..z1 starting at y0: a shell two voxels thick (the two slopes) and the two triangular gable ends."""
    ops = []
    if along == "x":  # the ridge runs along x
        half = (z1 - z0 + 1) // 2
        for i in range(min(height, half)):
            ops.append(box([x0, y0 + i, z0 + i], [x1, y0 + i, min(z0 + i + 1, z1 - i)], m))
            ops.append(box([x0, y0 + i, max(z1 - i - 1, z0 + i)], [x1, y0 + i, z1 - i], m))
            ops.append(box([x0, y0 + i, z0 + i], [x0 + 1, y0 + i, z1 - i], m))   # the gable ends
            ops.append(box([x1 - 1, y0 + i, z0 + i], [x1, y0 + i, z1 - i], m))
    else:
        half = (x1 - x0 + 1) // 2
        for i in range(min(height, half)):
            ops.append(box([x0 + i, y0 + i, z0], [min(x0 + i + 1, x1 - i), y0 + i, z1], m))
            ops.append(box([max(x1 - i - 1, x0 + i), y0 + i, z0], [x1 - i, y0 + i, z1], m))
            ops.append(box([x0 + i, y0 + i, z0], [x1 - i, y0 + i, z0 + 1], m))
            ops.append(box([x0 + i, y0 + i, z1 - 1], [x1 - i, y0 + i, z1], m))
    return ops

KIT = {}

KIT["torch"] = ([7, 22, 7], [
    cyl([3.5, 0, 3.5], 1.0, 15, "wood"), cyl([3.5, 13, 3.5], 1.9, 2, "metal"), sph([3.5, 17.5, 3.5], 2.3, "neon")])

KIT["barrel"] = ([16, 20, 16], [
    cyl([8, 1, 8], 7.0, 17, "wood"), cyl([8, 3, 8], 7.6, 1, "metal"), cyl([8, 14, 8], 7.6, 1, "metal"),
    cyl([8, 0, 8], 6.0, 1, "wood"), cyl([8, 18, 8], 5.0, 1, "wood")])

for n, w in (("fence_4", 64), ("fence_8", 128)):
    posts = [0, w // 2 - 1, w - 3] if w <= 64 else [0] + [i * 32 - 1 for i in range(1, w // 32)] + [w - 3]
    ops = [box([0, 6, 0], [w - 1, 8, 2], "wood"), box([0, 14, 0], [w - 1, 16, 2], "wood")]
    for x in posts:
        ops.append(box([max(0, x), 0, 0], [max(0, x) + 2, 20, 2], "wood"))
    KIT[n] = ([w, 22, 3], ops)

KIT["bridge_segment"] = ([32, 18, 48], [
    box([0, 4, 0], [31, 5, 47], "wood"),
    box([0, 2, 0], [2, 3, 47], "wood"), box([29, 2, 0], [31, 3, 47], "wood"),
    *[box([x, 6, z], [x + 1, 15, z + 1], "wood") for x in (0, 30) for z in (0, 12, 24, 36, 46)],
    box([0, 14, 0], [1, 15, 47], "wood"), box([30, 14, 0], [31, 15, 47], "wood")])

house = [box([0, 0, 0], [95, 1, 95], "concrete"),
         box([0, 2, 0], [95, 41, 95], "brick"), box([4, 2, 4], [91, 41, 91], "air"),   # walls and the room
         box([36, 2, 0], [59, 41, 3], "air"),                                          # the door opening (front, z = 0): 40 voxels, 2.5 m
         box([8, 22, 0], [20, 35, 3], "glass"), box([75, 22, 0], [87, 35, 3], "glass"), # front windows
         box([0, 22, 40], [3, 35, 54], "glass"), box([92, 22, 40], [95, 35, 54], "glass"),
         box([40, 22, 92], [56, 35, 95], "glass"),
         box([4, 42, 4], [91, 42, 91], "wood")]                                         # the ceiling
house += gable(0, 95, 0, 95, 42, 48, "wood", "x")
KIT["house_small"] = ([96, 92, 96], house)

KIT["well"] = ([30, 34, 30], [
    cyl([15, 0, 15], 13.0, 11, "stone"), cyl([15, 2, 15], 9.5, 10, "air"), cyl([15, 2, 15], 9.5, 6, "water"),
    box([2, 11, 14], [4, 28, 16], "wood"), box([25, 11, 14], [27, 28, 16], "wood"), box([2, 27, 13], [27, 29, 17], "wood"),
    box([14, 21, 14], [15, 26, 15], "metal")])

shed = [box([0, 0, 0], [47, 1, 39], "wood"), box([0, 2, 0], [47, 29, 39], "wood"), box([2, 2, 2], [45, 29, 37], "air"),
        box([14, 2, 0], [33, 35, 2], "air"), box([6, 14, 0], [11, 21, 2], "glass")]
shed += gable(0, 47, 0, 39, 30, 20, "wood", "x")
KIT["shed"] = ([48, 52, 40], shed)

KIT["stone_wall"] = ([64, 28, 8], [
    box([0, 0, 0], [63, 21, 7], "stone"),
    *[box([x, 22, 0], [x + 5, 27, 7], "stone") for x in range(0, 64, 12)]])

KIT["pillar"] = ([12, 44, 12], [
    box([0, 0, 0], [11, 3, 11], "concrete"), cyl([6, 4, 6], 4.2, 36, "concrete"), box([0, 40, 0], [11, 43, 11], "concrete")])

KIT["signpost"] = ([28, 34, 4], [
    box([12, 0, 1], [15, 26, 2], "wood"), box([1, 18, 0], [26, 28, 3], "wood"),
    box([4, 25, 3], [21, 25, 3], "brick"), box([4, 22, 3], [17, 22, 3], "brick"), box([4, 20, 3], [21, 20, 3], "brick")])  # three lines of lettering

KIT["sign_board"] = ([66, 30, 5], [  # a board 66 x 18 voxels on a post: the manifest writes its `text` on the front (+z) face, docs/TEXT.md
    box([30, 0, 1], [35, 12, 3], "wood"),
    box([0, 12, 0], [65, 29, 4], "wood"),
    box([0, 12, 0], [65, 12, 4], "brick"), box([0, 29, 0], [65, 29, 4], "brick"), box([0, 12, 0], [0, 29, 4], "brick"), box([65, 12, 0], [65, 29, 4], "brick")])

KIT["campfire"] = ([24, 8, 24], [
    cyl([12, 0, 12], 10.5, 3, "stone"), cyl([12, 0, 12], 7.0, 3, "air"), cyl([12, 0, 12], 6.5, 1, "char"),
    {"op": "line", "from": [7, 2, 9], "to": [17, 4, 15], "radius": 1.2, "material": "wood"},
    {"op": "line", "from": [7, 2, 15], "to": [17, 4, 9], "radius": 1.2, "material": "wood"}])

arch = [box([0, 0, 0], [55, 55, 7], "stone"), box([12, 0, 0], [43, 30, 7], "air"), cyl([28, 30, 0], 16.0, 8, "air", "z")]  # a 2 m wide, 2.9 m high opening: the player (28 voxels) walks through
KIT["stone_arch"] = ([56, 56, 8], arch)

KIT["market_stall"] = ([64, 44, 40], [
    box([0, 0, 0], [3, 30, 3], "wood"), box([60, 0, 0], [63, 30, 3], "wood"), box([0, 0, 36], [3, 38, 39], "wood"), box([60, 0, 36], [63, 38, 39], "wood"),
    box([0, 14, 4], [63, 16, 20], "wood"),                                  # the counter
    *[box([0, 30 + (z // 3), z], [63, 31 + (z // 3), z + 2], "brick") for z in range(0, 38, 3)]])  # a slanted awning

# straight stairs rising along +z (8 steps of 6 x 2 voxels, 2 m wide): a top and a bottom end that snap to the next flight
KIT["stairs"] = ([33, 16, 48], [box([0, 0, 6 * i], [32, 2 * i + 1, 6 * i + 5], "stone") for i in range(8)])  # (33 wide: the middle cell of a face is the same cell in every turn)

KIT["ladder"] = ([12, 48, 3], [
    box([0, 0, 0], [1, 47, 2], "wood"), box([10, 0, 0], [11, 47, 2], "wood"),
    *[box([2, y, 0], [9, y + 1, 1], "wood") for y in range(3, 47, 6)]])

KIT["window_wall"] = ([64, 40, 7], [
    box([0, 0, 0], [63, 31, 6], "brick"), box([0, 32, 0], [63, 39, 6], "stone"),
    box([20, 10, 0], [43, 25, 6], "air"), box([20, 10, 2], [43, 25, 4], "glass"),                           # the opening and its pane
    box([18, 8, 0], [45, 9, 6], "stone"), box([18, 26, 0], [45, 27, 6], "stone"), box([18, 8, 0], [19, 27, 6], "stone"), box([44, 8, 0], [45, 27, 6], "stone")])  # the frame

KIT["wall_corner"] = ([40, 28, 40], [
    box([0, 0, 0], [39, 21, 7], "stone"), box([0, 0, 0], [7, 21, 39], "stone"),
    *[box([x, 22, 0], [x + 5, 27, 7], "stone") for x in range(0, 40, 12)], *[box([0, 22, z], [7, 27, z + 5], "stone") for z in range(12, 40, 12)]])

KIT["path_tile"] = ([33, 2, 33], [
    box([0, 0, 0], [32, 1, 32], "stone"),
    *[box([x, 1, z], [x + 6, 1, z + 6], "concrete") for x in range(1, 31, 10) for z in range(1, 31, 10)]])

KIT["table"] = ([40, 22, 24], [
    box([0, 18, 0], [39, 21, 23], "wood"),
    *[box([x, 0, z], [x + 3, 17, z + 3], "wood") for x in (1, 35) for z in (1, 19)]])

KIT["chair"] = ([16, 32, 16], [
    box([1, 10, 1], [14, 12, 14], "wood"),
    *[box([x, 0, z], [x + 1, 9, z + 1], "wood") for x in (1, 13) for z in (1, 13)],
    box([1, 13, 13], [14, 30, 14], "wood")])

tent = []
for i in range(20):  # a canvas roof down to the ground on both sides, ridge along z
    tent.append(box([i, i, 0], [i + 1, i, 47], "sand")); tent.append(box([39 - i - 1, i, 0], [39 - i, i, 47], "sand"))
tent += [box([19, 20, 0], [20, 20, 47], "sand"), box([19, 0, 0], [20, 19, 1], "wood"), box([19, 0, 46], [20, 19, 47], "wood"),  # the front and back poles
         box([8, 0, 8], [31, 0, 39], "wood", "fill_air")]
KIT["tent"] = ([40, 22, 48], tent)

# ---- more nature and ruins for the world generator's feature rules (round 28): what the biomes lacked ---------------------------------------------------------------------------------
def ln(a, b, r, m, paint=None):
    o = {"op": "line", "from": a, "to": b, "radius": r, "material": m}
    if paint: o["paint"] = paint
    return o
def sphr(c, radii, m, mode=None, paint=None):
    o = {"op": "sphere", "centre": c, "radii": radii, "material": m}
    if mode: o["mode"] = mode
    if paint: o["paint"] = paint
    return o
def cylp(base, r, h, m, paint, axis="y"):
    o = cyl(base, r, h, m, axis); o["paint"] = paint
    return o

KIT["dead_tree"] = ([40, 80, 40], [  # a bare trunk with a few crooked limbs
    cyl([20, 0, 20], 3.4, 46, "wood"), cyl([20, 44, 20], 2.4, 18, "wood"),
    ln([20, 38, 20], [7, 60, 25], 1.6, "wood"), ln([7, 60, 25], [3, 72, 21], 1.0, "wood"), ln([12, 52, 23], [10, 66, 34], 0.8, "wood"),
    ln([20, 50, 20], [33, 68, 14], 1.4, "wood"), ln([33, 68, 14], [37, 77, 20], 0.8, "wood"), ln([27, 60, 17], [30, 70, 6], 0.7, "wood"),
    ln([20, 58, 20], [23, 78, 29], 1.1, "wood"), ln([22, 70, 25], [15, 76, 31], 0.6, "wood"),
    ln([20, 2, 20], [6, 0, 14], 1.6, "wood"), ln([20, 2, 20], [34, 0, 27], 1.6, "wood"), ln([20, 2, 20], [23, 0, 36], 1.4, "wood")])  # roots

willow = [cyl([28, 0, 28], 4.2, 50, "wood"), cyl([28, 40, 28], 3.0, 16, "wood"), sph([28, 62, 28], 22, "leaves"), sph([28, 60, 28], 15, "wood"),
          ln([28, 48, 28], [14, 62, 20], 1.5, "wood"), ln([28, 48, 28], [40, 64, 36], 1.5, "wood"), ln([28, 52, 28], [26, 66, 12], 1.3, "wood")]
import math as _m
for _k in range(14):  # hanging strands around the rim of the crown, down to about 2 m over the ground
    _a = _k * 2 * _m.pi / 14
    _x, _z = 28 + 21 * _m.cos(_a), 28 + 21 * _m.sin(_a)
    willow.append(cyl([round(_x), 30 + (_k * 7) % 9, round(_z)], 1.3, 32, "leaves"))
KIT["willow"] = ([56, 86, 56], willow)

KIT["fallen_log"] = ([64, 16, 18], [cyl([0, 7, 9], 6.5, 64, "wood", "x"), cyl([0, 7, 9], 4.6, 1, "wood", "x"), cyl([63, 7, 9], 4.6, 1, "wood", "x"),
                                    ln([44, 10, 9], [50, 15, 16], 1.5, "wood"), box([0, 11, 4], [63, 13, 14], "leaves", "paint")])  # a stub branch, moss along the top

KIT["stump"] = ([16, 12, 16], [cyl([8, 0, 8], 6.5, 9, "wood"), cyl([8, 8, 8], 5.0, 1, "wood"),
                               ln([8, 1, 8], [1, 0, 5], 1.6, "wood"), ln([8, 1, 8], [14, 0, 10], 1.6, "wood"), ln([8, 1, 8], [8, 0, 15], 1.4, "wood")])

KIT["mushroom_big"] = ([24, 32, 24], [sphr([12, 24, 12], [11.5, 8, 11.5], "flower-red"), box([0, 0, 0], [23, 20, 23], "air"), cyl([12, 0, 12], 4.0, 23, "sand"),
                                      *[sph([x, y, z], 1.5, "flower-white") for x, y, z in ((6, 29, 9), (15, 31, 15), (18, 27, 6), (8, 27, 18), (12, 31, 5))]])

KIT["berry_bush"] = ([20, 18, 20], [sphr([10, 9.5, 10], [9.5, 8, 9.5], "leaves"), box([0, 0, 0], [19, 1, 19], "air"),
                                    {"op": "set", "voxels": [[x, y, z, "flower-red"] for x, y, z in ((3, 10, 8), (6, 14, 5), (10, 16, 10), (14, 13, 4), (16, 9, 12), (12, 11, 17), (5, 8, 15), (9, 15, 15), (15, 15, 15), (2, 11, 12))]}])

KIT["cactus"] = ([16, 48, 16], [cyl([8, 0, 8], 2.8, 46, "leaves"), cyl([8, 46, 8], 2.0, 2, "leaves"),
                               cyl([8, 22, 8], 2.1, 6, "leaves", "x"), cyl([13, 22, 8], 2.1, 15, "leaves"), cyl([2, 30, 8], 2.1, 7, "leaves", "x"), cyl([3, 30, 8], 2.1, 12, "leaves")])
KIT["cactus_small"] = ([12, 12, 12], [sphr([6, 5.5, 6], [5.5, 6, 5.5], "leaves"), sph([6, 11, 6], 1.5, "flower-yellow")])

KIT["rock_spire"] = ([32, 72, 32], [cylp([16, 0, 16], 15, 10, "stone", "terracotta"), cylp([16, 10, 16], 12, 14, "stone", "clay"), cylp([16, 24, 16], 10, 16, "stone", "terracotta"),
                                    cylp([16, 40, 16], 8, 14, "stone", "clay"), cylp([16, 54, 16], 6.5, 12, "stone", "terracotta"), cylp([16, 66, 16], 7.5, 6, "stone", "dark_brick")])

KIT["boulder_big"] = ([48, 32, 48], [sphr([24, 12, 24], [23, 15, 23], "stone"), sphr([33, 20, 18], [11, 9, 11], "stone"), sphr([24, 24, 24], [16, 7, 16], "leaves", "paint")])  # moss on the top
KIT["ice_rock"] = ([24, 22, 24], [sphr([12, 8, 12], [11, 10, 11], "stone"), sphr([8, 12, 15], [7, 8, 7], "stone"), box([0, 11, 0], [23, 21, 23], "snow", "paint")])  # snow on top

KIT["dead_shrub"] = ([16, 14, 16], [ln([8, 0, 8], [2, 10, 4], 0.6, "wood"), ln([8, 0, 8], [13, 12, 9], 0.6, "wood"), ln([8, 0, 8], [7, 13, 14], 0.6, "wood"), ln([8, 0, 8], [12, 9, 2], 0.5, "wood"),
                                   ln([8, 0, 8], [3, 8, 13], 0.5, "wood"), ln([5, 5, 6], [1, 12, 9], 0.4, "wood"), ln([11, 6, 9], [15, 10, 14], 0.4, "wood")])

KIT["cairn"] = ([10, 18, 10], [sph([5, 4, 5], 4.6, "stone"), sph([5, 9, 5], 3.9, "stone"), sph([5, 13, 5], 3.1, "stone"), sph([5, 16, 5], 2.2, "stone")])
KIT["log_pile"] = ([32, 16, 24], [cyl([0, 3, 4], 3.5, 32, "wood", "x"), cyl([0, 3, 12], 3.5, 32, "wood", "x"), cyl([0, 3, 20], 3.5, 32, "wood", "x"),
                                  cyl([0, 9, 8], 3.5, 32, "wood", "x"), cyl([0, 9, 16], 3.5, 32, "wood", "x"), cyl([0, 14, 12], 3.3, 32, "wood", "x")])

circle = [box([40, 0, 40], [55, 3, 55], "stone")]  # an altar stone in the middle
for _k, _h in enumerate((24, 18, 26, 10, 22, 14, 26, 6)):  # eight standing stones, some broken, on a ring of 40 voxels
    _a = _k * 2 * _m.pi / 8
    _x, _z = int(round(47 + 40 * _m.cos(_a))), int(round(47 + 40 * _m.sin(_a)))
    circle.append(box([_x - 4, 0, _z - 3], [_x + 3, _h - 1, _z + 2], "stone"))
circle.append(box([47 + 40 - 6, 24, 47 - 3], [47 + 40 + 3, 27, 47 + 2], "stone"))  # a lintel across the first and its neighbour would need two tall stones: one lintel on the tallest pair
KIT["stone_circle"] = ([96, 28, 96], circle)

KIT["ruined_tower"] = ([40, 72, 40], [cyl([20, 0, 20], 19, 72, "stone"), cyl([20, 2, 20], 15, 70, "air"), box([16, 2, 0], [23, 20, 6], "air"),  # the shell, the hollow, the door
                                      box([0, 50, 0], [20, 71, 39], "air"), box([20, 60, 0], [39, 71, 18], "air"), box([24, 64, 18], [39, 71, 39], "air"),       # the broken top
                                      box([0, 26, 17], [5, 34, 22], "air"), box([34, 30, 17], [39, 38, 22], "air"), box([17, 36, 34], [22, 44, 39], "air"),       # windows
                                      *[box([10 + i * 4, 4 + i * 3, 22 - i], [13 + i * 4, 4 + i * 3, 24 - i], "stone") for i in range(0, 8)],                   # the stair's remains
                                      box([6, 1, 6], [33, 1, 33], "dirt", "fill_air"), sphr([12, 2, 28], [6, 2, 6], "stone"), sphr([27, 2, 10], [4, 2, 4], "stone")])  # rubble inside

KIT["broken_pillar"] = ([12, 24, 12], [cyl([6, 0, 6], 5.0, 24, "stone"), cyl([6, 0, 6], 5.8, 2, "stone"), box([0, 15, 0], [5, 23, 11], "air"), box([6, 19, 0], [11, 23, 11], "air"), box([6, 17, 6], [11, 23, 11], "air")])

hut = [cyl([24, 0, 24], 22, 28, "wood"), cyl([24, 2, 24], 19, 26, "air"), box([21, 2, 0], [27, 20, 6], "air"), box([0, 0, 0], [47, 1, 47], "dirt", "fill_air"),
       box([21, 2, 0], [27, 20, 6], "air"), cyl([24, 1, 24], 21.5, 1, "stone")]
for _i in range(12):  # a thatched cone
    hut.append(cylp([24, 26 + _i * 2, 24], 25 - _i * 2, 2, "wood", "straw"))
hut += [box([2, 10, 22], [4, 16, 26], "air"), box([44, 10, 22], [46, 16, 26], "air"), box([22, 10, 44], [26, 16, 46], "air"), cyl([24, 44, 24], 1.2, 6, "wood")]  # windows, a finial
KIT["hut_round"] = ([48, 52, 48], hut)

# the kit's folders (a model's path is FOLDER/name, also in the models folder of a project that uses it)
FOLDER = {}
for _folder, _names in {"nature": "oak birch pine bush rock tree_small dead_tree willow fallen_log stump mushroom_big berry_bush cactus cactus_small rock_spire boulder_big ice_rock dead_shrub cairn log_pile",
                        "buildings": "house_small shed market_stall stone_arch well door tent hut_round", "ruins": "stone_circle ruined_tower broken_pillar",
                        "props": "barrel bench crate lantern_post torch campfire signpost sign_board ladder table chair", "structures": "bridge_segment fence_4 fence_8 stone_wall pillar stairs window_wall wall_corner path_tile"}.items():
    for _n in _names.split():
        FOLDER[_n] = _folder
def path_of(name): return FOLDER[name] + "/" + name

# models of the Cove's asset kit are copied as they are
COPY = ["bench", "crate", "lantern_post", "oak", "birch", "pine", "bush", "rock", "tree_small", "door"]
COPY_MANIFESTS = ["door"]  # a manifest (doors with a hinge and a plate) is copied with its model: the kit has one prefab that does something

def main():
    view = None
    if "--view" in sys.argv:
        view = sys.argv[sys.argv.index("--view") + 1]
        os.makedirs(view, exist_ok=True)
    only = []
    if "--only" in sys.argv:
        i = sys.argv.index("--only") + 1
        while i < len(sys.argv) and not sys.argv[i].startswith("--"):
            only.append(sys.argv[i]); i += 1
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, "project.cfg"), "w") as f:
        f.write("name = kit\nterrain = flat\nworld = 8\n")
    os.makedirs(os.path.join(tmp, "models"), exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    try:
        with Voxelith(["--project", tmp]) as v:
            for name, (size, ops) in KIT.items():
                if only and name not in only: continue
                v.tool("model_new", name=name, size=size, replace=True)
                r = v.call("model_edit", model=name, ops=ops)
                if r.get("isError"):
                    sys.exit("%s: %s" % (name, json.dumps(r.get("structuredContent"))[:400]))
                info = r["structuredContent"]
                v.tool("model_save", model=name, file=path_of(name), overwrite=True)
                os.makedirs(os.path.join(OUT, FOLDER[name]), exist_ok=True)
                shutil.copy(os.path.join(tmp, "models", path_of(name) + ".vxm"), os.path.join(OUT, path_of(name) + ".vxm"))
                print("%-16s %s %7d voxels  %s" % (name, "x".join(map(str, info["size"])), info["solid_voxels"], json.dumps(info["materials"])))
                if view:
                    png = v.screenshot(os.path.join(view, name + ".png")) if False else None
                    img = v.call("model_view", model=name, size=256)
                    import base64
                    for c in img["content"]:
                        if c["type"] == "image":
                            open(os.path.join(view, name + ".png"), "wb").write(base64.b64decode(c["data"]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if only:
        print("rebuilt %s -> %s" % (", ".join(only), OUT))
        return
    cove = os.path.join(ROOT, "projects", "lantern_cove", "models")
    for n in COPY:
        os.makedirs(os.path.join(OUT, FOLDER[n]), exist_ok=True)
        shutil.copy(os.path.join(cove, n + ".vxm"), os.path.join(OUT, path_of(n) + ".vxm"))
    for n in COPY_MANIFESTS:
        text = open(os.path.join(cove, n + ".prefab.lua")).read().replace('"%s.vxm"' % n, '"%s.vxm"' % path_of(n))
        open(os.path.join(OUT, path_of(n) + ".prefab.lua"), "w").write(text)
    print("kit: %d built, %d copied, %d manifests -> %s" % (len(KIT), len(COPY), len(COPY_MANIFESTS), OUT))

if __name__ == "__main__":
    main()
