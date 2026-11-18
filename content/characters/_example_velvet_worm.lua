-- ===========================================================================================
--  EXAMPLE CUSTOM BUG: the Velvet Worm
--  Shows off everything a script can do: a segmented body with antennae, a hold-to-charge
--  attack, a sticky wall, a stamina mode, code that runs on game events, its own sounds,
--  its own animation and its own skill tree. Bug Creator > Example: Velvet Worm.
--  Guide: docs/CUSTOM_BUGS.md
-- ===========================================================================================

local GLUE = { 0.95, 0.92, 0.75 }

-- one pixel drawing per part, facing right ("." is empty)
local HEAD = {
    "..oooo.",
    ".obbbbo",
    "obcbccw",
    "obbbbbo",
    "obcbccw",
    ".obbbbo",
    "..oooo.",
}
local SEG = {
    ".ooo.",
    "obbbo",
    "obdbo",
    "oaaao",
    "obdbo",
    "obbbo",
    ".ooo.",
}
local SEG2 = {
    ".ooo.",
    "obbbo",
    "obbbo",
    "oaaao",
    "obbbo",
    "obbbo",
    ".ooo.",
}

-- a squirt of glue: a fan of sticky shots that leave puddles where they land
local function squirt(me, charge)
    local n = 1 + math.floor(charge * 4)
    for i = 1, n do
        local turn = (i - (n + 1) / 2) * 0.16
        me.shoot({ turn = turn, speed = 240 + charge * 120, range = 90 + charge * 70, damage = 5 + charge * 10,
            slow = { 0.4, 2 }, color = GLUE, size = 2 + charge * 2,
            pool = charge > 0.6 and { radius = 14 + charge * 8, life = 3, dps = 2, slow = 0.4, color = GLUE } or nil })
    end
    me.sound(charge > 0.9 and "big_squirt" or "squirt", 1 + (1 - charge) * 0.3)
    if charge > 0.9 then me.shake(0.12) end
end

return {
    name = "Velvet Worm",
    description = "A soft, many-legged hunter that shoots glue. Hold left click to build up a bigger squirt. Right click strings a sticky wall across your aim. Hold Shift to ooze along faster, leaving slick puddles behind. Every 12 kills, two little worms hatch and hunt with you.",
    lore = "Velvet worms catch prey by spraying two jets of sticky slime from their head. They've barely changed in 500 million years.",
    tip = "Hold {attack} to charge the glue. {secondary} builds a sticky wall. Hold {dash} to ooze.",
    playstyle = "control",
    tags = { "myriapod" },

    art = {
        palette = {
            o = "#140a10b0", a = "#3a1e2a", b = "#5a2e3e", c = "#7a4252", d = "#d8843a",
            w = "#f0e0c0",
        },
        -- a segmented body: the head, then segments that trail behind like a centipede's
        chain = {
            head = HEAD, segment = SEG, segment2 = SEG2,
            segments = 9, spacing = 3, wave = 0.12,
            leg = { 0, -2, -0.4, -4, -1, -5.5 },      -- one stubby leg each side of every segment
        },
        legColor = "#6a3a48",
        height = 3, lift = 1,
        -- always-there limbs: two long feelers
        limbs = {
            { u = 3, v = 1.5, segs = { { 3, 0.5, 0.4 }, { 3, -0.3, -0.2 }, { 2, -0.2, -0.2 } }, width = 1, color = "c" },
            { u = 3, v = -1.5, side = -1, segs = { { 3, 0.5, 0.4 }, { 3, -0.3, -0.2 }, { 2, -0.2, -0.2 } }, width = 1, color = "c" },
        },
    },
    scale = 1.1,

    stats = { maxHp = 60, moveSpeed = 92, armor = 0, hpRegen = 0.4 },

    -- its own sounds, made from a few numbers
    sounds = {
        squirt = { wave = "noise", freq = 900, to = 300, duration = 0.14, volume = 0.45, decay = 2 },
        big_squirt = { wave = "saw", freq = 220, to = 80, duration = 0.3, noise = 0.5, volume = 0.6 },
        hatch = { wave = "triangle", notes = { 520, 660, 880 }, duration = 0.25, volume = 0.4 },
    },

    -- its own animations: attack plays when the attack fires; me.anim("rear") plays the other
    anims = {
        attack = { time = 0.3, keys = { { 0, rear = 2, lunge = -2 }, { 0.3, rear = -1, lunge = 3, stretch = 0.2 }, { 1 } } },
        rear = { time = 0.5, keys = { { 0 }, { 0.4, rear = 4, stretch = -0.1 }, { 1 } } },
    },

    -- ATTACK: hold to charge (0 .. 1), let go to squirt
    attack = {
        type = "scripted",
        name = "Glue Squirt",
        cooldown = 0.5,
        range = 110,
        charge = 1.0,          -- seconds to a full charge
        hold = function(me, dt, charge)
            if charge >= 1 and not me.state.full then
                me.state.full = true
                me.ring({ radius = 10, color = GLUE })
            end
        end,
        release = function(me, charge)
            me.state.full = false
            squirt(me, charge)
        end,
    },

    -- SPECIAL: a sticky wall across your aim that catches and holds ants
    secondary = {
        type = "scripted",
        name = "Slime Line",
        cooldown = 5,
        range = 90,
        fire = function(me)
            me.anim("rear")
            me.wall({ length = 90, ahead = 45, life = 6, strength = 40, hold = 2.5, damage = 3 })
            me.pull({ radius = 70, strength = 160 })
            me.sound("big_squirt", 1.4)
        end,
    },

    -- DASH: a stamina mode. Hold Shift to ooze faster, dropping slick puddles
    dash = {
        type = "scripted",
        name = "Ooze",
        mode = true,
        speed = 1.45,
        stamina = 3,
        enter = function(me) me.state.drip = 0 me.sound("squirt", 0.7) end,
        tick = function(me, dt)
            me.state.drip = me.state.drip + dt
            if me.state.drip > 0.3 then
                me.state.drip = 0
                me.pool({ radius = 16, life = 2.5, dps = 3, slow = 0.5, color = { 0.6, 0.5, 0.65 } })
            end
        end,
        exit = function(me, dry) if dry then me.say("Out of slime!") end end,
    },

    -- code that runs on game events
    hooks = {
        onKill = function(me, ev)
            me.state.kills = (me.state.kills or 0) + 1
            if me.state.kills % 12 == 0 then
                me.summon({ count = 2, life = 10, damage = 6, speed = 150, bites = 6, color = { 0.55, 0.3, 0.4 } })
                me.sound("hatch")
            end
        end,
        onHurt = function(me, ev)
            -- once a wave, when badly hurt: curl up for a moment
            if me.hp < me.maxHp * 0.3 and not me.state.curled then
                me.state.curled = true
                me.shield(1.2)
                me.push({ radius = 50, strength = 300 })
                me.say("Curl!")
            end
        end,
        onWaveStart = function(me, ev) me.state.curled = false end,
    },

    -- its own skill tree (skip a level-up card for a point). Nodes can change stats, change
    -- the moves' numbers, or run code when something happens.
    skillTree = {
        branches = {
            { name = "Glue", color = { 0.95, 0.9, 0.6 }, nodes = {
                { id = "thick", tier = 1, ranks = 3, name = "Thick Glue", desc = "+15% damage per rank.",
                  stats = { damage = 15 } },
                { id = "quick", tier = 2, name = "Quick Squirt", desc = "Charges 30% faster.",
                  attack = { charge = { mul = -0.3 } } },
                { id = "sticky", tier = 3, name = "Sticky End", desc = "Ants you kill leave a glue puddle.",
                  procs = { { trigger = "onKill", chance = 0.4, effect = function(me, ev)
                      me.pool({ x = ev.x, y = ev.y, radius = 18, life = 3, dps = 4, slow = 0.4, color = GLUE })
                  end } } },
            } },
            { name = "Body", color = { 0.8, 0.5, 0.6 }, nodes = {
                { id = "soft", tier = 1, ranks = 3, name = "Soft Body", desc = "+15 max HP per rank.",
                  stats = { maxHp = 15 } },
                { id = "brood", tier = 2, name = "Big Brood", desc = "Every hit you take has a chance to hatch a worm.",
                  procs = { { trigger = "onHurt", chance = 0.3, effect = function(me)
                      me.summon({ count = 1, life = 8, damage = 5, bites = 4, color = { 0.55, 0.3, 0.4 } })
                  end } } },
            } },
        },
    },
}
