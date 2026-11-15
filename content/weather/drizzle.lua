return {
    effects = { playerSpeed = 0.96, enemySpeed = 0.92, note = "Damp: the ants slow down a little." },
    name = "Drizzle", weight = 10, duration = { 35, 70 }, order = 2, dim = 0.92, wind = { 10, 0 },
    particles = { kind = "rain", count = 110, colors = { "#d0deee" }, alpha = 0.4,
        vx = { 20, 30 }, vy = { 170, 200 }, life = { 0.3, 0.7 }, length = 5 },
}
