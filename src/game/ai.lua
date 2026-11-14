-- Small helpers shared by enemy behaviours (content/behaviors).
local AI = {}

-- Vector to the player: dx, dy, distance.
function AI.toPlayer(e, world)
    local p = world.player
    local dx, dy = p.x - e.x, p.y - e.y
    return dx, dy, math.sqrt(dx * dx + dy * dy) + 0.0001
end

-- Move toward a point at `speed` (slows down as it arrives).
function AI.goTo(e, tx, ty, speed)
    local dx, dy = tx - e.x, ty - e.y
    local d = math.sqrt(dx * dx + dy * dy) + 0.0001
    local s = speed * math.min(1, d / 6)
    e.mx, e.my = dx / d * s, dy / d * s
    return d
end

-- A hop through the air from (st.jx0, st.jy0) to (st.jx1, st.jy1) over st.jdur seconds.
-- Call AI.startJump then AI.updateJump each frame until it returns true (landed).
function AI.startJump(e, tx, ty, dur, height)
    local st = e.st
    st.jx0, st.jy0, st.jx1, st.jy1 = e.x, e.y, tx, ty
    st.jt, st.jdur, st.jh = 0, dur, height or 12
end

function AI.updateJump(e, dt)
    local st = e.st
    st.jt = st.jt + dt
    local k = math.min(1, st.jt / st.jdur)
    e.mx = (st.jx1 - st.jx0) / st.jdur
    e.my = (st.jy1 - st.jy0) / st.jdur
    e.z = math.sin(k * math.pi) * st.jh
    if k >= 1 then e.z, e.mx, e.my = 0, 0, 0 return true end
    return false
end

-- Flying bugs (bees, wasps): ease the height toward `h` with a little bob. Fliers only bite
-- or get stung near the ground (z < 3), so drop `h` to ~1 when going in for contact.
function AI.hover(e, world, dt, h)
    local target = h + (h > 2 and math.sin(world.time * 9 + e.uid) * 1.2 or 0)
    e.z = e.z + (target - e.z) * math.min(1, dt * 6)
end

-- A sting from a behaviour (not a contact bite): `mult` x the enemy's damage, with a squash.
function AI.sting(e, world, mult)
    world.player:hurt(e.damage * (mult or 1), e)
    e.squash = 0.12
end

-- Live enemies of one species, sorted by uid (cached per frame), for behaviours where a whole
-- group acts together (giant honey bee shimmer, warrior wasp drumming). Also returns a
-- per-world state table for that species that persists between frames.
local groups = setmetatable({}, { __mode = "k" })
function AI.group(world, id)
    local w = groups[world]
    if not w then w = {} groups[world] = w end
    local g = w[id]
    if not g then g = { list = {}, state = {} } w[id] = g end
    if g.time ~= world.time then
        g.time = world.time
        local list, n = g.list, 0
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if not e.dead and e.def.id == id then n = n + 1 list[n] = e end
        end
        for i = n + 1, #list do list[i] = nil end
        table.sort(list, function(a, b) return a.uid < b.uid end)
        for i = 1, n do list[i].st.rank = i end
    end
    return g.list, g.state
end

-- The closest live, ordinary (non-boss, not held, not hidden) enemy to (x, y) within r that
-- passes filter(o), or nil.
function AI.nearestOther(world, e, x, y, r, filter)
    local list, n = world:queryEnemies(x, y, r)
    local best, bd = nil, r * r
    for i = 1, n do
        local o = list[i]
        if o ~= e and not o.dead and not o.held and not o.hidden and not o.def.boss and (not filter or filter(o)) then
            local d = (o.x - x) ^ 2 + (o.y - y) ^ 2
            if d < bd then best, bd = o, d end
        end
    end
    return best
end

return AI
