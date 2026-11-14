-- Spin (lobster tail sweep, mantis scythe storm): whirls around several times, hitting every ant
-- around it on each turn.
-- params: damage (per turn), cooldown, radius (44), turns (3), turnTime (0.12), knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local function turn(player, world, params, left)
    local r = (params.radius or 44) * (1 + player.stats:get("area") / 100)
    local hits = Combat.area(world, player.x, player.y, r, params.damage, { knockback = params.knockback or 160 })
    world.hazards:deflect(player.x, player.y, r)
    local a = love.math.random() * math.pi * 2
    world:addFx({ kind = "arc", x = player.x, y = player.y, r = r, a = a, arc = 4.5, life = params.turnTime or 0.12, color = params.color })
    player.wangle = player.wangle + 2.1
    Audio.play("dash", { pitch = 1.4 })
    if hits >= 5 then world.camera:shake(0.05 + hits * 0.004) end
    if left > 1 then player:after(params.turnTime or 0.12, function(p, w) turn(p, w, params, left - 1) end) end
end

return {
    name = "Spin",
    range = function(params, player) return (params.radius or 44) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        turn(player, world, params, params.turns or 3)
    end,
}
