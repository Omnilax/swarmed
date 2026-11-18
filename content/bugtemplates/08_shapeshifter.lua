-- KIND: Shapeshifter
-- TEMPLATE: the Changeling. Two bugs in one: hold Shift to switch from a quick biter to a
-- heavy armoured crusher, and let go to switch back.
return {
    name = "Changeling",
    description = "Two bugs in one. Normally a quick, light biter. Hold Shift to swell into an armoured crusher with a slow, huge slam; let go to shrink back.",
    tip = "Hold {dash} for the heavy form. Let go to be quick again.",
    look = "stink_bug",
    playstyle = "brawler",
    stats = { maxHp = 90, moveSpeed = 120 },
    formName = "Quick form",
    card = { motto = "Which one am I today?", color = "#90e0a0", frame = "leaf" },

    attack = { name = "Quick Bite", cooldown = 0.3, blocks = { { "arc", radius = 36, degrees = 110, damage = 7, knockback = 40 } } },
    forms = {
        {
            name = "Crusher", say = "Crusher!",
            look = "rhino_beetle",
            stats = { armor = 6, moveSpeed = -45 },
            attack = { name = "Crusher Slam", cooldown = 1, blocks = {
                { "root", time = 0.2 }, { "circle", radius = 60, ahead = 20, damage = 30, knockback = 380, windup = 0.25 }, { "shake", amount = 0.2 } } },
            secondary = { name = "Ground Pound", cooldown = 4, blocks = { { "ring", radius = 90, inner = 0, damage = 20, knockback = 300 } } },
        },
    },
}
