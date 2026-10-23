# Input: bindings and the controller

The game reads the usual keys; the **input mapper** (`app/input_map.*`) rewrites the frame's input first, so rebinding and the controller need no changes in the game code. Remapping never touches determinism: the replay records the player's state, not the keys.

## The controller
A Linux joystick device (`/dev/input/js0..7`, the kernel's joystick API, no library; Sunshine creates a virtual pad for a Moonlight client that has one, so it works on :90). It is looked for every two seconds, so plugging in and out while the game runs is fine. The layout is the Xbox one the kernel reports (`pad:button12` etc. name a button by the kernel's number for other pads).

| control | does |
|---|---|
| left stick | walk (analog: a small push is a slow walk), radial dead zone |
| right stick | look (radians per second at full deflection: `look_speed`) |
| A | jump (in fly mode: up) |
| B | down |
| X | use / grab (E) |
| Y | walk / fly (V) |
| RB | sprint |
| RT / LT | dig (left mouse) / build (right mouse) |
| d-pad up / down | brush size |
| Start | the tool panels (Tab) |
| Back | flip the gravity room (G) |
| R3 / L3 | jetpack (C) / torch (B) |

## input.cfg
`voxelith --dump-input > ~/.config/voxelith/input.cfg` writes the defaults to edit. Read from `~/.config/voxelith/input.cfg`, then the project's `input.cfg`, then `--input FILE`, each on top of the last. One line per action, a list of sources (any of them triggers it); `none` unbinds:

```
forward = key:i, pad:lstick_up
jump = key:space, pad:a
sprint = key:shift, pad:rb
dig = mouse:left, pad:rt
deadzone = 0.2          # radial, 0 .. 0.9
look_speed = 2.4        # rad/s at full deflection
invert_look = off
toggle_sprint = off     # accessibility: press to start running, press again to stop
toggle_jetpack = off
```
Actions: forward back left right jump down sprint use dig build fly jetpack flip torch explode demolish ragdoll brush_up brush_down menu undo redo rain clock (the last four were raw keys, Z X Y N: now they can be rebound or unbound). Sources: `key:NAME` (letters, digits, space shift ctrl alt escape tab enter, arrows, f1..f10, plus minus comma period home end pageup pagedown), `mouse:left|right|middle|wheelup|wheeldown`, `pad:a b x y lb rb back start guide l3 r3 lt rt dpad_up dpad_down dpad_left dpad_right lstick_up/down/left/right rstick_up/down/left/right`. A physical key that some action uses as a source stops meaning itself (W does nothing when forward is on I). A line with an error is reported in the log and skipped. The editor and tool-panel keys that are not actions (F1..F12, the number keys, Z / X undo ...) are not remapped.

## Devices that are not controllers
Only a joystick device with at least 4 axes and 8 buttons that is not named like a pointer or a keyboard counts as a controller. Sunshine / Moonlight create a virtual absolute mouse ("libvirtualhid Mouse (Absolute)") that Linux also lists as `/dev/input/jsN`, with two axes resting at -1: read as a stick it made the player walk on its own. Such a device is now ignored (one line on stderr says so). `VX_NO_PAD=1` switches the controller off altogether.

## Game mode: a game is not the sandbox
The engine starts as a sandbox: LMB digs, RMB builds, Z undoes the world (also your level's build), Y makes rain, N and M move the clock, 1 to 8 teleport to the demo's spots, F1 to F10 toggle renderer features. A game does not want any of it. **`game = on` in `project.cfg`** (or `--game`) switches the sandbox off:
- the **actions** `dig build fly jetpack flip torch explode demolish ragdoll brush_up brush_down menu undo redo rain clock` lose their default sources (a line of `input.cfg` that names one brings it back: `dig = mouse:left`);
- the **raw keys** that are not actions do nothing: the number keys 1 to 8 (teleports), M (stop the clock), **T (the orbit autopilot: the camera flies off and the player stays)**, F1 to F10 (the renderer toggles; `--debug-keys` brings these three back for the author), the editor keys. Tab opens nothing (`--ui` still starts the tool panels for the author);
- what stays: movement, E (use), Space, Shift, Ctrl, 0 / Home (the camera: first / third person), **F3** (the HUD text), **F5** (a screenshot to ~/share), **F11** (save), End (mute), Plus / Minus (look speed), Esc, F12, `--hud 1`.
`status` reports `game_mode`. A recording keeps working: the actions that are gone are simply never pressed.

## Custom actions: the mouse and the pad for a game's own actions
A line `action.NAME = source, source ...` in `input.cfg` defines an action of the game (NAME: letters, digits, `_`; up to 8 sources, the same `key:` / `mouse:` / `pad:` syntax):
```
action.attack  = mouse:left, key:f, pad:rt
action.ability = key:q, pad:x
```
The engine reads them from the **raw** keyboard, mouse and pad (so `dig = none` frees the left button for `action.attack`) and logs every change as an action, so **a recording replays them and in a networked session every player's actions reach every machine at the same tick**. In the script:
```lua
function on_action(name, down, player)          -- in the simulation, at the tick the action took effect (down: true when pressed, false when released)
    if name == "attack" and down then attack(player) end
end
if input.down("attack", player) then ... end   -- is it held now (the state the logged actions made; player 0 by default)
```
`ui.input()` in `on_hud` has `actions` (the actions that went down this frame: `actions.attack == true`), `actions_up` and `held`. The pointer being free (a panel or `ui.cursor` is up) or a text field having the keyboard does not count: a held action goes up. Losing the window's focus lets go of everything. Menus use the usual `ui.input()` keys.

## The pointer: when the look has it, when it is free
In the window the pointer is either **captured by the look** (grabbed, hidden, warped back to the middle at every move: the mouse turns the player) or **free** (the usual OS arrow, clicks go to panels and to the script's HUD). It is free at the start; the engine decides like this:
- A **left or right click in the window** (read from the *raw* buttons: it does not matter what `dig` / `build` or custom actions are bound to, `game = on` and `dig = none` included) captures it, and that click does nothing else. **Esc** toggles it. Tab (the editor / panels), the top-down camera and the orbit demo free it.
- `ui.cursor(true)` in `on_hud` (a menu, an inventory, the class screen) **releases** the grab while it is asked for (every frame) and a click does not take it back; the OS arrow is shown (`ui.input().cursor_visible`, `ui.input().captured`, `ui.input().free`). When the script stops asking, the pointer stays free until a click, or until the script calls **`ui.capture()`** (the look takes it at once, e.g. when a screen is closed with a key).
- `action.attack = mouse:left` and the like are read from the raw buttons too and do not take part in this; while the pointer is free (or a panel has it) mouse sources do not count and a held action goes up.
- The window starts with an arrow (a game) or none (the orbit autopilot demo, so that a streamed picture has no arrow); the arrow is an X font cursor, so it shows on a headless display whose root cursor is nothing. Capturing hides it, releasing shows it again. The grab is `XGrabPointer` plus a warp to the middle on every motion event (core X events, not XInput2 raw): a streaming host with an *absolute* virtual mouse fights the warp. **In Moonlight use the relative mouse mode** (Ctrl+Alt+Shift+M toggles it, or turn off "optimize mouse for remote desktop") for mouse look.
