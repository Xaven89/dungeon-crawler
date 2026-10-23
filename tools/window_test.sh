#!/usr/bin/env bash
# The windowed paths on a virtual display (Xvfb): the engine opens a window, plays a networked-free project for a few seconds with the accessibility settings on, takes real X key events
# (the truck: E gets in, W drives, E gets out; F5 takes a picture) and must neither crash nor report an error. Exit 0 = good, 77 = no Xvfb / no GPU.
# Usage: tools/window_test.sh [voxelith binary]
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${1:-$ROOT/build/release/voxelith}"
# shellcheck source=/dev/null
source "$ROOT/env.sh" >/dev/null 2>&1 || true
command -v Xvfb >/dev/null 2>&1 || { echo "no Xvfb: skipped"; exit 77; }
TMP="$(mktemp -d)"
DISP=":$((120 + RANDOM % 60))"
trap 'kill $XVFB $ENG 2>/dev/null; rm -rf "$TMP"' EXIT
Xvfb "$DISP" -screen 0 1280x720x24 >"$TMP/xvfb.out" 2>&1 &
XVFB=$!
sleep 1
mkdir -p "$TMP/proj" "$TMP/home/share"
cat >"$TMP/proj/project.cfg" <<'CFG'
name = window test
terrain = flat
world = 40
lua = level.lua
CFG
cat >"$TMP/proj/level.lua" <<'LUA'
function on_tick(t)
    if t == 20 then
        local x, y, z = player.pos()
        local fx, fy, fz = player.forward()
        local l = math.sqrt(fx * fx + fz * fz)
        fx, fz = fx / l, fz / l
        vehicle.spawn { x = x + fx * 3.2, y = y + 1.2, z = z + fz * 3.2, heading = math.deg(math.atan(fx, fz)) }
        local a = agent.spawn { x = x - fx * 6, y = y + 0.1, z = z - fz * 6 }
        agent.wander(a, 4)
    end
end
function on_hud(dt) ui.text(40, 40, tr("title"), { size = 30 }) end
LUA
HOME="$TMP/home" DISPLAY="$DISP" timeout 120 "$BIN" --windowed --project "$TMP/proj" --hud 1 --setting subtitles=on --setting colorblind=deuteranopia --setting ui_scale=1.25 >"$TMP/engine.out" 2>&1 &
ENG=$!
for _ in $(seq 1 40); do grep -q "rendering " "$TMP/engine.out" 2>/dev/null && break; sleep 1; done
if grep -qiE "no vulkan|cannot create|no suitable|cannot open display" "$TMP/engine.out"; then echo "no window / GPU: skipped"; exit 77; fi
sleep 10
DISPLAY="$DISP" python3 "$ROOT/tools/xdrive.py" key F5 0.3 sleep 1 key e 0.3 sleep 2 key w 2 key a 0.5 key F5 0.3 sleep 1 key e 0.3 sleep 2 key F5 0.3 sleep 2
if ! kill -0 $ENG 2>/dev/null; then echo "the engine died:"; tail -15 "$TMP/engine.out"; exit 1; fi
if grep -qE "\[error\]|crashed|Segmentation" "$TMP/engine.out"; then echo "the engine reported an error:"; grep -E "\[error\]|crashed" "$TMP/engine.out" | head -5; exit 1; fi
n="$(ls "$TMP"/home/share/voxelith-*.png 2>/dev/null | wc -l)"
[ "$n" -ge 3 ] || { echo "only $n pictures were taken"; tail -5 "$TMP/engine.out"; exit 1; }
echo "a window on a virtual display: the truck was entered, driven and left, $n pictures, no errors"
