-- Giant millipede: the defensive cousin of the centipede. Slow and armoured, it poisons
-- everything pressed against its long body, coils into an armoured spiral, and rolls up into a
-- ball like a pill bug.
return {
    name = "Millipede",
    description = "Slow, armoured and toxic: stink glands along its whole body poison every ant touching it. Hold the special to coil into an armoured spiral (85% less damage, oozing toxin), let go to release it all in one burst. Hold Shift to curl into a ball and roll (on stamina): faster, tougher, and it bumps ants aside.",
    lore = "Millipedes don't bite. They curl up and ooze toxins; some even leak cyanide. Monkeys rub them on their fur as bug repellent.",
    sprite = "millipede",
    model = { kind = "chain", legs = "millipede_legs", head = "millipede_head", segment = "millipede_seg", segment2 = "millipede_seg2",
        segments = 18, spacing = 2.4, height = 3, lift = 1, legColor = "#c0402a", wave = 0.07,
        leg = { { 0, -1.8, -0.3, -3.4, -0.7, -4.6 } } },
    order = 26,
    playstyle = "tank",          -- src/config/playstyles.lua
    tip = "Ants touching you get poisoned, so let them come. Hold {secondary} to coil up (85% less damage), let go to burst.",
    radius = 8,
    scale = 1.2,
    stats = { maxHp = 110, armor = 8, moveSpeed = 70, hpRegen = 1.5 },
    attack = { type = "glandspray", damage = 6, cooldown = 0.5, radius = 14, every = 2, poison = { 5, 3 }, reach = 20 },
    secondary = { type = "coil", damage = 40, cooldown = 4, guard = 0.15, radius = 85, ooze = 3, time = 2, max = 3.5 },
    dash = { type = "ballroll", stamina = 2.5, regen = 1, speed = 1.8, damage = 5, knockback = 170, guard = 0.5 },
    anims = { dash = "run" },     -- held while curled up and rolling
    startingItems = {},
    tags = { "myriapod" },
}
