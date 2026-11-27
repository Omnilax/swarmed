-- ===========================================================================================
--  EXAMPLE CUSTOM BUG: the Gunner Beetle (Bug Creator round 4)
--  Shows the round 4 systems in one bug: ammo and a rage meter (resources), two stances,
--  extra buttons (abilities), an evolution that grows horns and claws as it levels, named
--  code passives (traits), and reading the game (facing, the cursor, sprees, waves...).
--  Import it: Bug Creator > Example: Gunner Beetle. Reference: docs/BUG_API.md.
-- ===========================================================================================

local PAL = {
    o = "#14100cb0",   -- outline
    a = "#2c3a48",     -- dark shell
    b = "#46607a",
    c = "#6c8eae",     -- highlight
    d = "#b8d0e8",     -- shine
    e = "#0a0806",     -- eyes
    m = "#c89040",     -- brass gun barrels
}

local BODY = {
    "....oooooo....",
    "..oobbbbbbooo.",
    ".oabbccccbbmmo",
    "oabbccddcceemo",
    "oabbccddcceemo",
    ".oabbccccbbmmo",
    "..oobbbbbbooo.",
    "....oooooo....",
}

local BRASS = { 0.95, 0.75, 0.35 }

return {
    name = "Gunner Beetle",
    description = "A beetle with a gun in its jaws. Shoots six-shot bursts, then reloads. Press R to put the gun away and brawl. Levels grow it horns, then claws, then a cannon.",
    tip = "{attack} shoots while you have ammo (F reloads early). R switches Gun / Brawl stance. G parries. Kill fast to fill Rage.",
    playstyle = "ranged",
    tags = { "beetle" },

    art = {
        palette = PAL,
        body = BODY,
        legs = { { 3, -2, 5, -6, 8, -8 }, { 0, -2, 0, -7, -1, -10 }, { -3, -2, -6, -6, -9, -8 } },
        legColor = "#2c3a48",
        height = 3, lift = 3, kneeUp = 2, stride = 2,
    },
    stats = { maxHp = 70, moveSpeed = 105, armor = 2 },

    -- RESOURCES: numbers the bug keeps, shown under the stamina bar. me.spend / me.gain /
    -- me.res / me.reload use them.
    resources = {
        ammo = { max = 6, reload = 1.1, color = "#e8b048", label = "Ammo" },        -- pips
        rage = { max = 100, start = 0, regen = -4, color = "#e05030", label = "Rage", show = "bar" },
    },

    -- STANCES: R cycles them (stanceSwitch = "code" leaves it to me.stance). Moves read
    -- me.stanceName to act differently; a stance can also bring its own attack / art.
    stances = {
        { name = "Gun", color = "#e8b048", speed = 0.95 },
        { name = "Brawl", color = "#e05030", say = "Fists up!", stats = { armor = 4, damage = 15 }, damageTaken = 0.8,
          onEnter = function(me) me.ring({ radius = 26, color = "#e05030" }) end },
    },

    attack = {
        type = "scripted", name = "Jaw Gun", cooldown = 0.16, range = 160,
        fire = function(me)
            if me.stanceName == "Brawl" then
                me.cooldown(0.4)
                me.hit({ shape = "arc", radius = 34 * me.scale, degrees = 120, damage = 11, knockback = 140 })
                return
            end
            if me.reloading("ammo") then return end
            if not me.spend("ammo", 1) then me.reload("ammo") return end
            local rage = me.res("rage")
            me.shoot({ speed = 520, range = 220, damage = 6 + rage / 20, size = 2, color = BRASS, pierce = me.stage >= 3 and 2 or 0 })
            me.sound("hit", 1.8, 0.5)
        end,
    },
    secondary = {
        type = "scripted", name = "Shell Toss", cooldown = 2.5, range = 140,
        fire = function(me)
            -- lobbed at the cursor: the aim is already pointed there for the special
            local x, y = me.cursor()
            local d = math.min(220, me.distTo(x, y))
            me.shoot({ arc = true, speed = 260, range = d, damage = 4, burst = { radius = 38, damage = 18 }, color = BRASS })
        end,
    },

    -- ABILITIES: extra buttons. key = "ability" (F, rebindable), "stance" (R)
    -- or any key name ("g", "1", "lctrl", "mouse4"). cost takes stamina / hp / nectar / a resource.
    abilities = {
        { name = "Reload", key = "ability", cooldown = 0.3, fire = function(me) me.reload("ammo", 0.6) end },
        { name = "Parry", key = "g", cooldown = 2, cost = { stamina = 0.25 }, fire = function(me)
            me.parry(0.35)
            me.ring({ radius = 18, color = "#ffffff" })
        end },
    },

    -- EVOLUTION: stages it grows through. Each stage adds to the last: stats add up, addLimbs
    -- piles more limbs on, any other field (attack, art, scale...) replaces the one before.
    evolution = {
        { level = 3, name = "Horned", say = "Horns!", stats = { damage = 10 },
          addLimbs = { { u = 6, v = 0, side = 1, z = 2, segs = { { 4, 0, -0.5 }, { 3, 0, -0.6 } }, width = 2, color = "c" } } },
        { level = 6, name = "Clawed", say = "Claws!", stats = { maxHp = 30, armor = 2 }, scale = 1.15,
          addLimbs = { { u = 4, v = 3, segs = { { 4, 0.7, 0 }, { 3, -0.5, 0 } }, width = 2, color = "b", tip = "pincer" } } },
        { level = 10, name = "Cannon", say = "BOOM.", stats = { area = 20 },
          secondary = { type = "scripted", name = "Cannon", cooldown = 1.6, range = 200, fire = function(me)
              me.shoot({ speed = 340, range = 240, damage = 30, size = 4, pierce = 6, burst = { radius = 50, damage = 20 }, color = BRASS })
              me.knock(-me.aimX, -me.aimY, 260)       -- recoil
              me.shake(0.2)
          end } },
    },

    -- TRAITS: named code passives. Each is a set of hooks that runs next to `hooks`.
    traits = {
        { name = "Bloodlust", desc = "Every 5 kills in a spree: +12 rage.",
          onSpree = function(me, ev) me.gain("rage", 12) end },
        { name = "Last Stand", desc = "Once a run, dying instead leaves it at 40% health.",
          onDeath = function(me, ev)
              if me.state.saved then return end
              me.state.saved = true
              me.say("Not yet!")
              me.revive(0.4)
          end },
    },

    hooks = {
        onKill = function(me, ev) me.gain("rage", 2) end,
        onWaveEnd = function(me, ev) me.setRes("ammo", 6) end,
        onLowHp = function(me, ev) me.stance("Brawl") end,
        onParry = function(me, ev) me.hitCircle({ radius = 40, damage = 20, knockback = 260 }) me.gain("rage", 15) end,
        -- draw on the HUD: ui.text / ui.bar / ui.rect / ui.circle, ui.top = the first free row
        onHud = function(me, ui)
            if me.spree >= 5 then ui.text("SPREE x" .. me.spree, ui.u(20), ui.top, "#ffd060", 18) end
        end,
        -- draw in the world: gfx.line / gfx.circle / gfx.text at world positions
        onDraw = function(me, gfx)
            if me.stanceName == "Gun" and not me.reloading("ammo") then
                local x, y = me.cursor()
                gfx.line(me.x, me.y, x, y, "#e8b048", 0.25)
            end
        end,
    },
}
