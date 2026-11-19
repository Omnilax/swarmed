-- KIND: Sniper
-- TEMPLATE: the Lancer. Keeps its distance: a long thrust that hits hardest at the very tip,
-- a charged piercing shot, and a hop backwards.
return {
    name = "Lancer",
    description = "Fights from as far away as it can. Its thrust deals double at the very tip. Hold right click to charge a shot that goes through a whole line of ants. Shift hops backwards.",
    tip = "Keep ants at the tip of your {attack}. Hold {secondary} and let go to fire.",
    look = "mantis",
    playstyle = "ranged",
    stats = { maxHp = 55, moveSpeed = 112, critChance = 15 },
    hitFx = { number = "#a0e0ff", crit = "#ffffff", sparks = { color = "#a0e0ff", count = 2 } },
    card = { motto = "Reach is everything.", color = "#a0e0ff", frame = "gold" },

    attack = {
        type = "scripted", name = "Long Thrust", cooldown = 0.55, range = 95,
        fire = function(me)
            me.hit({ shape = "box", length = 95, width = 10, damage = 9, knockback = 120, fx = "stab",
                sweet = { from = 0.75, mult = 2, color = "#ffffff", text = "TIP!" } })
        end,
    },
    secondary = {
        type = "scripted", name = "Piercing Shot", cooldown = 2.5, range = 300, charge = 1.2,
        hold = function(me, dt, charge) if charge >= 1 and not me.state.full then me.state.full = true me.ring({ radius = 12 }) end end,
        release = function(me, charge)
            me.state.full = false
            me.shoot({ speed = 420 + charge * 300, range = 200 + charge * 200, damage = 10 + charge * 40, pierce = math.floor(2 + charge * 8),
                size = 2 + charge * 2, color = { 0.7, 0.9, 1 } })
            if charge >= 1 then me.shake(0.12) me.hitstop(0.04) end
        end,
    },
    dash = { type = "scripted", name = "Hop Back", start = function(me) me.lunge(-70) me.shield(0.3) end },
}
