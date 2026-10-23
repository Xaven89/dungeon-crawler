# Injects real X input (XTEST) into the headless display :90, to drive the windowed game's tool UI.
import ctypes, sys, time, os
os.environ.setdefault("DISPLAY", ":90")
x11 = ctypes.CDLL("libX11.so.6"); xt = ctypes.CDLL("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XKeysymToKeycode.restype = ctypes.c_ubyte
x11.XStringToKeysym.restype = ctypes.c_ulong
d = x11.XOpenDisplay(None)
assert d, "cannot open display"
# --- the focus guard: input is only injected while the window that would receive it is the game's (its title starts with "Voxelith"): :90 is also the Sunshine display, and a streaming
# client that is using it must not get random keys
x11.XGetInputFocus.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_int)]
x11.XFetchName.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_char_p)]
x11.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_uint)]
x11.XQueryPointer.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong)] + [ctypes.POINTER(ctypes.c_int)] * 4 + [ctypes.POINTER(ctypes.c_uint)]
x11.XDefaultRootWindow.restype = ctypes.c_ulong
_guard = {"t": 0.0, "ok": False}
def window_name(w):
    for _ in range(6):
        if not w: return ""
        name = ctypes.c_char_p()
        if x11.XFetchName(ctypes.c_void_p(d), w, ctypes.byref(name)) and name.value: return name.value.decode(errors="replace")
        root, parent, kids, n = ctypes.c_ulong(), ctypes.c_ulong(), ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
        if not x11.XQueryTree(ctypes.c_void_p(d), w, ctypes.byref(root), ctypes.byref(parent), ctypes.byref(kids), ctypes.byref(n)): return ""
        w = parent.value
    return ""
def game_has_focus():
    if time.time() - _guard["t"] < 0.5: return _guard["ok"]
    foc, rev = ctypes.c_ulong(), ctypes.c_int()
    x11.XGetInputFocus(ctypes.c_void_p(d), ctypes.byref(foc), ctypes.byref(rev))
    w = foc.value
    if w in (0, 1):  # None / PointerRoot: the window under the pointer
        root, child = ctypes.c_ulong(), ctypes.c_ulong()
        ints = [ctypes.c_int() for _ in range(4)]
        mask = ctypes.c_uint()
        x11.XQueryPointer(ctypes.c_void_p(d), x11.XDefaultRootWindow(ctypes.c_void_p(d)), ctypes.byref(root), ctypes.byref(child), *[ctypes.byref(i) for i in ints], ctypes.byref(mask))
        w = child.value
    _guard["ok"] = window_name(w).startswith("Voxelith")
    _guard["t"] = time.time()
    return _guard["ok"]
def wait_for_game(timeout=60):
    t0 = time.time()
    while time.time() - t0 < timeout:
        _guard["t"] = 0.0
        if game_has_focus(): return True
        time.sleep(1)
    return False
def move(x, y):
    if not game_has_focus(): time.sleep(0.2); return xt.XTestFakeMotionEvent(ctypes.c_void_p(d), 0, int(x), int(y), 0); x11.XFlush(ctypes.c_void_p(d)); time.sleep(0.08)
def button(b, down):
    if not game_has_focus(): return
    xt.XTestFakeButtonEvent(ctypes.c_void_p(d), b, 1 if down else 0, 0); x11.XFlush(ctypes.c_void_p(d)); time.sleep(0.08)
def click(x, y, b=1): move(x, y); button(b, True); time.sleep(0.05); button(b, False); time.sleep(0.15)
def keysym(name): return x11.XStringToKeysym(name.encode())
def key(name, down=None):
    if not game_has_focus(): time.sleep(0.1); return
    kc = x11.XKeysymToKeycode(ctypes.c_void_p(d), keysym(name))
    if down is None:
        xt.XTestFakeKeyEvent(ctypes.c_void_p(d), kc, 1, 0); x11.XFlush(ctypes.c_void_p(d)); time.sleep(0.05)
        xt.XTestFakeKeyEvent(ctypes.c_void_p(d), kc, 0, 0)
    else:
        xt.XTestFakeKeyEvent(ctypes.c_void_p(d), kc, 1 if down else 0, 0)
    x11.XFlush(ctypes.c_void_p(d)); time.sleep(0.12)
def typ(s):
    for ch in s:
        names = {' ': 'space', '(': 'parenleft', ')': 'parenright', ',': 'comma', "'": 'apostrophe', '.': 'period', '=': 'equal', '-': 'minus', '_': 'underscore', '"': 'quotedbl'}
        shift = ch.isupper() or ch in '()_"'
        if shift: key("Shift_L", True)
        key(names.get(ch, ch))
        if shift: key("Shift_L", False)
