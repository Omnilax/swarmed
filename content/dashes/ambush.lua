-- Ambush (assassin bug): a darting lunge that ends with the beak buried in the first ant it
-- reaches. The stab hits hard and drinks (heals you), then the bug springs back off the body
-- so it isn't left standing in the crowd. Misses are just a quick dart.
-- params: distance (85), speed (x normal dash speed, 1.3), stab (damage, 16), heal (HP per
--         stab, 3), recoil (spring-back distance, 26), pierce (true: keep going after the stab,
--         stabbing every ant passed), ram (damage to other ants passed), knockback (90)
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local function stab(player, world, e, params)
    Combat.damage(world, e, params.stab or 16, { knockback = params.knockback or 90, kbx = player.dashX, kby = player.dashY })
    player:heal(params.heal or 3)
    world.particles:sparks(e.x, e.y, 5, { 1, 0.35, 0.3 }, player.dashX, player.dashY, 1.5, 120)
    Audio.play("hit", { pitch = 1.4 })
end

return {
    name = "Ambush",
    description = "Dart forward and drive your beak into the first ant you reach: a heavy stab that heals you, then spring back clear.",
    start = function(player, world, dx, dy, params)
        player:lunge(dx, dy, params.distance or 85, params.speed or 1.3)
        player.dashHit = {}
        player.ambushed = nil
    end,
    update = function(player, world, dt, params)
        local hit = player.dashHit
        if not hit then return end
        local fx, fy = util.normalize(player.dashX, player.dashY)
        for _, e in ipairs(Combat.collect(world, player.x + fx * 6, player.y + fy * 6, player.radius + 3)) do
            if not hit[e] then
                hit[e] = true
                if not player.ambushed or params.pierce then
                    player.ambushed = true
                    stab(player, world, e, params)
                    if not params.pierce then
                        -- spring back off the body (a short, guarded hop)
                        player:lunge(-fx, -fy, params.recoil or 26, 0.8)
                        player.dashHop, player.dashT0 = 5, player.dashT
                        player.iframes = math.max(player.iframes, player.dashT + 0.15)
                        player.dashHit = nil
                        return
                    end
                elseif (params.ram or 0) > 0 then
                    Combat.damage(world, e, params.ram, { knockback = params.knockback or 90, kbx = e.x - player.x, kby = e.y - player.y })
                end
            end
        end
    end,
}
