-- Matabele ant: termite raiders that rescue their wounded. When one is badly hurt it cries out,
-- a healthy nestmate runs over, picks it up and carries it out of the fight, and a few seconds
-- later the patient is back on its feet at full health. Kill the medics first.
-- params: woundAt (hp fraction, 0.5), carryTime (2.4), scan (seconds between checks, 0.4)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local function valid(o, uid) return o and o.uid == uid and not o.dead end

return {
    name = "Rescue raid",
    init = function(e) e.st.mode, e.st.scan, e.st.wt = "fight", love.math.random() * 0.4, love.math.random() * 6 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local woundAt = params.woundAt or 0.5
        if not st.cried and e.hp < e.maxHp * woundAt and st.mode ~= "carried" then
            st.cried = true
            world:floatText(e.x, e.y, "!", { 1, 0.9, 0.3 }, false)    -- stridulating for help
        end
        if st.mode == "fight" then
            st.wt = st.wt + dt * 4
            local w = math.sin(st.wt) * 0.25
            e.mx, e.my = (dx / d - dy / d * w) * e.speed, (dy / d + dx / d * w) * e.speed
            st.scan = st.scan - dt
            if st.scan <= 0 and e.hp > e.maxHp * 0.6 then
                st.scan = params.scan or 0.4
                local list, n = world:queryEnemies(e.x, e.y, 100)
                for i = 1, n do
                    local o = list[i]
                    local ost = o.st
                    if o ~= e and o.def == e.def and not o.dead and o.hp < o.maxHp * woundAt and ost.mode == "fight"
                        and not valid(ost.rescuer, ost.rescuerUid) then
                        ost.rescuer, ost.rescuerUid = e, e.uid
                        st.mode, st.patient, st.patientUid, st.t = "fetch", o, o.uid, 3
                        break
                    end
                end
            end
        elseif st.mode == "fetch" then
            local pt = st.patient
            st.t = st.t - dt
            if not valid(pt, st.patientUid) or pt.st.mode ~= "fight" or st.t <= 0 then st.mode = "fight" return end
            if AI.goTo(e, pt.x, pt.y, e.speed * 1.3) < e.radius + pt.radius + 2 then
                pt.st.mode, pt.st.carrier, pt.st.carrierUid = "carried", e, e.uid
                st.mode, st.t = "carry", params.carryTime or 2.4
            end
        elseif st.mode == "carry" then
            local pt = st.patient
            e.mx, e.my = -dx / d * e.speed * 1.15, -dy / d * e.speed * 1.15
            st.t = st.t - dt
            if not valid(pt, st.patientUid) then st.mode = "fight" return end
            if st.t <= 0 then
                pt.hp, pt.st.mode, pt.st.cried = pt.maxHp, "fight", false
                pt.z = 0
                world:floatText(pt.x, pt.y, "+", { 0.5, 1, 0.5 }, false)
                world.particles:burst(pt.x, pt.y, 6, { { 0.5, 1, 0.5 } }, 40, 40, { glow = true, grav = 0 })
                Audio.play("pickup", { pitch = 0.7 })
                st.mode = "fight"
            end
        else -- carried: ride on the rescuer's back
            local c = st.carrier
            if not valid(c, st.carrierUid) or c.st.mode ~= "carry" then
                st.mode, e.z = "fight", 0
                return
            end
            e.x, e.y = c.x + math.cos(c.angle) * 1.5, c.y + math.sin(c.angle) * 1.5
            e.mx, e.my, e.kvx, e.kvy = c.mx, c.my, 0, 0
            e.z = 5
        end
    end,
    draw = function(e)
        if e.st.mode ~= "fetch" and e.st.mode ~= "carry" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(0.5, 1, 0.5, 0.5)
        love.graphics.rectangle("fill", math.floor(x) - 1, math.floor(y) - 9, 3, 1)
        love.graphics.rectangle("fill", math.floor(x), math.floor(y) - 10, 1, 3)
    end,
}
