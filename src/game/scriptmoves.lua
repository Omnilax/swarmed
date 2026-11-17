-- Moves written in code by custom bug scripts (type = "scripted" in attack / secondary / dash,
-- see docs/CUSTOM_BUGS.md). The script's function gets `me`: a small toolkit that does things
-- to ants around the bug. It never sees the world, the player or the engine directly, every
-- number it passes is kept in range, and each call runs with an instruction budget
-- (CustomBugs.protect), so a broken move shows an error instead of freezing the game.
--
--   fire = function(me) ... end        attack / secondary: when the move is used
--   start = function(me) ... end       dash: when Shift is pressed
--   tick = function(me, dt) ... end    dash: every frame while the dash moves the bug
local Combat = require("src.game.combat")
local util = require("src.core.util")

local SM = {}
SM.errors = {}            -- custom bug id -> its last move error (shown in the Bug Creator)
SM.CALL_BUDGET = 200000   -- VM instructions per call

local function num(v, default, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then v = default end
    return math.max(lo, math.min(hi, v))
end

local function color(c, default)
    if type(c) ~= "table" then return default end
    return { num(c[1], 1, 0, 1), num(c[2], 1, 0, 1), num(c[3], 1, 0, 1) }
end

-- poison / slow / stun options shared by every hit
local function hitOpts(t, kbx, kby)
    local o = { knockback = num(t.knockback, 60, 0, 600), kbx = kbx, kby = kby }
    if type(t.poison) == "table" then o.poison = { num(t.poison[1], 4, 0, 60), num(t.poison[2], 3, 0, 10) } end
    if type(t.slow) == "table" then o.slow = { num(t.slow[1], 0.5, 0.1, 1), num(t.slow[2], 2, 0, 8) } end
    if t.stun then o.stun = num(t.stun, 0.5, 0, 3) end
    return o
end

-- The toolkit for one call. Everything engine-side runs unguarded (trusted, and fast).
function SM.api(player, world, params, ax, ay, dx, dy)
    local CB = require("src.game.custombugs")
    local U = CB.unguarded
    local area = 1 + player.stats:get("area") / 100
    local shots = 0
    player.scriptState = player.scriptState or {}
    local me = {
        x = player.x, y = player.y, aimX = ax, aimY = ay, angle = math.atan2(ay, ax),
        moveX = dx or ax, moveY = dy or ay,
        hp = player.hp, maxHp = player.stats:get("maxHp"), time = world.time or 0,
        params = params, state = player.scriptState,
    }
    local function dirOf(t)
        local a = math.atan2(ay, ax) + num(t.turn, 0, -math.pi * 2, math.pi * 2)
        return math.cos(a), math.sin(a), a
    end

    -- a cone in front: { radius, arc (radians), damage, knockback, poison = {dps, s}, slow = {mul, s}, stun, color, turn }
    function me.hitArc(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local cx, cy, ang = dirOf(t)
            local r = num(t.radius, 40, 4, 200) * area
            local half = num(t.arc, 2, 0.1, math.pi * 2) / 2
            local hits = Combat.collect(world, player.x, player.y, r, function(e, ex, ey)
                return math.abs(util.angleDiff(ang, math.atan2(ey, ex))) <= half
            end)
            local dmg = num(t.damage, 8, 0, 200)
            for _, e in ipairs(hits) do
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, dmg, hitOpts(t, nx, ny))
            end
            player.swingDir = -(player.swingDir or 1)
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = r, a = ang, arc = half * 2, dir = player.swingDir,
                life = 0.16, color = color(t.color) })
            return #hits
        end)
    end

    -- a circle: around the bug, `ahead` pixels along the aim, or at x, y. Knocks ants outwards.
    function me.hitCircle(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local cx, cy = dirOf(t)
            local ahead = num(t.ahead, 0, 0, 200)
            local x, y = num(t.x, player.x + cx * ahead, -1e5, 1e5), num(t.y, player.y + cy * ahead, -1e5, 1e5)
            local r = num(t.radius, 30, 4, 200) * area
            local dmg = num(t.damage, 8, 0, 200)
            local hits = Combat.collect(world, x, y, r)
            for _, e in ipairs(hits) do
                local nx, ny = util.normalize(e.x - x, e.y - y)
                Combat.damage(world, e, dmg, hitOpts(t, nx, ny))
            end
            world:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.2, color = color(t.color) })
            return #hits
        end)
    end

    -- a straight line along the aim: { length, width, damage, ... }
    function me.hitLine(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local cx, cy = dirOf(t)
            local len = num(t.length, 80, 4, 300) * area
            local x2, y2 = player.x + cx * len, player.y + cy * len
            local dmg = num(t.damage, 8, 0, 200)
            local hits = Combat.collectLine(world, player.x, player.y, x2, y2, num(t.width, 6, 1, 40))
            for _, e in ipairs(hits) do Combat.damage(world, e, dmg, hitOpts(t, cx, cy)) end
            world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = x2, y2 = y2, w = 3, life = 0.15, color = color(t.color) })
            return #hits
        end)
    end

    -- a projectile: { speed, range, damage, size, pierce, color, turn, poison, slow, stun,
    --   burst = { radius, damage } (explodes where it ends) }. 12 per call at most.
    function me.shoot(t)
        t = type(t) == "table" and t or {}
        shots = shots + 1
        if shots > 12 then return false end
        return U(function()
            local cx, cy = dirOf(t)
            local sp = num(t.speed, 260, 40, 700)
            local range = num(t.range, 140, 10, 400)
            local o = hitOpts(t, cx, cy)
            local burst = type(t.burst) == "table" and { r = num(t.burst.radius, 24, 4, 120) * area, d = num(t.burst.damage, 8, 0, 200) }
            local col = color(t.color, { 0.9, 1, 0.7 })
            world.hazards:friendlyShot({ x = player.x, y = player.y, z = 5, vx = cx * sp, vy = cy * sp,
                r = num(t.size, 3, 1, 10), damage = num(t.damage, 8, 0, 200), life = range / sp, color = col,
                pierce = math.floor(num(t.pierce, 0, 0, 10)), knockback = o.knockback, poison = o.poison, slow = o.slow, stun = o.stun,
                onEnd = burst and function(w, s)
                    Combat.area(w, s.x, s.y, burst.r, burst.d, { knockback = 60 })
                    w:addFx({ kind = "ring", x = s.x, y = s.y, r = burst.r, life = 0.2, color = col })
                end or nil })
            return true
        end)
    end

    -- move the bug: a quick dash along the aim (or turned by `turn`), distance in pixels
    function me.lunge(distance, turn)
        return U(function()
            local cx, cy = dirOf({ turn = turn })
            player:lunge(cx, cy, num(distance, 40, 0, 200))
        end)
    end

    function me.heal(n)
        return U(function()
            local max = player.stats:get("maxHp")
            player.hp = math.min(max, player.hp + num(n, 0, 0, 50))
        end)
    end

    -- run fn(me) again after `seconds` (combos, delayed blasts). 16 waiting at most.
    function me.after(seconds, fn)
        if type(fn) ~= "function" then return false end
        player.scriptPending = player.scriptPending or 0
        if player.scriptPending >= 16 then return false end
        player.scriptPending = player.scriptPending + 1
        player.delayed[#player.delayed + 1] = { t = num(seconds, 0.2, 0, 10), move = player.curMove, fn = function(p, w)
            p.scriptPending = math.max(0, (p.scriptPending or 1) - 1)
            SM.call(fn, p, w, params, p.aimX, p.aimY)
        end }
        return true
    end

    function me.ring(t)
        t = type(t) == "table" and t or {}
        return U(function()
            world:addFx({ kind = "ring", x = num(t.x, player.x, -1e5, 1e5), y = num(t.y, player.y, -1e5, 1e5),
                r = num(t.radius, 20, 2, 200), life = num(t.life, 0.25, 0.05, 2), color = color(t.color) })
        end)
    end

    function me.shake(a) return U(function() world.camera:shake(num(a, 0.1, 0, 0.5)) end) end

    local SOUNDS = { boom = true, zap = true, dash = true, hit = true, swing = true, special = true, chime = true, drop = true }
    function me.sound(name, pitch)
        if not SOUNDS[name] then return end
        return U(function() require("src.core.audio").play(name, { pitch = num(pitch, 1, 0.3, 3) }) end)
    end

    -- how many ants are within radius, and where the nearest one is
    function me.count(radius)
        return U(function() return #Combat.collect(world, player.x, player.y, num(radius, 40, 1, 400)) end)
    end
    function me.nearest(radius)
        return U(function()
            local e = world:nearestEnemy(player.x, player.y, num(radius, 100, 1, 400))
            if e then return e.x, e.y end
        end)
    end
    return me
end

-- Call a script function with the toolkit. Errors turn the move off for the rest of the run
-- and are kept for the Bug Creator to show.
SM.broken = setmetatable({}, { __mode = "k" })    -- functions that errored (params get copied)
function SM.call(fn, player, world, params, ax, ay, dx, dy, ...)
    if SM.broken[fn] then return end
    local CB = require("src.game.custombugs")
    local me = SM.api(player, world, params, ax, ay, dx, dy)
    local ok, err = CB.protect(fn, SM.CALL_BUDGET, 16, me, ...)
    if not ok then
        SM.broken[fn] = true
        local id = player.def and player.def.id or "?"
        local msg = tostring(err):gsub("^[^:]*:(%d+): ", "line %1: ")
        SM.errors[id] = (params.name or "move") .. ": " .. msg
        print("[scriptmoves] " .. id .. ": " .. SM.errors[id])
    end
end

return SM
