local util = require("src.core.util")
return {
    name = "Fairy Ring",
    description = "A ring of glowing mushrooms in the lawn. Brightest at night.",
    order = 3,
    paint = function(ground, stage, rng)
        local lg = love.graphics
        local S = stage.size
        local inset = S * (stage.patioInset or 0.2)
        -- centre the ring in the lawn border on a random side
        local side = rng:random(4)
        local t = 0.25 + rng:random() * 0.5
        local h = inset * 0.5
        local cxw, cyw = ({ { t * S, h }, { h, t * S }, { t * S, S - h }, { S - h, t * S } })[side][1],
            ({ { t * S, h }, { h, t * S }, { t * S, S - h }, { S - h, t * S } })[side][2]
        local R = math.min(48, inset * 0.38)
        local cap, capDark, stem = util.hex("#e8e0c8"), util.hex("#a89a7a"), util.hex("#f0ecd8")
        local glow = { 0.55, 1, 0.8 }
        local n = 16
        for i = 1, n do
            local a = i / n * 6.28 + rng:random() * 0.2
            local r = R * (0.9 + rng:random() * 0.2)
            local wx, wy = cxw + math.cos(a) * r, cyw + math.sin(a) * r
            local x, y = ground:toCanvas(wx, wy)
            x, y = math.floor(x), math.floor(y)
            local s = rng:random(2, 4)
            lg.setColor(0, 0, 0, 0.3)
            lg.ellipse("fill", x + 1, y + 1, s + 1, (s + 1) / 2)
            lg.setColor(stem[1], stem[2], stem[3], 1)
            lg.rectangle("fill", x, y - 1, 1, 2)
            lg.setColor(capDark[1], capDark[2], capDark[3], 1)
            lg.ellipse("fill", x, y - 2, s, s / 2)
            lg.setColor(cap[1], cap[2], cap[3], 1)
            lg.ellipse("fill", x, y - 2.5, s - 1, (s - 1) / 2)
            lg.setColor(glow[1], glow[2], glow[3], 0.9)
            lg.points(x + 0.5, y - 2.5)
            if i % 2 == 0 then
                local px, py = ground:toProjected(x, y)
                local d = ground.decorLights
                d[#d + 1] = { x = px, y = py, radius = 26, color = glow, intensity = 0.4, twinkle = 1.3 }
            end
        end
    end,
}
