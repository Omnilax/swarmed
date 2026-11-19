-- Madagascar hissing cockroach: nothing sticks to it. Immune to every debuff (poison, slows,
-- stuns, blinding, resin), quick on its feet, and its hiss stuns whole crowds.
return {
    name = "Hissing Roach",
    description = "Immune to all debuffs: venom, slows, stuns and blinding all slide off. Fast headbutts shove ants back (every 4th sends them flying). Hold the special to draw a breath, let go to HISS and stun everything around. Three quick scurries that startle the ants you bolt from and leave you running faster.",
    lore = "It hisses by forcing air out of the breathing holes along its sides; males hiss to fight over territory. It can survive a month without food.",
    sprite = "hissing_roach",
    model = { legs = "hissing_roach_legs", body = "hissing_roach_body", height = 5, lift = 2, stride = 1.8 },
    order = 21,
    playstyle = "brawler",          -- src/config/playstyles.lua
    tip = "Nothing slows, poisons or stuns you. Hold {secondary} to draw a breath: the longer you hold it, the wider the hiss stuns.",
    radius = 9,
    scale = 1.15,
    immune = true,
    stats = { maxHp = 80, armor = 2, moveSpeed = 140, hpRegen = 1 },
    attack = { type = "headbutt", damage = 9, cooldown = 0.38, reach = 28, arc = 1.7, knockback = 180, heavyEvery = 4, color = { 1, 0.75, 0.45 } },
    secondary = { type = "hiss", damage = 3, cooldown = 4, radius = 50, maxRadius = 115, stun = 0.8, maxStun = 2.6, charge = 1 },
    dash = { type = "scurry", distance = 60, speed = 1.3, charges = 3, startle = 0.4, burst = 1.35, burstTime = 0.6 },
    anims = {
        attack = { time = 0.25, keys = { { 0 }, { 0.3, rear = -1, lunge = -2 }, { 0.5, lunge = 5, rear = 1, stretch = 0.1 }, { 1 } } },
        -- swelling up with air while the breath is held, then the body jolts with the hiss
        secondary = { time = 0.6, holdAt = 0.4, hold = function(p) return p.hissing ~= nil end, keys = {
            { 0 }, { 0.4, stretch = -0.12, rear = 2, spread = 0.3, shake = 0.4 }, { 0.55, stretch = 0.2, rear = -1, lunge = -2, shake = 1.2 }, { 1 } } },
        dash = { time = 0.22, keys = { { 0, stretch = 0.18, rear = -1.2, spread = 0.2, shake = 0.3 }, { 0.7, stretch = 0.1 }, { 1 } } },
    },
    startingItems = {},
    tags = { "insect" },
}
