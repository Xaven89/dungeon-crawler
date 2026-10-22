-- A swing door in a metal frame, with a pressure plate in front of it (docs/PREFABS.md, docs/HINGES.md).
--   prefab.place("door", x, y, z [, { rotation = 0, name = "front", slots = { panel = "glass" }, params = { open = -90, plate = false, dynamic = true } }])
-- (x, y, z) is the frame's minimum corner. The panel turns about the "hinge" socket; the frame and the plate's spot are stamped / declared once.
-- Nodes: INSTANCE.door and, with params.plate, INSTANCE.plate (opens the door when something stands on it, closes it again after `close_delay` ticks).
-- params.dynamic = true: the panel is a real body on a hinge (the player walks against it and it opens, crates push it, blasts break it): friction holds it where it is left,
-- `spring_k` makes it fall shut, `two_way` lets it swing both ways (a saloon door); open / close then need `motor_torque`.
return {
    model = "door.vxm",
    slots = { frame = "metal", panel = "wood", handle = "metal", handle_back = "metal" },
    moving = { "panel", "handle", "handle_back" },        -- these stand open in a saved world: adopting the prefab does not look for them
    params = { open = 90, seconds = 0.8, plate = true, close_delay = 90, auto_close = false,
               dynamic = false, friction = 6, spring_k = 0, spring_damping = 0, motor_torque = 0, two_way = false },
    build = function(ctx, p)
        local door = events.door{
            name = ctx.name("door"), prefab = ctx, part = { "panel", "handle", "handle_back" },
            hinge = { axis = "y", at = "hinge", open = p.open, seconds = p.seconds, dynamic = p.dynamic, friction = p.friction,
                      spring_to = 0, spring_k = p.spring_k, spring_damping = p.spring_damping, motor_torque = p.motor_torque,
                      limits = p.two_way and { -100, 100 } or nil },
            auto_close = p.auto_close,
        }
        local h = { door = door }
        if p.plate then
            h.plate = events.volume{ name = ctx.name("plate"), box = ctx.box_at("plate", 24, 4, 12), player = true, bodies = true, min_mass = 30 }
            events.connect(h.plate, "enter", door, "open")
            events.connect(h.plate, "exit", door, "close", { delay = p.close_delay })
        end
        return h
    end,
}
