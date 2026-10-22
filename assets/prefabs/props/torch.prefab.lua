-- A torch that burns without setting anything on fire (docs/EMITTERS.md): a flame emitter with a flickering light and a thin wisp of smoke, switched by the `lit` parameter.
--   prefab.place("props/torch", x, y, z, { params = { lit = false } })      -- a dark torch; an event node `emitter` (on / off / toggle) lights it later: events.emitter{ name = "t.light", emitter = "<instance>.flame" }
-- The emitters are named "<instance>.flame" and "<instance>.smoke" and go away with the prefab.
return {
    model = "props/torch.vxm",
    params = { lit = true },
    build = function(ctx, p)
        ctx.emitter{ name = "flame", preset = "torch", at = { 3, 19, 3 }, enabled = p.lit }
        ctx.emitter{ name = "smoke", preset = "chimney_smoke", at = { 3, 21, 3 }, rate = 2, particle_size = { 1.5, 3.0 }, enabled = p.lit }
    end,
}
