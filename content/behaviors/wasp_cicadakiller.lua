-- Cicada killer: hunts prey bigger than itself and flies off carrying it. This one grabs an ant
-- from the swarm, carries it up high, flies over you and drops it on your head. The falling
-- ant's shadow on the ground shows where it will land. Hit the wasp and it lets go early.
-- params: search (radius it looks for prey in, 160), maxRadius (biggest ant it can lift, 7),
--         height (carry height, 26), carry (max seconds, 3.5), blast (landing radius, 16),
--         mult (landing damage x, 1.5), cooldown (2.5)
local AI = require("src.game.ai")
local Grab = require("src.game.grab")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local function drop(e, world)
    local st = e.st
    if Grab.valid(st.h) then
        st.mode, st.t = "drop", 0.3
        st.fx, st.fy, st.fz = st.h.e.x, st.h.e.y, st.h.e.z
    else
        st.mode, st.h, st.cd = "hunt", nil, 1
    end
end

return {
    name = "Prey bomber",
    init = function(e) e.st.mode, e.st.cd = "hunt", 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        if st.mode == "hunt" then
            AI.hover(e, world, dt, 10)
            st.cd = st.cd - dt
            local prey = st.cd <= 0 and AI.nearestOther(world, e, e.x, e.y, params.search or 160, function(o)
                return o.def.family == "ant" and o.radius <= (params.maxRadius or 7) and o.z < 2
            end)
            if prey then
                st.prey, st.preyUid, st.mode, st.t = prey, prey.uid, "grab", 2.5
            else
                -- nothing to carry: hang about out of reach
                AI.goTo(e, p.x + math.cos(world.time * 0.6 + e.uid) * 90, p.y + math.sin(world.time * 0.6 + e.uid) * 90, e.speed)
            end
        elseif st.mode == "grab" then
            local o = st.prey
            st.t = st.t - dt
            if o.dead or o.uid ~= st.preyUid or o.held or st.t <= 0 then
                st.mode, st.cd = "hunt", 0.5
            else
                AI.hover(e, world, dt, 2)
                if AI.goTo(e, o.x, o.y, e.speed * 1.6) < e.radius + o.radius + 1 then
                    st.h = Grab.hold(o)
                    o.heldBy, o.heldByUid = e, e.uid
                    st.mode, st.t = "carry", params.carry or 3.5
                    Audio.play("dash", { pitch = 0.7 })
                end
            end
        elseif st.mode == "carry" then
            if not Grab.valid(st.h) then st.mode, st.h = "hunt", nil return end
            AI.hover(e, world, dt, params.height or 26)
            -- aim to be over where you'll be
            local tx, ty = p.x + (p.vx or 0) * 0.3, p.y + (p.vy or 0) * 0.3
            local dd = AI.goTo(e, tx, ty, e.speed * 1.1)
            Grab.place(st.h, e.x, e.y, e.z - 4, e.angle)
            st.t = st.t - dt
            if (dd < 6 and e.z > (params.height or 26) * 0.7) or st.t <= 0 then drop(e, world) end
        elseif st.mode == "drop" then
            -- the ant falls; the wasp climbs away
            e.mx, e.my = -dx / d * e.speed, -dy / d * e.speed
            st.t = st.t - dt
            local k = math.max(0, st.t / 0.3)
            if Grab.valid(st.h) then Grab.place(st.h, st.fx, st.fy, st.fz * k * k) end
            if st.t <= 0 then
                local r = params.blast or 16
                if Grab.valid(st.h) then
                    local o = st.h.e
                    Grab.release(st.h)
                    o.heldBy = nil
                    o.slowT, o.slowMul = 0.8, 0     -- dazed by the fall
                end
                if (p.x - st.fx) ^ 2 + (p.y - st.fy) ^ 2 < (r + p.radius) ^ 2 and not p.dead then
                    AI.sting(e, world, params.mult or 1.5)
                    p:knock(p.x - st.fx + 0.01, p.y - st.fy, 160)
                end
                world:addFx({ kind = "ring", x = st.fx, y = st.fy, r = r, life = 0.2, color = { 0.9, 0.75, 0.5 } })
                world.particles:burst(st.fx, st.fy, 8, { { 0.5, 0.42, 0.32 } }, 70, 50, { grav = 300 })
                world.camera:shake(0.15)
                Audio.play("boom", { pitch = 1.8 })
                st.mode, st.h, st.cd = "hunt", nil, params.cooldown or 2.5
            end
        end
    end,
    -- carrying makes it slow to dodge: a hit makes it drop the ant where it is
    onHit = function(e, world)
        if e.st.mode == "carry" then drop(e, world) end
        return 1
    end,
    -- the carried ant's shadow on the ground (where it will fall)
    drawUnder = function(e)
        local st = e.st
        if (st.mode ~= "carry" and st.mode ~= "drop") or not Grab.valid(st.h) then return end
        local o = st.h.e
        local x, y = Iso.toScreen(o.x, o.y)
        local r = e.params.blast or 16
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.ellipse("fill", x, y, 4, 2)
        love.graphics.setColor(1, 0.7, 0.4, st.mode == "drop" and 0.8 or 0.3)
        love.graphics.ellipse("line", x, y, r * 1.4, r * 0.7)
    end,
}
