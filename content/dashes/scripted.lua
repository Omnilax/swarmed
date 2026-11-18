-- A dash written in code by a custom bug script (Bug Creator, docs/CUSTOM_BUGS.md):
-- dash = { type = "scripted", name = "Twig Vault", charges = 1,
--          start = function(me) me.lunge(70) end,       -- Shift pressed
--          tick = function(me, dt) end }                -- every frame while the dash moves you
-- src/game/scriptmoves.lua runs the functions with their toolkit, in the sandbox.
local SM = require("src.game.scriptmoves")

return {
    name = "Scripted Dash",
    description = "A dash written in a custom bug's script.",
    start = function(player, world, dx, dy, params, px, py)
        if type(params.start) == "function" then SM.call(params.start, player, world, params, player.aimX, player.aimY, dx, dy) end
    end,
    update = function(player, world, dt, params)
        if type(params.tick) == "function" then SM.call(params.tick, player, world, params, player.aimX, player.aimY, nil, nil, dt) end
    end,
}
