local util = require("src.core.util")
return {
    name = "Lost Bottle Caps",
    description = "Rusty caps and a burnt match left on the ground.",
    order = 2,
    paint = function(ground, stage, rng)
        local lg = love.graphics
        local S = stage.size
        local metals = { { "#b8b4a8", "#7c786e" }, { "#c84a3a", "#7e2a22" }, { "#d8b84a", "#8a7022" }, { "#4a78b0", "#2a4670" } }
        local rust = util.hex("#8a4a26")
        for _ = 1, 7 do
            local cx, cy = ground:toCanvas(S * (0.12 + rng:random() * 0.76), S * (0.12 + rng:random() * 0.76))
            cx, cy = math.floor(cx), math.floor(cy)
            local m = metals[rng:random(#metals)]
            local face, rim = util.hex(m[1]), util.hex(m[2])
            -- shadow, crimped rim, face, glint
            lg.setColor(0, 0, 0, 0.3)
            lg.ellipse("fill", cx + 1, cy + 2, 7, 3.5)
            lg.setColor(rim[1], rim[2], rim[3], 1)
            lg.ellipse("fill", cx, cy, 7, 3.5)
            lg.setColor(face[1], face[2], face[3], 1)
            lg.ellipse("fill", cx, cy - 0.5, 5, 2.5)
            for i = 0, 11 do
                local a = i / 12 * 6.28
                lg.setColor(rim[1] * 0.7, rim[2] * 0.7, rim[3] * 0.7, 1)
                lg.points(math.floor(cx + math.cos(a) * 7) + 0.5, math.floor(cy + math.sin(a) * 3.5) + 0.5)
            end
            lg.setColor(1, 1, 1, 0.6)
            lg.rectangle("fill", cx - 3, cy - 2, 2, 1)
            for _ = 1, rng:random(0, 5) do
                lg.setColor(rust[1], rust[2], rust[3], 0.8)
                lg.points(cx + rng:random(-5, 4) + 0.5, cy + rng:random(-2, 1) + 0.5)
            end
        end
        -- a burnt match
        local mx, my = ground:toCanvas(S * (0.3 + rng:random() * 0.4), S * (0.3 + rng:random() * 0.4))
        mx, my = math.floor(mx), math.floor(my)
        local wood = util.hex("#d8b880")
        lg.setColor(wood[1], wood[2], wood[3], 1)
        lg.setLineWidth(1)
        lg.line(mx, my + 0.5, mx + 14, my + 0.5 + 4)
        lg.setColor(0.12, 0.1, 0.09, 1)
        lg.rectangle("fill", mx - 2, my - 1, 3, 2)
    end,
}
