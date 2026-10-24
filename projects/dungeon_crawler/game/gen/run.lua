-- gen/run: a run is a seed. State (`G.state.run`): { mode = "orientation" | "gen", seed, floor, started }.
-- The Orientation is the hand built first floor (the old slice); the generated floors (gen/floor.lua) follow it, or the run starts on one ("skip the orientation").
-- A new run resets the character (the achievements stay: they are the player's, not the run's), builds the volume for it and goes to the class choice.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local R = {}
G.run = R
local floor = math.floor

function R.cur() return G.state and G.state.run end
function R.is_gen() local r = R.cur(); return r ~= nil and r.mode == "gen" end
function R.floor_no() local r = R.cur(); return r and r.floor or 1 end

-- a save from before the seeds: it is an Orientation run
function R.ensure()
    local s = G.state
    if not s.run then s.run = { mode = "orientation", seed = G.hash_salt, floor = 1, started = 0 } end
end

-- a seed from what the player does (there is no clock in the engine: the tick and the mouse are the entropy; the action is logged, so a replay gets the same number)
function R.entropy_seed(a, b)
    local h = math.floor(G.hash(time.tick() % 100000, math.floor(a or 0), math.floor(b or 0)) * 899999) + 100000
    return h
end

local function reset_state()
    local s = G.state
    local keep_ach, keep_n = s.ach, s.ach_count
    local flags = {}
    for k, v in pairs(s.flags or {}) do if k:sub(1, 4) == "bus_" or k == "flat_numbers" then flags[k] = v end end
    for k in pairs(s) do s[k] = nil end
    for k, v in pairs(G.new_state()) do s[k] = v end
    s.ach, s.ach_count, s.flags = keep_ach or {}, keep_n or 0, flags
    G.items.clear()
    G.announcer.counters = {}
    G.player.dead = false
end

-- the floors of a run, in order: the Orientation counts as floor 1 (band 0); 4 (the transit floor) is skipped until its own plan exists; the run ends after 8
R.FLOORS = { 1, 2, 3, 5, 6, 7, 8 }
function R.next_floor(n)
    for _, f in ipairs(R.FLOORS) do if f > n then return f end end
    return nil
end

-- the run number of a typed seed (any number or words: gen/run seed_of in hud_run): 0 .. 16,777,215. The run number is the engine's run seed (worldgen.run_seed, E7): the floors of every run differ,
-- the world's own seed stays (tools/play.sh new [SEED] is a new WORLD, a new run is a new run number inside the same world)
function R.run_of(seed) return floor(seed or 0) % 16777216 end
function R.can_new_run() return worldgen.run_seed ~= nil end

-- the world of a run: every band the big floors may have made goes back to the generator and (when the Orientation was played) its volume too, then the run number is set; all in one tick
function R.reset_world(no, orient)
    for n = 1, 8 do world.reset_region(-1024, 0, (n * 32 + 1) * 512, 19 * 512, 700, (n * 32 + 21) * 512 - 1) end
    if orient then world.reset_region(1072 - 64, 0, 848 - 64, 1072 + 130 * 16 + 64, 420, 848 + 160 * 16 + 64) end
    if no ~= worldgen.run_seed() then worldgen.run_seed(no) end
end

-- the run screen's answer: `seed` = a number: the run number (when the engine can set one), `skip` = start on a generated floor instead of the Orientation
function R.start(seed, skip, diff)
    if G.screen ~= "run" then return end
    local can = R.can_new_run()
    local no = can and R.run_of(seed) or nil
    reset_state()
    G.state.run = { mode = skip and "gen" or "orientation", seed = (G.floorgen.world_seed() * 31 + (no or 0)) % 2147483629, floor = 1, started = time.tick(), diff = diff or "normal" }
    G.state.run_no = no or 0
    G.state.checkpoint = "lobby"
    local F = G.floorgen
    local orient_again = (not skip) and project.fetch("orient_used", false)
    if can and (no ~= F.run_no() or F.touched or orient_again) then
        -- a new run in the same session: the old floors go, in this tick (before any cell can come alive on old voxels), then the veil while the world is made again
        G.screen = "loading"
        F.leave_all()
        R.reset_world(no, orient_again)
        F.touched = false
        G.gen.track.teardown("orientation"); G.gen.track.scope = "orientation"
        G.rebuilding = orient_again or false
        G.world.build()
        G.rebuilding = false
        G.world.populate()
        if not skip then project.store("orient_used", true) end
        G.world.respawn_orientation()
        after(150, function() if G.screen == "loading" then G.screen = "class" end end)
        return
    end
    if not skip then project.store("orient_used", true) end
    if not skip and G.floorgen.active then
        G.screen = "loading"
        G.floorgen.restore_authored(function()
            G.world.respawn_orientation()
            G.screen = "class"
        end)
    else
        G.screen = "class"
    end
end

-- the class was chosen (player.pick_class): a generated run starts on its first floor
function R.after_class()
    local run = R.cur()
    if run and run.mode == "gen" and not G.floorgen.job then R.begin_floor(run.floor) end
end

function R.begin_floor(n)
    local run = R.cur()
    run.floor = n
    run.fclock, run.fstage, run.collapsed = 0, 0, nil
    G.save()
    G.screen = "loading"
    G.safe = false
    G.current_room = nil
    G.floorgen.enter(n, function() R.floor_ready(n) end)
end

function R.floor_ready(n)
    local F = G.floorgen
    if n >= 3 then G.announcer.award("deep_three") end
    if n >= 5 then G.announcer.award("deep_five") end
    if n >= 3 and G.contracts.hardcore() then G.announcer.award("hardcore_two") end
    local p = F.layout
    G.state.checkpoint = p.start
    G.state.flags["visited_" .. p.start] = true
    G.world.last_safe = nil
    G.frozen_at = nil
    G.screen = nil
    G.announcer.say_key("floor.arrive", { prio = 2 }, n)
    for _, id in ipairs(p.rules or {}) do G.announcer.say_key("rule." .. id, { prio = 0 }) end
    if G.companion and G.companion.id then G.companion.respawn() end
    if G.state.ally then G.ally.respawn() end
    G.show.floor_begin()
    if n > 1 then G.contracts.on_new_floor() end
    G.show.deliver(p.rooms[p.start])
    G.save()
    after(150, function() if G.screen == nil and not G.player.dead then G.contracts.open(G.run.cur().seed, n) end end)
end

-- the stairs down (a free stairwell, or the end screen of the Orientation)
function R.descend(confirmed)
    local run = R.cur()
    if not run or G.screen == "loading" then return end
    if not confirmed and run.mode == "gen" then G.show.open_recap(); return end        -- the recap first; its button comes back here
    G.screen = nil
    if run.early_descent and G.floorgen.active then G.floorgen.early_penalty() end
    run.early_descent = nil
    if run.mode == "orientation" then run.mode = "gen" end
    local nxt = R.next_floor(run.floor)
    if not nxt then G.finish_floor(); return end
    R.begin_floor(nxt)
end

-- on_start of a saved gen run: the plan again (the voxels are the hook's, the things come alive around the player)
function R.resume()
    local run = R.cur()
    if run and run.mode == "gen" and run.floor then
        G.floorgen.load(run.floor)
        if G.state.ally then after(60, function() G.ally.respawn() end) end
        if G.state.run_over then G.screen = "runover"; G.run.over = { src = G.state.run_over_src or "?", floor = run.floor, seed = run.seed } end
        return true
    end
    return false
end

-- from the settings: leave this run and pick another (the seed screen)
function R.open_menu()
    if G.screen ~= "bag" or G.player.dead then return end
    G.screen = "run"
    G.hud.seed_text = nil
end

-- the run is over (a hardcore death): the summary, then the way into a new one
function R.end_run(src)
    G.player.dead = false
    G.state.run_over, G.state.run_over_src = true, tostring(src or "something")
    G.save()
    G.screen = "runover"
    G.run.over = { src = tostring(src or "something"), floor = R.floor_no(), seed = (R.cur() or {}).seed }
end
function R.new_after_over() if G.screen == "runover" then G.screen = "run"; G.hud.seed_text = nil end end

-- the difficulty of the run: enemy health / damage and the audience
R.DIFF = { easy = { hp = 0.8, dmg = 0.75, views = 0.9 }, normal = { hp = 1, dmg = 1, views = 1 }, hard = { hp = 1.35, dmg = 1.3, views = 1.25 } }
function R.diff() local r = R.cur(); return R.DIFF[(r and r.diff) or "normal"] or R.DIFF.normal end
