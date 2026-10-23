# A seeded random player: real X input (XTEST, libXtst via ctypes) into the windowed game for a while: walking, looking around, digging, building, blasts, teleports, rain, the panels.
# Usage: tools/xfuzz.py <dir containing xin.py> <seed> <seconds>   (see tools/xdrive.py for the same helpers; record the game with --record and --seconds, then --replay it)
import sys, time, random
sys.path.insert(0, sys.argv[1])
import xin
if not xin.wait_for_game(60): sys.exit("the game window did not appear (or does not have the focus): nothing was injected")
rnd = random.Random(int(sys.argv[2]))
dur = float(sys.argv[3])
keys = ["w", "a", "s", "d", "space", "f", "b", "y", "n", "m", "g", "r", "z", "x", "1", "2", "3", "4", "5", "6", "7", "F1", "F2", "F3", "F7", "F8", "F9", "F10", "k", "u"]
t0 = time.time()
n = 0
while time.time() - t0 < dur:
    c = rnd.random()
    if c < 0.45:
        k = rnd.choice(keys)
        down = rnd.random() < 0.3
        if down and k in "wasd":
            xin.key(k, True); time.sleep(rnd.uniform(0.2, 1.2)); xin.key(k, False)
        else:
            xin.key(k)
    elif c < 0.75:
        xin.move(rnd.randint(100, 1800), rnd.randint(100, 1000))
    elif c < 0.9:
        b = rnd.choice([1, 3])
        xin.button(b, True); time.sleep(rnd.uniform(0.05, 0.4)); xin.button(b, False)
    elif c < 0.95:
        xin.key("Tab"); time.sleep(0.3)
        for _ in range(rnd.randint(1, 4)):
            xin.click(rnd.randint(30, 700), rnd.randint(30, 600))
        xin.key("Tab")
    else:
        xin.key("Tab"); time.sleep(0.2); xin.key("Tab")
    n += 1
print("inputs", n)
