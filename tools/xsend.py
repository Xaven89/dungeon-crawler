#!/usr/bin/env python3
"""Sends synthetic key / mouse events to the engine's window (XSendEvent through ctypes: no xdotool or libXtst on this machine; docs/GUIDE.md names a tools/xdrive.py that the package does not contain).
usage: DISPLAY=:95 tools/xsend.py key i 0.2 key Escape 0.2 click 960 540 0.2 down left 0.5 up left 0.1 move 100 200
  key NAME [seconds]   a key press and release (X keysym names: i, c, space, Escape, 1, Return ...), `keydown NAME` / `keyup NAME` hold and release
  click X Y            move the pointer there and press / release the left button;  `rclick X Y` the right one;  `down left|right` / `up left|right` the buttons alone
  move X Y             a pointer motion to window coordinates
  wait SECONDS
The window is found by the title that contains `voxelith` / `Voxelith`. Works only if the engine reads core X events (see ENGINE_FEEDBACK.md for what it did)."""
import ctypes, ctypes.util, os, sys, time
from ctypes import c_int, c_uint, c_ulong, c_long, c_char_p, c_void_p, POINTER, Structure, Union, byref, c_short, c_ubyte

X = ctypes.CDLL("libX11.so.6")
X.XOpenDisplay.restype = c_void_p
X.XOpenDisplay.argtypes = [c_char_p]
X.XDefaultRootWindow.restype = c_ulong
X.XDefaultRootWindow.argtypes = [c_void_p]
X.XQueryTree.argtypes = [c_void_p, c_ulong, POINTER(c_ulong), POINTER(c_ulong), POINTER(POINTER(c_ulong)), POINTER(c_uint)]
X.XFetchName.argtypes = [c_void_p, c_ulong, POINTER(c_char_p)]
X.XStringToKeysym.restype = c_ulong
X.XStringToKeysym.argtypes = [c_char_p]
X.XKeysymToKeycode.restype = c_ubyte
X.XKeysymToKeycode.argtypes = [c_void_p, c_ulong]
X.XSendEvent.argtypes = [c_void_p, c_ulong, c_int, c_long, c_void_p]
X.XFlush.argtypes = [c_void_p]

class XKeyEvent(Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p), ("window", c_ulong), ("root", c_ulong), ("subwindow", c_ulong), ("time", c_ulong),
                ("x", c_int), ("y", c_int), ("x_root", c_int), ("y_root", c_int), ("state", c_uint), ("keycode", c_uint), ("same_screen", c_int)]
class XButtonEvent(Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p), ("window", c_ulong), ("root", c_ulong), ("subwindow", c_ulong), ("time", c_ulong),
                ("x", c_int), ("y", c_int), ("x_root", c_int), ("y_root", c_int), ("state", c_uint), ("button", c_uint), ("same_screen", c_int)]
class XMotionEvent(Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p), ("window", c_ulong), ("root", c_ulong), ("subwindow", c_ulong), ("time", c_ulong),
                ("x", c_int), ("y", c_int), ("x_root", c_int), ("y_root", c_int), ("state", c_uint), ("is_hint", ctypes.c_char), ("same_screen", c_int)]
class XEvent(Union):
    _fields_ = [("type", c_int), ("key", XKeyEvent), ("button", XButtonEvent), ("motion", XMotionEvent), ("pad", c_long * 24)]

KeyPress, KeyRelease, ButtonPress, ButtonRelease, MotionNotify = 2, 3, 4, 5, 6
KeyPressMask, KeyReleaseMask, ButtonPressMask, ButtonReleaseMask, PointerMotionMask = 1, 2, 4, 8, 64

dpy = X.XOpenDisplay(os.environ.get("DISPLAY", ":95").encode())
if not dpy: sys.exit("cannot open the display")
root = X.XDefaultRootWindow(dpy)

def find(win):
    name = c_char_p()
    if X.XFetchName(dpy, win, byref(name)) and name.value and b"oxelith" in name.value: return win
    r, p, kids, n = c_ulong(), c_ulong(), POINTER(c_ulong)(), c_uint()
    if X.XQueryTree(dpy, win, byref(r), byref(p), byref(kids), byref(n)) and n.value:
        for i in range(n.value):
            f = find(kids[i])
            if f: return f
    return 0

win = find(root)
if not win: sys.exit("no window with 'voxelith' in its title")

def send(ev, mask):
    X.XSendEvent(dpy, win, 1, mask, byref(ev)); X.XFlush(dpy)

def key(name, down, up, hold=0.05):
    code = X.XKeysymToKeycode(dpy, X.XStringToKeysym(name.encode()))
    ev = XEvent(); ev.key.type = KeyPress; ev.key.display = dpy; ev.key.window = win; ev.key.root = root; ev.key.keycode = code; ev.key.same_screen = 1
    if down: ev.key.type = KeyPress; send(ev, KeyPressMask)
    if down and up: time.sleep(hold)
    if up: ev.key.type = KeyRelease; send(ev, KeyReleaseMask)

def button(n, down, x=None, y=None):
    ev = XEvent(); ev.button.display = dpy; ev.button.window = win; ev.button.root = root; ev.button.button = n; ev.button.same_screen = 1
    if x is not None: ev.button.x = x; ev.button.y = y
    ev.button.type = ButtonPress if down else ButtonRelease
    send(ev, ButtonPressMask if down else ButtonReleaseMask)

def motion(x, y):
    ev = XEvent(); ev.motion.type = MotionNotify; ev.motion.display = dpy; ev.motion.window = win; ev.motion.root = root; ev.motion.x = x; ev.motion.y = y; ev.motion.same_screen = 1
    send(ev, PointerMotionMask)

a = sys.argv[1:]
i = 0
while i < len(a):
    c = a[i]
    if c == "key": key(a[i + 1], True, True); i += 2
    elif c == "keydown": key(a[i + 1], True, False); i += 2
    elif c == "keyup": key(a[i + 1], False, True); i += 2
    elif c in ("click", "rclick"):
        x, y = int(a[i + 1]), int(a[i + 2]); b = 1 if c == "click" else 3
        motion(x, y); time.sleep(0.05); button(b, True, x, y); time.sleep(0.08); button(b, False, x, y); i += 3
    elif c == "down": button(1 if a[i + 1] == "left" else 3, True); i += 2
    elif c == "up": button(1 if a[i + 1] == "left" else 3, False); i += 2
    elif c == "move": motion(int(a[i + 1]), int(a[i + 2])); i += 3
    elif c == "wait": time.sleep(float(a[i + 1])); i += 2
    else:
        try: time.sleep(float(c))
        except ValueError: sys.exit("unknown command " + c)
        i += 1
