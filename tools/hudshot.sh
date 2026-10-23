#!/bin/bash
# Looks at the game WITH its Lua HUD: runs the windowed engine in a private Xvfb and grabs the screen (the MCP / headless pictures never contain on_hud, see ENGINE_FEEDBACK.md).
# usage: [BOOT=file.lua] tools/hudshot.sh out.png [wait_seconds] [extra voxelith args...]     e.g. tools/hudshot.sh ~/share/hud.png 10 --script "idle:2000"
# BOOT: a Lua file copied to projects/dungeon_crawler/dev/boot.lua (included at the end of on_start) to set up the situation to look at.
# Starts from a clean world (the project's save is removed first: only use on a project you are developing), kills the engine afterwards.
cd "$(dirname "$0")/.."
OUT=${1:-hud.png}; WAIT=${2:-10}; shift 2 2>/dev/null
D=:95
if ! xdpyinfo -display $D >/dev/null 2>&1; then (Xvfb $D -screen 0 1920x1080x24 >/dev/null 2>&1 &); sleep 2; fi
P=projects/dungeon_crawler
rm -rf $P/world.vxs* $P/.state $P/.events $P/.prefabs
[ -n "$BOOT" ] && cp "$BOOT" $P/dev/boot.lua
DISPLAY=$D ./voxelith --windowed --manual --project $P --threads 3 --hud 0 --no-audio "$@" >/tmp/hudshot.log 2>&1 &
PID=$!
sleep "$WAIT"
ffmpeg -y -loglevel error -f x11grab -video_size 1920x1080 -i $D -frames:v 1 "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null
rm -rf $P/world.vxs* $P/.state $P/.events $P/.prefabs; git checkout -- $P/dev/boot.lua 2>/dev/null
echo "wrote $OUT"
