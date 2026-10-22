# Conveyor belt

> **Status (2026-10-21): built as an engine feature** (docs/TASKS.md item 15). A **belt node** in the event system: its box is a surface that moves in the contact solver, its texture scrolls, a lever / button / timer starts, stops and reverses it. Demo: `projects/conveyor_belt` (`voxelith --windowed --project projects/conveyor_belt`). The script-only test below it (`projects/conveyor_test`) is kept as the "what a script can do alone" comparison.

## The belt node
```lua
local belt = events.belt{ name = "belt", box = {x0, y0, z0, x1, y1, z1}, dir = {1, 0, 0}, speed = 1.0, texture = "belt", lit = true }
events.connect(lever, "on", belt, "on"); events.connect(lever, "off", belt, "off"); events.connect(button, "on", belt, "reverse")
```
Text form (`event_define`, MCP `event_create`, the Events window "belt"): `{kind: "belt", name, box, dir: "+x" | [x, y, z], speed (m/s, -20..20), texture?: name, lit?: running at the start}`.
- **Surface velocity**: while the node is on, every solid voxel of its box moves along `dir` (a unit vector, made tangent to the contact surface) at `speed` m/s. The contact solver adds it to the relative velocity of a body that touches such a voxel (`PhysicsWorld::surfaceVelocity`, `Contact::surfVel`), so friction carries a crate; no script pushes. A sleeping crate on a belt that starts or stops is woken (`wakeBox`). The player: `PlayerInput::platform` is the belt's velocity under the feet, so a player who stands still is carried and walking is relative to the belt.
- **Commands**: `on`, `off`, `toggle`, `reverse` (flips the direction; a stopped belt keeps the flip for when it starts). A lever's on / off or a button's press fit; `event_connect` refuses the rest.
- **Texture**: `texture = "belt"` (a built-in; any texture of the project works) makes three copies in the project's table, `<node>_on` and `<node>_rev` scrolling with and against the belt at its speed and `<node>_off` still, and the node swaps the voxels' texture byte (`EditOp::textureBox`) when its state changes. The scroll is a `scroll` field of the texture (voxels per second, `docs/TEXTURES.md`), evaluated in `shade.comp` from the frame time: no voxel edits per frame. Without `texture` the belt moves but looks like its material.
- **Physics notes** (round 22): the contact solver makes one contact per world brick (8 x 8 x 8 voxels), so a crate over a single brick has one contact point and could not resist the pitch of a friction drive: on a moving surface the friction rows use the lever arm without its part along the normal (`Contact::raF`), the drive pushes through the body's height and does not tip it. A body on a moving surface does not fall asleep (a belt of 0.1 m/s carries it for ever; it sleeps when the belt stops) and its resting damping works on the speed relative to the belt (`VoxelBody::onMovingSurface`, `surfaceVel`). A running belt can be reversed directly (the crate turns around in about a second). Deleting a running belt gives its voxels the still texture; an undo of something else does not rewrite a belt's texture.
- **Limits**: one direction per node (curves: several belts), speed within ±20 m/s. A belt carries what rests on its top face; a body pushed against its side is not carried.
- **Tests**: tests/test_belt.cpp (velocity, commands, a carried crate with the texture swaps, the player riding), the MCP smoke (a crate carried, stopped by `off`).

## The script-only version (`projects/conveyor_test`)

A test of what the engine can do today, not a feature: a belt 8 m long and 1.5 m wide on a concrete table with brick rails, crates that ride it, a Lua script that does everything (`level.lua`, about 90 lines).
Open it like any project: `voxelith --windowed --project projects/conveyor_test` (the belt is built 6 m in front of the player; no world save, it is rebuilt at each start).

- **The belt moves**: its surface is two voxel layers of light stone with dark metal stripes (4 voxels long, a period of 8). Every time the belt has moved one voxel (`speed * 16 / 60` voxels per tick) the stripes are drawn again one voxel further along +x with `edit.box`, so they travel with the belt. A voxel edit is the only thing a script can animate in the world (no texture offset, no moving voxel body with a surface), so the belt costs 17 box edits per voxel step.
- **The crates are carried**: a wooden 6-voxel crate (`body.box`, 40.5 kg) is a physics body on the belt. There is no surface velocity in the contact solver, so each tick the script reads the crate's position (`body.pos`), smooths its speed along the belt, and pushes it with `body.push` at the point where the belt touches it (a push at the middle tips the crate). The push aims at the belt's speed with a small learned correction (friction eats part of every push): the crates settle at the belt's speed in about two seconds.
- **Spawn and removal**: one crate every 4 s while fewer than 4 are on the belt, at the start end; a crate that falls off the far end is removed.
- **Run-time control** (the `lua` MCP tool or the console): `belt.speed(2.0)`, `belt.stop()`, `belt.start()`. At 2 m/s the crates measured 1.9 to 2.2 m/s.

Measured with the MCP tools (`bodies`, `step`): 1 m/s belt, crates 0.98 to 1.0 m/s after the first two seconds; a screenshot is `~/share/conveyor.png`.

## What the engine needed for a real conveyor (all three are built, see above)
1. **Surface velocity** on a body or on a voxel material (a contact property: the solver adds the belt's velocity to the relative velocity at the contact, so friction carries the load and no script has to push), for straight belts first, then curved ones and a moving platform that carries the player too.
2. **An animated surface**: a per-material or per-region texture scroll (the surface patterns of docs/PAINT.md already have a voxel-unit uv, so an offset that moves with time is cheap in `shade.comp`) instead of redrawing voxels.
3. **An event-system node** (`events.belt{ box, direction, speed }`, on / off / reverse by a signal) so a lever or a plate starts it, and a snap point / array tool (docs/TASKS.md) to build a long belt from pieces.
