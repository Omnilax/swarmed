-- ===========================================================================================
--  EXAMPLE CUSTOM BUG: the Stick Insect
--  A brand-new bug with its own art and its own moves written in code. Import it in the game:
--  Bug Creator > Examples > Stick Insect (or paste this whole file with Paste a Script).
--  Guide: docs/CUSTOM_BUGS.md ("Your own art" and "Moves written in code").
-- ===========================================================================================

-- Pixel art, top-down, facing right. Each letter is a colour from the palette, "." is empty.
local BODY = {
    "o.............................oooooooo...ooooo.....a",
    ".a.oooooooooooooooooooooooooooccccccccoooccewc...aa.",
    "..occbccccbccccbccccbccccbcddddddddddddddcccccoaa...",
    ".oabbbbbbbbbbbbbbbbbbbbbbbbggggggggggggggcdccbo.....",
    "..oaaoaaaaoaaaaoaaaaoaaaaoabbbbbbbbbbbbbbcccccoaa...",
    ".a.oooooooooooooooooooooooooooaaaaaaaaoooccewc...aa.",
    "o.............................oooooooo...ooooo.....a",
}

local TWIG = { 0.75, 0.62, 0.36 }

return {
    name = "Stick Insect",
    description = "Looks like a twig, fights like a whip. Long leg sweeps, every third one a jab that skewers a line. Right click flings a fan of thorns, twice. Shift vaults forward and lands with a thump.",
    lore = "Some stick insects are longer than your forearm, and many can regrow a lost leg.",
    tip = "Stand still to vanish into the twigs. Every third {attack} is a long jab. {secondary} throws two fans of thorns. {dash} vaults and thumps where you land.",
    playstyle = "control",
    tags = { "insect" },

    -- ART: its own body and legs instead of a built-in bug's look
    art = {
        palette = {
            o = "#1c140ab0",   -- outline (a little see-through, like the built-in bugs)
            a = "#4a3a1e",     -- dark bark
            b = "#6e5a30",
            c = "#94784a",
            d = "#bca06a",     -- highlight
            g = "#6a8a3a",     -- moss stripe
            e = "#140c06",     -- eyes
            w = "#e8dcb0",     -- eye shine
        },
        body = BODY,
        -- legs: { hipU, hipV, kneeU, kneeV, footU, footV } for one side (mirrored to the other).
        -- u = pixels forward from the middle of the drawing, v = pixels to the side.
        legs = {
            { 12, -1, 18, -8, 26, -12 },    -- front
            { 6, -1, 6, -10, 4, -16 },      -- middle
            { 1, -1, -6, -9, -14, -14 },    -- hind
        },
        legColor = "#7a6438",
        height = 2,      -- body thickness (pixels)
        lift = 3,        -- how high the body is held
        kneeUp = 2,      -- how high the knees rise
        stride = 2.4,    -- step length
    },
    scale = 1.1,

    stats = { maxHp = 45, moveSpeed = 96, armor = 1, dodge = 10, critChance = 12 },

    -- PASSIVE: stand still and it vanishes into the twigs; the first moments after moving
    -- again it hits 50% harder
    passives = { camo = { after = 0.6, ambush = 50 } },
    music = "flute",

    -- ATTACK: written in code. `me` is the toolkit (docs/CUSTOM_BUGS.md lists everything in it).
    attack = {
        type = "scripted",
        name = "Stick Whip",
        cooldown = 0.55,
        range = 55,           -- how close ants must be for auto-attack
        fire = function(me)
            me.state.swings = (me.state.swings or 0) + 1
            if me.state.swings % 3 == 0 then
                -- every third swing: a long jab through a whole line
                me.hitLine({ length = 95, width = 6, damage = 16, knockback = 160, color = TWIG })
                me.sound("hit", 1.3)
            else
                me.hitArc({ radius = 50, arc = 1.6, damage = 8, knockback = 90, color = TWIG })
            end
        end,
    },

    -- SPECIAL: a fan of thorns, then a second fan a moment later
    secondary = {
        type = "scripted",
        name = "Thorn Fan",
        cooldown = 3,
        range = 140,
        fire = function(me)
            local function fan(m)
                for i = -2, 2 do
                    m.shoot({ turn = i * 0.18, speed = 300, range = 150, damage = 7, pierce = 1,
                        poison = { 3, 2 }, color = { 0.6, 0.85, 0.35 } })
                end
                m.sound("zap", 1.6)
            end
            fan(me)
            me.after(0.35, fan)
        end,
    },

    -- DASH: vault forward, thump down where you land
    dash = {
        type = "scripted",
        name = "Twig Vault",
        charges = 2,
        start = function(me)
            me.lunge(80)
            me.after(0.22, function(m)
                local n = m.hitCircle({ radius = 34, damage = 10, knockback = 220, stun = 0.4, color = TWIG })
                if n >= 5 then m.shake(0.15) end
            end)
        end,
    },
}
