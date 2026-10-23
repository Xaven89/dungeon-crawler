#!/usr/bin/env python3
"""Tiny XTEST driver to exercise the windowed app's input without a human (no xdotool on this box).
usage: xdrive.py key w 1.5 | click 1 (4 / 5: wheel up / down) | move dx dy | moveto x y | down b | up b (hold a button) | keydown k | keyup k (hold a key) | sleep 2 ...  (actions run in order; DISPLAY must be set)"""
import ctypes, sys, time

x11 = ctypes.CDLL("libX11.so.6")
xtst = ctypes.CDLL("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XKeysymToKeycode.restype = ctypes.c_ubyte
x11.XStringToKeysym.restype = ctypes.c_ulong
dpy = x11.XOpenDisplay(None)
if not dpy:
    sys.exit("cannot open display")

def flush():
    x11.XFlush(ctypes.c_void_p(dpy))

def key(name, hold):
    kc = x11.XKeysymToKeycode(ctypes.c_void_p(dpy), ctypes.c_ulong(x11.XStringToKeysym(name.encode())))
    xtst.XTestFakeKeyEvent(ctypes.c_void_p(dpy), kc, 1, 0); flush()
    time.sleep(hold)
    xtst.XTestFakeKeyEvent(ctypes.c_void_p(dpy), kc, 0, 0); flush()

def click(button):
    xtst.XTestFakeButtonEvent(ctypes.c_void_p(dpy), button, 1, 0); flush()
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(ctypes.c_void_p(dpy), button, 0, 0); flush()

def move(dx, dy):
    xtst.XTestFakeRelativeMotionEvent(ctypes.c_void_p(dpy), dx, dy, 0); flush()

def button(b, down):
    xtst.XTestFakeButtonEvent(ctypes.c_void_p(dpy), b, 1 if down else 0, 0); flush()

def keyst(name, down):
    kc = x11.XKeysymToKeycode(ctypes.c_void_p(dpy), ctypes.c_ulong(x11.XStringToKeysym(name.encode())))
    xtst.XTestFakeKeyEvent(ctypes.c_void_p(dpy), kc, 1 if down else 0, 0); flush()

def moveto(x, y):
    xtst.XTestFakeMotionEvent(ctypes.c_void_p(dpy), -1, x, y, 0); flush()

a = sys.argv[1:]
i = 0
while i < len(a):
    if a[i] == "key": key(a[i + 1], float(a[i + 2])); i += 3
    elif a[i] == "click": click(int(a[i + 1])); i += 2
    elif a[i] == "move": move(int(a[i + 1]), int(a[i + 2])); i += 3
    elif a[i] == "down": button(int(a[i + 1]), True); i += 2
    elif a[i] == "up": button(int(a[i + 1]), False); i += 2
    elif a[i] == "keydown": keyst(a[i + 1], True); i += 2
    elif a[i] == "keyup": keyst(a[i + 1], False); i += 2
    elif a[i] == "moveto": moveto(int(a[i + 1]), int(a[i + 2])); i += 3
    elif a[i] == "sleep": time.sleep(float(a[i + 1])); i += 2
    else: sys.exit("bad action " + a[i])
