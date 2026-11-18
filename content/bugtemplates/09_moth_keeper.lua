-- KIND: Pet master
-- TEMPLATE: the Moth Keeper. A little zoo: moths that circle it and burn what they touch, a
-- spitter that shoots, and an ultimate that sends everything in at once.
return {
    name = "Moth Keeper",
    description = "Two moon moths circle it, singeing every ant they brush, and a spitter beetle shoots from its side. Its special calls them all closer for a burst of speed.",
    tip = "Walk into the ants: your moths do the damage. Fill the Frenzy meter to burn everything around you.",
    look = "orb_weaver",
    playstyle = "control",
    stats = { maxHp = 80, moveSpeed = 104, damage = -15 },
    statuses = { burn = { preset = "burn" } },
    pets = {
        { preset = "moth", count = 3, status = "burn", range = 40 },
        { preset = "spitter" },
    },
    card = { motto = "They do the work.", color = "#f0e0a0", frame = "web" },

    attack = { name = "Swat", cooldown = 0.6, blocks = { { "arc", radius = 34, degrees = 120, damage = 6 } } },
    secondary = {
        type = "scripted", name = "Call", cooldown = 8,
        fire = function(me)
            me.addPet(1)
            me.speed(1.4, 3)
            me.say("To me!")
        end,
    },
    ultimate = { name = "Moth Storm", color = "#ffe080", blocks = { { "status", radius = 140, status = "burn" }, { "ring_fx", radius = 140 } } },
}
