-- Parasite (src/game/parasites.lua). Not the little fungus item: this one has its threads in
-- your brain. It walks you toward the crowd on its own (your stick only nudges), and every
-- attack and every sharp turn bursts a ring of spores.
local Combat = require("src.game.combat")
local Parasites = require("src.game.parasites")
local util = require("src.core.util")

local COL = { 0.95, 0.6, 0.2 }
local PFX = { COL, { 0.85, 0.75, 0.5 } }
local PFX_OPT = { glow = true, grav = -20 }

local function ring(p, w, k)
    local r = 55 * (1 + p.stats:get("area") / 100) * (k or 1)
    local base = (p.attack.params.damage or 10) * 0.8
    Combat.area(w, p.x, p.y, r, base, { knockback = 60, poison = { 5, 2 }, procDepth = 1 })
    w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.35, color = COL })
    w.particles:burst(p.x, p.y, 10, PFX, 60, 40, PFX_OPT)
end

return {
    name = "Cordyceps Puppeteer",
    description = "Every attack and every sharp turn bursts a ring of spores (80% of your hit + poison). +20 Speed. Devours Cordyceps and Mycelium in your bag (+15% Area each).",
    effect = "Attacks and turns burst spore rings.",
    curse = "It walks for you. Your stick only nudges.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 2 },
    stats = { moveSpeed = 20 },
    feeds = { ids = { "cordyceps", "mycelium" }, stats = { area = 15 } },
    procs = {
        { trigger = "onAttack", effect = function(ctx) ring(ctx.player, ctx.world) end },
    },
    -- the fungus walks: heads for the thickest ants nearby (or wanders), turning smoothly
    steer = function(p, wx, wy, mag, dt, it)
        local w = p.world
        if not it.hx then it.hx, it.hy, it.turned, it.look = p.aimX, p.aimY, 0, 0 end
        it.look = it.look - dt
        if it.look <= 0 then
            it.look = 0.3
            local cx, cy = Parasites.crowd(w, p.x, p.y, 260)
            if cx and (cx - p.x) ^ 2 + (cy - p.y) ^ 2 > 30 * 30 then
                it.tx, it.ty = util.normalize(cx - p.x, cy - p.y)
            else
                local a = math.atan2(it.hy, it.hx) + (love.math.random() - 0.5) * 2.4
                it.tx, it.ty = math.cos(a), math.sin(a)
            end
            -- keep off the walls
            local S, m = w.size, 90
            if p.x < m or p.y < m or p.x > S - m or p.y > S - m then
                it.tx, it.ty = util.normalize(S / 2 - p.x, S / 2 - p.y)
            end
        end
        local tx, ty = it.tx + wx * mag * 0.45, it.ty + wy * mag * 0.45
        tx, ty = util.normalize(tx, ty)
        -- turn toward it at a limited rate
        local a0 = math.atan2(it.hy, it.hx)
        local d = math.atan2(ty, tx) - a0
        d = (d + math.pi) % (math.pi * 2) - math.pi
        local step = math.max(-3 * dt, math.min(3 * dt, d))
        local a = a0 + step
        it.hx, it.hy = math.cos(a), math.sin(a)
        -- sharp turning sheds spores: a ring for every ~70 degrees turned
        if Parasites.live(w) then
            it.turned = it.turned + math.abs(step)
            if it.turned >= 1.2 then
                it.turned = 0
                ring(p, w, 0.8)
            end
        end
        return it.hx, it.hy, 1
    end,
    tags = { "poison", "fungus" },
}
