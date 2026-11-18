-- Termite queen: a boss that barely moves. Her body is one enormous egg factory: she lays
-- clutches of eggs in a ring around herself that hatch into workers, soldiers and nasutes, and
-- now and then a whole brood streams out of her. She arrives with her king, who guards her;
-- while he lives she is tended and slowly heals. Kill the king and she stops healing but
-- panics, laying much faster. Get right up to her and soldiers rush out to plug the gap.
-- params: brood (enemy id streamed out, "termite_worker"), castes (list streamed in turn),
--         interval (seconds between clutches, 4.5), clutches (per laying, 3), egg ("termite_eggs"),
--         king (enemy id, "termite_king"), heal (fraction of max hp per second while tended, 0.012),
--         keep (distance from the player, 140), guard (soldier id, "termite_soldier")
local AI = require("src.game.ai")
local Content = require("src.content")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.95, 0.92, 0.82 }
local PFX_LIST_1 = { PFX_1 }

local function kingAlive(st)
    local k = st.king
    return k and k.uid == st.kingUid and not k.dead
end

return {
    name = "Termite queen",
    kingAlive = kingAlive,
    init = function(e) e.st.cd, e.st.layings, e.st.guardCd, e.st.needKing = 2.5, 0, 0, true end,
    update = function(e, world, dt, params)
        local st = e.st
        -- the king is spawned on her first update (not inside spawn, which is still filling her slot)
        if st.needKing then
            st.needKing = false
            local kdef = Content.enemies:get(params.king or "termite_king")
            local k = kdef and world:spawnEnemy(kdef, e.x + 14, e.y + 6)
            if k then
                st.king, st.kingUid = k, k.uid
                k.st.queen, k.st.queenUid = e, e.uid
            end
        end
        local dx, dy, d = AI.toPlayer(e, world)
        local keep = params.keep or 140
        local want = math.max(-1, math.min(1, (d - keep) / 40))
        e.mx, e.my = dx / d * want * e.speed, dy / d * want * e.speed
        -- the abdomen heaves as she breathes
        if math.sin(world.time * 2.2) > 0.97 then e.squash = 0.08 end

        local tended = kingAlive(st)
        if tended and e.hp < e.maxHp then
            e.hp = math.min(e.maxHp, e.hp + e.maxHp * (params.heal or 0.012) * dt)
            if love.math.random() < dt * 3 then
                world.particles:spawn(e.x + (love.math.random() - 0.5) * 16, e.y + (love.math.random() - 0.5) * 8, 8,
                    0, 0, 18, 0.6, { 0.95, 0.9, 0.6 }, 1, { glow = true, grav = -15 })
            end
        end
        if st.wasTended and not tended then
            world:floatText(e.x, e.y, "THE QUEEN PANICS", { 1, 0.6, 0.3 }, true)
        end
        st.wasTended = tended

        st.cd = st.cd - dt
        st.guardCd = st.guardCd - dt
        if d < 45 and st.guardCd <= 0 then
            -- soldiers burst out to plug the breach
            st.guardCd = 6
            local g = Content.enemies:get(params.guard or "termite_soldier")
            if g then world.spawner:spawnGroup(g, 3, e.x, e.y, { noElites = true }) end
        end
        if st.cd <= 0 then
            st.cd = (params.interval or 4.5) * (tended and 1 or 0.55)
            st.layings = st.layings + 1
            e.squash = 0.25
            Audio.play("dash", { pitch = 0.5 })
            local egg = Content.enemies:get(params.egg or "termite_eggs")
            local n = params.clutches or 3
            local a0 = love.math.random() * 6.28
            for i = 1, egg and n or 0 do
                local a = a0 + i / n * math.pi * 2
                world:spawnEnemy(egg, e.x + math.cos(a) * 18, e.y + math.sin(a) * 18)
            end
            -- every third laying a whole brood streams out, a different caste each time
            if st.layings % 3 == 0 then
                local castes = params.castes or { params.brood or "termite_worker" }
                local def = Content.enemies:get(castes[(math.floor(st.layings / 3) - 1) % #castes + 1])
                if def then
                    local cnt = math.max(2, math.floor(10 * (def.spawn.groupSize or 1) ^ 0.5))
                    world.spawner:spawnGroup(def, cnt, e.x, e.y, { noElites = true })
                end
            end
            world.particles:burst(e.x, e.y, 10, PFX_LIST_1, 60, 40)
        end
    end,
    -- a faint golden line to her king while he tends her
    drawUnder = function(e, world)
        local st = e.st
        if not kingAlive(st) then return end
        local x1, y1 = Iso.toScreen(e.x, e.y)
        local x2, y2 = Iso.toScreen(st.king.x, st.king.y)
        love.graphics.setColor(1, 0.85, 0.45, 0.12 + 0.06 * math.sin(world.time * 3))
        love.graphics.line(x1, y1, x2, y2)
    end,
}
