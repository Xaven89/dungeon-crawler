-- A sample inventory built on the widget set (docs/UI_KIT.md): include("engine/ui_kit.lua") then include("engine/inventory.lua") defines the global `inventory`.
--
-- The split the engine recommends: the GAME owns the rules and the data (what an item is, stack sizes, who may carry what: this file is a starting point to copy and change); the ENGINE owns the
-- widgets (uikit: slots, drag and drop, tooltips, focus, the pad). Everything that changes the inventory runs as a logged action (`ui.run(...)`: on_hud only draws and reads), so a replay and a
-- networked session do the same, and the contents are saved with the project (`project.store`).
--
--   local inv = inventory.new{ name = "player", slots = 24, hotbar = 8, items = {
--       apple = { name = "Apple",  color = "#cc3333", max_stack = 16, desc = "Restores a little health." },
--       stone = { name = "Stone",  color = "#8a8f99", max_stack = 99 } } }
--   inventory.add(inv, "apple", 5)            -- returns what did not fit
--   function on_hud(dt) inventory.hud(inv, dt) end      -- the hotbar always; the screen with the I key (inventory.toggle) or inv.open = true
--
-- In the game's own rules (on_tick, events, buttons) use inventory.count / add / remove / selected_item. The screen's moves arrive through inventory.apply_move (a global call made by ui.run).
inventory = { all = {} }
local I = inventory

local function copy_item(it) local c = {}; for k, v in pairs(it) do c[k] = v end; return c end

function I.new(def)
    local inv = {
        name = def.name or "player", defs = def.items or {}, bag_n = def.slots or 24, hotbar_n = def.hotbar or 8, cols = def.columns or 6,
        bag = {}, hotbar = {}, selected = 1, open = false, filter = "", sort_by = "name",
    }
    for i = 1, inv.bag_n do inv.bag[i] = false end
    for i = 1, inv.hotbar_n do inv.hotbar[i] = false end
    I.all[inv.name] = inv
    return inv
end

local function max_stack(inv, item)
    local d = inv.defs[item.id]
    return d and d.max_stack or 99
end

local function each_slot(inv)
    local n = 0
    return function()
        n = n + 1
        if n <= inv.hotbar_n then return inv.hotbar, n end
        if n <= inv.hotbar_n + inv.bag_n then return inv.bag, n - inv.hotbar_n end
    end
end

function I.count(inv, id)
    local c = 0
    for arr, i in each_slot(inv) do if arr[i] and arr[i].id == id then c = c + (arr[i].count or 1) end end
    return c
end

-- adds up to n of an item (stacks first, then empty slots: the hotbar before the bag); returns what did not fit
function I.add(inv, id, n)
    n = n or 1
    local def = inv.defs[id]
    if not def then error("inventory.add: unknown item '" .. tostring(id) .. "'") end
    local cap = def.max_stack or 99
    for arr, i in each_slot(inv) do
        local s = arr[i]
        if n > 0 and s and s.id == id and (s.count or 1) < cap then
            local mv = math.min(cap - (s.count or 1), n)
            s.count = (s.count or 1) + mv
            n = n - mv
        end
    end
    for arr, i in each_slot(inv) do
        if n > 0 and not arr[i] then
            local mv = math.min(cap, n)
            arr[i] = { id = id, count = mv }
            n = n - mv
        end
    end
    return n
end

-- removes up to n; returns how many were taken
function I.remove(inv, id, n)
    n = n or 1
    local taken = 0
    for arr, i in each_slot(inv) do
        local s = arr[i]
        if taken < n and s and s.id == id then
            local mv = math.min(n - taken, s.count or 1)
            s.count = (s.count or 1) - mv
            taken = taken + mv
            if s.count <= 0 then arr[i] = false end
        end
    end
    return taken
end

function I.selected_item(inv) return inv.hotbar[inv.selected] or nil end

-- the grid an id names: "bag" or "hotbar"
local function grid(inv, name) return name == "hotbar" and inv.hotbar or inv.bag end

-- A move the screen asked for (arrives through ui.run: a logged action). The standard stack rules of uikit.move_stack with this inventory's stack sizes.
function I.apply_move(name, from_grid, from, to_grid, to, split)
    local inv = I.all[name]
    if not inv then return false end
    local ok = uikit.move_stack({ items_from = grid(inv, from_grid), items_to = grid(inv, to_grid), from = from, to = to, split = split ~= "" and split or nil }, function(it) return max_stack(inv, it) end)
    if ok then I.save(inv) end
    return ok
end

function I.select(name, n)
    local inv = I.all[name]
    if inv and n >= 1 and n <= inv.hotbar_n then inv.selected = n end
end

function I.sort(name)
    local inv = I.all[name]
    if not inv then return end
    local items = {}
    for _, s in ipairs(inv.bag) do if s then items[#items + 1] = s end end
    local def = inv.defs
    table.sort(items, function(a, b)
        local na, nb = (def[a.id] and def[a.id].name or a.id), (def[b.id] and def[b.id].name or b.id)
        if na ~= nb then return na < nb end
        return (a.count or 1) > (b.count or 1)
    end)
    for i = 1, inv.bag_n do inv.bag[i] = items[i] or false end
    I.save(inv)
end

-- saving (project.store: a table of plain values; written beside the world save)
function I.to_table(inv)
    local function pack(arr) local out = {}; for i = 1, #arr do local s = arr[i]; out[i] = s and { id = s.id, count = s.count } or false end; return out end
    return { bag = pack(inv.bag), hotbar = pack(inv.hotbar), selected = inv.selected }
end

function I.from_table(inv, t)
    if type(t) ~= "table" then return end
    local function unpack_into(arr, src, n)
        for i = 1, n do
            local s = src and src[i]
            arr[i] = (type(s) == "table" and inv.defs[s.id]) and { id = s.id, count = math.max(1, math.floor(s.count or 1)) } or false
        end
    end
    unpack_into(inv.bag, t.bag, inv.bag_n)
    unpack_into(inv.hotbar, t.hotbar, inv.hotbar_n)
    inv.selected = math.max(1, math.min(inv.hotbar_n, math.floor(t.selected or 1)))
end

function I.save(inv)
    if project and project.store then project.store("inventory_" .. inv.name, I.to_table(inv)) end
end

function I.load(inv)
    if project and project.fetch then I.from_table(inv, project.fetch("inventory_" .. inv.name, nil)) end
end

-- ----------------------------------------------------------------------------------------------------------------------------- drawing
local function icon_for(inv)
    return function(item, x, y, w, h)
        local d = inv.defs[item.id] or {}
        ui.rect(x + 7, y + 7, w - 14, h - 14, d.color or "#7a8aa8", { radius = 8 })
        ui.rect(x + 7, y + 7, w - 14, h - 14, "#00000070", { radius = 8, outline = true })
        ui.text(x + w / 2, y + h / 2 - 14, (d.name or item.id):sub(1, 1):upper(), { size = 28, color = "#10141c", align = "center" })
    end
end

local function describe(inv)
    return function(item)
        local d = inv.defs[item.id] or {}
        local text = (d.name or item.id) .. ((item.count or 1) > 1 and ("  x" .. item.count) or "")
        if d.desc then text = text .. "\n" .. d.desc end
        text = text .. "\nstacks to " .. (d.max_stack or 99)
        return text
    end
end

function I.toggle(inv) inv.open = not inv.open end

-- Draws the hotbar (always) and the screen (while inv.open); call it from on_hud. Keys: I opens / closes, Escape closes, 1..9 select a hotbar slot, the mouse wheel over the hotbar does too.
function I.hud(inv, dt, opts)
    opts = opts or {}
    uikit.begin(dt)
    local input = ui.input() or { pressed = {}, keys = {}, wheel = 0 }
    local sw, sh = ui.size()
    if input.pressed and input.pressed[opts.key or "i"] then inv.open = not inv.open end
    if inv.open and input.keys and input.keys.escape then inv.open = false end
    if input.pressed then
        for n = 1, math.min(9, inv.hotbar_n) do
            if input.pressed[tostring(n)] and inv.selected ~= n then ui.run(string.format("inventory.select(%q, %d)", inv.name, n)) end
        end
    end
    local icon, tip = icon_for(inv), describe(inv)
    -- the hotbar: bottom centre
    local size, gap = 64, 6
    local hw = inv.hotbar_n * (size + gap) - gap
    local hx, hy = (sw - hw) / 2, sh - size - 24
    local hotkeys = {}
    for n = 1, math.min(9, inv.hotbar_n) do hotkeys[n] = n end
    local evh = uikit.slots("hotbar", inv.hotbar, hx, hy, inv.hotbar_n, { size = size, gap = gap, icon = icon, tooltip = tip, hotkeys = hotkeys })
    local sel = inv.selected
    ui.rect(hx + (sel - 1) * (size + gap) - 3, hy - 3, size + 6, size + 6, uikit.theme.accent, { radius = 8, outline = true, thickness = 3 })
    if evh.click and not inv.open then
        -- a click on the bar (screen closed) selects the slot; a drag with the screen closed is possible too
        if evh.click ~= inv.selected then ui.run(string.format("inventory.select(%q, %d)", inv.name, evh.click)) end
    end
    if inv.open then
        uikit.open_screen()
        local rows = math.ceil(inv.bag_n / inv.cols)
        local pw, ph = inv.cols * (size + gap) - gap + 40, rows * (size + gap) - gap + 190
        local px, py = (sw - pw) / 2, (sh - ph) / 2 - 40
        local cx, cy, cw = uikit.panel(px, py, pw, ph, opts.title or "Inventory")
        -- the filter and the sort button
        inv.filter = uikit.text_input("inv_filter", inv.filter, cx + 4, cy + 2, cw - 170, 36, { hint = "filter...", max = 20 })
        if uikit.button("inv_sort", "Sort", cx + cw - 156, cy + 2, 150, 36, { tooltip = "Stack and order the bag by name" }) then ui.run(string.format("inventory.sort(%q)", inv.name)) end
        local gy = cy + 52
        local ev = uikit.slots("bag", inv.bag, cx + 4, gy, inv.cols, { size = size, gap = gap, icon = icon, tooltip = tip, count = inv.bag_n,
            accept = function(item) return true end })
        -- what the filter hides is dimmed
        if inv.filter ~= "" then
            local f = inv.filter:lower()
            for n, x, y, w, h in uikit.grid(cx + 4, gy, inv.cols, rows, size, size, gap) do
                local s = inv.bag[n]
                local d = s and inv.defs[s.id]
                if s and not ((d and d.name or s.id):lower():find(f, 1, true)) then ui.rect(x, y, w, h, "#10141ca0", { radius = 6 }) end
            end
        end
        local total = 0
        for arr, i in each_slot(inv) do if arr[i] then total = total + 1 end end
        uikit.label(cx + 4, py + ph - 62, string.format("%d of %d slots used", total, inv.bag_n + inv.hotbar_n), { size = 20, color = uikit.theme.dim })
        uikit.label(cx + 4, py + ph - 36, "drag to move; shift + drag splits a stack, right button takes one; Enter / A picks up and puts down", { size = 18, color = uikit.theme.dim })
    end
    local drop = uikit.finish()
    if drop then ui.run(string.format("inventory.apply_move(%q, %q, %d, %q, %d, %q)", inv.name, drop.from_grid, drop.from, drop.to_grid, drop.to, drop.split or "")) end
end

return I
