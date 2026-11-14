-- Block (lobster): no dash at all. Hold the button to brace behind your claws: every hit is
-- negated while you shuffle along slowly. You can't attack while blocking.
-- params: slow (move speed x while blocking, 0.35), shove (pushes biting ants back, 90)
local Audio = require("src.core.audio")

return {
    name = "Block",
    description = "No dash. Hold to brace behind your claws: you take no damage at all, but can only shuffle along slowly and can't attack.",
    hold = true,
    update = function(player, world, dt, params, held)
        local was = player.blocking
        player.blocking = held
        if held and not was then Audio.play("equip", { pitch = 0.7 }) end
    end,
    -- called by Player:hurt instead of taking damage
    blocked = function(player, world, source, params)
        if type(source) == "table" and source.x then
            local dx, dy = source.x - player.x, source.y - player.y
            local l = math.sqrt(dx * dx + dy * dy) + 0.001
            source.kvx, source.kvy = source.kvx + dx / l * (params.shove or 90), source.kvy + dy / l * (params.shove or 90)
        end
        if player.blockFxT <= 0 then
            player.blockFxT = 0.15
            world.particles:sparks(player.x, player.y, 4, { 0.8, 0.9, 1 }, player.aimX, player.aimY, 2.5, 90)
            Audio.play("hit", { pitch = 1.8 })
        end
    end,
}
