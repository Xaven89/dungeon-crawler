-- The engine's widget set for a game's HUD (docs/UI_KIT.md). include("engine/ui_kit.lua") defines the global `uikit`.
--
-- It is immediate mode on top of the HUD calls (ui.rect / ui.text / ui.input / ui.clip ...): call it from on_hud(dt) every frame. A widget is a call with an id (a string that names it between frames: hover,
-- focus, the text being typed and the scroll position are kept by id) and returns what the person did:
--
--   function on_hud(dt)
--       uikit.begin(dt)                                   -- first: reads the input, moves the focus, resets the frame's lists
--       if uikit.button("ok", "Close", 20, 20, 120, 44) then closed = true end
--       volume = uikit.slider("vol", volume, 0, 1, 20, 80, 240, 28)
--       uikit.finish()                                    -- last: tooltips, the carried item, the focus ring
--   end
--
-- It draws and reads, it never changes the world (on_hud cannot): what a click should do to the game is the game's code, usually `ui.run("...")` (a logged action at the next tick).
-- Mouse AND keyboard / controller: every focusable widget takes part in focus navigation (arrow keys, d-pad, stick, Tab; Enter / A activates; Escape / B backs out of a text field).
local K = {}
uikit = K

K.theme = {
    panel = "#20242ce8", panel_edge = "#6a7388", title = "#2c3340", text = "#e8ecf4", dim = "#9aa3b5", accent = "#e0a030",
    button = "#3a4458", button_hover = "#4a5a78", button_down = "#2a3345", slot = "#2a303c", slot_hover = "#3a4458", slot_edge = "#586178",
    focus = "#ffd060", good = "#60c070", warn = "#d06050", tip = "#10141cf0", size = 22, radius = 6,
}

local S = { hot = nil, active = nil, focus = nil, scroll = {}, text = {}, cursor = {}, drag = nil, tip = nil, tip_time = 0, tip_for = nil,
            focusables = {}, clips = {}, want_pointer = false, time = 0, dt = 0, nav = nil, last_hover = nil, carried_by_pad = false }
K.state = S

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local T = K.theme

-- ---------------------------------------------------------------------------------------------------------------------------- frame
function K.begin(dt)
    S.dt = dt or 0
    S.time = S.time + S.dt
    S.input = ui.input() or { x = -1, y = -1, free = false, keys = {}, text = "", wheel = 0, pad_dx = 0, pad_dy = 0 }
    S.input.keys = S.input.keys or {}
    S.focusables = {}
    S.clips = {}
    S.hot_now = nil
    S.tip_now = nil
    S.slots_now = {}
    if not S.input.down and not S.input.released then S.active = nil end
    -- releasing the button ends a drag started with the pointer (the slot grids see S.drag.dropped in this frame)
    S.nav = nil
    local i = S.input
    if i.keys.up or i.pad_dy < 0 then S.nav = "up" elseif i.keys.down or i.pad_dy > 0 then S.nav = "down"
    elseif i.keys.left or i.pad_dx < 0 then S.nav = "left" elseif i.keys.right or i.pad_dx > 0 then S.nav = "right" end
    S.tab = i.keys.tab
    S.activate = i.keys.enter or i.pad_a
    S.back = i.keys.escape or i.pad_b
    if S.input.clicked then S.focus_from_mouse = true end
end

-- the pointer is over the rectangle, and inside every clip rectangle that is open
function K.over(x, y, w, h)
    local i = S.input
    if not i or not i.free then return false end
    if i.x < x or i.x >= x + w or i.y < y or i.y >= y + h then return false end
    for _, c in ipairs(S.clips) do
        if i.x < c[1] or i.x >= c[1] + c[3] or i.y < c[2] or i.y >= c[2] + c[4] then return false end
    end
    return true
end

function K.push_clip(x, y, w, h)
    local c = S.clips[#S.clips]
    if c then
        local x2, y2 = math.min(x + w, c[1] + c[3]), math.min(y + h, c[2] + c[4])
        x, y = math.max(x, c[1]), math.max(y, c[2])
        w, h = math.max(0, x2 - x), math.max(0, y2 - y)
    end
    S.clips[#S.clips + 1] = { x, y, w, h }
    ui.clip(x, y, w, h)
end

function K.pop_clip()
    S.clips[#S.clips] = nil
    ui.unclip()
end

function K.focusable(id, x, y, w, h)
    local c = S.clips[#S.clips]
    if c and (x + w < c[1] or x > c[1] + c[3] or y + h < c[2] or y > c[2] + c[4]) then return end -- (scrolled out of sight: not a target)
    S.focusables[#S.focusables + 1] = { id = id, x = x, y = y, w = w, h = h }
end

function K.focused(id) return S.focus == id end
function K.set_focus(id) S.focus = id end

-- the screen is open and wants the pointer: call it every frame it is up (ui.cursor: the mouse is released, a click is the HUD's)
function K.open_screen() S.want_pointer = true end

-- ---------------------------------------------------------------------------------------------------------------------------- layout
function K.anchor(w, h, where, margin)
    local sw, sh = ui.size()
    margin = margin or 20
    where = where or "center"
    local x, y = (sw - w) / 2, (sh - h) / 2
    if where:find("left") then x = margin elseif where:find("right") then x = sw - w - margin end
    if where:find("top") then y = margin elseif where:find("bottom") then y = sh - h - margin end
    return x, y
end

-- the cells of a grid: for i, x, y, w, h in uikit.grid(x0, y0, cols, rows, cell_w, cell_h, gap) do ... end
function K.grid(x0, y0, cols, rows, cw, ch, gap)
    gap = gap or 4
    ch = ch or cw
    local n, total = 0, cols * rows
    return function()
        n = n + 1
        if n > total then return nil end
        local c, r = (n - 1) % cols, (n - 1) // cols
        return n, x0 + c * (cw + gap), y0 + r * (ch + gap), cw, ch
    end
end

-- a column of rows: local col = uikit.column(x, y, w, gap); local x, y, w, h = col:next(36)
function K.column(x, y, w, gap)
    local c = { x = x, y = y, w = w, gap = gap or 6 }
    function c:next(h)
        local ry = self.y
        self.y = self.y + h + self.gap
        return self.x, ry, self.w, h
    end
    function c:skip(h) self.y = self.y + h end
    return c
end

-- the same for a row
function K.row(x, y, h, gap)
    local r = { x = x, y = y, h = h, gap = gap or 6 }
    function r:next(w)
        local rx = self.x
        self.x = self.x + w + self.gap
        return rx, self.y, w, self.h
    end
    return r
end

-- a window: returns the content rectangle x, y, w, h under the title bar
function K.panel(x, y, w, h, title)
    ui.rect(x, y, w, h, T.panel, { radius = T.radius })
    ui.rect(x, y, w, h, T.panel_edge, { radius = T.radius, outline = true, thickness = 1.5 })
    local top = 0
    if title then
        ui.rect(x, y, w, 40, T.title, { radius = T.radius })
        ui.text(x + 14, y + 8, title, { size = 24, color = T.text, shadow = true })
        top = 44
    end
    return x + 10, y + top + 6, w - 20, h - top - 16
end

function K.label(x, y, text, opts)
    opts = opts or {}
    ui.text(x, y, text, { size = opts.size or T.size, color = opts.color or T.text, align = opts.align, shadow = opts.shadow })
end

-- ---------------------------------------------------------------------------------------------------------------------------- interaction
-- Pointer and focus state of one widget: hover, press (the mouse went down on it and is still down), clicked (it went up on it), focus (the keyboard / pad is on it) and activate (Enter / A on it).
local function interact(id, x, y, w, h, focusable)
    local i = S.input
    local over = K.over(x, y, w, h)
    if over then S.hot_now = id end
    if over and i.clicked then S.active = id; S.focus = id end
    local pressed = S.active == id and i.down
    local clicked = over and i.released and S.active == id
    if focusable ~= false then K.focusable(id, x, y, w, h) end
    local focus = S.focus == id
    local activated = focus and S.activate
    return over, pressed, clicked or activated, focus
end

function K.tooltip(text)
    if text and text ~= "" then S.tip_now = text end
end

-- ---------------------------------------------------------------------------------------------------------------------------- widgets
function K.button(id, label, x, y, w, h, opts)
    opts = opts or {}
    local over, pressed, clicked, focus = interact(id, x, y, w, h)
    local col = opts.disabled and "#2a2e38" or (pressed and T.button_down or (over and T.button_hover or (opts.color or T.button)))
    ui.rect(x, y, w, h, col, { radius = T.radius })
    ui.rect(x, y, w, h, focus and T.focus or T.slot_edge, { radius = T.radius, outline = true, thickness = focus and 2.5 or 1.2 })
    ui.text(x + w / 2, y + h / 2 - (opts.size or T.size) * 0.55, label, { size = opts.size or T.size, color = opts.disabled and T.dim or T.text, align = "center", shadow = true })
    if opts.tooltip and over then K.tooltip(opts.tooltip) end
    return clicked and not opts.disabled
end

function K.checkbox(id, label, value, x, y, w, h)
    h = h or 28
    local over, _, clicked, focus = interact(id, x, y, w or 260, h)
    ui.rect(x, y + 2, h - 4, h - 4, over and T.slot_hover or T.slot, { radius = 4 })
    ui.rect(x, y + 2, h - 4, h - 4, focus and T.focus or T.slot_edge, { radius = 4, outline = true, thickness = focus and 2 or 1 })
    if value then ui.rect(x + 5, y + 7, h - 14, h - 14, T.accent, { radius = 3 }) end
    ui.text(x + h + 6, y + 2, label, { size = T.size, color = T.text })
    if clicked then value = not value end
    return value
end

-- value in [min, max]; dragging with the pointer, left / right (d-pad) steps while focused
function K.slider(id, value, min, max, x, y, w, h, step)
    h = h or 28
    local over, pressed, _, focus = interact(id, x, y, w, h)
    local i = S.input
    local span = max - min
    if pressed and span ~= 0 then
        value = clamp(min + (i.x - x) / w * span, min, max)
        if step then value = min + math.floor((value - min) / step + 0.5) * step end
    elseif focus and S.nav_consumed ~= S.time then
        local st = step or span / 20
        if S.nav == "left" then value = clamp(value - st, min, max); S.nav = nil
        elseif S.nav == "right" then value = clamp(value + st, min, max); S.nav = nil end
    end
    local f = span ~= 0 and (value - min) / span or 0
    ui.rect(x, y + h / 2 - 4, w, 8, T.slot, { radius = 4 })
    ui.rect(x, y + h / 2 - 4, w * f, 8, T.accent, { radius = 4 })
    ui.circle(x + w * f, y + h / 2, h / 2 - 2, (pressed or over) and "#ffffff" or "#d8dde8")
    if focus then ui.circle(x + w * f, y + h / 2, h / 2 + 1, T.focus, { outline = true, thickness = 2 }) end
    return value
end

-- labels = {"Items", "Skills"}; returns the active index
function K.tabs(id, labels, active, x, y, w, h)
    h = h or 40
    local n = #labels
    local tw = w / n
    for i, label in ipairs(labels) do
        local tid = id .. "#" .. i
        local over, _, clicked, focus = interact(tid, x + (i - 1) * tw, y, tw - 4, h)
        local on = i == active
        ui.rect(x + (i - 1) * tw, y, tw - 4, h, on and T.title or (over and T.button_hover or T.slot), { radius = T.radius })
        ui.rect(x + (i - 1) * tw, y, tw - 4, h, focus and T.focus or (on and T.accent or T.slot_edge), { radius = T.radius, outline = true, thickness = on and 2 or 1 })
        ui.text(x + (i - 1) * tw + (tw - 4) / 2, y + h / 2 - 12, label, { size = 22, color = on and T.text or T.dim, align = "center", shadow = true })
        if clicked then active = i end
    end
    return active
end

-- text = the current string; returns text, changed, submitted. Typing, Backspace, Delete, Home / End, Enter submits, Escape gives the focus back.
function K.text_input(id, text, x, y, w, h, opts)
    opts = opts or {}
    h = h or 36
    local over, _, clicked, focus = interact(id, x, y, w, h)
    local i = S.input
    local changed, submitted = false, false
    if over and i.clicked then S.focus = id; focus = true; S.cursor[id] = #text end
    local cur = clamp(S.cursor[id] or #text, 0, #text)
    if focus and (S.focus_from_mouse or true) then
        local typed = i.text or ""
        if typed ~= "" and not i.ctrl then
            typed = typed:gsub("[%c]", "")
            if opts.filter then typed = typed:gsub(opts.filter, "") end
            if typed ~= "" and #text + #typed <= (opts.max or 64) then
                text = text:sub(1, cur) .. typed .. text:sub(cur + 1)
                cur = cur + #typed
                changed = true
            end
        end
        if i.keys.backspace and cur > 0 then text = text:sub(1, cur - 1) .. text:sub(cur + 1); cur = cur - 1; changed = true end
        if i.keys.delete and cur < #text then text = text:sub(1, cur) .. text:sub(cur + 2); changed = true end
        if i.keys.left then cur = math.max(0, cur - 1) end
        if i.keys.right then cur = math.min(#text, cur + 1) end
        if i.keys.home then cur = 0 end
        if i.keys["end"] then cur = #text end
        if i.keys.enter then submitted = true end
        if i.keys.escape then S.focus = nil end
        S.nav = nil -- (the arrows move the caret, not the focus; Tab still moves it)
        S.activate = false
    end
    S.cursor[id] = cur
    ui.rect(x, y, w, h, "#161a22", { radius = 4 })
    ui.rect(x, y, w, h, focus and T.focus or T.slot_edge, { radius = 4, outline = true, thickness = focus and 2 or 1 })
    local shown = text
    if shown == "" and not focus and opts.hint then ui.text(x + 10, y + 7, opts.hint, { size = T.size, color = T.dim }) end
    ui.text(x + 10, y + 7, shown, { size = T.size, color = T.text })
    if focus and math.floor(S.time * 2) % 2 == 0 then
        local cx = x + 10 + ui.measure(text:sub(1, cur), T.size)
        ui.rect(cx, y + 6, 2, h - 12, T.text)
    end
    return text, changed, submitted
end

-- a vertical scroll area: local off = uikit.scroll("list", x, y, w, h, content_h, function(top) ... draw things at (y + top) ... end)
function K.scroll(id, x, y, w, h, content_h, draw)
    local st = S.scroll[id] or 0
    local max = math.max(0, content_h - h)
    local i = S.input
    if K.over(x, y, w, h) and i.wheel ~= 0 then st = st - i.wheel * 48 end
    -- the scrollbar thumb is dragged with the pointer
    local barx = x + w - 10
    if max > 0 then
        local th = math.max(30, h * h / content_h)
        local ty = y + (h - th) * (st / max)
        if K.over(barx, y, 10, h) and i.clicked then S.active = id .. "#bar" end
        if S.active == id .. "#bar" and i.down then st = clamp((i.y - y - th / 2) / (h - th), 0, 1) * max end
        S.scroll[id] = clamp(st, 0, max)
        st = S.scroll[id]
        K.push_clip(x, y, w, h)
        draw(-st)
        K.pop_clip()
        ui.rect(barx, y, 8, h, "#151922", { radius = 4 })
        ui.rect(barx, ty, 8, th, S.active == id .. "#bar" and T.accent or T.slot_edge, { radius = 4 })
    else
        S.scroll[id] = 0
        K.push_clip(x, y, w, h)
        draw(0)
        K.pop_clip()
    end
    return S.scroll[id]
end

-- ---------------------------------------------------------------------------------------------------------------------------- slot grids with drag and drop
-- items: an array; a slot is an item table ({ id = "apple", count = 3, ... }) or false / nil when empty. The widget draws, the GAME owns the rules: what it returns says what the person did
--   local ev = uikit.slots("bag", bag, x, y, 6, { rows = 4, size = 64, gap = 6, icon = draw_icon, tooltip = describe, accept = can_hold })
--   ev.hover = slot under the pointer / focus   ev.click / ev.right_click = a slot clicked
-- A DROP (an item released on a slot, or Enter on a slot while carrying one) is returned by uikit.finish() at the end of the frame:
--   local drop = uikit.finish()   -->  { from_grid = "hotbar", from = 3, to_grid = "bag", to = 5, split = nil | "half" | "one", items_from = <array>, items_to = <array> } or nil
-- apply it with uikit.move_stack(drop) or with your own rules (the widget never changes your items; the game owns them)
-- opts.icon(item, x, y, w, h) draws an item (default: a coloured square with the first letter of its id); opts.count_text(item) (default: the count when above 1); opts.tooltip(item) -> text.
-- Dragging: press on an item, move, release on a slot; or with the keyboard / pad: focus a slot, Enter picks the item up, move the focus, Enter drops it. Shift while dropping splits half, a right click picks one.
local function default_icon(item, x, y, w, h)
    ui.rect(x + 6, y + 6, w - 12, h - 12, item.color or "#7a8aa8", { radius = 6 })
    ui.text(x + w / 2, y + h / 2 - 14, (item.id or "?"):sub(1, 1):upper(), { size = 28, color = "#10141c", align = "center" })
end

function K.slots(id, items, x0, y0, cols, opts)
    opts = opts or {}
    local size, gap = opts.size or 64, opts.gap or 6
    local count = opts.count or #items
    local rows = opts.rows or math.ceil(count / cols)
    local ev = {}
    local i = S.input
    local drag = S.drag
    local dropped_here = drag and drag.dropped and drag.dropped.gx == id
    for n, x, y, w, h in K.grid(x0, y0, cols, rows, size, size, gap) do
        if n > count then break end
        local item = items[n]
        local sid = id .. ":" .. n
        local over, pressed, _, focus = interact(sid, x, y, w, h)
        S.slots_now[#S.slots_now + 1] = { grid = id, index = n, x = x, y = y, w = w, h = h, accept = opts.accept, items = items }
        local carried = drag and drag.grid == id and drag.index == n
        ui.rect(x, y, w, h, over and T.slot_hover or T.slot, { radius = 6 })
        ui.rect(x, y, w, h, focus and T.focus or T.slot_edge, { radius = 6, outline = true, thickness = focus and 3 or 1 })
        if item and not carried then
            (opts.icon or default_icon)(item, x, y, w, h)
            local ct = opts.count_text and opts.count_text(item) or ((item.count or 1) > 1 and tostring(item.count) or nil)
            if ct then ui.text(x + w - 6, y + h - 22, ct, { size = 20, color = T.text, align = "right", shadow = true }) end
        elseif item and carried then
            ui.rect(x, y, w, h, "#00000060", { radius = 6 })
        end
        if opts.hotkeys and opts.hotkeys[n] then ui.text(x + 6, y + 2, tostring(opts.hotkeys[n]), { size = 16, color = T.dim }) end
        if (over or focus) then
            ev.hover = n
            if item and opts.tooltip and not drag then K.tooltip(opts.tooltip(item)) end
        end
        -- picking up: the pointer goes down on an item (a right click picks one of a stack), or Enter / A on a focused one
        if over and i.clicked and item and not drag then S.drag = { grid = id, index = n, item = item, items = items, split = (i.shift and (item.count or 1) > 1) and "half" or nil, origin_x = i.x, origin_y = i.y, moved = false } end
        if over and i.right_clicked and item and not drag then S.drag = { grid = id, index = n, item = item, items = items, split = (item.count or 1) > 1 and "one" or nil, origin_x = i.x, origin_y = i.y, moved = false } end
        if focus and S.activate and not S.drag_started_this_frame then
            if not drag and item then S.drag = { grid = id, index = n, item = item, items = items, via_pad = true, moved = true }; S.drag_started_this_frame = true
            elseif drag and drag.via_pad and not (drag.grid == id and drag.index == n) then
                if not opts.accept or opts.accept(drag.item, n, drag) then S.dropped = { from_grid = drag.grid, from = drag.index, to = n, to_grid = id, split = drag.split, items_from = drag.items, items_to = items } end
                S.drag = nil
            elseif drag and drag.via_pad then S.drag = nil end -- (Enter on the slot it came from: put it back)
        end
        if over and (i.clicked or i.released) then ev.click = ev.click or n end
        if over and i.right_clicked then ev.right_click = n end
    end
    return ev
end

-- called by finish(): a pointer drag that is released is resolved against this frame's list of slots
local function resolve_drag()
    local d, i = S.drag, S.input
    if not d or d.via_pad then return end
    local moved = (math.abs(i.x - d.origin_x) + math.abs(i.y - d.origin_y)) > 8
    if moved then d.moved = true end
    if i.released then
        if d.moved then
            for _, sl in ipairs(S.slots_now) do
                if K.over(sl.x, sl.y, sl.w, sl.h) then
                    if not sl.accept or sl.accept(d.item, sl.index, d) then
                        S.dropped = { from_grid = d.grid, from = d.index, to = sl.index, to_grid = sl.grid, split = d.split, items_from = d.items, items_to = sl.items }
                    end
                    break
                end
            end
        end
        S.drag = nil
    end
end

-- Standard stack rules for a drop event (the game may use its own): same item -> merge up to `max_stack`; different -> swap; an empty slot takes the item, `split = "half"` / "one" moves part of a stack.
-- items_from / items_to are the arrays; returns true when something moved. `max_stack(item)` defaults to 99.
function K.move_stack(drop, max_stack)
    if not drop then return false end
    local from, to = drop.items_from, drop.items_to
    local a, b = from[drop.from], to[drop.to]
    if not a or (from == to and drop.from == drop.to) then return false end
    local cap = function(it) return max_stack and max_stack(it) or 99 end
    local amount = a.count or 1
    if drop.split == "half" then amount = math.max(1, (a.count or 1) // 2) elseif drop.split == "one" then amount = 1 end
    if b and b.id == a.id then -- merge
        local room = cap(b) - (b.count or 1)
        local mv = math.min(room, amount)
        if mv <= 0 then return false end
        b.count = (b.count or 1) + mv
        a.count = (a.count or 1) - mv
        if a.count <= 0 then from[drop.from] = false end
        return true
    end
    if not b then -- an empty slot: the whole stack or a part of it
        if amount >= (a.count or 1) then to[drop.to] = a; from[drop.from] = false
        else
            local piece = {}
            for k, v in pairs(a) do piece[k] = v end
            piece.count = amount
            a.count = (a.count or 1) - amount
            to[drop.to] = piece
        end
        return true
    end
    if drop.split then return false end
    from[drop.from], to[drop.to] = b, a -- different items: swap
    return true
end

-- ---------------------------------------------------------------------------------------------------------------------------- finish
local function move_focus(dir)
    local cur
    for _, f in ipairs(S.focusables) do if f.id == S.focus then cur = f end end
    if not cur then S.focus = S.focusables[1] and S.focusables[1].id or nil; return end
    local cx, cy = cur.x + cur.w / 2, cur.y + cur.h / 2
    local best, best_score
    for _, f in ipairs(S.focusables) do
        if f.id ~= cur.id then
            local fx, fy = f.x + f.w / 2, f.y + f.h / 2
            local dx, dy = fx - cx, fy - cy
            local along, across
            if dir == "right" then along, across = dx, math.abs(dy)
            elseif dir == "left" then along, across = -dx, math.abs(dy)
            elseif dir == "down" then along, across = dy, math.abs(dx)
            else along, across = -dy, math.abs(dx) end
            if along > 1 then
                local score = along + across * 2.2
                if not best_score or score < best_score then best, best_score = f, score end
            end
        end
    end
    if best then S.focus = best.id end
end

function K.finish()
    resolve_drag()
    -- focus: the arrows / d-pad / Tab move it to the nearest widget in that direction (only when something in this frame took the input)
    if S.nav then move_focus(S.nav) end
    if S.tab then
        local idx
        for n, f in ipairs(S.focusables) do if f.id == S.focus then idx = n end end
        local nxt = S.focusables[(idx or 0) % math.max(1, #S.focusables) + 1]
        if nxt then S.focus = nxt.id end
    end
    local still = false
    for _, f in ipairs(S.focusables) do if f.id == S.focus then still = true end end
    if not still and S.focus and not S.focus_keep then S.focus = nil end
    S.hot = S.hot_now
    -- the carried item follows the pointer
    local d, i = S.drag, S.input
    if d and d.moved and not d.via_pad then
        local sz = 56
        (d.icon or default_icon)(d.item, i.x - sz / 2, i.y - sz / 2, sz, sz)
        local n = d.split == "half" and ((d.item.count or 1) // 2) or (d.split == "one" and 1 or (d.item.count or 1))
        if n > 1 then ui.text(i.x + sz / 2, i.y + sz / 2 - 12, tostring(n), { size = 20, color = T.text, align = "right", shadow = true }) end
    elseif d and d.via_pad then
        local f
        for _, fo in ipairs(S.focusables) do if fo.id == S.focus then f = fo end end
        if f then default_icon(d.item, f.x - 8, f.y - 8, f.w, f.h) end
    end
    -- a tooltip appears after the pointer rested on the same thing for a moment
    if S.tip_now and not (d and d.moved) then
        if S.tip_for ~= S.tip_now then S.tip_for, S.tip_time = S.tip_now, 0 end
        S.tip_time = S.tip_time + S.dt
        if S.tip_time > 0.35 then
            local sw, sh = ui.size()
            local lines = {}
            for line in (S.tip_now .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
            local w = 0
            for _, l in ipairs(lines) do w = math.max(w, ui.measure(l, 20)) end
            w, h = w + 24, #lines * 26 + 16
            local tx, ty = clamp(i.x + 18, 4, sw - w - 4), clamp(i.y + 18, 4, sh - h - 4)
            ui.rect(tx, ty, w, h, T.tip, { radius = 6 })
            ui.rect(tx, ty, w, h, T.panel_edge, { radius = 6, outline = true })
            for n, l in ipairs(lines) do ui.text(tx + 12, ty + 8 + (n - 1) * 26, l, { size = 20, color = n == 1 and T.text or T.dim }) end
        end
    else
        S.tip_for, S.tip_time = nil, 0
    end
    if S.want_pointer then ui.cursor(true) end
    S.want_pointer = false
    S.drag_started_this_frame = false
    local drop = S.dropped
    S.dropped = nil
    return drop -- an item dropped on a slot this frame (by the pointer or the pad), or nil: the game applies it once
end

return K
