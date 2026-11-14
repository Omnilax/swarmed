-- Army ant: marches straight at the player and turns only slowly, like a relentless column.
-- params: turn (radians per second, 0.8)
return {
    name = "Relentless march",
    init = function(e, world)
        local p = world.player
        e.st.dir = math.atan2(p.y - e.y, p.x - e.x)
    end,
    update = function(e, world, dt, params)
        local p = world.player
        local want = math.atan2(p.y - e.y, p.x - e.x)
        local diff = (want - e.st.dir + math.pi) % (math.pi * 2) - math.pi
        local turn = (params.turn or 0.8) * dt
        e.st.dir = e.st.dir + math.max(-turn, math.min(turn, diff))
        e.mx, e.my = math.cos(e.st.dir) * e.speed, math.sin(e.st.dir) * e.speed
    end,
}
