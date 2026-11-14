-- Driver ant (siafu): a river of ants whose soldiers lock their jaws onto you and won't let go.
-- Each one hanging on slows you down and keeps biting. Dash to shake them all off.
-- params: hold (max seconds latched, 6), slowPer (speed lost per ant, 0.07), minSlow (0.35),
--         wobble (river sway, 0.5)
local AI = require("src.game.ai")

local function fling(e, world, p)
    local st = e.st
    local dx, dy = e.x - p.x, e.y - p.y
    local l = math.sqrt(dx * dx + dy * dy) + 0.0001
    e.kvx, e.kvy = dx / l * 220, dy / l * 220
    e.z = 0
    st.mode, st.t = "flung", 0.8
end

return {
    name = "Latch on",
    init = function(e) e.st.mode, e.st.t, e.st.wt = "approach", 0, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "approach" then
            st.wt = st.wt + dt * 3
            local a = math.sin(st.wt) * (params.wobble or 0.5)
            local c, s = math.cos(a), math.sin(a)
            local nx, ny = dx / d, dy / d
            e.mx, e.my = (nx * c - ny * s) * e.speed, (nx * s + ny * c) * e.speed
            if d < p.radius + e.radius + 1.5 and p.dashT <= 0 and not p.dead then
                st.mode, st.t = "latched", params.hold or 6
                st.ang = math.atan2(e.y - p.y, e.x - p.x)
                if not world.flags.latchHint then
                    world.flags.latchHint = true
                    world:floatText(p.x, p.y, "Dash to shake them off!", { 1, 0.85, 0.4 }, false)
                end
            end
        elseif st.mode == "latched" then
            -- hang on to the player's side
            local r = p.radius + e.radius * 0.5
            local tx, ty = p.x + math.cos(st.ang) * r, p.y + math.sin(st.ang) * r
            e.x, e.y, e.mx, e.my, e.kvx, e.kvy = tx, ty, 0, 0, 0, 0
            e.z = 2
            world.latchCount = world.latchCount + 1
            world:slowPlayer(math.max(params.minSlow or 0.35, 1 - (params.slowPer or 0.07) * world.latchCount))
            st.t = st.t - dt
            if p.dashT > 0 or st.t <= 0 or p.dead then fling(e, world, p) end
        else -- flung off, dazed
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "approach" end
        end
    end,
}
