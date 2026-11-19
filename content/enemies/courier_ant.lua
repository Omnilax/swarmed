-- Spawned by the "Stop the Courier" mini-goal (content/goals/courier.lua).
return {
    name = "Courier Ant",
    description = "Carries a crumb straight across the arena to the nest and never stops to fight.",
    lore = "Fast runners carry food home along the shortest path they know.",
    tip = "Get in its way: it won't turn aside.",
    sprite = "courier_ant",
    hp = 18, speed = 62, damage = 0, radius = 4, mass = 1.5, scale = 1.15,
    behavior = "courier",
    noElites = true,
    spawn = { weight = 0, minWave = 2 },
    gibs = { "#24150f", "#4a2216", "#e8d090" },
    splat = "#86743a",
    tags = { "ant", "goal" },
}
