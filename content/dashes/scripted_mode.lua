-- A hold-Shift stamina mode written in code by a custom bug script (Bug Creator,
-- docs/CUSTOM_BUGS.md). It burns the stamina bar while Shift is held, like the tiger beetle's
-- run or the dragonfly's flight:
-- dash = { type = "scripted", name = "Glide", mode = true, speed = 1.5, stamina = 3,
--          enter = function(me) me.fly(true, 14) end,
--          tick = function(me, dt) end,
--          exit = function(me, dry) me.fly(false) end }       -- dry = the bar ran out
-- Custom bugs pick this type themselves when the dash has mode = true.
local SM = require("src.game.scriptmoves")
local Stamina = require("src.game.stamina")

return Stamina.mode({
    name = "Scripted Mode",
    description = "A stamina mode written in a custom bug's script.",
    enter = function(player, world, params)
        if type(params.enter) == "function" then SM.call(params.enter, player, world, params, player.aimX, player.aimY) end
    end,
    tick = function(player, world, dt, params)
        if type(params.tick) == "function" then SM.call(params.tick, player, world, params, player.aimX, player.aimY, nil, nil, dt) end
    end,
    exit = function(player, world, params, dry)
        if type(params.exit) == "function" then SM.call(params.exit, player, world, params, player.aimX, player.aimY, nil, nil, dry and true or false) end
    end,
})
