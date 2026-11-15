-- Sparrow (boss encounter): circles high above the player as a shadow (out of reach), aims a
-- swoop down a line (a warning for `aim` s), then dives along it at `swoop` units/s snatching
-- every ant on the way and hitting the player for `damage`. It lands at the end and pecks
-- around for `land` s (ants in reach are eaten, the player is pecked for `peckDamage`): the
-- only time it can be hit. Then it takes off again.
-- params: circle (3.4), aim (1.0), swoop (420), land (3.6), peck (0.65), damage (18), peckDamage (9)
local Env = require("src.game.envfx")
local Audio = require("src.core.audio")

local HIGH = 90

local function takeOff(e)
    local st = e.st
    st.mode, st.t = "circle", 0
    e.hidden = true
    st.orbit = st.orbit or love.math.random() * math.pi * 2
end

return {
    name = "Swooping bird",
    init = function(e) takeOff(e) e.z = HIGH e.st.face = 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        st.t = st.t + dt
        if st.peckT then st.peckT = math.max(0, st.peckT - dt) end
        if st.mode == "circle" then
            e.hidden = true
            e.z = math.min(HIGH, e.z + dt * 120)
            st.orbit = st.orbit + dt * 0.9
            local tx, ty = p.x + math.cos(st.orbit) * 140, p.y + math.sin(st.orbit) * 140
            local dx, dy = tx - e.x, ty - e.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            local s = math.min(240, d * 3)
            e.mx, e.my = dx / d * s, dy / d * s
            if st.t >= (params.circle or 3.4) then
                st.mode, st.t = "aim", 0
                local ax, ay = p.x - e.x, p.y - e.y
                local l = math.sqrt(ax * ax + ay * ay) + 0.0001
                st.x1, st.y1 = e.x, e.y
                local S = world.size
                st.x2 = math.max(20, math.min(S - 20, p.x + ax / l * 130))
                st.y2 = math.max(20, math.min(S - 20, p.y + ay / l * 130))
                st.face = math.atan2(ay, ax)
                Audio.play("queen", { pitch = 1.9, volume = 0.5 })
            end
        elseif st.mode == "aim" then
            e.mx, e.my = 0, 0
            if st.t >= (params.aim or 1.0) then
                st.mode, st.t, st.hit, st.hitPlayer = "swoop", 0, {}, false
                e.hidden = false
                Audio.play("dash", { pitch = 0.4 })
            end
        elseif st.mode == "swoop" then
            local dx, dy = st.x2 - e.x, st.y2 - e.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            local s = params.swoop or 420
            e.mx, e.my = dx / d * s, dy / d * s
            e.z = math.max(2, e.z - dt * 260)
            for _, o in ipairs(require("src.game.combat").collect(world, e.x, e.y, 16)) do
                if o ~= e and not st.hit[o.uid] then
                    st.hit[o.uid] = true
                    Env.hurtAnt(world, o, 999, { air = true, bossMul = 0.2 })
                end
            end
            if not st.hitPlayer and Env.playerIn(world, e.x, e.y, 14) then
                st.hitPlayer = true
                Env.hurtPlayer(world, params.damage or 18, e.x, e.y, { force = 230, name = "sparrow" })
            end
            if d < s * dt + 2 or st.t > 2.5 then
                st.mode, st.t, st.peckCd = "land", 0, 0.4
                e.mx, e.my, e.z = 0, 0, 0
                world.camera:shake(0.2)
            end
        elseif st.mode == "land" then
            e.hidden = false
            e.z = 0
            -- hop about, pecking at whatever is near
            st.peckCd = st.peckCd - dt
            local target, best = nil, 40 * 40
            local list, n = world:queryEnemies(e.x, e.y, 40)
            for i = 1, n do
                local o = list[i]
                local dd = (o.x - e.x) ^ 2 + (o.y - e.y) ^ 2
                if o ~= e and not o.dead and not o.hidden and dd < best then target, best = o, dd end
            end
            local pd = math.sqrt((p.x - e.x) ^ 2 + (p.y - e.y) ^ 2)
            local tx, ty = p.x, p.y
            if target and not target.def.encounter then tx, ty = target.x, target.y end
            local dx, dy = tx - e.x, ty - e.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            st.face = math.atan2(dy, dx)
            e.mx, e.my = (d > 20 and dx / d * 35 or 0), (d > 20 and dy / d * 35 or 0)
            if st.peckCd <= 0 then
                st.peckCd, st.peckT = params.peck or 0.65, 0.15
                if pd < 26 then Env.hurtPlayer(world, params.peckDamage or 9, e.x, e.y, { force = 90, name = "sparrow" }) end
                Env.strikeCircle(world, e.x + dx / d * 12, e.y + dy / d * 12, 10, 999, { bossMul = 0.2 })
            end
            if st.t >= (params.land or 3.6) then takeOff(e) Audio.play("dash", { pitch = 0.6 }) end
        end
    end,
    drawUnder = function(e, world)
        local st = e.st
        -- its shadow, darker and sharper the lower it is
        local k = 1 - math.min(1, (e.z or 0) / HIGH)
        if st.mode ~= "land" then Env.shadow(e.x, e.y, 26 - 10 * k, 0.45 + 0.4 * k) end
        if st.mode == "aim" then
            Env.warnLane(st.x1, st.y1, st.x2, st.y2, 14, st.t / 1.0, world.time)
        end
    end,
}
