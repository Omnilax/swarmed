-- Termite soldier: walks with the colony, jaws first, and plugs gaps with its armoured head
-- (it has a shield: hits aimed at termites behind it glance off). Hurt it, or kill a termite
-- next to it, and it drums its head on the ground: every termite nearby goes into a frenzy
-- (faster for a few seconds) and the soldier itself charges in to scissor you with its jaws.
-- params: range (snap reach, 14), windup (0.3), snapDamage (10), drum (seconds drumming, 0.7),
--         alarmRadius (90), frenzy (speed x, 1.6), frenzyTime (3.5), alarmCd (6),
--         rush (speed x, 2.4), rushTime (0.8)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")
local Content = require("src.content")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 0.55, 0.2 }
local PFX_2 = { glow = true, grav = -20 }

local function alarm(e)
    local st = e.st
    if st.alarmCd > 0 or st.mode == "drum" or st.mode == "stagger" then return end
    st.mode, st.t = "drum", e.params.drum or 0.7
end

return {
    name = "Head-drummer",
    init = function(e)
        e.st.mode, e.st.t, e.st.alarmCd, e.st.cd = "advance", 0, 0, 0
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.alarmCd = st.alarmCd - dt
        st.cd = st.cd - dt
        -- a termite dying close by sounds the alarm
        if st.alarmCd <= 0 and st.mode == "advance" then
            local deaths = world.recentDeaths
            for i = 1, deaths.n do
                local k = deaths[i]
                local def = Content.enemies:get(k.id)
                if def and def.family == "termite" and (k.x - e.x) ^ 2 + (k.y - e.y) ^ 2 < 50 * 50 then alarm(e) break end
            end
        end
        if st.mode == "advance" or st.mode == "rush" then
            local s = st.mode == "rush" and e.speed * (params.rush or 2.4) or e.speed
            e.mx, e.my = dx / d * s, dy / d * s
            if st.mode == "rush" then
                st.t = st.t - dt
                if st.t <= 0 then st.mode = "advance" end
            end
            if d < (params.range or 14) + p.radius and st.cd <= 0 then
                st.mode, st.t, e.hitPad = "windup", params.windup or 0.3, 4
            end
        elseif st.mode == "windup" then
            e.mx, e.my = dx / d * 2, dy / d * 2
            st.t = st.t - dt
            if st.t <= 0 then
                e.hitPad = 0
                if d < (params.range or 14) + p.radius + 5 then
                    p:hurt((params.snapDamage or 10) * (e.damage / math.max(0.1, e.def.damage)), e)
                    p:knock(dx, dy, 120)
                    world:addFx({ kind = "ring", x = e.x + dx / d * 7, y = e.y + dy / d * 7, r = 8, life = 0.15, color = { 1, 0.8, 0.5 } })
                end
                Audio.play("hit", { pitch = 1.4 })
                st.mode, st.cd = "advance", 1.1
            end
        elseif st.mode == "drum" then
            -- rattling its head against the ground
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if math.floor(st.t * 24) % 2 == 0 then e.squash = 0.06 end
            if st.t <= 0 then
                local r = params.alarmRadius or 90
                local list, n = world:queryEnemies(e.x, e.y, r)
                local mul, time = params.frenzy or 1.6, params.frenzyTime or 3.5
                for i = 1, n do
                    local o = list[i]
                    if not o.dead and o.def.family == "termite" and not o.def.boss and o.slowT <= 0 then
                        -- slowMul above 1 is a haste (world.lua scales movement by it while slowT runs)
                        o.slowT, o.slowMul = time, mul
                        world.particles:spawn(o.x, o.y, 6, 0, 0, 25, 0.5, PFX_1, 1, PFX_2)
                    end
                end
                world:addFx({ kind = "ring", x = e.x, y = e.y, r = r, life = 0.35, color = { 1, 0.6, 0.25 } })
                Audio.play("dash", { pitch = 0.45 })
                st.alarmCd = params.alarmCd or 6
                st.mode, st.t = "rush", params.rushTime or 0.8
            end
        else -- stagger
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.cd = "advance", 0.4 end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode == "windup" then
            Combat.stagger(world, e, 0.8, opts)
            return 1
        end
        if e.hp > 1 then alarm(e) end
        return 1
    end,
    draw = function(e, world)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        local x, y = Iso.toScreen(e.x, e.y)
        if st.mode == "drum" then
            local k = 1 - st.t / (e.params.drum or 0.7)
            love.graphics.setColor(1, 0.6, 0.25, 0.6 * (1 - k))
            love.graphics.ellipse("line", x, y, 6 + k * 14, (6 + k * 14) * 0.5)
        elseif st.mode == "windup" then
            love.graphics.setColor(1, 0.85, 0.4, math.floor(st.t * 30) % 2 == 0 and 0.9 or 0.3)
            love.graphics.circle("line", x, y, 6)
        end
    end,
}
