-- Walk straight at the player, with an optional side-to-side wobble so swarms look alive.
-- params: wobble (radians, default 0), wobbleSpeed (default 4)
return {
    name = "Chase",
    update = function(e, world, dt, params)
        local p = world.player
        local dx, dy = p.x - e.x, p.y - e.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        dx, dy = dx / d, dy / d
        local wobble = params.wobble or 0
        if wobble > 0 then
            e.st.wt = (e.st.wt or love.math.random() * 6.28) + dt * (params.wobbleSpeed or 4)
            local a = math.sin(e.st.wt) * wobble
            local c, s = math.cos(a), math.sin(a)
            dx, dy = dx * c - dy * s, dx * s + dy * c
        end
        e.mx, e.my = dx * e.speed, dy * e.speed
    end,
}
