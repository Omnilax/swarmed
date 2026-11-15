-- Courier: runs straight for e.st.tx, e.st.ty (set by whoever spawns it, e.g. the courier
-- mini-goal), ignoring the player, and leaves the arena when it gets there.
local AI = require("src.game.ai")

return {
    name = "Courier",
    update = function(e, world, dt, params)
        local st = e.st
        if not st.tx then st.tx, st.ty = world.size - e.x, world.size - e.y end
        local d = AI.goTo(e, st.tx, st.ty, e.speed)
        if d < 10 then world:escapeEnemy(e, "COURIER ESCAPED") end
    end,
    drawUnder = function(e, world)
        -- a bright line to where it is heading, so you know where to cut it off
        local Iso = require("src.core.iso")
        local x, y = Iso.toScreen(e.x, e.y)
        local tx, ty = Iso.toScreen(e.st.tx or e.x, e.st.ty or e.y)
        love.graphics.setColor(1, 0.85, 0.4, 0.25)
        love.graphics.line(x, y, tx, ty)
        love.graphics.setColor(1, 1, 1, 1)
    end,
}
