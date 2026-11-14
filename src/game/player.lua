-- The player's bug: movement, dash, aiming, attacking and taking damage.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Sprites = require("src.gfx.sprites")
local Anim = require("src.gfx.anim")
local Stats = require("src.game.stats")
local Inventory = require("src.game.inventory")
local Skills = require("src.game.skills")
local Stamina = require("src.game.stamina")

local Player = {}
Player.__index = Player

local DASH_TIME, DASH_SPEED = 0.16, 420
Player.DASH_SPEED = DASH_SPEED

-- Queue something for later (attacks with several beats).
function Player:after(t, fn) self.delayed[#self.delayed + 1] = { t = t, fn = fn, move = self.curMove } end

-- Move fast along (dx, dy) for `dist` units, like a dash (afterimages included). Only the
-- start of a dash is untouchable (DASH_GUARD of it); the tail end can be bitten, so dashing
-- into a crowd is a risk. Jumps and flight get more (see the dash start in Player:update).
local DASH_GUARD = 0.55
Player.DASH_GUARD = DASH_GUARD
function Player:lunge(dx, dy, dist, speedMul)
    local sp = DASH_SPEED * (speedMul or 1)
    self.dashX, self.dashY = dx * (speedMul or 1), dy * (speedMul or 1)
    self.dashT = dist / sp
    self.iframes = math.max(self.iframes, self.dashT * DASH_GUARD + 0.03)
end

-- Letting go of a block shoves everything nearby away, to give room to escape.
-- Dash params: releaseRadius (40), releaseShove (300)
function Player:releaseShove(params)
    local Combat = require("src.game.combat")
    local world = self.world
    local r = (params.releaseRadius or 40) * (1 + self.stats:get("area") / 100)
    for _, e in ipairs(Combat.collect(world, self.x, self.y, r)) do
        local dx, dy, l = util.normalize(e.x - self.x, e.y - self.y)
        if l < 0.01 then dx, dy = self.aimX, self.aimY end
        local f = (params.releaseShove or 300) * (1.2 - 0.5 * math.min(1, l / r)) / math.max(0.5, e.mass) ^ 0.5
        e.kvx, e.kvy = e.kvx + dx * f, e.kvy + dy * f
    end
    self.iframes = math.max(self.iframes, 0.15)
    world:addFx({ kind = "ring", x = self.x, y = self.y, r = r, life = 0.22, color = { 0.85, 0.92, 1 } })
    world.particles:burst(self.x, self.y, 8, { { 0.8, 0.85, 0.9 } }, 110, 10, { grav = 120 })
    Audio.play("dash", { pitch = 0.7, volume = 0.6 })
end

function Player.new(world, def, x, y)
    local self = setmetatable({ world = world, x = x, y = y }, Player)
    self:setCharacter(def)
    self.hp = self.stats:get("maxHp")
    return self
end

-- Also used by the sandbox to swap characters mid-run (items are kept).
function Player:setCharacter(def)
    local oldInv = self.inventory
    self.def = def
    self.radius = def.radius
    self.stats = Stats.new(def.stats)
    self.inventory = Inventory.new(self)
    if oldInv then
        oldInv:transferTo(self.inventory)
    else
        for _, id in ipairs(def.startingItems) do self.inventory:add(id) end
    end
    self.attack = { type = Content.attacks:require(def.attack.type), params = def.attack, timer = 0.3 }
    -- right click: a slower, stronger special with its own cooldown
    local sec = def.secondary
    self.secondary = sec and { type = Content.attacks:require(sec.type), params = sec, timer = 0 } or nil
    -- Shift: each bug has its own kind of dash (content/dashes)
    if self.stamina then Stamina.stop(self) end
    self.stamina, self.holdMode, self.runMul, self.liftZ = nil, nil, nil, nil
    local dash = def.dash or { type = "dash" }
    self.dashDef, self.dashParams = Content.dashes:require(dash.type), dash
    -- skill tree: rebuilds the params above from the def plus bought nodes (XP kept on a swap)
    self.skills = Skills.new(self, self.skills and self.skills.xp)
    self.skills:apply()
    self.dashCharges = self.dashParams.charges or 1
    Stamina.state(self)
    self.blocking, self.blockFxT, self.dashHop, self.z, self.dashHit, self.grapple = false, 0, 0, 0, nil, nil
    self.sprite = Sprites.get(def.sprite)
    self.shadow = Sprites.shadowFor(self.sprite.w * 0.9 * (def.scale or 1))
    self.angle, self.anim, self.wangle = 0, 0, 0
    self.model = def.model
    -- chain bodies (centipede): each segment's world position, trailing behind the head
    self.chain = nil
    if def.model and def.model.kind == "chain" then
        self.chain = {}
        for i = 1, def.model.segments do self.chain[i] = { x = (self.x or 0) - i * def.model.spacing, y = self.y or 0 } end
    end
    self.iframes, self.flash = 0, 0
    -- animation state: lunge (attack), recoil (hurt), dash ghosts, breathing
    self.lungeT, self.recoilT, self.ghosts, self.ghostT, self.idleT = 0, 0, {}, 0, 0
    self.kvx, self.kvy, self.slowMul = 0, 0, 1     -- knockback velocity, honey slow
    self.momX, self.momY, self.ropeVX, self.ropeVY = 0, 0, nil, nil
    if self.carry then
        local Grab = require("src.game.grab")
        Grab.release(self.carry.h)
        for _, h in ipairs(self.carry.list or {}) do Grab.release(h) end
    end
    self.carry, self.weave, self.tailStab, self.rear, self.brood = nil, nil, nil, nil, nil   -- specials' state (grabs, web walls)
    -- batch 2 move state: speed / damage taken multipliers, chain posing, burrowed or cloaked look
    self.moveMul, self.guardMul, self.chainPose, self.hidden, self.alpha, self.cloakT, self.coil = nil, nil, nil, nil, nil, nil, nil
    -- hold-and-release dashes (mantis shrimp wind-up, centipede reversed / flipping, vinegaroon skip)
    self.recoil, self.reversed, self.flip, self.skip = nil, nil, nil, nil
    -- batch 1 move state: dragonfly flight, dung ball, stink shield; ward(player, amount, source)
    -- returning true makes Player:hurt ignore a hit
    self.airborne, self.flight, self.dung, self.stinkShieldT, self.ward = nil, nil, nil, nil, nil
    self.slowT, self.slowAmt = 0, 1                 -- timed slow (pebble daze)
    self.venomT, self.venomDps, self.venomTick = 0, 0, 0   -- poison from venomous bites
    self.stunT, self.blindT, self.gumT, self.gumMul = 0, 0, 0, 1   -- paralysed, blinded, attacks gummed up (bees, wasps)
    self.stepFrame, self._anims = 0, nil
    self.delayed = {}       -- attack follow-ups: { t = seconds, fn = function(player, world) }
    self.hurtFxT, self.dmgAccum, self.dmgShowT = 0, 0, 0
    self.dashT, self.dashCd, self.dashX, self.dashY = 0, 0, 0, 0
    self.aimX, self.aimY = 1, 0
    self.moving = false
    if self.hp then self.hp = math.min(self.hp, self.stats:get("maxHp")) end
end

-- A swish for every attack: slow, heavy moves sound lower; quick jabs are higher and softer.
function Player.swingSound(params, special)
    local cd = params.cooldown or 0.5
    if special then
        Audio.play("special", { pitch = 0.9 + love.math.random() * 0.2 })
    else
        Audio.play("swing", { pitch = math.max(0.7, math.min(1.5, 1.25 - cd * 0.5)), volume = math.min(1, 0.45 + cd) })
    end
end

-- Fire the main attack now (manual attacks call this when they let go). extra is passed on
-- to the attack's fire as its sixth argument (e.g. how long a punch was charged).
function Player:releaseAttack(ax, ay, extra)
    local atk = self.attack
    if atk.timer > 0 then return false end
    local params = self.skills:before("attack", atk.params)
    atk.type.fire(self, self.world, ax, ay, params, extra)
    self.skills:after("attack", ax, ay, nil, nil, params)
    Anim.move(self, "attack", atk.params)
    Player.swingSound(atk.params, false)
    self.lungeT = 0.18
    self.wangle = math.atan2(ay, ax)
    atk.timer = atk.params.cooldown
    return true
end

-- The same for a manual special (hold right click to aim, let go to fire: the pistol shrimp's
-- snap shot). The type sets manual = true and calls this from its update.
function Player:releaseSecondary(ax, ay, px, py, extra)
    local sec = self.secondary
    if not sec or sec.timer > 0 then return false end
    local params = self.skills:before("secondary", sec.params)
    sec.type.fire(self, self.world, ax, ay, params, px, py, extra)
    self.skills:after("secondary", ax, ay, px, py, params)
    Anim.move(self, "secondary", sec.params)
    Player.swingSound(sec.params, true)
    sec.timer = sec.params.cooldown
    self.lungeT = 0.18
    self.wangle = math.atan2(ay, ax)
    return true
end

-- Which way to face while walking along (wx, wy) with nothing to aim at: straight ahead, or
-- for sideways walkers (crab) side-on, keeping whichever side was already leading.
function Player:walkFacing(wx, wy)
    if not self.def.sideways then return wx, wy end
    local lx, ly = -wy, wx
    if lx * self.aimX + ly * self.aimY < 0 then lx, ly = wy, -wx end
    return lx, ly
end

function Player:attackRange()
    local t = self.attack.type
    -- enemy AI asks this every frame, so a move without a sensible range must not crash it
    if t.range then
        local r = t.range(self.attack.params, self)
        if type(r) == "number" and r == r then return r end
    end
    return (self.attack.params.radius or self.attack.params.reach or 40) * (1 + self.stats:get("area") / 100)
end

function Player:update(dt)
    local world = self.world
    if self.dead then return end
    local demo = world.flags.demo     -- title-screen attract mode: wander and fight on its own
    local mx, my
    if demo then
        local t = world.time * 0.35
        mx, my = math.cos(t) * 0.5, math.sin(t * 2) * 0.35
    else
        mx, my = Input.moveVector()
    end
    -- paralysed (tarantula hawk sting): no walking, dashing or attacking until it wears off
    local stunned = self.stunT > 0
    if stunned then
        mx, my = 0, 0
        -- struggle: mashing dash or attack wears the paralysis off faster
        if not demo and (Input.pressed("dash") or Input.pressed("attack")) then self.stunT = self.stunT - 0.2 end
    end
    local mag = util.len(mx, my)
    local wx, wy = Iso.screenDirToWorld(mx, my)
    self.moving = mag > 0.1

    -- Dash: each bug's own kind (content/dashes), all paid for from one stamina pool
    -- (src/game/stamina.lua), which refills faster with Dash Cooldown items.
    local dd, dp = self.dashDef, self.dashParams
    Stamina.update(self, dt)
    if dd.hold then
        local wasBlocking = self.blocking
        local held = not demo and Input.down("dash")
        if dd.blocked then held = Stamina.guard(self, dt, dp, held) end
        dd.update(self, world, dt, dp, held)
        if wasBlocking and not self.blocking and dd.blocked then self:releaseShove(dp) end
        if (self.blocking or self.holdMode) and not (self._anims and self._anims.dash) then Anim.move(self, "dash", dp) end
    elseif not demo and not stunned and Input.pressed("dash") and self.dashT <= 0.04 and not self.grapple
        and ((dd.free and dd.free(self)) or Stamina.hasCharge(self)) then
        if not (dd.free and dd.free(self)) then Stamina.spendCharge(self) end
        local dx, dy = self.aimX, self.aimY
        if self.moving then dx, dy = wx, wy end
        local px, py = self:pointer()
        self.dashHop, self.dashHit, self.dashT0 = 0, nil, nil
        dd.start(self, world, dx, dy, dp, px, py)
        -- jumps (a hop of any height) and flights stay untouchable for nearly the whole move;
        -- a dash def or a character's dash params can set their own share with iframes = 0..1
        local guard = dp.iframes or dd.iframes
        if self.dashHop >= 6 or dd.jump then guard = math.max(guard or 0, 0.95) end
        if guard and self.dashT > 0 then self.iframes = math.max(self.iframes, self.dashT * guard + 0.05) end
        Anim.move(self, "dash", dp)
        self.dashT0 = self.dashT
        Audio.play("dash")
        self.inventory:trigger("onDash", { world = world, player = self, procDepth = 0 })
    end
    if (self.dashT > 0 or self.grapple) and dd.update and not dd.hold then dd.update(self, world, dt, dp) end
    if dd.tick then dd.tick(self, world, dt, dp) end      -- dashes with lasting effects (stink shield)
    -- hops: height follows an arc over the dash
    if self.dashT > 0 and self.dashHop > 0 and self.dashT0 then
        self.z = math.sin((1 - self.dashT / self.dashT0) * math.pi) * self.dashHop
    elseif self.ropeVX then
        -- set by the grapple line
    else
        self.z = self.liftZ or 0       -- liftZ: held up by a mode (dragonfly flight)
    end
    if self.blockFxT > 0 then self.blockFxT = self.blockFxT - dt end

    local vx, vy
    if self.dashT > 0 then
        self.dashT = self.dashT - dt
        vx, vy = self.dashX * DASH_SPEED, self.dashY * DASH_SPEED
        world.particles:spawn(self.x, self.y, 2, 0, 0, 20, 0.25, { 0.6, 0.85, 1 }, 1, { glow = true, grav = 0 })
    else
        local speed = self.stats:get("moveSpeed") * (self.def.immune and 1 or self.slowMul or 1) * (self.blocking and (dp.slow or 0.35) or 1)
            * (self.moveMul or 1) * (self.runMul or 1)
        local mvx, mvy = wx * mag, wy * mag
        -- sideways walkers (crab): quick to the side of where they face, slow forward and back
        local sw = self.def.sideways
        if sw and mag > 0.01 then
            local f = mvx * self.aimX + mvy * self.aimY
            local sx, sy = mvx - f * self.aimX, mvy - f * self.aimY
            mvx = self.aimX * f * (sw.forward or 0.6) + sx * (sw.side or 1.15)
            mvy = self.aimY * f * (sw.forward or 0.6) + sy * (sw.side or 1.15)
        end
        vx, vy = mvx * speed + self.kvx + self.momX, mvy * speed + self.kvy + self.momY
    end
    if self.ropeVX then vx, vy = self.ropeVX, self.ropeVY end    -- swinging on a grapple line
    self.vx, self.vy = vx, vy      -- for enemies that lead their shots
    local S, r = world.size, self.radius
    self.x = util.clamp(self.x + vx * dt, r, S - r)
    self.y = util.clamp(self.y + vy * dt, r, S - r)

    -- Aim
    local range = self:attackRange()
    local target
    local sx, sy
    if not demo then sx, sy = Input.aimStick() end
    if sx then
        self.aimX, self.aimY = Iso.screenDirToWorld(sx, sy)
    else
        local mode = demo and "nearest" or Settings.get("aimMode")
        if mode == "mouse" and Input.lastDevice == "touch" then mode = "nearest" end
        if mode == "nearest" then
            target = world:nearestEnemy(self.x, self.y, range * 1.6)
            if target then
                self.aimX, self.aimY = util.normalize(target.x - self.x, target.y - self.y)
            elseif self.moving then
                self.aimX, self.aimY = self:walkFacing(wx, wy)
            end
        elseif mode == "mouse" then
            local ax, ay = world:mouseWorld()
            local nx, ny, l = util.normalize(ax - self.x, ay - self.y)
            if l > 0 then self.aimX, self.aimY = nx, ny end
        elseif self.moving then
            self.aimX, self.aimY = self:walkFacing(wx, wy)
        end
    end
    local svx, svy = self.aimX - self.aimY, (self.aimX + self.aimY) * 0.5
    self.angle = self.angle + util.angleDiff(self.angle, math.atan2(svy, svx)) * math.min(1, dt * 18)
    self.wangle = self.wangle + util.angleDiff(self.wangle, math.atan2(self.aimY, self.aimX)) * math.min(1, dt * 18)

    -- Secondary (right click): aimed where you point, on its own cooldown
    local sec = self.secondary
    local atkSpeed = math.max(0.2, 1 + self.stats:get("attackSpeed") / 100)
    if sec then
        sec.timer = sec.timer - dt * atkSpeed
        -- specials with a held part (drawing a web wall, munching a snatched ant) or a carry
        if sec.type.update then
            local px, py = self:pointer()
            sec.type.update(self, world, dt, sec.params, not demo and Input.down("secondary"), px, py)
        end
        if not demo and not stunned and not self.blocking and sec.timer <= 0 and not sec.type.manual and Input.pressed("secondary") then
            local px, py = self:pointer()
            local ax, ay, l = util.normalize(px - self.x, py - self.y)
            if l < 1 then ax, ay = self.aimX, self.aimY end
            self.aimX, self.aimY = ax, ay
            local params = self.skills:before("secondary", sec.params)
            sec.type.fire(self, world, ax, ay, params, px, py)
            self.skills:after("secondary", ax, ay, px, py, params)
            Anim.move(self, "secondary", sec.params)
            Player.swingSound(sec.params, true)
            sec.timer = sec.params.cooldown
            self.lungeT = 0.18
            self.wangle = math.atan2(ay, ax)
        end
    end

    -- Attack
    local atk = self.attack
    atk.timer = atk.timer - dt * atkSpeed * (self.gumT > 0 and self.gumMul or 1)
    -- Hold-to-charge attacks (mantis shrimp punch): the attack's own update decides when to
    -- let go and calls Player:releaseAttack. want = auto-attack sees something to hit.
    if atk.type.update then
        local free = not self.blocking and not stunned
        local auto = (Settings.get("autoAttack") or demo) and (target ~= nil or world:nearestEnemy(self.x, self.y, range * 1.2) ~= nil)
        atk.type.update(self, world, dt, atk.params, free and not demo and Input.down("attack"), free and auto)
    end
    if atk.timer <= 0 and (not self.blocking or dd.attackWhileBlocking) and not stunned and not atk.type.manual then
        local want
        if Settings.get("autoAttack") or demo then
            want = target ~= nil or world:nearestEnemy(self.x, self.y, range * 1.2) ~= nil
        else
            want = Input.down("attack")
        end
        if want then
            local params = self.skills:before("attack", atk.params)
            atk.type.fire(self, world, self.aimX, self.aimY, params)
            self.skills:after("attack", self.aimX, self.aimY, nil, nil, params)
            Anim.move(self, "attack", atk.params)
            Player.swingSound(atk.params, false)
            self.lungeT = 0.18
            self.wangle = math.atan2(self.aimY, self.aimX)  -- snap to face the strike
            atk.timer = atk.params.cooldown
        else
            atk.timer = 0
        end
    end

    -- Follow-ups queued by attacks (second slash, pounce landing...)
    for i = #self.delayed, 1, -1 do
        local d = self.delayed[i]
        d.t = d.t - dt
        if d.t <= 0 then
            table.remove(self.delayed, i)
            self.curMove = d.move
            d.fn(self, world)
            self.curMove = nil
        end
    end

    -- Regen and timers
    local maxHp = self.stats:get("maxHp")
    self.hp = math.min(maxHp, self.hp + self.stats:get("hpRegen") * dt)
    self.iframes = math.max(0, self.iframes - dt)
    self.flash = math.max(0, self.flash - dt)
    self.inventory:update(dt)
    self.lungeT = math.max(0, self.lungeT - dt)
    local kd = 1 - util.damp(9, dt)
    self.kvx, self.kvy = self.kvx * kd, self.kvy * kd
    -- momentum (flung off a grapple line) carries on for a while
    local md = 1 - util.damp(self.momDamp or 2.5, dt)
    self.momX, self.momY = self.momX * md, self.momY * md
    self.hurtFxT = math.max(0, self.hurtFxT - dt)
    -- damage numbers are summed over a short window so a swarm reads as one big number
    if self.dmgAccum > 0 then
        self.dmgShowT = self.dmgShowT - dt
        if self.dmgShowT <= 0 then
            local n = self.dmgAccum
            world:floatText(self.x, self.y, "-" .. (n >= 10 and math.floor(n + 0.5) or (math.floor(n * 10 + 0.5) / 10)),
                { 1, 0.35, 0.35 }, n >= 15)
            self.dmgAccum = 0
        end
    end
    self.recoilT = math.max(0, self.recoilT - dt)
    if self.slowT > 0 then self.slowT = self.slowT - dt end
    if self.stunT > 0 then self.stunT = self.stunT - dt end
    if self.blindT > 0 then self.blindT = self.blindT - dt end
    if self.gumT > 0 then
        self.gumT = self.gumT - dt
        if self.gumT <= 0 then self.gumMul = 1 end
    end
    -- Venom: damage over time in half-second ticks (a dash's i-frames skip a tick).
    if self.venomT > 0 then
        self.venomT = self.venomT - dt
        self.venomTick = self.venomTick + dt
        if self.venomTick >= 0.5 then
            self.venomTick = self.venomTick - 0.5
            self:hurt(self.venomDps * 0.5, "venom")
            world.particles:spawn(self.x, self.y, 8, (love.math.random() - 0.5) * 20, (love.math.random() - 0.5) * 20, 30, 0.6,
                { 0.7, 0.35, 1 }, 1, { glow = true, grav = -20 })
        end
        if self.venomT <= 0 then self.venomDps = 0 end
    end
    -- Dash afterimages: a ghost of the bug every few hundredths of a second, fading out.
    if self.dashT > 0 then
        self.ghostT = self.ghostT - dt
        if self.ghostT <= 0 then
            self.ghostT = 0.025
            self.ghosts[#self.ghosts + 1] = { x = self.x, y = self.y, wangle = self.wangle, anim = self.anim, t = 0 }
        end
    end
    for i = #self.ghosts, 1, -1 do
        local g = self.ghosts[i]
        g.t = g.t + dt
        if g.t > 0.22 then table.remove(self.ghosts, i) end
    end
    -- Legs step in time with how fast the bug is actually going; when standing still they
    -- shuffle now and then instead of freezing mid-stride.
    local fps = self.model and Sprites.get(self.model.legs).fps or self.sprite.fps
    if self.dashT > 0 then
        self.anim = self.anim + dt * fps * 2
        self.idleT = 0
    elseif self.moving then
        self.anim = self.anim + dt * fps * math.max(0.4, mag)
        self.idleT = 0
    else
        self.idleT = self.idleT + dt
        local f = self.anim % 4     -- frames 0 and 4 of the 8-frame cycle are the resting pose
        if f > 0.05 and f < 3.95 then self.anim = self.anim + dt * fps * 0.6   -- finish the step
        elseif self.idleT % 2.6 > 2.3 then self.anim = self.anim + dt * fps * 0.5 end
    end
    -- Chain bodies: every segment follows the one in front at a fixed spacing, so the body
    -- flows along the path the head took, and at speed it ripples side to side.
    if self.chain then
        local sp = self.model.spacing
        local prev = self
        for _, seg in ipairs(self.chain) do
            local dx, dy = seg.x - prev.x, seg.y - prev.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < 0.001 then dx, dy, d = -math.cos(self.wangle), -math.sin(self.wangle), 1 end
            seg.x, seg.y = prev.x + dx / d * sp, prev.y + dy / d * sp
            prev = seg
        end
        -- moves can pose the whole chain (millipede coiling up or rolling as a wheel)
        if self.chainPose then self.chainPose(self) end
    end
    -- Footfalls: each half of the gait plants a set of feet (frames 1 and 5 of 8). Kick up a
    -- little dust on each side and leave faint prints in the dust.
    local step = math.floor(self.anim / 4)
    if step ~= self.stepFrame then
        self.stepFrame = step
        if self.model and (self.moving or self.dashT > 0) then self:footfall(step % 2 == 0 and 1 or -1) end
    end
end

function Player:footfall(side)
    local world = self.world
    local c, s = math.cos(self.wangle), math.sin(self.wangle)
    local reach = self.radius * 1.1
    for k = -1, 1, 2 do
        -- two feet of the tripod on this side, one on the other
        local px, py = -s * reach * side * k, c * reach * side * k
        local fwd = (k == 1) and 0.6 or -0.5
        local x, y = self.x + px + c * reach * fwd, self.y + py + s * reach * fwd
        world.particles:spawn(x, y, 1, (love.math.random() - 0.5) * 18 - c * 10, (love.math.random() - 0.5) * 18 - s * 10, 14, 0.35,
            { 0.62, 0.58, 0.52 }, 1, { grav = 60 })
        if Settings.get("decals") and love.math.random() < 0.5 then
            world.pendingSplats[#world.pendingSplats + 1] = { kind = "drop", x, y, { 0.42, 0.39, 0.35 }, 1 }
        end
    end
end

-- Poison (venomous bites): keeps the strongest dose and the longest duration.
function Player:poison(dps, time)
    if self.def.immune then return end     -- hissing roach: shrugs off every debuff
    self.venomDps = math.max(self.venomDps, dps)
    self.venomT = math.max(self.venomT, time)
end

-- Slow to `mul` x speed for `time` seconds (pebble daze).
function Player:slow(mul, time)
    if self.def.immune then return end     -- hissing roach: shrugs off every debuff
    if self.slowT <= 0 or mul < self.slowAmt then self.slowAmt = mul end
    self.slowT = math.max(self.slowT, time)
end

-- Paralysed for `time` seconds (no moving, dashing or attacking).
function Player:stun(time)
    if self.def.immune then return end     -- hissing roach: shrugs off every debuff
    self.stunT = math.max(self.stunT, time)
end

-- Blinded for `time` seconds: the light shrinks to arm's reach.
function Player:blind(time)
    if self.def.immune then return end     -- hissing roach: shrugs off every debuff
    self.blindT = math.max(self.blindT, time)
end

-- Attacks recharge at `mul` x speed for `time` seconds (resin gumming up the jaws). Stacks down.
function Player:gum(mul, time)
    if self.def.immune then return end     -- hissing roach: shrugs off every debuff
    self.gumMul = self.gumT > 0 and math.max(0.25, self.gumMul * mul) or mul
    self.gumT = math.max(self.gumT, time)
end

local function armorMultiplier(armor)
    if armor >= 0 then return 15 / (15 + armor) end
    return (15 - armor) / 15
end

-- Where the player is pointing in the world: the mouse, or ahead along the aim on a pad.
function Player:pointer()
    local dev = Input.lastDevice
    if dev ~= "gamepad" and dev ~= "touch" and not self.world.flags.demo then return self.world:mouseWorld() end
    return self.x + self.aimX * 100, self.y + self.aimY * 100
end

function Player:hurt(amount, source)
    local world = self.world
    if self.dead or self.iframes > 0 or world.flags.god then return end
    if self.ward and self.ward(self, amount, source) then return end
    if self.blocking then
        self.dashDef.blocked(self, world, source, self.dashParams)
        Stamina.blockHit(self, self.dashParams)
        self.inventory:trigger("onBlock", { world = world, player = self, damage = amount, source = source, procDepth = 0 })
        return
    end
    if love.math.random() * 100 < self.stats:get("dodge") then
        world:floatText(self.x, self.y, "dodge", { 0.7, 0.9, 1 })
        self.iframes = 0.2
        self.inventory:trigger("onDodge", { world = world, player = self, procDepth = 0 })
        return
    end
    -- No invulnerability after a hit: every bite lands, so a bigger crowd hurts more.
    -- Only dashing (and dodge) avoid damage. Feedback is throttled so swarms don't spam it.
    local dmg = math.max(0.5, amount * armorMultiplier(self.stats:get("armor")) * (self.guardMul or 1))
    self.hp = self.hp - dmg
    if self.dmgAccum == 0 then self.dmgShowT = 0.3 end
    self.dmgAccum = self.dmgAccum + dmg
    if self.hurtFxT <= 0 or dmg >= 8 then
        self.hurtFxT = 0.18
        self.flash = 0.12
        self.recoilT = 0.2
        world.camera:shake(math.min(0.5, 0.15 + dmg * 0.03))
        Audio.play("hurt")
        Input.vibrate(math.min(1, 0.3 + dmg * 0.05), 0.12)
    end
    local ctx = { world = world, player = self, damage = dmg, source = source, procDepth = 0 }
    world.events:emit("player_hurt", ctx)
    self.inventory:trigger("onHurt", ctx)
    if self.hp <= 0 then
        self.hp = 0
        self.dead = true
        world.events:emit("player_died", ctx)
    end
end

-- Shove the player (trap-jaw snaps, explosions). Big bugs are heavier and get pushed less,
-- tiny ones get flung further (def.scale 1.45 takes ~57% of the shove, 0.8 takes ~140%).
function Player:knock(dx, dy, force)
    local l = math.sqrt(dx * dx + dy * dy) + 0.0001
    force = force / (self.def.scale or 1) ^ 1.5
    self.kvx, self.kvy = self.kvx + dx / l * force, self.kvy + dy / l * force
end

function Player:heal(n)
    self.hp = math.min(self.stats:get("maxHp"), self.hp + n)
end

return Player
