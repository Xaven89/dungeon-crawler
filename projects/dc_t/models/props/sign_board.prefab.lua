-- A board on a post with TEXT on its front face (docs/TEXT.md): voxel letters of a 5 x 7 font, written into the model before it is stamped, so they turn, move and go away with the prefab.
--   prefab.place("props/sign_board", x, y, z, { params = { text = "TAVERN", material = "brick", color = "dark_red", size = 1 } })
-- The board holds 10 letters at size 1 (a letter is 5 x 7 voxels: 31 x 44 cm) or 6 at size 2. An empty text leaves a blank board.
return {
    model = "props/sign_board.vxm",
    params = { text = "WELCOME", material = "brick", color = "", size = 1 },
    labels = function(p)
        local size = math.max(1, math.min(2, math.floor(p.size)))
        return { { text = p.text, at = { 33, 12 + math.floor((18 - 7 * size) / 2), 4 }, facing = "+z", material = p.material, size = size, align = "center",
                   paint = p.color ~= "" and p.color or nil } }
    end,
}
