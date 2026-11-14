-- Only where a stage asks for it (desert stages list `dust` in their `weather` odds).
return {
    name = "Dust Wind", weight = 0, duration = { 40, 80 }, order = 10, dim = 0.88, wind = { 110, 10 },
    fog = { color = "#d8b884", alpha = 0.2, count = 7, size = { 120, 220 } },
    particles = { kind = "mote", count = 160, colors = { "#d8b884", "#c8a070", "#e8d0a4" }, alpha = 0.55,
        vx = { 30, 70 }, vy = { -6, 10 }, life = { 1, 2.5 }, size = { 1, 1.5 } },
}
