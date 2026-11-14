-- Termite king: the queen's lifelong mate. Stays at her side, and whenever you get near her he
-- rears up and charges at you. Hit him during the rear-up to stagger him. If the queen dies he
-- loses it: from then on he hunts you, faster and angrier. (Spawned on his own, he is already
-- widowed.)
-- params: guard (how close you may get to the queen before he charges, 90), orbit (12),
--         windup (0.45), rush (speed x, 2.6), rushTime (0.7), cooldown (1.6), rage (speed x
--         once widowed, 1.5), rageDamage (damage x once widowed, 1.4)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")

local function queenAlive(st)
    local q = st.queen
    return q and q.uid == st.queenUid and not q.dead
end

return {
    name = "Royal consort",
    init = function(e) e.st.mode, e.st.t, e.st.cd, e.st.ang = "attend", 0, 1, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local q = queenAlive(st) and st.queen or nil
        if not q and not st.widowed then
            st.widowed = true
            e.speed = e.speed * (params.rage or 1.5)
            e.damage = e.damage * (params.rageDamage or 1.4)
            if st.queen then world:floatText(e.x, e.y, "THE KING RAGES", { 1, 0.4, 0.25 }, true) end
            st.mode = "hunt"
        end
        st.cd = st.cd - dt
        if st.mode == "attend" then
            -- pacing around her
            st.ang = st.ang + dt * 0.8
            local o = (params.orbit or 12) + q.radius
            AI.goTo(e, q.x + math.cos(st.ang) * o, q.y + math.sin(st.ang) * o, e.speed)
            local qd = math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2)
            if qd < (params.guard or 90) and st.cd <= 0 and not p.dead then
                st.mode, st.t, e.hitPad = "windup", params.windup or 0.45, 4
            end
        elseif st.mode == "hunt" then
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            if d < 70 and st.cd <= 0 then st.mode, st.t, e.hitPad = "windup", params.windup or 0.45, 4 end
        elseif st.mode == "windup" then
            e.mx, e.my = dx / d * 2, dy / d * 2
            st.t = st.t - dt
            if st.t <= 0 then
                st.mode, st.t, e.hitPad = "rush", params.rushTime or 0.7, 2
                st.dx, st.dy = dx / d, dy / d
                Audio.play("dash", { pitch = 0.7 })
            end
        elseif st.mode == "rush" then
            local s = e.speed * (params.rush or 2.6)
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if st.t <= 0 or d < p.radius + e.radius + 1 then
                e.hitPad = 0
                st.mode, st.cd = st.widowed and "hunt" or "attend", params.cooldown or 1.6
            end
        else -- stagger
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.cd = st.widowed and "hunt" or "attend", 0.8 end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode == "windup" then Combat.stagger(world, e, 0.9, opts) return 1.3 end
        return 1
    end,
    draw = function(e)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        local x, y = Iso.toScreen(e.x, e.y)
        if st.mode == "windup" then
            love.graphics.setColor(1, 0.4, 0.25, math.floor(st.t * 30) % 2 == 0 and 0.9 or 0.3)
            love.graphics.ellipse("line", x, y, 9, 4.5)
        elseif st.widowed then
            love.graphics.setColor(1, 0.3, 0.2, 0.35 + 0.2 * math.sin(love.timer.getTime() * 8))
            love.graphics.rectangle("fill", math.floor(x) - 2, math.floor(y) - 7, 1, 1)
            love.graphics.rectangle("fill", math.floor(x) + 1, math.floor(y) - 7, 1, 1)
        end
    end,
}
