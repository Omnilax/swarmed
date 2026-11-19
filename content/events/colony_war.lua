-- Colony war: a rival colony (red) marches in from the far side and goes for your colony's
-- ants; the ants it meets fight back. Both sides count as enemies (the wave waits for them),
-- but every ant they kill is one less for you. Stay out of the middle and let them fight.
local Content = require("src.content")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local function util_contains(t, v) return t ~= nil and util.contains(t, v) end

local TINT = { 1, 0.5, 0.42 }

local function rivalSpecies(world)
    local options = {}
    for _, d in ipairs(world.spawner.knownList or {}) do
        if d.family == "ant" and not d.boss and not d.solid and not util_contains(d.tags, "flying") and (d.damage or 0) > 0 then
            options[#options + 1] = d
        end
    end
    if #options == 0 then return Content.enemies:get("worker_ant") or Content.enemies:all()[1] end
    return options[love.math.random(#options)]
end


local function enlist(world, e, side)
    if e.rival or e.def.boss or e.def.encounter or e.def.solid then return end
    e.rival = side
    e.rivalBase = e.behavior
    e.behavior = Content.behaviors:require("rival")
    if side == "red" then e.tint = TINT end
end

return {
    name = "Colony War",
    description = "A rival colony attacks your colony's ants. Let them fight!",
    color = { 1, 0.5, 0.4 },
    kind = "event",
    weight = 8, minWave = 3,
    allowed = function(world) return world.spawner.mode == nil or not world.spawner.mode.families or util_contains(world.spawner.mode.families, "ant") end,
    start = function(world, ev)
        local st = ev.st
        st.def = rivalSpecies(world)
        local sp = world.spawner
        local p = world.player
        local S = world.size
        -- in from the side opposite the player
        local x0, y0 = S - p.x, S - p.y
        local a = math.atan2(y0 - S / 2, x0 - S / 2)
        st.x, st.y = S / 2 + math.cos(a) * S * 0.48, S / 2 + math.sin(a) * S * 0.48
        local size = math.max(8, math.floor(sp:groupSize(st.def, ev.opts.size or 1.4)))
        st.left, st.cd, st.red, st.enlistT = size, 0, {}, 0
        Audio.play("queen", { pitch = 1.4 })
    end,
    update = function(world, ev, dt)
        local st = ev.st
        -- the invaders pour in
        st.cd = st.cd - dt
        while st.cd <= 0 and st.left > 0 do
            st.cd = st.cd + 0.08
            st.left = st.left - 1
            local e = world:spawnEnemy(st.def, st.x + (love.math.random() - 0.5) * 16, st.y + (love.math.random() - 0.5) * 16)
            if e then
                enlist(world, e, "red")
                st.red[#st.red + 1] = e
                st.spawned = (st.spawned or 0) + 1
            end
        end
        -- colony ants near an invader turn to face it
        st.enlistT = st.enlistT - dt
        local alive = 0
        if st.enlistT <= 0 then
            st.enlistT = 0.5
            for _, r in ipairs(st.red) do
                if not r.dead and r.rival == "red" then
                    alive = alive + 1
                    local list, n = world:queryEnemies(r.x, r.y, 55)
                    for i = 1, n do
                        local o = list[i]
                        if not o.dead and not o.rival and (o.z or 0) < 4 then enlist(world, o, "home") end
                    end
                end
            end
            if st.left <= 0 and alive == 0 then ev.done = true end
        end
    end,
    finish = function(world, ev)
        -- the war is over: colony ants go back to hunting you
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e and not e.dead and e.rival == "home" then
                e.behavior, e.rival = e.rivalBase, nil
                e.st.foe = nil
            end
        end
    end,
}
