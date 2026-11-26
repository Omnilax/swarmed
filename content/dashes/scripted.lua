-- A dash written in code by a custom bug script (Bug Creator, docs/CUSTOM_BUGS.md):
-- dash = { type = "scripted", name = "Twig Vault", charges = 1,
--          start = function(me) me.lunge(70) end,       -- Shift pressed
--          tick = function(me, dt) end }                -- every frame while the dash moves you
-- src/game/scriptmoves.lua runs the functions with their toolkit, in the sandbox.
local SM = require("src.game.scriptmoves")

--          free = function(me) return me.state.looping end      -- (optional) true: this press costs no stamina
return {
    name = "Scripted Dash",
    description = "A dash written in a custom bug's script.",
    free = function(player)
        local p = player.dashParams
        if not (p and type(p.free) == "function") then return false end
        return SM.call(p.free, player, player.world, p, player.aimX, player.aimY) == true
    end,
    start = function(player, world, dx, dy, params, px, py)
        if type(params.start) == "function" then SM.call(params.start, player, world, params, player.aimX, player.aimY, dx, dy) end
    end,
    update = function(player, world, dt, params)
        if type(params.tick) == "function" then SM.call(params.tick, player, world, params, player.aimX, player.aimY, nil, nil, dt) end
    end,
}
