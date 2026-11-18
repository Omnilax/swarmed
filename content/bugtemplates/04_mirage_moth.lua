-- KIND: Trickster
-- TEMPLATE: the Mirage Moth. Hard to pin down: its dust dazes ants so they stumble about,
-- its dash leaves it unseen for a moment, and it blinks away when hit.
return {
    name = "Mirage Moth",
    description = "A blur of wings and dust. Its powder dazes ants so they stagger about, and charmed ones turn on their friends. Shift vanishes for a moment. When it gets hit it blinks away.",
    tip = "{attack} throws dazing dust. {secondary} charms the ants around you. {dash} makes you vanish.",
    look = "dragonfly",
    playstyle = "control",
    stats = { maxHp = 60, moveSpeed = 130, dodge = 15 },

    statuses = { daze = { preset = "daze", onHit = 0.4 }, charm = { preset = "charm" } },
    passives = { blink = {} },
    effects = { sparkle = { color = "#e0d0ff", rate = 6 }, trail = "petals" },
    card = { motto = "Now you see me.", color = "#d0b0ff", frame = "leaf" },

    attack = { name = "Dust", cooldown = 0.45, blocks = {
        { "shoot", count = 3, spread = 40, speed = 260, range = 110, damage = 5, pierce = 1 } } },
    secondary = { name = "Beguile", cooldown = 6, blocks = { { "status", radius = 70, status = "charm" }, { "ring_fx", radius = 70, color = "#ff90d0" } } },
    dash = { type = "scripted", name = "Vanish", start = function(me) me.lunge(60) me.cloak(1.5) me.particles({ count = 14, color = { 0.9, 0.85, 1 } }) end },
}
