-- Props: things in the arena that are neither the player nor an enemy (content/props, see
-- _template.lua). They are never in the enemy list, so they never hold a wave up, the ants
-- ignore them, and the player's attacks only reach them through Props:attacked.
--
--   pushable props (pebbles, twigs, fallen acorns) are shoved by walking into them, launched by
--   a dash or an attack, and flatten every ant they roll over while they are moving fast. A hit
--   pops them off the ground (they bounce and settle), squashes them, chips bits off and spins a
--   stick by where it was struck; blasts scatter them; they knock into each other like marbles.
--   Grab attacks can pick them up like an ant (src/game/grab.lua, Grab.collect): a held prop is
--   placed by its holder, and a thrown one bowls through the crowd, crashes down and rolls on.
--   Others do their own thing in update / onHit: web cocoons (break one to free an ally), the
--   bug you freed fighting beside you, the merchant beetle.
--
-- Instances: { def, id, x, y, vx, vy, z, vz, r, angle, t, st (own state), hp, life (seconds, or nil),
--   dead }. Pushable ones also carry isProp, radius (size when grabbed), mass and held, so the
--   grab code can treat them like an ant. Fields passed in opts to Props:spawn are copied onto the instance.
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
    if def.pushable then
        o.isProp, o.vz = true, 0
        o.radius = o.radius or def.grabRadius or o.r
        o.mass = o.mass or def.mass or 1
    end
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

-- What a prop is made of: the bits that chip off it and how it sounds when struck.
local MATERIAL = {
    stone = { chips = { { 0.62, 0.6, 0.56 }, { 0.42, 0.4, 0.38 }, { 0.8, 0.78, 0.72 } }, pitch = 1.5, dust = { 0.7, 0.65, 0.55 } },
    wood = { chips = { { 0.52, 0.36, 0.2 }, { 0.36, 0.24, 0.12 }, { 0.7, 0.55, 0.32 } }, pitch = 1.05, dust = { 0.6, 0.5, 0.35 } },
    shell = { chips = { { 0.95, 0.88, 0.78 }, { 0.85, 0.7, 0.62 }, { 0.7, 0.6, 0.5 } }, pitch = 1.8, dust = { 0.85, 0.78, 0.62 } },
    nut = { chips = { { 0.72, 0.46, 0.2 }, { 0.5, 0.4, 0.24 }, { 0.38, 0.3, 0.17 } }, pitch = 0.85, dust = { 0.6, 0.5, 0.35 } },
}
Props.MATERIAL = MATERIAL
local function material(o) return MATERIAL[o.def.material or "stone"] or MATERIAL.stone end

local GRAVITY = 700

-- Send a pushable prop flying along (dx, dy) at `speed`; it can hit every ant once again.
-- hop: how hard it pops off the ground (upward speed, px/s; default from the speed).
function Props:launch(o, dx, dy, speed, hop)
    local l = math.sqrt(dx * dx + dy * dy) + 0.0001
    local m = (o.def.mass or 1) ^ 0.25
    o.vx, o.vy = dx / l * speed, dy / l * speed
    o.vz = math.max(o.vz or 0, hop or math.min(160, speed * 0.32 / m))
    o.hitSet = {}
    if o.def.spinOnLaunch then o.spin = (o.spin or 0) + (love.math.random() - 0.5) * o.def.spinOnLaunch end
    Audio.play("dash", { pitch = 0.7 + love.math.random() * 0.2 })
end

-- A prop struck (by a swing, a sting, a squeeze): it squashes, flashes and chips. `power` ~1.
function Props:struck(o, power, dx, dy)
    local world, mat = self.world, material(o)
    power = power or 1
    o.squash = math.min(0.45, 0.18 + power * 0.12)
    o.flash = 0.08
    world.particles:burst(o.x, o.y, math.floor(2 + power * 3), mat.chips, 50 + power * 40, 50 + power * 30, { grav = 380 })
    if dx and (dx ~= 0 or dy ~= 0) then
        world.particles:sparks(o.x, o.y, 2, { 1, 0.95, 0.8 }, dx, dy)
    end
    Audio.play("hit", { pitch = mat.pitch + love.math.random() * 0.2, volume = 0.55 })
end

-- A blast at (x, y): pushable props within `radius` are thrown out and up.
function Props:blast(x, y, radius, force)
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.pushable and not o.held then
            local dx, dy = o.x - x, o.y - y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < radius + o.r then
                local k = 1 - math.min(1, d / (radius + o.r)) * 0.6
                local m = (o.def.mass or 1) ^ 0.5
                if d < 0.5 then dx, dy = love.math.random() - 0.5, love.math.random() - 0.5 end
                self:launch(o, dx, dy, (force or 260) * k / m, (force or 260) * 0.6 * k / m)
                if o.def.length then o.spin = (o.spin or 0) + (love.math.random() - 0.5) * 14 end
            end
        end
    end
end

function Props:physics(o, dt)
    local world, def = self.world, o.def
    local p = world.player
    local S = world.size
    if o.squash and o.squash > 0 then o.squash = math.max(0, o.squash - dt * 2.2) end
    if o.flash and o.flash > 0 then o.flash = o.flash - dt end
    -- picked up: whoever holds it moves it (Grab.place / a throw). If nobody has for a moment
    -- (the holder let go some other way), it drops.
    if o.held then
        o.heldPing = (o.heldPing or 0) + dt
        if o.heldPing < 0.35 then return end
        o.held = nil
    end
    -- in the air: arc down, bounce, settle
    if o.z > 0 or o.vz > 0 then
        o.vz = o.vz - GRAVITY * dt
        o.z = o.z + o.vz * dt
        if o.z <= 0 then
            o.z = 0
            local impact = -o.vz
            if impact > 90 then
                o.vz = impact * (def.bounce or 0.38)
                o.squash = math.min(0.4, impact / 600)
                world.particles:burst(o.x, o.y, 3, { material(o).dust }, 30, 15, { grav = 200 })
                if impact > 160 then Audio.play("hit", { pitch = material(o).pitch * 0.7, volume = 0.35 }) end
                -- a stick lands on one end and flips round
                if def.length then o.spin = (o.spin or 0) + (love.math.random() - 0.5) * impact * 0.02 end
            else
                o.vz = 0
            end
        end
    end
    -- the player bumps it along, or launches it with a dash
    if not p.dead and (p.z or 0) < 6 and o.z < 8 then
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
    -- flatten ants it rolls over while it is going fast (and low enough to reach them)
    if speed >= (def.crushSpeed or 55) and o.z < o.r + 6 then
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

-- Moving pushable props knock into each other: a pebble rolled into a pebble sends it on, like
-- marbles (heavier ones give less). A stick collides along its length.
function Props:collide()
    local list = self.list
    local n = #list
    for i = 1, n do
        local a = list[i]
        if not a.dead and a.def.pushable and not a.held and a.z < 6 then
            local aMoving = a.vx * a.vx + a.vy * a.vy > 400
            for j = i + 1, n do
                local b = list[j]
                if not b.dead and b.def.pushable and not b.held and b.z < 6
                    and (aMoving or b.vx * b.vx + b.vy * b.vy > 400)
                    and not (a.def.length and b.def.length) then
                    -- the round one against the other's body (a stick's line, or a centre)
                    local round, other = a, b
                    if a.def.length then round, other = b, a end
                    local d = Props.distance(other, round.x, round.y)
                    local reach = round.r + other.r
                    if d < reach then
                        -- the normal: from the closest point on the other to the round one
                        local nx, ny
                        if other.def.length then
                            nx, ny = -math.sin(other.angle), math.cos(other.angle)
                            if nx * (round.x - other.x) + ny * (round.y - other.y) < 0 then nx, ny = -nx, -ny end
                        else
                            nx, ny = round.x - other.x, round.y - other.y
                            local l = math.sqrt(nx * nx + ny * ny)
                            if l < 0.01 then nx, ny, l = 1, 0, 1 end
                            nx, ny = nx / l, ny / l
                        end
                        local ma, mb = round.def.mass or 1, other.def.mass or 1
                        -- push apart
                        local over = reach - d
                        round.x, round.y = round.x + nx * over * mb / (ma + mb), round.y + ny * over * mb / (ma + mb)
                        other.x, other.y = other.x - nx * over * ma / (ma + mb), other.y - ny * over * ma / (ma + mb)
                        -- trade momentum along the normal (a bit springy)
                        local rel = (round.vx - other.vx) * nx + (round.vy - other.vy) * ny
                        if rel < 0 then
                            local jimp = -(1 + 0.75) * rel / (1 / ma + 1 / mb)
                            round.vx, round.vy = round.vx + nx * jimp / ma, round.vy + ny * jimp / ma
                            other.vx, other.vy = other.vx - nx * jimp / mb, other.vy - ny * jimp / mb
                            round.hitSet, other.hitSet = {}, {}
                            if other.def.length then other.spin = (other.spin or 0) + (love.math.random() - 0.5) * 6 end
                            if -rel > 60 then
                                self.world.particles:sparks((round.x + other.x) / 2, (round.y + other.y) / 2, 2, { 1, 0.95, 0.8 }, nx, ny)
                                Audio.play("hit", { pitch = material(round).pitch + 0.3, volume = math.min(0.5, -rel / 500) })
                            end
                        end
                    end
                end
            end
        end
    end
end

function Props:update(dt)
    local world = self.world
    self:collide()
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
-- power (~0.7..1.8, from the move's damage) sets how hard: how far they fly and how high they pop.
function Props:attacked(px, py, ax, ay, range, power)
    local world = self.world
    local p = world.player
    power = power or 1
    for _, o in ipairs(self.list) do
        local def = o.def
        if not o.dead and not o.held and (def.pushable or def.onHit) then
            local d = Props.distance(o, px, py)
            local dx, dy = o.x - px, o.y - py
            local l = math.sqrt(dx * dx + dy * dy) + 0.0001
            local facing = (dx * ax + dy * ay) / l
            if d <= range + o.r * 0.5 and (d < p.radius + o.r + 6 or facing > 0.25) then
                if def.pushable then
                    local kb = 1 + p.stats:get("knockback") / 200
                    -- closer hits land harder; a wee bit of scatter so no two hits look alike
                    local near = 1.15 - 0.3 * math.min(1, d / math.max(1, range))
                    local jit = (love.math.random() - 0.5) * 0.3
                    local bx, by = dx / l + ax * 0.5, dy / l + ay * 0.5
                    bx, by = bx - by * jit, by + bx * jit
                    self:launch(o, bx, by, (def.batSpeed or 230) * kb * power * near)
                    -- a stick struck off-centre spins round its middle
                    if def.length then
                        local ux, uy = math.cos(o.angle), math.sin(o.angle)
                        local along = ((px + ax * d) - o.x) * ux + ((py + ay * d) - o.y) * uy
                        local cross = ux * ay - uy * ax
                        o.spin = (o.spin or 0) - cross * (along / (def.length / 2)) * 10 * power + (love.math.random() - 0.5) * 2
                    end
                    self:struck(o, power, dx, dy)
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

-- Lifted (held, thrown, popped high) props draw over the crowd, with a shadow on the ground.
local function lifted(o) return o.isProp and (o.held or o.z > 4) end

-- Struck props flash pale for a moment (their colours pulled toward white).
local flashShader
local function getFlash()
    if flashShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            extern number amount;
            vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
                vec4 c = Texel(tex, uv) * color;
                return vec4(mix(c.rgb, vec3(1.0, 0.97, 0.9), amount), c.a);
            }
        ]])
        flashShader = ok and sh or false
    end
    return flashShader or nil
end

local function drawBody(world, o)
    local lg = love.graphics
    local sx, sy = Iso.toScreen(o.x, o.y, o.z)
    sx, sy = math.floor(sx), math.floor(sy)
    local sq = o.squash or 0
    if sq > 0.01 then
        lg.push()
        lg.translate(sx, sy)
        lg.scale(1 + sq * 0.6, 1 - sq * 0.5)
        lg.translate(-sx, -sy)
    end
    local sh = (o.flash or 0) > 0 and getFlash()
    if sh then
        sh:send("amount", math.min(0.75, o.flash * 10))
        lg.setShader(sh)
    end
    o.def.draw(world, o, sx, sy)
    if sh then lg.setShader() end
    if sq > 0.01 then lg.pop() end
end

function Props:draw()
    local world, lg = self.world, love.graphics
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.draw and not lifted(o) then drawBody(world, o) end
    end
    lg.setColor(1, 1, 1, 1)
end

function Props:drawAir()
    local world, lg = self.world, love.graphics
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.draw and lifted(o) then
            local gx, gy = Iso.toScreen(o.x, o.y, 0)
            local k = math.max(0.4, 1 - o.z / 60)
            lg.setColor(0, 0, 0, 0.3 * k)
            lg.ellipse("fill", math.floor(gx), math.floor(gy) + 1, (o.def.length and 10 or o.r * 1.3) * k, o.r * 0.6 * k)
            drawBody(world, o)
        end
    end
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.drawAir then
            local sx, sy = Iso.toScreen(o.x, o.y, o.z)
            o.def.drawAir(world, o, math.floor(sx), math.floor(sy))
        end
    end
    lg.setColor(1, 1, 1, 1)
end

local function printLabel(world, fontFn, text, color, x, y, z, align)
    local lg = love.graphics
    local wx, wy = world:toWindow(x, y, z)
    local f = fontFn()
    lg.setFont(f)
    local w = f:getWidth(text)
    -- align: "center" (default), "left" (text starts at the point), "right" (text ends there)
    if align == "left" then wx = wx + w / 2 + 8 elseif align == "right" then wx = wx - w / 2 - 8 end
    if align then wy = wy - f:getHeight() / 2 end
    lg.setColor(0, 0, 0, 0.75)
    lg.print(text, math.floor(wx - w / 2) + 1, math.floor(wy) + 1)
    local c = color or { 1, 1, 1 }
    lg.setColor(c[1], c[2], c[3], 1)
    lg.print(text, math.floor(wx - w / 2), math.floor(wy))
end

-- Text labels over props (the merchant's price), drawn in window space by the HUD. A prop's
-- `label` returns one text and colour; `labels` returns a list of { text, color, x, y, z, align }
-- (x, y, z default to the prop and its labelZ), for props with several things to read (a shrine's
-- blessings).
function Props:drawLabels(fontFn)
    local world, lg = self.world, love.graphics
    for _, o in ipairs(self.list) do
        if not o.dead and o.def.label then
            local text, color = o.def.label(world, o)
            if text then printLabel(world, fontFn, text, color, o.x, o.y, (o.def.labelZ or 24) + o.z) end
        end
        if not o.dead and o.def.labels then
            for _, l in ipairs(o.def.labels(world, o) or {}) do
                printLabel(world, fontFn, l.text, l.color, l.x or o.x, l.y or o.y, (l.z or o.def.labelZ or 24) + o.z, l.align)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return Props
