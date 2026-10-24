#!/bin/bash
# Starts THE DESCENT (windowed). The run is the world: its seed is the world's seed.
#   tools/play.sh                 continue the saved run (its own seed)
#   tools/play.sh new [SEED]      forget the saved run and start a new world: SEED is a number or any words (the same words are the same dungeon on every machine); without it a random one
cd "$(dirname "$0")/.."
P=projects/dungeon_crawler
SEEDARG=()
if [ "$1" = "new" ]; then
    rm -rf $P/world.vxs* $P/.state $P/.events $P/.prefabs
    S="$2"
    if [ -z "$S" ]; then S=$(( (RANDOM * 32768 + RANDOM) % 899999 + 100000 )); fi
    if ! [[ "$S" =~ ^[0-9]+$ ]]; then S=$(printf '%s' "$S" | cksum | cut -d' ' -f1); fi
    SEEDARG=(--seed "$S")
    echo "new run, seed $S"
    shift; [ -n "$1" ] && shift
fi
exec ./voxelith --manual --project $P --hud 0 --threads 3 "${SEEDARG[@]}" "$@"
