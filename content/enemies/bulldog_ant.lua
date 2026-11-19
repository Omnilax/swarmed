-- Bulldog ant: watches with huge eyes and rushes you when you turn your back.
return {
    name = "Bulldog Ant",
    description = "Hangs back and watches you with enormous eyes. The moment you turn your back it rushes in, and its sting is venomous.",
    lore = "Australian bulldog ants can see an intruder a metre away and will chase it down, stinging again and again.",
    tip = "Keep facing them and they hesitate. Hit one mid-rush to stagger it for a counter. Its bites crack your armor.",
    sprite = "bulldog_ant",
    hp = 12,
    speed = 48,
    damage = 5,
    shred = { armor = 2, time = 4, max = 10 },   -- bites crack your armor (src/config/defense.lua)
    radius = 4.5,
    mass = 1.6,
    behavior = "stalker",
    behaviorParams = { keep = 80, watch = 0.3, rush = 2.7, rushTime = 0.9, cooldown = 1.3 },
    venom = { dps = 2, time = 2.5 },
    biteRate = 0.7,
    swarmShade = 0.15,
    spawn = { weight = 12, minWave = 5, groupSize = 0.25 },
    gibs = { "#1a1010", "#c03a1a", "#f0d070" },
    splat = "#8a6a30",
    tags = { "ant", "venom" },
    elites = { aggressive = { params = { watch = 0.1, rush = 3.2 }, note = "Barely waits before it pounces." } },
}
