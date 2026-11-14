-- Tarantula hawk: the giant spider wasp. It paralyses a tarantula with its sting and drags it
-- back to its burrow. This one stalks you, rears up (big red ring), and lunges; if the sting
-- lands you're paralysed and dragged off. Mash dash or attack to struggle free sooner, or
-- hurt it to make it let go. Hit it while it rears to stagger it.
-- params: range (34), windup (0.7), stun (1.4), drag (speed, 55), cooldown (4), stagger (1)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local function letGo(e)
    local st = e.st
    st.mode, st.cd = "stalk", e.params.cooldown or 4
end

return {
    name = "Paralyse and drag",
    init = function(e) e.st.mode, e.st.cd, e.st.ang = "stalk", 2, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local range = params.range or 34
        if st.mode == "stalk" then
            AI.hover(e, world, dt, d < 24 and 1 or 6)
            st.cd = st.cd - dt
            st.ang = st.ang + dt * 0.6
            local r = st.cd > 0 and 60 or range * 0.9
            AI.goTo(e, p.x + math.cos(st.ang) * r, p.y + math.sin(st.ang) * r, e.speed)
            if st.cd <= 0 and d < range * 1.2 then st.mode, st.t = "windup", params.windup or 0.7 end
        elseif st.mode == "windup" then
            e.biteCd = 1
            e.mx, e.my = dx / d * 2, dy / d * 2
            AI.hover(e, world, dt, 5)
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t, st.dx, st.dy = "lunge", 0.25, dx / d, dy / d end
        elseif st.mode == "lunge" then
            e.biteCd = 1
            AI.hover(e, world, dt, 1)
            e.mx, e.my = st.dx * 240, st.dy * 240
            st.t = st.t - dt
            if d < p.radius + e.radius + 3 and not p.dead and p.dashT <= 0 then
                AI.sting(e, world, 1)
                p:stun(params.stun or 1.4)
                world:floatText(p.x, p.y, "PARALYSED: MASH TO STRUGGLE", { 1, 0.5, 0.4 }, false)
                Audio.play("zap", { pitch = 0.4 })
                world.camera:shake(0.25)
                -- drag you off away from the middle of the fight
                local ax, ay = e.x - world.size / 2, e.y - world.size / 2
                local l = math.sqrt(ax * ax + ay * ay) + 0.001
                st.mode, st.gx, st.gy = "drag", ax / l, ay / l
                st.hp0 = e.hp
            elseif st.t <= 0 then
                letGo(e)
            end
        elseif st.mode == "drag" then
            e.biteCd = 1
            AI.hover(e, world, dt, 3)
            local s = params.drag or 55
            e.mx, e.my = st.gx * s, st.gy * s
            -- hold you just under its jaws
            p.x, p.y = e.x + st.gx * (e.radius + p.radius - 2), e.y + st.gy * (e.radius + p.radius - 2)
            if p.stunT <= 0 or p.dead or e.hp < st.hp0 then
                if e.hp < st.hp0 then p.stunT = math.min(p.stunT, 0.1) end
                letGo(e)
            end
        else -- staggered
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then letGo(e) end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode == "windup" then Combat.stagger(world, e, e.params.stagger or 1, opts) end
        return 1
    end,
    draw = function(e)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        if st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        local r = (e.params.range or 34) * (1.2 - 0.4 * st.t / (e.params.windup or 0.7))
        love.graphics.setColor(1, 0.2, 0.15, 0.4 + 0.4 * math.sin(st.t * 30))
        love.graphics.ellipse("line", x, y, r * 1.414, r * 0.707)
    end,
}
