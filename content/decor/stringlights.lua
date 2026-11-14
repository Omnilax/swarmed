local util = require("src.core.util")
return {
    name = "String Lights",
    description = "Warm bulbs strung along the back of the arena. They glow after dusk.",
    order = 4,
    paint = function(ground, stage, rng)
        local lg = love.graphics
        local S = stage.size
        local wire = util.hex("#2a2420")
        local cols = { { 1, 0.78, 0.45 }, { 1, 0.62, 0.4 }, { 1, 0.9, 0.6 }, { 0.75, 0.9, 1 } }
        -- the two far edges (x = 0 and y = 0 run along the top of the screen)
        for edge = 1, 2 do
            local prevX, prevY
            local span, sag = 36, 5
            for i = 0, math.floor(S / span) do
                local u = i * span
                local wx, wy = edge == 1 and u or 6, edge == 1 and 6 or u
                local x, y = ground:toCanvas(wx, wy)
                y = y - 14
                if prevX then
                    -- sagging wire between posts, then a bulb at the low point
                    lg.setColor(wire[1], wire[2], wire[3], 1)
                    lg.setLineWidth(1)
                    local mx, my = (prevX + x) / 2, (prevY + y) / 2 + sag
                    lg.line(prevX, prevY, mx, my, x, y)
                    local c = cols[rng:random(#cols)]
                    lg.setColor(c[1], c[2], c[3], 1)
                    lg.rectangle("fill", math.floor(mx) - 1, math.floor(my) + 1, 3, 3)
                    lg.setColor(1, 1, 1, 0.9)
                    lg.points(math.floor(mx) + 0.5, math.floor(my) + 1.5)
                    local px, py = ground:toProjected(mx, my + 10)
                    local d = ground.decorLights
                    d[#d + 1] = { x = px, y = py, radius = 64, color = c, intensity = 0.9, twinkle = 2 }
                end
                prevX, prevY = x, y
            end
        end
    end,
}
