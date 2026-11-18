-- KIND: Vampire
-- TEMPLATE: the Vampire Tick. Drinks health from what it bites; its special charms a ring of
-- ants into fighting for it for a moment.
return {
    name = "Vampire Tick",
    description = "Every bite drinks a little health back. Its special charms the ants around it into fighting each other. Weak at range, hard to kill up close.",
    tip = "Stay in the thick of it: {attack} heals you. {secondary} turns ants against each other.",
    look = "tarantula",
    playstyle = "brawler",
    colors = { hue = 340, saturation = 1.3 },
    scale = 0.9,
    stats = { maxHp = 70, moveSpeed = 108, lifesteal = 10 },
    statuses = { charm = { preset = "charm", time = 3 } },
    hitFx = { number = "#ff3050", sparks = { color = "#c00020", count = 3 } },
    card = { motto = "Just a little sip.", color = "#e02040", frame = "bone" },

    attack = {
        type = "scripted", name = "Drain Bite", cooldown = 0.4, range = 32,
        fire = function(me)
            me.hit({ shape = "arc", radius = 32, degrees = 90, damage = 8, knockback = 30,
                onHit = function(me2, ev) me2.heal(1) end })
        end,
    },
    secondary = { name = "Hypnotise", cooldown = 7, blocks = { { "status", radius = 80, status = "charm" }, { "ring_fx", radius = 80, color = "#ff4060" } } },
    dash = { from = "jumping_spider" },
}
