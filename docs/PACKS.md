# Packs

A **pack** is a project (or a part of one) in a single file others can add: levels, models, sounds, scripts, material tables, strings. It is a plain zip, `NAME-VERSION.vxpack`.

```
voxelith --pack projects/lantern_cove                  # -> lantern-cove-1.0.0.vxpack (named by pack.cfg; --pack-out FILE to choose)
voxelith --project lantern-cove-1.0.0.vxpack           # a pack run as a project: unpacked once under ~/.local/share/voxelith/packs/ (its saves live there)
voxelith --project mygame --mod extra-2.0.0.vxpack     # a pack mounted under a project; or in the project's project.cfg:  mods = extra-2.0.0.vxpack, other.vxpack
```

## pack.cfg
```
id = my-pack            # lower case letters, digits, - and _ ; a mod author's namespace for saves too
name = My pack
version = 1.2.0         # dotted numbers
engine = 1.0.0          # the lowest engine that can run it (refused with a message when the engine is older)
requires = base>=1.1, other        # packs that must be there (found beside the pack, in ~/.local/share/voxelith/mods/, or named in project.cfg's mods =)
description / author / license
```
`voxelith --pack` takes every file of the project except state and saves (`.`-directories, `*.vxs`, `*.log`, `*.vxpack`, crash reports) and writes them with deflate (stored when that is not smaller). The same files always give the same bytes.

## Mounting
A project with packs under it runs from a **mount directory** (`~/.cache/voxelith/mounts/NAME-HASH/`) that looks like an ordinary project to every loader: packs in dependency order (a pack after what it requires, the list order otherwise), then the project on top. Files with the same name are **overridden** (the project wins, then the later pack): models, sounds, include()d scripts, strings. The tables that overlay by line are **concatenated in mount order**: `materials.csv` (later lines win by id), `foliage.csv`, `input.cfg`. `project.cfg` and `level.lua` are the project's own. Saves and state (`world.vxs`, `.prefabs`, `.events`, `.state`) are links to the real project directory, so playing with mods never writes into a pack or the mount. Errors say what is wrong: an unmet requirement (`'base' 1.1 or newer`), two packs with one id, a pack that needs a newer engine, a damaged zip (every entry is checked against its checksum; names with `..` or absolute paths are refused; limits of 256 MB an entry and 1 GB in all).

Not built: a pack browser in the UI, signatures, a download source, conflict warnings between packs that override the same file, per-pack save namespaces (the project's save holds everything).
