return {
    name = "Stink Bug",
    description = "Fights with its stench. Sprays thick clouds that poison ants, slow them and make them take extra damage. Right click squirts an acid pool that burns, walls ants off and steams up a cloud. Shift clamps down under its shield, blasts the ants away and leaves a ring of clouds.",
    lore = "A stink bug's smell comes from glands on its thorax. Other stink bugs use the same scent to gather.",
    sprite = "stink_bug",
    model = { legs = "stink_bug_legs", body = "stink_bug_body", height = 3, lift = 2 },
    order = 19,
    radius = 8,
    stats = { maxHp = 65, armor = 4, moveSpeed = 95 },
    attack = { type = "stinkcloud", damage = 5, cooldown = 0.7, range = 40, radius = 22, life = 2.6, drift = 14, max = 8, weaken = 1.25, choke = 0.7 },
    secondary = { type = "acidpool", damage = 10, cooldown = 3, range = 130, radius = 34, life = 6, max = 3 },
    dash = { type = "stinkshield", time = 1.6, radius = 30, damage = 6 },
    anims = {
        -- the stink glands fire: the body clenches and puffs up
        attack = { time = 0.3, keys = { { 0 }, { 0.3, stretch = -0.12, rear = -1, spread = 0.2 }, { 0.5, stretch = 0.08, rear = 1, shake = 0.5 }, { 1 } } },
        secondary = { time = 0.35, keys = { { 0 }, { 0.3, rear = 2, lunge = -2 }, { 0.5, lunge = 3, stretch = 0.1 }, { 1 } } },
        dash = { time = 1.6, keys = { { 0 }, { 0.08, rear = -3, spread = 0.45, stretch = -0.1, shake = 1 }, { 0.85, rear = -2.5, spread = 0.4 }, { 1 } } },
    },
    startingItems = {},
    tags = { "insect", "true bug" },
}
