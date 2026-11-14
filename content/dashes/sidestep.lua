-- Sidestep (tailless whip scorpion): it scuttles sideways like a crab, keeping its palps and
-- feelers facing the swarm. Dashes to the side you move toward (or to the left of your aim).
-- params: distance (64), speed (1.2), charges (2)
return {
    name = "Sidestep",
    description = "Scuttle sideways like a crab without ever turning away from the swarm. Two charges.",
    start = function(player, world, dx, dy, params)
        local ax, ay = player.aimX, player.aimY
        -- left or right of the aim, whichever is closer to the way you are moving
        local lx, ly = ay, -ax
        local dot = lx * dx + ly * dy
        if dot < 0 then lx, ly = -lx, -ly end
        if math.abs(dot) < 0.2 and not player.moving then lx, ly = ay, -ax end
        player:lunge(lx, ly, params.distance or 64, params.speed or 1.2)
        world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = player.x + lx * (params.distance or 64), y2 = player.y + ly * (params.distance or 64),
            life = 0.18, w = 2, color = { 0.9, 0.75, 0.55 } })
    end,
}
