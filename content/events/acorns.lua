-- Falling acorns: the oak above drops its acorns. A shadow marks each one; where it lands it
-- crushes the ants under it, and the acorn stays as something heavy to roll into the crowd.
local Env = require("src.game.envfx")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local FALL, R = 1.1, 18

return {
    name = "Falling Acorns",
    description = "Watch the shadows! Then roll the acorns into the ants.",
    color = { 0.95, 0.75, 0.4 },
    kind = "hazard",
    weight = 9, minWave = 2,
    duration = 12,
    start = function(world, ev) ev.st.falls, ev.st.cd, ev.st.dropped = {}, 0.3, 0 end,
    update = function(world, ev, dt)
        local st, p = ev.st, world.player
        st.cd = st.cd - dt
        if st.cd <= 0 and ev.t < ev.life - FALL - 0.2 then
            st.cd = 0.7 + love.math.random() * 0.6
            -- some at the player, some into the thick of the crowd
            local x, y
            local target = love.math.random() < 0.5 and world.enemyCount > 0 and world.enemies[love.math.random(world.enemyCount)]
            if target then x, y = Env.pointNear(world, target.x, target.y, 20) else x, y = Env.pointNear(world, p.x, p.y, 70) end
            st.falls[#st.falls + 1] = { x = x, y = y, t = 0 }
        end
        for i = #st.falls, 1, -1 do
            local f = st.falls[i]
            f.t = f.t + dt
            if f.t >= FALL then
                table.remove(st.falls, i)
                local kills = Env.strikeCircle(world, f.x, f.y, R, 30 + world.spawner.wave * 2, { force = 120 })
                if Env.playerIn(world, f.x, f.y, R - 3) then Env.hurtPlayer(world, 12, f.x, f.y, { force = 150 }) end
                world.camera:shake(0.15)
                Audio.play("boom", { pitch = 1.3, volume = 0.6 })
                world.particles:burst(f.x, f.y, 10, { { 0.5, 0.4, 0.3 }, { 0.6, 0.45, 0.25 } }, 80, 60, { grav = 300 })
                if kills >= 3 then world:floatText(f.x, f.y, "BONK x" .. kills, { 1, 0.8, 0.5 }) end
                world.props:spawn("acorn", f.x, f.y)
                st.dropped = st.dropped + 1
            end
        end
    end,
    drawGround = function(world, ev)
        for _, f in ipairs(ev.st.falls) do
            local k = f.t / FALL
            Env.shadow(f.x, f.y, 4 + 10 * k, 0.3 + 0.6 * k)
            Env.warnCircle(f.x, f.y, R, k, world.time, { 1, 0.6, 0.25 })
        end
    end,
    drawAir = function(world, ev)
        local lg = love.graphics
        for _, f in ipairs(ev.st.falls) do
            local h = (1 - f.t / FALL) ^ 1.6 * 220
            local sx, sy = Iso.toScreen(f.x, f.y, h)
            lg.setColor(0.55, 0.32, 0.12, 1)
            lg.ellipse("fill", sx, sy, 5, 6)
            lg.setColor(0.38, 0.3, 0.17, 1)
            lg.ellipse("fill", sx, sy - 5, 5, 2.5)
        end
    end,
}
