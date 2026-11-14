-- Exploding ant: rushes in; once close it stops, swells and flashes, then bursts, hurting the
-- player and every ant nearby. Kill it first and it only pops (see the enemy's onDeath).
-- params: trigger (distance to start the fuse, 16), fuse (0.7), radius (blast, 46),
--         blastDamage (22 to the player), antDamage (30 to ants)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")

return {
    name = "Self-destruct",
    init = function(e) e.st.mode = "rush" end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "rush" then
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            if d < (params.trigger or 16) + p.radius then st.mode, st.t = "fuse", params.fuse or 0.7 end
        else
            e.mx, e.my = dx / d * 1.2, dy / d * 1.2
            st.t = st.t - dt
            e.flash = (math.floor(st.t * 14) % 2 == 0) and 0.05 or 0
            e.scale = e.baseScale * (1 + (1 - st.t / (params.fuse or 0.7)) * 0.5)
            if st.t <= 0 then
                local r = params.radius or 46
                if d < r + p.radius then
                    p:hurt((params.blastDamage or 22) * (e.damage / math.max(0.1, e.def.damage)), e)
                    p:knock(-dx, -dy, 220)
                end
                e.st.exploded = true
                world:killEnemy(e)
                Combat.explode(world, e.x, e.y, r, params.antDamage or 30, { procDepth = Combat.MAX_PROC_DEPTH, noCrit = true, color = { 1, 0.85, 0.3 } })
            end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "fuse" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        local r = (e.params.radius or 46)
        love.graphics.setColor(1, 0.8, 0.2, 0.25 + 0.25 * math.sin(e.st.t * 30))
        love.graphics.ellipse("line", x, y, r, r / 2)
    end,
}
