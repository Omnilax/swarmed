-- Trap-jaw: walks up, cocks its jaws (short telegraph), snaps for heavy damage, then flings
-- itself backwards out of reach and comes again.
-- params: range (snap reach, 18), windup (0.25), snapDamage (14), leap (distance, 60), cooldown (1.0)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")

return {
    name = "Snap and leap",
    init = function(e) e.st.mode, e.st.t = "approach", 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "approach" then
            st.t = st.t - dt
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            if d < (params.range or 18) + p.radius and st.t <= 0 then st.mode, st.t, e.hitPad = "windup", params.windup or 0.25, 5 end
        elseif st.mode == "windup" then
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then
                e.hitPad = 0
                if d < (params.range or 18) + p.radius + 6 then
                    p:hurt((params.snapDamage or 14) * (e.damage / math.max(0.1, e.def.damage)), e)
                    p:knock(dx, dy, 160)
                    world:addFx({ kind = "ring", x = e.x + dx / d * 8, y = e.y + dy / d * 8, r = 10, life = 0.15, color = { 1, 0.9, 0.7 } })
                end
                Audio.play("hit", { pitch = 1.6 })
                local leap = params.leap or 60
                AI.startJump(e, e.x - dx / d * leap, e.y - dy / d * leap, 0.32, 10)
                st.mode = "leap"
            end
        elseif st.mode == "leap" then
            if AI.updateJump(e, dt) then st.mode, st.t = "approach", params.cooldown or 1.0 end
        else -- stagger: hit while cocking its jaws
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t = "approach", 0.4 end
        end
    end,
    -- a hit while the jaws are cocked jams them: staggered, no snap
    onHit = function(e, world, opts)
        if e.st.mode == "windup" then Combat.stagger(world, e, e.params.stagger or 0.8, opts) end
        return 1
    end,
    draw = function(e)
        if e.st.mode == "stagger" then Combat.drawDazed(e) return end
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.85, 0.4, math.floor(e.st.t * 30) % 2 == 0 and 0.9 or 0.3)
        love.graphics.circle("line", x, y, 7)
    end,
}
