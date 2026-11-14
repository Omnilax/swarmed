local util = require("src.core.util")
return {
    name = "Fallen Petals",
    description = "Blossom petals scattered across the floor.",
    order = 1,
    paint = function(ground, stage, rng)
        local lg = love.graphics
        local S = stage.size
        local cols = { util.hex("#f0b8cc"), util.hex("#f6d2de"), util.hex("#e494b0") }
        local light = util.hex("#fff0f4")
        -- in drifts: petals bunch up around a few spots
        for _ = 1, 9 do
            local hx, hy = rng:random() * S, rng:random() * S
            for _ = 1, rng:random(14, 34) do
                local a, r = rng:random() * 6.28, rng:random() ^ 0.7 * 60
                local cx, cy = ground:toCanvas(hx + math.cos(a) * r, hy + math.sin(a) * r)
                cx, cy = math.floor(cx), math.floor(cy)
                local c = cols[rng:random(#cols)]
                lg.setColor(c[1], c[2], c[3], 0.95)
                if rng:random() < 0.5 then lg.rectangle("fill", cx, cy, 2, 1) else lg.rectangle("fill", cx, cy, 1, 2) end
                lg.setColor(light[1], light[2], light[3], 0.8)
                lg.points(cx + 0.5, cy + 0.5)
            end
        end
    end,
}
