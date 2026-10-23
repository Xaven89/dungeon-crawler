-- hud_run: the screens of the run (G.screen "run": the seed and the way in, "loading": the floor is being built) and the floor label.
Game = Game or {}
local G = Game
local H = G.hud
local C = H.C
local floor, max, min = math.floor, math.max, math.min

H.seed_text = nil

-- the way in: a seed and two doors
function H.run_screen(w, h, input)
    uikit.open_screen()
    ui.rect(0, 0, w, h, "#05060af2")
    ui.text(w / 2, 120, tr("run.title"), { size = 84, color = C.gold, align = "center" })
    ui.text(w / 2, 220, tr("run.sub"), { size = 26, color = C.dim, align = "center" })
    if not H.seed_text then H.seed_text = tostring(G.run.entropy_seed(input.x, input.y)) end
    ui.text(w / 2 - 330, 292, tr("run.seed"), { size = 30, color = "#eef1f8" })
    local txt = uikit.text_input("run_seed", H.seed_text, w / 2 - 200, 284, 300, 46, { hint = "123456", max = 9, filter = "digits" })
    if txt and txt ~= H.seed_text then H.seed_text = txt end
    if uikit.button("run_roll", tr("run.roll"), w / 2 + 120, 284, 200, 46) then H.seed_text = tostring(G.run.entropy_seed(input.x, input.y)) end
    local seed = tonumber(H.seed_text) or 1
    local cw, ch = 520, 330
    local x1, x2, y = w / 2 - cw - 30, w / 2 + 30, 380
    for i, spec in ipairs({ { x1, "orientation", "#6fd0ff", false }, { x2, "dungeon", "#ff8a3c", true } }) do
        local x = spec[1]
        local hover = uikit.over(x, y, cw, ch)
        ui.rect(x, y, cw, ch, hover and "#1b2030f2" or "#10131cf0", { radius = 16 })
        ui.rect(x, y, cw, ch, spec[3], { radius = 16, outline = true, thickness = hover and 5 or 3 })
        ui.text(x + cw / 2, y + 22, tr("run." .. spec[2] .. ".name"), { size = 40, color = spec[3], align = "center" })
        local ly = y + 82
        for _, ln in ipairs(H.wrap(tr("run." .. spec[2] .. ".blurb"), 22, cw - 50)) do ui.text(x + 26, ly, ln, { size = 22, color = "#dfe4f0" }); ly = ly + 28 end
        if uikit.button("run_" .. spec[2], tr("run.go"), x + 60, y + ch - 80, cw - 120, 56, { color = spec[3] }) then
            ui.run(string.format("Game.run.start(%d, %s)", seed, tostring(spec[4])))
        end
    end
    ui.text(w / 2, y + ch + 36, tr("run.hint"), { size = 20, color = C.dim, align = "center" })
end

-- the veil while a floor is built
local tips = { "loading.1", "loading.2", "loading.3", "loading.4", "loading.5" }
function H.loading_screen(w, h)
    uikit.open_screen()
    ui.rect(0, 0, w, h, "#05060afa")
    local run = G.run.cur() or {}
    ui.text(w / 2, h / 2 - 150, tr("loading.title"), { size = 64, color = C.gold, align = "center" })
    ui.text(w / 2, h / 2 - 70, tr("loading.floor", run.floor or 1), { size = 40, color = "#ffffff", align = "center" })
    local frac = G.floorgen and G.floorgen.progress() or 0
    ui.bar(w / 2 - 300, h / 2 + 10, 600, 22, frac, "#ffcf4a", "#1a1d28")
    local tip = tips[1 + (floor(time.tick() / 240) % #tips)]
    ui.text(w / 2, h / 2 + 70, tr(tip), { size = 24, color = C.dim, align = "center" })
    ui.text(w / 2, h - 60, tr("run.seed") .. " " .. tostring(run.seed or ""), { size = 22, color = "#5a6074", align = "center" })
end

-- the place, under the title (top left)
function H.floor_label()
    local run = G.run.cur()
    if not run then return "FLOOR 1" end
    local label = "FLOOR " .. (run.floor or 1)
    if run.mode == "orientation" then label = label .. " ORIENTATION" else label = label .. "  SEED " .. tostring(run.seed) end
    return label
end

-- the recap episode at the stairs
function H.recap_screen(w, h, input)
    uikit.open_screen()
    local r = G.show.recap or {}
    ui.rect(0, 0, w, h, "#05060af2")
    ui.text(w / 2, 70, tr("recap.title", r.floor or 1), { size = 70, color = C.gold, align = "center" })
    ui.text(w / 2, 150, tr("recap.sub"), { size = 24, color = C.glee, align = "center" })
    local rows = {
        { "recap.time", string.format("%d:%02d", floor((r.secs or 0) / 60), (r.secs or 0) % 60) },
        { "recap.kills", tostring(r.kills or 0) }, { "recap.best_hit", tostring(r.best_hit or 0) }, { "recap.combo", "x" .. tostring(r.best_combo or 0) },
        { "recap.gold", G.format_int(r.gold or 0) }, { "recap.crates", tostring(r.crates or 0) }, { "recap.stains", tostring(r.stains or 0) },
        { "recap.deaths", tostring(r.deaths or 0) }, { "recap.lowlight", (r.worst_hit or 0) > 0 and string.format("%d (%s)", r.worst_hit, r.worst_src) or "-" },
    }
    for i, row in ipairs(rows) do
        local y = 210 + (i - 1) * 46
        ui.text(w / 2 - 40, y, tr(row[1]), { size = 28, color = C.dim, align = "right" })
        ui.text(w / 2, y, row[2], { size = 28, color = "#ffffff" })
    end
    -- the rank and the audience
    local rx = w / 2 + 420
    ui.text(rx, 230, tr("recap.rank"), { size = 26, color = C.dim, align = "center" })
    ui.text(rx, 262, r.rank or "D", { size = 150, color = ({ S = "#ff4fa3", A = "#ffcf4a", B = "#7fd0ff", C = "#a0a8b8", D = "#707890" })[r.rank or "D"], align = "center" })
    ui.text(rx, 440, string.format("%s %s", tr("show.viewers"), G.format_int(r.views or 0)), { size = 24, color = "#ff6a8a", align = "center" })
    ui.text(rx, 474, string.format("%+d %s", r.followers or 0, tr("show.followers")), { size = 22, color = "#ffd24a", align = "center" })
    local ly = 640
    for _, ln in ipairs(H.wrap(r.line or "", 26, 1100)) do ui.text(w / 2, ly, ln, { size = 26, color = "#dfe4f0", align = "center" }); ly = ly + 34 end
    if uikit.button("recap_go", tr("ui.descend", (r.floor or 1) + 1), w / 2 - 190, h - 130, 380, 60, { color = C.gold }) then ui.run("Game.run.descend(true)") end
    if uikit.button("recap_back", tr("recap.back"), w / 2 - 190, h - 60, 380, 44) or (input.keys and input.keys.escape) then ui.run("Game.close_end()") end
end
