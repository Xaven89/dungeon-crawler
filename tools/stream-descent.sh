#!/usr/bin/env bash
# Starts THE DESCENT on the headless X display :90 that Sunshine captures (for Moonlight). Sunshine's app entry runs this script.
#   tools/stream-descent.sh          continue the saved run        tools/stream-descent.sh new      forget the saved run first
# Extra arguments go to the engine. The log is ~/share/descent-stream.log.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DISPLAY="${DISPLAY:-:90}"
export XAUTHORITY="${XAUTHORITY:-/etc/X11/headless.xauth}"
P=projects/dungeon_crawler

# the headless Xorg can come up at 1024x768: make the screen the size of the output's mode (the same fix as the Voxelith stream script)
if command -v xrandr >/dev/null 2>&1; then
    XR="$(xrandr 2>/dev/null)"
    OUT="$(printf '%s\n' "$XR" | awk '/ connected/{print $1; exit}')"
    CUR="$(printf '%s\n' "$XR" | awk '/\*/{print $1; exit}')"
    SCR="$(printf '%s\n' "$XR" | sed -n 's/^Screen 0:.*current \([0-9]*\) x \([0-9]*\),.*/\1x\2/p')"
    if [[ -n "$OUT" && -n "$CUR" && "$CUR" != "$SCR" ]]; then
        MODE="$SCR"; printf '%s\n' "$XR" | grep -q "^ *$MODE " || MODE="${VOXELITH_MODE:-1920x1080}"
        xrandr --output "$OUT" --mode "$MODE" --pos 0x0 && xrandr --fb "$MODE"
    fi
fi

cd "$ROOT"
if [[ "${1:-}" == "new" ]]; then shift; rm -rf "$P"/world.vxs* "$P"/.state "$P"/.events "$P"/.prefabs; fi
mkdir -p "$HOME/share"
LOG="$HOME/share/descent-stream.log"
echo "[stream] $(date -Is) starting THE DESCENT $*" >"$LOG"
exec ./voxelith --manual --project "$P" --hud 0 --threads 3 "$@" >>"$LOG" 2>&1
