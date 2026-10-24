-- gen/trains: the cars of the Iron Tangle (floor 4): one `events.train` per line (gen/transit.lua `transit_lines`), a flat deck 14 x 3.6 m that lies in the track bed flush with the platforms. The node moves
-- the body; the player standing on it is carried (R1), the game puts the commuters on and takes them off at the stops (T4).
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local T = {}
G.gen.trains = T
local floor = math.floor

T.cars = {}                  -- line name -> { id, body, line }
T.pending_reset = false
local DECK = { red = "carpet", yellow = "gold", blue = "obsidian" }

-- the cars of the floor (made when the floor is entered or loaded, in the floor's scope: taken away with it)
function T.enter(P)
    T.cars = {}
    local car = transit_const().car
    for _, line in ipairs(transit_lines()) do
        local pts = {}
        for i, p in ipairs(line.points) do pts[i] = { G.wx(p[1]), G.wy(line.level * transit_const().level_m), G.wz(p[2]) } end
        local id = events.train{ name = "iron_" .. line.name, body = { width = floor(car.width * 16 + 0.5), thickness = floor(car.thickness * 16 + 0.5), length = floor(car.len * 16 + 0.5), material = DECK[line.name] },
                                 track = pts, closed = line.closed, speed = line.speed, accel = car.accel, stops = line.stops, end_seconds = 20, start_on = true }
        T.cars[line.name] = { id = id, body = events.train_body(id), line = line }
        events.on(id, "stopped", function(e) T.on_stopped(line.name, e) end)
        events.on(id, "departing", function(e) T.on_departing(line.name, e) end)
    end
    T.pending_reset = true
end

-- every car starts over at its first stop when the player can act (the veil and the contract screen are over): the first lap begins with the Red car standing at HUB S
function T.tick(t)
    if T.pending_reset and G.state.class and not G.screen and not G.player.dead then
        T.pending_reset = false
        for _, c in pairs(T.cars) do events.command(c.id, "reset") end
    end
end

function T.on_stopped(name, e) end
function T.on_departing(name, e) end

-- where a car is (world metres of the middle of its deck) or nil
function T.where(name)
    local c = T.cars[name]
    if not c then return nil end
    local x, y, z, ok = body.pos(c.body)
    if not ok then return nil end
    return x, y, z
end
