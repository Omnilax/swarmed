-- Parasite (src/game/parasites.lua). A long worm coiled inside you, like the ones that ride
-- crickets: an extra joint that whips out after every attack. It craves water, though, and now
-- and then it takes the wheel and drags you off somewhere.
local Combat = require("src.game.combat")
local Parasites = require("src.game.parasites")

local COL = { 0.85, 0.7, 0.45 }

return {
    name = "Horsehair Worm",
    description = "An extra joint: every attack cracks a long whip straight ahead (70% of your hit, pierces). Devours Grasshopper Legs and Strider Legs in your bag (+10% Area each).",
    effect = "Attacks crack a long whip ahead.",
    curse = "Every 9 s it drags you off for 1.5 s.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 2 },
    stats = { area = 10 },
    feeds = { ids = { "grasshopper_legs", "strider_legs" }, stats = { area = 10 } },
    procs = {
        {
            trigger = "onAttack",
            effect = function(ctx)
                local p, w = ctx.player, ctx.world
                local ax, ay = ctx.ax or p.aimX, ctx.ay or p.aimY
                p:after(0.12, function()
                    if p.dead then return end
                    local len = 105 * (1 + p.stats:get("area") / 100)
                    local x2, y2 = p.x + ax * len, p.y + ay * len
                    local base = (p.attack.params.damage or 10) * 0.7
                    for _, e in ipairs(Combat.collectLine(w, p.x, p.y, x2, y2, 6)) do
                        Combat.damage(w, e, base, { knockback = 90, kbx = ax, kby = ay, procDepth = ctx.procDepth + 1 })
                    end
                    w:addFx({ kind = "stab", x = p.x, y = p.y, x2 = x2, y2 = y2, w = 3, z = 4, life = 0.18, color = COL })
                end)
            end,
        },
    },
    -- the pull: every 9 s (while a wave is on) it drags you off in one direction for 1.5 s
    steer = function(p, wx, wy, mag, dt, it)
        if not Parasites.live(p.world) then it.pullT = nil return wx, wy, mag end
        it.pullCD = (it.pullCD or 9) - dt
        if it.pullCD <= 0 then
            it.pullCD, it.pullT = 9, 1.5
            local a = love.math.random() * math.pi * 2
            it.px, it.py = math.cos(a), math.sin(a)
            p.world:floatText(p.x, p.y - 16, "the worm pulls!", COL, false)
        end
        if it.pullT and it.pullT > 0 then
            it.pullT = it.pullT - dt
            -- the stick can fight it a little
            local x, y = it.px + wx * mag * 0.3, it.py + wy * mag * 0.3
            local l = math.sqrt(x * x + y * y) + 1e-6
            return x / l, y / l, 1
        end
        return wx, wy, mag
    end,
    tags = { "offense" },
}
