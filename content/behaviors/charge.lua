-- Approach, stop and wind up (telegraphed), then dash in a straight line.
-- Hitting the ant while it winds up or dashes staggers it out of the charge (and a hit during
-- the dash counts as a counter for extra damage). Charging ants are easier to hit, too.
-- params: range (start charging within), windup, dashSpeed, dashTime, cooldown,
--         stagger (seconds dazed when interrupted, 0.9),
--         knock (shove the player this hard when the dash connects, then stop: head-butts),
--         rally (enemy id: when one of those dies nearby, rush in angry for a moment)
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")

return {
    name = "Charge",
    init = function(e) e.st.mode, e.st.t, e.st.cd, e.st.rallyT = "approach", 0, 0, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy = p.x - e.x, p.y - e.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        if st.mode == "approach" then
            st.cd = st.cd - dt
            -- recruitment: a minor dies close by and the majors come running
            if params.rally then
                local deaths = world.recentDeaths
                for i = 1, deaths.n do
                    local k = deaths[i]
                    if k.id == params.rally and (k.x - e.x) ^ 2 + (k.y - e.y) ^ 2 < 120 * 120 then st.rallyT = 1.6 break end
                end
            end
            local sp = e.speed
            if st.rallyT > 0 then st.rallyT, sp = st.rallyT - dt, sp * 1.9 end
            e.mx, e.my = dx / d * sp, dy / d * sp
            if d < (params.range or 90) and st.cd <= 0 then
                st.mode, st.t = "windup", params.windup or 0.6
                st.dx, st.dy = dx / d, dy / d
                e.hitPad = 6
            end
        elseif st.mode == "windup" then
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t = "dash", params.dashTime or 0.35 end
        elseif st.mode == "dash" then
            local s = params.dashSpeed or 240
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if params.knock and d < p.radius + e.radius + 2 then
                p:hurt(e.damage * 1.5, e)
                p:knock(st.dx, st.dy, params.knock)
                world.camera:shake(0.2)
                st.t = 0
            end
            if st.t <= 0 then st.mode, st.cd, e.hitPad = "approach", params.cooldown or 2, 0 end
        else -- stagger
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.cd = "approach", (params.cooldown or 2) * 0.5 end
        end
    end,
    onHit = function(e, world, opts)
        local mode = e.st.mode
        if mode ~= "windup" and mode ~= "dash" then return 1 end
        Combat.stagger(world, e, e.params.stagger or 0.9, opts)
        return mode == "dash" and 1.5 or 1
    end,
    -- Telegraph: a flashing line showing where the dash will go.
    draw = function(e, world)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        if st.mode ~= "windup" then return end
        local len = (e.params.dashSpeed or 240) * (e.params.dashTime or 0.35)
        local x1, y1 = Iso.toScreen(e.x, e.y)
        local x2, y2 = Iso.toScreen(e.x + st.dx * len, e.y + st.dy * len)
        local blink = math.floor(st.t * 12) % 2 == 0
        love.graphics.setColor(1, 0.25, 0.2, blink and 0.8 or 0.35)
        love.graphics.line(x1, y1, x2, y2)
    end,
}
