-- Red with rage: faster, harder hitting, attacks more often and from further away.
return {
    name = "Aggressive",
    description = "Blood-red and furious. Moves faster, bites harder, and every attack comes sooner, faster and from further away.",
    color = "#ff3a2a",
    safeColor = "#d55e00",
    hp = 1.6, damage = 1.5, speed = 1.35, mass = 1.2, scale = 1.2,
    params = { cooldown = 0.55, windup = 0.7, interval = 0.7, range = 1.25, shotSpeed = 1.5, keep = 1.2,
        dashSpeed = 1.25, dashTime = 1.2, snapDamage = 1.3, leap = 1.2, distance = 1.3, rest = 0.6, fuse = 0.7 },
    weight = 12, minWave = 3,
}
