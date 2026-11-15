return {
    effects = { playerSpeed = 0.88, enemySpeed = 0.78, drift = 0.22, note = "Wind and rain: everything slows and gets blown about." },
    name = "Thunderstorm", weight = 4, duration = { 30, 60 }, order = 4, dim = 0.62, wind = { 70, 6 },
    lightning = true,
    fog = { color = "#6e7890", alpha = 0.16, count = 6, size = { 150, 240 } },
    particles = { kind = "rain", count = 460, max = 1000, colors = { "#c0d0ea", "#e2ecf8" }, alpha = 0.6,
        vx = { 110, 130 }, vy = { 360, 400 }, life = { 0.2, 0.45 }, length = 12 },
}
