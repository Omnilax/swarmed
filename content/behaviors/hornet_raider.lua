-- Asian giant hornet: the biggest hornet there is. A scout finds a bee hive, rubs its scent
-- on it, and the nestmates arrive for the slaughter. This one closes in and circles you while
-- it marks you (golden scent, a second or so); hit it hard enough to interrupt. If it finishes,
-- more giant hornets fly in for the raid. Its bite is brutal.
-- params: mark (seconds, 1.3), raid (hornets called, 2), delay (seconds before they come, 2.5),
--         max (giant hornets alive at most, 4), stagger (0.9)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local SCENT = { 1, 0.85, 0.35 }

local function raidUpdate(world, z)
    if z.t < z.delay or z.done then return end
    z.done, z.t = true, z.maxLife
    local list = AI.group(world, z.id)
    local n = math.min(z.raid, z.max - #list)
    for _ = 1, n do
        local pt = world.spawner:edgePoint()
        local h = world:spawnEnemy(z.id, pt[1], pt[2])
        if h then h.st.raider = true end
    end
    if n > 0 then world:floatText(world.player.x, world.player.y, "THE RAID ARRIVES", { 1, 0.5, 0.3 }, true) end
end

return {
    name = "Mark and raid",
    init = function(e) e.st.mode, e.st.ang = "hunt", love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "hunt" then
            AI.hover(e, world, dt, d < 26 and 1 or 7)
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            if not st.raider and not st.marked and d < 60 and not p.dead then
                st.mode, st.t, st.ang = "mark", params.mark or 1.3, math.atan2(e.y - p.y, e.x - p.x)
            end
        elseif st.mode == "mark" then
            -- circle close round you, dabbing scent
            e.biteCd = math.max(e.biteCd, 0.3)
            AI.hover(e, world, dt, 4)
            st.ang = st.ang + dt * 2.5
            AI.goTo(e, p.x + math.cos(st.ang) * 22, p.y + math.sin(st.ang) * 22, e.speed * 2)
            if love.math.random() < dt * 12 then
                world.particles:spawn(e.x, e.y, 4, 0, 0, 15, 0.6, SCENT, 1, { glow = true, grav = -10 })
            end
            st.t = st.t - dt
            if st.t <= 0 then
                st.marked, st.mode = true, "hunt"
                world:floatText(p.x, p.y, "MARKED FOR A RAID", { 1, 0.75, 0.3 }, true)
                Audio.play("zap", { pitch = 0.5 })
                world.hazards:addZone({ kind = "raid", x = p.x, y = p.y, r = 1, life = 99, delay = params.delay or 2.5,
                    raid = params.raid or 2, max = params.max or 4, id = e.def.id, color = SCENT, update = raidUpdate,
                    draw = function() end })
            end
        else -- staggered
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "hunt" end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode == "mark" then
            Combat.stagger(world, e, e.params.stagger or 0.9, opts)
            e.st.mode = "stagger"
            world:floatText(e.x, e.y, "MARK INTERRUPTED", { 1, 0.85, 0.5 }, false)
        end
        return 1
    end,
    draw = function(e)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        if st.mode ~= "mark" then return end
        local p = e.params
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(SCENT[1], SCENT[2], SCENT[3], 0.6)
        love.graphics.arc("line", "open", x, y, 7, -math.pi / 2, -math.pi / 2 + math.pi * 2 * (1 - st.t / (p.mark or 1.3)))
    end,
}
