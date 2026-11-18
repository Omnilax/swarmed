-- KIND: Glass cannon
-- TEMPLATE: the Spark Wasp. Its own pixel art and buzzing wings. Fragile but deadly: lightning
-- that jumps from ant to ant, and at wave 10 it molts into a bigger, tougher queen.
local PAL = { o = "#140c04c0", a = "#2a2010", b = "#e0b020", c = "#ffe070", y = "#1a1408", e = "#100808", w = "#fff8d0" }
return {
    name = "Spark Wasp",
    description = "Paper-thin but crackling with power. Its sting arcs lightning through up to five ants. It dies fast, so keep moving. At wave 10 it molts into a bigger, tougher queen.",
    tip = "Never stand still. {attack} arcs lightning, {secondary} discharges everything around you.",
    playstyle = "speedster",
    tags = { "insect" },
    art = {
        palette = PAL,
        body = {
            ".oooo....ooo..",
            "obybyboooccoo.",
            "obybybbcccbeo.",
            "obybybbcccbbwo",
            "obybybbcccbeo.",
            "obybyboooccoo.",
            ".oooo....ooo..",
        },
        legs = { { 2, -1, 3, -5, 5, -7 }, { 0, -1, -1, -5, -2, -8 }, { -1, -1, -4, -4, -7, -6 } },
        legColor = "#2a2010",
        wings = { size = 5, color = "#e8f4ff", flap = 30 },
        antennae = { length = 5, color = "#2a2010" },
        height = 2, lift = 4,
    },
    stats = { maxHp = 35, moveSpeed = 140, damage = 40, critChance = 20 },
    movement = { hover = 4 },
    effects = { glow = { color = "#ffe060", radius = 40, intensity = 0.5, pulse = 3 } },
    hitFx = { number = "#ffff80", sparks = { color = "#ffff80", count = 3 }, sound = "zap" },
    card = { motto = "Live fast.", color = "#ffe040", frame = "gold" },

    attack = { type = "scripted", name = "Arc Sting", cooldown = 0.5, range = 70,
        fire = function(me) me.chain({ radius = 70, jumps = 4, range = 55, damage = 7, color = { 1, 1, 0.5 } }) end },
    secondary = { name = "Discharge", cooldown = 5, blocks = { { "ring", radius = 80, inner = 0, damage = 18, knockback = 200 }, { "hitstop", time = 0.05 } } },
    dash = { from = "dragonfly" },
    molt = { wave = 10, name = "Spark Queen", say = "Long live the queen!", stats = { maxHp = 50, armor = 2 }, scale = 1.3 },
}
