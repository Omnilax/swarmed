-- ===========================================================================================
--  BUILT-IN SCRIPTED BUG: the Water Strider (written by Ozy in the Bug Creator format)
--  Skates over the field as if it were a pond. Almost no grip: it darts forward in sharp
--  bursts, one long middle leg then the other, and glides between them with its legs held
--  still. Turning is a slow carve, and pulling back against
--  your slide makes it skid to a stop, throwing up a spray of rings.
--
--    Left click    Rostrum Stab: a quick, narrow stab straight ahead that kicks you a little
--                  backwards (stab, slide away). Stabbing at speed hits harder.
--    Right click   Ripple: a soft ring that spreads out from the strider in every direction,
--                  slowly, fading as it goes. Barely any damage: it slows and nudges ants.
--    Shift         Figure Eight: skates one figure 8 round the spot it started on, touching
--                  each ant on the way once. Can't be hurt while looping.
--  Written against docs/BUG_API.md. Files in content/scripted/ load through the Bug Creator's
--  script pipeline (src/game/custombugs.lua, CustomBugs.loadBuiltIns) but join the roster as
--  real bugs: their id is the file name, and unlocks live in src/config/unlocks.lua.
-- ===========================================================================================

local WATER = { 0.62, 0.83, 1 }
local WATER_HEX = "#9fd4ff"
local TAU = 2 * math.pi

-- skating
local STROKE_GAP = 0.55        -- seconds between bursts while pushing
local STROKE_FORCE = 250       -- push of a burst from standing still
local BURST_SPEED = 1.8         -- speed multiplier for the split second of each burst
local BURST_TIME = 0.12         -- how long that lasts
local STROKE_ANGLE = 0.3       -- each stroke pushes this far (radians) to its own side, so you weave
local GLIDE_TOP = 300          -- at this speed a stroke barely adds anything
local SKID_DOT = -0.35         -- pulling back this hard against your slide = a skid
local SKID_BRAKE = 70          -- how hard a skid slows you, per skid tick

-- stab
local RECOIL = 85              -- backwards kick of each stab
local MOMENTUM_SAY_GAP = 6     -- seconds between "Momentum!" call-outs

-- ripple (right click): a gentle ring all round
local RIPPLE_SPEED = 105       -- px/s at the start (slows as it fades)
local RIPPLE_LIFE = 1.8        -- seconds until it fades out (about 140 px across)
local RIPPLE_DAMAGE = 3        -- damage at the very start (it's mostly a slow, not a kill)
local RIPPLE_KNOCK = 50        -- nudge at the very start
local RIPPLE_GAP = 11          -- px between the rings in one ripple
local MAX_RIPPLES = 6

-- figure eight (Shift)
local EIGHT_TIME = 1.35        -- seconds for the one figure 8
local EIGHT_LENGTH = 70        -- how far each loop reaches along the aim
local EIGHT_WIDTH = 90         -- how wide the loops are (the 8 is about half this to each side)
local EIGHT_DAMAGE = 9         -- each ant touched, once per 8
local EIGHT_REACH = 24         -- how close an ant must pass to be touched

local function angleDiff(a, b)
    local d = (a - b) % TAU
    if d > math.pi then d = d - TAU end
    return d
end

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- ---------------------------------------------------------------- water rings (just looks)

local function ring(me, x, y, maxR, life)
    local st = me.state
    st.rings = st.rings or {}
    if #st.rings >= 36 then table.remove(st.rings, 1) end
    table.insert(st.rings, { x = x, y = y, t = 0, life = life or 0.7, r = maxR or 12 })
end

-- a ring under one foot. fwd / side in px along and across the body (side + = left)
local function footRing(me, fwd, side, maxR, life)
    local fx, fy = me.facingX or 1, me.facingY or 0
    ring(me, me.x + fx * fwd - fy * side, me.y + fy * fwd + fx * side, maxR, life)
end

-- ---------------------------------------------------------------- the ripple

-- a ring spreading out from (x, y) in every direction
local function newRipple(me, x, y, life, damage)
    local st = me.state
    st.ripples = st.ripples or {}
    if #st.ripples >= MAX_RIPPLES then table.remove(st.ripples, 1) end
    local area = 1 + (me.stat("area") or 0) / 100
    table.insert(st.ripples, { x = x, y = y, life = (life or RIPPLE_LIFE) * math.max(0.4, area),
        damage = damage or RIPPLE_DAMAGE, t = 0, r = 4, lastR = 0, tick = 0, hit = {} })
end

local function updateRipples(me, dt)
    local list = me.state.ripples
    if not list then return end
    for i = #list, 1, -1 do
        local rp = list[i]
        rp.t = rp.t + dt
        local s = 1 - rp.t / rp.life                     -- strength, 1 -> 0
        if s <= 0 then
            table.remove(list, i)
        else
            rp.r = rp.r + RIPPLE_SPEED * (0.35 + 0.65 * s) * dt
            rp.tick = rp.tick + dt
            if rp.tick >= 0.06 then
                rp.tick = 0
                local inner = rp.lastR - 6
                rp.lastR = rp.r
                local dmg = rp.damage * s
                -- every ant the outer ring has just passed under, once each
                for _, e in ipairs(me.enemiesNear({ x = rp.x, y = rp.y, radius = rp.r + 4, max = 40 })) do
                    if not rp.hit[e.uid] and dist(e.x, e.y, rp.x, rp.y) >= inner then
                        rp.hit[e.uid] = true
                        if s > 0.05 then
                            -- a tiny hitbox just inside the ant, so the nudge goes outward
                            local ang = math.atan2(e.y - rp.y, e.x - rp.x)
                            me.hit({ shape = "circle", x = e.x - math.cos(ang) * 4, y = e.y - math.sin(ang) * 4,
                                radius = 5, damage = dmg, knockback = RIPPLE_KNOCK * s, slow = { 0.7, 0.8 + s },
                                noCrit = true, color = WATER })
                        end
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- the figure eight

local function eightPoint(e, th)
    -- lemniscate of Gerono: starts and ends at the centre, crossing it once in the middle
    local fx = math.sin(th) * EIGHT_LENGTH
    local fy = math.sin(th) * math.cos(th) * EIGHT_WIDTH * e.side
    local ca, sa = math.cos(e.a), math.sin(e.a)
    return e.x + ca * fx - sa * fy, e.y + sa * fx + ca * fy
end

local function updateEight(me, dt)
    local st = me.state
    local e = st.eight
    e.t = e.t + dt
    -- ease in and out a touch, like leaning into the curves
    local k = math.min(1, e.t / EIGHT_TIME)
    local th = (k - math.sin(k * TAU) * 0.06) * TAU
    local px, py = eightPoint(e, th)
    me.teleport(px, py)
    local nx, ny = eightPoint(e, math.min(TAU, th + 0.15))
    if dist(nx, ny, px, py) > 0.5 then me.face(nx, ny) end

    -- touch each ant along the way once
    for _, a in ipairs(me.enemiesNear({ radius = EIGHT_REACH, max = 12 })) do
        if not e.hit[a.uid] then
            e.hit[a.uid] = true
            local ang = me.angleTo(a.x, a.y)
            me.hit({ shape = "circle", x = a.x - math.cos(ang) * 4, y = a.y - math.sin(ang) * 4, radius = 5,
                damage = EIGHT_DAMAGE, knockback = 130, color = WATER })
        end
    end

    -- the blade line: a ring every few px
    e.mark = e.mark + dt
    if e.mark >= 0.05 then
        e.mark = 0
        ring(me, px, py, 10, 0.9)
    end
    if k >= 1 then
        st.eight = nil
        -- leave the last curve and carry on gliding along it
        local tx, ty = eightPoint(e, TAU - 0.05)
        local ox, oy = px - tx, py - ty
        local d = math.sqrt(ox * ox + oy * oy)
        if d > 0.01 then me.knock(ox / d, oy / d, 110) end
    end
end

-- ---------------------------------------------------------------- skating

local function skate(me, dt)
    local st = me.state
    local vx, vy, sp = me.vx or 0, me.vy or 0, me.speedNow or 0
    local mx, my = me.moveInput()

    if me.moving then
        -- pulling back against the slide: skid
        local along = sp > 1 and (mx * vx + my * vy) / sp or 1
        if sp > 70 and along < SKID_DOT then
            st.skid = (st.skid or 0) - dt
            if st.skid <= 0 then
                st.skid = 0.07
                me.knock(-vx / sp, -vy / sp, SKID_BRAKE)
                footRing(me, -4, 10, 9, 0.5)
                footRing(me, -4, -10, 9, 0.5)
                if not st.skidding then me.sound("skid", 0.9 + math.random() * 0.2) end
            end
            st.skidding = true
            return
        end
        st.skidding = false

        -- stroke: push off one leg, then the other, each a little out to its own side
        st.stroke = (st.stroke or 0) - dt
        if st.stroke <= 0 then
            st.stroke = STROKE_GAP
            st.leg = -(st.leg or 1)
            local a = math.atan2(my, mx) + STROKE_ANGLE * st.leg
            local push = STROKE_FORCE * math.max(0.15, 1 - math.max(0, sp * along) / GLIDE_TOP)
            -- a sharp burst, then nothing but glide until the next one
            me.knock(math.cos(a), math.sin(a), push)
            me.speed(BURST_SPEED, BURST_TIME)
            me.anim(st.leg > 0 and "strokeL" or "strokeR")
            me.sound("skate", 0.9 + math.random() * 0.2, 0.5)
            footRing(me, 10, -30 * st.leg, 14)
        end
    else
        st.stroke = 0
        st.skidding = false
        if sp > 40 then
            -- gliding: a thin wake behind
            st.wake = (st.wake or 0) - dt
            if st.wake <= 0 then
                st.wake = math.max(0.06, 0.18 - sp / 2000)
                footRing(me, -14, 0, 8, 0.7)
            end
        else
            -- standing on the surface: the feet press little dimples now and then
            st.idle = (st.idle or 0) - dt
            if st.idle <= 0 then
                st.idle = 1.4 + math.random() * 0.8
                footRing(me, 10, 30, 6)
                footRing(me, 10, -30, 6)
                footRing(me, -26, 24, 6)
                footRing(me, -26, -24, 6)
            end
        end
    end
end

-- ---------------------------------------------------------------- the body
-- top-down, facing right: a long, narrow, dark body with a silvery sheen down the back, a
-- small head with big eyes, and the stabbing rostrum at the front tip
local BODY = {
    ".....oooooooooo.........",
    "...ooabbbbbbbbaooo.oo...",
    ".ooabbccccccbbbaaoohko..",
    "oaabccdddddccbbbaaahhhrs",
    ".ooabbccccccbbbaaoohko..",
    "...ooabbbbbbbbaooo.oo...",
    ".....oooooooooo.........",
}

return {
    name = "Water Strider",
    order = 27,                  -- position in bug select (built-in bugs only)
    description = "Skates across the field as if it were a pond: it darts forward in sharp bursts, legs held still, and glides with almost no grip. Left click stabs with its needle mouth and kicks you back a little. Right click sends a soft ripple spreading out all round that slows ants. Shift skates one figure 8 that touches every ant it passes.",
    lore = "Water striders stand on water using surface tension; their legs are covered in tiny water-repellent hairs. They feel the ripples of insects that fall in and skate over to stab them.",
    tip = "You have almost no grip: push off, glide, and pull back against your slide to skid to a stop. Each stab kicks you backwards, and stabs at speed hit harder. {secondary} sends a soft ripple all round. {dash} skates a figure 8 and can't be hurt while looping.",
    playstyle = "brawler",
    tags = { "insect", "true bug" },
    music = "rattle",

    art = {
        palette = {
            o = "#0a0c10b0",   -- outline
            a = "#1e2228",
            b = "#2e343c",
            c = "#3e4650",
            d = "#5e6a76",     -- silvery sheen down the back
            h = "#262a30",     -- head
            k = "#c8d8e0",     -- eye shine
            r = "#3a2e28",     -- rostrum
            s = "#6a5040",     -- rostrum tip
        },
        body = BODY,
        legs = {
            { 6, -2, 10, -6, 14, -6 },        -- front: short, for grabbing prey
            { 1, -2, 4, -16, 10, -30 },       -- middle: the long oars
            { -2, -2, -8, -12, -26, -24 },    -- hind: long, trailing, for steering
        },
        legColor = "#2a3038",
        height = 2,          -- sits low, right on the surface
        lift = 0,            -- feet never leave the water
        kneeUp = 4,
        stride = 0.35,       -- legs barely shift: they're held out still on the surface
        -- two forward feelers
        limbs = {
            { u = 10, v = 1.2, segs = { { 4, 0.3, 0.2 }, { 4, -0.15, -0.1 } }, width = 1, color = "c" },
            { u = 10, v = -1.2, side = -1, segs = { { 4, 0.3, 0.2 }, { 4, -0.15, -0.1 } }, width = 1, color = "c" },
        },
    },
    scale = 1.2,

    stats = { maxHp = 70, armor = 0, moveSpeed = 100, damage = 10, critChance = 15, dodge = 8,
        dashCooldown = 2.4 },

    movement = { slide = 0.9 },     -- ice: almost no grip (lower = grippier)

    sounds = {
        stab = { wave = "square", freq = 1300, to = 500, duration = 0.05, volume = 0.4 },
        skate = { wave = "noise", freq = 1400, to = 600, duration = 0.14, volume = 0.22, decay = 2 },
        skid = { wave = "noise", freq = 2400, to = 900, duration = 0.3, volume = 0.3 },
        ripple = { wave = "triangle", freq = 300, to = 520, duration = 0.25, volume = 0.3 },
        drip = { wave = "triangle", notes = { 900, 1300 }, duration = 0.08, volume = 0.3 },
        eight = { wave = "noise", freq = 900, to = 1500, duration = 0.9, volume = 0.25 },
    },

    anims = {
        attack = { time = 0.2, keys = { { 0, lunge = -1 }, { 0.3, lunge = 5, stretch = 0.2 }, { 0.6, lunge = -1 }, { 1 } } },
        -- push off one side, then the other: a slight lean into each stroke
        strokeL = { time = 0.22, keys = { { 0, stretch = -0.15, lunge = -1 }, { 0.25, stretch = 0.15, lunge = 2 }, { 1 } } },
        strokeR = { time = 0.22, keys = { { 0, stretch = -0.15, lunge = -1, rear = 1 }, { 0.25, stretch = 0.15, lunge = 2 }, { 1 } } },
        ripple = { time = 0.4, keys = { { 0 }, { 0.3, stretch = -0.15 }, { 1 } } },
        eight = { time = EIGHT_TIME, keys = { { 0, stretch = 0.1 }, { 0.25, stretch = 0.15 }, { 0.75, stretch = 0.15 }, { 1 } } },
    },

    -- LEFT CLICK: Rostrum Stab. Kicks you backwards; hits harder the faster you're going.
    attack = {
        type = "scripted",
        name = "Rostrum Stab",
        cooldown = 0.32,
        range = 50,
        fire = function(me)
            local st = me.state
            local sp = me.speedNow or 0
            local boost = math.min(sp, 300) / 300                  -- 0 .. 1
            me.hitLine({ length = 52, width = 8, damage = 16 + 12 * boost, knockback = 80 + 80 * boost,
                hitstop = boost > 0.6 and 0.03 or nil, color = { 0.85, 0.9, 1 } })
            me.sound("stab", 1.05 - boost * 0.25 + math.random() * 0.1)
            -- push off the stab: slide a little the other way
            me.knock(-me.aimX, -me.aimY, RECOIL)
            footRing(me, 6, 0, 10, 0.5)
            -- a big, fast stab now and then gets a call-out
            if boost > 0.75 then
                me.ring({ radius = 14, color = WATER })
                if me.time - (st.saidAt or -99) > MOMENTUM_SAY_GAP then
                    st.saidAt = me.time
                    me.say("Momentum!", WATER_HEX)
                end
            end
        end,
    },

    -- RIGHT CLICK: Ripple. A soft ring spreading out all round, fading as it goes.
    secondary = {
        type = "scripted",
        name = "Ripple",
        cooldown = 6,
        range = 90,
        fire = function(me)
            newRipple(me, me.x, me.y)
            me.anim("ripple")
            me.sound("ripple")
            me.sound("drip", 0.9, 0.5)
        end,
    },

    -- SHIFT: Figure Eight. One 8, then it carries on gliding.
    dash = {
        type = "scripted",
        name = "Figure Eight",
        start = function(me)
            local st = me.state
            if st.eight then return end                  -- already looping: don't restart it
            st.eightSide = -(st.eightSide or 1)          -- alternates which way the first loop bends
            st.eight = { t = 0, x = me.x, y = me.y, a = me.angle, mark = 0, side = st.eightSide, hit = {} }
            me.shield(EIGHT_TIME)
            me.root(EIGHT_TIME)
            me.anim("eight")
            me.sound("eight")
        end,
    },

    hooks = {
        onTick = function(me, dt)
            local st = me.state
            updateRipples(me, dt)

            -- age the water rings
            if st.rings then
                for i = #st.rings, 1, -1 do
                    local r = st.rings[i]
                    r.t = r.t + dt
                    if r.t >= r.life then table.remove(st.rings, i) end
                end
            end

            if st.eight then updateEight(me, dt) return end
            skate(me, dt)
        end,

        onDraw = function(me, gfx)
            local st = me.state
            -- rings on the water
            if st.rings then
                for _, r in ipairs(st.rings) do
                    local k = r.t / r.life
                    gfx.circle(r.x, r.y, 2 + r.r * k, WATER_HEX, 0.45 * (1 - k), true)
                end
            end
            -- ripples: a thin outer ring with two fainter rings following it in
            if st.ripples then
                for _, rp in ipairs(st.ripples) do
                    local s = 1 - rp.t / rp.life
                    for w = 0, 2 do
                        local rr = rp.r - w * RIPPLE_GAP
                        if rr > 2 then
                            gfx.circle(rp.x, rp.y, rr, WATER_HEX, s * (0.6 - w * 0.17), true)
                        end
                    end
                end
            end
        end,
    },

    skillTree = {
        branches = {
            { name = "Rostrum", color = { 0.85, 0.9, 1 }, nodes = {
                { id = "needle", tier = 1, ranks = 3, name = "Needle Mouth", desc = "+15% damage per rank.",
                  stats = { damage = 15 } },
                { id = "quickstab", tier = 2, name = "Quick Stab", desc = "Attacks 20% faster.",
                  stats = { attackSpeed = 20 } },
                { id = "keen", tier = 3, name = "Keen Eyes", desc = "+15% crit chance.",
                  stats = { critChance = 15 } },
            } },
            { name = "Ripple", color = { 0.62, 0.83, 1 }, nodes = {
                { id = "wide", tier = 1, ranks = 3, name = "Long Ripples", desc = "Ripples spread 15% further per rank.",
                  stats = { area = 15 } },
                { id = "swell", tier = 2, name = "Swell", desc = "Ripple recharges 20% faster.",
                  secondary = { cooldown = { mul = -0.2 } } },
                { id = "splash", tier = 3, name = "Splash", desc = "Kills have a 30% chance to send a small ripple out from where the ant fell.",
                  procs = { { trigger = "onKill", chance = 0.3, effect = function(me, ev)
                      newRipple(me, ev.x, ev.y, 0.9, 1.5)
                  end } } },
            } },
            { name = "Skating", color = { 0.4, 0.5, 0.6 }, nodes = {
                { id = "glide", tier = 1, ranks = 2, name = "Glide", desc = "+12 move speed per rank.",
                  stats = { moveSpeed = 12 } },
                { id = "loops", tier = 2, ranks = 2, name = "Tight Loops", desc = "Figure Eight recharges 0.3 s faster per rank.",
                  stats = { dashCooldown = -0.3 } },
                { id = "hairs", tier = 3, name = "Water-Repellent Hairs", desc = "+10% dodge.",
                  stats = { dodge = 10 } },
            } },
        },
    },
}
