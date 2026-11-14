-- Attack animation clips (format: src/gfx/anim.lua). Looked up as "<character id>.<slot>"
-- (slot = attack, secondary, dash), then by the move's type id. The type-id clips move only the
-- body, so any new bug that reuses a move gets a sensible animation; the per-character ones add
-- limbs drawn at that bug's own claws, tail, jaws or forelegs.
local pi = math.pi

local A = {}

-- Copy a clip and give it limbs (works for built clips too).
local function withLimbs(base, limbs, extra)
    local c = {}
    for k, v in pairs(base) do c[k] = v end
    for k, v in pairs(extra or {}) do c[k] = v end
    c.limbs = limbs
    if base.build then
        c.build = function(params, p, side)
            local b = base.build(params, p, side)
            local out = {}
            for k, v in pairs(b) do out[k] = v end
            out.limbs = limbs
            return out
        end
    end
    return c
end

local function dashTime(params, speed) return (params.distance or 67) / (420 * (speed or params.speed or 1)) end

-- ---------------------------------------------------------------------------------------------
-- Generic clips by move type (body only)
-- ---------------------------------------------------------------------------------------------

-- Standard dash: leans into it, stretches out at speed; with a hop it crouches, flies, lands.
A.dash = {
    build = function(params)
        local t = dashTime(params)
        if (params.hop or 0) > 0 then
            return { time = t + 0.12, keys = {
                { 0, rear = -1.5, spread = 0.3, stretch = -0.1 },
                { 0.2, stretch = 0.18, reach = 2.5 },
                { 0.75, stretch = 0.1, reach = 1.5 },
                { 0.88, stretch = -0.15, rear = -1.5, spread = 0.3 },
                { 1 } } }
        end
        local ram = (params.ram or 0) > 0
        return { time = t + 0.1, keys = {
            { 0, rear = ram and -1 or -0.5, stretch = 0.14, lunge = ram and 2 or 1, spread = ram and 0.2 or 0 },
            { 0.75, rear = ram and -1 or 0, stretch = 0.1, lunge = ram and 2 or 0 },
            { 1 } } }
    end,
}

-- Block: hunker down behind the claws, legs braced wide, for as long as it's held.
A.block = { time = 0.5, holdAt = 0.3, hold = function(p) return p.blocking end, keys = {
    { 0 }, { 0.3, rear = -1.5, spread = 0.35, lunge = 1, guard = 1 }, { 1 } } }

-- Blast-off: the chamber goes off (squash), the recoil throws the bug up and back.
A.blast = { time = 0.38, keys = {
    { 0, stretch = -0.25, rear = 1, shake = 1.5 },
    { 0.2, stretch = 0.15, rear = 3, spread = -0.2 },
    { 0.75, rear = 1.5 },
    { 1 } } }

-- Grapple: reaches for the line with its front legs and hangs on while reeled in.
A.grapple = { time = 0.4, holdAt = 0.4, hold = function(p) return p.grapple ~= nil end, keys = {
    { 0 }, { 0.15, reach = 3.5, rear = 1.5 }, { 0.4, reach = 3, stretch = 0.12, rear = 2 }, { 1 } } }

-- Wide melee sweep: wind the head round to one side, swing it across. Alternates sides.
A.arc = { time = 0.3, mirror = true, keys = {
    { 0 },
    { 0.2, twist = -0.55, lunge = -1, rear = 1, jaw = 1 },
    { 0.5, twist = 0.6, lunge = 3, rear = -0.5, stretch = 0.06, jaw = -0.5 },
    { 1 } } }

-- Heavy line thrust: rock back, then drive forward and flick the head up.
A.pierce = { time = 0.42, keys = {
    { 0 },
    { 0.35, lunge = -3, rear = -1.5, spread = 0.3, stretch = -0.08 },
    { 0.5, lunge = 7, rear = 0.5, stretch = 0.16 },
    { 0.7, lunge = 5, rear = 3 },
    { 1 } } }

-- Ground slam: rear up on one side, crash down ahead.
A.slam = { time = 0.45, mirror = true, keys = {
    { 0 },
    { 0.35, up = 1, rear = 2, lunge = -2, twist = -0.2 },
    { 0.55, slam = 1, rear = -1.5, lunge = 4, twist = 0.15, stretch = -0.12, spread = 0.3 },
    { 0.8, slam = 0.8, rear = -1, lunge = 2 },
    { 1 } } }

-- Spin: arms flung out wide, low and braced while it whirls.
A.spin = {
    build = function(params)
        return { time = (params.turns or 3) * (params.turnTime or 0.12) + 0.12, keys = {
            { 0 }, { 0.15, out = 1, rear = 1, spread = 0.3 }, { 0.8, out = 1, rear = 1, spread = 0.3 }, { 1 } } }
    end,
}

-- Burst around the bug: gather in, then a bristling jolt.
A.nova = { time = 0.32, keys = {
    { 0 },
    { 0.3, rear = -1.5, spread = 0.1, stretch = -0.08 },
    { 0.45, rear = 1.5, spread = 0.4, stretch = 0.1, reach = 2, shake = 1, fang = 1 },
    { 1 } } }

-- Sprint strike: low and long, jaws open, snapping shut as it runs through.
A.lunge = {
    build = function(params)
        return { time = dashTime(params, 1.2) + 0.14, keys = {
            { 0, rear = -1, stretch = 0.15, lunge = 2, jaw = 1 },
            { 0.5, stretch = 0.2, lunge = 3, jaw = 1.1 },
            { 0.62, stretch = -0.1, twist = 0.2, jaw = -0.5 },
            { 1 } } }
    end,
}

-- Charge dash: the long sprint of a lunge at full speed, jaws open, snapping shut at the end.
A.chargedash = {
    build = function(params)
        local t = dashTime({ distance = (params.maxDistance or 150) * 0.7 }, 1.9)
        return { time = t + 0.16, keys = {
            { 0, rear = -1, stretch = 0.2, lunge = 3, jaw = 1 },
            { 0.6, stretch = 0.2, lunge = 3, jaw = 1.1 },
            { 0.75, stretch = -0.1, twist = 0.2, jaw = -0.5 },
            { 1 } } }
    end,
}
-- Winding up a charge dash (slot "charge"): dug in low, legs braced, quivering.
A["chargedash.charge"] = { time = 0.4, holdAt = 0.6, hold = function(p) return p.dashCharge ~= nil end, keys = {
    { 0 }, { 0.6, rear = -2, stretch = -0.12, spread = 0.35, lunge = -2, shake = 0.4, jaw = 1 }, { 1 } } }

-- Claw snap: lurches into the bite as the claw slams shut.
A.clawsnap = { time = 0.3, keys = { { 0, open = 1 }, { 0.3, lunge = 3, open = 0, stretch = 0.08 }, { 1 } } }
-- Holding the claw open (slot "charge"): reared back, straining.
A["clawsnap.charge"] = { time = 0.5, holdAt = 0.8, hold = function(p) return p.clawCharge ~= nil end, keys = {
    { 0 }, { 0.8, rear = 1.5, lunge = -1, spread = 0.25, shake = 0.3 }, { 1 } } }

-- Run (hold-Shift stamina mode): stretched out low for as long as it's held.
A.run = { time = 0.3, holdAt = 0.5, hold = function(p) return p.holdMode ~= nil end, keys = {
    { 0 }, { 0.5, stretch = 0.14, rear = -0.6, lunge = 1.5 }, { 1 } } }

-- Leap slam: crouch, spring high with the front legs up, crash down in a squash.
A.leapslam = {
    build = function(params)
        local t = dashTime(params, params.speed or 0.85)
        local tot = t + 0.2
        local land = t / tot
        return { time = tot, keys = {
            { 0, rear = -1.5, spread = 0.35, stretch = -0.12 },
            { 0.15, rear = 2, stretch = 0.15, reach = 3.5, fang = 1 },
            { land * 0.9, rear = 1, reach = 3, fang = 1 },
            { land + 0.05, rear = -2.5, stretch = -0.18, spread = 0.45, fang = -0.4, shake = 1 },
            { 1 } } }
    end,
}

-- Feeler pull: thrown forward along the line.
A.feelerpull = { time = 0.25, keys = { { 0, stretch = -0.1, rear = 1 }, { 0.3, stretch = 0.15, lunge = 2 }, { 1 } } }

-- Hair flick: a quick shake of the abdomen.
A.hairflick = { time = 0.12, keys = { { 0 }, { 0.4, rear = 1.2, shake = 0.5 }, { 1 } } }

-- Rampage: stays in the low sprint pose for as long as the strikes keep coming.
A.rampage = { time = 0.4, holdAt = 0.5, hold = function(p) return p.dashT > 0 or #p.delayed > 0 end, keys = {
    { 0, rear = -1, stretch = 0.12 },
    { 0.5, rear = -1, stretch = 0.18, lunge = 2, jaw = 1, shake = 0.4 },
    { 0.7, jaw = -0.5, stretch = -0.1 },
    { 1 } } }

-- Pounce: crouch, spring with the front legs reaching, land in a squash with fangs in.
A.pounce = {
    build = function(params)
        local t = dashTime(params, 1.4)
        local tot = t + 0.22
        local land = t / tot
        return { time = tot, keys = {
            { 0, rear = -1.5, spread = 0.3, stretch = -0.1 },
            { 0.12, rear = 1, stretch = 0.2, reach = 3 },
            { land * 0.85, reach = 4, stretch = 0.15, rear = 2, fang = 1 },
            { land + 0.08, rear = -1.5, stretch = -0.15, spread = 0.35, reach = 1, fang = -0.3 },
            { 1 } } }
    end,
}

-- Spray: braces, the jet's push rocks it back and makes it shudder.
A.spray = { time = 0.32, keys = {
    { 0 },
    { 0.15, lunge = -2, rear = 1.5, spread = 0.25, stretch = -0.06, shake = 0.6 },
    { 0.6, lunge = -1.5, rear = 1, shake = 0.6 },
    { 1 } } }

-- Lob: dips, then heaves up and forward.
A.grenade = { time = 0.36, keys = {
    { 0 },
    { 0.3, rear = -1.5, lunge = -2, spread = 0.25 },
    { 0.5, rear = 3, lunge = 2, stretch = 0.1 },
    { 1 } } }

-- Rapid jabs: a fast head snap.
A.jabs = { time = 0.12, keys = { { 0 }, { 0.4, lunge = 3, jab = 1 }, { 1 } } }

-- Tail stab: a hitch of the body as the tail whips (the chain animates the tail itself).
A.tailstab = { time = 0.24, keys = { { 0 }, { 0.3, lunge = -2, rear = 1 }, { 1 } } }

-- Throw a web: abdomen up, then a forward flick of the front legs.
A.web = { time = 0.32, keys = {
    { 0 }, { 0.3, rear = 2, lunge = -2 }, { 0.5, lunge = 2, reach = 2.5, stretch = 0.08 }, { 1 } } }

-- Silk wall: front legs out handling the strand while it's being drawn.
A.silkwall = { time = 0.5, holdAt = 0.35, hold = function(p) return p.weave ~= nil end, keys = {
    { 0 }, { 0.35, reach = 2.5, rear = 1, shake = 0.3 }, { 1 } } }

-- Dragline: rears to fire, then hauls the catch in hand over hand.
A.dragline = { time = 0.45, holdAt = 0.45, hold = function(p) return p.carry ~= nil and p.carry.kind == "yank" end, keys = {
    { 0 }, { 0.2, rear = 2, lunge = 1, reach = 2 }, { 0.45, rear = 1, lunge = -2, reach = 1.5, shake = 0.5 },
    { 0.7, fang = 1, lunge = 2 }, { 1 } } }

-- Swing and hurl: clamps, strains and lifts, swings, then lunges into the throw.
A.clubthrow = { time = 0.6, holdAt = 0.4, hold = function(p) return p.carry ~= nil and p.carry.kind == "swing" end, keys = {
    { 0 }, { 0.15, jaw = 1, lunge = 3 }, { 0.3, jaw = -0.5, rear = 2.5, spread = 0.3, shake = 0.6 },
    { 0.4, jaw = -0.5, rear = 2.5, spread = 0.3, shake = 0.6 }, { 0.6, jaw = 1, lunge = 4, rear = 1, stretch = 0.1 }, { 1 } } }

-- Fang slam: (the rear-up itself comes from player.rear) front legs and fangs up, then crash.
A.fangslam = {
    build = function(params)
        local w = params.windup or 0.28
        local tot = w + 0.32
        local pw = w / tot
        return { time = tot, keys = {
            { 0 },
            { pw * 0.9, reach = 3.5, fang = 1, lunge = -2 },
            { pw + 0.06, fang = -0.4, lunge = 5, rear = -3, stretch = -0.15, spread = 0.4, shake = 1 },
            { pw + 0.3, lunge = 2, rear = -1, spread = 0.2 },
            { 1 } } }
    end,
}

-- Spiderlings: shakes its back to send the brood off.
A.spiderlings = { time = 0.45, keys = { { 0 }, { 0.15, shake = 1.5, rear = 1.5 }, { 0.6, shake = 1.5, rear = 1 }, { 1 } } }

-- Snatch: forelegs shoot out, snap in, hold on munching; let go to fling.
A.snatch = { time = 0.6, holdAt = 0.5, hold = function(p) return p.carry ~= nil and p.carry.kind == "snatch" end, keys = {
    { 0 },
    { 0.2, L = 1.2, R = 1.2, lunge = 4, stretch = 0.1 },
    { 0.35, L = 0.3, R = 0.3, rear = 1 },
    { 0.5, L = 0.3, R = 0.3, rear = 1, shake = 0.4 },
    { 0.7, L = 1, R = 1, lunge = 2, twist = 0.3 },
    { 1 } } }

-- Twin slashes: left then right, the body twisting into each.
A.slashes = {
    build = function(params)
        local gap = params.gap or 0.09
        local tot = gap + 0.26
        local g = gap / tot
        return { time = tot, keys = {
            { 0, L = 0.2 },
            { 0.12, L = 1.15, twist = -0.35, lunge = 2 },
            { g, L = 0.6, R = 0.3, twist = 0 },
            { g + 0.12, L = 0.1, R = 1.15, twist = 0.35, lunge = 2 },
            { g + 0.3, R = 0.5, twist = 0.1 },
            { 1 } } }
    end,
}

-- Scorpion pincers and sting: snap left, snap right, then the tail comes over.
A.pinchsting = {
    build = function(params, p)
        local combo = p.attack and p.attack.combo or 1
        if combo < 3 then
            return { time = 0.2, side = combo == 1 and -1 or 1, keys = {
                { 0, open = 0.3 }, { 0.3, pinch = 1, open = 1, lunge = 2, twist = 0.2 }, { 0.55, pinch = 0.8, open = 0, lunge = 1 }, { 1 } } }
        end
        return { time = 0.32, keys = {
            { 0, show = 1 },
            { 0.35, tail = 0.55, rear = 1, lunge = -1, show = 1 },
            { 0.5, tail = 1.05, lunge = 3, stretch = 0.06, show = 1 },
            { 0.75, tail = 1, show = 1 },
            { 1, tail = 0.2 } } }
    end,
}

A.venomsting = { time = 0.4, keys = {
    { 0, show = 1 },
    { 0.4, tail = 0.6, rear = 2, lunge = -2, open = 1, guard = 0.5, show = 1 },
    { 0.55, tail = 1.15, lunge = 4, stretch = 0.08, open = 1, guard = 0.5, show = 1 },
    { 0.8, tail = 1, show = 1 },
    { 1, tail = 0.2 } } }

A.venomchain = { time = 0.3, keys = { { 0 }, { 0.3, rear = 1.5, lunge = -1 }, { 0.5, lunge = 3, stretch = 0.08 }, { 1 } } }

-- ---------------------------------------------------------------------------------------------
-- Limbs (body sprite pixels from the centre; u forward, v to the side)
-- ---------------------------------------------------------------------------------------------

-- Stag beetle antler-jaws: blend "jaw" 1 = gaping, negative = clamped shut.
local STAG_JAWS = { { u = 7, v = 2.2, pair = true, ch = "jaw", width = 2, color = "D",
    segs = { { 4.0, 0.52 }, { 4.0, -0.42 }, { 3.8, -0.53 }, { 2.6, -0.54 } },
    strike = { { 4.4, 1.0 }, { 4.2, -0.42 }, { 3.8, -0.6 }, { 2.6, -0.7 } } } }

-- Tiger beetle sickle jaws.
local TIGER_JAWS = { { u = 8.7, v = 1.2, pair = true, ch = "jaw", width = 1, color = "w",
    segs = { { 2.6, 0.48 }, { 2.15, -0.96 }, { 1.0, -0.9 } },
    strike = { { 3.0, 1.0 }, { 2.6, -0.9 }, { 1.4, -1.0 } } } }

-- Scorpion: pincer arms (one side per snap) and the tail curling over to sting.
local SCORP_PINCER = { u = 6, v = 2, ch = "pinch", open = "open", width = 2, color = "C", tip = "pincer", tipLen = 3,
    segs = { { 3.9, 0.69 }, { 2.9, -0.15 }, { 3.2, -0.3 } },
    strike = { { 4.4, 0.3 }, { 4.0, -0.15 }, { 3.6, -0.15 } } }
local SCORP_GUARD = { u = 6, v = 2, pair = true, ch = "guard", open = "open", width = 2, color = "C", tip = "pincer", tipLen = 3,
    segs = SCORP_PINCER.segs, strike = { { 3.8, 0.9, 0.5 }, { 3, -0.6, 0 }, { 3, -0.4, 0 } } }
local SCORP_TAIL = { u = -12, v = 0, z = 3, ch = "tail", alpha = "show", width = 3, color = "3", tip = "sting", tipLen = 3.5,
    segs = { { 2.5, pi - 0.3, 0.3 }, { 2.5, -0.9, 0 }, { 2.5, -0.9, 0.1 }, { 2.5, -0.9, 0.1 }, { 2, -0.6, 0 } },
    strike = { { 7, 0, 1.3 }, { 7, 0, -0.65 }, { 7, 0, -0.65 }, { 7, 0, -0.6 }, { 5, 0, -0.5 } } }

-- Spider fangs (chelicerae): "fang" swings them out and down.
local function fangs(u, v, size, color)
    return { u = u, v = v, pair = true, ch = "fang", width = size > 1.5 and 2 or 1, color = color or "w", tip = "fang", tipLen = 1.5 * size,
        segs = { { 1.0 * size, 0.2, 0 }, { 0.8 * size, 0, -0.5 } },
        strike = { { 1.7 * size, 0.5, 0.9 }, { 1.6 * size, -0.4, -0.5 } } }
end

-- Mantis raptorial forelegs: folded at rest, scything out at strike ("L" and "R").
local MANTIS_ARMS = { { u = 7, v = 1, z = 6, pair = true, ch = "R", chR = "L", width = 2, color = "D", tip = "blade", tipLen = 3,
    segs = { { 4.7, 0.56, 0.2 }, { 4.1, -0.4, 0 }, { 3, 2.6, 0 } },
    strike = { { 6, 0.15, 0.3 }, { 6.5, -0.55, -0.2 }, { 3, 1.0, 0 } } } }

-- Centipede forcipules (venom claws).
local CENTI_CLAWS = { { u = 1, v = 1.4, pair = true, ch = "jab", width = 1, color = "l", tip = "fang", tipLen = 1,
    segs = { { 1.9, 0.1 }, { 1.1, -1.1 } }, strike = { { 2.8, -0.1 }, { 1.6, -1.4 } } } }

-- ---------------------------------------------------------------------------------------------
-- Per character
-- ---------------------------------------------------------------------------------------------

-- Rhinoceros beetle: the horn is part of the body, so the whole head swings and tosses.
A["rhino_beetle.attack"] = A.arc
A["rhino_beetle.secondary"] = A.pierce

-- Stag beetle: antler-jaws gape and scissor shut on the sweep; clamp and lift for the throw.
A["stag_beetle.attack"] = withLimbs(A.arc, STAG_JAWS, { time = 0.34 })
A["stag_beetle.secondary"] = withLimbs(A.clubthrow, STAG_JAWS)

-- Tiger beetle: sickle jaws open on the sprint and snap shut through the ants.
A["tiger_beetle.attack"] = withLimbs(A.chargedash, TIGER_JAWS)
A["tiger_beetle.charge"] = withLimbs(A["chargedash.charge"], TIGER_JAWS)
A["tiger_beetle.secondary"] = withLimbs(A.lunge, TIGER_JAWS)

-- Scorpion
A["scorpion.attack"] = withLimbs(A.pinchsting, { SCORP_PINCER, SCORP_TAIL })
A["scorpion.secondary"] = withLimbs(A.venomsting, { SCORP_GUARD, SCORP_TAIL })

-- Lobster: its claws and clips are in content/characters/lobster.lua

-- Centipede
A["centipede.attack"] = withLimbs(A.jabs, CENTI_CLAWS)

-- Spiders
A["jumping_spider.attack"] = withLimbs(A.pounce, { fangs(7, 0.7, 1.2, "w") })
A["jumping_spider.secondary"] = withLimbs(A.dragline, { fangs(7, 0.7, 1.2, "w") })
A["tarantula.attack"] = withLimbs(A.fangslam, { fangs(8, 1.1, 1.5, "w") })
A["tarantula.secondary"] = A.hairflick
A["tarantula.dash"] = withLimbs(A.leapslam, { fangs(8, 1.1, 1.5, "w") })
A["wolf_spider.attack"] = withLimbs(A.nova, { fangs(7, 0.7, 1.3, "w") })

-- Mantis
A["mantis.attack"] = withLimbs(A.slashes, MANTIS_ARMS)
A["mantis.secondary"] = withLimbs(A.snatch, MANTIS_ARMS)

-- ---------------------------------------------------------------------------------------------
-- Dashes of their own (round 16): body-only clips by dash type
-- ---------------------------------------------------------------------------------------------

-- Ambush: low and stretched on the dart, a jolt as the beak goes in.
A.ambush = {
    build = function(params)
        local t = dashTime(params)
        return { time = t + 0.14, keys = {
            { 0, rear = -1, stretch = 0.16, lunge = 2 },
            { 0.6, stretch = 0.2, lunge = 4, rear = -0.5 },
            { 0.75, stretch = -0.1, shake = 0.6, lunge = 1 },
            { 1 } } }
    end,
}
-- Claw wall (stamina hold): braced low behind the claws for as long as it's held.
A.clawwall = { time = 0.35, holdAt = 0.5, hold = function(p) return p.holdMode ~= nil end, keys = {
    { 0 }, { 0.5, rear = -1.2, spread = 0.35, lunge = 1, stretch = -0.06 }, { 1 } } }
-- Scurry: flattened right down, legs a blur.
A.scurry = { time = 0.2, keys = { { 0, stretch = 0.18, rear = -1.2, spread = 0.2, shake = 0.3 }, { 0.7, stretch = 0.1 }, { 1 } } }
-- Safety line: a spring up with the front legs reaching, a soft landing.
A.safetyline = A.dash
-- Horn charge: head down and driving, the horn heaving up at the end.
A.horncharge = {
    build = function(params)
        local t = dashTime(params)
        local tot = t + 0.16
        local stop = t / tot
        return { time = tot, keys = {
            { 0, rear = -1.5, lunge = 3, stretch = 0.12, spread = 0.2 },
            { stop * 0.9, rear = -1.5, lunge = 3, stretch = 0.12, shake = 0.3 },
            { stop + 0.08, rear = 2.5, lunge = 1, stretch = -0.1 },
            { 1 } } }
    end,
}
-- Tail flick: a rear-up as it springs back, the tail cracking forward.
A.tailflick = { time = 0.3, keys = {
    { 0, rear = 2, lunge = -2, stretch = -0.1, tail = 1.2, show = 1 },
    { 0.5, rear = 1, lunge = -1, tail = 0.8, show = 1 },
    { 1, tail = 0.2 } } }
-- Clumsy flight: wing cases up, wobbling through the air, a heavy squash on landing.
A.clumsyflight = {
    build = function(params)
        local t = dashTime(params, params.speed or 0.5)
        local tot = t + 0.2
        local land = t / tot
        return { time = tot, keys = {
            { 0, rear = -1.5, spread = 0.35, stretch = -0.1 },
            { 0.15, rear = 1.5, stretch = 0.08, reach = 2, shake = 0.5 },
            { land * 0.9, rear = 1, reach = 2, shake = 0.5, twist = 0.1 },
            { land + 0.05, rear = -2.5, stretch = -0.2, spread = 0.45, shake = 1 },
            { 1 } } }
    end,
}

-- Leaf sway: rocks over to one side like a leaf in the wind, forelegs folded ready to strike.
A.leafsway = { time = 0.32, keys = {
    { 0, twist = 0.25, rear = 1, stretch = -0.06 },
    { 0.4, twist = -0.2, side = 1.5, rear = 1.5, shake = 0.2, reach = 1 },
    { 0.75, twist = 0.08, rear = 0.5 },
    { 1 } } }

-- Per character dashes with limbs
A["mantis.dash"] = withLimbs(A.leafsway, MANTIS_ARMS)
A["scorpion.dash"] = withLimbs(A.tailflick, { SCORP_GUARD, SCORP_TAIL })
A["stag_beetle.dash"] = withLimbs(A.clumsyflight, STAG_JAWS)
A["jumping_spider.dash"] = withLimbs(A.safetyline, { fangs(7, 0.7, 1.2, "w") })
A["rhino_beetle.dash"] = A.horncharge

return A
