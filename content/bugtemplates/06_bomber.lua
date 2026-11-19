-- KIND: Bomber
-- TEMPLATE: the Firebug. Lobs bombs that burst into burning puddles; burning ants spread the
-- fire when they die.
return {
    name = "Firebug",
    description = "Lobs little bombs that burst and set ants alight. Burn stacks up and spreads when a burning ant dies. Its special drops a ring of fire around it.",
    tip = "Aim {attack} where the ants will be. {secondary} for a ring of fire when they get close.",
    look = "bombardier_beetle",
    playstyle = "ranged",
    stats = { maxHp = 70, moveSpeed = 100 },
    statuses = { burn = { name = "Burn", color = "#ff7a30", dps = 5, time = 3, stacks = 3, spread = 28 } },
    effects = { glow = { color = "#ff9040", radius = 50, intensity = 0.5, pulse = 1 }, trail = "fire" },
    hitFx = { number = "#ffa040" },
    soundPack = { death = "boom" },
    card = { motto = "Everything burns.", color = "#ff9040", frame = "plain" },

    attack = {
        type = "scripted", name = "Fire Bomb", cooldown = 0.8, range = 140,
        fire = function(me)
            me.shoot({ arc = true, range = 130, damage = 0, color = { 1, 0.6, 0.2 }, burst = { radius = 28, damage = 10 },
                pool = { radius = 16, life = 2, dps = 4, color = { 1, 0.45, 0.1 } } })
        end,
    },
    secondary = {
        type = "scripted", name = "Ring of Fire", cooldown = 6,
        fire = function(me)
            me.hit({ shape = "ring", radius = 70, inner = 30, damage = 12, status = "burn", knockback = 160, color = { 1, 0.5, 0.2 } })
            for i = 0, 7 do
                local a = me.angle + i * math.pi / 4
                me.pool({ x = me.x + math.cos(a) * 50, y = me.y + math.sin(a) * 50, radius = 14, life = 3, dps = 5, color = { 1, 0.45, 0.1 } })
            end
        end,
    },
    hooks = { onHit = function(me, ev) if math.random() < 0.3 then me.statusArea({ status = "burn", radius = 8, x = ev.x, y = ev.y, fx = false }) end end },
}
