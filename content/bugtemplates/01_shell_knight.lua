-- KIND: Tank
-- TEMPLATE: the Shell Knight. A walking fortress: huge health and armour, a slow slam that
-- knocks ants flying (with a freeze-frame when it lands), and Shift raises its shell to block.
-- Bug Creator > Template Gallery. Change anything, press Save to make it yours.
return {
    name = "Shell Knight",
    description = "A walking fortress. Its slam is slow but sends ants flying, and every hit it lands weakens them. Hold Shift to raise its shell and block everything.",
    tip = "{attack} slams the ground ahead. Hold {dash} to block: ants that hit the shell bounce off.",
    look = "hermit_crab",
    playstyle = "tank",
    scale = 1.25,
    stats = { maxHp = 160, armor = 8, moveSpeed = 70, hpRegen = 1 },

    statuses = { weaken = { preset = "weaken", onHit = 0.35 } },        -- weakened ants hit softer
    passives = { shell = {} },
    hitFx = { number = "#ffd070", sparks = { color = "#ffd070", count = 4 } },
    card = { motto = "Nothing gets through.", color = "#ffd070", frame = "shell" },

    attack = {
        type = "scripted", name = "Shell Slam", cooldown = 1.1, range = 60,
        fire = function(me)
            me.root(0.25)                          -- plants its feet
            me.hit({ shape = "box", length = 60, width = 44, ahead = 6, damage = 26, knockback = 420,
                windup = 0.22, hitstop = 0.06, shake = 0.2, kb = "aim", sweet = { from = 0.7, mult = 1.4, text = "CRUNCH" } })
        end,
    },
    dash = {
        type = "scripted", name = "Shell Up",
        hold = function(me, dt, held)
            me.block(held, 220)
            me.speed(held and 0.35 or 1, 0.1)
        end,
    },
    ultimate = { name = "Earthquake", color = "#ffb050", duration = 0.6,
        blocks = { { "shake", amount = 0.4 }, { "ring", radius = 140, inner = 0, damage = 50, knockback = 500 }, { "shield", time = 2 } } },
}
