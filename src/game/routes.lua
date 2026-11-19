-- Route gates: after a wave, two tunnels open in the ground near the player, a safe one and a
-- hard one from content/routes (numbers in src/config/rewards.lua routes). Walk into one to start the next
-- wave that way: the hard one has more / tougher ants and pays a better reward when it is
-- cleared (bonus XP, frenzy, a rarer item card). Ignore them, or press Next Wave, for a normal
-- wave. They only show while there is a break (Settings > Gameplay > Next Wave not "Right Away"),
-- never before the final wave, and can be turned off in a Custom Waves set (run rule "routeGates").
-- The chosen route is world.route while its wave runs (Spawner and World:hpScale read it).
local Content = require("src.content")
local Rules = require("src.game.rules")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Iso = require("src.core.iso")
local util = require("src.core.util")

local Routes = {}
Routes.__index = Routes

function Routes.new(rewards)
    return setmetatable({ rewards = rewards, world = rewards.world, gates = nil, pending = nil, taken = 0 }, Routes)
end

local function pick(kind, wave)
    return Content.routes:pickWeighted(function(d) return d.weight end, function(d) return d.kind == kind and d.minWave <= wave end)
end

-- Open the two tunnels for wave `next`.
function Routes:offer(next)
    local w, sp = self.world, self.world.spawner
    local cfg = self.rewards.cfg.routes
    self.gates = nil
    if not Rules.get("routeGates") or next < cfg.fromWave or sp:isFinal(next) or sp.timer <= 0 then return end
    if not require("src.game.onramp").allows(w, "routes", next) then return end
    local safe, hard = pick("safe", next), pick("hard", next)
    if not safe or not hard then return end
    local p, S = w.player, w.size
    -- one to the left of the bug on screen, one to the right (screen x = world x - y)
    local o = cfg.offset * 0.7071
    local function at(sx)
        return { x = util.clamp(p.x + sx * o, 30, S - 30), y = util.clamp(p.y - sx * o, 30, S - 30) }
    end
    local a, b = at(-1), at(1)
    if love.math.random() < 0.5 then a, b = b, a end
    a.def, b.def = safe, hard
    self.gates = { a, b }
    -- enough break to walk over to one
    if sp.timer ~= math.huge then sp.timer = math.max(sp.timer, cfg.minBreak) end
    w.events:emit("routes_offered", safe, hard)
end

function Routes:choose(gate)
    local w, sp = self.world, self.world.spawner
    self.gates = nil
    self.pending = gate.def
    w.route = gate.def
    self.taken = self.taken + 1
    local col = util.hex(gate.def.color)
    w.particles:burst(gate.x, gate.y, 24, { col, { 1, 1, 1 } }, 120, 80, { glow = true, grav = 60 })
    Audio.play("ui_confirm", { pitch = gate.def.kind == "hard" and 0.8 or 1.2 })
    w.events:emit("route_chosen", gate.def)
    sp:startWave()
end

function Routes:waveStarted()
    self.gates = nil
    self.world.route = self.pending
    self.pending = nil
    local r = self.world.route
    if r then self.world.milestone = { text = r.name:upper(), t = 0.2 } end
end

function Routes:waveCleared(n)
    local w, p = self.world, self.world.player
    local r = w.route
    if r and not p.dead then
        self.rewards:pay(r.reward, p.x, p.y)
        if r.kind == "hard" then w:floatText(p.x, p.y - 26, "ROUTE CLEARED!", util.hex(r.color), true) end
    end
    w.route = nil
    if not p.dead then self:offer(n + 1) end
end

function Routes:update(dt)
    local gates = self.gates
    if not gates then return end
    local w, sp, p = self.world, self.world.spawner, self.world.player
    -- the wave started some other way (timer, Next Wave): a normal wave
    if sp.phase ~= "break" then self.gates = nil return end
    if w.pendingChoice or p.dead then return end      -- the item choice comes first
    local r = self.rewards.cfg.routes.radius + p.radius
    for _, g in ipairs(gates) do
        g.t = (g.t or 0) + dt
        if g.t > 0.3 and (p.x - g.x) ^ 2 + (p.y - g.y) ^ 2 < r * r then
            self:choose(g)
            return
        end
        if love.math.random() < dt * 12 then
            local a = love.math.random() * math.pi * 2
            local col = util.hex(g.def.color)
            w.particles:spawn(g.x + math.cos(a) * 12, g.y + math.sin(a) * 12, 1, 0, 0, 20, 0.8, col, 1, { glow = true, grav = -20 })
        end
    end
end

function Routes:drawWorld()
    if not self.gates then return end
    local lg = love.graphics
    local t = self.world.time
    for _, g in ipairs(self.gates) do
        local x, y = Iso.toScreen(g.x, g.y)
        local col = util.hex(g.def.color)
        local r = self.rewards.cfg.routes.radius
        lg.setColor(0.05, 0.03, 0.02, 0.85)
        lg.ellipse("fill", x, y, r * 0.8, r * 0.4)
        lg.setColor(col[1], col[2], col[3], 0.6 + 0.3 * math.sin(t * 5))
        lg.setLineWidth(2)
        lg.ellipse("line", x, y, r, r * 0.5)
        lg.setLineWidth(1)
        lg.setColor(col[1], col[2], col[3], 0.35)
        local k = (t * 0.8) % 1
        lg.ellipse("line", x, y, r * (1 + k * 0.6), r * 0.5 * (1 + k * 0.6))
    end
    lg.setColor(1, 1, 1, 1)
end

-- Names over the tunnels (window pixels), and the route of the running wave.
function Routes:drawHud(alpha)
    local w = self.world
    local lg = love.graphics
    local u = Theme.u
    if self.gates and not w.pendingChoice then
        for _, g in ipairs(self.gates) do
            local x, y = w:toWindow(g.x, g.y, 18)
            local col = util.hex(g.def.color)
            lg.setFont(Theme.font(16, "bold"))
            local name = g.def.name
            local fw = lg.getFont():getWidth(name)
            Theme.printShadow(name, math.floor(x - fw / 2), math.floor(y - u(58)), { col[1], col[2], col[3], alpha })
            lg.setFont(Theme.font(14))
            local bw = u(170)
            local _, lines = lg.getFont():getWrap(g.def.description, bw)
            for i, line in ipairs(lines) do
                fw = lg.getFont():getWidth(line)
                Theme.printShadow(line, math.floor(x - fw / 2), math.floor(y - u(40) + (i - 1) * u(16)), { 1, 0.95, 0.85, alpha * 0.9 })
            end
        end
    end
end

return Routes
