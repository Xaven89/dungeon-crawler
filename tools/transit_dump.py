#!/usr/bin/env python3
"""ASCII of the Iron Tangle (floor 4): the cells, their letters, doors and the tracks. usage: tools/transit_dump.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3"]) as v:
    v.step(5)
    out = v.lua("""
for cj = 0, 4 do local row = {}
  for ci = 0, 4 do local i = transit_cell_info(ci, cj); local o = {}
    for _, d in ipairs({ 'N', 'E', 'S', 'W' }) do if i.open[d] then o[#o + 1] = d .. ':' .. i.open[d]:sub(1, 3) .. i.door[d] end end
    row[#row + 1] = string.format('%s %-9s %-8s y%d %s', i.code, i.theme, i.role, i.room.y, table.concat(o, ' ')) end
  print(table.concat(row, ' | ')) end
for _, l in ipairs(transit_lines()) do local t = {}; for k, s in ipairs(l.stops) do t[#t + 1] = s[1] .. '/' .. s[2] .. 's' end
  print(l.name, l.closed and 'loop' or 'open', #l.points, 'waypoints, level', l.level, 'stops', table.concat(t, ' ')) end""", ticks=0)["output"]
    print("\n".join(out))
