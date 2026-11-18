-- Queens with phases, the Empress and named champions (src/game/bosses.lua).
--   love . --selftest --bosses   (saves selftest_boss_card.png, selftest_empress.png, selftest_champion.png)
local State = require("src.core.state")
local Records = require("src.game.records")
local Content = require("src.content")

return function(wait, shot)
    Records.noSave = true
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = "dune_field", seed = 5 }))
    wait(0.2)
    local w = game.world
    w.flags.god = true
    local p = w.player

    -- a queen walks in: title card, then she enrages at half health and calls her brood
    local qd = Content.enemies:require("queen_desert")
    local q = w:spawnEnemy(qd, p.x + 120, p.y)
    assert(w.boss == q, "a queen owns the boss bar")
    wait(0.5)
    local card = w.bosses.card
    assert(card and card.title == qd.name:upper(), "a queen gets a title card")
    print("[selftest] queen card: " .. card.title .. " / " .. card.sub)
    shot("boss_card")
    local speed, count = q.speed, w.enemyCount
    q.hp = math.floor(q.maxHp * 0.45)
    wait(0.1)
    assert(q.enraged == 1 and q.speed > speed, "a queen under half health should enrage")
    assert(w.enemyCount > count, "an enraged queen calls her brood")
    w:clearEnemies()
    wait(0.1)

    -- the last crowned queen of the final wave is the Empress, with two phases
    local sp = w.spawner
    sp.finalThisWave, sp.crownLeft = true, 0
    local e = w:spawnEnemy(qd, p.x + 120, p.y)
    e.title = "Crowned " .. qd.name
    wait(0.5)
    assert(e.empress and e.title == "The Empress" and #e.phases.list == 2, "the last crowned queen is the Empress")
    assert(w.bosses.card.title == "THE EMPRESS", "the Empress gets her card")
    shot("empress")
    w:clearEnemies()
    sp.finalThisWave = false
    wait(3.5)

    -- a champion: the first elite on wave 3
    w.events:emit("wave_started", 3)
    local elite = Content.elites:all()[1]
    local c = w:spawnEnemy(Content.enemies:require("worker_ant"), p.x + 90, p.y, elite)
    assert(c.champion and w.champion == c, "the first elite of wave 3 is a named champion")
    local hp, cname = c.maxHp, c.champion
    wait(0.6)
    shot("champion")
    local xp, nectar = w.xp, w.nectar
    w:killEnemy(c)
    wait(0.1)
    assert(w.champion == nil, "a slain champion leaves the bar")
    assert(w.nectar > nectar, "a champion pays nectar")
    -- only one champion a wave
    local c2 = w:spawnEnemy(Content.enemies:require("worker_ant"), p.x + 90, p.y, elite)
    assert(not c2.champion, "only the first elite is a champion")
    print(("[selftest] champion %s, %d hp"):format(cname, hp))
    print("[selftest] bosses OK")
end
