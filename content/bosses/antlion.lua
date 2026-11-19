-- The Antlion Pit: a stage hazard, not a fight (see src/game/director.lua, def.hazard). An
-- antlion digs a sand pit somewhere in the arena and waits at the bottom. The slope drags ants
-- and you down; whatever reaches its jaws gets eaten (you get bitten), and it flicks sand at
-- you. You can't hit it or grab it: it is buried in the sand. Lead the ants over the rim.
--
--   dig      a pit opens up (the rim marked while it grows)
--   wait     it sits in its pit, pulling things in and flicking sand
--   burrow   the pit caves in and it tunnels off to dig again somewhere near you
-- When the wave is cleared (or it has stayed its while) the pit fills in and it is gone.
local Env = require("src.game.envfx")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local Antlion = require("src.gfx.antlion")

local P = {
    pit = 95, pull = 34, antPull = 55, bite = 12, jaws = 11,
    flick = 3.2, shots = 3, shotDamage = 6,
    digTime = 1.5, wait = { 9, 12 }, burrowTime = 1.1,
}

local function setMode(h, mode, label, danger)
    h.st.mode, h.st.t = mode, 0
    h.label, h.danger = label, danger
end

local function dig(world, h, x, y)
    local st = h.st
    st.x, st.y = x, y
    st.body = { x = x, y = y, st = {} }
    st.waitFor = P.wait[1] + love.math.random() * (P.wait[2] - P.wait[1])
    st.flick = 2
    setMode(h, "dig", "DIGGING A PIT", false)
    Audio.play("rumble", { pitch = 1.1, volume = 0.7 })
end

-- The pit's live radius: grows while it digs, caves in while it burrows / leaves.
local function radius(st)
    if st.mode == "dig" then return P.pit * math.min(1, st.t / P.digTime) end
    if st.mode == "burrow" then return P.pit * math.max(0, 1 - st.t / P.burrowTime) end
    if st.mode == "leave" then return P.pit * math.max(0, 1 - st.t / 1.5) end
    return P.pit
end

-- The slope: the player and ants slide toward the jaws; ants that reach them are eaten.
local function pull(world, h, dt, R)
    local st, p = h.st, world.player
    local b = st.body
    if b.st.snap then b.st.snap = b.st.snap - dt if b.st.snap <= 0 then b.st.snap = nil end end
    if R < 4 then return end
    local dx, dy = st.x - p.x, st.y - p.y
    local d = math.sqrt(dx * dx + dy * dy) + 0.0001
    if not p.dead and d < R and p.dashT <= 0 and (p.z or 0) < 4 then
        local s = (P.pull * (1 - d / R) + 8) * dt
        p.x, p.y = p.x + dx / d * math.min(s, d), p.y + dy / d * math.min(s, d)
        if d < P.jaws + p.radius + 4 then
            st.biteCd = (st.biteCd or 0) - dt
            if st.biteCd <= 0 then
                st.biteCd, b.st.snap = 1.1, 0.25
                Env.hurtPlayer(world, P.bite, st.x, st.y, { force = 60, name = "antlion" })
                Audio.play("hit", { pitch = 0.5 })
            end
        end
    end
    local list, n = world:queryEnemies(st.x, st.y, R)
    for i = 1, n do
        local o = list[i]
        if not o.dead and not o.hidden and not o.held and (o.z or 0) < 4 and not o.def.encounter and not o.def.boss and not o.dropH then
            local ox, oy = st.x - o.x, st.y - o.y
            local od = math.sqrt(ox * ox + oy * oy) + 0.0001
            if od < R then
                local s = (P.antPull * (1 - od / R) + 10) * dt
                o.x, o.y = o.x + ox / od * math.min(s, od), o.y + oy / od * math.min(s, od)
                if od < P.jaws + 2 then
                    b.st.snap = 0.25
                    Env.hurtAnt(world, o, 999)
                end
            end
        end
    end
end

-- Lumps of sand lobbed at the player (they can be batted back like any shot).
local function flick(world, h, dt)
    local st, p = h.st, world.player
    st.flick = st.flick - dt
    if st.flick > 0 or p.dead then return end
    st.flick = P.flick
    local T = 0.9
    for _ = 1, P.shots do
        local tx = p.x + (p.vx or 0) * T * 0.6 + (love.math.random() - 0.5) * 50
        local ty = p.y + (p.vy or 0) * T * 0.6 + (love.math.random() - 0.5) * 50
        world.hazards:shoot({ x = st.x, y = st.y, z = 4, vx = (tx - st.x) / T, vy = (ty - st.y) / T,
            vz = (1 - 4 + 300 * T * T / 2) / T, grav = 300, r = 3, damage = P.shotDamage,
            life = T + 0.3, color = { 0.78, 0.66, 0.42 }, pebble = true,
            lob = { x = tx, y = ty, r = 12, slow = 0.6, slowTime = 0.8, flight = T } })
    end
    Audio.play("dash", { pitch = 1.4 })
end

return {
    name = "The Antlion Pit",
    title = "Antlion",
    description = "The sand slides toward its jaws. Ants that fall in are eaten; don't follow them.",
    hazard = true,
    weight = 10, minWave = 6,
    stay = 26,
    arrive = 6,
    xp = 25,
    survived = "THE ANTLION BURROWS AWAY",
    leaveTime = 1.6,

    start = function(world, h)
        -- in open ground, a fair way from the player and the walls
        dig(world, h, Env.pointAway(world, 160, 130))
    end,

    update = function(world, h, dt)
        local st, p = h.st, world.player
        st.t = st.t + dt
        local R = radius(st)
        st.R = R
        pull(world, h, dt, R)
        if st.mode == "dig" then
            if st.t >= P.digTime then setMode(h, "wait", "LURKING IN ITS PIT", false) end
        elseif st.mode == "wait" then
            flick(world, h, dt)
            if st.t >= st.waitFor then
                setMode(h, "burrow", "TUNNELLING!", true)
                Audio.play("rumble", { pitch = 0.9, volume = 0.6 })
            end
        elseif st.mode == "burrow" and st.t >= P.burrowTime then
            -- it comes up again near the player, though not right under them
            local x, y
            for _ = 1, 10 do
                x, y = Env.pointNear(world, p.x, p.y, 140, 110)
                if (x - p.x) ^ 2 + (y - p.y) ^ 2 > 70 * 70 then break end
            end
            dig(world, h, x, y)
        end
    end,

    leave = function(world, h, dt)
        local st = h.st
        if st.mode ~= "leave" then setMode(h, "leave", nil, false) end
        st.t = st.t + dt
        st.R = radius(st)
        if st.R <= 0 then h.gone = true end
    end,

    drawGround = function(world, h)
        local st = h.st
        local R = st.R or 0
        if st.mode == "dig" then Env.warnCircle(st.x, st.y, P.pit, st.t / P.digTime, world.time, { 0.95, 0.75, 0.35 }) end
        if R < 2 then return end
        Antlion.drawPit(st.x, st.y, R)
        -- sand trickling down in a slow swirl
        local lg = love.graphics
        lg.setColor(0.9, 0.82, 0.6, 0.6)
        for i = 1, 14 do
            local a = i / 14 * math.pi * 2 + world.time * 0.6
            local rr = R * (0.25 + ((i * 0.37 + world.time * 0.3) % 0.75))
            local sx, sy = Iso.toScreen(st.x + math.cos(a) * rr, st.y + math.sin(a) * rr)
            lg.rectangle("fill", math.floor(sx), math.floor(sy), 1, 1)
        end
        -- the larva at the bottom, sinking with the pit when it burrows
        local k = R / P.pit
        if k > 0.35 then
            local sx, sy = Iso.toScreen(st.x, st.y)
            Antlion.drawBody(st.body, world, sx, sy, k, k, false)
        end
        lg.setColor(1, 1, 1, 1)
    end,
}
