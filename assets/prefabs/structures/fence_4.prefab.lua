-- fence_4 as a prefab with snap points: carried with the pointer it jumps to the open end of another fence piece (docs/PREFABS.md "Snap points"), turned to fit.
-- The faces are the two ends of the piece's long axis; `at` is a cell on the face, `dir` the way it looks (away from the piece).
return {
    model = "structures/fence_4.vxm",
    snaps = {
        west = { at = {0, 10, 1}, dir = "-x", tag = "fence" },
        east = { at = {63, 10, 1}, dir = "+x", tag = "fence" },
    },
}
