-- Real ant formation behaviour.
--   March: ants spawned together form a follow-the-leader column. Each one walks to where the
--          ant ahead of it was a moment ago (its breadcrumb), so columns snake and flow.
--          The head ant wanders toward the player on a gently curving path.
--   Surround: within engageRange the column breaks up. Each ant takes an angle around the player
--          and a ring that tightens over time, so the swarm encircles you and closes in.
-- params: engageRange (110), ringShrink (units/s, 22), orbit (rad/s, 0.35), spacing (6),
--         gait (stop-and-go strength 0..1, 0.35)
local util = require("src.core.util")

local TRAIL = 6         -- breadcrumbs kept per ant
local TRAIL_DT = 0.06   -- seconds between breadcrumbs

local function leaderOf(e)
    local l = e.leader
    if l and l.uid == e.leaderUid and not l.dead then return l end
    e.leader = nil
    return nil
end

return {
    name = "Column",
    init = function(e)
        e.st.trail, e.st.ti, e.st.tt = {}, 0, 0
        e.st.phase = love.math.random() * 6.28
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        -- breadcrumbs for whoever follows us
        st.tt = st.tt - dt
        if st.tt <= 0 then
            st.tt = TRAIL_DT
            st.ti = st.ti % TRAIL + 1
            local b = st.trail[st.ti] or {}
            b.x, b.y = e.x, e.y
            st.trail[st.ti] = b
        end

        local dx, dy = p.x - e.x, p.y - e.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        local engage = params.engageRange or 110
        local speed = e.speed
        st.phase = st.phase + dt * 7
        local gait = params.gait or 0.35

        if st.mode == "surround" or d < engage then
            if st.mode ~= "surround" then
                st.mode = "surround"
                st.slot = math.atan2(e.y - p.y, e.x - p.x)
                st.ring = d
                st.dir = love.math.random() < 0.5 and -1 or 1
            end
            st.ring = math.max(p.radius + e.radius * 0.5, st.ring - (params.ringShrink or 22) * dt)
            st.slot = st.slot + st.dir * (params.orbit or 0.35) * dt
            local tx = p.x + math.cos(st.slot) * st.ring - e.x
            local ty = p.y + math.sin(st.slot) * st.ring - e.y
            local tl = math.sqrt(tx * tx + ty * ty) + 0.0001
            local s = speed * math.min(1, tl / 6) * (1 - gait + gait * math.max(0, math.sin(st.phase)))
            e.mx, e.my = tx / tl * s, ty / tl * s
            if d > engage * 2 then st.mode = nil end
            return
        end

        local leader = leaderOf(e)
        if leader then
            -- follow the oldest breadcrumb of the ant ahead
            local lt = leader.st.trail
            local b = lt and lt[leader.st.ti % TRAIL + 1] or leader
            if not b or not b.x then b = leader end
            local tx, ty = b.x - e.x, b.y - e.y
            local tl = math.sqrt(tx * tx + ty * ty) + 0.0001
            local gap = (params.spacing or 6)
            local s = speed * util.clamp((tl - gap * 0.5) / gap, 0, 1.25)
            e.mx, e.my = tx / tl * s, ty / tl * s
        else
            -- column head: curving approach with stop-and-go pace
            local wob = math.sin(st.phase * 0.18) * 0.7
            local c, s0 = math.cos(wob), math.sin(wob)
            local nx, ny = dx / d, dy / d
            nx, ny = nx * c - ny * s0, nx * s0 + ny * c
            local s = speed * (1 - gait + gait * math.max(0, math.sin(st.phase * 0.6)))
            e.mx, e.my = nx * s, ny * s
        end
    end,
}
