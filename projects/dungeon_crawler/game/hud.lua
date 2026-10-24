-- hud: everything drawn over the picture. on_hud only DRAWS and READS (docs/HUD.md): what a click does goes through ui.run("Game.xxx(...)") as a logged action.
-- Screens (G.screen): "class" (the start), "bag" (I: inventory / C: character / J: achievements as tabs), "shop", "death", "end".
Game = Game or {}
local G = Game
local H = {}
G.hud = H
local floor, max, min = math.floor, math.max, math.min

local C = {
    panel = "#0b0d14e6", edge = "#5b6280", glee = "#58f2ff", gold = "#ffcf4a", red = "#e04a4a", blue = "#4a86ff", green = "#5fd35f", text = "#eef1f8", dim = "#98a0b4",
    magenta = "#ff4fa3", dark = "#05060a",
}
H.C = C

-- ---------------------------------------------------------------------------------------------- helpers
local function wrap(text, size, maxw)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        local try = (line == "") and word or (line .. " " .. word)
        if ui.measure(try, size) > maxw and line ~= "" then
            lines[#lines + 1] = line
            line = word
        else
            line = try
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end
H.wrap = wrap

local function pressed(input, k) return input and input.pressed and input.pressed[k] end

local function bar(x, y, w, h, frac, color, back, label, size)
    frac = max(0, min(1, frac))
    ui.rect(x, y, w, h, back or "#12141cdd", { radius = h / 2 })
    if frac > 0 then ui.rect(x, y, max(h, w * frac), h, color, { radius = h / 2 }) end
    ui.rect(x, y, w, h, "#00000080", { radius = h / 2, outline = true, thickness = 2 })
    if label then ui.text(x + w / 2, y + h / 2 - (size or 18) * 0.62, label, { size = size or 18, color = "#ffffff", align = "center" }) end
end

local function item_icon(item, x, y, w, h)
    local d = G.items.defs[item.id] or {}
    local col = d.color or "#7a8aa8"
    ui.rect(x + 5, y + 5, w - 10, h - 10, "#1a1d28", { radius = 8 })
    -- a small picture per kind
    local cx, cy = x + w / 2, y + h / 2
    if d.kind == "weapon" then
        ui.line(cx - 14, cy + 14, cx + 14, cy - 14, col, 8); ui.line(cx - 12, cy + 4, cx - 4, cy + 12, "#8a6a3a", 5)
    elseif d.kind == "armor" then
        ui.rect(cx - 15, cy - 14, 30, 28, col, { radius = 6 }); ui.rect(cx - 6, cy - 14, 12, 8, "#1a1d28", { radius = 4 })
    elseif d.kind == "trinket" then
        ui.circle(cx, cy, 13, col); ui.circle(cx, cy, 13, "#00000090", { outline = true, thickness = 2 })
    elseif d.kind == "consumable" then
        ui.rect(cx - 9, cy - 8, 18, 24, col, { radius = 5 }); ui.rect(cx - 5, cy - 16, 10, 8, "#d8dce8", { radius = 2 })
    elseif d.kind == "quest" then
        ui.rect(cx - 16, cy - 10, 32, 20, col, { radius = 3 }); ui.rect(cx - 12, cy - 6, 8, 8, "#1a1d28")
    else
        ui.circle(cx, cy, 12, col, {}); ui.circle(cx - 4, cy - 4, 4, "#ffffff60")
    end
    ui.rect(x + 2, y + 2, w - 4, h - 4, col, { radius = 9, outline = true, thickness = 2 })
    if (item.count or 1) > 1 then ui.text(x + w - 8, y + h - 24, tostring(item.count), { size = 20, color = "#ffffff", align = "right" }) end
end

local function item_tip(item) return G.items.describe(item.id) end

-- ---------------------------------------------------------------------------------------------- GLEE's panel
local function glee_face(cx, cy, speaking, t)
    local pulse = speaking and (0.5 + 0.5 * math.sin(t * 0.7)) or 0.15
    ui.circle(cx, cy, 36, "#0a2a3a")
    ui.circle(cx, cy, 36, C.glee, { outline = true, thickness = 3 })
    ui.circle(cx, cy, 30 + pulse * 3, "#58f2ff22")
    local blink = (t % 150) < 6
    ui.rect(cx - 17, cy - 12, 10, blink and 2 or 12, C.glee, { radius = 3 })
    ui.rect(cx + 7, cy - 12, 10, blink and 2 or 12, C.glee, { radius = 3 })
    local mh = speaking and (3 + 11 * pulse) or 3
    ui.rect(cx - 13, cy + 12, 26, mh, C.glee, { radius = 4 })
end

function H.announcer(w, h)
    local A = G.announcer
    local m = A.current
    local t = time.tick()
    local pw = min(1000, w - 760)
    local px = (w - pw) / 2
    local py = 16
    if not m then
        -- idle: a quiet little tag so the host is still "there"
        ui.rect(px + pw / 2 - 90, py, 180, 34, "#0b0d14b0", { radius = 17 })
        ui.text(px + pw / 2, py + 5, "GLEE  ON AIR", { size = 20, color = "#58f2ff90", align = "center" })
        return
    end
    local who = m.who or "GLEE"
    local col = (who == "HONK") and "#ffa04a" or C.glee
    local shown = floor((t - m.t_start) * 1.5) + 1
    local text = m.text:sub(1, shown)
    local size = 25
    local lines = wrap(m.text, size, pw - 150)
    local ph = #lines * 31 + 46
    local fade = min(1, (m.t_end - t) / 20, (t - m.t_start + 4) / 8)
    local alpha = string.format("%02x", floor(255 * max(0, min(1, fade))))
    ui.rect(px, py, pw, ph, "#080a12" .. string.format("%02x", floor(236 * max(0, min(1, fade)))), { radius = 16 })
    ui.rect(px, py, pw, ph, col .. alpha, { radius = 16, outline = true, thickness = 3 })
    if who == "HONK" then
        ui.circle(px + 62, py + 56, 34, "#ffa04a"); ui.text(px + 62, py + 36, "H", { size = 40, color = "#1a1008", align = "center" })
    else
        glee_face(px + 62, py + 56, shown <= #m.text, t)
    end
    ui.text(px + 118, py + 8, who == "HONK" and "ADMIRAL HONK" or "GLEE", { size = 20, color = col })
    local y = py + 34
    local used = 0
    for _, ln in ipairs(lines) do
        local part = text:sub(used + 1, used + #ln + 1)
        if #part > #ln then part = part:sub(1, #ln) end
        ui.text(px + 118, y, part, { size = size, color = "#f2f6ff" })
        used = used + #ln + 1
        y = y + 31
        if used >= #text then break end
    end
end

-- ---------------------------------------------------------------------------------------------- the always-on HUD
local function hud_player(w, h, input)
    local s = G.state
    local P = G.player
    local t = time.tick()
    if not s.class then return end
    -- bottom left: the stats
    local x, y = 28, h - 150
    ui.rect(x - 10, y - 12, 420, 134, "#0b0d14c8", { radius = 14 })
    ui.text(x + 4, y - 4, string.format("%s  LV %d", G.player.classes[s.class].name, s.level), { size = 24, color = G.player.classes[s.class].color })
    bar(x, y + 28, 396, 30, s.hp / P.max_hp(), t - P.flash < 12 and "#ff9090" or C.red, nil, string.format("HP  %d / %d", floor(s.hp + 0.5), P.max_hp()), 20)
    bar(x, y + 64, 396, 20, s.mp / P.max_mp(), C.blue, nil, string.format("MP  %d / %d", floor(s.mp + 0.5), P.max_mp()), 15)
    bar(x, y + 90, 396, 12, s.xp / P.xp_needed(), "#c8a040", nil, nil)
    ui.text(x + 4, y + 104, string.format("%s gold", G.format_int(s.gold)), { size = 20, color = C.gold })
    if s.points > 0 then ui.text(x + 392, y + 104, string.format("%d stat points: press C", s.points), { size = 20, color = C.green, align = "right" }) end
    -- ability (bottom right of the stats)
    local ab = P.classes[s.class].ability
    local ax, ay = x + 430, y + 28
    ui.rect(ax, ay, 74, 74, "#0b0d14c8", { radius = 12 })
    local cdleft = max(0, P.next_ability - t)
    local frac = (ab.cd > 0 and cdleft > 0) and (cdleft / ab.cd) or 0
    ui.circle(ax + 37, ay + 37, 26, cdleft > 0 and "#3a3f50" or P.classes[s.class].color)
    if frac > 0 then ui.rect(ax + 4, ay + 4 + 66 * (1 - frac), 66, 66 * frac, "#00000099", { radius = 10 }) end
    ui.text(ax + 37, ay + 24, "RMB", { size = 20, color = "#101418", align = "center" })
    ui.text(ax + 37, ay + 78, ab.name .. (ab.cost > 0 and (" " .. ab.cost) or ""), { size = 16, color = C.dim, align = "center" })
    -- quick keys: R heal, X mana, G throw (the number keys are the engine's teleports)
    local inv = G.items.inv
    local qx, qy = (w - 3 * 150) / 2 - 20, h - 92
    local quick = { { "R", "heal", { "bandage", "smoothie", "sushi", "cheese" }, C.red }, { "X", "mana", { "energy", "cheese" }, C.blue }, { "G", "throw", { "firecracker" }, "#ffb040" } }
    for i, q in ipairs(quick) do
        local n = 0
        for _, id in ipairs(q[3]) do n = n + G.items.count(id) end
        local x0 = qx + (i - 1) * 150
        ui.rect(x0, qy, 138, 66, "#0b0d14c8", { radius = 12 })
        ui.rect(x0, qy, 138, 66, n > 0 and q[4] or "#3a4054", { radius = 12, outline = true, thickness = 2 })
        ui.text(x0 + 14, qy + 8, q[1], { size = 30, color = n > 0 and "#ffffff" or "#5a6074" })
        ui.text(x0 + 52, qy + 10, q[2], { size = 22, color = n > 0 and "#dfe4f0" or "#5a6074" })
        ui.text(x0 + 52, qy + 36, "x" .. n, { size = 22, color = n > 0 and C.gold or "#5a6074" })
    end
end

local function hud_world(w, h, input)
    local s, P = G.state, G.player
    local t = time.tick()
    -- crosshair and hitmark
    local cx, cy = w / 2, h / 2
    ui.circle(cx, cy, 2.5, "#ffffffd0")
    for _, d in ipairs({ { -14, 0, -7, 0 }, { 7, 0, 14, 0 }, { 0, -14, 0, -7 }, { 0, 7, 0, 14 } }) do ui.line(cx + d[1], cy + d[2], cx + d[3], cy + d[4], "#ffffff90", 2) end
    local age = t - P.hitmark
    if age < 10 then
        local col = P.hitmark_crit and "#ffd24a" or (P.hitmark_wall and "#a8b0c0" or "#ffffff")
        local r = 10 + age
        ui.line(cx - r, cy - r, cx - r + 8, cy - r + 8, col, 3); ui.line(cx + r, cy - r, cx + r - 8, cy - r + 8, col, 3)
        ui.line(cx - r, cy + r, cx - r + 8, cy + r - 8, col, 3); ui.line(cx + r, cy + r, cx + r - 8, cy + r - 8, col, 3)
    end
    -- the interaction prompt (what the E key would press)
    if not G.screen and not P.dead then
        local it = G.traps.current_prompt()
        if it then
            local tw = ui.measure(it.prompt, 26) + 70
            ui.rect(cx - tw / 2, cy + 70, tw, 46, "#0b0d14d0", { radius = 10 })
            ui.rect(cx - tw / 2, cy + 70, tw, 46, "#ffd24a", { radius = 10, outline = true, thickness = 2 })
            ui.text(cx - tw / 2 + 14, cy + 78, "E", { size = 28, color = "#ffd24a" })
            ui.text(cx - tw / 2 + 52, cy + 82, it.prompt, { size = 24, color = "#ffffff" })
        end
    end
    -- the loot log: small lines at the bottom left, above the stats box, they fade after a few seconds
    do
        local lines = P.log_lines
        local base = h - 190
        for i = #lines, 1, -1 do
            local l = lines[i]
            local age = t - l.t
            if age > 480 then table.remove(lines, i)
            else
                local a = age > 400 and (1 - (age - 400) / 80) or 1
                local yy = base - (#lines - i) * 26
                ui.text(30, yy, l.text, { size = 20, color = l.color .. string.format("%02x", floor(255 * a)), shadow = true })
            end
        end
    end
    -- popups above the crosshair
    local n = #P.popups
    for i = n, 1, -1 do
        local p = P.popups[i]
        local a = t - p.t
        if a < 150 then
            local fade = a > 100 and (1 - (a - 100) / 50) or 1
            local yy = cy - 70 - (n - i) * 30 - a * 0.3
            local col = p.color
            ui.text(cx, yy, p.text, { size = p.big and 36 or 24, color = col .. string.format("%02x", floor(255 * fade)), align = "center" })
        end
    end
    -- the red vignette: after a hit and while nearly dead
    local fa = max(0, 1 - (t - P.flash) / 24)
    local low = (s.class and s.hp < P.max_hp() * 0.25) and (0.35 + 0.15 * math.sin(t * 0.2)) or 0
    local a = max(fa * 0.55, low)
    if a > 0.01 then
        local c = "#c01010" .. string.format("%02x", floor(a * 255))
        local e = 90
        ui.rect(0, 0, w, e, c); ui.rect(0, h - e, w, e, c); ui.rect(0, 0, e, h, c); ui.rect(w - e, 0, e, h, c)
    end
    -- the top left: where we are
    local W = G.world
    local room = G.current_room and W.rooms[G.current_room]
    ui.text(26, 20, tr("title"), { size = 28, color = C.gold })
    ui.text(26, 52, (H.floor_label and H.floor_label() or "FLOOR 1") .. "  " .. (room and room.name or "..."), { size = 20, color = C.dim })
    local rl = H.rule_label and H.rule_label()
    if rl then ui.text(26, 78, rl, { size = 18, color = "#ff9a5a" }) end
    local cy_ = h - 160
    for _, kind in ipairs({ "bleed", "septic" }) do
        if G.skills.has(kind) then
            local left = floor((s.cond[kind] - t) / 60)
            ui.text(26, cy_, string.format("%s  %ds", G.skills.COND[kind].name, left), { size = 20, color = G.skills.COND[kind].color })
            cy_ = cy_ + 26
        end
    end
    -- the top right: the show's numbers
    local sh = G.show.st()
    ui.text(w - 26, 20, tr("show.viewers") .. "  " .. G.format_int(sh.views > 0 and sh.views or G.show.viewers()), { size = 24, color = "#ff6a8a", align = "right" })
    ui.text(w - 26, 50, string.format("%s %s   %s %d", tr("show.followers"), G.format_int(sh.followers), tr("show.favorites"), sh.favorites), { size = 18, color = "#ffd24a", align = "right" })
    ui.text(w - 26, 74, string.format("kills %d   deaths %d   achievements %d/%d", s.kills, s.deaths, s.ach_count or 0, #G.announcer.order), { size = 16, color = C.dim, align = "right" })
    -- the buzz: how loud the audience is right now
    local buzz = min(1, sh.buzz / 150)
    if buzz > 0.02 then bar(w - 226, 100, 200, 8, buzz, buzz > 0.6 and "#ff4fa3" or "#c0508a", "#12141c99") end
    -- the help line while the run is young
    if t < 4000 and not G.screen then ui.text(w / 2, h - 118, tr("ui.help"), { size = 20, color = "#ffffff80", align = "center" }) end
end

-- the map (top left, under the place): the rooms the contestant has seen, the corridors between them, an arrow for the player
local links = { { "lobby", "hall" }, { "hall", "boiler" }, { "boiler", "conveyor" }, { "conveyor", "gutter" }, { "gutter", "ballroom" }, { "ballroom", "grotto" }, { "grotto", "arena" }, { "arena", "stairwell" } }
-- the map of a big floor: a window of 260 x 260 px around the player (0.8 px per metre: 10 cells), the rooms the contestant has seen, the halls between them, the safe rooms and the stairwells
-- within two cells (even in the fog), the arrow of the player
local MM_COL = { safe = "#2f8f5f", rest = "#2f8f5f", guild = "#3f8f8f", stairs_free = "#c8a83a", arena = "#b03a3a", ante = "#7a4f4f", prize = "#8a6fc0", connector = "#4a5878", borough = "#6a5a3a", borough_arena = "#b03a3a" }
function G.minimap_cells(w, h)
    local F, s = G.floorgen, G.state
    local P = F.layout
    local mx, my, size, sc = 26, 92, 260, 0.8
    ui.rect(mx - 8, my - 8, size + 16, size + 16, "#0b0d14a0", { radius = 10 })
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local function sx(x) return mx + size / 2 + (x - lx) * sc end
    local function sz(z) return my + size / 2 + (z - lz) * sc end
    local pci, pcj = math.floor(lx / 32), math.floor(lz / 32)
    local function visible(r) return sx(r.x) < mx + size and sx(r.x + r.w) > mx and sz(r.z) < my + size and sz(r.z + r.d) > my end
    local function clipped(x, y, rw, rh, col, opts)
        local x0, y0, x1, y1 = math.max(x, mx), math.max(y, my), math.min(x + rw, mx + size), math.min(y + rh, my + size)
        if x1 > x0 and y1 > y0 then ui.rect(x0, y0, x1 - x0, y1 - y0, col, opts) end
    end
    -- the halls between rooms that were both visited
    for _, e in ipairs(P.plan.edges) do
        local a, b = P.rooms[e.a], P.rooms[e.b]
        if a and b and s.flags["visited_" .. e.a] and s.flags["visited_" .. e.b] then
            local ax, ay, bx, by = sx(a.x + a.w / 2), sz(a.z + a.d / 2), sx(b.x + b.w / 2), sz(b.z + b.d / 2)
            if ax > mx and ax < mx + size and ay > my and ay < my + size and bx > mx and bx < mx + size and by > my and by < my + size then ui.line(ax, ay, bx, by, "#6a7388", 2) end
        end
    end
    for _, id in ipairs(P.order) do
        local r = P.rooms[id]
        if visible(r) then
            local seen = s.flags["visited_" .. id]
            local near = math.abs(r.ci - pci) <= 2 and math.abs(r.cj - pcj) <= 2
            local special = (r.theme == "safe" or r.theme == "rest" or r.theme == "stairs_free" or r.theme == "guild")
            if r.theme == "stairs_free" and P.floor == 3 and not s.flags["known_" .. id] then special = false end      -- (the over-city: the stairs are found by the note in a pub)
            if seen or (special and near) then
                local cur = (G.current_room == id)
                local col = seen and (cur and "#5a86c4" or (MM_COL[r.theme] and MM_COL[r.theme] or "#4a5878")) or (MM_COL[r.theme] or "#2a3347") .. "a0"
                clipped(sx(r.x), sz(r.z), r.w * sc, r.d * sc, col, { radius = 2 })
                if cur then clipped(sx(r.x), sz(r.z), r.w * sc, r.d * sc, "#9fd0ff", { radius = 2, outline = true, thickness = 2 }) end
                if r.theme == "stairs_free" then ui.text(sx(r.x + r.w / 2) - 4, sz(r.z + r.d / 2) - 8, "v", { size = 16, color = "#ffe27a" }) end
            end
        end
    end
    local fx, fy, fz = player.forward()
    local n = math.max(0.01, math.sqrt(fx * fx + fz * fz))
    local ax, ay = mx + size / 2, my + size / 2
    ui.line(ax, ay, ax + fx / n * 16, ay + fz / n * 16, "#ffd24a", 4)
    ui.circle(ax, ay, 7, "#ffd24a")
    ui.circle(ax, ay, 3, "#0b0d14")
    -- the floor's clock under the map: the time left and what the clock allows now
    local f = F.frac()
    local left = F.remaining_s()
    local state, col = "stairwells sealed", "#c0c8d8"
    if f >= 1 then state, col = "COLLAPSE", "#ff5050"
    elseif f >= F.AT_CLOSE then state, col = "safe rooms closed", "#ff7a5a"
    elseif f >= F.AT_LATE then state, col = "stairs free, service open", "#7fe08a"
    elseif f >= F.AT_OPEN then state, col = "stairs open (leaving now costs viewers)", "#ffd24a" end
    ui.text(mx, my + size + 14, string.format("%d:%02d  %s", floor(left / 60), left % 60, state), { size = 18, color = col })
    if P.floor == 3 then
        local OC = G.gen.overcity
        ui.text(mx, my + size + 38, (OC.is_night() and "NIGHT" or "DAY") .. "   " .. (s.flags.quest_why and "quest done: the service stairs are open" or string.format("quest: find out why (%d / 3)", OC.clue_count())), { size = 18, color = OC.is_night() and "#8fa0ff" or "#ffd9a0" })
    end
end

function G.minimap(w, h)
    if G.screen == "class" or not G.state.class then return end
    if G.floorgen and G.floorgen.active and G.floorgen.layout then return G.minimap_cells(w, h) end
    local W, s = G.world, G.state
    local mx, my, sc = 26, 92, 1.55
    local pw, ph = 124 * sc + 16, 154 * sc + 16
    ui.rect(mx - 8, my - 8, pw, ph, "#0b0d14a0", { radius = 10 })
    local function center(r) return mx + (r.x + r.w / 2) * sc, my + (r.z + r.d / 2) * sc end
    local lk = links
    if G.floorgen and G.floorgen.active and G.floorgen.layout then
        lk = {}
        for _, e in ipairs(G.floorgen.layout.edges) do lk[#lk + 1] = { e.a, e.b } end
    end
    for _, l in ipairs(lk) do
        if s.flags["visited_" .. l[1]] and s.flags["visited_" .. l[2]] and W.rooms[l[1]] and W.rooms[l[2]] then
            local ax, ay = center(W.rooms[l[1]]); local bx, by = center(W.rooms[l[2]])
            ui.line(ax, ay, bx, by, "#6a7388", 3)
        end
    end
    for id, r in pairs(W.rooms) do
        local seen = s.flags["visited_" .. id]
        local x, y = mx + r.x * sc, my + r.z * sc
        if seen then
            local cur = (G.current_room == id)
            ui.rect(x, y, r.w * sc, r.d * sc, cur and "#4a6a9a" or "#2a3347", { radius = 3 })
            ui.rect(x, y, r.w * sc, r.d * sc, cur and "#9fd0ff" or "#586178", { radius = 3, outline = true, thickness = 2 })
            if s.cleared[id] then ui.text(x + 4, y + 2, "ok", { size = 14, color = "#5fd35f" }) end
        else
            ui.rect(x, y, r.w * sc, r.d * sc, "#ffffff0c", { radius = 3, outline = true, thickness = 1 })
        end
    end
    if G.boss and G.boss.active and G.boss.inst and not G.boss.inst.dead then
        local br = W.rooms[G.boss.lair.room]
        if br then local ax, ay = center(br); ui.circle(ax, ay, 6, "#ff3030") end
    end
    local px, py, pz = player.pos()
    local lx, ly, lz = G.to_local(px, py, pz)
    local fx, fy, fz = player.forward()
    local ax, ay = mx + lx * sc, my + lz * sc
    local n = math.max(0.01, math.sqrt(fx * fx + fz * fz))
    local dx, dz = fx / n, fz / n
    ui.line(ax, ay, ax + dx * 12, ay + dz * 12, "#ffd24a", 3)
    ui.circle(ax, ay, 4.5, "#ffd24a")
end

-- achievement toasts (right side, under the numbers)
local function hud_toasts(w, h)
    local A = G.announcer
    local t = time.tick()
    local y = 112
    for i = #A.toasts, 1, -1 do
        local ts = A.toasts[i]
        local age = t - ts.t
        if age > 420 then table.remove(A.toasts, i)
        else
            local slide = min(1, age / 14)
            local fade = age > 360 and (1 - (age - 360) / 60) or 1
            local bx = w - 26 - 440 * slide
            local al = string.format("%02x", floor(255 * fade))
            ui.rect(bx, y, 440, 84, "#0b0d14" .. string.format("%02x", floor(230 * fade)), { radius = 12 })
            ui.rect(bx, y, 440, 84, "#ffcf4a" .. al, { radius = 12, outline = true, thickness = 3 })
            ui.text(bx + 14, y + 6, tr("ui.achievements"), { size = 16, color = "#ffcf4a" .. al })
            ui.text(bx + 14, y + 26, tr("achievement." .. ts.id .. ".name"), { size = 26, color = "#ffffff" .. al })
            ui.text(bx + 14, y + 58, tr("achievement." .. ts.id .. ".desc"), { size = 17, color = "#b8c0d4" .. al })
            y = y + 94
        end
    end
end

-- the boss bar
local function hud_boss(w, h)
    local B = G.boss
    if not B or not B.active or not B.inst or B.inst.dead then return end
    local bw = 900
    local x, y = (w - bw) / 2, h - 230
    ui.text(w / 2, y - 36, (B.inst.name or tr("ui.boss")):upper(), { size = 30, color = "#ff7a7a", align = "center" })
    bar(x, y, bw, 26, B.inst.hp / B.inst.max_hp, "#c03030", nil, nil)
    local ph = B.phase or 1
    for i = 1, 3 do ui.circle(x + bw - 20 - (3 - i) * 22, y - 18, 6, i <= ph and "#ff5050" or "#403040") end
    if B.inst.meter then
        bar(x + bw / 2 - 160, y + 34, 320, 14, min(1, B.inst.meter / 100), "#ffcf4a", nil, nil)
        ui.text(x + bw / 2, y + 52, tr("boss.meter"), { size = 16, color = "#ffcf4a", align = "center" })
    end
end

-- ---------------------------------------------------------------------------------------------- the screens
local function panel(x, y, w, h, title)
    return uikit.panel(x, y, w, h, title)
end

local function class_screen(w, h, input)
    uikit.open_screen()
    ui.rect(0, 0, w, h, "#05060acc")
    ui.text(w / 2, 170, tr("ui.class_title"), { size = 64, color = C.gold, align = "center" })
    ui.text(w / 2, 245, tr("ui.class_hint"), { size = 24, color = C.dim, align = "center" })
    local cw, ch, gap = 410, 610, 24
    local total = #G.player.class_order * (cw + gap) - gap
    local x0 = (w - total) / 2
    for i, id in ipairs(G.player.class_order) do
        local c = G.player.classes[id]
        local x, y = x0 + (i - 1) * (cw + gap), 290
        local hover = uikit.over(x, y, cw, ch)
        ui.rect(x, y, cw, ch, hover and "#1b2030f2" or "#10131cf0", { radius = 16 })
        ui.rect(x, y, cw, ch, c.color, { radius = 16, outline = true, thickness = hover and 5 or 3 })
        ui.text(x + cw / 2, y + 18, tr("ui.class." .. id .. ".name"):upper(), { size = 38, color = c.color, align = "center" })
        ui.text(x + cw / 2, y + 64, tr("ui.class." .. id .. ".tag"), { size = 21, color = C.dim, align = "center" })
        local ly = y + 108
        for _, ln in ipairs(wrap(tr("ui.class." .. id .. ".blurb"), 22, cw - 50)) do ui.text(x + 26, ly, ln, { size = 22, color = "#dfe4f0" }); ly = ly + 28 end
        local by = y + 300
        for _, st in ipairs({ "str", "dex", "int", "con", "cha" }) do
            ui.text(x + 26, by, st:upper(), { size = 21, color = C.dim })
            bar(x + 90, by + 4, cw - 130, 16, c.stats[st] / 10, c.color, nil, tostring(c.stats[st]), 14)
            by = by + 32
        end
        local wd = G.items.defs[c.weapon]
        ui.text(x + 26, y + 478, tr("ui.weapon") .. ": " .. wd.name, { size = 20, color = "#dfe4f0" })
        ui.text(x + 26, y + 506, tr("ui.ability") .. ": " .. c.ability.name .. (c.ability.cost > 0 and ("  (" .. c.ability.cost .. " " .. tr("ui.mana") .. ")") or ""), { size = 20, color = "#dfe4f0" })
        if uikit.button("class_" .. id, tr("ui.choose"), x + 60, y + ch - 80, cw - 120, 56, { color = c.color }) then ui.run(string.format("Game.player.pick_class(%q)", id)) end
    end
end

local function title_screen(w, h)
    uikit.open_screen()
    local t = time.tick()
    local a = math.min(1, t / 60, (330 - t) / 40)
    a = math.max(0, a)
    local al = string.format("%02x", math.floor(255 * a))
    ui.rect(0, 0, w, h, "#05060a" .. string.format("%02x", math.floor(235 * math.min(1, (330 - t) / 30 + 0.0))))
    ui.text(w / 2, h / 2 - 190, "A GLEE PRODUCTION", { size = 28, color = "#58f2ff" .. al, align = "center" })
    ui.text(w / 2, h / 2 - 130, tr("title"), { size = 150, color = "#ffcf4a" .. al, align = "center" })
    ui.text(w / 2, h / 2 + 50, tr("subtitle"), { size = 34, color = "#ffffff" .. al, align = "center" })
    ui.text(w / 2, h / 2 + 140, "Please wait while we locate your consent.", { size = 24, color = "#98a0b4" .. al, align = "center" })
    local dots = math.floor(t / 20) % 4
    ui.text(w / 2, h / 2 + 180, string.rep(".", dots), { size = 40, color = "#98a0b4" .. al, align = "center" })
end

local function bag_screen(w, h, input)
    uikit.open_screen()
    local s, P = G.state, G.player
    local inv = G.items.inv
    local pw, ph = 1260, 820
    local px, py = (w - pw) / 2, (h - ph) / 2 - 30
    local cx, cy, cw, chh = panel(px, py, pw, ph, "")
    local tabs = uikit.tabs("bag_tabs", { tr("ui.inventory") .. " (I)", tr("ui.character") .. " (C)", "Achievements (J)", tr("ui.settings"), tr("ui.skills") .. " (K)" }, G.bag_tab or 1, cx, cy, 1100, 40)
    if tabs ~= (G.bag_tab or 1) then G.bag_tab = tabs end
    local top = cy + 56
    if (G.bag_tab or 1) == 1 then
        -- the equipment on the left, the bag on the right
        ui.text(cx + 8, top, tr("ui.equipped"), { size = 26, color = C.gold })
        local ey = top + 40
        for _, slot in ipairs({ "weapon", "armor", "trinket" }) do
            local id = s.equip[slot]
            local d = id and G.items.defs[id]
            ui.rect(cx + 8, ey, 460, 84, "#161a26", { radius = 10 })
            ui.rect(cx + 8, ey, 460, 84, d and d.color or "#3a4054", { radius = 10, outline = true, thickness = 2 })
            ui.text(cx + 100, ey + 8, slot:upper(), { size = 15, color = C.dim })
            if d then
                item_icon({ id = id, count = 1 }, cx + 14, ey + 6, 72, 72)
                ui.text(cx + 100, ey + 28, d.name, { size = 22, color = d.color })
                local line = d.dmg and string.format("dmg %d-%d  reach %.1f", d.dmg[1], d.dmg[2], d.reach) or (d.def and ("armour " .. d.def) or (d.desc or ""))
                ui.text(cx + 100, ey + 56, line, { size = 17, color = C.dim })
                if uikit.button("unequip_" .. slot, "x", cx + 426, ey + 6, 36, 30, { tooltip = "Unequip" }) then ui.run(string.format("Game.player.unequip(%q)", slot)) end
            else
                ui.text(cx + 100, ey + 34, "(empty)", { size = 20, color = "#5a6074" })
            end
            ey = ey + 96
        end
        -- the sheet
        local sy = ey + 14
        ui.text(cx + 8, sy, string.format("%s  LV %d", P.classes[s.class].name, s.level), { size = 24, color = P.classes[s.class].color })
        local lines = {
            string.format("HP %d / %d     MP %d / %d", floor(s.hp), P.max_hp(), floor(s.mp), P.max_mp()),
            string.format("Armour %.1f     Crit %d%%     Gold %s", P.defense(), floor(P.crit_chance() * 100), G.format_int(s.gold)),
            string.format("XP %d / %d     Kills %d     Deaths %d", s.xp, P.xp_needed(), s.kills, s.deaths),
        }
        for i, ln in ipairs(lines) do ui.text(cx + 8, sy + 34 + (i - 1) * 28, ln, { size = 20, color = "#dfe4f0" }) end
        ui.text(cx + 8, sy + 128, "Quick keys: R heal, X mana, G throw.", { size = 17, color = C.dim })
        -- the bag
        local bx = cx + 520
        ui.text(bx, top, tr("ui.inventory"), { size = 26, color = C.gold })
        local size, gap = 72, 8
        local ev = uikit.slots("bag", inv.bag, bx, top + 40, inv.cols, { size = size, gap = gap, icon = item_icon, tooltip = item_tip, count = inv.bag_n })
        -- a click is the button going UP over the slot it went down on, without a drag (the kit reports `click` on the press AND on the release, which made an item equip twice)
        local dr = uikit.state.drag
        if input.released and ev.hover and dr and dr.grid == "bag" and dr.index == ev.hover and (math.abs(input.x - dr.origin_x) + math.abs(input.y - dr.origin_y)) <= 8 and not dr.via_pad then
            local it = inv.bag[ev.hover]
            if it then ui.run(string.format("Game.player.use_item(%q)", it.id)) end
        end
        if ev.right_click then
            local it = inv.bag[ev.right_click]
            if it and (G.safe or G.state.checkpoint == "stairwell") then ui.run(string.format("Game.shop.sell(%q)", it.id)) end
        end
        local used = 0
        for _, sl in ipairs(inv.bag) do if sl then used = used + 1 end end
        ui.text(bx, top + 40 + 4 * (size + gap) + 4, string.format("%d / %d slots", used, inv.bag_n), { size = 18, color = C.dim })
        ui.text(bx, top + 40 + 4 * (size + gap) + 30, G.state.checkpoint == "stairwell" and "Right-click an item to sell it to the vending machine." or "Click an item to use or equip it.", { size = 17, color = C.dim })
    elseif G.bag_tab == 2 then
        ui.text(cx + 8, top, string.format("%s  -  level %d", P.classes[s.class].name, s.level), { size = 30, color = P.classes[s.class].color })
        ui.text(cx + 8, top + 42, tr("ui.points") .. ": " .. s.points, { size = 24, color = s.points > 0 and C.green or C.dim })
        local y = top + 90
        local names = { str = "Strength", dex = "Dexterity", int = "Intelligence", con = "Constitution", cha = "Charm" }
        local descs = { str = "melee damage", dex = "crit chance, dodge", int = "mana, spell power", con = "health, armour, regeneration", cha = "gold from kills, bard power" }
        for _, st in ipairs({ "str", "dex", "int", "con", "cha" }) do
            local total, base = P.stat(st), s.stats[st]
            ui.text(cx + 8, y, names[st], { size = 26, color = "#eef1f8" })
            ui.text(cx + 250, y + 2, string.format("%d", total) .. (total ~= base and (string.format("  (%d + %d)", base, total - base)) or ""), { size = 24, color = C.gold })
            ui.text(cx + 420, y + 4, descs[st], { size = 18, color = C.dim })
            if s.points > 0 and uikit.button("spend_" .. st, "+", cx + 640, y - 2, 44, 36) then ui.run(string.format("Game.player.spend(%q)", st)) end
            y = y + 54
        end
        local w_ = P.weapon()
        ui.text(cx + 8, y + 20, string.format("Weapon: %s   damage %d-%d   swing %.2fs   reach %.1fm", w_.name, w_.dmg[1], w_.dmg[2], w_.cd / 60, w_.reach), { size = 20, color = "#dfe4f0" })
        ui.text(cx + 8, y + 120, string.format("Contracts: %s", (#G.contracts.held() == 0) and "none" or (function() local n = {}; for _, id in ipairs(G.contracts.held()) do n[#n + 1] = tr("contract." .. id .. ".name") end return table.concat(n, ", ") end)()), { size = 18, color = "#ffcf4a" })
        ui.text(cx + 8, y + 50, string.format("Max HP %d    Max MP %d    Armour %.1f    Crit %d%%    Gold bonus %d%%", P.max_hp(), P.max_mp(), P.defense(), floor(P.crit_chance() * 100), floor(P.gold_bonus() * 100)), { size = 20, color = "#dfe4f0" })
        ui.text(cx + 8, y + 90, string.format("Time played %d:%02d     Kills %d     Deaths %d", floor(s.playtime / 3600), floor(s.playtime / 60) % 60, s.kills, s.deaths), { size = 20, color = C.dim })
    elseif G.bag_tab == 5 then
        ui.text(cx + 8, top, tr("ui.skills"), { size = 30, color = C.gold })
        ui.text(cx + 8, top + 38, tr("ui.skills_hint"), { size = 18, color = C.dim })
        local y = top + 80
        for _, id in ipairs(G.skills.order) do
            local d, lv, n = G.skills.defs[id], G.skills.level(id), G.skills.count(id)
            local nxt = d.thr[lv + 1]
            ui.rect(cx + 8, y, 1180, 74, "#161a26", { radius = 10 })
            ui.rect(cx + 8, y, 1180, 74, lv > 0 and "#7fe0ff" or "#2a2e3c", { radius = 10, outline = true, thickness = 2 })
            ui.text(cx + 24, y + 8, string.format("%s   %s", d.name, lv > 0 and ("LV " .. lv) or "-"), { size = 26, color = lv > 0 and "#ffffff" or "#6a7084" })
            ui.text(cx + 24, y + 42, d.desc, { size = 17, color = C.dim })
            local frac = nxt and (n - (d.thr[lv] or 0)) / (nxt - (d.thr[lv] or 0)) or 1
            bar(cx + 800, y + 26, 340, 18, frac, "#7fe0ff", nil, nxt and string.format("%d / %d", n, nxt) or "MAX", 14)
            y = y + 82
        end
    elseif G.bag_tab == 4 then
        ui.text(cx + 8, top, tr("ui.settings"), { size = 30, color = C.gold })
        local y = top + 70
        for _, name in ipairs({ "music", "sfx", "voice" }) do
            ui.text(cx + 8, y, tr("ui.bus." .. name), { size = 26, color = "#eef1f8" })
            local v = uikit.slider("bus_" .. name, G.music.bus[name], 0, 1.5, cx + 300, y - 4, 520, 36, 0.05)
            ui.text(cx + 850, y, string.format("%d%%", math.floor(v * 100 + 0.5)), { size = 24, color = C.gold })
            if math.abs(v - G.music.bus[name]) > 0.001 then ui.run(string.format("Game.music.set_bus(%q, %.2f)", name, v)) end
            y = y + 70
        end
        local flat = G.state.flags.flat_numbers and true or false
        local nf = uikit.checkbox("flat_numbers", tr("ui.flat_numbers"), flat, cx + 8, y + 10, 700, 36)
        if nf ~= flat then ui.run(string.format("Game.music.set_flat_numbers(%s)", tostring(nf))) end
        y = y + 60
        ui.text(cx + 8, y + 20, tr("ui.settings_hint"), { size = 20, color = C.dim })
        local run = G.run.cur()
        if run then
            ui.text(cx + 8, y + 70, string.format("%s  %s    %s %d    %s", tr("run.seed"), tostring(run.seed), "FLOOR", run.floor or 1, run.mode == "orientation" and "ORIENTATION" or ""), { size = 24, color = "#eef1f8" })
            if uikit.button("new_run", tr("run.new"), cx + 8, y + 120, 420, 48) then ui.run("Game.run.open_menu()") end
        end
    else
        ui.text(cx + 8, top, string.format("Achievements  %d / %d", s.ach_count or 0, #G.announcer.order), { size = 28, color = C.gold })
        local y = top + 44
        local col = 0
        for i, id in ipairs(G.announcer.order) do
            local got = s.ach[id]
            local x = cx + 8 + col * 400
            ui.rect(x, y, 386, 60, got and "#1e2230" or "#10121a", { radius = 10 })
            ui.rect(x, y, 386, 60, got and "#ffcf4a" or "#2a2e3c", { radius = 10, outline = true, thickness = 2 })
            ui.text(x + 12, y + 5, tr("achievement." .. id .. ".name"), { size = 19, color = got and "#ffffff" or "#6a7084" })
            ui.text(x + 12, y + 32, tr("achievement." .. id .. ".desc"), { size = 14, color = got and "#b8c0d4" or "#4a5064" })
            col = col + 1
            if col == 3 then col = 0; y = y + 66 end
        end
    end
    if uikit.button("bag_close", tr("ui.close"), px + pw - 170, py + ph - 56, 150, 40) or (input.keys and input.keys.escape) then G.screen = nil end
end

local function shop_screen(w, h, input)
    uikit.open_screen()
    local s = G.state
    local pw, ph = 900, 780
    local px, py = (w - pw) / 2, (h - ph) / 2 - 10
    local cx, cy, cw = panel(px, py, pw, ph, tr("ui.shop"))
    ui.text(cx + 4, cy + 4, string.format("%s gold", G.format_int(s.gold)), { size = 28, color = C.gold })
    local y = cy + 54
    for i, entry in ipairs(G.shop.stock) do
        local d = G.items.defs[entry.id]
        ui.rect(cx, y, cw, 64, "#161a26", { radius = 10 })
        item_icon({ id = entry.id, count = 1 }, cx + 4, y - 4, 72, 72)
        ui.text(cx + 90, y + 6, d.name, { size = 24, color = d.color })
        ui.text(cx + 90, y + 36, d.desc or "", { size = 16, color = C.dim })
        ui.text(cx + cw - 190, y + 18, tostring(entry.price) .. " g", { size = 26, color = s.gold >= entry.price and C.gold or "#aa5555", align = "right" })
        if uikit.button("buy_" .. i, tr("ui.buy"), cx + cw - 170, y + 10, 150, 44, { disabled = s.gold < entry.price }) then ui.run(string.format("Game.shop.buy(%d)", i)) end
        y = y + 72
    end
    ui.text(cx + 4, y + 10, "Right-click an item in your bag (I) to sell it for half its worth.", { size = 18, color = C.dim })
    if uikit.button("shop_close", tr("ui.close"), px + pw - 170, py + ph - 56, 150, 40) or (input.keys and input.keys.escape) then G.screen = nil end
end

local function death_screen(w, h)
    local P = G.player
    local age = time.tick() - (P.dead_tick or 0)
    local a = min(1, age / 40)
    ui.rect(0, 0, w, h, "#300000" .. string.format("%02x", floor(a * 200)))
    ui.text(w / 2, h / 2 - 120, tr("ui.dead_title"), { size = 120, color = "#ff4040" .. string.format("%02x", floor(a * 255)), align = "center" })
    ui.text(w / 2, h / 2 + 20, tr("ui.dead_sub"), { size = 36, color = "#ffd0d0" .. string.format("%02x", floor(a * 255)), align = "center" })
    ui.text(w / 2, h / 2 + 78, string.format("Killed by %s.   Gold lost to administrative processing: %d", tostring(P.death_src), P.death_gold_lost or 0), { size = 24, color = "#c09090", align = "center" })
end

local function end_screen(w, h, input)
    uikit.open_screen()
    local s = G.state
    ui.rect(0, 0, w, h, "#05060af0")
    ui.text(w / 2, 150, tr("end.title"), { size = 100, color = C.gold, align = "center" })
    ui.text(w / 2, 270, tr("end.sub"), { size = 30, color = C.glee, align = "center" })
    local rows = {
        { "Time", string.format("%d:%02d", floor(s.playtime / 3600), floor(s.playtime / 60) % 60) },
        { "Level", tostring(s.level) }, { "Kills", tostring(s.kills) }, { "Deaths", tostring(s.deaths) },
        { "Gold", G.format_int(s.gold) }, { "Achievements", string.format("%d / %d", s.ach_count or 0, #G.announcer.order) },
    }
    for i, r in ipairs(rows) do
        ui.text(w / 2 - 20, 360 + i * 46, r[1], { size = 30, color = C.dim, align = "right" })
        ui.text(w / 2 + 20, 360 + i * 46, r[2], { size = 30, color = "#ffffff" })
    end
    if uikit.button("end_descend", tr("ui.descend", (G.run.floor_no() or 1) + 1), w / 2 - 190, 650, 380, 56, { color = C.gold }) then ui.run("Game.run.descend(true)") end
    if uikit.button("end_continue", "Keep exploring Floor " .. (G.run.floor_no() or 1), w / 2 - 190, 720, 380, 56) then ui.run("Game.close_end()") end
end

-- ---------------------------------------------------------------------------------------------- the entry point
function H.draw(dt)
    local w, h = ui.size()
    uikit.begin(dt)
    local input = ui.input() or { pressed = {}, keys = {} }
    local s = G.state
    if not s then return end
    hud_world(w, h, input)
    hud_player(w, h, input)
    hud_boss(w, h)
    hud_toasts(w, h)
    if G.minimap then G.minimap(w, h) end
    -- screens
    local sc = G.screen
    if sc == "title" then title_screen(w, h)
    elseif sc == "run" then H.run_screen(w, h, input)
    elseif sc == "loading" then H.loading_screen(w, h)
    elseif sc == "class" then class_screen(w, h, input)
    elseif sc == "bag" then bag_screen(w, h, input)
    elseif sc == "shop" then shop_screen(w, h, input)
    elseif sc == "death" then death_screen(w, h)
    elseif sc == "end" then end_screen(w, h, input)
    elseif sc == "recap" then H.recap_screen(w, h, input)
    elseif sc == "contracts" then H.contract_screen(w, h, input)
    elseif sc == "runover" then H.runover_screen(w, h, input) end
    H.announcer(w, h)
    -- keys (only when no modal asks for the pointer)
    if s.class and sc ~= "death" and sc ~= "class" and sc ~= "end" and sc ~= "title" and sc ~= "run" and sc ~= "loading" and sc ~= "recap" and sc ~= "contracts" and sc ~= "runover" then
        if pressed(input, "i") then G.screen = (sc == "bag" and (G.bag_tab or 1) == 1) and nil or "bag"; G.bag_tab = 1
        elseif pressed(input, "c") then G.screen = (sc == "bag" and G.bag_tab == 2) and nil or "bag"; G.bag_tab = 2
        elseif pressed(input, "o") or (input.keys and input.keys.escape and sc == nil) then G.screen = (sc == "bag" and G.bag_tab == 4) and nil or "bag"; G.bag_tab = 4
        elseif pressed(input, "j") then G.screen = (sc == "bag" and G.bag_tab == 3) and nil or "bag"; G.bag_tab = 3
        elseif pressed(input, "k") then G.screen = (sc == "bag" and G.bag_tab == 5) and nil or "bag"; G.bag_tab = 5 end
    end
    -- (the engine draws the OS cursor when the pointer is released with Esc: no cursor of our own, that made two)
    if input.free and not G.screen and s.class and not G.cutscene then
        local msg = tr("ui.capture")
        local tw = ui.measure(msg, 30) + 60
        ui.rect(w / 2 - tw / 2, h / 2 + 150, tw, 60, "#0b0d14e0", { radius = 12 })
        ui.rect(w / 2 - tw / 2, h / 2 + 150, tw, 60, "#ffd24a", { radius = 12, outline = true, thickness = 3 })
        ui.text(w / 2, h / 2 + 164, msg, { size = 30, color = "#ffffff", align = "center" })
    end
    -- a menu closed: the look takes the mouse back at once (the class choice, the bag, the shop ...), no extra click needed
    if H.prev_screen and not G.screen and s.class and input.free and ui.capture then ui.capture() end
    H.prev_screen = G.screen
    local drop = uikit.finish()
    if drop then ui.run(string.format("inventory.apply_move(%q, %q, %d, %q, %d, %q)", "player", drop.from_grid, drop.from, drop.to_grid, drop.to, drop.split or "")) end
end

function on_hud(dt) H.draw(dt) end
