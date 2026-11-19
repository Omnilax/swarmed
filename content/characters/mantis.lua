return {
    name = "Mantis",
    description = "Strikes with two scything forelegs, left then right, faster than ants can react. Right click snatches ants: hold to munch them for health, let go to fling them.",
    lore = "A mantis strike takes about a twentieth of a second. It can turn its head to look over its shoulder.",
    sprite = "mantis",
    model = { legs = "mantis_legs", body = "mantis_body", height = 3, lift = 4, kneeUp = 1.5 },
    order = 12,
    playstyle = "brawler",          -- src/config/playstyles.lua
    tip = "{secondary} snatches up to three ants: hold it to munch them for health, let go to fling them into the crowd.",
    radius = 7,
    scale = 1.05,
    stats = { maxHp = 30, moveSpeed = 115, critChance = 20, attackSpeed = 25, damage = 10 },
    attack = { type = "slashes", damage = 8, cooldown = 0.65, radius = 44, arc = 1.8, gap = 0.09, knockback = 80, color = { 0.75, 1, 0.5 } },
    secondary = { type = "snatch", damage = 16, cooldown = 3, reach = 52, grabs = 3, bite = 6, heal = 2, munch = 1.6, distance = 110 },
    dash = { type = "leafsway", charges = 2, distance = 58, speed = 1.2, primed = 1.0 },
    startingItems = {},
    tags = { "insect" },
}
