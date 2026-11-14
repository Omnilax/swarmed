-- Shell guard (hermit crab): no dash. Hold to pull back into the shell: every hit is negated,
-- and unlike a plain block you can keep walking at a decent pace and keep pinching out of the
-- shell's mouth. Ants that bite the shell get nipped back.
-- params: slow (move speed x while in the shell, 0.7), thorns (damage back to biters, 4),
--         shove (pushes biters away, 70)
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")

return {
    name = "Shell Guard",
    description = "No dash. Hold to pull back into your shell: no damage at all, and you can still walk and pinch. Biters get nipped back.",
    hold = true,
    attackWhileBlocking = true,
    update = function(player, world, dt, params, held)
        local was = player.blocking
        player.blocking = held
        if held and not was then Audio.play("equip", { pitch = 0.55 }) end
    end,
    blocked = function(player, world, source, params)
        if type(source) == "table" and source.x and source.def then
            local dx, dy = source.x - player.x, source.y - player.y
            local l = math.sqrt(dx * dx + dy * dy) + 0.001
            Combat.damage(world, source, params.thorns or 4, { knockback = params.shove or 70, kbx = dx / l, kby = dy / l, noCrit = true, procDepth = 1 })
        end
        if player.blockFxT <= 0 then
            player.blockFxT = 0.15
            world.particles:sparks(player.x, player.y, 4, { 1, 0.9, 0.75 }, player.aimX, player.aimY, 2.5, 80)
            Audio.play("hit", { pitch = 1.4, volume = 0.6 })
        end
    end,
}
