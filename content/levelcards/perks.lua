-- Perk cards: a lasting effect for the rest of the run. Taking the same perk again ranks it up
-- (maxRank), and its power is the sum of the rarity rolls it was taken with (common 1 ..
-- legendary 2), so a legendary rank 1 is as strong as two commons. text(power) describes it at
-- the power you would have after taking the card. Procs work like item procs
-- (content/items/_template.lua): effect(ctx, power, state, levelups); state is a scratch table.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

local function r(v) return math.floor(v + 0.5) end
local function r1(v) return math.floor(v * 10 + 0.5) / 10 end
local function deeper(ctx) return { procDepth = (ctx.procDepth or 0) + 1 } end

return {
    {
        id = "venom_glands", name = "Venom Glands", family = "perk", weight = 6, maxRank = 3,
        text = function(pw) return ("%d%% of your hits poison the ant: %s damage a second for 3 s"):format(r(math.min(40, 15 * pw)), r1(3 * pw)) end,
        procs = { { trigger = "onHit", chance = function(pw) return math.min(0.4, 0.15 * pw) end,
            effect = function(ctx, pw)
                local e = ctx.target
                if not e or e.dead or e.isProp then return end
                e.poisonT = math.max(e.poisonT or 0, 3)
                e.poisonDps = math.max(e.poisonDps or 0, 3 * pw)
                e.poisonSrc = "Venom Glands"
            end } },
    },
    {
        id = "static_antennae", name = "Static Antennae", family = "perk", weight = 5, maxRank = 3,
        text = function(pw) return ("Every 10th hit zaps %d ants nearby for %d damage"):format(2 + math.floor(pw), r(7 * pw)) end,
        procs = { { trigger = "onHit",
            effect = function(ctx, pw, st)
                st.n = (st.n or 0) + 1
                if st.n < 10 or not ctx.target then return end
                st.n = 0
                local o = deeper(ctx)
                o.color = { 0.6, 0.9, 1 }
                Combat.chain(ctx.world, ctx.target, 2 + math.floor(pw), 90, 7 * pw, o)
            end } },
    },
    {
        id = "popping_corpses", name = "Popping Corpses", family = "perk", weight = 5, maxRank = 3, minLevel = 3,
        text = function(pw) return ("%d%% of kills burst, hitting ants around them for %d"):format(r(math.min(30, 8 * pw)), r(8 * pw)) end,
        procs = { { trigger = "onKill", chance = function(pw) return math.min(0.3, 0.08 * pw) end,
            effect = function(ctx, pw)
                local w = ctx.world
                w:addFx({ kind = "ring", x = ctx.x, y = ctx.y, r = 40, life = 0.25, color = { 0.75, 1, 0.45 } })
                w.particles:burst(ctx.x, ctx.y, 6, { { 0.7, 0.95, 0.4 }, { 0.45, 0.7, 0.25 } }, 90, 60)
                local o = deeper(ctx)
                o.knockback = 80
                Combat.area(w, ctx.x, ctx.y, 40, 8 * pw, o)
            end } },
    },
    {
        id = "bloodlust", name = "Bloodlust", family = "perk", weight = 5, maxRank = 3,
        text = function(pw) return ("Each kill gives +%s%% Damage for 3 s, stacking up to 10 times"):format(r1(1.5 * pw)) end,
        procs = { { trigger = "onKill",
            effect = function(ctx, pw, st)
                local now = ctx.world.time
                st.stacks = (st.t and st.t > now) and math.min(10, st.stacks + 1) or 1
                st.t = now + 3
                ItemFx.buff(ctx.player, "lu_bloodlust", "damage", st.stacks * 1.5 * pw, 0, 3)
            end } },
    },
    {
        id = "adrenaline", name = "Adrenaline", family = "perk", weight = 5, maxRank = 3,
        text = function(pw) return ("Getting bitten gives +%d%% Speed and +%d%% Attack Speed for 3 s (every 6 s at most)"):format(r(15 * pw), r(15 * pw)) end,
        procs = { { trigger = "onHurt", cooldown = 6,
            effect = function(ctx, pw)
                local p = ctx.player
                ItemFx.buff(p, "lu_adren_speed", "moveSpeed", 0, 0.15 * pw, 3)
                ItemFx.buff(p, "lu_adren_atk", "attackSpeed", 15 * pw, 0, 3)
                ctx.world:floatText(p.x, p.y - 14, "adrenaline!", { 1, 0.5, 0.35 })
            end } },
    },
    {
        id = "spiny_back", name = "Spiny Back", family = "perk", weight = 5, maxRank = 3,
        text = function(pw) return ("When an ant bites you, spines hit every ant touching you for %d"):format(r(5 * pw)) end,
        procs = { { trigger = "onHurt", cooldown = 0.4,
            effect = function(ctx, pw)
                local p = ctx.player
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 34, life = 0.18, color = { 0.95, 0.85, 0.6 } })
                Combat.area(ctx.world, p.x, p.y, 34, 5 * pw, { procDepth = 1, knockback = 90 })
            end } },
    },
    {
        id = "dust_kick", name = "Dust Kick", family = "perk", weight = 5, maxRank = 3,
        text = function(pw) return ("Dashing kicks up dust that hits ants around you for %d and shoves them away"):format(r(6 * pw)) end,
        procs = { { trigger = "onDash", cooldown = 0.3,
            effect = function(ctx, pw)
                local p, w = ctx.player, ctx.world
                w:addFx({ kind = "ring", x = p.x, y = p.y, r = 48, life = 0.3, color = { 0.85, 0.72, 0.5 } })
                w.particles:burst(p.x, p.y, 8, { { 0.8, 0.7, 0.5 }, { 0.6, 0.5, 0.35 } }, 110, 40)
                Combat.area(w, p.x, p.y, 48, 6 * pw, { procDepth = 1, knockback = 170 })
            end } },
    },
    {
        id = "riposte", name = "Riposte", family = "perk", weight = 4, maxRank = 3, minLevel = 3,
        text = function(pw) return ("Dodging or blocking a bite strikes back at every ant near you for %d"):format(r(10 * pw)) end,
        procs = {
            { trigger = "onDodge", cooldown = 0.8, effect = function(ctx, pw)
                local p = ctx.player
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 55, life = 0.25, color = { 0.7, 0.9, 1 } })
                Combat.area(ctx.world, p.x, p.y, 55, 10 * pw, { procDepth = 1, knockback = 120 })
            end },
            { trigger = "onBlock", cooldown = 0.8, effect = function(ctx, pw)
                local p = ctx.player
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 55, life = 0.25, color = { 0.7, 0.9, 1 } })
                Combat.area(ctx.world, p.x, p.y, 55, 10 * pw, { procDepth = 1, knockback = 120 })
            end },
        },
    },
    {
        id = "finishing_bite", name = "Finishing Bite", family = "perk", weight = 4, maxRank = 3, minLevel = 5,
        text = function(pw) return ("Hits finish off ants left under %d%% health (not bosses)"):format(r(math.min(25, 8 * pw))) end,
        procs = { { trigger = "onHit",
            effect = function(ctx, pw)
                local e = ctx.target
                if not e or e.dead or e.isProp or e.hp <= 0 or not e.maxHp then return end
                if e.def.boss or e.def.hazard then return end
                if e.hp <= e.maxHp * math.min(0.25, 0.08 * pw) then
                    Combat.damage(ctx.world, e, e.hp * 3 + 10, { procDepth = (ctx.procDepth or 0) + 1, noCrit = true })
                end
            end } },
    },
    {
        id = "acrid_trail", name = "Acrid Trail", family = "perk", weight = 4, maxRank = 3, minLevel = 4,
        text = function(pw) return ("Walking leaves a stinging trail: ants in it take %s damage a second and slow down"):format(r1(4 * pw)) end,
        procs = { { trigger = "onTick",
            effect = function(ctx, pw, st)
                local p = ctx.player
                local moving = (p.vx or 0) ^ 2 + (p.vy or 0) ^ 2 > 400
                st.clock = (st.clock or 0) + (ctx.dt or 0)
                if st.clock < 0.45 then return end
                st.clock = 0
                if not moving then return end
                ItemFx.patch(ctx.world, { x = p.x, y = p.y, r = 18, life = 2.5, dps = 4 * pw, slow = 0.7,
                    color = { 0.6, 0.85, 0.3 } })
            end } },
    },
    {
        id = "nectar_nose", name = "Nectar Nose", family = "perk", weight = 4, maxRank = 3,
        text = function(pw) return ("%d%% of kills drop an extra nectar bead"):format(r(math.min(25, 6 * pw))) end,
        procs = { { trigger = "onKill", chance = function(pw) return math.min(0.25, 0.06 * pw) end,
            effect = function(ctx)
                if ctx.world.beads then ctx.world.beads:drop(ctx.x + 4, ctx.y + 3, 1) end
            end } },
    },
    {
        id = "wave_feast", name = "Wave Feast", family = "perk", weight = 5, maxRank = 3,
        text = function(pw) return ("Heal %d%% of your Max HP at the start of every wave"):format(r(math.min(60, 12 * pw))) end,
        procs = { { trigger = "onWaveStart",
            effect = function(ctx, pw)
                local p = ctx.player
                local hp = p.stats:get("maxHp") * math.min(0.6, 0.12 * pw)
                p:heal(hp)
                ctx.world:floatText(p.x, p.y - 14, "+" .. math.floor(hp + 0.5) .. " HP", { 0.5, 1, 0.5 })
            end } },
    },
    {
        id = "molt_reserve", name = "Molt Reserve", family = "perk", weight = 2, maxRank = 1, minLevel = 8,
        text = function(pw) return ("Once this run, a killing bite makes you molt instead: back up with %d%% HP"):format(r(math.min(80, 30 * pw))) end,
        saveFromDeath = function(p, pw, world)
            p.hp = p.stats:get("maxHp") * math.min(0.8, 0.3 * pw)
            p.iframes = math.max(p.iframes or 0, 2)
            world:addFx({ kind = "ring", x = p.x, y = p.y, r = 90, life = 0.6, color = { 0.5, 1, 0.85 } })
            world:addFx({ kind = "ring", x = p.x, y = p.y, r = 50, life = 0.4, color = { 1, 1, 1 } })
            world:floatText(p.x, p.y - 18, "MOLTED!", { 0.5, 1, 0.85 }, true)
            Combat.area(world, p.x, p.y, 90, 0, { knockback = 260, noCrit = true })
            require("src.core.audio").play("level_up", { pitch = 0.7 })
        end,
    },
}
