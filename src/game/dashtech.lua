-- Dash tech: a little extra for players who dash well (Settings > Gameplay > "Dash Tech").
--   * Kill-dash refund: the first kill made during a pressed dash (or a moment after it ends)
--     gives back part of the dash's stamina. Chain kills and keep moving.
--   * Chained dashes: dashing again soon after the last one ended is faster, up to 3 links.
--     Same distance, less time, so a chain zips through gaps.
-- Only pressed dashes (and hold-and-release ones) count; hold modes and blocks don't. Every
-- dash's own code is left alone: this scales the dash velocity Player:update moves with.
-- Kills made in a dash are emitted as "dash_kill" (Records counts them for unlock goals).
local Settings = require("src.core.settings")
local Stamina = require("src.game.stamina")

local DashTech = {
    REFUND = 0.5,        -- share of one dash's stamina given back by a kill-dash
    KILL_GRACE = 0.25,   -- seconds after a dash ends that kills still count
    CHAIN_WINDOW = 0.45, -- seconds after a dash ends to chain the next one
    CHAIN_SPEED = 0.15,  -- dash speed added per chain link
    CHAIN_MAX = 3,
}

local function on() return Settings.get("dashTech") ~= false end

local function state(p)
    local s = p.dashTech
    if not s then
        s = { active = false, chain = 0, lastEnd = -1, killUntil = -1, refunded = true }
        p.dashTech = s
    end
    return s
end

-- Listen for kills (World.new calls this once).
function DashTech.attach(world)
    world.events:on("enemy_died", function() DashTech.onKill(world) end)
end

-- A pressed dash just started (Player:update, after the dash def's start).
function DashTech.onStart(p)
    local s = state(p)
    local now = p.world.time
    if on() and now - s.lastEnd <= DashTech.CHAIN_WINDOW then
        s.chain = math.min(DashTech.CHAIN_MAX, s.chain + 1)
    else
        s.chain = 0
    end
    s.active, s.refunded = true, false
    if s.chain > 0 and p.dashT > 0 then
        local mul = 1 + DashTech.CHAIN_SPEED * s.chain
        p.dashX, p.dashY = p.dashX * mul, p.dashY * mul
        p.dashT = p.dashT / mul
        p.dashT0 = p.dashT
        local w = p.world
        w.particles:burst(p.x, p.y, 3 + s.chain * 2, { { 0.6, 0.9, 1 } }, 90, 6, { glow = true })
        if s.chain >= 2 then w:floatText(p.x, p.y - 10, "chain x" .. (s.chain + 1), { 0.6, 0.9, 1 }) end
    end
end

-- Every frame (Player:update): notice when the dash is over.
function DashTech.update(p)
    local s = p.dashTech
    if s and s.active and p.dashT <= 0 and not p.grapple then
        s.active = false
        s.lastEnd = p.world.time
        s.killUntil = s.lastEnd + DashTech.KILL_GRACE
    end
end

function DashTech.dashing(p)
    local s = p.dashTech
    return s ~= nil and (s.active or p.world.time <= s.killUntil)
end

function DashTech.onKill(world)
    local p = world.player
    if not p or p.dead or not DashTech.dashing(p) or not on() then return end
    world.events:emit("dash_kill")
    local s = p.dashTech
    if s.refunded then return end
    s.refunded = true
    local st = Stamina.state(p)
    if st.cur >= st.max - 1e-6 then return end
    Stamina.spend(p, -st.cost * DashTech.REFUND)
    world.particles:burst(p.x, p.y, 5, { { 0.55, 1, 0.6 } }, 70, 6, { glow = true, grav = -40 })
end

return DashTech
