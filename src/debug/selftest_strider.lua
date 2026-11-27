-- The Water Strider (built-in scripted bug, content/scripted/water_strider.lua):
--   love . --selftest --strider
-- It joins the roster like a built-in bug (id, family, unlock, achievements, skill tree with its
-- kin branch, music), and its moves work: it glides after a push, the stab kicks it backwards,
-- the ripple slows ants all round, the figure 8 comes back to where it started and shields it.
-- Saves selftest_strider_*.png (ripple, eight, fight).
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    local SM = require("src.game.scriptmoves")
    local ID = "water_strider"

    -- 1. a real roster bug
    local def = Content.characters:get(ID)
    assert(def, "the Water Strider is not in the roster")
    assert(def.builtin and def.custom, "should be a built-in scripted bug")
    assert(def.name == "Water Strider", "name")
    assert(require("src.config.bugfamilies").of(def).id == "insect", "should sit with the insects in bug select")
    assert(require("src.game.unlocks").bugGoal(ID), "should have an unlock goal")
    assert(Content.achievements:get("unlock_bug_" .. ID), "no unlock achievement")
    assert(Content.achievements:get("bug_" .. ID), "no champion achievement")
    local tree = require("src.game.skills").treeFor(ID)
    assert(tree and #tree.branches == 4, "skill tree should have its 3 branches + the insect kin branch")
    assert(tree.branches[4].kin, "4th branch should be the kin branch")
    assert(require("src.core.music").themeFor(def) == "rattle", "music theme")
    local CustomBugs = require("src.game.custombugs")
    assert(not CustomBugs.list[ID], "must not show up as a player-made bug")
    local ok = CustomBugs.register({ id = ID, custom = true, name = "x" })
    assert(not ok, "a custom bug must not replace a built-in scripted bug")
    print("[selftest] strider: in the roster (insect family, unlock, tree, music)")

    -- 2. its moves, in the sandbox
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = ID }))
    wait(0.5)
    local world = game.world
    local pl = world.player
    assert(pl.def.id == ID, "not playing the strider")
    world.flags.god = false
    world.hitstop, world.hitstopCd = 0, 99
    world.pilot = { pressed = {}, down = {} }
    local function step(sec)
        for _ = 1, math.floor(sec * 60) do
            world:update(1 / 60)
            world.pilot.pressed = {}
        end
    end
    local function reset()
        world:clearEnemies()
        world.hazards:clear()
        pl.x, pl.y = world.size * 0.5, world.size * 0.5
        pl.hp = pl.stats:get("maxHp")
        pl.momX, pl.momY, pl.kvx, pl.kvy = 0, 0, 0, 0
        world.pilot.mx, world.pilot.my = nil, nil
        step(0.6)
    end
    local function errs() return SM.errors[ID] end

    -- glide: push for a second, let go, and it keeps sliding
    reset()
    world.pilot.mx, world.pilot.my = 1, 0
    step(1.2)
    local x0, y0 = pl.x, pl.y
    world.pilot.mx, world.pilot.my = 0, 0
    step(0.4)
    local slid = math.sqrt((pl.x - x0) ^ 2 + (pl.y - y0) ^ 2)
    assert(slid > 20, ("should glide after letting go (slid %.1f px in 0.4 s)"):format(slid))
    assert(not errs(), "script error: " .. tostring(errs()))
    print(("[selftest] strider: glides %.0f px after letting go"):format(slid))

    -- stab: hits the ant in front and kicks the strider backwards
    reset()
    step(0.1)
    local ax, ay = pl.aimX, pl.aimY
    world.flags.freezeAI = true
    world:spawnRing("worker_ant", 1, pl.x + ax * 30, pl.y + ay * 30, 0)
    local e = world.enemies[1]
    local hp0 = e and e.hp
    local sx, sy = pl.x, pl.y
    world.pilot.pressed = { attack = true }
    world.pilot.down = { attack = true }
    world:update(1 / 60)
    world.pilot.down = {}
    step(0.25)
    assert(e and (e.dead or e.hp < hp0), "the stab didn't hurt the ant in front")
    local back = (pl.x - sx) * ax + (pl.y - sy) * ay
    assert(back < -2, ("the stab should kick the strider backwards (moved %.1f along the aim)"):format(back))
    world.flags.freezeAI = false
    print(("[selftest] strider: stab hits and kicks back %.0f px"):format(-back))

    -- ripple: a ring all round that touches (and slows) ants on every side
    reset()
    world.flags.freezeAI = true
    world:spawnRing("worker_ant", 8, pl.x, pl.y, 45)
    local ring = {}
    for i = 1, world.enemyCount do ring[i] = { e = world.enemies[i], hp = world.enemies[i].hp } end
    world.pilot.pressed = { secondary = true }
    world.pilot.down = { secondary = true }
    world:update(1 / 60)
    world.pilot.down = {}
    step(0.2)
    shot("strider_ripple")
    step(0.8)
    local touched = 0
    for _, r in ipairs(ring) do if r.e.dead or r.e.hp < r.hp then touched = touched + 1 end end
    assert(touched >= 6, ("the ripple should reach ants on every side (%d / %d)"):format(touched, #ring))
    world.flags.freezeAI = false
    print(("[selftest] strider: ripple touched %d / %d ants all round"):format(touched, #ring))

    -- figure eight: loops back to the start, touches ants on the way, can't be hurt while looping
    reset()
    world.flags.freezeAI = true
    world:spawnRing("worker_ant", 10, pl.x, pl.y, 40)
    local eight = {}
    for i = 1, world.enemyCount do eight[i] = { e = world.enemies[i], hp = world.enemies[i].hp } end
    local cx, cy = pl.x, pl.y
    world.pilot.pressed = { dash = true }
    world.pilot.down = { dash = true }
    world:update(1 / 60)
    world.pilot.pressed, world.pilot.down = {}, {}
    local far, hp = 0, pl.hp
    for f = 1, 75 do
        world:update(1 / 60)
        far = math.max(far, math.sqrt((pl.x - cx) ^ 2 + (pl.y - cy) ^ 2))
        if f == 20 then
            pl:hurt(5, { x = pl.x + 1, y = pl.y })
            shot("strider_eight")
        end
    end
    assert(pl.hp == hp, "the strider got hurt mid figure 8")
    assert(far > 40, ("the figure 8 should travel out (%.0f px)"):format(far))
    local home = math.sqrt((pl.x - cx) ^ 2 + (pl.y - cy) ^ 2)
    assert(home < 30, ("the figure 8 should end near its start (%.0f px away)"):format(home))
    local hits = 0
    for _, r in ipairs(eight) do if r.e.dead or r.e.hp < r.hp then hits = hits + 1 end end
    assert(hits >= 3, "the figure 8 should touch ants on the way (" .. hits .. ")")
    world.flags.freezeAI = false
    print(("[selftest] strider: figure 8 out %.0f px, back within %.0f px, touched %d ants, no damage"):format(far, home, hits))

    -- breaking out: Shift again mid-loop costs no stamina and skates off the way you steer
    reset()
    local Stamina = require("src.game.stamina")
    world.pilot.pressed = { dash = true }
    world:update(1 / 60)
    world.pilot.pressed = {}
    step(0.3)
    assert(pl._me and pl._me.state.eight, "should be looping")
    local st0 = Stamina.state(pl).cur
    world.pilot.mx, world.pilot.my = -1, 0
    world.pilot.pressed = { dash = true }
    world:update(1 / 60)
    world.pilot.pressed = {}
    assert(not pl._me.state.eight, "Shift mid-loop should break out of the figure 8")
    assert(Stamina.state(pl).cur >= st0 - 1e-6, "breaking out should not cost stamina")
    local bx, by = pl.x, pl.y
    step(0.3)
    local dx, dy = pl.moveDirX, pl.moveDirY
    local went = (pl.x - bx) * dx + (pl.y - by) * dy
    assert(went > 25, ("should skate off the way you steer (%.0f px)"):format(went))
    print(("[selftest] strider: broke out of the loop, skated %.0f px the chosen way"):format(went))

    -- the skill tree: 3 branches of 6 like the main bugs, the kin branch topped by its signature,
    -- and the move-changing nodes are read by the script (me.rank)
    assert(#tree.branches[1].nodes == 6 and #tree.branches[2].nodes == 6 and #tree.branches[3].nodes == 6, "6 nodes per branch")
    local sig
    for _, n in ipairs(tree.branches[4].nodes) do if n.signature then sig = n end end
    assert(sig and sig.id == "water_strider_pondskater", "signature node on the kin branch")
    pl.skills.ranks["water_strider_longneedle"] = 1
    assert(pl._me.rank("longneedle") == 1, "me.rank should read the strider's own node ids")
    pl.skills.ranks["water_strider_longneedle"] = nil

    -- a short fight with every move (and every node), no script errors
    for _, br in ipairs(tree.branches) do for _, n in ipairs(br.nodes) do pl.skills.ranks[n.id] = n.ranks or 1 end end
    pl.skills:apply()
    reset()
    world:spawnRing("worker_ant", 12, pl.x, pl.y, 70)
    for f = 1, 240 do
        local ph = f % 60
        world.pilot.pressed = { attack = ph % 12 == 1, secondary = ph == 20, dash = ph == 40 }
        world.pilot.down = { attack = ph % 12 < 4 }
        world.pilot.mx, world.pilot.my = math.cos(f * 0.05), math.sin(f * 0.05)
        world:update(1 / 60)
    end
    world.pilot = nil
    assert(not errs(), "script error in a fight: " .. tostring(errs()))
    shot("strider_fight")
    print("[selftest] strider: OK")
end
