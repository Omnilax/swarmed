-- Cursed: a wasp larva grows inside you. Each wave it makes you stronger and eats a little
-- more of you. The growth is kept for the run (world.economy.growth), so it survives saves.
local function apply(player)
    local w = player.world
    local n = w and w.economy and w.economy.growth and w.economy.growth.parasitoid_egg or 0
    player.stats:removeSource("fx:parasitoid_egg")
    if n > 0 then
        player.stats:addModifier("fx:parasitoid_egg", "damage", 6 * n, 0)
        player.stats:addModifier("fx:parasitoid_egg", "maxHp", -3 * n, 0)
    end
end

return {
    name = "Parasitoid Egg",
    description = "Every wave start: +6% Damage for the rest of the run (per stack). Cursed: and -3 Max HP each time.",
    effect = "Every wave start: +6% Damage for the rest of the run (per stack).",
    curse = "-3 Max HP at every wave start (per stack), for the rest of the run.",
    rarity = "cursed",
    category = "cursed",
    shape = { "X.", "XX" },
    onAdd = function(player) apply(player) end,
    procs = {
        {
            trigger = "onWaveStart",
            effect = function(ctx, stacks)
                local Economy = require("src.game.economy")
                local g = Economy.state(ctx.world).growth
                g.parasitoid_egg = (g.parasitoid_egg or 0) + stacks
                apply(ctx.player)
                local p = ctx.player
                p.hp = math.min(p.hp, p.stats:get("maxHp"))
                ctx.world:floatText(p.x, p.y - 10, "IT GROWS", { 0.75, 0.45, 1 }, true)
            end,
        },
    },
    tags = { "cursed", "offense", "bug" },
}
