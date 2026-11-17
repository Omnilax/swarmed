-- A hold-Shift move written in code by a custom bug script (Bug Creator, docs/CUSTOM_BUGS.md):
-- dash = { type = "scripted", name = "Bark Guard", hold = function(me, dt, held) ... end }
-- hold runs every frame with held = Shift down or not (me.block, me.speed, me.fly,
-- me.useStamina... make it a block, a sprint or a flight). Custom bugs pick this type
-- themselves when the dash has `hold`.
local SM = require("src.game.scriptmoves")

return {
    name = "Scripted Hold",
    description = "A hold move written in a custom bug's script.",
    hold = true,
    update = function(player, world, dt, params, held)
        if held and player.stunT > 0 then held = false end
        if type(params.hold) == "function" then SM.call(params.hold, player, world, params, player.aimX, player.aimY, nil, nil, dt, held and true or false) end
        if held and not player.wasHolding then player.inventory:trigger("onDash", { world = world, player = player, procDepth = 0 }) end
        player.wasHolding = held
    end,
}
