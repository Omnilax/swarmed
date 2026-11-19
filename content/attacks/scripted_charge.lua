-- A hold-to-charge move written in code by a custom bug script (Bug Creator,
-- docs/CUSTOM_BUGS.md). Works as the attack or the special:
--   attack = { type = "scripted", name = "Big Swing", charge = 1.2,     -- seconds to full
--              hold = function(me, dt, charge) end,                     -- every frame while held
--              release = function(me, charge) me.hitArc({ damage = 6 + 20 * charge }) end }
-- charge goes 0 .. 1. Auto-attack charges to `autoCharge` (0.5) and lets go by itself.
-- (Custom bugs pick this type themselves when a move has `release`.)
local SM = require("src.game.scriptmoves")
local Iso = require("src.core.iso")

local function slotOf(player, params)
    if player.secondary and player.secondary.params == params then return "secondary" end
    return "attack"
end

local function chargeOf(player, slot)
    player.scriptCharge = player.scriptCharge or {}
    return player.scriptCharge, slot
end

return {
    name = "Scripted Charge",
    manual = true,
    range = function(params) return params.range or 40 end,
    update = function(player, world, dt, params, down, a, b)
        local slot = slotOf(player, params)
        local move = player[slot]
        local ch = chargeOf(player, slot)
        if move.timer > 0 then ch[slot] = nil return end
        -- the attack slot gets (down, auto); the special gets (held, px, py)
        local auto = slot == "attack" and a or false
        local full = math.max(0.05, tonumber(params.charge) or 1)
        if down or auto then
            ch[slot] = (ch[slot] or 0) + dt
            local f = math.min(1, ch[slot] / full)
            if type(params.hold) == "function" then SM.call(params.hold, player, world, params, player.aimX, player.aimY, nil, nil, dt, f) end
            if not (auto and not down and f >= (tonumber(params.autoCharge) or 0.5)) then return end
        end
        if not ch[slot] then return end
        local f = math.min(1, ch[slot] / full)
        ch[slot] = nil
        if slot == "attack" then
            player:releaseAttack(player.aimX, player.aimY, f)
        else
            local px, py = a, b
            player:releaseSecondary(player.aimX, player.aimY, px, py, f)
        end
    end,
    fire = function(player, world, ax, ay, params, x1, x2, x3)
        -- attack: (extra); special: (px, py, extra)
        local f = x3 or (type(x1) == "number" and x2 == nil and x1) or 0
        local fn = params.release or params.fire
        if type(fn) == "function" then SM.call(fn, player, world, params, ax, ay, nil, nil, f) end
    end,
    -- a ring that closes in as the charge fills
    draw = function(player, world, params)
        local ch = player.scriptCharge
        if not ch then return end
        local lg = love.graphics
        local full = math.max(0.05, tonumber(params.charge) or 1)
        for _, slot in ipairs({ "attack", "secondary" }) do
            local t = ch[slot]
            local move = player[slot]
            if t and move and move.params == params then
                local f = math.min(1, t / full)
                local x, y = Iso.toScreen(player.x, player.y, 0)
                local c = params.color or { 1, 0.9, 0.5 }
                lg.setColor(c[1], c[2], c[3], 0.35 + 0.5 * f)
                lg.ellipse("line", x, y, 18 - 9 * f, (18 - 9 * f) * 0.5)
                if f >= 1 then lg.ellipse("line", x, y, 6, 3) end
            end
        end
        lg.setColor(1, 1, 1, 1)
    end,
}
