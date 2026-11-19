return {
    effects = { drift = 0.38, note = "Gusts push everyone downwind. Small ants get blown away." },
    name = "Gusty Wind", weight = 8, duration = { 30, 60 }, order = 6, wind = { 90, 14 },
    particles = { kind = "leaf", count = 110, colors = { "#8a5a2a", "#6a4426", "#a07a36", "#5a7a30" }, alpha = 0.9,
        vx = { 20, 60 }, vy = { -10, 20 }, life = { 2.5, 5 }, size = { 2, 3 }, sway = 3, spin = { -6, 6 } },
}
