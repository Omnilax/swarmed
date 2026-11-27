-- Velvet worm: a soft, slow, wriggling hunter that slows the swarm down and outlasts it. A long
-- chain body (like the millipede's) with a big wormy ripple (model.ripple), a simple bite, two
-- jets of glue that slow every ant they touch, and a slime line that reels it backwards out of
-- trouble with a little heal. Innate procs (def.procs, run by src/game/skills.lua):
--   * ants that bite it get poisoned by the slime on its skin (every ant touching the body);
--   * ants that die while slowed burst in a splash of glue that hurts everything around.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local GLUE = { 0.95, 0.88, 0.6 }

return {
    name = "Velvet Worm",
    description = "Slow, soft and wriggly, it wins by gluing the swarm down and outlasting it. Ants that bite it get poisoned. A simple bite up front; right click squirts two strings of slime that slow every ant they touch. Shift shoots a slime line behind you and reels you back along it, healing a little. Slowed ants burst when they die, splashing everything around.",
    lore = "Velvet worms catch prey by spraying two jets of sticky slime from their head. They've barely changed in 500 million years.",
    sprite = "velvet_worm",
    model = { kind = "chain", legs = "velvet_worm_legs", head = "velvet_worm_head", segment = "velvet_worm_seg", segment2 = "velvet_worm_seg2",
        segments = 14, spacing = 2.6, height = 3, lift = 1, legColor = "#6a3a48", wave = 0.12,
        ripple = 4, rippleSpeed = 40, rippleLen = 0.55, rippleIdle = 0.3, squirm = 0.08,   -- a big, slow wriggle that never stops (src/game/world.lua)
        leg = { { 0, -2, -0.3, -3.2, -0.6, -4.1 } } },
    order = 28,
    playstyle = "control",          -- src/config/playstyles.lua
    tip = "Slow ants first: {secondary} glues a whole line. Slowed ants burst when they die. {dash} pulls you back out of trouble and heals you.",
    radius = 7,
    scale = 1.1,
    stats = { maxHp = 85, armor = 1, moveSpeed = 58, hpRegen = 1 },
    attack = { type = "wormbite", damage = 9, cooldown = 0.45, reach = 18, radius = 12, knockback = 40, color = { 1, 0.75, 0.6 } },
    secondary = { type = "slimestring", damage = 3, cooldown = 1.8, range = 170, speed = 340, slow = { 0.35, 3 }, jets = 2, gap = 0.08 },
    dash = { type = "slimeline", distance = 95, speed = 1.05, heal = 5, charges = 1, regen = 0.3 },
    -- innate: payback poison and bursting slowed ants (see the top of this file)
    poisonSkin = { dps = 4, time = 3, reach = 10 },
    burst = { radius = 30, damage = 12 },
    procs = {
        { trigger = "onHurt", effect = function(ctx)
            local p, w = ctx.player, ctx.world
            local ps = p.def.poisonSkin
            local function dose(x, y)
                for _, e in ipairs(Combat.collect(w, x, y, ps.reach)) do fx.poison(e, ps.dps, ps.time) end
            end
            dose(p.x, p.y)
            for i, s in ipairs(p.chain or {}) do if i % 3 == 0 then dose(s.x, s.y) end end
        end },
        { trigger = "onKill", effect = function(ctx)
            local e = ctx.target
            if not e or (e.slowT or 0) <= 0 then return end
            local b = ctx.player.def.burst
            fx.explode(ctx, ctx.x, ctx.y, b.radius, b.damage, GLUE)
        end },
    },
    anims = {
        attack = { time = 0.26, keys = { { 0, rear = 1, lunge = -1 }, { 0.4, lunge = 4, stretch = 0.15 }, { 1 } } },
        secondary = { time = 0.4, keys = { { 0 }, { 0.3, rear = 3, lunge = -1.5 }, { 0.5, rear = 1, lunge = 2, stretch = 0.1 }, { 1 } } },
        dash = { time = 0.35, keys = { { 0, rear = -1, stretch = -0.15 }, { 0.5, stretch = 0.2 }, { 1 } } },
    },
    startingItems = {},
    tags = { "myriapod" },
}
