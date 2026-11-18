-- Parasite (src/game/parasites.lua). Lice breed: one more every wave. Each louse makes you
-- twitchier and faster, and the itch gets worse: you keep stopping to scratch.
local Parasites = require("src.game.parasites")
local ItemFx = require("src.game.itemfx")

local MAX = 6

local function apply(p)
    local it = Parasites.find(p.inventory, "head_lice")
    if not it then return end
    local n = it.level or 1
    Parasites.setStats(p, "head_lice", { attackSpeed = 15 * n, moveSpeed = 6 * n })
end

return {
    name = "Head Lice",
    description = "+15% Attack Speed and +6 Speed per louse. They breed: one more louse every wave (up to 6). Devours Feathers in your bag (+6% Attack Speed each).",
    effect = "+Atk Speed per louse. Breeds each wave.",
    curse = "You stop to scratch every few seconds.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    feeds = { ids = { "feather" }, stats = { attackSpeed = 6 } },
    onAdd = function(p) apply(p) end,
    procs = {
        {
            trigger = "onWaveStart",
            effect = function(ctx)
                local it = Parasites.find(ctx.player.inventory, "head_lice")
                if it and (it.level or 1) < MAX then
                    it.level = (it.level or 1) + 1
                    apply(ctx.player)
                    ctx.world:floatText(ctx.player.x, ctx.player.y - 16, "the lice breed: " .. it.level, { 1, 0.85, 0.7 }, false)
                end
            end,
        },
        {
            trigger = "onTick",
            effect = function(ctx)
                local p, w = ctx.player, ctx.world
                if not Parasites.live(w) then return end
                local it = Parasites.find(p.inventory, "head_lice")
                local n = it and it.level or 1
                local s = ItemFx.state(p, "head_lice")
                s.itch = (s.itch or 6) - ctx.dt
                if s.itch <= 0 then
                    s.itch = math.max(3, 10 - 1.4 * (n - 1)) * (0.8 + love.math.random() * 0.4)
                    p:stun(0.45)
                    w:floatText(p.x, p.y - 16, "scratch scratch", { 1, 0.85, 0.7 }, false)
                end
            end,
        },
    },
    tags = { "offense", "mobility" },
}
