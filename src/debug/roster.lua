-- Model viewer:  love . --roster   (add --shot to save roster.png in the save folder and quit)
-- Every character's 3D model walking in place, slowly turning, at 4x. Handy for checking legs.
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local Theme = require("src.ui.theme")

local Roster = { t = 0 }
Roster.__index = Roster

function Roster.new(opts) return setmetatable({ t = opts.t or 0, shot = opts.shot, angle = opts.angle }, Roster) end

function Roster:update(dt)
    self.t = self.t + dt
    if self.shot and self.t > 0.4 and not self.taken then
        self.taken = true
        love.graphics.captureScreenshot("roster.png")
    elseif self.taken and self.t > 0.8 then
        love.event.quit()
    end
end

function Roster:draw()
    local lg = love.graphics
    lg.clear(0.12, 0.11, 0.1)
    local all = Content.characters:all()
    local cols = 4
    local W = lg.getDimensions()
    for i, c in ipairs(all) do
        local cx, cy = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = W / cols * (cx + 0.5), 120 + cy * 210
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", x, y + 6, 70, 26)
        lg.setColor(1, 1, 1, 1)
        local a = self.angle or (-0.5 + math.sin(self.t * 0.5 + i) * 0.6)
        Sprites.drawModel(c.model, 1, x, y, a, false, 4, 4, 1, { phase = (self.t * 1.3 + i * 0.13) % 1, bob = 0 })
        lg.setFont(Theme.font(18))
        Theme.printShadow(c.name, x - 120, y + 55, Theme.colors.text, "center", 240)
    end
end

return Roster
