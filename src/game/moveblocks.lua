-- No-code moves for custom bugs (Bug Creator > Mix Parts > Build a move, or in a script):
--   attack = { name = "Leap Slash", cooldown = 0.8, blocks = {
--       { "lunge", distance = 50 },
--       { "wait", time = 0.1 },
--       { "arc", radius = 50, degrees = 140, damage = 12 },
--       { "pool", radius = 20, life = 3, dps = 4 },
--   } }
-- Blocks run top to bottom; a "wait" block holds the ones after it back. The list is plain
-- data, so the mixer can edit it and it is saved as written. MoveBlocks.compile turns it into
-- the move's fire / start function (it only calls the `me` toolkit).
--
-- Combos: combo = { <step>, <step>, ..., window = 0.7 } where each step is a function(me) or a
-- list of blocks: pressing again within `window` seconds plays the next step, else back to 1.
local MB = {}

-- kind -> { label, params = { { key, label, min, max, step, default } }, run(me, b) }
local function P(key, label, min, max, step, default) return { key = key, label = label, min = min, max = max, step = step, default = default } end
local DMG = P("damage", "Damage", 0, 200, 1, 10)

MB.KINDS = {
    lunge = { label = "Lunge", desc = "Throw the bug forward.", params = { P("distance", "Distance", 0, 200, 5, 40) },
        run = function(me, b) me.lunge(b.distance) end },
    wait = { label = "Wait", desc = "Pause before the next blocks.", params = { P("time", "Seconds", 0.05, 2, 0.05, 0.15) } },
    arc = { label = "Swing (arc)", desc = "A wedge in front of the bug.",
        params = { P("radius", "Reach", 10, 200, 5, 50), P("degrees", "Width (degrees)", 10, 360, 10, 120), DMG,
            P("knockback", "Knockback", 0, 600, 20, 80), P("windup", "Wind-up (s)", 0, 1.5, 0.05, 0) },
        run = function(me, b) me.hit({ shape = "arc", radius = b.radius, degrees = b.degrees, damage = b.damage, knockback = b.knockback,
            windup = b.windup, status = b.status, hitstop = b.hitstop, shake = b.shake }) end },
    circle = { label = "Slam (circle)", desc = "A round blast, at the bug or out ahead.",
        params = { P("radius", "Radius", 5, 200, 5, 35), P("ahead", "Distance ahead", 0, 200, 5, 0), DMG,
            P("knockback", "Knockback", 0, 600, 20, 120), P("windup", "Wind-up (s)", 0, 1.5, 0.05, 0) },
        run = function(me, b) me.hit({ shape = "circle", radius = b.radius, ahead = b.ahead, damage = b.damage, knockback = b.knockback,
            windup = b.windup, status = b.status, hitstop = b.hitstop, shake = b.shake }) end },
    box = { label = "Thrust (box)", desc = "A long rectangle along the aim.",
        params = { P("length", "Length", 10, 300, 5, 70), P("width", "Width", 4, 120, 2, 20), DMG,
            P("knockback", "Knockback", 0, 600, 20, 100), P("windup", "Wind-up (s)", 0, 1.5, 0.05, 0) },
        run = function(me, b) me.hit({ shape = "box", length = b.length, width = b.width, damage = b.damage, knockback = b.knockback,
            windup = b.windup, status = b.status, hitstop = b.hitstop, shake = b.shake, fx = "stab" }) end },
    ring = { label = "Shockwave (ring)", desc = "A donut round the bug: misses what is right next to it.",
        params = { P("radius", "Radius", 20, 250, 5, 70), P("inner", "Hole", 0, 200, 5, 35), DMG, P("knockback", "Knockback", 0, 600, 20, 160) },
        run = function(me, b) me.hit({ shape = "ring", radius = b.radius, inner = b.inner, damage = b.damage, knockback = b.knockback,
            status = b.status, hitstop = b.hitstop, shake = b.shake }) end },
    sweep = { label = "Spinning sweep", desc = "A blade that sweeps round over time.",
        params = { P("radius", "Reach", 10, 200, 5, 55), P("turn", "Turn (degrees)", 30, 720, 30, 360), P("time", "Seconds", 0.1, 2, 0.05, 0.4), DMG },
        run = function(me, b)
            local half = math.rad(b.turn) / 2
            me.hit({ shape = "arc", radius = b.radius, degrees = 40, active = b.time, sweep = { -half, half }, follow = true,
                damage = b.damage, status = b.status, hitstop = b.hitstop, shake = b.shake, fx = "outline" })
        end },
    shoot = { label = "Shoot", desc = "Fire shots along the aim (a fan when more than one).",
        params = { P("count", "Shots", 1, 12, 1, 1), P("spread", "Fan (degrees)", 0, 180, 5, 30), P("speed", "Speed", 60, 800, 20, 280),
            P("range", "Range", 20, 600, 10, 160), DMG, P("pierce", "Pierce", 0, 10, 1, 0) },
        run = function(me, b)
            local n = math.floor(b.count)
            for i = 1, n do
                local turn = n > 1 and math.rad(b.spread) * ((i - 1) / (n - 1) - 0.5) or 0
                me.shoot({ turn = turn, speed = b.speed, range = b.range, damage = b.damage, pierce = b.pierce, status = b.status })
            end
        end },
    lob = { label = "Lob a bomb", desc = "An arcing shot that bursts where it lands.",
        params = { P("range", "Range", 20, 400, 10, 120), P("radius", "Burst radius", 5, 120, 5, 30), DMG },
        run = function(me, b) me.shoot({ arc = true, range = b.range, damage = 0, burst = { radius = b.radius, damage = b.damage } }) end },
    pool = { label = "Puddle", desc = "A puddle on the ground that hurts and slows.",
        params = { P("radius", "Radius", 5, 120, 5, 24), P("life", "Seconds", 0.5, 15, 0.5, 3), P("dps", "Damage / s", 0, 60, 1, 4),
            P("slow", "Speed inside", 0.1, 1, 0.05, 0.6), P("ahead", "Distance ahead", 0, 200, 5, 0) },
        run = function(me, b) me.pool({ radius = b.radius, life = b.life, dps = b.dps, slow = b.slow, ahead = b.ahead }) end },
    push = { label = "Push away", desc = "Shove the ants around the bug away.",
        params = { P("radius", "Radius", 10, 250, 5, 60), P("strength", "Strength", 20, 800, 20, 260) },
        run = function(me, b) me.push({ radius = b.radius, strength = b.strength }) end },
    pull = { label = "Pull in", desc = "Drag the ants around the bug in.",
        params = { P("radius", "Radius", 10, 250, 5, 90), P("strength", "Strength", 20, 800, 20, 200) },
        run = function(me, b) me.pull({ radius = b.radius, strength = b.strength }) end },
    wall = { label = "Sticky wall", desc = "A wall across the aim that catches ants.",
        params = { P("length", "Length", 20, 300, 10, 80), P("life", "Seconds", 1, 20, 1, 5) },
        run = function(me, b) me.wall({ length = b.length, life = b.life }) end },
    summon = { label = "Hatch helpers", desc = "Little helpers that run down ants.",
        params = { P("count", "How many", 1, 10, 1, 2), P("damage", "Damage", 0, 100, 1, 5), P("life", "Seconds", 1, 30, 1, 8) },
        run = function(me, b) me.summon({ count = b.count, damage = b.damage, life = b.life }) end },
    heal = { label = "Heal", desc = "Get some health back.", params = { P("amount", "HP", 1, 100, 1, 5) },
        run = function(me, b) me.heal(b.amount) end },
    shield = { label = "Shield", desc = "Nothing hurts the bug for a moment.", params = { P("time", "Seconds", 0.1, 5, 0.1, 0.6) },
        run = function(me, b) me.shield(b.time) end },
    speed = { label = "Speed up", desc = "Move faster (or slower) for a while.",
        params = { P("mul", "Speed x", 0.2, 3, 0.1, 1.4), P("time", "Seconds", 0.5, 20, 0.5, 2) },
        run = function(me, b) me.speed(b.mul, b.time) end },
    root = { label = "Plant feet", desc = "Stand still for a moment (heavy swings).", params = { P("time", "Seconds", 0.05, 2, 0.05, 0.25) },
        run = function(me, b) me.root(b.time) end },
    cloak = { label = "Vanish", desc = "The ants lose track of the bug.", params = { P("time", "Seconds", 0.5, 10, 0.5, 2) },
        run = function(me, b) me.cloak(b.time) end },
    status = { label = "Afflict", desc = "Put one of the bug's own status effects on the ants around it.",
        params = { P("radius", "Radius", 10, 250, 5, 60) },
        run = function(me, b) me.statusArea({ radius = b.radius, status = b.status }) end },
    ring_fx = { label = "Ring effect", desc = "A ring flash (looks only).", params = { P("radius", "Radius", 5, 250, 5, 30) },
        run = function(me, b) me.ring({ radius = b.radius, color = b.color }) end },
    shake = { label = "Screen shake", desc = "Shake the screen.", params = { P("amount", "Amount", 0.02, 0.8, 0.02, 0.15) },
        run = function(me, b) me.shake(b.amount) end },
    hitstop = { label = "Hitstop", desc = "Freeze the action a moment.", params = { P("time", "Seconds", 0.01, 0.25, 0.01, 0.05) },
        run = function(me, b) me.hitstop(b.time) end },
    sound = { label = "Sound", desc = "Play a sound (pitch).", params = { P("pitch", "Pitch", 0.3, 3, 0.1, 1) },
        run = function(me, b) me.sound(type(b.name) == "string" and b.name or "boom", b.pitch) end },
}
MB.ORDER = { "lunge", "wait", "arc", "circle", "box", "ring", "sweep", "shoot", "lob", "pool", "push", "pull", "wall",
    "summon", "heal", "shield", "speed", "root", "cloak", "status", "ring_fx", "shake", "hitstop", "sound" }

local function clampNum(v, p)
    v = tonumber(v)
    if not v or v ~= v then v = p.default end
    return math.max(p.min, math.min(p.max, v))
end

-- Check a block list: unknown kinds dropped with a warning, numbers kept in range. Returns a
-- clean copy (plain data) or nil.
function MB.clean(list, warns, where)
    if type(list) ~= "table" then return nil end
    local out = {}
    for i, b in ipairs(list) do
        if i > 24 then warns[#warns + 1] = where .. ": 24 blocks at most" break end
        local kind = type(b) == "table" and (b[1] or b.kind)
        local K = MB.KINDS[kind]
        if not K then
            warns[#warns + 1] = ("%s[%d]: no block '%s' (%s)"):format(where, i, tostring(kind), table.concat(MB.ORDER, ", "))
        else
            local c = { kind }
            for _, p in ipairs(K.params) do c[p.key] = clampNum(b[p.key], p) end
            -- extras every block may carry
            if type(b.status) == "string" then c.status = b.status:sub(1, 20) end
            if type(b.name) == "string" then c.name = b.name:sub(1, 20) end
            if tonumber(b.hitstop) then c.hitstop = math.max(0, math.min(0.25, tonumber(b.hitstop))) end
            if tonumber(b.shake) then c.shake = math.max(0, math.min(0.8, tonumber(b.shake))) end
            if type(b.color) == "string" then c.color = b.color end
            out[#out + 1] = c
        end
    end
    return out
end

-- A clean block list -> function(me).
function MB.compile(list)
    local function runFrom(me, i)
        while i <= #list do
            local b = list[i]
            if b[1] == "wait" then
                local rest = i + 1
                me.after(b.time, function(me2) runFrom(me2, rest) end)
                return
            end
            MB.KINDS[b[1]].run(me, b)
            i = i + 1
        end
    end
    return function(me) runFrom(me, 1) end
end

-- combo = { step, step, ..., window } -> function(me). Each step: function or block list.
function MB.combo(c, warns, where)
    local steps = {}
    for i, s in ipairs(c) do
        if i > 8 then warns[#warns + 1] = where .. ": 8 steps at most" break end
        if type(s) == "function" then steps[#steps + 1] = s
        else
            local bl = MB.clean(s, warns, where .. "[" .. i .. "]")
            if bl and #bl > 0 then steps[#steps + 1] = MB.compile(bl) end
        end
    end
    if #steps == 0 then return nil end
    local window = math.max(0.1, math.min(3, tonumber(c.window) or 0.8))
    local key = {}
    return function(me)
        local st = me.state
        local cs = st[key] or { n = 0, t = -99 }
        st[key] = cs
        if me.time - cs.t > window + (me.params.cooldown or 0) then cs.n = 0 end
        cs.n = cs.n % #steps + 1
        cs.t = me.time
        me.combo = cs.n
        return steps[cs.n](me)
    end
end

-- A short readable line for a block (mixer list).
function MB.describe(b)
    local K = MB.KINDS[b[1]]
    if not K then return tostring(b[1]) end
    local bits = {}
    for i, p in ipairs(K.params) do
        if i > 3 then break end
        bits[#bits + 1] = p.label:lower() .. " " .. tostring(b[p.key])
    end
    return K.label .. (#bits > 0 and ("  (" .. table.concat(bits, ", ") .. ")") or "")
end

function MB.new(kind)
    local K = MB.KINDS[kind]
    local b = { kind }
    for _, p in ipairs(K.params) do b[p.key] = p.default end
    return b
end

return MB
