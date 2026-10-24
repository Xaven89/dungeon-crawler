#!/usr/bin/env python3
"""The room layout grammar (gen/furnish.lua) over many rooms, in the engine's Lua through the MCP (no world is touched): lays out every room of the themes that have a grammar row on the plans of
`RUNS` run numbers x floors, and asserts: no two blocking footprints overlap, nothing in a door band or on a crate's place, no spot inside a footprint or a band, the doors and spots are one region
(contract item 15), every chair within 1.2 m of a table (or the bar), every bookcase on a wall. Prints counts, the time per layout and the largest layout.
usage: tools/furnish_check.py [RUNS=40] [--floors 1,2,3,5] [--themes hall,library,crypt,depot] [--first N]"""
import os, sys, time, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
os.environ.setdefault("VOXELITH", os.path.join(ROOT, "voxelith"))
from voxelith_client import Voxelith
args = [a for a in sys.argv[1:] if not a.startswith("--")]
runs = int(args[0]) if args else 40
def opt(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default
floors = [int(x) for x in opt("--floors", "1,2,3,5").split(",")]
themes = opt("--themes", "hall,library,crypt,depot").split(",")
first = int(opt("--first", "1"))
CHUNK = 6
tl = "{" + ",".join("%s = true" % t for t in themes) + "}"

def lua_code(run, fl, i0, i1, layout):
    return """
local THEMES = %s
local H = cellgen_hash_from(worldgen.hash, %d); local CG = cellgen_make(H)
local plan = CG.plan(0, %d, 'small')
local ri = 0
for _, id in ipairs(plan.order) do
  local info = plan.cells[id]; local r = info.room
  if r and THEMES[info.theme] then
    ri = ri + 1
    if ri > %d and ri <= %d then
      local doors = {}
      for _, d in ipairs({ 'E', 'S', 'W', 'N' }) do local k = info.open[d]; if k and k ~= 'internal' and info.door and info.door[d] then doors[#doors + 1] = { side = d, pos = info.door[d] } end end
      local mk = function(salt) return deco_rng(H, %d, info.ci, info.cj, salt or 1) end
      local lay = %s
      if lay then
        local bad = deco_layout_check(lay, r, doors)
        for _, b in ipairs(bad) do print('V', %d, id, info.theme, b) end
        local tables = {}
        for _, it in ipairs(lay.items) do if it.cat == 'table' or it.id == 'bar' then tables[#tables + 1] = it end end
        for _, it in ipairs(lay.items) do
          if it.cat == 'chair' then
            local ok = false
            for _, t in ipairs(tables) do
              local dx = math.max(t.x0 - it.x1, it.x0 - t.x1, 0); local dz = math.max(t.z0 - it.z1, it.z0 - t.z1, 0)
              if math.sqrt(dx * dx + dz * dz) <= 1.2 then ok = true; break end
            end
            if not ok then print('V', %d, id, info.theme, 'a chair far from every table') end
          elseif it.cat == 'bookcase' then
            local X0, Z0, X1, Z1 = r.x, r.z, r.x + r.w, r.z + r.d
            if not (it.x0 - X0 < 0.1 or X1 - it.x1 < 0.1 or it.z0 - Z0 < 0.1 or Z1 - it.z1 < 0.1) then print('V', %d, id, info.theme, 'a bookcase off the wall') end
          end
        end
        local ops = 0
        local B = { model = function() ops = ops + 1 end, fill = function() ops = ops + 1 end, vbox = function() ops = ops + 1 end, sphere = function() ops = ops + 1 end, pillar = function() ops = ops + 1 end, ring = function() ops = ops + 1 end }
        deco_room(B, info.theme, r, doors, mk, %d)
        local kinds = {}
        for _, sp in ipairs(lay.spots) do kinds[sp.kind] = (kinds[sp.kind] or 0) + 1 end
        if info.theme == 'arena' and not kinds.boss then print('V', %d, id, info.theme, 'an arena without a boss spot') end
        local kt = {}
        for k, n in pairs(kinds) do kt[#kt + 1] = k .. '=' .. n end
        table.sort(kt)
        print('R', info.theme, #lay.items, #lay.spots, ops, %d .. ':' .. id, lay.trimmed, table.concat(kt, ','))
      end
    end
  end
end
print('N', ri)""" % (tl, run, fl, i0, i1, fl, ("deco_layout(info.theme, r, doors, mk, %d)" % fl) if layout else "nil", run, run, run, run, fl, run)

bad_by, examples = collections.Counter(), collections.defaultdict(list)
n_rooms = n_items = n_spots = trimmed = 0
t_lay = t_plan = 0.0
biggest = (0, "")
by_theme = collections.defaultdict(lambda: [0, 0, 0, 0, 0])
kinds_by = collections.defaultdict(collections.Counter)
rooms_trimmed = 0
t0 = time.time()
with Voxelith(["--project", "projects/dungeon_crawler", "--threads", "3"]) as v:
    v.step(5)
    for fl in floors:
        for run in range(first, first + runs):
            i0 = 0
            while True:
                tb = time.time(); out = v.lua(lua_code(run, fl, i0, i0 + CHUNK, True), ticks=0)["output"]; t_lay += time.time() - tb
                tb = time.time(); v.lua(lua_code(run, fl, i0, i0 + CHUNK, False), ticks=0); t_plan += time.time() - tb
                total = 0
                for line in out:
                    p = line.split("\t")
                    if p[0] == "N": total = int(p[1])
                    elif p[0] == "V":
                        bad_by[(p[3], p[4])] += 1
                        if len(examples[(p[3], p[4])]) < 2: examples[(p[3], p[4])].append("floor %d run %s %s" % (fl, p[1], p[2]))
                    elif p[0] == "R":
                        n_rooms += 1; n_items += int(p[2]); n_spots += int(p[3])
                        bt = by_theme[p[1]]; bt[0] += 1; bt[1] += int(p[2]); bt[2] += int(p[3]); bt[3] += int(p[4]); bt[4] = max(bt[4], int(p[4]))
                        trimmed += int(p[6]) if len(p) > 6 else 0
                        if len(p) > 6 and int(p[6]) > 0: rooms_trimmed += 1
                        if len(p) > 7:
                            for kv in p[7].split(','):
                                if kv: k_, n_ = kv.split('='); kinds_by[p[1]][k_] += int(n_)
                        if int(p[2]) > biggest[0]: biggest = (int(p[2]), "floor %d %s" % (fl, p[5]))
                i0 += CHUNK
                if i0 >= total: break
print("floors %s, runs %d..%d, themes %s: %d rooms, %d items, %d spots, layout + checks + flood: %.2f ms per room (plan subtracted), largest %d items (%s), %.0f s" % (floors, first, first + runs - 1, themes, n_rooms, n_items, n_spots,
      (t_lay - t_plan) * 1000 / max(1, n_rooms), biggest[0], biggest[1], time.time() - t0))
for t, (n, i, s, o, om) in sorted(by_theme.items()): print("  %-8s %4d rooms  %.1f items  %.1f spots per room  %.0f B ops per room (max %d)" % (t, n, i / n, s / n, o / n, om))
print("items removed by the flood: %d in %d rooms" % (trimmed, rooms_trimmed))
for t in sorted(kinds_by): print("  spots of %-8s %s" % (t, dict(kinds_by[t])))
print("violations:", sum(bad_by.values()))
for k, c in sorted(bad_by.items()): print("  %-8s %-50s %4d  e.g. %s" % (k[0], k[1], c, "; ".join(examples[k])))
