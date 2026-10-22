-- The inventory test: a screen with a bag, a hotbar, tooltips, drag and drop (the pointer, or Enter / A and the arrows), stack splitting, a filter and sort; contents saved with the project.
-- Keys: I opens / closes, Escape closes, 1..8 select a hotbar slot, G gives a random item, H clears the bag, N reads the selected item aloud.
include("engine/ui_kit.lua")
include("engine/inventory.lua")

local items = {
    apple = { name = "Apple",   color = "#cc3333", max_stack = 16, desc = "Restores a little health." },
    stone = { name = "Stone",   color = "#8a8f99", max_stack = 99, desc = "A building block." },
    wood  = { name = "Wood",    color = "#a8773c", max_stack = 99, desc = "Planks for a shelter." },
    torch = { name = "Torch",   color = "#f0a030", max_stack = 20, desc = "Lights a dark place." },
    key   = { name = "Key",     color = "#e8d040", max_stack = 1,  desc = "Opens one door." },
    sword = { name = "Sword",   color = "#c0c8d8", max_stack = 1,  desc = "Sharp." },
    gem   = { name = "Gem",     color = "#40c0e0", max_stack = 8,  desc = "Worth a lot to the right person." },
}
local order = { "apple", "stone", "wood", "torch", "key", "sword", "gem" }

inv = inventory.new{ name = "player", slots = 24, hotbar = 8, columns = 6, items = items }

function on_start()
    inventory.load(inv)
    local total = 0
    for _, it in ipairs(items_list or {}) do total = total + inventory.count(inv, it) end
    for _, id in ipairs(order) do total = total + inventory.count(inv, id) end
    if total == 0 then -- a first start (or an emptied bag that was saved empty: give the starter set again)
        inventory.add(inv, "apple", 5); inventory.add(inv, "stone", 40); inventory.add(inv, "wood", 12)
        inventory.add(inv, "torch", 3); inventory.add(inv, "sword", 1); inventory.add(inv, "gem", 2)
        inventory.save(inv)
    end
end

-- the game's own rules: these run as logged actions (a key through ui.run), not in on_hud
function give_random(seed)
    local id = order[(seed % #order) + 1]
    local left = inventory.add(inv, id, 1 + (seed % 3))
    inventory.save(inv)
    print("gave " .. id .. (left > 0 and (" (" .. left .. " did not fit)") or ""))
end

function clear_bag()
    for i = 1, inv.bag_n do inv.bag[i] = false end
    inventory.save(inv)
end

local gives = 0
function on_hud(dt)
    inventory.hud(inv, dt)
    local input = ui.input()
    if input and input.pressed then
        if input.pressed.g then gives = gives + 1; ui.run("give_random(" .. gives .. ")") end
        if input.pressed.h then ui.run("clear_bag()") end
    end
    local sw, sh = ui.size()
    local sel = inventory.selected_item(inv)
    local d = sel and items[sel.id]
    ui.text(20, sh - 40, d and ("holding: " .. d.name .. (sel.count > 1 and (" x" .. sel.count) or "")) or "holding nothing", { size = 22, color = "#e8ecf4", shadow = true })
    ui.text(20, 20, "I inventory   1-8 hotbar   G give   H clear", { size = 20, color = "#9aa3b5", shadow = true })
end
