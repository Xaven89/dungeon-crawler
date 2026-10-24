#!/bin/sh
# builds / refreshes the scratch project projects/dc_p1 (git-excluded) from the game: the same code, but with the big floors' world (project.cfg and the one-row biomes.csv from dev/p1/: terrain = biomes,
# world = endless, so that the region hook runs). The Orientation's save (world.vxs) is copied once and stays. See GAME.md "Big floors P1".
cd "$(dirname "$0")/.." || exit 1
mkdir -p projects/dc_p1
rsync -a --delete --exclude 'world.vxs*' --exclude 'project.cfg' --exclude 'biomes.csv' --exclude '.state' --exclude '.events' projects/dungeon_crawler/ projects/dc_p1/
[ -f projects/dc_p1/world.vxs ] || cp projects/dungeon_crawler/world.vxs* projects/dc_p1/ 2>/dev/null
cp projects/dungeon_crawler/dev/p1/biomes.csv projects/dc_p1/biomes.csv
cp projects/dungeon_crawler/dev/p1/project.cfg projects/dc_p1/project.cfg
