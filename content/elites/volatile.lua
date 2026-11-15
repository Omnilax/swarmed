-- Swollen with acid: bursts into a ring of burning globs when it dies.
return {
    name = "Volatile",
    description = "Swollen with boiling acid. When it dies it bursts into a ring of burning globs, so don't stand next to it when it pops.",
    color = "#ff9a1e",
    safeColor = "#e69f00",
    hp = 1.5, damage = 1.2, speed = 1.05, scale = 1.25,
    weight = 6, minWave = 7,
    onDeath = function(world, x, y, e)
        local n = 6
        for i = 1, n do
            local a = i / n * math.pi * 2
            world.hazards:shoot({ x = x, y = y, vx = math.cos(a) * 95, vy = math.sin(a) * 95, vz = 60, r = 3,
                damage = 3, life = 1.1, color = { 1, 0.55, 0.15 }, splat = true })
        end
        world.particles:burst(x, y, 10, { { 1, 0.7, 0.2 }, { 1, 0.4, 0.1 } }, 110, 80, { glow = true })
        require("src.core.audio").play("boom", { pitch = 1.4 })
    end,
}
