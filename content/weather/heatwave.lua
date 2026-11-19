-- Heatwave: shimmering, sun-baked air. Cold-blooded bugs warm up: everyone moves faster, the
-- ants even more than you.
return {
    name = "Heatwave", weight = 5, duration = { 30, 60 }, order = 9,
    stages = { "backyard", "sandstone_wash", "mown_lawn", "dappled_garden" },
    effects = { playerSpeed = 1.15, enemySpeed = 1.25, note = "Hot ground: everyone speeds up, ants most of all.", color = { 1, 0.7, 0.35 } },
    particles = { kind = "mote", count = 40, colors = { "#fff0c0", "#ffe0a0" }, alpha = 0.35,
        vx = { -4, 4 }, vy = { -18, -8 }, life = { 1.5, 3 }, size = 1, sway = 2 },
}
