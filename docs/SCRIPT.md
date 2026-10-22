# The control language (`--script`, MCP `run_script`)

A script is the player's controls as text: the same grammar drives `voxelith --script "..."` (a scripted headless run), the window's tour mode and the `run_script` tool of the MCP server.
It runs at the fixed 60 Hz tick, with gravity, physics and destruction exactly like play; everything it does is an action in a recording.

```
A script is a comma separated list of tokens, run at the fixed 60 Hz tick; numbers of one token are separated by / (not by commas).
Tokens that take time (N = ticks, 60 per second):
  idle:N  fwd:N  run:N  back:N  left:N  right:N  thrust:N     hold that input for N ticks (run = fwd with Shift)
  jump                                                          one tick of the jump key
  pan:YAW/PITCH/N                                               turn the view by YAW and PITCH degrees over N ticks
  arc:N/YAW                                                     walk forward for N ticks while turning YAW degrees
Instant tokens (angles in degrees; positive turn:D turns right, positive pitch:D looks up; the tower spot faces +x):
  turn:DEG  pitch:DEG   turn / tilt the view at once         tp:K        teleport spot K (1 tower, 2 planet A, 3 planet B, 4 flip room, 5 tube, 6 launch pad, 7 liquid yard, 8 habitat tube)
  fly  walk             switch the movement mode (no number)  eye:x/y/z/tx/ty/tz   put the camera at x y z (metres) looking at tx ty tz, fly mode
  view:x/y/z/tx/ty/tz   the same, relative to planet A
  dig:R  boom:R  fire:R  carve a sphere / blast / set alight at the look point, radius R voxels (1 voxel = 6.25 cm)
  rain:0|1  flip  doll  demolish  pour:N                        rain on or off, the flip-room switch, a ragdoll, the tower's charges, N grains of sand
  stamp:SHAPE/MAT/SIZE/MODE  copy:HALF  paste:ROT  undo  redo   the editor at the look point (shape 0 sphere 1 cube 2 disc 3 rough, MAT id, mode 0 replace 1 fill air 2 paint)
  probe  bodies                                                 log the gravity at the player / the bodies
  save                                                          save the edited chunks (F11)
  use  use:ID                                                   press the button / lever you look at (within 3.5 m), or the node with this id (the E key)
  grab  grab:ID  release  throw:SPEED                           hold the body you look at (within 3.5 m) or the body with this id; let go; let go with a throw along the view (default 8 m/s)
Example: --script "idle:60,turn:90,pitch:-10,fwd:120,dig:14,idle:30"   (`tour` is a built-in script)
```

Notes
- Digging, blasts and fires act at the look point: turn and pitch first, then `dig:14`.
- `pitch:-10` looks down, `turn:90` turns right; the tower spot faces +x.
- Numbers of one token are separated by `/`, tokens by commas (`pan:90/-10/60`).
- Instant tokens (`dig`, `boom`, `tp`, `stamp` ...) take no time of their own; a blast or dig that ends a script is followed by one tick so that its edits are in the world.
- `eye:x/y/z/tx/ty/tz` puts the camera at (x, y, z) metres looking at (tx, ty, tz) and switches to fly mode. For a free camera that does not move the player use the MCP `screenshot` tool.
- Built-in scripts: `tour` (every phase of the demo), `soak`, `soakstill`, `aerial`, `storm`, `valley` (the gates).
