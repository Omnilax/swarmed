-- KIND: Berserker
-- TEMPLATE: the Red Mantis. A three-hit combo that ends in a spinning sweep, heavier and
-- faster the angrier it gets.
return {
    name = "Red Mantis",
    description = "Chains its strikes: slash, slash, then a spinning sweep. Every kill makes it angrier and faster, and below half health it hits much harder.",
    tip = "Keep pressing {attack}: the third hit spins. Kills stack up its rage.",
    look = "mantis",
    playstyle = "brawler",
    colors = { hue = 330 },
    stats = { maxHp = 75, moveSpeed = 118, damage = 15, attackSpeed = 10 },
    passives = { rampage = {}, berserk = {} },
    hitFx = { number = "#ff5040", crit = "#ffe060", sparks = { color = "#ff6040", count = 4 } },
    soundPack = { attack = { sound = "swing", pitch = 0.8 } },
    card = { motto = "More.", color = "#ff5040", frame = "bone" },

    attack = { name = "Fury Combo", cooldown = 0.28, combo = { window = 0.7,
        { { "arc", radius = 46, degrees = 120, damage = 9, knockback = 60 } },
        { { "lunge", distance = 18 }, { "arc", radius = 50, degrees = 140, damage = 11, knockback = 80 } },
        function(me)
            me.hit({ shape = "arc", radius = 58, degrees = 50, active = 0.32, sweep = { -3.3, 3.3 }, follow = true,
                damage = 14, knockback = 220, hitstop = 0.05, shake = 0.15 })
            me.cooldown(0.6)                        -- a breath after the finisher
        end,
    } },
    ultimate = { name = "Bloodlust", color = "#ff4030", duration = 0.3, blocks = { { "shake", amount = 0.3 }, { "speed", mul = 1.5, time = 6 } },
        buff = { stats = { damage = 40, attackSpeed = 40 }, time = 6 } },
}
