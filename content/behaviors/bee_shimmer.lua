-- Giant honey bee: their open-air combs are covered by a curtain of bees that defends the colony
-- with "shimmering": a wave ripples across the curtain as bee after bee flips up. Here the bees
-- hang in a sheet facing you; come close, or hit one, and a wave runs along the sheet with
-- each bee darting out to sting in turn. Go round the end of the sheet, not through it.
-- params: distance (sheet from you, 70), spacing (between bees, 7), trigger (how close sets it
--         off, 48), step (delay between neighbours, 0.05), lunge (0.32), cooldown (3)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")

return {
    name = "Shimmering curtain",
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local list, g = AI.group(world, e.def.id)
        local n = #list
        local dist = params.distance or 70
        -- the first bee of the group runs the shared timers and keeps the sheet facing you
        if st.rank == 1 then
            local cx, cy = 0, 0
            for i = 1, n do cx, cy = cx + list[i].x, cy + list[i].y end
            local want = math.atan2(cy / n - p.y, cx / n - p.x)
            g.ang = (g.ang or want) + require("src.core.util").angleDiff(g.ang or want, want) * math.min(1, dt * 0.8)
            g.cd = (g.cd or 1) - dt
            g.waveT = (g.waveT or 99) + dt
            local sx, sy = p.x + math.cos(g.ang) * dist, p.y + math.sin(g.ang) * dist
            if g.cd <= 0 and ((p.x - sx) ^ 2 + (p.y - sy) ^ 2 < (params.trigger or 48) ^ 2 or g.hit) then
                g.waveT, g.cd = 0, params.cooldown or 3
            end
            g.hit = nil
        end
        local ang = g.ang or 0
        local c, s = math.cos(ang), math.sin(ang)
        local slot = ((st.rank or 1) - (n + 1) / 2) * (params.spacing or 7)
        local tx, ty = p.x + c * dist - s * slot, p.y + s * dist + c * slot
        local mine = (g.waveT or 99) - ((st.rank or 1) - 1) * (params.step or 0.05)
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        if mine >= 0 and mine < (params.lunge or 0.32) then
            -- my turn in the wave: dart at you
            AI.hover(e, world, dt, 1)
            e.mx, e.my = dx / d * e.speed * 3.2, dy / d * e.speed * 3.2
            if not st.stung and d < p.radius + e.radius + 2 and not p.dead then
                st.stung = true
                AI.sting(e, world, 1)
            end
        else
            if mine < 0 or mine > 1 then st.stung = nil end
            AI.hover(e, world, dt, 6)
            AI.goTo(e, tx, ty, e.speed * (mine >= 0 and mine < 1 and 2 or 1))
            if mine < -0.6 or mine > 1.5 then e.mx, e.my = e.mx + dx / d * 2, e.my + dy / d * 2 end   -- face you
        end
    end,
    onHit = function(e, world)
        local _, g = AI.group(world, e.def.id)
        g.hit = true
        return 1
    end,
    -- the sheet's ripple: a glint on each bee as the wave passes
    draw = function(e, world)
        local _, g = AI.group(world, e.def.id)
        local mine = (g.waveT or 99) - ((e.st.rank or 1) - 1) * (e.params.step or 0.05)
        if mine < -0.25 or mine > 0 then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 0.9, 0.5, 0.7)
        love.graphics.rectangle("fill", math.floor(x) - 2, math.floor(y) - 6, 5, 1)
    end,
}
