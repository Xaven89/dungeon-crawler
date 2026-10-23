-- gen/contracts: at every arrival the show offers three sponsor contracts (from the seed): each is a deal, a boon and a price. Signed ones stay for the run. One of them is the hardcore one:
-- "Exclusive Broadcast Rights" doubles the audience and ends the run when you die.
Game = Game or {}
local G = Game
G.gen = G.gen or {}
local C = {}
G.contracts = C
local floor, max, min = math.floor, math.max, math.min

C.defs = {
    hazard_pay        = { gold = 0.30, edmg = 0.15 },
    product_placement = { spectacle = 0.50, hp = -0.15 },
    union_dues        = { clear_heal = 0.35, floor_tax = 0.15 },
    fine_print        = { stats = { str = 3, con = -3 } },
    exclusive         = { spectacle = 0.50, viewers = 1.0, hardcore = true },
    night_owl         = { dmg = 0.25, mp = -0.5 },
    bulk_discount     = { shop = -0.30, sell = -0.5 },
    glass_cannon      = { dmg = 0.40, hp = -0.25 },
}
C.order = { "hazard_pay", "product_placement", "union_dues", "fine_print", "exclusive", "night_owl", "bulk_discount", "glass_cannon" }

function C.held() local s = G.state; s.contracts = s.contracts or {}; return s.contracts end
function C.has(id) for _, h in ipairs(C.held()) do if h == id then return true end end return false end

local function sum(key)
    local v = 0
    for _, id in ipairs(C.held()) do local d = C.defs[id]; if d and d[key] then v = v + d[key] end end
    return v
end
function C.gold() return sum("gold") end
function C.edmg() return 1 + sum("edmg") end
function C.dmg() return 1 + sum("dmg") end
function C.hp() return 1 + sum("hp") end
function C.mp() return 1 + sum("mp") end
function C.spectacle() return 1 + sum("spectacle") end
function C.viewers() return 1 + sum("viewers") end
function C.shop_price() return 1 + sum("shop") end
function C.sell_price() return 1 + sum("sell") end
function C.stat(name)
    local v = 0
    for _, id in ipairs(C.held()) do local d = C.defs[id]; if d and d.stats and d.stats[name] then v = v + d.stats[name] end end
    return v
end
function C.hardcore() return C.has("exclusive") end

-- what is on offer at this arrival: three not yet signed, picked from the seed
function C.offer(seed, floor_n)
    local pool = {}
    for _, id in ipairs(C.order) do if not C.has(id) then pool[#pool + 1] = id end end
    local r = G.gen.layout.make_rng(seed, floor_n, 909)
    r.shuffle(pool)
    local out = {}
    for i = 1, min(3, #pool) do out[i] = pool[i] end
    return out
end

function C.open(seed, floor_n)
    local offer = C.offer(seed, floor_n)
    if #offer == 0 then return end
    C.offered = offer
    G.screen = "contracts"
    G.announcer.say_key("contract.offer", { prio = 1 })
end

function C.sign(id)
    if G.screen ~= "contracts" then return end
    if id and C.defs[id] then
        local h = C.held(); h[#h + 1] = id
        G.state.hp = min(G.state.hp, G.player.max_hp())
        G.announcer.say_key("contract.signed", { prio = 1 }, tr("contract." .. id .. ".name"))
        G.sfx.play("achievement", nil, nil, nil, 0.5, 0.8)
        if #h >= 3 then G.announcer.award("contractor") end
        if G.show then G.show.score(15, nil) end
    else
        G.state.gold = G.state.gold + 40
        G.announcer.say_key("contract.declined", { prio = 1 })
    end
    G.screen = nil
    G.save()
end

-- the effects that are not just numbers
function C.on_room_cleared()
    local f = sum("clear_heal")
    if f > 0 then G.player.heal(floor(G.player.max_hp() * f)) end
end
function C.on_new_floor()
    local t = sum("floor_tax")
    if t > 0 then
        local lost = floor(G.state.gold * t)
        G.state.gold = G.state.gold - lost
        if lost > 0 then G.player.log("-" .. lost .. " gold (union dues)", "#ff9a7a") end
    end
end
