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
Actions: forward back left right jump down sprint use dig build fly jetpack flip torch explode demolish ragdoll brush_up brush_down menu. Sources: `key:NAME` (letters, digits, space shift ctrl alt escape tab enter, arrows, f1..f10, plus minus comma period home end pageup pagedown), `mouse:left|right|middle|wheelup|wheeldown`, `pad:a b x y lb rb back start guide l3 r3 lt rt dpad_up dpad_down dpad_left dpad_right lstick_up/down/left/right rstick_up/down/left/right`. A physical key that some action uses as a source stops meaning itself (W does nothing when forward is on I). A line with an error is reported in the log and skipped. The editor and tool-panel keys that are not actions (F1..F12, the number keys, Z / X undo ...) are not remapped.

## Devices that are not controllers
Only a joystick device with at least 4 axes and 8 buttons that is not named like a pointer or a keyboard counts as a controller. Sunshine / Moonlight create a virtual absolute mouse ("libvirtualhid Mouse (Absolute)") that Linux also lists as `/dev/input/jsN`, with two axes resting at -1: read as a stick it made the player walk on its own. Such a device is now ignored (one line on stderr says so). `VX_NO_PAD=1` switches the controller off altogether.
