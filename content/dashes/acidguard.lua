-- Acid guard (vinegaroon): no dash. Hold to hunker down behind the palps with the tail cocked
-- over the back: you take no damage, shuffle slowly and can't attack, and anything that bites
-- you gets a squirt of vinegar in the face (corroded and shoved off).
-- params: slow (move speed x while guarding, 0.4), damage (per counter-squirt, 6), corrode
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Acid Guard",
    description = "No dash. Hold to hunker behind your palps: you take no damage and every ant that bites you is sprayed with acid.",
    hold = true,
    update = function(player, world, dt, params, held)
        local was = player.blocking
        player.blocking = held
        if held and not was then Audio.play("equip", { pitch = 0.6 }) end
    end,
    blocked = function(player, world, source, params)
        if type(source) == "table" and source.x and source.hp then
            local dx, dy = source.x - player.x, source.y - player.y
            local l = math.sqrt(dx * dx + dy * dy) + 0.001
            if not source.dead then
                Combat.damage(world, source, params.damage or 6, { knockback = 110, kbx = dx / l, kby = dy / l, corrode = params.corrode or { 1.4, 3 } })
            end
        end
        if player.blockFxT <= 0 then
            player.blockFxT = 0.12
            world.particles:sparks(player.x, player.y, 5, { 0.8, 1, 0.45 }, player.aimX, player.aimY, 2.5, 90)
            Audio.play("dash", { pitch = 2.2, volume = 0.4 })
        end
    end,
}
