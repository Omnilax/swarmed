-- Dewdrop shrine (a map gamble, src/game/gambles.lua): a big bead of dew on a leaf, ringed by
-- pebbles. Stand in the ring while the wave is on to gather the dew; it draws ants in while it
-- fills, and it slowly dries if you step out. When it is full three blessings float up around
-- it: walk into the one you want (a permanent stat boost for the run).
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
local Audio = require("src.core.audio")
local Env = require("src.game.envfx")
local Gambles = require("src.game.gambles")

local COLOR = { 0.62, 0.92, 1 }

local function cfg(world) return world.gambles.cfg.shrine end

local function leave(world, o)
    if o.leaving then return end
    o.leaving, o.busy, o.st.fade = true, false, 0.7
end

-- where offer i of n floats (world coords): fanned out over the top of the ring, from the
-- screen's left round to its right (in the isometric view up the screen is -x, -y)
local function offerPos(o, i, n)
    local a = -math.pi * 0.75 + (i - (n + 1) / 2) * (math.pi / 2)
    local r = o.st.ring * 1.15
    return o.x + math.cos(a) * r, o.y + math.sin(a) * r
end

-- which way an offer's text runs: away from the shrine
local function offerAlign(i, n)
    local k = i - (n + 1) / 2
    if k < 0 then return "right" elseif k > 0 then return "left" end
    return "center"
end

local function callAnts(world, o)
    local c = cfg(world)
    local sp = world.spawner
    local def = sp:pickEnemy()
    if not def then return end
    local n = math.max(1, math.floor(c.callBase + (sp.wave or 1) * c.callPerWave))
    world:spawnRing(def, n, o.x, o.y, c.callRadius)
end

return {
    name = "Dewdrop Shrine",
    description = "Stand in the ring to gather the dew, then pick a blessing. It calls ants in.",
    radius = 10,
    labelZ = 34,
    gamble = { weight = 12, minWave = 2, text = "Stand in its ring to gather a blessing. The dew draws ants in.", color = COLOR },
    leave = leave,
    init = function(world, o)
        local st = o.st
        st.ring, st.charge, st.callT, st.state, st.fade, st.pop = cfg(world).ring, 0, 0.6, "fill", 1, 0
    end,
    update = function(world, o, dt)
        local st, p, c = o.st, world.player, cfg(world)
        st.pop = math.min(1, st.pop + dt * 3)
        if o.leaving then
            st.fade = st.fade - dt
            if st.fade <= 0 then o.dead = true end
            return
        end
        local inside = not p.dead and Env.playerIn(world, o.x, o.y, st.ring)
        if st.state == "fill" then
            if inside and Gambles.live(world) then
                st.charge = math.min(1, st.charge + dt / c.fill)
                st.callT = st.callT - dt
                if st.callT <= 0 then
                    st.callT = c.callEvery
                    callAnts(world, o)
                end
                if love.math.random() < dt * 10 then
                    local a = love.math.random() * math.pi * 2
                    world.particles:burst(o.x + math.cos(a) * st.ring, o.y + math.sin(a) * st.ring, 1, { COLOR }, 30, 50)
                end
            else
                st.charge = math.max(0, st.charge - c.drain * dt)
            end
            o.busy = st.charge > 0.05
            if st.charge >= 1 then
                st.state, st.armT = "offer", 0.7
                st.offers = world.gambles:rollBlessings(c.offers)
                o.busy = true
                Audio.play("chime", { pitch = 1.5 })
                world:floatText(o.x + 20, o.y + 20, "CHOOSE A BLESSING", COLOR, true)
                world.particles:burst(o.x, o.y, 24, { COLOR, { 1, 1, 1 } }, 120, 90, { grav = 160 })
                world.events:emit("shrine_full", o)
            end
        elseif st.state == "offer" then
            st.armT = math.max(0, st.armT - dt)
            if st.armT > 0 or p.dead then return end
            for i, b in ipairs(st.offers) do
                local ox, oy = offerPos(o, i, #st.offers)
                if (p.x - ox) ^ 2 + (p.y - oy) ^ 2 < (p.radius + 7) ^ 2 then
                    world.gambles:bless(b.stat, b.add, "shrine")
                    Audio.play("chime", { pitch = 1.9 })
                    world.particles:burst(ox, oy, 18, { COLOR, { 1, 1, 1 } }, 110, 80)
                    st.state, st.taken = "done", i
                    leave(world, o)
                    break
                end
            end
        end
    end,
    draw = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local a = st.fade * st.pop
        -- the ring: pebbles round a damp patch that fills in as the dew gathers
        if st.state == "fill" then
            local c = COLOR
            lg.setColor(c[1], c[2], c[3], (0.08 + 0.15 * st.charge) * a)
            Env.ellipse("fill", o.x, o.y, st.ring)
            lg.setColor(c[1], c[2], c[3], (0.4 + 0.2 * math.sin(o.t * 3)) * a)
            Env.ellipse("line", o.x, o.y, st.ring)
            if st.charge > 0 then
                lg.setColor(c[1], c[2], c[3], (0.25 + 0.3 * st.charge) * a)
                Env.ellipse("fill", o.x, o.y, st.ring * st.charge)
            end
        end
        -- the ring of pebbles and the leaf, painted (src/gfx/propart.lua)
        local Iso = require("src.core.iso")
        for i = 0, 9 do
            local ang = i / 10 * math.pi * 2
            local px, py = Iso.toScreen(o.x + math.cos(ang) * st.ring, o.y + math.sin(ang) * st.ring)
            Paint.draw(PA.pebble(2, i), math.floor(px + 0.5), math.floor(py + 0.5), 0, 1, 1, a)
        end
        lg.setColor(0, 0, 0, 0.3 * a)
        lg.ellipse("fill", sx, sy + 2, 15, 6)
        Paint.draw(PA.shrineLeaf(), sx, sy, 0, 1, 1, a)
    end,
    drawAir = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local a = st.fade * st.pop
        -- the drop: grows as it fills, bobs a little
        local k = st.state == "fill" and st.charge or (st.state == "offer" and 1 or 0.4)
        local r = (4 + 5 * k) * st.pop
        local y = sy - 6 - r + math.sin(o.t * 2) * 1
        if st.state ~= "done" then
            Paint.draw(PA.drop(r), sx, math.floor(y + r + 0.5), 0, 1, 1, a)
        end
        if st.state == "offer" then
            -- three bubbles, each with a blessing in it
            for i, b in ipairs(st.offers) do
                local ox, oy = offerPos(o, i, #st.offers)
                local px, py = require("src.core.iso").toScreen(ox, oy, 10 + math.sin(o.t * 3 + i) * 2)
                lg.setColor(0.6, 0.9, 1, 0.3 + 0.2 * math.sin(o.t * 4 + i))
                lg.circle("fill", px, py, 7)
                lg.setColor(1, 1, 1, st.armT > 0 and 0.4 or 0.95)
                lg.circle("line", px, py, 7)
                lg.setColor(1, 1, 1, 0.9)
                lg.circle("fill", px - 2, py - 2, 1.5)
            end
        end
    end,
    labels = function(world, o)
        local st = o.st
        if o.leaving then return nil end
        if st.state == "offer" then
            local out = {}
            for i, b in ipairs(st.offers) do
                local ox, oy = offerPos(o, i, #st.offers)
                local al = offerAlign(i, #st.offers)
                out[#out + 1] = { text = Gambles.describe(b.stat, b.add), x = ox, y = oy, z = al == "center" and 26 or 10,
                    align = al, color = { 0.75, 0.95, 1 } }
            end
            return out
        end
        if st.state == "fill" then
            if st.charge > 0 then
                return { { text = ("Dew %d%%"):format(math.floor(st.charge * 100)), color = COLOR } }
            end
            if not Gambles.live(world) then return { { text = "Dewdrop Shrine (fills during a wave)", color = { 0.7, 0.8, 0.85 } } } end
            return { { text = "Dewdrop Shrine: stand in the ring", color = COLOR } }
        end
    end,
}
