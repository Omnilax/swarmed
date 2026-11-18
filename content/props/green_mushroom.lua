-- Green Mushroom: the only cure for parasites (src/game/parasites.lua). A rare sprout that
-- only shows up while you carry a parasite. Walk into it to eat it: every parasite is purged at
-- once and you heal a little. It wilts when the next wave starts if nobody ate it.
-- Spawned by Parasites.onWaveStart with { delay = seconds underground first }.
local Paint = require("src.gfx.paint")
local Audio = require("src.core.audio")
local Env = require("src.game.envfx")

local hex, ramp = Paint.hex, Paint.ramp
local floor, max, min, sin = math.floor, math.max, math.min, math.sin

local CAP = ramp("#0e3a12", "#1c5a1c", "#2e7e26", "#48a232", "#6cc446", "#a4e66c")
local STALK = ramp("#8a9a74", "#b0bc96", "#d2d8b8", "#eef0dc")
local GILL = hex("#5c7040")
local SPOT = ramp("#c8f0a0", "#e8ffd0")

-- painted once (origin: feet). A domed toadstool cap with pale spots on a short stalk.
local function art()
    return Paint.get("green_mushroom", function()
        local p = Paint.pic(22, 24, 11, 22)
        p:blob(0, -5, 3.2, 6, 0, STALK)
        p:blob(0, -11, 9.5, 2.2, 0, { GILL, GILL, GILL })
        p:blob(0, -14, 10, 7, 0, CAP, function(u, v, i, a, b)
            if v > -11 then return nil end
            local k = floor(i * 6) + 1
            -- pale spots on a staggered grid
            local gx, gy = (u + 12) % 6, (v + 20 + floor((u + 12) / 6) % 2 * 3) % 6
            if (gx - 3) ^ 2 + (gy - 3) ^ 2 < 2.4 then return SPOT[min(2, max(1, floor(i * 2) + 1))] end
            return CAP[min(6, k)]
        end)
        p:outline()
        return p
    end)
end

local COL = { 0.55, 1, 0.5 }

return {
    name = "Green Mushroom",
    description = "Walk into it to purge every parasite (and heal a little). Rare: only sprouts while you carry one.",
    radius = 9,
    labelZ = 30,
    mushroom = true,
    init = function(world, o)
        o.st.grow = 0
        o.st.fade = 1
    end,
    update = function(world, o, dt)
        local st = o.st
        if (o.delay or 0) > 0 then
            o.delay = o.delay - dt
            if o.delay <= 0 then require("src.game.parasites").popped(world, o) end
            return
        end
        st.grow = min(1, st.grow + dt * 2.5)
        if st.wilt then
            st.fade = st.fade - dt * 1.5
            if st.fade <= 0 then o.dead = true end
            return
        end
        if love.math.random() < dt * 4 then
            world.particles:spawn(o.x + (love.math.random() - 0.5) * 16, o.y + (love.math.random() - 0.5) * 16, 6, 0, -12, 10, 1.2, COL, 1, { glow = true, grav = -8 })
        end
        if st.grow >= 1 and Env.playerIn(world, o.x, o.y, o.r) then
            o.dead = true
            local Parasites = require("src.game.parasites")
            local n = Parasites.purge(world)
            local p = world.player
            p:heal(p.stats:get("maxHp") * Parasites.cfg(world).mushroom.heal)
            world:floatText(o.x, o.y - 20, n > 0 and ("PURGED " .. n .. " PARASITE" .. (n > 1 and "S" or "")) or "Tasty", COL, true)
            world.particles:burst(o.x, o.y - 6, 26, { COL, { 1, 1, 0.85 } }, 120, 90, { grav = 140 })
            Audio.play("pickup", { pitch = 0.8 })
            Audio.play("wave_clear", { pitch = 1.4, volume = 0.6 })
        end
    end,
    draw = function(world, o, sx, sy)
        if (o.delay or 0) > 0 then return end
        local lg = love.graphics
        local st = o.st
        local g = st.grow
        local pulse = 0.5 + 0.5 * sin(world.time * 3 + o.uid)
        -- a soft green glow on the ground so it reads from across the arena
        lg.setColor(0.4, 1, 0.35, (0.18 + 0.12 * pulse) * st.fade)
        lg.ellipse("fill", sx, sy, 18 * g, 8 * g)
        lg.setColor(0, 0, 0, 0.3 * st.fade)
        lg.ellipse("fill", sx + 1, sy + 1, 9 * g, 4 * g)
        local squash = 1 + (1 - g) * 0.3
        Paint.draw(art(), sx, sy, 0, g * (1 / squash) * (st.wilt and 1 or 1), g * squash * (st.wilt and st.fade or 1), st.fade)
    end,
    label = function(world, o)
        if (o.delay or 0) > 0 or o.st.wilt then return end
        local d = math.sqrt((world.player.x - o.x) ^ 2 + (world.player.y - o.y) ^ 2)
        if d < 160 then return "EAT TO PURGE PARASITES", COL end
    end,
}
