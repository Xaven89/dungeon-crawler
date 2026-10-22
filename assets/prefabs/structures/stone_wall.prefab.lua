-- stone_wall as a prefab with snap points: carried with the pointer it jumps to the open end of another wall piece (docs/PREFABS.md "Snap points"), turned to fit.
-- The faces are the two ends of the piece's long axis; `at` is a cell on the face, `dir` the way it looks (away from the piece).
return {
    model = "structures/stone_wall.vxm",
    snaps = {
        west = { at = {0, 10, 4}, dir = "-x", tag = "wall" },
        east = { at = {63, 10, 4}, dir = "+x", tag = "wall" },
    },
}
