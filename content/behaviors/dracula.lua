-- Dracula ant: has the fastest strike in the animal kingdom. Walks up, cocks its jaws for a
-- split second and snaps them so fast it sends a shockwave cone that hurls you back.
-- When hurt it drinks the blood of nearby ants to heal itself (adults really do feed on their
-- own larvae's blood). Hit it while the jaws are cocked to jam them.
-- params: range (24), windup (0.2), snapDamage (9), knock (320), cone (radians, 1.5),
--         cooldown (1.5), drainRange (36), drainRate (hp per second, 8), stagger (0.8)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")
local util = require("src.core.util")

local function victimOf(e)
    local v = e.st.victim
    if v and v.uid == e.st.victimUid and not v.dead then return v end
    e.st.victim = nil
    return nil
end

return {
    name = "Shockwave snap",
    init = function(e) e.st.mode, e.st.cd, e.st.scan = "approach", 0, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local range = params.range or 24
        if st.mode == "approach" then
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 and d < range + p.radius then
                st.mode, st.t, st.dx, st.dy, e.hitPad = "windup", params.windup or 0.2, dx / d, dy / d, 5
            end
            -- feeding: wounded, it drains a neighbour
            if e.hp < e.maxHp then
                st.scan = st.scan - dt
                local v = victimOf(e)
                if not v and st.scan <= 0 then
                    st.scan = 0.3
                    local list, n = world:queryEnemies(e.x, e.y, params.drainRange or 36)
                    for i = 1, n do
                        local o = list[i]
                        if o ~= e and not o.dead and o.def ~= e.def and not o.def.boss then
                            st.victim, st.victimUid = o, o.uid
                            break
                        end
                    end
                    v = victimOf(e)
                end
                if v then
                    local amt = (params.drainRate or 8) * dt * world:hpScale()
                    if (v.x - e.x) ^ 2 + (v.y - e.y) ^ 2 > (params.drainRange or 36) ^ 2 * 1.4 then
                        st.victim = nil
                    else
                        v.hp = v.hp - amt
                        e.hp = math.min(e.maxHp, e.hp + amt)
                        if v.hp <= 0 then world:killEnemy(v) end
                    end
                end
            else
                st.victim = nil
            end
        elseif st.mode == "windup" then
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then
                e.hitPad = 0
                local a = math.atan2(st.dy, st.dx)
                local reach = range + 10
                world:addFx({ kind = "arc", x = e.x, y = e.y, r = reach, a = a, arc = params.cone or 1.5, life = 0.12, color = { 1, 0.4, 0.3 } })
                if d < reach + p.radius and math.abs(util.angleDiff(a, math.atan2(dy, dx))) < (params.cone or 1.5) / 2 + 0.3 then
                    p:hurt((params.snapDamage or 9) * (e.damage / math.max(0.1, e.def.damage)), e)
                    p:knock(dx, dy, params.knock or 320)
                    world.camera:shake(0.25)
                end
                Audio.play("hit", { pitch = 2.2 })
                st.mode, st.cd = "approach", params.cooldown or 1.5
            end
        else -- stagger
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.cd = "approach", 0.5 end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode == "windup" then Combat.stagger(world, e, e.params.stagger or 0.8, opts) end
        return 1
    end,
    draw = function(e)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        if st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        local x2, y2 = Iso.toScreen(e.x + st.dx * 22, e.y + st.dy * 22)
        love.graphics.setColor(1, 0.35, 0.3, math.floor(st.t * 40) % 2 == 0 and 0.9 or 0.4)
        love.graphics.line(x, y, x2, y2)
    end,
    -- a thin red thread while it feeds
    drawUnder = function(e)
        local v = victimOf(e)
        if not v then return end
        local x1, y1 = Iso.toScreen(e.x, e.y, 2)
        local x2, y2 = Iso.toScreen(v.x, v.y, 2)
        love.graphics.setColor(0.9, 0.1, 0.15, 0.6 + 0.3 * math.sin(love.timer.getTime() * 12))
        love.graphics.line(x1, y1, x2, y2)
    end,
}
