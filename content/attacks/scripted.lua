-- A move written in code by a custom bug script (Bug Creator, docs/CUSTOM_BUGS.md):
-- attack / secondary = { type = "scripted", name = "Stick Whip", cooldown = 0.6, range = 50,
--                        fire = function(me) me.hitArc({ radius = 50, damage = 9 }) end }
-- src/game/scriptmoves.lua runs the function with its toolkit, in the sandbox.
local SM = require("src.game.scriptmoves")

return {
    name = "Scripted Move",
    range = function(params) return params.range or 40 end,
    fire = function(player, world, ax, ay, params)
        if type(params.fire) == "function" then SM.call(params.fire, player, world, params, ax, ay) end
    end,
}
