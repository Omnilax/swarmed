-- The merchant beetle wanders in with a pack of wares, priced in nectar a little under the shop:
-- walk into it to buy (up to two things). It leaves with the wave.
local Env = require("src.game.envfx")

return {
    name = "Merchant Beetle",
    description = "A shop that comes to you, a little cheaper. Walk into it to buy with nectar.",
    color = { 0.5, 1, 0.85 },
    kind = "event",
    weight = 7, minWave = 3,
    start = function(world, ev)
        local e = world.spawner:edgePoint()
        ev.st.m = world.props:spawn("merchant", e[1], e[2])
    end,
    update = function(world, ev)
        if ev.st.m.dead then ev.done = true end
    end,
    finish = function(world, ev)
        local m = ev.st.m
        if m and not m.dead then m.def.leave(world, m) end
    end,
}
