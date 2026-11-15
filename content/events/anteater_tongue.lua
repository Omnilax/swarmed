-- An anteater noses at the edge of the arena and flicks its long sticky tongue across a lane,
-- three times. Everything in the lane is licked up: ants are eaten, you are hurt and dragged.
-- The red lane warns you first; lure a crowd into it.
local Env = require("src.game.envfx")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local WARN, OUT, HOLD, BACK = 1.4, 0.22, 0.18, 0.4
local WIDTH = 9

local function aim(world, st)
    local p = world.player
    -- the snout sits just outside one edge, the tongue reaches through (near) the player
    local x1, y1, x2, y2 = Env.crossing(world, p.x, p.y, 60)
    local dx, dy = x2 - x1, y2 - y1
    local l = math.sqrt(dx * dx + dy * dy) + 0.0001
    local reach = math.min(l, 300 + love.math.random() * 80)
    st.x1, st.y1 = x1, y1
    st.x2, st.y2 = x1 + dx / l * reach, y1 + dy / l * reach
    st.phase, st.pt = "warn", 0
    Audio.play("rumble", { pitch = 1.6 })
end

return {
    name = "Anteater",
    description = "A tongue licks across the red lane. Lead the ants into it!",
    color = { 1, 0.55, 0.45 },
    kind = "hazard",
    weight = 9, minWave = 3,
    start = function(world, ev) ev.st.licks = 0 aim(world, ev.st) end,
    update = function(world, ev, dt)
        local st = ev.st
        st.pt = st.pt + dt
        if st.phase == "warn" and st.pt >= WARN then
            st.phase, st.pt = "out", 0
            Audio.play("dash", { pitch = 0.5 })
        elseif st.phase == "out" and st.pt >= OUT then
            st.phase, st.pt = "hold", 0
            local eaten = Env.strikeLane(world, st.x1, st.y1, st.x2, st.y2, WIDTH, 999, { force = 0, bossMul = 0.15 })
            if eaten >= 5 then world:floatText(st.x2, st.y2, eaten .. " LICKED UP", { 1, 0.6, 0.6 }, true) end
            if Env.playerInLane(world, st.x1, st.y1, st.x2, st.y2, WIDTH) then
                local p = world.player
                if Env.hurtPlayer(world, 14, p.x, p.y) then p:knock(st.x1 - p.x, st.y1 - p.y, 160) end
            end
            world.camera:shake(0.15)
        elseif st.phase == "hold" and st.pt >= HOLD then
            st.phase, st.pt = "back", 0
        elseif st.phase == "back" and st.pt >= BACK then
            st.licks = st.licks + 1
            if st.licks >= (ev.opts.licks or 3) then ev.done = true else st.phase, st.pt = "rest", 0 end
        elseif st.phase == "rest" and st.pt >= 1.2 then
            aim(world, st)
        end
    end,
    drawGround = function(world, ev)
        local st = ev.st
        if st.phase == "warn" then Env.warnLane(st.x1, st.y1, st.x2, st.y2, WIDTH, st.pt / WARN, world.time) end
    end,
    drawAir = function(world, ev)
        local st, lg = ev.st, love.graphics
        local k = 0
        if st.phase == "out" then k = st.pt / OUT elseif st.phase == "hold" then k = 1 elseif st.phase == "back" then k = 1 - st.pt / BACK end
        if k > 0 then Env.tongue(st.x1, st.y1, st.x2, st.y2, k, 4) end
        if st.phase ~= "rest" then
            -- the tip of a long grey snout poking in at the edge
            local dx, dy = st.x2 - st.x1, st.y2 - st.y1
            local l = math.sqrt(dx * dx + dy * dy) + 0.0001
            local ax, ay = Iso.toScreen(st.x1 - dx / l * 30, st.y1 - dy / l * 30, 4)
            local bx, by = Iso.toScreen(st.x1 + dx / l * 6, st.y1 + dy / l * 6, 3)
            lg.setLineWidth(9)
            lg.setColor(0.38, 0.34, 0.3, 1)
            lg.line(ax, ay, bx, by)
            lg.setLineWidth(5)
            lg.setColor(0.55, 0.5, 0.44, 1)
            lg.line(ax, ay - 2, bx, by - 1)
            lg.setLineWidth(1)
            lg.setColor(0.1, 0.08, 0.08, 1)
            lg.circle("fill", bx, by, 2)
        end
    end,
}
