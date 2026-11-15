-- A live little arena for character select: the highlighted bug fights a few worker ants and,
-- on a loop, shows off its special and its dash, with a caption naming each as it happens.
-- It is a real World (sandbox mode, invincible, no spawner) driven by scripted buttons
-- (world.pilot, read by Player:update), drawn through the world canvas into a box.
local Content = require("src.content")
local Audio = require("src.core.audio")
local Screen = require("src.core.screen")
local Theme = require("src.ui.theme")

local Preview = {}
Preview.__index = Preview

local ANT = "worker_ant"
local LOOP = 6.5            -- seconds: walk and fight, special, walk, dash
local STEPS = {
    { at = 1.6, move = "secondary", hold = 1.0 },
    { at = 4.2, move = "dash", hold = 0.8 },
}

function Preview.new(charId)
    local World = require("src.game.world")
    local self = setmetatable({ id = charId, t = 0, caption = nil, capT = 0 }, Preview)
    local w = World.new({ mode = "sandbox", character = charId })
    w.flags.god, w.flags.demo = true, true
    w.pilot = { pressed = {}, down = {} }
    self.world = w
    local def = Content.characters:get(charId)
    self.def = def
    local sec = def.secondary and Content.attacks:get(def.secondary.type)
    local dash = Content.dashes:get((def.dash or { type = "dash" }).type)
    self.names = { secondary = sec and sec.name, dash = dash and dash.name }
    self:refill()
    -- settle the camera on the bug
    Audio.muted = true
    for _ = 1, 20 do w:update(1 / 30) end
    Audio.muted = false
    return self
end

function Preview:refill()
    local w, p = self.world, self.world.player
    if not Content.enemies:get(ANT) then return end
    local n = 8 - w.enemyCount
    if n > 0 then w:spawnRing(ANT, n, p.x, p.y, 70) end
end

function Preview:update(dt)
    local w = self.world
    local pilot = w.pilot
    pilot.pressed = {}
    self.t = self.t + dt
    local cycle, t1 = math.floor(self.t / LOOP), self.t % LOOP
    pilot.down = {}
    self.fired = self.fired or {}
    for i, st in ipairs(STEPS) do
        if t1 >= st.at and self.fired[i] ~= cycle then
            self.fired[i] = cycle
            if st.move ~= "secondary" or self.def.secondary then
                pilot.pressed[st.move] = true
                self.caption, self.capT = { st.move == "dash" and "DASH" or "SPECIAL", self.names[st.move] or "" }, 1.8
            end
        end
        if t1 >= st.at and t1 < st.at + st.hold then pilot.down[st.move] = true end
    end
    -- a slow figure of eight so dashes go somewhere
    local a = self.t * 0.6
    pilot.mx, pilot.my = math.cos(a) * 0.6, math.sin(a * 2) * 0.4
    self.capT = math.max(0, self.capT - dt)
    Audio.muted = true
    w:update(math.min(dt, 1 / 30))
    Audio.muted = false
    -- keep it tidy: a few ants always around, nobody wanders off
    if w.enemyCount < 4 then self:refill() end
    local p = w.player
    local c = w.size / 2
    if (p.x - c) ^ 2 + (p.y - c) ^ 2 > 140 * 140 then
        pilot.mx, pilot.my = 0, 0
        p.x, p.y = p.x + (c - p.x) * 0.02, p.y + (c - p.y) * 0.02
    end
end

-- Draw into a box on screen. Call before any other drawing that frame (it uses the world canvas).
function Preview:draw(x, y, bw, bh)
    local w = self.world
    w:flushDecals()
    Screen.beginWorld({ 0.09, 0.08, 0.12, 1 }, 1)
    w:draw()
    -- the patch of world shown: about 230 pixels tall around the bug, the box's shape
    local srcH = math.min(Screen.viewH, 200)
    local srcW = math.min(Screen.viewW, math.floor(srcH * bw / bh))
    srcH = math.floor(srcW * bh / bw)
    Screen.endWorldInto(x, y, bw, bh, srcW, srcH)
    local lg = love.graphics
    lg.setColor(Theme.colors.panelEdge)
    lg.rectangle("line", x, y, bw, bh)
    if self.caption and self.capT > 0 then
        local a = math.min(1, self.capT * 3)
        local u = Theme.u
        lg.setFont(Theme.font("label", "bold"))
        local txt = self.caption[1] .. "  ·  " .. self.caption[2]
        local tw = lg.getFont():getWidth(txt) + u(16)
        lg.setColor(0.05, 0.04, 0.035, 0.75 * a)
        lg.rectangle("fill", x + u(8), y + u(8), tw, lg.getFont():getHeight() + u(8))
        Theme.printShadow(txt, x + u(16), y + u(12), { Theme.colors.focus[1], Theme.colors.focus[2], Theme.colors.focus[3], a })
    end
    lg.setColor(1, 1, 1, 1)
end

-- Free the world's big canvases now rather than whenever the garbage collector gets to them.
function Preview:release()
    local g = self.world and self.world.ground
    if g then
        if g.canvas then g.canvas:release() end
        if g.decals then g.decals:release() end
    end
    self.world = nil
end

return Preview
