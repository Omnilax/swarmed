return {
    name = "Tiger Beetle",
    description = "One of the fastest runners on Earth. Hold left click to wind up a charge dash that tears through the crowd. Right click: a quick sprint strike. Hold Shift to run, clipping ants aside.",
    lore = "It runs so fast its eyes can't keep up: it has to stop now and then to see where its prey went.",
    sprite = "tiger_beetle",
    model = { legs = "tiger_beetle_legs", body = "tiger_beetle_body", height = 3, lift = 3 },
    order = 4,
    playstyle = "speedster",          -- src/config/playstyles.lua
    tip = "Hold {attack} to wind up a charge that tears through a line of ants. Hold {dash} to sprint, clipping ants aside.",
    radius = 5,
    scale = 0.85,
    stats = { maxHp = 35, moveSpeed = 175, dashCooldown = 0.8, critChance = 10 },
    attack = { type = "chargedash", damage = 14, cooldown = 0.55, charge = 0.75, distance = 50, maxDistance = 150, width = 9,
        maxMult = 3, knockback = 160, guard = 0.35, crawl = 0.45, color = { 0.6, 1, 0.7 } },
    secondary = { type = "lunge", damage = 11, cooldown = 1.1, distance = 60, width = 8, knockback = 110, color = { 0.6, 1, 0.7 } },
    dash = { type = "run", stamina = 2.4, regen = 1, speed = 1.6, ram = 3, knockback = 130 },
    startingItems = {},
    tags = { "beetle", "insect", "fast" },
}
