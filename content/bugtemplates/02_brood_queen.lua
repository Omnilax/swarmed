-- KIND: Summoner
-- TEMPLATE: the Brood Queen. Lets her children do the work: mites that hunt, a guard that
-- stays close, and a fresh brood every few kills.
return {
    name = "Brood Queen",
    description = "Never fights alone. Two mites hunt for her and a guard beetle stays at her side. Every 10 kills a fresh brood hatches. Her special lays a nest that keeps hatching helpers.",
    tip = "Stay near your brood. {secondary} lays a nest. Fill the Frenzy meter for a whole swarm.",
    look = "hissing_roach",
    playstyle = "control",
    stats = { maxHp = 85, moveSpeed = 88, damage = -10 },

    pets = { { preset = "mite", count = 2 }, { preset = "guard" } },
    card = { motto = "Many hands make light work.", color = "#e0a060", frame = "web" },

    attack = { name = "Nip", cooldown = 0.5, blocks = { { "arc", radius = 34, degrees = 100, damage = 6, knockback = 40 } } },
    secondary = {
        type = "scripted", name = "Lay Nest", cooldown = 7,
        fire = function(me)
            me.ring({ radius = 18, color = { 1, 0.8, 0.5 } })
            for i = 1, 4 do
                me.after(i * 1.2, function(me2) me2.summon({ count = 2, life = 8, damage = 5, bites = 4, color = { 0.7, 0.5, 0.3 } }) end)
            end
        end,
    },
    hooks = {
        onKill = function(me)
            me.state.k = (me.state.k or 0) + 1
            if me.state.k % 10 == 0 then me.summon({ count = 3, life = 10, damage = 6 }) me.say("Hatch!") end
        end,
    },
    ultimate = { name = "Swarm", color = "#ffb070", blocks = { { "summon", count = 10, damage = 8, life = 12 }, { "ring_fx", radius = 60 } } },
}
