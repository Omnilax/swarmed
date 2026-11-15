-- The Final Swarm: an optional last stand after the run is won (the victory screen's "Final
-- Swarm"). The waves stop and every species met pours in from every side for DURATION seconds,
-- faster and faster, with lots of elites and a crowned queen halfway. Live through it and the
-- swarm breaks: the run ends with a "Swarm survived" screen (records: swarmsSurvived, the
-- bug's best swarm KOs). Dying in it still counts the run as won.
-- world.finalSwarm is the live swarm; it emits "final_swarm_over" { survived, kills, time }.
local Entries = require("src.game.entries")

local FinalSwarm = {
    DURATION = 60,
    GAP = { 1.1, 0.35 },     -- seconds between packs: at the start, at the end
    PACK = 0.7,              -- pack size x the wave's usual group size
    MAX_ALIVE = 450,         -- kept lower than the waves' cap so phones keep up
    ELITES = { mul = 3, anyWave = true },
}
FinalSwarm.__index = FinalSwarm

function FinalSwarm.start(world)
    local sp = world.spawner
    local self = setmetatable({ world = world, t = 0, packT = 2, kills = 0, queenSent = false, done = false,
        kos0 = world.kos }, FinalSwarm)
    world.finalSwarm = self
    world.pendingChoice = nil
    sp.enabled = false          -- no more waves; the swarm sends its own packs
    sp.eliteCfg = FinalSwarm.ELITES
    sp.crownLeft = sp.crownLeft or 0
    self.off = world.events:on("enemy_died", function() if not self.done then self.kills = self.kills + 1 end end)
    world.camera:shake(0.4)
    world:floatText(world.player.x, world.player.y - 16, "THE FINAL SWARM", { 1, 0.45, 0.35 }, true)
    require("src.core.audio").play("ui_confirm", { pitch = 0.6 })
    world.events:emit("final_swarm_started")
    return self
end

function FinalSwarm:left() return math.max(0, FinalSwarm.DURATION - self.t) end

function FinalSwarm:update(dt)
    if self.done then return end
    local world, sp = self.world, self.world.spawner
    if world.player.dead then return self:finish(false) end
    self.t = self.t + dt
    if self.t >= FinalSwarm.DURATION then return self:finish(true) end
    local k = self.t / FinalSwarm.DURATION
    self.packT = self.packT - dt
    if self.packT <= 0 then
        self.packT = FinalSwarm.GAP[1] + (FinalSwarm.GAP[2] - FinalSwarm.GAP[1]) * k
        if world.enemyCount < FinalSwarm.MAX_ALIVE then
            local def = sp:pickEnemy()
            if def then
                local e = sp:edgePoint()
                Entries.send(sp, def, math.max(4, math.floor(sp:groupSize(def, FinalSwarm.PACK))), e[1], e[2])
            end
        end
    end
    -- halfway: one crowned queen joins in
    if not self.queenSent and self.t >= FinalSwarm.DURATION / 2 then
        self.queenSent = true
        local queen = sp:pickQueen()
        if queen then
            local e = sp:edgePoint()
            local st = sp:spawnGroup(queen, 1, e[1], e[2], { noElites = true })
            if st then st.crown = { hpMul = 1.3, scale = 1.25 } end
        end
    end
end

-- survived: the clock ran out with the player alive.
function FinalSwarm:finish(survived)
    if self.done then return end
    self.done = true
    local world = self.world
    if self.off then world.events:off("enemy_died", self.off) end
    local info = { survived = survived, kills = self.kills, time = math.floor(self.t) }
    self.result = info
    if survived then
        -- the swarm breaks: everything left scatters back into the grass
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e and not e.dead then world.particles:burst(e.x, e.y, 2, { { 0.55, 0.45, 0.3 } }, 60, 4, { grav = 120 }) end
        end
        world:clearEnemies()
        world.camera:shake(0.5)
        world:floatText(world.player.x, world.player.y - 16, "THE SWARM BREAKS", { 1, 0.84, 0.4 }, true)
        world.pendingVictory = { wave = world.spawner.wave, first = false, swarm = info, at = world.time + 1.2 }
    end
    world.events:emit("final_swarm_over", info)
end

-- The HUD shows the clock and swarm KOs in place of the wave label (src/ui/hud.lua).

return FinalSwarm
