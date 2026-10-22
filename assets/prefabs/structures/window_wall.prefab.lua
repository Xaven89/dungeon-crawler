-- window_wall: a brick wall piece 4 m long with a framed window (a glass pane). Pieces of its own kind (a thin wall, 7 voxels) join at their ends; the thicker stone_wall and wall_corner join each other.
return {
    model = "structures/window_wall.vxm",
    snaps = {
        west = { at = {0, 10, 3},  dir = "-x", tag = "thin_wall" },
        east = { at = {63, 10, 3}, dir = "+x", tag = "thin_wall" },
    },
}
