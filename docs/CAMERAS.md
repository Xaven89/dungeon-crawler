# Cameras

The picture is drawn from a *camera*; the simulation does not care which. Three modes (`0` (or `Home`) cycles them in a running game, `camera.mode("...")` from Lua; `--check-project` and the MCP know the table too):

| mode | what you see | how you control it |
|---|---|---|
| `first` | the player's eyes (the default) | mouse look, WASD walks |
| `third` | from behind the player, `distance` metres back and `lift` above the eyes, pulled in front of walls; the player is drawn as a box with a nose | as first person; the crosshair is still the eyes' ray (what you aim at is what the eyes see) |
| `editor` (`top`, `god`, `rts` are aliases) | a god view for building: it looks at a *focus point* on the ground from above (`pitch`, `zoom`), the pointer is free. It is **only a camera**: the player stays parked where it is, gravity fields do not turn it (up is world +y; `local_up` makes it follow the gravity at the focus on a planetoid), nothing pulls it in front of a tree, a roof or the rock of a cave | WASD / the left stick pan (Shift faster; the focus follows the floor under it, looking down from 2 m above it so a crown is never the floor, and climbs at most `climb_rate` = 8 m/s), the wheel zooms, the middle button or the arrow keys turn and tilt, **a click acts at the pointer** (LMB digs, RMB builds, F blasts, B torches; E presses a button within 40 m of the camera along the pointer's ray; with the editor on (Tab) the brush places at the pointer, Q switches to the selection tool: docs/EDITOR_MODE.md); no hand and no seat while it is on (the vehicle stops when you switch) |

```lua
camera.mode("third")                 -- first | third | editor; returns the mode name; camera.mode() just asks. An unknown name is an error.
camera.set { distance = 5, lift = 0.5 }                -- third: metres behind / above the eyes
camera.set { zoom = 40, pitch = 60, yaw = 90, pan_speed = 1.2, fov = 70, local_up = 0, climb_rate = 8 }   -- editor: metres, degrees, focus points per second per metre of zoom
camera.focus(x, y, z)                -- editor: the point on the ground (metres) the camera looks at
```

## How it works
* `app/view_camera.*` is plain geometry (no Vulkan, no world): `ViewCamera::view` turns the player's eye / view and the settings into the camera pose and the ray a click goes along; a ray callback (the world's `raycastWorld`) pulls the camera in front of walls and lets the focus follow the ground. Tests: `tests/test_view_camera.cpp`.
* The pose goes to the renderer through `cameraFromPlayer()` in `main.cpp`, for the window, for headless pictures and for the MCP `screenshot` (without `eye` / `target`).
* **The editor camera does not move the player.** It is machine-local view state like the third-person camera: the player's state line and the recording do not change, other players in a networked session see it standing where it was. What the simulation needs from it goes through one logged action, `view_centre {chunk x, chunk z, on, player, height}`, sent when the focus crosses a chunk (at most every 10 ticks) and when the camera is switched off: the world streams around that chunk too (`ChunkStreamer::setExtraCentres`) and bodies near it stay awake, in a plain session, in a recording, in a replay and on every peer alike. The camera itself is not in the log.
* Clicks: `aimEyeM()` / `aimDir()` in `main.cpp` are the ray of an action. Actions are logged with the numbers they resolved to (the cell, the radius), never with the view, so a replay does not need the camera.
* Scripts' `dig:R`, `boom:R`, `fire:R` tokens and the editor panels' "at the look point" buttons still use the centre of the picture, which is where the camera looks (the focus) in the editor camera, not where the parked player looks.

## Not built
A camera that follows a vehicle or an agent by itself (`camera.follow`), shoulder offset and an over-the-shoulder aim, edge scrolling, camera paths (`camera.path{...}` with keyframes), split screen, a picture-in-picture, the player's body as a real model (it is a debug box), selecting and ordering agents with a drag box (the next step for a strategy game; `agent.*` has the calls).
