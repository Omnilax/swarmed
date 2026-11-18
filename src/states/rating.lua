-- Bug Creator > Rate It: runs the power-level fights (src/game/bugrating.lua) a slice per frame
-- with a progress bar, then shows the score next to the built-in bugs'.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Input = require("src.core.input")
local Rating = require("src.game.bugrating")

local Screen = {}
Screen.__index = Screen

function Screen.new(def)
    local self = setmetatable({ def = def, t = 0 }, Screen)
    self.rating = Rating.new(def.id)
    return self
end

function Screen:update(dt)
    self.t = self.t + dt
    if not self.rating.score then
        -- about a tenth of a second of work per frame
        local t0 = love.timer.getTime()
        repeat self.rating:step(20) until self.rating.score or love.timer.getTime() - t0 > 0.1
    end
    if Input.pressed("ui_back") or (self.rating.score and Input.pressed("ui_confirm")) then State.pop() end
end

function Screen:mousepressed() if self.rating.score then State.pop() end end

function Screen:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local c = Theme.colors
    lg.clear(c.bg)
    Theme.title("Power Level")
    local pw = math.min(w - u(120), u(720))
    local px = (w - pw) / 2
    Theme.panel(px, u(130), pw, h - u(220))
    lg.setFont(Theme.font("heading"))
    Theme.printShadow(self.def.name, px, u(160), c.text, "center", pw)
    local r = self.rating
    if not r.score then
        local bw = pw - u(120)
        local bx, by = px + u(60), u(260)
        lg.setColor(0, 0, 0, 0.4)
        lg.rectangle("fill", bx, by, bw, u(16), 6, 6)
        lg.setColor(c.focus)
        lg.rectangle("fill", bx, by, bw * math.min(1, r.progress), u(16), 6, 6)
        lg.setFont(Theme.font("body"))
        lg.setColor(c.dim)
        lg.printf("Fighting the same waves as the Rhino Beetle, the Mantis and the Wolf Spider...", px + u(30), by + u(36), pw - u(60), "center")
        return
    end
    if r.error then
        lg.setFont(Theme.font("body"))
        lg.setColor(c.bad)
        lg.printf("The test fight broke: " .. r.error, px + u(30), u(240), pw - u(60), "center")
        return
    end
    lg.setFont(Theme.font(64, "bold"))
    local col = r.score >= 130 and c.bad or r.score >= 85 and c.good or c.focus
    Theme.printShadow(tostring(r.score), px, u(220), col, "center", pw)
    lg.setFont(Theme.font("body"))
    lg.setColor(c.text)
    lg.printf(Rating.words(r.score), px + u(30), u(310), pw - u(60), "center")
    local pr = r.parts
    if pr then
        local m, ref = pr.mine, pr.ref
        local rows = {
            { "Damage per second", ("%d  (built-in bugs: %d)"):format(m.dealt / math.max(1, m.time), ref.dealt / math.max(1, ref.time)) },
            { "Ants defeated", ("%d  (built-in bugs: %d)"):format(m.kills, ref.kills) },
            { "Damage taken", ("%d  (built-in bugs: %d)"):format(m.taken, ref.taken) },
            { "Lasted", m.alive and ("the whole %d s"):format(Rating.TIME) or ("%d s, then fell"):format(m.time) },
        }
        lg.setFont(Theme.font("label"))
        local lh = lg.getFont():getHeight() + u(8)
        for i, row in ipairs(rows) do
            local y = u(370) + (i - 1) * lh
            lg.setColor(c.accent)
            lg.printf(row[1], px, y, pw / 2 - u(10), "right")
            lg.setColor(c.text)
            lg.print(row[2], px + pw / 2 + u(10), y)
        end
        lg.setColor(c.dim)
        lg.printf("100 = as strong as an average built-in bug. Saved in its record (Bug Creator panel).", px + u(30), u(370) + #rows * lh + u(16), pw - u(60), "center")
    end
    Theme.footer({ { "Enter", "Done" } })
end

return Screen
