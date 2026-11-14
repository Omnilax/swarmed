-- Japanese honey bee: when a hornet gets into their hive they mob it, pack around it in a
-- ball and vibrate their flight muscles until it cooks (at 46 C, which they survive and the
-- hornet doesn't). They do it to you: they don't sting, they cling all round you, and the more
-- of them in the ball the faster the heat rises (the orange ring). At full heat you cook.
-- Kill some to cool down, or dash to burst the ball apart.
-- params: join (distance they mob from, 34), minBall (bees needed to heat up, 4), rate (heat per
--         second per extra bee, 0.11), cool (0.3), cook (damage x at full heat, 6)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "Heat ball",
    init = function(e) e.st.cd = 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local list, g = AI.group(world, e.def.id)
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        st.cd = st.cd - dt
        if st.rank == 1 then
            -- the group's heat: rises with every bee in the ball, cools when it breaks up
            local inBall = 0
            for i = 1, #list do if list[i].st.balled then inBall = inBall + 1 end end
            g.count = inBall
            local need = params.minBall or 4
            g.heat = g.heat or 0
            if inBall >= need then
                g.heat = g.heat + dt * (inBall - need + 1) * (params.rate or 0.11)
            else
                g.heat = math.max(0, g.heat - dt * (params.cool or 0.3))
            end
            if p.dashT > 0 and inBall > 0 then
                -- dashing bursts the ball apart
                g.heat = g.heat * 0.5
                for i = 1, #list do
                    local o = list[i]
                    if o.st.balled then
                        o.st.balled, o.st.cd = nil, 1
                        local ox, oy = o.x - p.x, o.y - p.y
                        local l = math.sqrt(ox * ox + oy * oy) + 0.001
                        o.kvx, o.kvy = ox / l * 180, oy / l * 180
                    end
                end
            end
            if g.heat >= 1 and not p.dead then
                g.heat = 0.25
                p:hurt(e.damage * (params.cook or 6), e)
                world:floatText(p.x, p.y, "COOKED", { 1, 0.55, 0.2 }, true)
                world:addFx({ kind = "ring", x = p.x, y = p.y, r = 26, life = 0.3, color = { 1, 0.55, 0.15 } })
                world.camera:shake(0.3)
                Audio.play("boom", { pitch = 1.3 })
            end
            if g.heat > 0.3 and not world.flags.heatHint then
                world.flags.heatHint = true
                world:floatText(p.x, p.y, "They're cooking you! Dash out", { 1, 0.7, 0.3 }, false)
            end
        end
        if st.balled then
            -- clinging round you, buzzing, each in its own spot of the ring
            local n = math.max(1, #list)
            local a = (st.rank or 1) / n * math.pi * 2 + world.time * 1.2
            local r = p.radius + e.radius + 1
            AI.goTo(e, p.x + math.cos(a) * r, p.y + math.sin(a) * r, e.speed * 3)
            AI.hover(e, world, dt, 3)
            if d > 30 then st.balled = nil end
        else
            AI.hover(e, world, dt, 7)
            local sgn = st.cd > 0 and -1 or 1
            e.mx, e.my = dx / d * e.speed * sgn, dy / d * e.speed * sgn
            if st.cd <= 0 and d < (params.join or 34) and not p.dead then st.balled = true end
        end
    end,
    -- the heat: an orange ring round you that thickens and glows as it builds
    drawUnder = function(e, world)
        local _, g = AI.group(world, e.def.id)
        local h = g.heat or 0
        if h <= 0.02 or g.drawnAt == world.time then return end
        g.drawnAt = world.time      -- whichever bee is on screen draws it, once
        local p = world.player
        local x, y = Iso.toScreen(p.x, p.y)
        local lg = love.graphics
        lg.setColor(1, 0.45 + 0.3 * h, 0.1, 0.25 + 0.5 * h)
        lg.setLineWidth(1 + math.floor(h * 3))
        lg.ellipse("line", x, y, 16, 8)
        lg.setLineWidth(1)
        if h > 0.7 then
            lg.setColor(1, 0.8, 0.4, (h - 0.7) * 2 * (0.6 + 0.4 * math.sin(world.time * 30)))
            lg.ellipse("fill", x, y, 14, 7)
        end
    end,
}
