-- A gardener's boot: a shadow grows over you and follows you (slower than you walk), then
-- locks and stomps. Everything under it is flattened, you included if you stay.
local Env = require("src.game.envfx")
local Audio = require("src.core.audio")

local FOLLOW, LOCK = 2.6, 0.7
local R = 46

local function newStomp(world, st)
    local p = world.player
    st.x, st.y = Env.pointNear(world, p.x, p.y, 40)
    st.phase, st.pt = "follow", 0
end

return {
    name = "Boot Stomp",
    description = "Get out from under the shadow! Drag the ants in with you.",
    color = { 1, 0.5, 0.35 },
    kind = "hazard",
    weight = 8, minWave = 4,
    start = function(world, ev) ev.st.left = ev.opts.stomps or (world.spawner.wave >= 8 and 2 or 1) newStomp(world, ev.st) end,
    update = function(world, ev, dt)
        local st, p = ev.st, world.player
        st.pt = st.pt + dt
        if st.phase == "follow" then
            -- creeps after the player at 70 units/s
            local dx, dy = p.x - st.x, p.y - st.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            local s = math.min(d, 70 * dt)
            st.x, st.y = st.x + dx / d * s, st.y + dy / d * s
            if st.pt >= FOLLOW then st.phase, st.pt = "lock", 0 end
        elseif st.phase == "lock" and st.pt >= LOCK then
            st.phase, st.pt = "stomp", 0
            local kills = Env.strikeCircle(world, st.x, st.y, R, 999, { bossMul = 0.25 })
            if Env.playerIn(world, st.x, st.y, R - 4) then Env.hurtPlayer(world, 15, st.x, st.y, { force = 220 }) end
            world.camera:shake(0.7)
            world:hitStop(0.08)
            Audio.play("boom", { pitch = 0.45 })
            world.particles:burst(st.x, st.y, 30, { { 0.5, 0.42, 0.32 }, { 0.65, 0.56, 0.44 } }, 160, 60, { grav = 260 })
            world:addFx({ kind = "ring", x = st.x, y = st.y, r = R + 10, life = 0.35, color = { 0.8, 0.7, 0.55 } })
            if kills >= 5 then world:floatText(st.x, st.y, kills .. " STOMPED", { 1, 0.75, 0.5 }, true) end
            st.prints = st.prints or {}
            st.prints[#st.prints + 1] = { x = st.x, y = st.y, t = 0 }
        elseif st.phase == "stomp" and st.pt >= 1.0 then
            st.left = st.left - 1
            if st.left <= 0 then st.phase = "done" else newStomp(world, st) end
        end
        for _, pr in ipairs(st.prints or {}) do pr.t = pr.t + dt end
        if st.phase == "done" and st.pt > 4 then ev.done = true end
    end,
    drawGround = function(world, ev)
        local st, lg = ev.st, love.graphics
        for _, pr in ipairs(st.prints or {}) do
            -- a boot print pressed into the ground
            local a = math.max(0, 1 - pr.t / 6) * 0.4
            lg.setColor(0.15, 0.1, 0.07, a)
            Env.ellipse("fill", pr.x, pr.y, R * 0.9)
            lg.setColor(0.1, 0.07, 0.05, a)
            for i = -2, 2 do Env.ellipse("fill", pr.x + i * 12, pr.y - i * 12, 5) end
        end
        if st.phase == "follow" or st.phase == "lock" then
            local k = st.phase == "follow" and st.pt / FOLLOW * 0.7 or 0.7 + 0.3 * st.pt / LOCK
            Env.shadow(st.x, st.y, R * (0.5 + 0.5 * k), 0.4 + 0.6 * k)
            if st.phase == "lock" then Env.warnCircle(st.x, st.y, R, st.pt / LOCK, world.time) end
        end
    end,
    drawAir = function(world, ev)
        local st, lg = ev.st, love.graphics
        local Iso = require("src.core.iso")
        if st.phase == "lock" or (st.phase == "stomp" and st.pt < 0.5) then
            -- the sole coming down (then lifting away)
            local h = st.phase == "lock" and (1 - st.pt / LOCK) ^ 2 * 160 + 4 or st.pt / 0.5 * 160
            local sx, sy = Iso.toScreen(st.x, st.y, h)
            lg.setColor(0.25, 0.18, 0.12, 0.95)
            lg.ellipse("fill", sx, sy, R * 1.3, R * 0.6)
            lg.setColor(0.4, 0.3, 0.2, 1)
            lg.ellipse("fill", sx, sy - 6, R * 1.2, R * 0.5)
            lg.setColor(0.18, 0.12, 0.08, 1)
            lg.ellipse("line", sx, sy, R * 1.3, R * 0.6)
        end
    end,
}
