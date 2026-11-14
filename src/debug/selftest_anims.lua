-- Attack animations: every character's attack, special and dash clip is found, samples to sane
-- numbers from start to end, and draws in a real fight (screenshot mid-swing).
--   love . --selftest --animtest   runs just this part
local State = require("src.core.state")
local Content = require("src.content")
local Anim = require("src.gfx.anim")

-- The original twelve all have hand-made clips for their attack and special.
local CORE = { "rhino_beetle", "wolf_spider", "bombardier_beetle", "tiger_beetle", "stag_beetle", "scorpion",
    "lobster", "centipede", "jumping_spider", "tarantula", "orb_weaver", "mantis" }

local function finite(v) return v == v and v > -1e6 and v < 1e6 end

return function(wait, shot)
    -- 1. clips exist and sample cleanly (no world needed)
    for _, id in ipairs(CORE) do
        local def = Content.characters:get(id)
        assert(Anim.find(def, "attack", def.attack.type), id .. ": no attack animation")
        assert(Anim.find(def, "secondary", def.secondary.type), id .. ": no special animation")
        assert(Anim.find(def, "dash", (def.dash or { type = "dash" }).type), id .. ": no dash animation")
    end
    local checked = 0
    for _, def in ipairs(Content.characters:all()) do
        for _, slot in ipairs({ "attack", "secondary", "dash" }) do
            local params = slot == "attack" and def.attack or slot == "secondary" and def.secondary or def.dash or { type = "dash" }
            local o = { world = { time = 0 }, def = def, attack = { combo = 0 }, delayed = {}, dashT = 0, blocking = false }
            for combo = 1, 3 do
                o.attack.combo = combo
                o._anims = nil
                o.world.time = 0
                if params then Anim.move(o, slot, params) end
                local st = o._anims and o._anims[slot]
                if st then
                    for k = 0, 10 do
                        o.world.time = st.dur * k / 10
                        local s = Anim.sample(o)
                        for _, ch in ipairs(Anim.CHANNELS) do
                            assert(finite(s[ch]), def.id .. " " .. slot .. ": channel " .. ch .. " is " .. tostring(s[ch]))
                        end
                        for _, l in ipairs(s.limbs) do assert(finite(l.k) and finite(l.k2), def.id .. " " .. slot .. ": bad limb blend") end
                    end
                    o.world.time = st.dur + 1
                    Anim.sample(o)
                    assert(not (o._anims and o._anims[slot]), def.id .. " " .. slot .. ": clip never ends")
                    checked = checked + 1
                end
            end
        end
    end
    print(("[selftest] anims: %d clips sampled"):format(checked))

    -- 2. in a real fight: fire each move and grab the frame mid-animation
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "sandbox", character = "scorpion" }))
    wait(0.5)
    local world = game.world
    world.flags.god = true
    for _, id in ipairs(CORE) do
        local cdef = Content.characters:get(id)
        world:clearEnemies()
        local pl = world.player
        pl:setCharacter(cdef)
        pl.x, pl.y = world.size * 0.45, world.size * 0.45
        pl.attack.timer = 1e9
        world:spawnRing("worker_ant", 16, pl.x + 40, pl.y, 24)
        world.flags.freezeAI = true
        wait(0.2)
        pl.aimX, pl.aimY = 1, 0
        pl.attack.type.fire(pl, world, 1, 0, pl.attack.params)
        Anim.move(pl, "attack", pl.attack.params)
        assert(Anim.active(pl), id .. ": attack animation didn't start")
        wait(0.08)
        shot("anim_" .. id)
        wait(0.6)
        local sec = pl.secondary
        sec.type.fire(pl, world, 1, 0, sec.params, pl.x + 70, pl.y + 10)
        Anim.move(pl, "secondary", sec.params)
        wait(0.9)
        if pl.carry and sec.type.update then sec.type.update(pl, world, 0.016, sec.params, false, pl.x + 70, pl.y) end
        wait(0.6)
        world.flags.freezeAI = false
    end
    print("[selftest] anims: ok")
end
