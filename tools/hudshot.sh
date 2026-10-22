#!/bin/bash
# Looks at the game WITH its Lua HUD: runs the windowed engine in a private Xvfb and grabs the screen (the MCP / headless pictures never contain on_hud, see ENGINE_FEEDBACK.md).
# usage: tools/hudshot.sh out.png [wait_seconds] [extra voxelith args...]     e.g. tools/hudshot.sh ~/share/hud.png 10 --script "idle:2000"
# Starts from a clean world (the project's save is removed first: only use on a project you are developing), kills the engine afterwards.
cd "$(dirname "$0")/.."
OUT=${1:-hud.png}; WAIT=${2:-10}; shift 2 2>/dev/null
D=:95
if ! xdpyinfo -display $D >/dev/null 2>&1; then (Xvfb $D -screen 0 1280x720x24 >/dev/null 2>&1 &); sleep 2; fi
P=projects/dungeon_crawler
rm -rf $P/world.vxs* $P/.state $P/.events $P/.prefabs
DISPLAY=$D ./voxelith --windowed --manual --project $P --threads 3 --time 0.75 --hud 0 --no-audio "$@" >/tmp/hudshot.log 2>&1 &
PID=$!
sleep "$WAIT"
ffmpeg -y -loglevel error -f x11grab -video_size 1280x720 -i $D -frames:v 1 "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null
rm -rf $P/world.vxs* $P/.state $P/.events $P/.prefabs
echo "wrote $OUT"
