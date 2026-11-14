-- Keyframed attack animations for 3D-model bugs (the player's character).
--
-- A clip moves the body over its planted legs and can draw extra jointed limbs (claws, tails,
-- forelegs, fangs) that swing out for the strike. Clips are plain tables, so a character can
-- carry its own in its file:
--
--   anims = { attack = <clip or library name>, secondary = ..., dash = ... }
--
-- or reuse one from the shared library in src/config/anims.lua, which is looked up as
-- "<character id>.<slot>" first, then by the move's type id ("slashes", "dash", "block"...).
--
-- Clip fields:
--   time    seconds the clip lasts (number, or function(params, player) -> seconds)
--   keys    { {t, channel = value, ...}, ... } with t from 0 to 1. A channel a key doesn't name
--           is 0 there; values ease smoothly from key to key.
--   limbs   jointed appendages drawn while the clip plays (see below)
--   hold    function(player) -> true while the pose should stay held (blocking, carrying, charging);
--           the clip waits at `holdAt` (0..1) and plays out once it lets go
--   mirror  true: every other play is mirrored (left hand, right hand)
--   build   function(params, player, side) -> clip, for timings that depend on the move's params
--
-- Body channels (all add up across clips playing at once):
--   lunge   px the body moves forward over its legs (negative: pulls back)
--   side    px sideways (mirrored)            rear    px the body rises (negative: crouch)
--   twist   radians the body turns on its legs (mirrored)
--   spin    radians the whole bug turns       stretch body squash/stretch (0.2 = 20% longer)
--   reach   px the front pair of feet reach forward (pounces, grabs)
--   spread  extra stance width (0.3 = legs 30% wider, bracing)
--   shake   px of jitter (straining, charging up)
--
-- Limbs: { u, v, z, pair, segs, strike, ch, width, color, tip, open, alpha }
--   u, v    where it attaches, in body sprite pixels from the centre (u forward, v to the side)
--   z       attach height (default: top of the body)
--   pair    true: drawn on both sides, mirrored (chR names the right side's channel, else ch)
--   segs    rest pose: { {len, a, p}, ... } segment length, yaw and pitch, each relative to the
--           segment before (radians; yaw towards +v, pitch upwards)
--   strike  the same list at full strike; the limb blends rest -> strike by channel `ch` (0..1,
--           overshoot allowed)
--   alt     optional third pose blended in on top by channel `ch2` (raise with ch, slam with ch2)
--   width   line width in px (1..3)    color  body palette letter ("D") or "#rrggbb"
--   tip     "pincer" | "blade" | "sting" | "fang" | "club" | nil
--   open    channel that opens a pincer tip (0 shut .. 1 wide)
--   alpha   channel for its opacity (default: fully shown while the clip plays)
local Anim = {}

local clipsLib    -- src/config/anims.lua, loaded on first use

local function library()
    if not clipsLib then clipsLib = require("src.config.anims") end
    return clipsLib
end

Anim.CHANNELS = { "lunge", "side", "rear", "twist", "spin", "stretch", "reach", "spread", "shake" }
local MIRRORED = { side = true, twist = true, spin = true }

-- Which clip a character uses for a move slot ("attack", "secondary", "dash").
function Anim.find(def, slot, typeId)
    local own = def and def.anims and def.anims[slot]
    local lib = library()
    if type(own) == "string" then own = lib[own] end
    if own then return own end
    if def and def.id and lib[def.id .. "." .. slot] then return lib[def.id .. "." .. slot] end
    if typeId and lib[typeId] then return lib[typeId] end
    return nil
end

local function now(o) return (o.world and o.world.time) or love.timer.getTime() end

-- Start a clip on `o` (usually the player) in its own layer (`slot`), replacing what was there.
-- clip: a clip table or a library name. opts: side (1 / -1), params (the move's params).
function Anim.play(o, clip, slot, opts)
    if type(clip) == "string" then clip = library()[clip] end
    if not clip then return end
    opts = opts or {}
    o._anims = o._anims or {}
    local prev = o._anims[slot or "main"]
    local side = opts.side or 1
    if clip.mirror and not opts.side then
        side = (prev and prev.clip == clip and prev.flip) and -1 or 1
    end
    local c = clip
    if clip.build then c = clip.build(opts.params or {}, o, side) or clip end
    if c.side then side = c.side end     -- a built clip may pick its own side (left pincer, right pincer)
    local time = c.time or clip.time or 0.25
    if type(time) == "function" then time = time(opts.params or {}, o) end
    o._anims[slot or "main"] = { clip = clip, c = c, t0 = now(o), dur = math.max(0.01, time), side = side, flip = side == 1 }
end

-- Play the character's clip for a move slot, if it has one.
function Anim.move(player, slot, params)
    local clip = Anim.find(player.def, slot, params and params.type)
    if clip then Anim.play(player, clip, slot, { params = params }) end
end

function Anim.stop(o, slot)
    if o._anims then
        if slot then o._anims[slot] = nil else o._anims = nil end
    end
end

-- Is anything playing (for tests and the catalogue)?
function Anim.active(o)
    if not o._anims then return false end
    for _ in pairs(o._anims) do return true end
    return false
end

local function smooth(f) return f * f * (3 - 2 * f) end

-- Value of channel `ch` at progress p (0..1) of a clip's keys.
local function channel(keys, ch, p)
    local n = #keys
    if n == 0 then return 0 end
    if p <= keys[1][1] then return keys[1][ch] or 0 end
    for i = 2, n do
        local b = keys[i]
        if p <= b[1] then
            local a = keys[i - 1]
            local span = b[1] - a[1]
            local f = span > 0 and smooth((p - a[1]) / span) or 1
            local va, vb = a[ch] or 0, b[ch] or 0
            return va + (vb - va) * f
        end
    end
    return keys[n][ch] or 0
end
Anim.channel = channel

local out = { limbs = {} }
local NONE = {}

-- Sum every playing clip into one pose: out.lunge, out.twist, ... plus out.limbs, a list of
-- { limb, k (blend), open, alpha, side } to draw. Finished clips are dropped.
function Anim.sample(o)
    for _, ch in ipairs(Anim.CHANNELS) do out[ch] = 0 end
    local limbs = out.limbs
    for i = #limbs, 1, -1 do limbs[i] = nil end
    local layers = o._anims or NONE
    local t = now(o)
    for slot, st in pairs(layers) do
        local c = st.c
        local held = st.clip.hold and st.clip.hold(o)
        local elapsed = t - st.t0
        if held then
            local at = (st.clip.holdAt or 0.5) * st.dur
            if elapsed > at then st.t0, elapsed = t - at, at end
        end
        local p = elapsed / st.dur
        if p >= 1 and not held then
            layers[slot] = nil
        else
            p = math.max(0, math.min(1, p))
            local keys = c.keys or {}
            for _, ch in ipairs(Anim.CHANNELS) do
                local v = channel(keys, ch, p)
                if MIRRORED[ch] then v = v * st.side end
                out[ch] = out[ch] + v
            end
            for _, limb in ipairs(c.limbs or {}) do
                local sides = limb.pair and 2 or 1
                for k = 1, sides do
                    local sd = (limb.side or (k == 1 and 1 or -1)) * st.side
                    local chName = (k == 2 and limb.chR) or limb.ch
                    limbs[#limbs + 1] = {
                        limb = limb, side = sd,
                        k = chName and channel(keys, chName, p) or 1,
                        k2 = limb.ch2 and channel(keys, limb.ch2, p) or 0,
                        open = limb.open and channel(keys, limb.open, p) or 0,
                        alpha = limb.alpha and math.max(0, math.min(1, channel(keys, limb.alpha, p))) or 1,
                    }
                end
            end
        end
    end
    -- limbs always drawn at rest (a model's restLimbs, e.g. the lobster's crushers), unless a
    -- playing clip is moving the same limb (same `group` and side)
    local model = o.model or (o.def and o.def.model)
    local rest = model and model.restLimbs
    if rest then
        local n = #limbs
        for _, limb in ipairs(rest) do
            for sd = 1, -1, -2 do
                local free = not limb.side or limb.side == sd
                for i = 1, n do
                    if free and limbs[i].limb.group == limb.group and limbs[i].side == sd then free = false end
                end
                if free then
                    limbs[#limbs + 1] = { limb = limb, side = sd, k = 0, k2 = 0, open = limb.restOpen or 0, alpha = 1 }
                end
            end
        end
    end
    if out.shake ~= 0 then out.shake = out.shake * (love.math.random() - 0.5) * 2 end
    return out
end

-- Copy a sample into a Sprites.drawModel pose. `facing` is the bug's world angle; sx/sy its
-- draw scale. Adds to whatever pose.bx/by/bob already hold.
function Anim.applyTo(pose, s, facing, sx, sy)
    local fx, fy = math.cos(facing), math.sin(facing)
    local f, sd = s.lunge, s.side
    local wx, wy = fx * f - fy * sd, fy * f + fx * sd
    pose.bx = (pose.bx or 0) + (wx - wy) * (sx or 1) + s.shake
    pose.by = (pose.by or 0) + (wx + wy) * 0.5 * (sy or 1)
    pose.bob = (pose.bob or 0) + s.rear
    pose.twist, pose.spin, pose.stretch = s.twist, s.spin, s.stretch
    pose.reach, pose.spread = s.reach, s.spread
    pose.limbs = #s.limbs > 0 and s.limbs or nil
end

return Anim
