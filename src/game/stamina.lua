-- One stamina pool per bug, shared by every dash-like ability. The HUD shows it as the bar
-- under the health bar (src/ui/hud.lua). Three kinds of dash spend it:
--   * pressed dashes (and hold-and-release ones via content/dashes/_charge.lua): each use costs
--     one "charge" = max / params.charges. dashCharges / dashCd are kept up to date from the
--     pool so old readers still work, but only change the pool through this module.
--   * hold-Shift modes made with Stamina.mode{...} (below): burn 1 stamina per second while on.
--   * blocks (hold dashes with a `blocked` fn): burn params.drain per second while held, cost
--     params.raiseCost to raise, params.hitCost per blocked hit. Running dry breaks the guard:
--     it drops and can't go back up for params.breakLock seconds, and Shift must be let go.
-- Refill is per second (params.regen) once the pool hasn't been spent for a moment, and
-- Dash Cooldown items speed it up (1.2 s is the base stat). Nothing refills while a mode is
-- on or a block is up.
--
-- API for dash files and other systems:
--   Stamina.state(player)            the pool { cur, max, on, lockT, ... } (created on demand)
--   Stamina.hasCharge(player)        enough for one pressed dash?
--   Stamina.spendCharge(player)      pay for one pressed dash
--   Stamina.refundCharge(player)     give one back
--   Stamina.spend(player, amount)    take any amount (clamped at 0), pauses the refill
--   Stamina.sap(player, dt, k)       slow the refill by share k (sweat bees)
--   Stamina.fraction(player)         0..1 for UI
-- A pressed dash def can set free = function(player) return true end to skip the cost (the
-- safety line's zip back, the acid skip's second hop).
local Stamina = {}

local function kind(player)
    local dd = player.dashDef
    if dd.stamina then return "mode" end
    if dd.blocked then return "block" end
    return "tap"
end

local function sizes(player)
    local dp, k = player.dashParams, kind(player)
    if k == "mode" then return dp.stamina or 2.5, dp.regen or 1, 1 end
    if k == "block" then return dp.stamina or 3, dp.regen or 0.9, 1 end
    local n = math.max(1, dp.charges or 1)
    local max = dp.stamina or n
    local cost = dp.cost or max / n
    return max, dp.regen or cost / 1.2, cost
end

function Stamina.state(player)
    local s = player.stamina
    if not s then
        local max = sizes(player)
        s = { cur = max, max = max, on = false, lockT = 0, delayT = 0, cost = 1, flashT = 0 }
        player.stamina = s
    end
    return s
end

-- Refill per second right now (Dash Cooldown items included).
function Stamina.regenRate(player)
    local _, regen = sizes(player)
    return regen * 1.2 / math.max(0.2, player.stats:get("dashCooldown"))
end

local function sync(player, s)
    s.cur = math.max(0, math.min(s.max, s.cur))
    player.dashCharges = math.floor(s.cur / s.cost + 1e-6)
    local rate = Stamina.regenRate(player)
    local left = s.cost - (s.cur - player.dashCharges * s.cost)
    player.dashCd = (s.cur >= s.max - 1e-6) and 0 or (left / math.max(0.01, rate) + s.delayT)
end

-- Every frame, from Player:update before the dash runs.
function Stamina.update(player, dt)
    local s = Stamina.state(player)
    local max, _, cost = sizes(player)
    s.max, s.cost = max, cost          -- skill nodes can change the size mid-run
    if s.lockT > 0 then s.lockT = s.lockT - dt end
    if s.flashT > 0 then s.flashT = s.flashT - dt end
    if s.delayT > 0 then
        s.delayT = s.delayT - dt
    elseif not s.on and not player.blocking then
        s.cur = s.cur + dt * Stamina.regenRate(player)
    end
    sync(player, s)
end

function Stamina.spend(player, amount, delay)
    local s = Stamina.state(player)
    s.cur = s.cur - amount
    s.delayT = math.max(s.delayT, delay or 0)
    sync(player, s)
end

function Stamina.hasCharge(player)
    local s = Stamina.state(player)
    return s.cur >= s.cost - 1e-6
end

function Stamina.spendCharge(player)
    Stamina.spend(player, Stamina.state(player).cost)
end

function Stamina.refundCharge(player)
    local s = Stamina.state(player)
    s.cur = s.cur + s.cost
    sync(player, s)
end

function Stamina.sap(player, dt, k)
    local s = Stamina.state(player)
    if s.cur < s.max then Stamina.spend(player, dt * Stamina.regenRate(player) * k) end
end

function Stamina.fraction(player)
    local s = player.stamina
    return s and s.cur / math.max(0.01, s.max) or 1
end

-- Blocks: filters the held button. Returns whether the guard is up this frame.
function Stamina.guard(player, dt, params, held)
    local s = Stamina.state(player)
    if s.needRelease then
        if held then return false end
        s.needRelease = nil
    end
    if held and player.stunT > 0 then held = false end
    if player.blocking then
        if not held then return false end
        Stamina.spend(player, dt * (params.drain or 1), 0.4)
        if s.cur <= 0 then
            -- guard broken: down it goes, and stays down for a moment
            s.lockT, s.needRelease, s.flashT = params.breakLock or 1.2, true, 0.6
            local world = player.world
            world.particles:sparks(player.x, player.y, 8, { 1, 0.55, 0.4 }, player.aimX, player.aimY, 3, 120)
            world:floatText(player.x, player.y, "guard broken", { 1, 0.55, 0.4 })
            require("src.core.audio").play("hit", { pitch = 0.6 })
            return false
        end
        return true
    end
    if not held then return false end
    if s.lockT > 0 or s.cur < s.max * (params.minStart or 0.25) then
        s.flashT, s.needRelease = 0.3, true      -- too tired: let go and try again
        return false
    end
    Stamina.spend(player, params.raiseCost or 0.3, 0.4)
    return true
end

-- A hit soaked by a block costs a little extra.
function Stamina.blockHit(player, params)
    Stamina.spend(player, params.hitCost or 0.04, 0.4)
end

-- Force the mode off (stunned, character swap, a move that needs it off).
function Stamina.stop(player, dry)
    local s = player.stamina
    if not s or not s.on then return end
    local def, params = player.dashDef, player.dashParams
    s.on = false
    s.lockT = 0.25
    player.holdMode, player.runMul = nil, nil
    if def.spec and def.spec.exit then def.spec.exit(player, player.world, params, dry) end
end

-- Hold-Shift stamina modes: run (tiger beetle), fly (dragonfly), dig (camel spider), roll up
-- (millipede, dung beetle)... While Shift is held the bug switches into its mode and burns
-- stamina; letting go, or running dry, drops back out. Stamina refills while the mode is off
-- (faster with Dash Cooldown items).
--
-- A dash file makes one with Stamina.mode{...} and returns it:
--   return Stamina.mode({
--       name = "Run", description = "...",
--       speed = 1.6,                          -- move speed x while on (params.speed wins)
--       iframes = 0.15,                       -- untouchable for this long on entering (0.12)
--       enter = function(player, world, params) end,
--       tick  = function(player, world, dt, params) end,      -- every frame while on
--       exit  = function(player, world, params, dry) end,     -- dry = stamina ran out
--       idle  = function(player, world, dt, params) end,      -- every frame while off (optional)
--       canEnter = function(player, params) return true end,  -- optional gate (dung ball size)
--       draw = function(player, world, params) end,           -- optional, drawn in the world
--   })
-- The character's dash table is `params`: stamina (seconds of full use, 2.5), regen (stamina
-- per second while off, 1), minStart (share of the bar needed to start, 0.25), speed.
-- While on: player.holdMode = the dash def, player.runMul = speed. Animation clips can hold
-- their pose with hold = function(p) return p.holdMode ~= nil end.
function Stamina.mode(spec)
    local def = {
        name = spec.name, description = spec.description,
        hold = true, stamina = true, spec = spec,
    }
    def.update = function(player, world, dt, params, held)
        local s = Stamina.state(player)
        if held and player.stunT > 0 then held = false end
        if s.on then
            Stamina.spend(player, dt, 0.3)
            if not held or s.cur <= 0 then
                Stamina.stop(player, s.cur <= 0)
            else
                player.runMul = params.speed or spec.speed or 1
                if spec.tick then spec.tick(player, world, dt, params) end
            end
        elseif held and s.lockT <= 0 and s.cur >= s.max * (params.minStart or 0.25)
            and (not spec.canEnter or spec.canEnter(player, params)) then
            s.on = true
            player.holdMode = def
            player.runMul = params.speed or spec.speed or 1
            player.iframes = math.max(player.iframes, spec.iframes or 0.12)
            if spec.enter then spec.enter(player, world, params) end
            player.inventory:trigger("onDash", { world = world, player = player, procDepth = 0 })
        elseif held and s.lockT <= 0 and s.cur < s.max * (params.minStart or 0.25) then
            s.flashT = 0.3          -- too tired to start: the HUD bar flashes
        end
        if not s.on and spec.idle then spec.idle(player, world, dt, params) end
    end
    def.draw = spec.draw
    return def
end

return Stamina
