-- Enemy instances are plain tables recycled through a pool, so spawning and killing
-- hundreds of ants per minute creates almost no garbage.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Sprites = require("src.gfx.sprites")
local Elites = require("src.game.elites")

local Enemy = {}
local pool = {}
local nextUid = 0

Enemy.DIFFICULTY = {
    larva = { hp = 0.7, damage = 0.6 },
    worker = { hp = 1, damage = 1 },
    soldier = { hp = 1.35, damage = 1.3 },
    queen = { hp = 1.75, damage = 1.6 },
}

-- elite (optional): an affix from content/elites.
function Enemy.spawn(world, def, x, y, elite)
    local e = table.remove(pool) or { st = {} }
    for k in pairs(e.st) do e.st[k] = nil end
    local diff = Enemy.DIFFICULTY[Settings.get("difficulty")] or Enemy.DIFFICULTY.worker
    nextUid = nextUid + 1
    e.uid = nextUid
    e.leader, e.leaderUid = nil, nil
    e.def = def
    e.x, e.y = x, y
    e.mx, e.my, e.kvx, e.kvy = 0, 0, 0, 0
    e.maxHp = math.max(1, math.floor(def.hp * diff.hp * world:hpScale() + 0.5))
    e.hp = e.maxHp
    e.damage = def.damage * diff.damage * world.modeDef.enemyDamage

    e.speed = def.speed * (0.9 + love.math.random() * 0.2)
    if def.boss then world.boss = e end
    e.radius = def.radius
    e.mass = def.mass
    e.scale = def.scale
    e.params = def.behaviorParams
    e.elite = elite
    if elite then
        e.maxHp = math.max(1, math.floor(e.maxHp * elite.hp + 0.5))
        e.hp = e.maxHp
        e.damage = e.damage * elite.damage
        e.speed = e.speed * elite.speed
        e.mass = e.mass * elite.mass
        e.radius = e.radius * elite.scale ^ 0.5
        e.scale = e.scale * elite.scale
        e.params = Elites.params(def, elite)
    end
    e.baseScale = e.scale
    e.sprite = Sprites.get(def.sprite)
    e.shadow = Sprites.shadowFor(e.sprite.w * 0.8 * def.scale)
    e.behavior = Content.behaviors:require(def.behavior)
    e.anim = love.math.random() * 4
    e.angle = math.atan2(world.player.y - y, world.player.x - x)
    e.flash = 0
    e.squash = 0
    e.hurtTimer = 0
    e.spawnT = 0.2
    e.z, e.held, e.heldBy = 0, nil, nil
    e.dropH = nil
    e.tint, e.rival, e.title, e.rushed = nil, nil, nil, nil   -- colony war colours, boss bar names
    e.hidden, e.alpha = nil, nil      -- burrowed (untargetable, undrawn) / see-through (camouflage)
    e.slowT, e.slowMul = 0, 1
    e.stunT, e.corrodeT, e.corrodeMul = 0, 0, 1   -- stunned (hiss), corroded by acid (takes more damage)
    e.poisonT, e.poisonDps, e.poisonTick = 0, 0, 0   -- venom from the player's attacks   -- slowed by webs and hair (Combat opts.slow, web zones)
    e.hitPad = 0     -- extra reach for the player's attacks (charging ants are easier to hit)
    e.biteCd = love.math.random() * 0.4
    e.dead = false
    e.lure, e.lureUid, e.lureRolled, e.escaped, e.rushed = nil, nil, nil, nil, nil   -- (pooled tables keep old fields)
    -- pacing (src/game/pacing.lua): straggler call, royal guard, heat / pressure scaling
    e.called, e.guardOf, e.guardUid, e.guardA, e.guards, e.guardMul = nil, nil, nil, nil, nil, nil
    e.pace, e.dpace = 1, 1
    if e.behavior.init then e.behavior.init(e, world, e.params) end
    return e
end

function Enemy.release(e)
    e.def, e.sprite, e.behavior, e.leader, e.elite, e.params = nil, nil, nil, nil, nil, nil
    e.uid = -1
    pool[#pool + 1] = e
end

return Enemy
