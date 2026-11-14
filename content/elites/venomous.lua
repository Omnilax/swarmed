-- Purple venom: every bite poisons you for a few seconds.
return {
    name = "Venomous",
    description = "Its sting glows violet. Every bite poisons you, dealing damage over a few seconds. Dash away and let it wear off.",
    color = "#b25cff",
    hp = 1.7, damage = 1.1, speed = 1.1, mass = 1.2, scale = 1.2,
    venom = { dps = 1.5, time = 3 },
    params = { shotDamage = 1.2 },
    weight = 9, minWave = 6,
}
