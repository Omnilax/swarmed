-- Sand wasp: digs its burrow in loose sand, kicking it out behind like a dog. This one digs
-- pits round you. A pit drags you down toward its middle (dash out), and while you're stuck in
-- one the wasp dives in to sting.
-- params: pit (radius, 24), pull (50), life (7), dig (seconds, 1.1), spot ({min, max} distance
--         from you it digs, {25, 50}), cooldown (1.5)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local SAND = { 0.78, 0.66, 0.45 }

local function pitDraw(z, sx, sy, fade)
    local lg = love.graphics
    local r = z.r * math.min(1, z.t / 0.3)
    for i = 3, 1, -1 do
        local k = i / 3
        local v = 0.35 + 0.45 * k
        lg.setColor(SAND[1] * v, SAND[2] * v, SAND[3] * v, 0.75 * fade)
        lg.ellipse("fill", sx, sy + (1 - k) * 2, r * k * 1.4, r * k * 0.7)
    end
    -- sand trickling down the slope
    lg.setColor(0.95, 0.85, 0.6, 0.6 * fade)
    for i = 0, 5 do
        local a = i * 1.05 + z.t
        local f = (z.t * 0.7 + i * 0.37) % 1
        lg.rectangle("fill", math.floor(sx + math.cos(a) * r * 1.4 * (1 - f)), math.floor(sy + math.sin(a) * r * 0.7 * (1 - f)), 1, 1)
    end
end

return {
    name = "Pit digger",
    init = function(e) e.st.mode, e.st.cd = "fly", 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        if st.mode == "fly" then
            AI.hover(e, world, dt, 8)
            st.cd = st.cd - dt
            if st.cd <= 0 then
                local sp = params.spot or { 25, 50 }
                local a = love.math.random() * math.pi * 2
                local r = sp[1] + love.math.random() * (sp[2] - sp[1])
                st.tx = math.max(20, math.min(world.size - 20, p.x + math.cos(a) * r))
                st.ty = math.max(20, math.min(world.size - 20, p.y + math.sin(a) * r))
                st.mode, st.t = "goto", 3
            else
                AI.goTo(e, p.x + math.cos(world.time + e.uid) * 70, p.y + math.sin(world.time + e.uid) * 70, e.speed)
            end
        elseif st.mode == "goto" then
            AI.hover(e, world, dt, 5)
            st.t = st.t - dt
            if AI.goTo(e, st.tx, st.ty, e.speed * 1.4) < 4 or st.t <= 0 then st.mode, st.t = "dig", params.dig or 1.1 end
        elseif st.mode == "dig" then
            e.mx, e.my = 0, 0
            e.z = math.max(0, e.z - dt * 20)
            st.t = st.t - dt
            -- sand flying out behind it
            if love.math.random() < dt * 25 then
                local a = e.angle + math.pi + (love.math.random() - 0.5)
                world.particles:spawn(e.x, e.y, 2, math.cos(a) * 60, math.sin(a) * 60, 40, 0.5, SAND, 1, { grav = 300 })
            end
            if st.t <= 0 then
                world.hazards:addZone({ kind = "pit", x = e.x, y = e.y, r = params.pit or 24, life = params.life or 7,
                    pull = params.pull or 50, color = SAND, draw = pitDraw })
                Audio.play("hit", { pitch = 0.4 })
                st.mode, st.t = "lurk", 2.5
            end
        elseif st.mode == "lurk" then
            -- wait by the pits; dive in when you're caught in one
            AI.hover(e, world, dt, 8)
            AI.goTo(e, p.x + math.cos(world.time * 1.3 + e.uid) * 40, p.y + math.sin(world.time * 1.3 + e.uid) * 40, e.speed)
            st.t = st.t - dt
            local caught = false
            for _, z in ipairs(world.hazards.zones) do
                if z.kind == "pit" and (p.x - z.x) ^ 2 + (p.y - z.y) ^ 2 < z.r * z.r then caught = true break end
            end
            if caught then st.mode, st.t = "dive", 0.6
            elseif st.t <= 0 then st.mode, st.cd = "fly", params.cooldown or 1.5 end
        else
            AI.hover(e, world, dt, 1)
            e.mx, e.my = dx / d * e.speed * 2.4, dy / d * e.speed * 2.4
            st.t = st.t - dt
            if d < p.radius + e.radius + 2 and not p.dead then
                AI.sting(e, world, 1)
                st.t = 0
            end
            if st.t <= 0 then st.mode, st.cd = "fly", params.cooldown or 1.5 end
        end
    end,
}
