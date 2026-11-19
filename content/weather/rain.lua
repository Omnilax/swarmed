return {
    effects = { playerSpeed = 0.9, enemySpeed = 0.82, note = "Wet ground: everyone moves slower, ants most of all." },
    name = "Rain", weight = 9, duration = { 35, 70 }, order = 3, dim = 0.8, wind = { 30, 0 },
    fog = { color = "#8a96aa", alpha = 0.12, count = 5, size = { 140, 220 } },
    particles = { kind = "rain", count = 380, max = 900, colors = { "#c4d6ee", "#e2ecf8" }, alpha = 0.55,
        vx = { 50, 60 }, vy = { 300, 340 }, life = { 0.25, 0.55 }, length = 10 },
}
