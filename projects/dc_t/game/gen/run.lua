-- gen/run: a run is a seed. State (`G.state.run`): { mode = "orientation" | "gen", seed, floor, started }.
-- The Orientation is the hand built first floor (the old slice); the generated floors (gen/floor.lua) follow it, or the run starts on one ("skip the orientation").
-- A new run resets the character (the achievements stay: they are the player's, not the run's), builds the volume for it and goes to the class choice.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local R = {}
G.run = R

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

-- the run screen's answer: `skip` = start on a generated floor instead of the Orientation
function R.start(seed, skip)
    if G.screen ~= "run" then return end
    reset_state()
    G.state.run = { mode = skip and "gen" or "orientation", seed = seed, floor = 1, started = time.tick() }
    G.state.checkpoint = "lobby"
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

-- the class was chosen (player.pick_class): a generated run starts building its first floor
function R.after_class()
    local run = R.cur()
    if run and run.mode == "gen" and not G.floorgen.job then R.begin_floor(run.floor) end
end

function R.begin_floor(n)
    local run = R.cur()
    run.floor = n
    run.building = n                      -- (saved with the world: a start that finds this knows the build was cut off)
    G.save()
    G.screen = "loading"
    G.safe = false
    G.current_room = nil
    G.floorgen.start(run.seed, n, function() R.floor_ready(n) end)
end

function R.floor_ready(n)
    local F = G.floorgen
    R.cur().building = nil
    if n >= 3 then G.announcer.award("deep_three") end
    if n >= 5 then G.announcer.award("deep_five") end
    if n >= 3 and G.contracts.hardcore() then G.announcer.award("hardcore_two") end
    local p = F.layout
    local r = p.rooms[p.start]
    G.state.checkpoint = p.start
    G.state.flags["visited_" .. p.start] = true
    G.world.last_safe = nil
    player.teleport(G.mx(r.x + r.w / 2), G.my(0.1), G.mz(r.z + r.d / 2))
    G.screen = nil
    G.announcer.say_key("floor.arrive", { prio = 2 }, n)
    for _, id in ipairs(p.rules or {}) do G.announcer.say_key("rule." .. id, { prio = 0 }) end
    if G.companion and G.companion.id then G.companion.respawn() end
    if G.state.ally then G.ally.respawn() end
    G.show.floor_begin()
    if n > 1 then G.contracts.on_new_floor() end
    G.show.deliver(r)
    G.save()
    after(150, function() if G.screen == nil and not G.player.dead then G.contracts.open(G.run.cur().seed, n) end end)
end

-- the stairs down (the button in the exit stairwell, or the end screen of the Orientation)
function R.descend(confirmed)
    local run = R.cur()
    if not run or G.screen == "loading" then return end
    if not confirmed and run.mode == "gen" then G.show.open_recap(); return end        -- the recap first; its button comes back here
    G.screen = nil
    if run.mode == "orientation" then run.mode = "gen" end
    R.begin_floor(run.floor + 1)
end

-- on_start of a saved gen run: the plan again, the things again (the voxels are in the world save)
function R.resume()
    local run = R.cur()
    if run and run.mode == "gen" and run.floor then
        if run.building then
            -- the game was closed while the floor was being built: the world holds half of it. Wipe everything and build it again.
            G.floorgen.layout, G.floorgen.active = nil, false
            G.world.populate_list = G.world.populate_list or {}
            after(30, function() R.begin_floor(run.building) end)
            return true
        end
        G.floorgen.load(run.seed, run.floor)
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
