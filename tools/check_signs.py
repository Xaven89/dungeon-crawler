#!/usr/bin/env python3
"""Looks in front of every voxel sign of THE DESCENT (Game.texts, written by game/core.lua G.text): from the middle of each letter column a ray goes 3.5 m along the way the text faces; a column whose ray hits
something solid before that (a pillar, a pipe, a sconce, a beam) is hidden from straight ahead. Prints the signs with hidden columns and where. usage: tools/check_signs.py (starts its own MCP server)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); os.environ.setdefault("VOXELITH", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "voxelith"))
from voxelith_client import Voxelith
CODE = """local G = Game
local D = { ['+z'] = {0, 1}, ['-z'] = {0, -1}, ['+x'] = {1, 0}, ['-x'] = {-1, 0} }
for _, t in ipairs(G.texts) do
  local f = D[t.facing]
  local along = { -f[2], f[1] }                 -- the direction of the line of text (a unit step)
  local chars = #t.text
  local width = (chars * 4 * t.size * t.spacing - t.spacing) / 16     -- metres (a 5 x 7 font: about 6 voxels per character at size 1: use 6)
  width = chars * 6 * t.size / 16
  local hidden, total, first = 0, 0, nil
  local h = 7 * t.size / 16 / 2
  local n = math.floor(width / 0.25)
  for i = 0, n do
    local u = i * 0.25
    local px = t.x + (t.facing:sub(2) == 'z' and u or 0) * 1 + (t.facing:sub(2) == 'x' and 0 or 0)
    local pz = t.z
    local qx, qz
    if t.facing:sub(2) == 'z' then px, pz = t.x + u, t.z else px, pz = t.x, t.z + u end
    total = total + 1
    local blocked = false
    for d = 0.15, 3.5, 0.1 do
      local cx, cz = px + f[1] * d, pz + f[2] * d
      if world.solid(G.wx(cx), G.wy(t.y + h), G.wz(cz)) then blocked = true; break end
    end
    if blocked then hidden = hidden + 1; first = first or u end
  end
  if hidden > 0 then print(string.format('%-60s x%.1f y%.1f z%.1f %s  hidden columns %d of %d, first at +%.2f m', t.text:sub(1, 40), t.x, t.y, t.z, t.facing, hidden, total, first or 0)) end
end
print('done, signs: ' .. #G.texts)"""
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3"]) as v:
    v.step(300)
    print("\n".join(v.lua(CODE, ticks=0)["output"]))
