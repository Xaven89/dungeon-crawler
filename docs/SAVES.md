# Saves, versions and the script store

A project's state lives in four places, all next to each other and all versioned (`core/save_version.hpp`, `kSaveVersion = 2`):

| file | what | format |
|---|---|---|
| the `--save` file (`world.vxs`) | the edited chunks | an append-only log; version 2 starts with a header record `VXSH` + the version (20 bytes); a file without one is version 1 (chunk records did not change, so it reads and appends as before) |
| `.prefabs/tracked.txt` | the placed prefabs | text, first line `#version 2` |
| `.events/state.txt` | the event nodes' levels and doors | text, first line `#version 2` |
| `.state/store.json` | the script's `project.store` values | JSON `{ "version": 2, "values": { ... } }` |

**A file of a newer version than the engine knows is refused with a message and left exactly as it is** (the world save: the engine will not start on it; the text files: not read). Never "half read and overwrite". When a format changes: bump `kSaveVersion`, keep the reader for the old version (the next save writes the new one), add a test with a file of the old shape.

## The script store

```
project.store(key, value)      -- numbers, booleans, strings and tables of them; nil removes the key
project.fetch(key [, default]) -- reads it back, also after a restart
project.keys()                 -- sorted
```
Keys are 1 to 64 characters. A table with the keys 1..n is a list; otherwise string and number keys (a number key is written `"#3"`, a string key that starts with `#` gets another `#`), so tables come back as they went in. Integers stay integers. Limits: 12 levels (this also stops a table that contains itself), 10,000 entries a table, 1 MB for the whole store; functions, userdata and NaN / infinity are refused with a message. A value that is refused leaves the store as it was.

It is written with the world save (the `save` action, F11, the exit save), read before the level script's `on_start`, copied into a recording (`store_0.json`) and read from there by a replay, and **mixed into the session hash when it is not empty**: two peers whose quest counters differ have diverged, and a replay shows it. Store what the game's progress is (inventory, quest stage, counters, settings of a mod); Lua globals are not saved.


## Older engines and cut files
An engine from before format 2 opening a version-2 `.vxs` reads the header record as garbage and shows 0 chunks (it does not damage the file as long as it is not saved over: keep a copy when switching back). A record cut off at the end of the file (a crash during a write) is trimmed on the next open; damage in the middle is not guessed at. A `#version` newer than the engine knows in `.events/state.txt`, `tracked.txt` or `store.json` is refused and **kept**: the file is not overwritten by the next save, and the log says so.

## Node states and the world save
The states of the event nodes (a door left open, a lever thrown: `<project>/.events/state.txt`) belong to the world they were saved with. A start that has **no world save** (it was deleted, or this is a new run) builds the level again and does **not** read them (the log says so): a door saved open would otherwise be declared open in a corridor whose bars the level has just built. `project.store` (the game's own progress) is separate and is read whenever the file is there.
