# The game's HUD, from Lua

A level script draws its own HUD: define `on_hud(dt)`; it is called once per drawn frame (not per tick) and issues immediate-mode commands in a virtual space **1080 units high** (`ui.size()` gives `w, h`: the width follows the window's aspect ratio, so anchoring to the right edge is `w - 20`). The commands are drawn over the picture by the tool UI layer, whether or not the panels are shown. The first three lines of the Lantern Cove (name, position, visits) are the example.

```
function on_hud(dt)
    local w, h = ui.size()
    ui.text(w - 20, 20, "score " .. project.fetch("score", 0), { size = 30, color = "#ffcc00", align = "right" })
    ui.bar(20, h - 40, 300, 14, player_health, "red")                 -- a bar: fraction 0..1, fill colour [, background]
    ui.rect(10, 10, 200, 20, { 1, 0, 0, 0.5 })                         -- x, y, w, h, colour [, { radius = 6, outline = true, thickness = 2 }]
    ui.line(0, 0, 100, 100, 0xff8000, 3)
    ui.circle(w / 2, h / 2, 6, "white", { outline = true })            -- a crosshair dot
    if ui.button("Open", 300, 300, 120, 40) then                        -- true in the frame it was clicked (pointer free: panels shown or the mouse released)
        ui.run("events.command(events.find('gate'), 'open')")           -- code run as a logged action at the next tick
    end
end
```
**Colours**: `"#rrggbb"`, `"#rrggbbaa"`, a name (white black red green blue yellow orange grey cyan), a number (`0xRRGGBB`, or `0xRRGGBBAA` above 24 bits), or a table `{ r, g, b [, a] }` in 0..1 (or 0..255 when any value is above 1). **Text** options: `size` (default 24), `color`, `align` (`left` `center` `right` of x), `shadow` (default on). `ui.mouse()` gives `{ x, y, down, clicked }` in the virtual space, or nil while the look has the mouse.

**It draws and reads, it does not change the world**: on_hud runs outside the tick, so it cannot be part of the simulation (and in a networked session each peer draws its own). Edits, bodies, events commands and `project.store` writes from inside it are refused with a message; `ui.run(code)` is the way to act: the code is run as an action (logged, replayed, sent to the other peers). At most 3,000 commands a frame and 16 `ui.run` calls; text is cut at 400 characters; the usual 20 million instruction limit applies to the call. In a picture nobody is looking at (the MCP `screenshot {hud: true}`, a headless run with `--hud-lua`) `on_hud` is called with an **idle input** (no pointer, no keys, `ui.input().free` false) a few times, and what its buttons would run with `ui.run` is dropped: a picture never logs an action. Without `hud: true` / `--hud-lua` the picture is the world only.

**Pictures**: `ui.image(x, y, w, h, "images/icon.png" [, { tint = colour, uv = {u0, v0, u1, v1} }])` draws a PNG of the project (path relative to the project; 8 or 16 bit grey / colour / palette, with or without alpha, at most 2048 x 2048). It is read once and kept (at most 64 different pictures, 64 MB), uploaded to the GPU the first time it is drawn; `ui.image_size("icon.png")` returns its width and height in pixels (to lay out by). `tint` multiplies the colours (and the alpha: a fading icon); `uv` picks a part (a sprite sheet). **SVG** works too (`images/lantern.svg`): the drawing is rasterised (NanoSVG: paths, fills, strokes, gradients, transforms; not text, filters or masks) for the size you draw it at, at twice the pixels in steps of 32 so that it stays sharp when the window is bigger than 1080 high; one raster is kept per size it is drawn at (they count against the 64 pictures and the 64 MB), so draw an icon at a few sizes, not at a different one every frame. `ui.image_size("x.svg")` returns the size the file declares. A picture that cannot be read is an error of the script's HUD (the line is shown in the log) and nothing else is drawn that frame.

**More input and drawing** (the base of the widget set in docs/UI_KIT.md): `ui.input()` returns `{x, y, free, down, clicked, released, right_down, right_clicked, wheel, text, shift, ctrl, keys = {up, down, left, right, enter, escape, tab, backspace, delete, home, end}, pressed = {i = true, ["1"] = true ...}, pad_dx, pad_dy, pad_a, pad_b, actions = {attack = true}, actions_up, held}` (`actions` / `actions_up` / `held` are the custom actions of input.cfg, docs/INPUT.md; the keys and the pad are true / steps in the frame they went down, a held d-pad repeats; `pressed` names every key that went down with the names of `input.cfg`); `ui.clip(x, y, w, h)` / `ui.unclip()` cut the drawing to a rectangle (they nest); `ui.measure(text [, size])` is the width of a text in HUD units; `ui.capture()` makes the look take the pointer at once (a click does it otherwise; `ui.input().captured` / `cursor_visible` say what it is now: docs/INPUT.md "The pointer"); `ui.cursor(true)` asks for the pointer while a screen is up (the mouse is released, a click neither takes it back nor digs). A widget library for it: `include("engine/ui_kit.lua")` (docs/UI_KIT.md).

Not built: a retained widget tree (the kit is immediate mode), fonts other than the UI's.
