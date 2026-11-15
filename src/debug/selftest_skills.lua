-- Skill trees: XP from kills, points, buying every node (both sides of each fork), and a short
-- fight with the whole tree active for every bug. Screenshots of the tree screen.
--   love . --selftest --skills   runs just this part (also part of the full selftest)
local State = require("src.core.state")
local Content = require("src.content")
local Skills = require("src.game.skills")

-- Buy everything available, preferring the left (first) or right (last) side of each fork.
local function buyAll(sk, side)
    local bought = true
    while bought do
        bought = false
        local nodes = {}
        for _, br in ipairs(sk.tree.branches) do
            for _, n in ipairs(br.nodes) do nodes[#nodes + 1] = n end
        end
        if side == "right" then
            local r = {}
            for i = #nodes, 1, -1 do r[#r + 1] = nodes[i] end
            nodes = r
        end
        for _, n in ipairs(nodes) do
            if sk:status(n) == "available" then
                assert(sk:buy(n.id), "could not buy " .. n.id)
                bought = true
            end
        end
    end
end

-- Fire everything the bug has, the way Player:update does (with the skill hooks).
local function useEverything(pl, world)
    local sk = pl.skills
    local atk = pl.attack
    local params = sk:before("attack", atk.params)
    atk.type.fire(pl, world, pl.aimX, pl.aimY, params)
    sk:after("attack", pl.aimX, pl.aimY, nil, nil, params)
    local sec = pl.secondary
    if sec then
        local px, py = pl.x + pl.aimX * 70, pl.y + pl.aimY * 70
        params = sk:before("secondary", sec.params)
        sec.type.fire(pl, world, pl.aimX, pl.aimY, params, px, py)
        sk:after("secondary", pl.aimX, pl.aimY, px, py, params)
    end
    if pl.dashDef.hold then
        pl.dashDef.update(pl, world, 0.016, pl.dashParams, true)
        pl:hurt(5, world.enemies[1])
        pl.dashDef.update(pl, world, 0.016, pl.dashParams, false)
    elseif pl.dashT <= 0 and not pl.grapple then
        pl.dashDef.start(pl, world, -pl.aimX, -pl.aimY, pl.dashParams, pl.x - pl.aimX * 100, pl.y - pl.aimY * 100)
        pl.dashT0 = pl.dashT
        pl.inventory:trigger("onDash", { world = world, player = pl, procDepth = 0 })
    end
end

return function(wait, shot)
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.3)
    local world = game.world
    local pl = world.player
    world.spawner.enabled = false
    world.levelups.disabled = true      -- the classic way: levels give skill points (--levelups tests cards)

    -- XP: one per kill, levels give points, the curve climbs
    local sk = pl.skills
    assert(sk and sk.tree, "rhino beetle has no skill tree")
    assert(sk.level == 0 and sk.points == 0, "fresh bug should start at level 0")
    local e = world:spawnEnemy("worker_ant", pl.x + 30, pl.y)
    require("src.game.combat").damage(world, e, 9999, { noCrit = true })
    -- (the XP comes as a nectar bead that drifts in once it is inside Pickup Range)
    for _ = 1, 60 do world:update(1 / 60) end
    assert(sk.xp == 1, "a kill should give 1 XP (got " .. sk.xp .. ")")
    world:grantXP(Skills.xpFor(1) - 1)
    assert(sk.level == 1 and sk.points == 1, "first level should give a skill point")
    assert(Skills.xpFor(10) > Skills.xpFor(2), "XP curve should climb")
    local n1 = sk.tree.branches[1].nodes[1]
    local hpBefore = pl.attack.params.damage
    assert(sk:buy(n1.id), "could not buy a tier 1 node")
    assert(pl.attack.params.damage > hpBefore, "buying Heavy Horn did not raise sweep damage")
    assert(Content.characters:get("rhino_beetle").attack.damage == hpBefore, "skill mods leaked into the character def")
    -- a run can't finish the whole tree by wave ~20: level-up cards offer at most one node a
    -- pick (chance skillShare); a 15-wave run is ~12-15k XP, wave 20 ~20k
    local cfg = require("src.config.levelups")
    local lv, xp = 0, 20000
    while xp >= Skills.xpFor(lv + 1) do xp = xp - Skills.xpFor(lv + 1); lv = lv + 1 end
    local offers = math.ceil(lv * cfg.skillShare)
    for _, t in ipairs(Content.skilltrees:all()) do
        local ranks = 0           -- the cheapest full tree: per tier, the fork side with fewest ranks
        for _, br in ipairs(t.branches) do
            local byTier = {}
            for _, n in ipairs(br.nodes) do byTier[n.tier] = math.min(byTier[n.tier] or math.huge, n.ranks) end
            for _, r in pairs(byTier) do ranks = ranks + r end
        end
        assert(ranks > offers, t.id .. " tree (" .. ranks .. " ranks) can be finished in one run (" .. offers .. " node offers)")
    end
    print(("[selftest] skills: level %d by wave 20, ~%d node offers"):format(lv, offers))

    -- the tree screen, via the bag's tab
    world:grantXP(400)
    local Inv = require("src.states.inventory")
    local inv = State.push(Inv.new(game))
    wait(0.1)
    require("src.states.skilltree").openFrom(inv)
    local tree = State.top()
    assert(tree.skills == sk, "SKILLS tab did not open the tree")
    wait(0.2)
    shot("skilltree")
    tree:toBag()
    wait(0.1)
    shot("skilltree_bagtab")
    State.pop()

    -- every bug: buy the whole tree (left forks, then right forks) and fight with it
    game = State.switch(Game.new({ mode = "sandbox", character = "rhino_beetle" }))
    wait(0.3)
    world = game.world
    world.flags.god = true
    local count = 0
    for _, cdef in ipairs(Content.characters:all()) do
        if Skills.treeFor(cdef.id) then
            for _, side in ipairs({ "left", "right" }) do
                world:clearEnemies()
                pl = world.player
                pl.skills = nil
                pl:setCharacter(cdef)
                pl.x, pl.y = world.size * 0.5, world.size * 0.5
                pl.momX, pl.momY = 0, 0
                sk = pl.skills
                sk:gainXP(200000, true)
                buyAll(sk, side)
                for _, n in pairs(sk.tree.nodes) do
                    local st = sk:status(n)
                    assert(st == "maxed" or st == "excluded", cdef.id .. ": node " .. n.id .. " left " .. st)
                end
                world:spawnRing("worker_ant", 40, pl.x, pl.y, 40)
                world:spawnRing("soldier_ant", 8, pl.x, pl.y, 70)
                for k = 1, 90 do
                    if k % 15 == 1 then
                        local t = world:nearestEnemy(pl.x, pl.y, 200)
                        if t then pl.aimX, pl.aimY = require("src.core.util").normalize(t.x - pl.x, t.y - pl.y) end
                        useEverything(pl, world)
                    end
                    world:update(1 / 30)
                    if pl.secondary and pl.secondary.type.update then
                        pl.secondary.type.update(pl, world, 1 / 30, pl.secondary.params, k % 30 < 10, pl.x + 60, pl.y)
                    end
                end
                if side == "left" and cdef.id == "bombardier_beetle" then shot("skills_fight_bombardier") end
                if side == "left" and cdef.id == "stag_beetle" then shot("skills_fight_stag") end
                count = count + 1
            end
        else
            print("[selftest] skills: no tree yet for " .. cdef.id)
        end
    end
    world:clearEnemies()
    world.hazards:clear()
    -- swapping bugs keeps the XP and refunds the points
    pl = world.player
    local xpNow = pl.skills.xp
    pl:setCharacter(Content.characters:get("mantis"))
    assert(pl.skills.xp == xpNow and pl.skills.spent == 0 and pl.skills.points > 0, "swap should keep XP and refund points")
    print(("[selftest] skills OK (%d trees x 2 fork sides fought)"):format(count / 2))
end
