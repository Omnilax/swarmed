-- Code written in custom bug scripts (Bug Creator, docs/CUSTOM_BUGS.md) and the `me` toolkit it
-- gets. Script functions never see the world, the player or the engine directly: they act
-- through `me`, every number they pass is kept in range, and every call runs with an
-- instruction budget (CustomBugs.protect), so a broken function shows an error instead of
-- freezing the game. The engine work behind the toolkit runs unguarded (trusted, fast).
--
-- Where script code runs:
--   moves (attack / secondary / dash with type = "scripted", see CustomBugs.build):
--     fire(me)                      used (pressed, or on its cooldown)
--     hold(me, dt, charge) + release(me, charge)   hold-to-charge: every frame while held, then
--                                   on letting go (attack / secondary)
--     start(me), tick(me, dt)       pressed dash; tick every frame while the dash moves the bug
--     hold(me, dt, held)            hold dash: every frame (blocks, aim modes...)
--     enter(me), tick(me, dt), exit(me, dry), mode = true   a hold-Shift mode on the stamina bar
--   hooks = { onStart, onTick(me, dt), onHit(me, ev), onKill(me, ev), onHurt(me, ev),
--             onDodge, onBlock, onDash, onDashEnd, onWaveStart(me, ev), onEat }  on the bug
--   own skill tree procs: effect(me, ev, rank), condition(me, ev, rank)
local Combat = require("src.game.combat")
local util = require("src.core.util")

local SM = {}
SM.errors = {}            -- custom bug id -> its last script error (shown in the Bug Creator)
SM.CALL_BUDGET = 200000   -- VM instructions per call
SM.broken = setmetatable({}, { __mode = "k" })    -- functions that errored (switched off)

local function CB() return require("src.game.custombugs") end

local function num(v, default, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then v = default end
    return math.max(lo, math.min(hi, v))
end

local function color(c, default)
    if type(c) ~= "table" then return default end
    return { num(c[1], 1, 0, 1), num(c[2], 1, 0, 1), num(c[3], 1, 0, 1) }
end

----------------------------------------------------------------------------------------------
-- The toolkit. Built once per player; `cx` holds what the current call is about (its move
-- params, aim, proc depth) and is saved / restored around nested calls.

local function build(player)
    local cx = { params = {}, ax = 1, ay = 0, depth = 0, shots = 0 }
    local me = { state = {} }
    local function world() return player.world end
    local function U(fn) return CB().unguarded(fn) end
    local function area() return 1 + player.stats:get("area") / 100 end

    local function dirOf(t)
        local a = math.atan2(cx.ay, cx.ax) + num(t and t.turn, 0, -math.pi * 2, math.pi * 2)
        return math.cos(a), math.sin(a), a
    end
    -- extras every hit understands
    local function hitOpts(t, kbx, kby)
        local o = { knockback = num(t.knockback, 60, 0, 900), kbx = kbx, kby = kby, procDepth = cx.depth,
            noCrit = t.noCrit == true or nil, crit = t.crit == true or nil }
        if type(t.poison) == "table" then o.poison = { num(t.poison[1], 4, 0, 200), num(t.poison[2], 3, 0, 20) } end
        if type(t.slow) == "table" then o.slow = { num(t.slow[1], 0.5, 0.05, 1), num(t.slow[2], 2, 0, 15) } end
        if type(t.corrode) == "table" then o.corrode = { num(t.corrode[1], 1.3, 1, 3), num(t.corrode[2], 3, 0, 15) } end
        if t.stun then o.stun = num(t.stun, 0.5, 0, 5) end
        return o
    end
    local function point(t, defAhead)
        local cxv, cyv = dirOf(t)
        local ahead = num(t.ahead, defAhead or 0, -400, 400)
        return num(t.x, player.x + cxv * ahead, -1e5, 1e5), num(t.y, player.y + cyv * ahead, -1e5, 1e5)
    end
    local function liftable(e) return not (e.def.boss or e.def.queen or e.def.hazard) and not e.held end

    -- hits ------------------------------------------------------------------------------
    function me.hitArc(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local w = world()
            local _, _, ang = dirOf(t)
            local r = num(t.radius, 40, 4, 400) * area()
            local half = num(t.arc, 2, 0.1, math.pi * 2) / 2
            local hits = Combat.collect(w, player.x, player.y, r, function(e, ex, ey)
                return math.abs(util.angleDiff(ang, math.atan2(ey, ex))) <= half
            end)
            local dmg = num(t.damage, 8, 0, 1000)
            for _, e in ipairs(hits) do
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(w, e, dmg, hitOpts(t, nx, ny))
            end
            player.swingDir = -(player.swingDir or 1)
            if t.fx ~= false then
                w:addFx({ kind = "arc", x = player.x, y = player.y, r = r, a = ang, arc = half * 2, dir = player.swingDir,
                    life = 0.16, color = color(t.color) })
            end
            return #hits
        end)
    end

    function me.hitCircle(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local w = world()
            local x, y = point(t, 0)
            local r = num(t.radius, 30, 4, 400) * area()
            local dmg = num(t.damage, 8, 0, 1000)
            local hits = Combat.collect(w, x, y, r)
            for _, e in ipairs(hits) do
                local nx, ny = util.normalize(e.x - x, e.y - y)
                Combat.damage(w, e, dmg, hitOpts(t, nx, ny))
            end
            if t.fx ~= false then w:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.2, color = color(t.color) }) end
            return #hits
        end)
    end

    function me.hitLine(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local w = world()
            local dx, dy = dirOf(t)
            local len = num(t.length, 80, 4, 600) * area()
            local x2, y2 = player.x + dx * len, player.y + dy * len
            local dmg = num(t.damage, 8, 0, 1000)
            local hits = Combat.collectLine(w, player.x, player.y, x2, y2, num(t.width, 6, 1, 80))
            for _, e in ipairs(hits) do Combat.damage(w, e, dmg, hitOpts(t, dx, dy)) end
            if t.fx ~= false then
                w:addFx({ kind = "stab", x = player.x, y = player.y, x2 = x2, y2 = y2, w = 3, life = 0.15, color = color(t.color) })
            end
            return #hits
        end)
    end

    -- the nearest ant within radius (single target). Returns true if it hit one.
    function me.hitNearest(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local w = world()
            local e = w:nearestEnemy(player.x, player.y, num(t.radius, 60, 1, 600))
            if not e then return false end
            local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
            Combat.damage(w, e, num(t.damage, 8, 0, 1000), hitOpts(t, nx, ny))
            if t.fx ~= false then w:addFx({ kind = "stab", x = player.x, y = player.y, x2 = e.x, y2 = e.y, w = 2, life = 0.12, color = color(t.color) }) end
            return true
        end)
    end

    -- chain lightning style: hits an ant, then jumps to `jumps` more
    function me.chain(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local w = world()
            local e = w:nearestEnemy(player.x, player.y, num(t.radius, 80, 1, 600))
            if not e then return 0 end
            Combat.chain(w, e, math.floor(num(t.jumps, 3, 0, 20)), num(t.range, 60, 5, 300), num(t.damage, 8, 0, 1000),
                { procDepth = cx.depth, color = color(t.color) })
            return 1
        end)
    end

    -- shove ants in a circle away (strength > 0) or pull them in (strength < 0)
    function me.push(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local w = world()
            local x, y = point(t, 0)
            local s = num(t.strength, 200, -800, 800)
            local hits = Combat.collect(w, x, y, num(t.radius, 50, 4, 400) * area())
            for _, e in ipairs(hits) do
                if not e.def.boss then
                    local nx, ny = util.normalize(e.x - x, e.y - y)
                    e.kvx, e.kvy = e.kvx + nx * s / e.mass, e.kvy + ny * s / e.mass
                end
            end
            return #hits
        end)
    end
    function me.pull(t)
        t = type(t) == "table" and t or {}
        t.strength = -math.abs(num(t.strength, 200, 0, 800))
        return me.push(t)
    end

    -- projectiles ------------------------------------------------------------------------
    -- { speed, range, damage, size, pierce, color, turn, arc = true (lobbed), burst = { radius, damage },
    --   pool = { ... me.pool fields } (leaves a pool where it stops), poison, slow, stun }
    function me.shoot(t)
        t = type(t) == "table" and t or {}
        cx.shots = cx.shots + 1
        if cx.shots > 30 then return false end
        return U(function()
            local w = world()
            local dx, dy = dirOf(t)
            local sp = num(t.speed, 260, 30, 900)
            local range = num(t.range, 140, 10, 700)
            local life = range / sp
            local o = hitOpts(t, dx, dy)
            local burst = type(t.burst) == "table" and { r = num(t.burst.radius, 24, 4, 200) * area(), d = num(t.burst.damage, 8, 0, 1000) }
            local pool = type(t.pool) == "table" and t.pool
            local col = color(t.color, { 0.9, 1, 0.7 })
            local depth = cx.depth
            local s = { x = player.x, y = player.y, z = 5, vx = dx * sp, vy = dy * sp,
                r = num(t.size, 3, 1, 16), damage = num(t.damage, 8, 0, 1000), life = life, color = col,
                pierce = math.floor(num(t.pierce, 0, 0, 40)), knockback = o.knockback, poison = o.poison, slow = o.slow,
                stun = o.stun, corrode = o.corrode, procDepth = depth }
            if t.arc then s.vz, s.grav, s.pierce = 160 * life * 0.5 + 40, 320, 0 end
            if burst or pool then
                s.onEnd = function(w2, sh)
                    if burst then
                        Combat.area(w2, sh.x, sh.y, burst.r, burst.d, { knockback = 60, procDepth = depth })
                        w2:addFx({ kind = "ring", x = sh.x, y = sh.y, r = burst.r, life = 0.2, color = col })
                    end
                    if pool then SM.addPool(player, w2, pool, sh.x, sh.y, depth) end
                end
            end
            w.hazards:friendlyShot(s)
            return true
        end)
    end

    -- ground pools: { radius, life, dps (to ants inside), slow (speed x), pull, x, y, ahead, color }
    function me.pool(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local x, y = point(t, 0)
            SM.addPool(player, world(), t, x, y, cx.depth)
            return true
        end)
    end

    -- a sticky wall across the aim, `ahead` pixels out: { length, ahead, life, strength, hold, damage }
    function me.wall(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local dx, dy = dirOf(t)
            local x, y = point(t, 40)
            local half = num(t.length, 80, 10, 300) / 2
            world().hazards:addWall({ x1 = x - dy * half, y1 = y + dx * half, x2 = x + dy * half, y2 = y - dx * half,
                life = num(t.life, 6, 0.5, 30), strength = num(t.strength, 30, 1, 400), hold = num(t.hold, 2, 0, 10),
                damage = num(t.damage, 2, 0, 200), max = math.floor(num(t.max, 3, 1, 8)) })
            return true
        end)
    end

    -- helpers that run down ants: { count, life, damage, speed, bites, poison, color, size }
    function me.summon(t)
        t = type(t) == "table" and t or {}
        return U(function()
            return SM.addHelpers(player, { count = t.count, life = t.life, damage = t.damage, speed = t.speed, bites = t.bites,
                size = t.size, color = t.color, poison = type(t.poison) == "table" and hitOpts(t).poison or nil, depth = cx.depth })
        end)
    end

    -- grab and throw: grab(radius) lifts the nearest ant (true if it got one); throw{...} hurls it
    -- along the aim: { distance, damage (to ants on the way), landDamage, landRadius, height }
    function me.grab(radius)
        return U(function()
            local Grab = require("src.game.grab")
            if player.scriptHeld and Grab.valid(player.scriptHeld) then return true end
            local w = world()
            local best, bd
            for _, e in ipairs(Grab.collect(w, player.x, player.y, num(radius, 40, 4, 200))) do
                if liftable(e) then
                    local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
                    if not bd or d < bd then best, bd = e, d end
                end
            end
            if not best then return false end
            player.scriptHeld = Grab.hold(best)
            return true
        end)
    end
    function me.holding()
        local Grab = require("src.game.grab")
        return player.scriptHeld ~= nil and Grab.valid(player.scriptHeld)
    end
    function me.throw(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local Grab = require("src.game.grab")
            local h = player.scriptHeld
            player.scriptHeld = nil
            if not (h and Grab.valid(h)) then return false end
            local dx, dy = dirOf(t)
            local dist, time = num(t.distance, 120, 10, 400), 0.4
            Grab.fling(world(), h, dx * dist / time, dy * dist / time, time, { damage = num(t.damage, 8, 0, 1000),
                landDamage = num(t.landDamage, 12, 0, 1000), radius = num(t.landRadius, 30, 4, 200),
                knockback = 160, height = num(t.height, 24, 0, 120), color = color(t.color) })
            return true
        end)
    end

    -- the bug itself ----------------------------------------------------------------------
    function me.lunge(distance, turn)
        return U(function()
            local dx, dy = dirOf({ turn = turn })
            player:lunge(dx, dy, num(distance, 40, 0, 400))
        end)
    end
    -- a hop (only during a dash: the arc it flies over)
    function me.jump(height) player.dashHop = num(height, 8, 0, 40) end
    function me.heal(n)
        return U(function()
            player.hp = math.min(player.stats:get("maxHp"), player.hp + num(n, 0, 0, 500))
        end)
    end
    -- move speed x mul for some seconds
    function me.speed(mul, seconds)
        player.scriptSpeed, player.scriptSpeedT = num(mul, 1, 0.1, 4), num(seconds, 1, 0, 60)
    end
    -- nothing can hurt the bug for a moment
    function me.shield(seconds) player.iframes = math.max(player.iframes, num(seconds, 0.5, 0, 5)) end
    -- block every hit while on (me.block(true) ... me.block(false)); hits shove ants back
    function me.block(on, shove)
        player.scriptBlock = on and true or nil
        player.scriptBlockShove = num(shove, 90, 0, 600)
        SM.installWard(player)
    end
    -- camouflage: the ants lose track of the bug for some seconds (attacking does not end it)
    function me.cloak(seconds)
        return U(function()
            local id = {}
            player.cloakT, player.alpha = id, 0.3
            player:after(num(seconds, 2, 0, 20), function(p) if p.cloakT == id then p.cloakT, p.alpha = nil, nil end end)
        end)
    end
    -- fly over the ants: walking ants can't touch the bug up there (flyers and shots still can)
    function me.fly(on, height)
        player.liftZ = on and num(height, 10, 6, 40) or nil
    end
    function me.stamina()
        local Stamina = require("src.game.stamina")
        return Stamina.fraction(player)
    end
    -- spend stamina (1 = a full bar); false (and nothing spent) if there isn't enough
    function me.useStamina(amount)
        local Stamina = require("src.game.stamina")
        local s = Stamina.state(player)
        local a = num(amount, 0.1, 0, 10) * s.max
        if s.cur < a then s.flashT = 0.3 return false end
        Stamina.spend(player, a, 0.4)
        return true
    end

    -- timing, looks, sounds, senses -----------------------------------------------------------
    function me.after(seconds, fn)
        if type(fn) ~= "function" then return false end
        player.scriptPending = player.scriptPending or 0
        if player.scriptPending >= 32 then return false end
        player.scriptPending = player.scriptPending + 1
        local params, depth = cx.params, cx.depth
        player.delayed[#player.delayed + 1] = { t = num(seconds, 0.2, 0, 30), move = player.curMove, fn = function(p, w)
            p.scriptPending = math.max(0, (p.scriptPending or 1) - 1)
            SM.run(fn, p, params, p.aimX, p.aimY, { depth = depth })
        end }
        return true
    end
    function me.ring(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local x, y = point(t, 0)
            world():addFx({ kind = "ring", x = x, y = y, r = num(t.radius, 20, 2, 400), life = num(t.life, 0.25, 0.05, 3),
                color = color(t.color) })
        end)
    end
    function me.particles(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local x, y = point(t, 0)
            world().particles:burst(x, y, math.floor(num(t.count, 8, 1, 60)), { color(t.color, { 1, 1, 1 }) },
                num(t.speed, 80, 0, 600), 30, { glow = t.glow and true or nil })
        end)
    end
    function me.say(text, c)
        if type(text) ~= "string" then return end
        return U(function() world():floatText(player.x, player.y - 10, text:sub(1, 40), color(c, { 1, 0.95, 0.7 })) end)
    end
    function me.shake(a) return U(function() world().camera:shake(num(a, 0.1, 0, 0.8)) end) end
    function me.sound(name, pitch, volume)
        local Audio = require("src.core.audio")
        local id = type(name) == "string" and (Audio.sounds[player.def.id .. ":" .. name] and (player.def.id .. ":" .. name)
            or (SM.SOUNDS[name] and name))
        if not id then return end
        return U(function() Audio.play(id, { pitch = num(pitch, 1, 0.2, 4), volume = num(volume, 1, 0, 1) }) end)
    end
    -- rocks, sticks, leaves... near the bug: up to 20 { x, y, id, size }
    function me.props(radius)
        return U(function()
            local out, props = {}, world().props
            if not props then return out end
            local Props = require("src.game.props")
            for _, o in ipairs(props.list) do
                if #out >= 20 then break end
                if not o.dead and Props.distance(o, player.x, player.y) <= num(radius, 80, 1, 800) then
                    out[#out + 1] = { x = o.x, y = o.y, id = o.def.id, size = o.r }
                end
            end
            return out
        end)
    end
    -- knock the props around a point flying: { radius, strength, ahead, x, y }
    function me.kickProps(t)
        t = type(t) == "table" and t or {}
        return U(function()
            local props = world().props
            if not props then return end
            local x, y = point(t, 0)
            props:blast(x, y, num(t.radius, 40, 4, 300), num(t.strength, 260, 0, 900))
        end)
    end
    -- play one of the bug's own animations (anims = { spin = { ... } } in the script)
    function me.anim(name)
        local clip = type(name) == "string" and player.def.anims and player.def.anims[name]
        if not clip then return false end
        return U(function()
            require("src.gfx.anim").play(player, clip, "script_" .. name, { params = cx.params })
            return true
        end)
    end
    function me.count(radius)
        return U(function() return #Combat.collect(world(), player.x, player.y, num(radius, 40, 1, 800)) end)
    end
    function me.nearest(radius)
        return U(function()
            local e = world():nearestEnemy(player.x, player.y, num(radius, 100, 1, 800))
            if e then return e.x, e.y end
        end)
    end
    -- up to 40 ants near the bug: { x, y, hp, maxHp, boss } copies
    function me.enemies(radius)
        return U(function()
            local out = {}
            for _, e in ipairs(Combat.collect(world(), player.x, player.y, num(radius, 80, 1, 800))) do
                if #out >= 40 then break end
                out[#out + 1] = { x = e.x, y = e.y, hp = e.hp, maxHp = e.maxHp, boss = e.def.boss and true or false,
                    id = e.def.id, flying = (e.z or 0) > 4, elite = e.elite and true or false, queen = e.def.queen and true or false,
                    poisoned = (e.poisonT or 0) > 0, slowed = (e.slowT or 0) > 0 }
            end
            return out
        end)
    end
    return me, cx
end

SM.SOUNDS = { boom = true, zap = true, dash = true, hit = true, swing = true, special = true, chime = true, drop = true,
    kill = true, pickup = true, equip = true, bell = true, hurt = true }

-- Refresh what `me` shows for a call.
local function refresh(player, me, cx, params, ax, ay, dx, dy)
    local w = player.world
    cx.params, cx.ax, cx.ay, cx.shots = params or {}, ax or player.aimX, ay or player.aimY, 0
    me.x, me.y, me.aimX, me.aimY = player.x, player.y, cx.ax, cx.ay
    me.angle = math.atan2(cx.ay, cx.ax)
    me.moveX, me.moveY = dx or cx.ax, dy or cx.ay
    me.hp, me.maxHp, me.time = player.hp, player.stats:get("maxHp"), w and w.time or 0
    me.wave = w and w.spawner and w.spawner.wave or 0
    me.level = player.skills and player.skills.level or 0
    me.params = cx.params
    me.moving = player.moving and true or false
    me.flying = (player.liftZ or 0) > 0
    me.blocking = player.scriptBlock and true or false
end

-- Call a script function with the toolkit. opts: depth (proc depth of hits it makes), label.
-- Errors switch that function off for the rest of the session; the Creator shows them.
function SM.run(fn, player, params, ax, ay, opts, ...)
    if type(fn) ~= "function" or SM.broken[fn] or not player.world then return end
    if not player._me then player._me, player._cx = build(player) end
    local me, cx = player._me, player._cx
    -- a call inside a call (a hit setting off onHit): put the outer call's view back after
    local saved = { cx.params, cx.ax, cx.ay, cx.depth, cx.shots, me.x, me.y, me.aimX, me.aimY, me.moveX, me.moveY }
    refresh(player, me, cx, params, ax, ay, opts and opts.dx, opts and opts.dy)
    cx.depth = opts and opts.depth or 0
    local ok, res = CB().protect(fn, SM.CALL_BUDGET, 16, me, ...)
    cx.params, cx.ax, cx.ay, cx.depth, cx.shots = saved[1], saved[2], saved[3], saved[4], saved[5]
    me.x, me.y, me.aimX, me.aimY, me.moveX, me.moveY = saved[6], saved[7], saved[8], saved[9], saved[10], saved[11]
    me.params = cx.params
    if not ok then
        SM.broken[fn] = true
        local id = player.def and player.def.id or "?"
        local msg = tostring(res):gsub("^[^:]*:(%d+): ", "line %1: ")
        SM.errors[id] = ((params and params.name) or (opts and opts.label) or "script") .. ": " .. msg
        print("[scriptmoves] " .. id .. ": " .. SM.errors[id])
        return nil
    end
    return res
end

-- The moves' entry point (content/attacks/scripted.lua, content/dashes/scripted.lua).
function SM.call(fn, player, world, params, ax, ay, dx, dy, ...)
    return SM.run(fn, player, params, ax, ay, { dx = dx, dy = dy }, ...)
end

----------------------------------------------------------------------------------------------
-- Pools, helpers, the held ant, blocking, speed: things that last

-- little helpers that run down ants: { count, life, damage, speed, bites, size, color, poison, depth }
function SM.addHelpers(player, t)
    local list = player.scriptHelpers or {}
    player.scriptHelpers = list
    local n = math.floor(num(t.count, 3, 1, 20))
    for i = 1, n do
        if #list >= 60 then break end
        local a = i / n * math.pi * 2 + love.math.random() * 0.5
        list[#list + 1] = { x = player.x, y = player.y, vx = math.cos(a) * 90, vy = math.sin(a) * 90, t = 0,
            life = num(t.life, 5, 0.5, 30), damage = num(t.damage, 4, 0, 500), speed = num(t.speed, 160, 30, 500),
            bites = math.floor(num(t.bites, 3, 1, 50)), size = math.floor(num(t.size, 2, 1, 6)),
            color = color(t.color, { 0.45, 0.38, 0.3 }), poison = t.poison, depth = t.depth or 0, look = 0 }
    end
    return n
end

function SM.addPool(player, world, t, x, y, depth)
    local zones = world.hazards.zones
    local mine = 0
    for _, z in ipairs(zones) do if z.scriptPool then mine = mine + 1 end end
    if mine >= 12 then return end
    local col = color(t.color, { 0.5, 0.8, 0.3 })
    local dps, slow, pull = num(t.dps, 6, 0, 500), t.slow and num(t.slow, 0.5, 0.05, 1), num(t.pull, 0, 0, 400)
    world.hazards:addZone({ scriptPool = true, x = x, y = y, r = num(t.radius, 30, 4, 200), life = num(t.life, 4, 0.2, 30),
        color = col,
        update = function(w, z, dt)
            z.tick = (z.tick or 0) - dt
            local burn = z.tick <= 0
            if burn then z.tick = 0.25 end
            local list, n = w:queryEnemies(z.x, z.y, z.r + 10)
            for k = 1, n do
                local e = list[k]
                if not e.dead and e.z < 6 then
                    local dx, dy = e.x - z.x, e.y - z.y
                    local d = math.sqrt(dx * dx + dy * dy) + 0.001
                    if d < z.r + e.radius then
                        if slow then e.slowT, e.slowMul = math.max(e.slowT, 0.15), math.min(e.slowT > 0 and e.slowMul or 1, slow) end
                        if pull > 0 and not e.def.boss then e.x, e.y = e.x - dx / d * pull * dt * 0.3, e.y - dy / d * pull * dt * 0.3 end
                        if burn and dps > 0 then Combat.damage(w, e, dps * 0.25, { dot = true, noCrit = true, procDepth = (depth or 0) + 1 }) end
                    end
                end
            end
        end,
        draw = function(z, sx, sy, fade)
            local lg = love.graphics
            local grow = math.min(1, z.t / 0.3)
            lg.setColor(col[1], col[2], col[3], 0.35 * fade)
            lg.ellipse("fill", sx, sy, z.r * grow * 0.9, z.r * grow * 0.45)
            lg.setColor(col[1], col[2], col[3], 0.7 * fade)
            lg.ellipse("line", sx, sy, z.r * grow * 0.9, z.r * grow * 0.45)
        end })
end

-- Blocking for script code: a ward (Player:hurt asks it first) that soaks hits while on.
function SM.installWard(player)
    if player.scriptWardOn then return end
    player.scriptWardOn = true
    local prev = player.ward
    player.ward = function(p, amount, source)
        if p.scriptBlock then
            if type(source) == "table" and source.x and source.kvx then
                local dx, dy = source.x - p.x, source.y - p.y
                local l = math.sqrt(dx * dx + dy * dy) + 0.001
                local s = p.scriptBlockShove or 90
                source.kvx, source.kvy = source.kvx + dx / l * s, source.kvy + dy / l * s
            end
            if (p.blockFxT or 0) <= 0 then
                p.blockFxT = 0.15
                p.world.particles:sparks(p.x, p.y, 4, { 0.8, 0.9, 1 }, p.aimX, p.aimY, 2.5, 90)
                require("src.core.audio").play("hit", { pitch = 1.8 })
            end
            p.inventory:trigger("onBlock", { world = p.world, player = p, damage = amount, source = source, procDepth = 0 })
            return true
        end
        if prev then return prev(p, amount, source) end
    end
end

-- Every frame for a custom bug (Player:update): hooks.onTick / onStart, helpers, timers.
function SM.tick(player, world, dt)
    local def = player.def
    require("src.game.bugtraits").tick(player, world, dt)
    local hooks = def.hooks
    if player.scriptSpeedT then
        player.scriptSpeedT = player.scriptSpeedT - dt
        if player.scriptSpeedT <= 0 then player.scriptSpeed, player.scriptSpeedT = nil, nil end
    end
    if hooks then
        if hooks.onStart and not player.scriptStarted and world.mode ~= "menu" then
            player.scriptStarted = true
            SM.run(hooks.onStart, player, nil, nil, nil, { label = "onStart" })
        end
        if hooks.onTick then SM.run(hooks.onTick, player, nil, nil, nil, { label = "onTick" }, dt) end
    end
    -- a held ant rides over the bug's head
    local h = player.scriptHeld
    if h then
        local Grab = require("src.game.grab")
        if Grab.valid(h) then Grab.place(h, player.x + player.aimX * 4, player.y + player.aimY * 4, 14, player.wangle or 0)
        else player.scriptHeld = nil end
    end
    -- helpers hunt
    local list = player.scriptHelpers
    if list then
        for i = #list, 1, -1 do
            local s = list[i]
            s.t = s.t + dt
            s.look = s.look - dt
            if s.look <= 0 or (s.target and (s.target.dead or s.target.uid ~= s.uid)) then
                s.look = 0.3
                s.target = world:nearestEnemy(s.x, s.y, 140)
                s.uid = s.target and s.target.uid
            end
            local e = s.target
            if e and not e.dead and e.uid == s.uid then
                local dx, dy, d = util.normalize(e.x - s.x, e.y - s.y)
                local k = math.min(1, dt * 8)
                s.vx, s.vy = s.vx + (dx * s.speed - s.vx) * k, s.vy + (dy * s.speed - s.vy) * k
                if d < e.radius + 2 then
                    Combat.damage(world, e, s.damage, { knockback = 20, kbx = dx, kby = dy, poison = s.poison, noCrit = true,
                        procDepth = s.depth + 1 })
                    s.bites = s.bites - 1
                    s.target, s.look = nil, 0.15
                    s.vx, s.vy = -dx * 80, -dy * 80
                end
            else
                local dx, dy = util.normalize(player.x - s.x, player.y - s.y)
                s.vx, s.vy = s.vx + (dx * s.speed * 0.6 - s.vx) * dt * 3, s.vy + (dy * s.speed * 0.6 - s.vy) * dt * 3
            end
            s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
            if s.bites <= 0 or s.t > s.life then table.remove(list, i) end
        end
        if #list == 0 then player.scriptHelpers = nil end
    end
end

-- Drawn in the world (World:draw): helpers.
function SM.draw(player, world)
    local list = player.scriptHelpers
    if not list then return end
    local Iso = require("src.core.iso")
    local lg = love.graphics
    for _, s in ipairs(list) do
        local x, y = Iso.toScreen(s.x, s.y, 0)
        x, y = math.floor(x), math.floor(y)
        local leg = math.floor(s.t * 20) % 2
        local c = s.color
        lg.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1)
        lg.rectangle("fill", x - s.size - 1, y - leg, 1, 1)
        lg.rectangle("fill", x + s.size, y - 1 + leg, 1, 1)
        lg.setColor(c[1], c[2], c[3], 1)
        lg.rectangle("fill", x - math.floor(s.size / 2), y - math.floor(s.size / 2), s.size, s.size)
    end
    lg.setColor(1, 1, 1, 1)
end

-- Game events (Inventory:trigger) -> the bug's hooks. ev is a copy: never engine tables.
local EVENTS = { onHit = true, onKill = true, onHurt = true, onDodge = true, onBlock = true, onDash = true,
    onDashEnd = true, onWaveStart = true, onEat = true, onAttack = true, onSpecial = true }
function SM.evOf(ctx)
    local t = ctx.target
    return { x = ctx.x or (t and t.x), y = ctx.y or (t and t.y), damage = ctx.damage, crit = ctx.crit and true or false,
        wave = ctx.wave, dt = ctx.dt, boss = t and t.def and t.def.boss and true or false,
        hp = t and t.hp, maxHp = t and t.maxHp, move = type(ctx.move) == "string" and ctx.move or nil }
end
function SM.event(player, name, ctx)
    if player.def.passives then require("src.game.bugtraits").event(player, name, ctx) end
    local hooks = player.def.hooks
    local fn = hooks and EVENTS[name] and hooks[name]
    if not fn then return end
    if (ctx.procDepth or 0) >= 3 then return end      -- hits made by hooks can set off hooks, a few deep
    SM.run(fn, player, nil, nil, nil, { depth = (ctx.procDepth or 0) + 1, label = name }, SM.evOf(ctx))
end

return SM
