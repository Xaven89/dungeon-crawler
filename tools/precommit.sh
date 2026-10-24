#!/bin/bash
# The checks of the big floors in one script (run before a commit that touches game/gen/ or the hook; `tools/precommit.sh --quick` for the fast ones):
#   1. the project loads (voxelith --check-project)
#   2. the plan contract (items 1-14) over many seeds and floors (tools/plan_check.py)
#   3. the walkability of the shells by the engine's flood fill, a fresh world per seed (tools/p1_validate.py) on floors 1, 2, 3 and 5
# exit 0 = all good. The soak (tools/p5_soak.py: bot runs with replay hashes) takes an hour: run it before a release, not before a commit.
cd "$(dirname "$0")/.." || exit 1
QUICK=0; [ "$1" = "--quick" ] && QUICK=1
fail=0
./voxelith --check-project projects/dungeon_crawler 2>&1 | grep -q "^0 error(s)" || { echo "check-project FAILED"; fail=1; }
N=300; [ $QUICK = 1 ] && N=60
python3 tools/plan_check.py $N --floors 1,2,3,4,5,6,7,8 | tee /tmp/precommit_plan.txt | grep -E "^violations: 0$" >/dev/null || { echo "plan_check FAILED"; tail -12 /tmp/precommit_plan.txt; fail=1; }
tools/p1_sync.sh
SEEDS="1 2"; [ $QUICK = 1 ] && SEEDS="1"
for f in 1 2 3 5; do
    python3 tools/p1_validate.py $SEEDS --floor $f | tee /tmp/precommit_validate_$f.txt | grep -E "^problems: 0$" >/dev/null || { echo "p1_validate floor $f FAILED"; tail -8 /tmp/precommit_validate_$f.txt; fail=1; }
done
# the ground cover of the dungeon (projects/dungeon_crawler/foliage.csv): no row but the meadow's and the moss (0.6) may be denser than 0.3 (a test value must not ship)
python3 - <<'PY' || { echo "foliage.csv FAILED"; fail=1; }
import sys
bad = []
for l in open("projects/dungeon_crawler/foliage.csv"):
    if l.startswith("#") or l.startswith("@") or not l.strip(): continue
    f = l.split(",")
    if f[0] != "grass" and float(f[3]) > {"moss": 0.6}.get(f[0], 0.3): bad.append((f[0], f[3]))
if bad: print("foliage.csv: density above 0.3:", bad); sys.exit(1)
PY
[ $fail = 0 ] && echo "precommit: all good" || echo "precommit: FAILED"
exit $fail
