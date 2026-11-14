-- Water jet (pistol shrimp): the big claw spits fast pellets of pressurised water, one after
-- another like a machine gun, each knocking its ant back a little. Every few shots a pellet
-- carries a tiny cavitation pop that splashes the ants around it. Shooting drops the cloak.
-- params: damage, cooldown (fast, ~0.12), range (130), pierce (extra ants per pellet, 0), spread (0.12), popEvery (6), popRadius (14), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Water Jet",
    range = function(params, player) return (params.range or 130) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        require("content.dashes.cloak").reveal(player)
        local range = (params.range or 130) * (1 + player.stats:get("area") / 100)
        local atk = player.attack
        atk.count = (atk.count or 0) + 1
        local pop = atk.count % (params.popEvery or 6) == 0
        local a = math.atan2(ay, ax) + (love.math.random() - 0.5) * (params.spread or 0.12)
        local sp = 420
        -- fired from the big claw (on the right side)
        local cx, cy = player.x + ax * 8 - ay * 4, player.y + ay * 8 + ax * 4
        world.hazards:friendlyShot({ x = cx, y = cy, z = 4, vx = math.cos(a) * sp, vy = math.sin(a) * sp, r = pop and 3 or 2,
            damage = params.damage, life = range / sp, color = params.color or { 0.6, 0.85, 1 }, pierce = params.pierce or 0, knockback = 50,
            onEnd = pop and function(w, s)
                local r = (params.popRadius or 14) * (1 + w.player.stats:get("area") / 100)
                Combat.area(w, s.x, s.y, r, params.damage, { knockback = 60 })
                w:addFx({ kind = "ring", x = s.x, y = s.y, r = r, life = 0.15, color = { 0.8, 0.95, 1 } })
            end or nil })
        world.particles:spawn(cx, cy, 4, ax * 40, ay * 40, 20, 0.15, { 0.8, 0.95, 1 }, 1, { glow = true, grav = 0 })
        Audio.play("hit", { pitch = 2.2 + love.math.random() * 0.3, volume = 0.3 })
    end,
}
