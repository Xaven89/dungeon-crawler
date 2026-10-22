-- bridge_segment as a prefab with snap points: carried with the pointer it jumps to the open end of another bridge piece (docs/PREFABS.md "Snap points"), turned to fit.
-- The faces are the two ends of the piece's long axis; `at` is a cell on the face, `dir` the way it looks (away from the piece).
return {
    model = "structures/bridge_segment.vxm",
    snaps = {
        south = { at = {16, 4, 0}, dir = "-z", tag = "bridge" },
        north = { at = {16, 4, 47}, dir = "+z", tag = "bridge" },
    },
}
