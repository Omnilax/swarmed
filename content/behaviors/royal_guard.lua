-- A queen's royal guard (src/game/pacing.lua): circles her, and charges anyone who comes close
-- to her. While any guard lives the queen shrugs off most damage. Once she is gone, guards
-- just chase. params: engage (how close to the queen the player must come, default 95)
local AI = require("src.game.ai")

return {
    name = "Royal Guard",
    update = function(e, world, dt, params)
        local q = e.guardOf
        local p = world.player
        if not q or q.dead or q.uid ~= e.guardUid then
            e.guardOf = nil
            local dx, dy, d = AI.toPlayer(e, world)
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            return
        end
        local qx, qy = p.x - q.x, p.y - q.y
        if qx * qx + qy * qy < (params.engage or 95) ^ 2 then
            local dx, dy, d = AI.toPlayer(e, world)
            e.mx, e.my = dx / d * e.speed * 1.15, dy / d * e.speed * 1.15
        else
            e.guardA = (e.guardA or 0) + dt * 0.7
            local r = q.radius + 16
            AI.goTo(e, q.x + math.cos(e.guardA) * r, q.y + math.sin(e.guardA) * r, e.speed * 1.4)
        end
    end,
}
