-- A campfire of emitters (docs/EMITTERS.md): flames, rising embers and a column of smoke, with a warm light. It burns without setting the grass alight; `lit = false` leaves it cold.
return {
    model = "props/campfire.vxm",
    params = { lit = true },
    build = function(ctx, p)
        ctx.emitter{ name = "fire", preset = "campfire", at = { 12, 3, 12 }, enabled = p.lit }
        ctx.emitter{ name = "embers", preset = "embers", at = { 12, 4, 12 }, enabled = p.lit }
        ctx.emitter{ name = "smoke", preset = "chimney_smoke", at = { 12, 8, 12 }, rate = 4, enabled = p.lit }
    end,
}
