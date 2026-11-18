-- Weaver ant: works in pairs holding a strand of larval silk between them. The pair spreads out
-- on either side of you and sweeps the strand across, so it sticks to you and slows you down.
-- Dash through a strand to snip it (the pair needs a few seconds to spin a new one).
-- params: spread (half-width of the net, 34), sweep (how far past you they aim, 26),
--         maxLen (strand breaks beyond this, 130), slow (speed x while stuck, 0.45)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 1, 1 }
local PFX_2 = { grav = 40 }
local PFX_LIST_1 = { PFX_1 }

local function partnerOf(e)
    local pt = e.st.partner
    if pt and pt.uid == e.st.partnerUid and not pt.dead and pt.st.partner == e then return pt end
    e.st.partner = nil
    return nil
end

-- distance from point (px, py) to segment a-b
local function segDist(px, py, ax, ay, bx, by)
    local vx, vy = bx - ax, by - ay
    local l2 = vx * vx + vy * vy + 0.0001
    local t = math.max(0, math.min(1, ((px - ax) * vx + (py - ay) * vy) / l2))
    local cx, cy = ax + vx * t - px, ay + vy * t - py
    return math.sqrt(cx * cx + cy * cy)
end

return {
    name = "Silk pair",
    init = function(e) e.st.cd, e.st.cutT = love.math.random() * 0.4, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local pt = partnerOf(e)
        if st.cutT > 0 then st.cutT = st.cutT - dt end
        if not pt then
            -- look for a free weaver to pair up with
            st.cd = st.cd - dt
            if st.cd <= 0 then
                st.cd = 0.4
                local list, n = world:queryEnemies(e.x, e.y, 90)
                for i = 1, n do
                    local o = list[i]
                    if o ~= e and o.def == e.def and not o.dead and not partnerOf(o) then
                        st.partner, st.partnerUid, st.side = o, o.uid, 1
                        o.st.partner, o.st.partnerUid, o.st.side = e, e.uid, -1
                        st.cutT, o.st.cutT = 0, 0
                        pt = o
                        break
                    end
                end
            end
            if not pt then
                local dx, dy, d = AI.toPlayer(e, world)
                e.mx, e.my = dx / d * e.speed, dy / d * e.speed
                return
            end
        end
        -- pincer: each partner heads for its side of the player, a bit past them
        local cx, cy = (e.x + pt.x) / 2, (e.y + pt.y) / 2
        local ux, uy = p.x - cx, p.y - cy
        local ul = math.sqrt(ux * ux + uy * uy) + 0.0001
        ux, uy = ux / ul, uy / ul
        local spread, sweep = params.spread or 34, params.sweep or 26
        AI.goTo(e, p.x - uy * st.side * spread + ux * sweep, p.y + ux * st.side * spread + uy * sweep, e.speed)
        -- the strand (checked once per pair)
        if st.side == 1 and st.cutT <= 0 then
            local len = math.sqrt((e.x - pt.x) ^ 2 + (e.y - pt.y) ^ 2)
            st.touch = false
            if len < (params.maxLen or 130) and segDist(p.x, p.y, e.x, e.y, pt.x, pt.y) < p.radius + 2 then
                if p.dashT > 0 then
                    st.cutT, pt.st.cutT = 3, 3
                    world:floatText(p.x, p.y, "SNIP!", { 1, 1, 1 }, false)
                    world.particles:burst(p.x, p.y, 6, PFX_LIST_1, 60, 30, PFX_2)
                    Audio.play("hit", { pitch = 2 })
                else
                    st.touch = true
                    world:slowPlayer(params.slow or 0.45)
                end
            end
        end
    end,
    -- The silk strand is part of the world, so it's always drawn (not just as a warning).
    drawUnder = function(e, world)
        local st = e.st
        local pt = st.side == 1 and st.cutT <= 0 and partnerOf(e)
        if not pt then return end
        local len = math.sqrt((e.x - pt.x) ^ 2 + (e.y - pt.y) ^ 2)
        if len > (e.params.maxLen or 130) then return end
        local x1, y1 = Iso.toScreen(e.x, e.y, 3)
        local x2, y2 = Iso.toScreen(pt.x, pt.y, 3)
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2 + 2 + len * 0.02
        local a = st.touch and 0.95 or 0.55
        love.graphics.setColor(0.95, 0.95, 0.9, a)
        love.graphics.line(x1, y1, mx, my, x2, y2)
        love.graphics.setColor(1, 1, 1, a * 0.4)
        love.graphics.line(x1, y1 + 1, mx, my + 1, x2, y2 + 1)
    end,
}
