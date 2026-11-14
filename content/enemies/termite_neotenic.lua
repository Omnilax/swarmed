-- Neotenic termite (brood maker): stays back and lays egg clutches that hatch into termites.
return {
    name = "Neotenic Termite",
    family = "termite",
    description = "A brood maker. Waddles around behind the fight laying clutches of eggs that hatch into termites.",
    lore = "If the queen is lost, some workers mature into neotenics: stand-in breeders that keep the colony growing.",
    tip = "Stamp out the egg clutches before they hatch, and chase the layer down when you can.",
    sprite = "termite_neotenic",
    hp = 14,
    speed = 22,
    damage = 1,
    radius = 4.5,
    mass = 2,
    behavior = "termite_brood",
    behaviorParams = { keep = 150, interval = 5, maxClutches = 3, egg = "termite_eggs" },
    swarmShade = 0.15,
    spawn = { weight = 8, minWave = 10, groupSize = 0.12 },
    gibs = { "#dcbc70", "#f0e6d2", "#86602c" },
    splat = "#d8cba0",
    tags = { "termite", "support" },
    elites = {
        aggressive = { params = { interval = 3, maxClutches = 5 }, note = "Lays more clutches, faster." },
    },
}
