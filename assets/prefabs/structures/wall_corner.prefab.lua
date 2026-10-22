-- wall_corner: two arms of stone wall at a right angle (the same 8 voxel wall as stone_wall): each arm's open end joins a stone_wall piece, turned to fit.
return {
    model = "structures/wall_corner.vxm",
    snaps = {
        west  = { at = {0, 10, 4}, dir = "-x", tag = "wall" },
        north = { at = {4, 10, 39}, dir = "+z", tag = "wall" },
    },
}
