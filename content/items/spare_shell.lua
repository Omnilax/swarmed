-- A hermit crab's next home, carried along for emergencies. Shore item (src/game/shore.lua).
local ItemFx = require("src.game.itemfx")

local PFX = { { 0.95, 0.82, 0.62 }, { 0.8, 0.6, 0.42 } }

return {
    name = "Spare Shell",
    description = "+5 Armor, +8 Max HP, -6 Speed. Once per wave (+1 per stack), dropping below 35% HP pulls you into the shell: untouchable for 1 second, then +10 Armor for 4 seconds. Crustaceans: +3 Armor more.",
    effect = "Once per wave (+1 per stack), dropping below 35% HP pulls you into the shell: untouchable for 1 second, then +10 Armor for 4 seconds.",
    rarity = "uncommon",
    category = "guard",
    size = { 2, 2 },
    stats = { armor = 5, maxHp = 8, moveSpeed = -6 },
    kin = { tags = { "crustacean" }, stats = { armor = 3 } },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx, stacks)
                local p, s = ctx.player, ItemFx.state(ctx.player, "spare_shell")
                if p.hp <= 0 or p.hp > p.stats:get("maxHp") * 0.35 or (s.used or 0) >= stacks then return end
                s.used = (s.used or 0) + 1
                p.iframes = math.max(p.iframes, 1)
                ItemFx.buff(p, "spare_shell", "armor", 10, 0, 4)
                ctx.world:floatText(p.x, p.y, "SHELL", { 0.95, 0.82, 0.62 }, true)
                ctx.world.particles:burst(p.x, p.y, 10, PFX, 60, 50)
            end,
        },
        { trigger = "onWaveStart", effect = function(ctx) ItemFx.state(ctx.player, "spare_shell").used = 0 end },
    },
    tags = { "defense", "shore" },
}
