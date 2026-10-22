-- stairs: a flight of 8 steps (each 6 voxels deep and 2 high, 2 m wide) rising along +z. Carried with the pointer it jumps to the end of another flight: the top of one meets the bottom of the next
-- (the next flight is placed 15 voxels higher, so a long staircase is a row of flights) (docs/PREFABS.md "Snap points").
return {
    model = "structures/stairs.vxm",
    snaps = {
        bottom = { at = {16, 0, 0},   dir = "-z", tag = "stairs_bottom", mate = "stairs_top" },
        top    = { at = {16, 15, 47}, dir = "+z", tag = "stairs_top",    mate = "stairs_bottom" },
    },
}
