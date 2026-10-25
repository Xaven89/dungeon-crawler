-- shop: the vending machine of the stairwell (buy) and the sale of anything from the bag (right click in the inventory screen).
Game = Game or {}
local G = Game
local S = {}
G.shop = S

S.stock = {
    { id = "bandage", price = 9 }, { id = "smoothie", price = 18 }, { id = "energy", price = 18 }, { id = "sushi", price = 48 },
    { id = "firecracker", price = 24 }, { id = "cheese", price = 70 }, { id = "hivis", price = 70 }, { id = "dagger_cd", price = 85 },
}

function S.open() G.screen = "shop"; G.sfx.play("ui_open"); G.announcer.say_key("shop.enter", { key = "shop_enter", cooldown = 5000 }) end

function S.buy(i)
    local e = S.stock[i]
    local s = G.state
    if not e then return false end
    local price = math.floor(e.price * G.contracts.shop_price() + 0.5)
    if s.gold < price then G.announcer.say_key("shop.broke", { prio = 1, key = "broke", cooldown = 600 }); G.sfx.play("hurt", nil, nil, nil, 0.375, 1.4); return false end
    if not G.items.add(e.id, 1) then G.player.popup("BAG FULL", "#ff8080"); return false end
    s.gold = s.gold - price
    G.sfx.play("coin")
    G.announcer.say_key("shop.buy", { key = "shop_buy", cooldown = 900 })
    G.announcer.award("shopper")
    G.save()
    return true
end

function S.sell(id)
    local d = G.items.defs[id]
    if not d or d.kind == "quest" or G.items.count(id) < 1 then return false end
    local price = math.max(1, math.floor(d.value / 2 * G.contracts.sell_price()))
    G.items.remove(id, 1)
    G.state.gold = G.state.gold + price
    G.player.log("sold for " .. price .. " gold", "#ffd24a")
    G.sfx.play("coin")
    G.save()
    return true
end
