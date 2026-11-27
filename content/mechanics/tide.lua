-- The tide: the sea along the front edge of the beach (the arena's x = size side) comes in and
-- goes out on a slow cycle, with a wash of surf every few seconds. At low tide the sea is right
-- out (low < 0 puts it past the edge) and the rock pools inland drain to dry stone; at high tide
-- the sea floods in and the pools fill. Nothing stays wet for good, so the water is a moment to
-- use, not a place to camp.
-- In the water ants struggle (x0.55) and the small ones drown; the backwash drags them out to
-- sea. Most bugs wade (x0.75) and the salt water hurts them (sting / deep HP a second, sized for
-- a 100 HP bug), but water bugs are at home there (Shore.amphibious: crustaceans, the Water
-- Strider): full speed and a little faster, and they mend 1 HP a second while they're in it.
-- Flying or jumping over the water is safe.
-- params: low, high (how far the sea reaches in at low / high tide, share of the arena),
-- period (seconds per tide), surge (extra reach of each wash of surf, world units),
-- pools = { { x, y, r }, ... } (rock pools: centre as a share of the arena, full radius),
-- sting, deep (HP a second the water takes from other bugs in the shallows / out of their depth)
local Env = require("src.game.envfx")
local Shore = require("src.game.shore")
local Iso = require("src.core.iso")

local sin, cos, max, min, pi = math.sin, math.cos, math.max, math.min, math.pi

-- How far the water comes in (world units from the x = size edge) at height y.
local function reach(m, y)
    local st = m.st
    return st.depth + st.surge + sin(y * 0.031 + st.t * 0.6) * 7 + sin(y * 0.083 - st.t * 1.1) * 3
end

local function inSea(m, world, x, y) return x > world.size - reach(m, y) end

-- How full the rock pools are (0 dry .. 1 full): they drain soon after the tide turns.
local function poolFill(k) return max(0, min(1, (k - 0.2) / 0.55)) end

local function inPool(m, x, y)
    local f = m.st.fill or 1
    if f <= 0 then return false end
    for _, p in ipairs(m.st.pools) do
        local dx, dy, r = x - p.x, y - p.y, p.r * f
        if dx * dx + dy * dy < r * r then return true end
    end
    return false
end

local function wet(m, world, x, y) return inSea(m, world, x, y) or inPool(m, x, y) end

-- Out of its depth: far enough into the sea that small ants drown and other bugs hurt more.
local function deep(m, world, x, y) return x > world.size - reach(m, y) + 18 end

return {
    name = "Tide",
    description = "The sea comes in and goes out, and the rock pools fill and drain with it. Water slows ants and drowns small ones, and the salt stings most bugs; crustaceans and the Water Strider are at home in it.",
    start = function(world, m)
        local P, S, st = m.params, world.size, m.st
        st.t, st.tick, st.surge, st.surgeT, st.washV = 0, 0, 0, 2, 0
        st.depth = S * (P.low or -0.1)
        st.k, st.fill, st.hurtT, st.warnT, st.rising = 0, 0, 0, 0, false
        st.pools = {}
        for _, p in ipairs(P.pools or {}) do st.pools[#st.pools + 1] = { x = p[1] * S, y = p[2] * S, r = p[3] } end
    end,
    update = function(world, m, dt)
        local P, S, st, sp = m.params, world.size, m.st, world.spawner
        st.t = st.t + dt
        -- the tide itself: a slow swell between low and high water
        local k = 0.5 - 0.5 * cos(st.t / (P.period or 45) * 2 * pi)
        local lo = P.low or -0.1
        local want = S * (lo + ((P.high or 0.24) - lo) * k)
        local p = world.player
        -- call the turn of the tide over the player's head, so the flood is never a surprise
        local rising = k > st.k
        if p and rising ~= st.rising and st.t > 1 then
            if rising then world:floatText(p.x, p.y - 20, "HIGH TIDE COMING IN", { 0.6, 0.9, 1 }, true)
            else world:floatText(p.x, p.y - 20, "THE TIDE GOES OUT", { 0.85, 0.8, 0.6 }, true) end
        end
        st.k, st.rising = k, rising
        st.fill = poolFill(k)
        local old = st.depth
        st.depth = st.depth + (want - st.depth) * min(1, dt * 2)
        -- a wash of surf every few seconds: rushes in, then drains back out
        st.surgeT = st.surgeT - dt
        if st.surgeT <= 0 then st.surgeT = 3.5 + love.math.random() * 2.5; st.washV = P.surge or 22 end
        st.surge = st.surge + (st.washV - st.surge) * min(1, dt * 4)
        st.washV = max(0, st.washV - dt * 12)
        st.ebbing = st.surge > st.washV + 1 or st.depth < old
        -- water bugs mend in the water; the salt stings everyone else (more out of their depth)
        st.hurtT, st.warnT = st.hurtT - dt, st.warnT - dt
        if p and p.hp > 0 and not p.dead and (p.z or 0) < 4 and wet(m, world, p.x, p.y) then
            if Shore.amphibious(p) then
                p:heal(dt * (P.mend or 1))
            elseif st.hurtT <= 0 then
                st.hurtT = 0.5
                local dps = deep(m, world, p.x, p.y) and (P.deep or 6) or (P.sting or 2.5)
                -- the water isn't a blow you can block or parry; dashing and dodging still work
                local blocking = p.blocking
                p.blocking = nil
                Env.hurtPlayer(world, dps * 0.5, p.x, p.y, { name = "tide" })
                p.blocking = blocking
                if st.warnT <= 0 then
                    st.warnT = 5
                    world:floatText(p.x, p.y - 14, "the salt water stings!", { 0.7, 0.9, 1 })
                end
            end
        end
        -- the backwash drags ants in the sea out (not queens, bosses or hazards)
        if st.ebbing then
            local list, n = world:queryEnemies(S, S * 0.5, S * 0.75)
            for i = 1, n do
                local e = list[i]
                if not e.dead and (e.z or 0) < 4 and not e.def.boss and not e.def.encounter and not e.def.aquatic and inSea(m, world, e.x, e.y) then
                    e.x = min(S - 2, e.x + dt * 14)
                end
            end
        end
        -- small ants out of their depth drown (only during a wave, so the breaks stay calm)
        st.tick = st.tick + dt
        if st.tick >= 0.5 and sp and sp.phase == "wave" then
            st.tick = 0
            local wave = max(1, sp.wave)
            local list, n = world:queryEnemies(S, S * 0.5, S * 0.75)
            for i = 1, n do
                local e = list[i]
                if not e.dead and (e.z or 0) < 4 and e.radius <= 4.5 and not e.def.boss and not e.def.encounter and not e.def.aquatic
                    and deep(m, world, e.x, e.y) then
                    Env.hurtAnt(world, e, 2 + wave * 0.25)
                end
            end
        end
    end,
    field = function(world, m, x, y, who)
        if not wet(m, world, x, y) then return 1 end
        if who == "player" then
            local p = world.player
            if (p.z or 0) > 4 then return 1 end
            return Shore.amphibious(p) and (m.params.kinSpeed or 1.12) or 0.75
        end
        if (who.z or 0) > 4 or who.def.encounter then return 1 end
        if who.def.aquatic then return m.params.kinSpeed or 1.12 end   -- shrimp, krill, plankton
        return 0.55
    end,
    drawGround = function(world, m)
        local lg, S, st = love.graphics, world.size, m.st
        local step = 16
        local function band(off, r, g, b, a)
            lg.setColor(r, g, b, a)
            for y = 0, S - step, step do
                local y2 = y + step
                local x1, x2 = S - reach(m, y) + off, S - reach(m, y2) + off
                if x1 < S or x2 < S then
                    local ax, ay = Iso.toScreen(min(S, x1), y)
                    local bx, by = Iso.toScreen(min(S, x2), y2)
                    local cx, cy = Iso.toScreen(S, y2)
                    local dx, dy = Iso.toScreen(S, y)
                    lg.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
                end
            end
        end
        -- wet sand where the last wash reached, then shallows to deep water
        band(-14 - st.washV * 0.4, 0.32, 0.26, 0.18, 0.22)
        band(0, 0.3, 0.62, 0.66, 0.5)
        band(12, 0.18, 0.46, 0.58, 0.55)
        band(34, 0.12, 0.32, 0.5, 0.55)
        band(70, 0.08, 0.22, 0.42, 0.5)
        -- the foam line along the water's edge, and a few glints out to sea
        lg.setLineWidth(2)
        lg.setColor(0.94, 0.97, 1, 0.75)
        -- (at low tide the sea is out past the edge: the foam line hugs the edge where it's out)
        local pts = {}
        for y = 0, S, 8 do
            local sx, sy = Iso.toScreen(min(S, S - reach(m, y) + sin(y * 0.4 + st.t * 3) * 1.2), y)
            pts[#pts + 1], pts[#pts + 2] = sx, sy
        end
        if st.depth + st.surge > -12 then lg.line(pts) end
        lg.setLineWidth(1)
        lg.setColor(0.85, 0.95, 1, 0.35)
        for i = 1, 14 do
            local y = (i * 53 + st.t * 6) % S
            local r = reach(m, y)
            if r > 8 then
                local sx, sy = Iso.toScreen(S - r * (0.25 + (i % 4) * 0.15), y)
                local w = 3 + (st.t * 2 + i) % 5
                lg.line(sx - w, sy, sx + w, sy)
            end
        end
        -- rock pools: a basin of stone (dry and pale at low tide), clear water that fills and
        -- drains with the tide, a glint
        local f = st.fill or 1
        for _, p in ipairs(st.pools) do
            lg.setColor(0.36 + 0.2 * (1 - f), 0.33 + 0.18 * (1 - f), 0.3 + 0.14 * (1 - f), 0.9)
            Env.ellipse("fill", p.x, p.y, p.r + 4)
            if f > 0 then
                local r = p.r * f
                lg.setColor(0.16, 0.42, 0.5, 0.85)
                Env.ellipse("fill", p.x, p.y, r)
                lg.setColor(0.3, 0.6, 0.66, 0.6)
                Env.ellipse("fill", p.x - r * 0.2, p.y - r * 0.2, r * 0.55)
                lg.setColor(0.85, 0.95, 1, 0.45)
                Env.ellipse("line", p.x, p.y, r * (0.3 + 0.2 * ((st.t * 0.5) % 1)))
            end
        end
    end,
}
