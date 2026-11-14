-- (Helper module, not a dash: the leading _ keeps the registry from loading it.)
-- Shared bits for "hold Shift, let go" dashes (mantis shrimp's charged recoil punch, centipede's
-- flip). They are `hold = true` dashes, but unlike a block they still spend a dash charge (which
-- comes out of the shared stamina pool like any dash, src/game/stamina.lua) and fire the same hooks a pressed dash does.
local Anim = require("src.gfx.anim")
local Audio = require("src.core.audio")
local Stamina = require("src.game.stamina")

local Charge = {}

-- Can a hold start now? (a charge in hand, not paralysed, not mid-dash)
function Charge.ready(player)
    return Stamina.hasCharge(player) and player.stunT <= 0 and player.dashT <= 0.04 and not player.grapple
end

-- Spend a charge and clear last dash's hop/hit state. Call before moving the bug.
function Charge.spend(player)
    Stamina.spendCharge(player)
    player.dashHop, player.dashHit, player.dashT0 = 0, nil, nil
end

-- After the release has moved the bug: animation, sound, and onDash procs (items, skills).
-- anim = false when the dash already started its clip as the charge began (a held wind-up).
function Charge.fired(player, world, params, anim)
    if anim ~= false then Anim.move(player, "dash", params) end
    player.dashT0 = player.dashT
    Audio.play("dash")
    player.inventory:trigger("onDash", { world = world, player = player, procDepth = 0 })
end

return Charge
