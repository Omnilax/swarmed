-- A rare map event: a fat aphid matriarch wanders in. Aphids bear live clones of themselves,
-- and she will clone one of your items too: walk into her, pick the item to copy, then feed her
-- another item of the same rarity (src/states/duplicate.lua). One copy, then she leaves; she also
-- leaves when the wave ends. Only turns up when your bag has two items of one rarity.
local Duplicate = require("src.game.duplicate")

return {
    name = "Aphid Matriarch",
    description = "Feed her an item and she clones another of the same rarity. Walk into her.",
    color = { 0.6, 1, 0.55 },
    kind = "event",
    weight = 2, minWave = 5,
    allowed = function(world)
        return (world.matriarchs or 0) < 2 and Duplicate.anyPair(world.player.inventory)
    end,
    start = function(world, ev)
        world.matriarchs = (world.matriarchs or 0) + 1
        local e = world.spawner:edgePoint()
        ev.st.m = world.props:spawn("clone_aphid", e[1], e[2])
    end,
    update = function(world, ev)
        if ev.st.m.dead then ev.done = true end
    end,
    finish = function(world, ev)
        local m = ev.st.m
        if m and not m.dead then m.def.leave(world, m) end
    end,
}
