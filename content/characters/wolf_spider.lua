return {
    name = "Wolf Spider",
    description = "Quick and fragile. Pulses venom bursts all around. Right click shakes off the spiderlings riding on its back to hunt ants down. Shift darts away and vanishes into the litter for a moment, so the ants lose track of it.",
    sprite = "wolf_spider",
    model = { legs = "wolf_spider_legs", body = "wolf_spider_body", height = 4, lift = 3, kneeUp = 2.5 },
    order = 2,
    playstyle = "speedster",          -- src/config/playstyles.lua
    tip = "Fragile but quick. {dash} makes you vanish for a moment, so the ants lose track of you. {secondary} sends spiderlings to hunt.",
    radius = 6,
    scale = 0.9,
    stats = { maxHp = 38, moveSpeed = 150, critChance = 10, attackSpeed = 15, dodge = 6 },
    attack = { type = "nova", damage = 6, cooldown = 0.6, radius = 38, knockback = 80, color = { 0.65, 1, 0.5 } },
    secondary = { type = "spiderlings", damage = 4, cooldown = 3, count = 8, bites = 3, speed = 170, life = 4, poison = { 4, 3 } },
    dash = { type = "shadowdash", distance = 90, speed = 1.3, hide = 1.4 },
    -- the low dart before it melts into the litter
    anims = { dash = "dash" },
    startingItems = {},
    tags = { "spider", "arachnid" },
}
