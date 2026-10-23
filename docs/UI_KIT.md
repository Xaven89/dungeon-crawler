# The widget set and the inventory test

> **Status (2026-10-21): built** (`assets/lib/ui_kit.lua`, `assets/lib/inventory.lua`, `projects/inventory_test`, the HUD input in `script/hud.hpp`, tests in tests/test_lua.cpp "ui kit" and "inventory sample").

The answer to "where does an inventory belong": the **game** owns its rules and data (what an item is, stack sizes, crafting, who may carry what); the **engine** owns what every game needs: drawing and input primitives (the HUD, docs/HUD.md), layout helpers, ready widgets (buttons, sliders, tabs, text fields, scroll areas, **slot grids with drag and drop**, tooltips), focus and **controller navigation**, text with the localization tables and the saving of script state. `assets/lib/inventory.lua` is a sample to copy, not part of the engine's rules. The inventory is the test that showed what was missing.

## What the engine gave the HUD for it
`ui.input()` (the mouse buttons and wheel, the typed text, the keys that went down by group and by name, Shift / Ctrl, the controller's d-pad steps and A / B), `ui.clip(x, y, w, h)` / `ui.unclip()` (scroll areas), `ui.measure(text [, size])` (the width in the UI's font), `ui.cursor(true)` (the script wants the pointer: the mouse is released, a click neither takes it back nor digs). All of it in docs/HUD.md. `include("engine/x.lua")` reads the engine's library `assets/lib/x.lua` (found from the program's place, or `VX_LIB`).

## uikit (`include("engine/ui_kit.lua")`)
Immediate mode, called from `on_hud(dt)`; a widget has an id (a string) and returns what the person did; hover, focus, the text being typed and scroll positions are kept by id.
```lua
function on_hud(dt)
    uikit.begin(dt)                                                  -- first: reads the input, moves the focus
    local x, y, w, h = uikit.panel(100, 100, 500, 400, "Settings")   -- a window: the content rectangle under the title
    if uikit.button("ok", "Close", x, y, 120, 44) then open = false end
    volume = uikit.slider("vol", volume, 0, 1, x, y + 60, 300, 28)
    name = uikit.text_input("name", name, x, y + 110, 300, 36, { hint = "your name" })
    local drop = uikit.finish()                                       -- last: tooltips, the carried item, the focus ring; returns an item dropped on a slot this frame
end
```
| | |
|---|---|
| `button(id, label, x, y, w, h, {disabled, tooltip, color})` | true when clicked (pressed and released on it, or Enter / A while focused) |
| `checkbox(id, label, value, x, y, w)` / `slider(id, value, min, max, x, y, w, h, step)` / `tabs(id, labels, active, x, y, w, h)` | the new value |
| `text_input(id, text, x, y, w, h, {hint, max, filter})` (`filter` is a Lua pattern of what to REMOVE from what is typed: `%D` keeps only digits) | `text, changed, submitted`: typing, Backspace, Delete, arrows, Home / End, Enter submits, Escape leaves |
| `scroll(id, x, y, w, h, content_h, function(top) ... end)` | a clipped area with the wheel and a draggable bar; draw at `y + top` |
| `slots(id, items, x, y, cols, {rows, size, gap, count, icon, tooltip, accept, hotkeys, count_text})` | a grid of slots; `items` is an array of `{id, count, ...}` / false; returns `{hover, click, right_click}` |
| `move_stack(drop, max_stack)` | the standard stack rules for a drop (merge up to the stack size, swap different items, fill an empty slot, `split = "half"` or `"one"`) |
| `grid`, `column`, `row`, `anchor`, `panel`, `label` | layout helpers |
| `tooltip(text)` | a tooltip after the pointer rested for 0.35 s (several lines with `\n`) |
| `open_screen()` | call it every frame a screen is up: it asks for the pointer |
| `theme` | the colours and sizes |

**Drag and drop**: press on an item, move, release on any slot of any grid: `finish()` returns `{from_grid, from, to_grid, to, split, items_from, items_to}` and the game applies it (`uikit.move_stack` or its own rules; the widget never changes the items). Shift while pressing splits half a stack, the right button takes one. With the keyboard or the controller: focus a slot, **Enter / A** picks the item up (it follows the focus), move the focus, Enter / A puts it down.
**Focus**: every button, slider, tab, field and slot is a focus target; the arrow keys, the d-pad or the stick move the focus to the nearest widget in that direction, Tab cycles, a ring is drawn; in a text field the arrows move the caret and Escape gives the focus back.
It draws and reads only: what a click does to the game is the game's code, usually `ui.run("...")` (a logged action at the next tick).

## The inventory sample (`include("engine/inventory.lua")`)
`inventory.new{name, slots, hotbar, columns, items}`, `add` / `remove` / `count` (the hotbar fills first, stacks before empty slots, a stack size per item), `selected_item`, `sort`, `to_table` / `from_table` / `save` / `load` (`project.store`), and `inventory.hud(inv, dt)` for `on_hud`: the hotbar always, the screen with **I** (Escape closes; 1..9 select; a bag grid, a filter field, a Sort button, tooltips with the item's description, a slot counter). Everything that changes the inventory is asked for through `ui.run("inventory.apply_move(...)")` (a logged action), so a replay and a networked session agree and the contents are saved with the project. `projects/inventory_test` is the test level: I, 1..8, G (give an item), H (clear); every widget of the screen works with the mouse and with the keyboard.

## Not built
A retained widget tree and automatic layout (rows and columns are computed by the helpers, not by a layout pass), text wrapping, a multi-line text field, rich text, images in widgets beyond `ui.image` (the item icons are drawn by a function: use `ui.image` there), drag and drop onto the 3D world, fonts for other scripts, a screen reader (docs/ACCESSIBILITY.md), localized labels (use `loc(...)` of docs/LOCALIZATION.md for the strings you pass in).
