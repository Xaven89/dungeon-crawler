#!/bin/bash
# Starts THE DESCENT (windowed). `tools/play.sh new` forgets the saved run first.
cd "$(dirname "$0")/.."
P=projects/dungeon_crawler
if [ "$1" = "new" ]; then rm -rf $P/world.vxs* $P/.state $P/.events $P/.prefabs; echo "new run"; fi
exec ./voxelith --manual --project $P --hud 0 --threads 3 "${@:2}"
