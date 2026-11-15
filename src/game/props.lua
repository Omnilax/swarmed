-- Props: things in the arena that are neither the player nor an enemy (content/props, see
-- _template.lua). They are never in the enemy list, so they never hold a wave up, the ants
-- ignore them, and the player's attacks only reach them through Props:attacked.
--
--   pushable props (pebbles, twigs, fallen acorns) are shoved by walking into them, launched by
--   a dash or an attack, and flatten every ant they roll over while they are moving fast.
--   Others do their own thing in update / onHit: web cocoons (break one to free an ally), the
--   bug you freed fighting beside you, the merchant beetle.
--
-- Instances: { def, id, x, y, vx, vy, z, r, angle, t, st (own state), hp, life (seconds, or nil),
--   dead }. Fields passed in opts to Props:spawn are copied onto the instance.
local Content = require("src.content")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")
local Env = require("src.game.envfx")

local Props = {}
Props.__index = Props

Props.MAX = 60      -- props kept at once (the oldest pushable one makes way)

local nextUid = 0

function Props.new(world)
    return setmetatable({ world = world, list = {} }, Props)
end

function Props:spawn(id, x, y, opts)
    local def = Content.props:require(id)
    nextUid = nextUid + 1
    local o = { def = def, id = def.id, uid = nextUid, x = x, y = y, vx = 0, vy = 0, z = 0, r = def.radius,
        angle = 0, t = 0, st = {}, hp = def.hp, hitSet = {} }
    for k, v in pairs(opts or {}) do o[k] = v end
    -- def.max: at most this many of one kind (the oldest goes)
    if def.max then
        local mine = {}
        for _, old in ipairs(self.list) do if old.id == def.id and not old.dead then mine[#mine + 1] = old end end
        if #mine >= def.max then mine[1].dead = true end
    end
    if #self.list >= Props.MAX then
        for i, old in ipairs(self.list) do
            if old.def.pushable then table.remove(self.list, i) break end
        end
    end
    self.list[#self.list + 1] = o
    if def.init then def.init(self.world, o) end
    return o
end

function Props:count(id)
    local n = 0
    for _, o in ipairs(self.list) do if not o.dead and (not id or o.id == id) then n = n + 1 end end
    return n
end

function Props:find(id)
    local out = {}
    for _, o in ipairs(self.list) do if not o.dead and o.id == id then out[#out + 1] = o end end
    return out
end

function Props:clear(id)
    for _, o in ipairs(self.list) do
        if not id or o.id == id then o.dead = true end
    end
end

-- The two ends of a long prop (twig), or nil for a round one.
local function ends(o)
    local L = o.def.length
    if not L then return nil end
    local cx, cy = math.cos(o.angle) * L / 2, math.sin(o.angle) * L / 2
    return o.x - cx, o.y - cy, o.x + cx, o.y + cy
end

-- Distance from a point to the prop's body (centre for round props, the stick for twigs).
function Props.distance(o, x, y)
    local x1, y1, x2, y2 = ends(o)
    if not x1 then return math.sqrt((x - o.x) ^ 2 + (y - o.y) ^ 2) end
    return math.sqrt((Env.segDist2(x, y, x1, y1, x2, y2)))
end

-- Send a pushable prop flying along (dx, dy) at `speed`; it can hit every ant once again.
function Props:launch(o, dx, dy, speed)
    local l = math.sqrt(dx * dx + dy * dy) + 0.0001
    o.vx, o.vy = dx / l * speed, dy / l * speed
    o.hitSet = {}
    if o.def.spinOnLaunch then o.spin = (love.math.random() - 0.5) * o.def.spinOnLaunch end
    Audio.play("dash", { pitch = 0.7 + love.math.random() * 0.2 })
end

function Props:physics(o, dt)
    local world, def = self.world, o.def
    local p = world.player
    local S = world.size
    -- the player bumps it along, or launches it with a dash
    if not p.dead and (p.z or 0) < 6 then
        local d = Props.distance(o, p.x, p.y)
        local reach = p.radius + o.r
        if d < reach then
            local dx, dy = o.x - p.x, o.y - p.y
            local x1, y1, x2, y2 = ends(o)
            if x1 then
                -- push a stick at the point touched: away from the player, square to the stick
                local nx, ny = -math.sin(o.angle), math.cos(o.angle)
                if nx * dx + ny * dy < 0 then nx, ny = -nx, -ny end
                dx, dy = nx, ny
            end
            local l = math.sqrt(dx * dx + dy * dy) + 0.0001
            dx, dy = dx / l, dy / l
            if p.dashT > 0 then
                if o.dashedBy ~= world.director.dashNo then
                    o.dashedBy = world.director.dashNo
                    self:launch(o, dx * 0.4 + (p.dashX or dx) * 0.6, dy * 0.4 + (p.dashY or dy) * 0.6, def.dashSpeed or 280)
                end
            else
                -- slide out of the player, and roll on at walking pace
                local push = (reach - d)
                o.x, o.y = o.x + dx * push, o.y + dy * push
                local pv = math.max(30, math.sqrt((p.vx or 0) ^ 2 + (p.vy or 0) ^ 2)) * (def.shove or 1.15) / (def.mass or 1) ^ 0.3
                local along = o.vx * dx + o.vy * dy
                if along < pv then o.vx, o.vy = o.vx + dx * (pv - along), o.vy + dy * (pv - along) end
            end
        end
    end
    -- roll, slow down, bounce off the walls
    o.x, o.y = o.x + o.vx * dt, o.y + o.vy * dt
    local m = o.r
    if o.x < m then o.x, o.vx = m, math.abs(o.vx) * 0.5 elseif o.x > S - m then o.x, o.vx = S - m, -math.abs(o.vx) * 0.5 end
    if o.y < m then o.y, o.vy = m, math.abs(o.vy) * 0.5 elseif o.y > S - m then o.y, o.vy = S - m, -math.abs(o.vy) * 0.5 end
    local f = math.exp(-(def.friction or 2.5) * dt)
    o.vx, o.vy = o.vx * f, o.vy * f
    local speed = math.sqrt(o.vx * o.vx + o.vy * o.vy)
    if def.length then
        -- a rolling stick turns square to the way it rolls
        if o.spin then o.angle = o.angle + o.spin * dt o.spin = o.spin * f end
        if speed > 10 then
            local want = math.atan2(o.vy, o.vx) + math.pi / 2
            local diff = (want - o.angle + math.pi) % math.pi - math.pi / 2
            o.angle = o.angle + diff * math.min(1, dt * 3)
        end
    elseif def.roll then
        o.roll = (o.roll or 0) + speed * dt / math.max(2, o.r)
    end
    if speed < 4 then
        o.vx, o.vy = 0, 0
        if next(o.hitSet) then o.hitSet = {} end
        return
    end
    -- flatten ants it rolls over while it is going fast
    if speed >= (def.crushSpeed or 55) then
        local hits
        local x1, y1, x2, y2 = ends(o)
        if x1 then hits = Combat.collectLine(world, x1, y1, x2, y2, o.r) else hits = Combat.collect(world, o.x, o.y, o.r) end
        local dmg = (def.damage or 12) * math.min(2, speed / 160) * (1 + math.max(0, (world.spawner.wave or 1) - 1) * 0.08)
        for _, e in ipairs(hits) do
            if not o.hitSet[e.uid] then
                o.hitSet[e.uid] = true
                local killed = Env.hurtAnt(world, e, dmg, { force = speed * 0.8, kx = o.vx, ky = o.vy })
                if killed then world:floatText(e.x, e.y, "SQUASH", { 0.95, 0.85, 0.6 }) end
                -- heavy ants slow it down
                local k = math.max(0.75, 1 - e.mass * 0.03 / (def.mass or 1))
                o.vx, o.vy = o.vx * k, o.vy * k
            end
        end
    end
end

function Props:update(dt)
    local world = self.world
    for i = #self.list, 1, -1 do
        local o = self.list[i]
        if not o.dead then
            o.t = o.t + dt
            if o.def.pushable then self:physics(o, dt) end
            if o.def.update then o.def.update(world, o, dt) end
            if o.life and o.t >= o.life then o.dead = true end
        end
        if o.dead then
            if o.def.remove then o.def.remove(world, o) end
            table.remove(self.list, i)
        end
    end
end

-- An attack from (px, py) aimed along (ax, ay) with reach `range`: props in front get hit.
function Props:attacked(px, py, ax, ay, range)
    local world = self.world
    local p = world.player
    for _, o in ipairs(self.list) do
        local def = o.def
        if not o.dead and (def.pushable or def.onHit) then
            local d = Props.distance(o, px, py)
            local dx, dy = o.x - px, o.y - py
            local l = math.sqrt(dx * dx + dy * dy) + 0.0001
            local facing = (dx * ax + dy * ay) / l
            if d <= range + o.r * 0.5 and (d < p.radius + o.r + 6 or facing > 0.25) then
                if def.pushable then
                    local kb = 1 + p.stats:get("knockback") / 200
                    self:launch(o, dx / l + ax * 0.5, dy / l + ay * 0.5, (def.batSpeed or 230) * kb)
                    world.particles:sparks(o.x, o.y, 3, { 1, 0.95, 0.8 }, dx, dy)
                end
                if def.onHit then def.onHit(world, o, 1, dx / l, dy / l) end
            end
        end
    end
end

-- A dash through a prop with onHit (cocoon): a full-strength hit, once per dash.
function Props:dashHits()
    local world = self.world
    local p = world.player
    if p.dead or p.dashT <= 0 then return end
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.onHit and not o.def.pushable and o.dashedBy ~= world.director.dashNo
            and Props.distance(o, p.x, p.y) < p.radius + o.r then
            o.dashedBy = world.director.dashNo
            o.def.onHit(world, o, o.def.dashHit or 1, o.x - p.x, o.y - p.y)
        end
    end
end

function Props:draw()
    local world, lg = self.world, love.graphics
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.draw then
            local sx, sy = Iso.toScreen(o.x, o.y, o.z)
            o.def.draw(world, o, math.floor(sx), math.floor(sy))
        end
    end
    lg.setColor(1, 1, 1, 1)
end

function Props:drawAir()
    local world, lg = self.world, love.graphics
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.drawAir then
            local sx, sy = Iso.toScreen(o.x, o.y, o.z)
            o.def.drawAir(world, o, math.floor(sx), math.floor(sy))
        end
    end
    lg.setColor(1, 1, 1, 1)
end

-- Text labels over props (the merchant's price), drawn in window space by the HUD.
function Props:drawLabels(fontFn)
    local world, lg = self.world, love.graphics
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.label then
            local text, color = o.def.label(world, o)
            if text then
                local wx, wy = world:toWindow(o.x, o.y, (o.def.labelZ or 24) + o.z)
                local f = fontFn()
                lg.setFont(f)
                local w = f:getWidth(text)
                lg.setColor(0, 0, 0, 0.75)
                lg.print(text, math.floor(wx - w / 2) + 1, math.floor(wy) + 1)
                local c = color or { 1, 1, 1 }
                lg.setColor(c[1], c[2], c[3], 1)
                lg.print(text, math.floor(wx - w / 2), math.floor(wy))
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Props
