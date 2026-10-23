#!/usr/bin/env python3
"""Writes the sample creatures (rigged .vxm models, docs/ANIMATION.md) without the engine: a slime, a skeleton and a goblin (the unfriendly ones), a rabbit, a deer and a chicken
(the friendly ones). Every creature faces +z and stands on y = 0 (docs/AGENTS.md); the part names follow the roles the rig infers (pelvis, head, torso, thigh_l / shin_l / foot_l,
upper_arm_l / forearm_l, front_leg_l / lower_leg_fl / foot_fl, tail), so `agent.spawn{animation = "auto"}` walks them by rule, and the clips are what the rules do not do: a slime's hop,
an attack swing, an idle sway. Colours are paint (docs/PAINT.md) on a flat texture, so the voxels show the colour and not the material's pattern.
usage: tools/make_creatures.py [OUT_DIR]   (default projects/creature_test/models; also copied to assets/prefabs/creatures)
The file layout is the one of src/world/vxm.cpp and src/world/rig.cpp (saveRig): VXM4 = voxels with texture names, then the part table, the part map, the clips, an ANIM chunk."""
import math, os, struct, sys, json

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

# ---- the paint palette (src/world/paint.cpp): index by name ------------------------------------------------------------------------------------------------------------------------
HUES = ["red", "orange", "yellow", "lime", "green", "spring", "cyan", "azure", "blue", "violet", "magenta", "rose"]
TONES = ["pale_", "light_", "", "deep_", "dark_", "muted_", "dusty_", "shadow_"]
EXTRA = ["sand", "straw", "tan", "light_brown", "brown", "dark_brown", "chestnut", "espresso", "brick", "dark_brick", "terracotta", "clay", "stone", "light_stone", "slate", "dark_slate", "concrete",
         "grass", "moss", "leaf", "pine", "olive", "water", "sky", "navy", "teal", "skin_light", "skin_tan", "skin_brown", "skin_dark", "snow", "gold", "silver", "copper", "bronze", "hot_pink", "amber",
         "wine", "indigo", "cream"]
PAINT = {"white": 1, "grey": 8, "black": 16}
for _i in range(16): PAINT["grey%d" % _i] = 1 + _i  # grey0 white ... grey15 black
for _h, _hn in enumerate(HUES):
    for _t, _tn in enumerate(TONES): PAINT[_tn + _hn] = 17 + _h * 8 + _t
for _i, _n in enumerate(EXTRA): PAINT[_n] = 113 + _i

def lz4_literal_block(raw):
    """An LZ4 block of one literal-only sequence (LZ4_decompress_safe accepts it)."""
    n = len(raw)
    if n == 0: return b""
    if n < 15: return bytes([n << 4]) + raw
    out = bytearray([0xF0])
    rest = n - 15
    while rest >= 255:
        out.append(255); rest -= 255
    out.append(rest)
    return bytes(out) + raw

def s8(s):
    b = s.encode()
    assert len(b) < 256
    return bytes([len(b)]) + b

class Creature:
    def __init__(self, name, size, scale=1.0):
        self.name, self.size = name, tuple(size)
        self.scale = scale  # world voxels per voxel of this model (Rig::scale, docs/ANIMATION.md "Voxel scale")
        self.vox = {}      # (x, y, z) -> (material, paint, texture, part)
        self.parts = [("root", -1, (0.0, 0.0, 0.0))]  # name, parent index, pivot
        self.clips = []    # (name, duration, loop, {part: [(t, rot, pos, glow)]}, events)
    # parts
    def part(self, name, parent, pivot):
        self.parts.append((name, self.index(parent), tuple(float(v) for v in pivot)))
        return name
    def index(self, name):
        for i, p in enumerate(self.parts):
            if p[0] == name: return i
        raise KeyError(name)
    # shapes (coordinates in voxels; inclusive boxes; a voxel is in a sphere when its centre is)
    def put(self, x, y, z, m, paint, part, tex="smooth"):
        sx, sy, sz = self.size
        if 0 <= x < sx and 0 <= y < sy and 0 <= z < sz: self.vox[(x, y, z)] = (m, PAINT[paint] if isinstance(paint, str) else paint, tex, part)
    def box(self, a, b, paint, part="root", m="wood"):
        for x in range(a[0], b[0] + 1):
            for y in range(a[1], b[1] + 1):
                for z in range(a[2], b[2] + 1): self.put(x, y, z, m, paint, part)
    def ellipsoid(self, c, r, paint, part="root", m="wood"):
        rx, ry, rz = (r, r, r) if isinstance(r, (int, float)) else r
        for x in range(int(c[0] - rx - 1), int(c[0] + rx + 2)):
            for y in range(int(c[1] - ry - 1), int(c[1] + ry + 2)):
                for z in range(int(c[2] - rz - 1), int(c[2] + rz + 2)):
                    dx, dy, dz = (x + 0.5 - c[0]) / rx, (y + 0.5 - c[1]) / ry, (z + 0.5 - c[2]) / rz
                    if dx * dx + dy * dy + dz * dz <= 1.0: self.put(x, y, z, m, paint, part)
    def line(self, a, b, r, paint, part="root", m="wood"):
        n = int(max(abs(b[i] - a[i]) for i in range(3)) * 2) + 1
        for k in range(n + 1):
            t = k / n
            p = [a[i] + (b[i] - a[i]) * t for i in range(3)]
            self.ellipsoid((p[0] + 0.5, p[1] + 0.5, p[2] + 0.5), r, paint, part, m)
    # clips: keys = {part: [(t, (rx, ry, rz), (px, py, pz), glow)]}
    def clip(self, name, duration, loop, keys, events=()):
        self.clips.append((name, float(duration), bool(loop), keys, list(events)))
    # the file
    def write(self, path):
        sx, sy, sz = self.size
        mats, texs = [], []
        for v in self.vox.values():
            if v[0] not in mats: mats.append(v[0])
            if v[2] and v[2] not in texs: texs.append(v[2])
        raw = bytearray(sx * sy * sz * 4)
        pmap = bytearray(sx * sy * sz)
        for (x, y, z), (m, paint, tex, part) in self.vox.items():
            i = x + sx * (y + sy * z)
            struct.pack_into("<HBB", raw, i * 4, mats.index(m) + 1, paint, texs.index(tex) + 1 if tex else 0)
            pmap[i] = self.index(part)
        out = bytearray(b"VXM4")
        out += struct.pack("<III", sx, sy, sz)
        out += struct.pack("<H", len(mats)) + b"".join(s8(m) for m in mats)
        out += struct.pack("<H", len(texs)) + b"".join(s8(t) for t in texs)
        packed = lz4_literal_block(bytes(raw))
        out += struct.pack("<II", len(raw), len(packed)) + packed
        out += bytes([len(self.parts)])
        for name, parent, pivot in self.parts:
            out += s8(name) + struct.pack("<Hfff", parent + 1, *pivot) + s8("")
        packed = lz4_literal_block(bytes(pmap))
        out += struct.pack("<II", len(pmap), len(packed)) + packed
        out += struct.pack("<H", len(self.clips))
        events = {}
        for name, duration, loop, keys, ev in self.clips:
            out += s8(name) + struct.pack("<fBH", duration, 1 if loop else 0, len(keys))
            for part, ks in keys.items():
                ks = sorted(ks, key=lambda k: k[0])
                out += struct.pack("<BH", self.index(part), len(ks))
                for t, rot, pos, glow in ks:
                    assert 0 <= t <= duration, (name, part, t)
                    out += struct.pack("<ffffffff", t, rot[0], rot[1], rot[2], pos[0], pos[1], pos[2], glow)
            if ev: events[name] = [{"t": t, "name": n} for t, n in ev]
        if events or self.scale != 1.0:
            doc = {"events": events} if events else {}
            if self.scale != 1.0: doc["scale"] = self.scale
            text = json.dumps(doc).encode()
            out += b"ANIM" + struct.pack("<HI", 1, len(text)) + text
        with open(path, "wb") as f: f.write(out)
        return len(self.vox)

def K(t, rot=(0, 0, 0), pos=(0, 0, 0), glow=0.0): return (t, rot, pos, glow)

# ---- the creatures ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
def slime():
    c = Creature("slime", (16, 12, 16))
    c.ellipsoid((8, 5, 8), (7.5, 5.5, 7.5), "light_green")
    c.ellipsoid((8, 6.5, 8), (5.5, 4, 5.5), "green")           # a darker core shows through the lighter skin at the edges
    for x in (4, 10):                                          # eyes: white with a dark pupil, on the front
        c.box((x, 5, 13), (x + 1, 6, 14), "white")
        c.box((x, 5, 14), (x + 1, 5, 14), "black")
    c.box((6, 3, 14), (9, 3, 14), "dark_green")                 # a mouth line
    hop = {"root": [K(0, (0, 0, 0), (0, 0, 0)), K(0.15, (-10, 0, 0), (0, 3, 0)), K(0.3, (0, 0, 0), (0, 6, 0)), K(0.45, (8, 0, 0), (0, 2, 0)), K(0.55, (0, 0, 0), (0, 0, 0)), K(1.0, (0, 0, 0), (0, 0, 0))]}
    c.clip("walk", 1.0, True, hop, [(0.55, "land")])
    c.clip("idle", 2.0, True, {"root": [K(0, pos=(0, 0, 0)), K(1.0, pos=(0, 1, 0)), K(2.0, pos=(0, 0, 0))]})
    c.clip("attack", 0.5, False, {"root": [K(0), K(0.15, (-30, 0, 0), (0, 2, -2)), K(0.3, (20, 0, 0), (0, 1, 5)), K(0.5)]}, [(0.3, "hit")])
    return c

def biped(c, skin, pelvisY, legLen, shinLen, torsoH, headR, armLen, foreLen, width, limbR, paint_torso=None, cloth=None):
    """A standing figure: pelvis (root), torso, head, arms and legs with a shin and a foot; `pelvisY` is the hip height; parts are tagged as they are drawn."""
    cx, cz = c.size[0] / 2, c.size[2] / 2
    hipX = width / 2
    # legs
    for side, sgn in (("l", -1), ("r", 1)):
        hx = cx + sgn * hipX
        thigh = c.part("thigh_" + side, "root", (hx, pelvisY, cz))
        shin = c.part("shin_" + side, thigh, (hx, pelvisY - legLen, cz))
        foot = c.part("foot_" + side, shin, (hx, pelvisY - legLen - shinLen, cz))
        c.line((hx - 0.5, pelvisY - 1, cz - 0.5), (hx - 0.5, pelvisY - legLen, cz - 0.5), limbR, skin, thigh)
        c.line((hx - 0.5, pelvisY - legLen - 1, cz - 0.5), (hx - 0.5, pelvisY - legLen - shinLen + 1, cz - 0.5), limbR, skin, shin)
        c.box((int(hx - 1.5), 0, int(cz - 1.5)), (int(hx + 0.5), 1, int(cz + 2.5)), cloth or skin, foot)
    # pelvis and torso
    c.box((int(cx - hipX - 1.5), pelvisY - 1, int(cz - 1.5)), (int(cx + hipX + 0.5), pelvisY + 1, int(cz + 0.5)), cloth or skin, "root")
    torso = c.part("torso", "root", (cx, pelvisY + 2, cz))
    c.box((int(cx - hipX - 1.5), pelvisY + 2, int(cz - 1.5)), (int(cx + hipX + 0.5), pelvisY + torsoH, int(cz + 0.5)), paint_torso or skin, torso)
    # head
    headY = pelvisY + torsoH + 1
    head = c.part("head", torso, (cx, headY, cz))
    c.ellipsoid((cx, headY + headR, cz), headR, skin, head)
    # arms
    for side, sgn in (("l", -1), ("r", 1)):
        sx = cx + sgn * (hipX + 2.5)
        sy = pelvisY + torsoH - 1
        upper = c.part("upper_arm_" + side, torso, (sx, sy, cz))
        fore = c.part("forearm_" + side, upper, (sx, sy - armLen, cz))
        c.line((sx - 0.5, sy, cz - 0.5), (sx - 0.5, sy - armLen + 1, cz - 0.5), limbR, skin, upper)
        c.line((sx - 0.5, sy - armLen, cz - 0.5), (sx - 0.5, sy - armLen - foreLen + 1, cz - 0.5), limbR, skin, fore)
    return torso, head

def skeleton():
    c = Creature("skeleton", (16, 38, 8))
    bone = "grey1"
    torso, head = biped(c, bone, pelvisY=18, legLen=9, shinLen=7, torsoH=12, headR=3.5, armLen=7, foreLen=7, width=5, limbR=0.9)
    # a ribcage: the torso's box becomes rows of ribs with gaps, a spine behind
    cx, cz = 8, 4
    c.vox = {k: v for k, v in c.vox.items() if not (4 <= k[0] <= 11 and 21 <= k[1] <= 29 and 2 <= k[2] <= 4)}
    for y in range(21, 30, 2): c.box((4, y, 2), (11, y, 4), bone, "torso")
    c.box((7, 20, 4), (8, 30, 4), "grey3", "torso")
    c.box((7, 21, 2), (8, 29, 2), bone, "torso")  # the breastbone
    # the skull: dark eye sockets and a grin
    for x in (6, 9): c.box((x, 35, 7), (x, 36, 7), "black", "head")
    for x in range(6, 10, 2): c.box((x, 32, 7), (x, 32, 7), "grey6", "head")
    c.clip("idle", 2.4, True, {"torso": [K(0, (0, 0, 0)), K(1.2, (0, 0, 3)), K(2.4, (0, 0, 0))], "head": [K(0, (0, 0, 0)), K(1.2, (0, -12, 0)), K(2.4, (0, 0, 0))]})
    c.clip("attack", 0.7, False, {"upper_arm_r": [K(0, (0, 0, 0)), K(0.25, (-160, 0, -20)), K(0.4, (-30, 0, 0)), K(0.7, (0, 0, 0))],
                                  "forearm_r": [K(0, (0, 0, 0)), K(0.25, (-60, 0, 0)), K(0.4, (-10, 0, 0)), K(0.7, (0, 0, 0))],
                                  "torso": [K(0, (0, 0, 0)), K(0.25, (-8, 0, 0)), K(0.4, (12, 0, 0)), K(0.7, (0, 0, 0))]}, [(0.4, "hit")])
    return c

def goblin():
    c = Creature("goblin", (16, 28, 10))
    skin = "deep_green"
    torso, head = biped(c, skin, pelvisY=12, legLen=6, shinLen=5, torsoH=8, headR=4.5, armLen=6, foreLen=6, width=5, limbR=1.1, paint_torso="dark_brown", cloth="chestnut")
    # a big head with pointed ears, a long nose, red eyes
    c.line((2.5, 24, 5), (0.5, 28, 5), 0.9, skin, "head"); c.line((12.5, 24, 5), (14.5, 28, 5), 0.9, skin, "head")
    c.box((7, 23, 9), (8, 24, 9), skin, "head")                    # the nose
    for x in (5, 10): c.box((x, 25, 8), (x, 25, 8), "red", "head")
    c.box((6, 21, 8), (9, 21, 8), "dark_red", "head")                # the mouth
    c.box((7, 20, 8), (7, 20, 8), "white", "head")                   # a tooth
    # a club in the right hand
    club = c.part("club", "forearm_r", (12.5, 8, 5))
    c.line((12.5, 7, 5), (12.5, 7, 15), 1.0, "brown", club); c.ellipsoid((12.5, 7.5, 15), 2.2, "dark_brown", club)
    c.clip("idle", 2.0, True, {"torso": [K(0, (3, 0, 0)), K(1.0, (6, 0, 0)), K(2.0, (3, 0, 0))], "head": [K(0, (0, 15, 0)), K(1.0, (0, -15, 0)), K(2.0, (0, 15, 0))]})
    c.clip("attack", 0.6, False, {"upper_arm_r": [K(0, (0, 0, 0)), K(0.2, (-170, 0, -25)), K(0.35, (-20, 0, 0)), K(0.6, (0, 0, 0))],
                                  "forearm_r": [K(0, (0, 0, 0)), K(0.2, (-40, 0, 0)), K(0.35, (0, 0, 0)), K(0.6, (0, 0, 0))],
                                  "torso": [K(0, (0, 0, 0)), K(0.2, (-12, -10, 0)), K(0.35, (18, 10, 0)), K(0.6, (0, 0, 0))]}, [(0.35, "hit")])
    return c

def quad(c, fur, belly, bodyY, bodyR, legH, lowerH, legR, neck=None, headR=3, headPaint=None):
    """A four-legged body along z (the front at +z): body (root), front and hind legs with a lower leg and a hoof/paw, a head (on a neck part when given), a tail."""
    cx = c.size[0] / 2
    rx, ry, rz = bodyR
    zc = c.size[2] / 2 - 2
    c.ellipsoid((cx, bodyY, zc), (rx, ry, rz), fur)
    c.ellipsoid((cx, bodyY - ry * 0.45, zc), (rx * 0.8, ry * 0.6, rz * 0.8), belly)
    legs = []
    for name, suffix, sgn, zz in (("front_leg_l", "fl", -1, zc + rz * 0.6), ("front_leg_r", "fr", 1, zc + rz * 0.6), ("hind_leg_l", "hl", -1, zc - rz * 0.6), ("hind_leg_r", "hr", 1, zc - rz * 0.6)):
        hx = cx + sgn * (rx - legR - 0.5)
        up = c.part(name, "root", (hx, bodyY - ry * 0.4, zz))
        lo = c.part("lower_leg_" + suffix, up, (hx, lowerH, zz))
        ft = c.part("foot_" + suffix, lo, (hx, 1, zz))
        c.line((hx - 0.5, bodyY - ry * 0.4, zz - 0.5), (hx - 0.5, lowerH, zz - 0.5), legR, fur, up)
        c.line((hx - 0.5, lowerH - 1, zz - 0.5), (hx - 0.5, 1, zz - 0.5), legR * 0.9, fur, lo)
        c.box((int(hx - legR), 0, int(zz - legR)), (int(hx + legR - 1), 0, int(zz + legR - 1)), "dark_slate", ft)
        legs.append(up)
    parent = "root"
    hz, hy = zc + rz, bodyY + ry * 0.4
    if neck:
        parent = c.part("spine1", "root", (cx, bodyY + ry * 0.3, zc + rz * 0.7))
        c.line((cx - 0.5, bodyY + ry * 0.3, zc + rz * 0.7), (cx - 0.5, bodyY + ry * 0.3 + neck[0], zc + rz * 0.7 + neck[1]), neck[2], fur, parent)
        hz, hy = zc + rz * 0.7 + neck[1], bodyY + ry * 0.3 + neck[0]
    head = c.part("head", parent, (cx, hy, hz))
    c.ellipsoid((cx, hy + headR * 0.6, hz + headR * 0.8), headR, headPaint or fur, head)
    tail = c.part("tail1", "root", (cx, bodyY + ry * 0.5, zc - rz))
    return head, tail, (cx, hy, hz)

def rabbit():
    c = Creature("rabbit", (10, 14, 14))
    head, tail, (cx, hy, hz) = quad(c, "tan", "cream", bodyY=5, bodyR=(3.5, 3, 5), legH=0, lowerH=3, legR=0.9, headR=2.5)
    # long ears on the head, a white tail puff, pink nose, dark eyes
    for sgn in (-1, 1):
        c.line((cx + sgn * 1.5 - 0.5, hy + 3, hz + 1), (cx + sgn * 1.8 - 0.5, hy + 8, hz - 1), 0.8, "tan", "head")
    c.ellipsoid((cx, 7.5, 2), 1.4, "white", "tail1")
    c.box((int(cx) - 1, int(hy) + 1, int(hz) + 3), (int(cx), int(hy) + 1, int(hz) + 3), "pale_rose", "head")
    for x in (int(cx) - 2, int(cx) + 1): c.box((x, int(hy) + 2, int(hz) + 2), (x, int(hy) + 2, int(hz) + 2), "black", "head")
    c.clip("idle", 3.0, True, {"head": [K(0, (0, 0, 0)), K(1.0, (0, 20, 0)), K(1.6, (-15, 20, 0)), K(2.2, (0, 0, 0)), K(3.0, (0, 0, 0))]})
    return c

def deer():
    c = Creature("deer", (14, 36, 40))
    head, tail, (cx, hy, hz) = quad(c, "light_brown", "cream", bodyY=20, bodyR=(5, 5.5, 13), legH=0, lowerH=10, legR=1.1, neck=(8, 4, 1.6), headR=3)
    # antlers: two branching lines from the head, a white rump, a tail, dark eyes and nose
    for sgn in (-1, 1):
        bx = cx + sgn * 2.5 - 0.5
        c.line((bx, hy + 3, hz + 1), (bx + sgn * 2, hy + 9, hz - 1), 0.7, "chestnut", "head")
        c.line((bx + sgn * 1, hy + 6, hz), (bx + sgn * 3.5, hy + 8, hz + 2), 0.6, "chestnut", "head")
        c.line((bx + sgn * 1.5, hy + 7.5, hz - 0.5), (bx + sgn * 0.5, hy + 11, hz - 2), 0.6, "chestnut", "head")
    c.ellipsoid((cx, 21, 4.5), (3.5, 3, 2), "cream", "root")
    c.line((cx - 0.5, 23, 4), (cx - 0.5, 19, 1), 0.9, "light_brown", "tail1")
    c.box((int(cx) - 1, int(hy) + 2, int(hz) + 5), (int(cx), int(hy) + 2, int(hz) + 5), "black", "head")
    for x in (int(cx) - 3, int(cx) + 2): c.box((x, int(hy) + 3, int(hz) + 3), (x, int(hy) + 3, int(hz) + 3), "black", "head")
    c.clip("idle", 4.0, True, {"spine1": [K(0, (0, 0, 0)), K(1.5, (35, 0, 0)), K(2.5, (35, 0, 0)), K(3.2, (0, 0, 0)), K(4.0, (0, 0, 0))],
                               "head": [K(0, (0, 0, 0)), K(1.5, (20, 0, 0)), K(2.5, (20, 15, 0)), K(3.2, (0, 0, 0)), K(4.0, (0, 0, 0))]})
    return c

def chicken():
    c = Creature("chicken", (8, 14, 12))
    cx, cz = 4, 6
    c.ellipsoid((cx, 7, cz), (3, 3, 4), "white")
    for side, sgn in (("l", -1), ("r", 1)):  # legs: a thigh and a foot (no shin: they swing)
        hx = cx + sgn * 1.5
        leg = c.part("leg_" + side, "root", (hx, 5, cz))
        c.line((hx - 0.5, 5, cz - 0.5), (hx - 0.5, 1, cz - 0.5), 0.6, "amber", leg)
        foot = c.part("foot_" + side, leg, (hx, 1, cz))
        c.box((int(hx) - 1, 0, int(cz) - 1), (int(hx), 0, int(cz) + 2), "amber", foot)
        wing = c.part("wing_" + side, "root", (hx + sgn * 1.5, 8.5, cz))
        c.ellipsoid((cx + sgn * 3, 7.5, cz - 0.5), (1, 2, 2.8), "grey3", wing)
    head = c.part("head", "root", (cx, 9, cz + 3))
    c.line((cx - 0.5, 9, cz + 3), (cx - 0.5, 12, cz + 4), 1.0, "white", head)
    c.box((cx - 1, 12, cz + 4), (cx, 12, cz + 6), "amber", head)                 # the beak
    c.box((cx - 1, 13, cz + 3), (cx, 13, cz + 4), "red", head)                   # the comb
    c.box((cx - 1, 10, cz + 5), (cx, 10, cz + 5), "red", head)                   # the wattle
    for x in (cx - 2, cx + 1): c.box((x, 12, cz + 4), (x, 12, cz + 4), "black", head)
    tail = c.part("tail1", "root", (cx, 8, cz - 3))
    c.line((cx - 0.5, 8, cz - 3), (cx - 0.5, 11, cz - 6), 0.9, "grey3", tail)
    c.clip("idle", 1.6, True, {"head": [K(0, (0, 0, 0)), K(0.4, (25, 0, 0)), K(0.8, (0, 0, 0)), K(1.0, (0, 30, 0)), K(1.3, (0, -30, 0)), K(1.6, (0, 0, 0))]})
    return c

ALL = [slime, skeleton, goblin, rabbit, deer, chicken]

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "projects", "creature_test", "models")
    os.makedirs(out, exist_ok=True)
    kit = os.path.join(ROOT, "assets", "prefabs", "creatures")
    os.makedirs(kit, exist_ok=True)
    for make in ALL:
        c = make()
        path = os.path.join(out, c.name + ".vxm")
        n = c.write(path)
        with open(path, "rb") as f: data = f.read()
        with open(os.path.join(kit, c.name + ".vxm"), "wb") as f: f.write(data)
        print("%-10s %2dx%2dx%2d  %5d voxels  %2d parts  clips: %s" % (c.name, *c.size, n, len(c.parts), ", ".join(k[0] for k in c.clips)))

if __name__ == "__main__":
    main()
