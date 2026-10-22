-- path_tile: a 2 m paving tile; its four sides join other tiles, so a path or a plaza is a carried row.
return {
    model = "structures/path_tile.vxm",
    snaps = {
        west  = { at = {0, 0, 16},  dir = "-x", tag = "path" },
        east  = { at = {32, 0, 16}, dir = "+x", tag = "path" },
        south = { at = {16, 0, 0},  dir = "-z", tag = "path" },
        north = { at = {16, 0, 32}, dir = "+z", tag = "path" },
    },
}
