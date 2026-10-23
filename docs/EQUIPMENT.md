# Equipment: items on characters

Engine = mechanism, game = items. The engine knows **where** things sit on a body (sockets), **how** an item is shown on it (merged into the part, or a child model that follows it) and
how one item file serves the first-person hand and the third-person body. The game keeps slots, stats and rules (`assets/lib/equipment.lua` is a copy-and-change helper).
Design notes: the plan lives with the round-30 handover; this file is the reference and grows with each phase.

Status: **sockets**, **merge / hide / replace**, **attach** (Lua `model.*` and `player.*`), the `hand` block and the helper are built. Capes follow (see `docs/TASKS.md`).

## Sockets

A socket is a **part of the rig without voxels**: a name, a parent part and a pivot (model voxels). It is posed by its parent like any part (it follows the arm through `attack`,
a clip may even animate it), no body is built for it, and the file format is the one every rig already has. What a part cannot say is how an item *lies* on it, so a socket
may carry a rotation (`socketRot`, degrees, X then Y then Z, in the parent's model frame) that is kept in the file's `ANIM` chunk: `"sockets": { "grip_r": { "rot": [180, 0, 0] } }`
(older readers ignore it).

**Sides.** A socket is named for the **body's** side: the kit figures face +z, so their right hand is at -x, which is the `_l` side of the part names (`hand_l`, `upper_arm_l` ... are at -x, as in `tools/make_creatures.py`).
`grip_r` is therefore a child of `hand_l`: the sword hand is the figure's right, and `attack` swings the `_l` arm.

**Names.** Roles (`inferRoles`) are guessed from part names by prefix (`hand`, `arm`, `head`, `torso`, `tail`, `cape` ...), so a socket must not start with a role word:
`hand_socket` would become the arm's end. The kit's names:

| socket | parent | where | rot |
|---|---|---|---|
| `grip_r`, `grip_l` | `hand_l`, `hand_r` | the palm (60 % of the hand down the arm) | 90, 0, 0 |
| `head_top` | `head` | the top of the head, centre | identity |
| `face` | `head` | the front of the head at eye height | identity |
| `back` | `torso` | the middle of the back (the -z face) | 0, 180, 0 |
| `belt_l`, `belt_r` | `torso` | the side of the body at the crotch layer | identity |
| `shoulder_l`, `shoulder_r` | `upper_arm_r`, `upper_arm_l` | the top of the arm (a pauldron turns with the arm) | identity |

**Item convention.** An item is modelled **pointing +y with its anchor at the bottom** (a sword's handle, a hat's crown, a shield's grip), facing +z. The socket's rotation turns that
into the body's frame. A grip turns +y 90 degrees about x along the fingers: forward at rest, and **up when the forearm is bent a right angle**, which is the fighting stance (sword hand with the blade up and
leaning forward, the shield standing on the other forearm facing forward). The kit figures have a looping clip `ready` for it (`equipment.stance(target)` names the idle that suits what is held); a hat on `head_top`
points up as drawn. A figure that walks with a sword in its hand swings the blade with its arm: there is no armed walk clip yet.

`check-project` warns about a socket named like a body part, and notes a figure (a rig with `walk`) without sockets.

## Making sockets

- Kit figures: `tools/rig_figures.py` finds the landmarks it already needs and adds the nine sockets (the nine kit figures have them).
- Python: `Creature.socket(name, parent, pivot, rot=None)` in `tools/make_creatures.py`.
- A model that is already a file (a converted pack figure, your own): `model_rig_set { id, sockets = { grip_r = { parent = "hand_r", pivot = {x, y, z}, rot = {180, 0, 0} } }, save = true }`
  (MCP; the same table through the Lua `model.rig(id, { sockets = ... })`). A name that exists is moved (only the given fields change), `null` (Lua: `false`, a table cannot hold nil) removes a socket, a part with
  voxels is refused. A live model takes added and removed sockets (the per-part arrays follow); removing one from a model that is limp or has a procedural layer is refused, because
  the parts after it would change index.
- `model.rig(id)` / `model_rig` list them (`sockets`, and `socket_rot` on a part).

## Merging an item into a part

```lua
child = model.attach(m, "sword.vxm", "grip_r" [, { name = "sword", mode = "auto", offset = {0, 0, 0}, rot = {0, 0, 0}, anchor = {x, y, z}, scale = 0.3, swap = {..}, hide_parts = { "hair" } }])   -- child: 0 (merged) or the item's own model id
model.detach(m [, name_or_socket])              -- no name: everything
model.hide_part(m, "head", true)                -- the part's own voxels are not drawn (items merged into it still are)
model.replace_part(m, "torso", "plate.vxm")     -- the part is drawn from a model in the figure's own grid; nil brings the original back
model.sockets(m)  -- { grip_r = { parent = "hand_r", pivot = {..}, rot = {180, 0, 0} }, ... }
model.attachments(m)  -- { { name, target, mode = "merge", file, replacement } }
player.attach(file, socket [, opts [, player]]) / player.detach([name [, player]]) / player.hide_part(part, on [, player]) / player.replace_part(part, file | nil [, player])
```

`m` is a model id or an agent id (a model agent's body). Files are relative to the script, or a kit model by its plain name.

How it is drawn: the item's voxels are **baked into the body of the part the socket rides** (the part itself when it has voxels). The item then follows every clip, the procedural layer and the agent's turn
because it *is* the part's body: **no extra body**, so the renderer's 48 bodies per 16 x 16 tile (docs/ANIMATION.md) do not move. Placement: the item's `anchor` part (else the bottom centre) goes to the socket's pivot
(`offset`, metres along the model's x, y, z, moves it), the item is turned by the socket's `rot` composed with `rot`; the result must be one of the 24 axis rotations (else the call is refused with the reason)
and the cell grid stays rigid (the rotation is about cell centres, the shift is rounded once). Where an item overlaps the part's own voxels the item is drawn. One item per `name` (default: the socket's name):
a second item on a socket replaces the first. The palette swap of the model applies to the item too.

`replace_part` is the armour mechanism: the replacement is a model **drawn in the figure's own grid** (paint the plate torso over the figure in MagicaVoxel and export that piece alone, or cut it with
`tools/vox_split.py`): its voxel at cell c is drawn where the original's voxel at c was, under every clip, because the part's pivot is untouched. A replacement of another size works when it has an `anchor`
part (the anchor goes to the part's pivot). `hide_part` of a replaced part is refused: `replace_part(part, nil)` brings it back. There is no `hair` part in the kit figures (hair is head voxels): a helmet
covers the head; cut a `hair` part into the figure to hide it.

Limits of merging (stated by the call that hits them; `mode = "auto"` then attaches instead): the item must have the model's own voxel scale; a part's body cannot pass 256 voxels per axis with its items
(a 2 m pike on a 0.6 figure is 53 voxels); items are merged into models that are only drawn (the player's body, a proxy agent, `model.spawn{ visual = true }`): a model with physics bodies
(`collision = "parts"`) refuses a merge (an attached item works), and `hide_part` works on it (the body stays, for collision, and is not drawn). Items are in no hash and no save; a script that equips runs on every peer and in a
replay. A new `player.model()` starts without items.

## Attaching an item as a model of its own

`mode = "attach"` (or `"auto"` when merging does not fit: the item has several parts or clips, another voxel scale, a rotation that is not a quarter turn, the model has physics bodies, or the merged body would pass 256 voxels)
spawns the item as a **visual model of its own** that follows the part: every tick, before it is posed, the engine reads the parent's *drawn body* of the part the socket rides (so the item stays in the hand of a limp
or pushed model too) and places the child there: the child's `anchor` (its `anchor` part, or the option, else its bottom centre) on the socket, turned by the socket's `rot` composed with `rot` (**any angle**), moved by `offset`.
The child has its own voxel scale (`scale`, e.g. a fine sword on a coarse figure), its own clips (`model.play(child, ...)`), its own procedural layer, its own palette `swap`, and the bodies of the picture's temporal filter
see its real speed (a swung blade is not smeared). It costs the item's bodies (a sword of one part: one), which count against the renderer's 48 bodies per 16 x 16 tile (docs/ANIMATION.md): **merge what is rigid, attach what must
move on its own**, at most 8 attached bodies per figure. When the part the item hangs from has no body (hidden, destroyed) the item is not drawn until it does. Removing the parent (or `detach`, or another item in the same slot)
removes the child and gives its bricks back. A moved parent (`model.move`) takes its children along without a speed; items may hang on items four deep.

## The kit's sample items

`assets/prefabs/props/items` (plain names, made by `tools/make_items.py`; all at voxel scale 0.6, one part, pointing +y with an `anchor` part, a `hand` block for the held ones): **weapons** `iron_sword` (1 m), `battle_axe`, `wooden_staff`;
**worn** `iron_helmet`, `wizard_hat` (`head_top`), `pauldron` (`shoulder_l/r`, mirror it), `cape` (`back`, a 3-link spring chain, attach mode), `round_shield` (`grip_l`, faces +z);
**the office kit** `mop`, `torch` (the flame is the emissive `flame` material), `lute`, `stapler`, `clipboard`, `calculator`. Held items face outward from the carrier in the `ready` stance (a clipboard shows its paper to the viewer);
`rot = {0, 180, 0}` turns one to face the carrier. `tools/item_anchor.py` makes an item from a loose `.vox`; a new one in `make_items.py` is a ten-line function.
