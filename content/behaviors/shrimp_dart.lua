-- Shrimp: swims at the player in kicks (a burst of speed that glides out), and when it is hit
-- it tail-flips: snaps backwards away from you, still facing you, the way a real shrimp escapes.
-- Some come straight back in a lunge.
-- params: kick (speed x at the start of a kick, 1.8), glide (how fast a kick fades, 2.2 per s),
--         rest ({min, max} seconds between kicks, {0.35, 0.8}), wobble (radians off course, 0.5),
--         flee (chance a hit makes it flick away, 0.6), flick (tail-flip push, 220),
--         fleeCd (seconds before it can flick again, 1.2), biteFlee (true: also flicks off after
--         a bite, so it nips and darts), lunge (nil, or speed x of a lunge back at you after a
--         flick), lungeTime (0.35)
local AI = require("src.game.ai")

local PFX = { { 0.85, 0.95, 1 }, { 0.6, 0.8, 0.9 } }

local function flick(e, world, params)
    local st = e.st
    local dx, dy, d = AI.toPlayer(e, world)
    local push = (params.flick or 220) / math.max(0.4, e.mass)
    e.kvx, e.kvy = e.kvx - dx / d * push, e.kvy - dy / d * push
    st.mode, st.t, st.fleeCd = "flee", 0.32, params.fleeCd or 1.2
    e.squash = 0.14
    world.particles:burst(e.x, e.y, 3, PFX, 30, 16)
end

return {
    name = "Shrimp darter",
    init = function(e, world, params)
        local st = e.st
        st.mode, st.t, st.v, st.fleeCd, st.lastCd = "swim", love.math.random() * 0.6, 0.6, 0, 0
        st.ph = love.math.random() * 6.28
    end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        if st.fleeCd > 0 then st.fleeCd = st.fleeCd - dt end
        -- a nip, then away (biteFlee): the bite timer jumping up means it just bit
        if params.biteFlee and e.biteCd > st.lastCd + 0.05 and st.mode == "swim" then flick(e, world, params) end
        st.lastCd = e.biteCd
        if st.mode == "flee" then
            -- drifting back on the flick (knockback velocity), turned to face you
            e.mx, e.my = dx / d * 2, dy / d * 2
            st.t = st.t - dt
            if st.t <= 0 then
                if params.lunge then st.mode, st.t = "lunge", params.lungeTime or 0.35
                else st.mode, st.t = "swim", 0.2 end
            end
        elseif st.mode == "lunge" then
            local sp = e.speed * params.lunge
            e.mx, e.my = dx / d * sp, dy / d * sp
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t, st.v = "swim", 0.3, 0.5 end
        else
            st.t = st.t - dt
            st.v = math.max(0.35, st.v - dt * (params.glide or 2.2))
            if st.t <= 0 then
                local r = params.rest or { 0.35, 0.8 }
                st.t = r[1] + love.math.random() * (r[2] - r[1])
                st.v = params.kick or 1.8
                st.ph = st.ph + (love.math.random() - 0.5) * 2
            end
            local a = math.atan2(dy, dx) + math.sin(st.ph + world.time * 1.3) * (params.wobble or 0.5)
            local sp = e.speed * st.v
            e.mx, e.my = math.cos(a) * sp, math.sin(a) * sp
        end
    end,
    -- a hit can set off the tail-flip
    onHit = function(e, world, opts, dmg)
        local st = e.st
        if st.mode == "swim" and st.fleeCd <= 0 and e.hp > dmg and love.math.random() < (e.params.flee or 0.6) then
            flick(e, world, e.params)
        end
        return 1
    end,
}
