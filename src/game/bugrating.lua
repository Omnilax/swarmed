-- A custom bug's "power level" (Bug Creator > Rate It): the bug plays the same short fight a
-- few built-in bugs play (waves 3 to 5 for 40 seconds, fighting on its own like the title
-- screen bug), and its damage, kills and toughness are compared with theirs. 100 = as strong as
-- an average built-in bug. The fight runs a slice per frame (Rating:step) so the screen stays live.
local Content = require("src.content")
local Audio = require("src.core.audio")

local Rating = {}
Rating.__index = Rating

Rating.REFS = { "rhino_beetle", "mantis", "wolf_spider" }
Rating.TIME = 40          -- simulated seconds per fight
local DT = 1 / 30
local cache = {}          -- reference bug id -> result (kept for the session)

-- One fight: returns a stepper; done() -> result { dealt, kills, taken, alive, time }
local function fight(charId)
    local World = require("src.game.world")
    love.math.setRandomSeed(1234)
    local w = World.new({ mode = "run", character = charId, seed = 1234 })
    w.flags.demo = true
    w.rewards.frenzy.max = 1e9           -- no ultimates (they would swing short fights)
    local r = { dealt = 0, kills = 0, taken = 0, alive = true, time = 0 }
    w.events:on("enemy_hit", function(ctx) r.dealt = r.dealt + (ctx.damage or 0) end)
    w.events:on("enemy_killed", function() r.kills = r.kills + 1 end)
    w.events:on("player_hurt", function(ctx) r.taken = r.taken + (ctx.damage or 0) end)
    w.spawner:startWave(3)
    local steps = math.floor(Rating.TIME / DT)
    local i = 0
    return function(budget)
        local muted = Audio.muted
        Audio.muted = true
        for _ = 1, budget do
            if i >= steps or w.player.dead then break end
            i = i + 1
            w.pendingChoice = nil
            w:update(DT)
            if w.spawner.phase == "break" then w.spawner:startWave(math.min(8, (w.spawner.wave or 3) + 1)) end
        end
        Audio.muted = muted
        r.time = i * DT
        if w.player.dead then r.alive = false end
        local done = i >= steps or w.player.dead
        if done then
            r.hpLeft = w.player.hp / w.player.stats:get("maxHp")
            w.events.handlers = {}
        end
        return done, i / steps
    end, r
end

function Rating.new(charId)
    local self = setmetatable({ id = charId, queue = {}, results = {}, progress = 0 }, Rating)
    for _, ref in ipairs(Rating.REFS) do
        if Content.characters:get(ref) and not cache[ref] then self.queue[#self.queue + 1] = ref end
    end
    self.queue[#self.queue + 1] = charId
    self.total = #self.queue
    return self
end

-- Run some of the fights. Returns true when the rating is ready (self.score, self.parts).
function Rating:step(budget)
    if self.score then return true end
    local id = self.queue[1]
    if not id then self:finish() return true end
    if not self.cur then
        local ok, stepper, r = pcall(fight, id)
        if not ok then self.error = tostring(stepper) self:finish() return true end
        self.cur, self.curR = stepper, r
    end
    local ok, done, p = pcall(self.cur, budget or 60)
    if not ok then self.error = tostring(done) self.cur = nil table.remove(self.queue, 1) return false end
    self.progress = ((self.total - #self.queue) + (p or 0)) / self.total
    if done then
        if id == self.id then self.mine = self.curR else cache[id] = self.curR end
        self.cur = nil
        table.remove(self.queue, 1)
    end
    return false
end

function Rating:finish()
    local ref = { dealt = 0, kills = 0, taken = 0, time = 0, n = 0 }
    for _, id in ipairs(Rating.REFS) do
        local r = cache[id]
        if r then
            ref.dealt, ref.kills, ref.taken, ref.time, ref.n = ref.dealt + r.dealt, ref.kills + r.kills, ref.taken + r.taken, ref.time + r.time, ref.n + 1
        end
    end
    local m = self.mine
    if not m or ref.n == 0 then self.score = 0 return end
    for _, k in ipairs({ "dealt", "kills", "taken", "time" }) do ref[k] = ref[k] / ref.n end
    -- damage per second, kills, and how well it stands up (time alive, damage taken per second)
    local offense = (m.dealt / math.max(1, m.time)) / math.max(1, ref.dealt / math.max(1, ref.time))
    local kills = (m.kills + 1) / (ref.kills + 1)
    local takenRate = (m.taken / math.max(1, m.time)) / math.max(0.5, ref.taken / math.max(1, ref.time))
    local tough = (m.time / Rating.TIME) * math.min(2.5, 1 / math.max(0.25, takenRate))
    local score = 100 * (offense ^ 0.4) * (kills ^ 0.3) * (tough ^ 0.3)
    self.score = math.floor(score + 0.5)
    self.parts = { offense = offense, kills = kills, tough = tough, mine = m, ref = ref }
    -- remembered in the bug's record
    local Records = require("src.game.records")
    local p = Records.get()
    local c = p.characters[self.id]
    if not c then
        c = { runs = 0, wins = 0, kills = 0, bestWave = 0 }
        p.characters[self.id] = c
    end
    c.power = self.score
    pcall(Records.save)
end

function Rating.words(score)
    if score >= 170 then return "Overpowered: far stronger than the built-in bugs"
    elseif score >= 130 then return "Strong: a cut above most built-in bugs"
    elseif score >= 85 then return "Fair: about as strong as a built-in bug"
    elseif score >= 55 then return "Weak: a tough run ahead"
    else return "Very weak: a real challenge" end
end

return Rating
