-- TEMPLATE. Copy to my_attack.lua; characters use it with attack = { type = "my_attack", ... }.
-- Everything else in the character's attack table is passed to you as `params`.
local Combat = require("src.game.combat")

return {
    name = "My Attack",
    -- How far the attack reaches; used for auto-attack and auto-aim.
    range = function(params, player) return params.radius end,
    -- (ax, ay) is the normalised aim direction in world space.
    fire = function(player, world, ax, ay, params)
        -- Combat.collect / Combat.damage / Combat.area / Combat.explode / Combat.chain
        Combat.area(world, player.x + ax * 20, player.y + ay * 20, params.radius, params.damage, { knockback = 60 })
        world:addFx({ kind = "ring", x = player.x + ax * 20, y = player.y + ay * 20, r = params.radius, life = 0.2 })
    end,
}
