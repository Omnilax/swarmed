-- Nasute termite: squirts bursts of sticky glue from a nozzle on its head.
return {
    name = "Nasute Termite",
    family = "termite",
    description = "Keeps its distance and squirts bursts of sticky glue. A hit gums you up, and the glue leaves sticky patches on the floor.",
    lore = "Nasute soldiers have traded their jaws for a squirt gun. The glue tangles up ant legs and smells of turpentine.",
    tip = "Its nozzle beads up with glue just before a burst. Step sideways and stay out of the sticky patches.",
    sprite = "termite_nasute",
    hp = 6,
    speed = 34,
    damage = 1,
    radius = 3.5,
    mass = 1,
    behavior = "termite_nasute",
    behaviorParams = { keep = 105, cooldown = 2.6, windup = 0.45, burst = 3, gap = 0.12, shotSpeed = 165, shotDamage = 2 },
    swarmShade = 0.12,
    spawn = { weight = 14, minWave = 9, groupSize = 0.35 },
    gibs = { "#24160c", "#8a7860", "#f0e8a0" },
    splat = "#d8d494",
    tags = { "termite", "ranged" },
    elites = {
        aggressive = { params = { burst = 5, gap = 0.08, cooldown = 1.8 }, note = "Squirts longer bursts more often." },
    },
}
