local util = require("src.core.util")
return {
    name = "Chalk Hopscotch",
    description = "A faded chalk hopscotch on the patio slabs.",
    order = 5,
    stages = { "backyard" },
    paint = function(ground, stage, rng)
        local lg = love.graphics
        local S = stage.size
        local chalk = { util.hex("#f4f0e8"), util.hex("#f4c8d8"), util.hex("#c8e0f4") }
        local x0, y0 = S * 0.58, S * 0.3
        local cell = 22
        -- 1, 2, 3-4, 5, 6-7, 8, then a half-circle "home"
        local rows = { 1, 1, 2, 1, 2, 1 }
        local function quad(a, b, w, h)
            local pts = {}
            for _, c in ipairs({ { a, b }, { a + w, b }, { a + w, b + h }, { a, b + h }, { a, b } }) do
                local x, y = ground:toCanvas(c[1], c[2])
                pts[#pts + 1], pts[#pts + 2] = x, y
            end
            return pts
        end
        lg.setLineWidth(1)
        for r, count in ipairs(rows) do
            for k = 1, count do
                local c = chalk[rng:random(#chalk)]
                lg.setColor(c[1], c[2], c[3], 0.55)
                local off = count == 1 and cell * 0.5 or (k - 1) * cell
                lg.line(quad(x0 + off, y0 + (r - 1) * cell, cell, cell))
            end
        end
        -- scuffed chalk dust
        for _ = 1, 70 do
            local x, y = ground:toCanvas(x0 + rng:random() * cell * 2, y0 + rng:random() * cell * #rows)
            lg.setColor(1, 1, 1, 0.12 + rng:random() * 0.15)
            lg.points(math.floor(x) + 0.5, math.floor(y) + 0.5)
        end
    end,
}
