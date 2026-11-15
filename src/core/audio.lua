-- Sound playback with volume buses and voice limits. Sounds are synthesised at startup as
-- placeholders; swap `data` for love.sound.newSoundData("assets/sfx/x.ogg") when real audio exists.
local Settings = require("src.core.settings")

local Audio = { sounds = {}, focused = true }
local RATE = 22050

local function synth(duration, fn)
    local n = math.floor(duration * RATE)
    local sd = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local v = fn(i / RATE, i / n)
        sd:setSample(i, math.max(-1, math.min(1, v)))
    end
    return sd
end

local function noise() return love.math.random() * 2 - 1 end

-- bus: which volume slider applies. voices: max overlapping copies. gap: min seconds between plays.
local defs = {
    hit = { bus = "sfx", voices = 6, gap = 0.035, volume = 0.35, pitchVar = 0.25,
        data = function() return synth(0.07, function(t, p) return noise() * (1 - p) ^ 3 end) end },
    kill = { bus = "sfx", voices = 8, gap = 0.03, volume = 0.4, pitchVar = 0.3,
        data = function()
            return synth(0.12, function(t, p)
                local f = 900 - 600 * p
                return math.sin(t * f * math.pi * 2) * (1 - p) ^ 2 * 0.8 + noise() * 0.15 * (1 - p)
            end)
        end },
    hurt = { bus = "sfx", voices = 2, gap = 0.1, volume = 0.6, pitchVar = 0.1,
        data = function()
            return synth(0.25, function(t, p)
                local sq = math.sin(t * (220 - 120 * p) * math.pi * 2) > 0 and 1 or -1
                return sq * 0.5 * (1 - p) ^ 1.5
            end)
        end },
    dash = { bus = "sfx", voices = 2, gap = 0.05, volume = 0.35, pitchVar = 0.1,
        data = function() return synth(0.16, function(t, p) return noise() * math.sin(p * math.pi) * 0.7 end) end },
    zap = { bus = "sfx", voices = 4, gap = 0.05, volume = 0.3, pitchVar = 0.2,
        data = function()
            return synth(0.12, function(t, p)
                local sq = math.sin(t * (1400 + noise() * 600) * math.pi * 2) > 0 and 1 or -1
                return sq * 0.4 * (1 - p)
            end)
        end },
    boom = { bus = "sfx", voices = 3, gap = 0.06, volume = 0.5, pitchVar = 0.2,
        data = function()
            local lp = 0
            return synth(0.35, function(t, p)
                lp = lp + (noise() - lp) * 0.15
                return lp * 2.5 * (1 - p) ^ 2
            end)
        end },
    -- ground heaving before ants burst out of it (src/game/entries.lua)
    rumble = { bus = "sfx", voices = 2, gap = 0.25, volume = 0.45, pitchVar = 0.2,
        data = function()
            local lp, lp2 = 0, 0
            return synth(0.6, function(t, p)
                lp = lp + (noise() - lp) * 0.04
                lp2 = lp2 + (lp - lp2) * 0.1
                local tremble = 0.6 + 0.4 * math.sin(t * 38 * math.pi * 2)
                return lp2 * 9 * math.sin(p * math.pi) * tremble
            end)
        end },
    pickup = { bus = "sfx", voices = 3, gap = 0.05, volume = 0.4,
        data = function()
            return synth(0.18, function(t, p)
                local f = p < 0.5 and 520 or 780
                return (math.sin(t * f * math.pi * 2) + math.sin(t * f * 2 * math.pi * 2) * 0.3) * (1 - p) ^ 1.5 * 0.5
            end)
        end },
    -- a nectar bead collected (src/game/nectar.lua plays it with a rising pitch along a chain)
    nectar = { bus = "sfx", voices = 4, gap = 0.035, volume = 0.28,
        data = function()
            return synth(0.11, function(t, p)
                local f = 1046
                return (math.sin(t * f * math.pi * 2) + math.sin(t * f * 3 * math.pi * 2) * 0.15) * math.exp(-p * 5) * 0.6
            end)
        end },
    equip = { bus = "ui", voices = 2, gap = 0.03, volume = 0.45,
        data = function()
            return synth(0.09, function(t, p) return (noise() * 0.5 + math.sin(t * 300 * math.pi * 2) * 0.6) * (1 - p) ^ 3 end)
        end },
    drop = { bus = "ui", voices = 2, gap = 0.03, volume = 0.4,
        data = function()
            return synth(0.12, function(t, p) return math.sin(t * (260 - 120 * p) * math.pi * 2) * (1 - p) ^ 2 * 0.7 end)
        end },
    -- every attack and special (Player.swingSound)
    swing = { bus = "sfx", voices = 4, gap = 0.06, volume = 0.22, pitchVar = 0.2,
        data = function()
            -- a short airy swish: noise swept through a resonant band
            local bp, lp = 0, 0
            return synth(0.12, function(t, p)
                local f = 0.08 + 0.25 * p
                lp = lp + (noise() - lp) * f
                bp = bp + (lp - bp) * f
                return (lp - bp) * 3 * math.sin(p * math.pi)
            end)
        end },
    special = { bus = "sfx", voices = 2, gap = 0.1, volume = 0.4, pitchVar = 0.1,
        data = function()
            -- a heavier whoosh with a low thump under it
            local lp = 0
            return synth(0.3, function(t, p)
                lp = lp + (noise() - lp) * (0.05 + 0.2 * p)
                local thump = math.sin(t * (90 - 40 * p) * math.pi * 2) * math.exp(-t * 18)
                return lp * 2.2 * math.sin(p * math.pi) + thump * 0.6
            end)
        end },
    -- run events (src/game/feedback.lua plays these from world events)
    wave_start = { bus = "sfx", voices = 1, gap = 0.5, volume = 0.55,
        data = function()
            -- two war-drum hits and a low horn
            local lp = 0
            return synth(1.1, function(t, p)
                local v = 0
                for _, h in ipairs({ 0, 0.18 }) do
                    local d = t - h
                    if d >= 0 then v = v + math.sin(d * (60 + 80 * math.exp(-d * 25)) * math.pi * 2) * math.exp(-d * 9) end
                end
                local ht = t - 0.3
                if ht > 0 then
                    local env = math.min(1, ht / 0.08) * math.max(0, 1 - ht / 0.8)
                    local ph = ht * 110 * math.pi * 2
                    lp = lp + ((math.sin(ph) + 0.5 * math.sin(ph * 2) + 0.3 * math.sin(ph * 3)) - lp) * 0.3
                    v = v + lp * env * 0.45
                end
                return v * 0.8
            end)
        end },
    wave_clear = { bus = "sfx", voices = 1, gap = 0.5, volume = 0.45,
        data = function()
            -- a rising three-note chime (D, F, A)
            return synth(0.9, function(t)
                local v = 0
                for i, f in ipairs({ 587, 698, 880 }) do
                    local d = t - (i - 1) * 0.1
                    if d >= 0 then v = v + (math.sin(d * f * math.pi * 2) + 0.3 * math.sin(d * f * 4 * math.pi * 2)) * math.exp(-d * 4) end
                end
                return v * 0.35
            end)
        end },
    chime = { bus = "sfx", voices = 2, gap = 0.08, volume = 0.3,
        data = function()
            -- a glassy plink (a dew drop): two bright partials, quick decay
            return synth(0.45, function(t)
                local v = math.sin(t * 1319 * math.pi * 2) + 0.5 * math.sin(t * 2637 * math.pi * 2)
                return v * math.exp(-t * 9) * 0.5
            end)
        end },
    bell = { bus = "sfx", voices = 2, gap = 0.2, volume = 0.5,
        data = function()
            -- a bell: inharmonic partials ringing out
            return synth(1.6, function(t)
                local v = 0
                for i, pr in ipairs({ { 1, 1 }, { 2.4, 0.6 }, { 3.0, 0.4 }, { 4.5, 0.25 }, { 5.9, 0.15 } }) do
                    v = v + math.sin(t * 392 * pr[1] * math.pi * 2) * pr[2] * math.exp(-t * (2 + i * 0.9))
                end
                return v * 0.4 * math.min(1, t / 0.004)
            end)
        end },
    queen = { bus = "sfx", voices = 1, gap = 1, volume = 0.6,
        data = function()
            -- a deep, rumbling chitter as a queen enters
            local lp = 0
            return synth(1.2, function(t, p)
                local env = math.min(1, t / 0.15) * (1 - p) ^ 1.5
                local f = 55 + 10 * math.sin(t * 7)
                local ph = t * f * math.pi * 2
                lp = lp + (noise() - lp) * 0.08
                local buzz = (math.sin(ph) + 0.6 * math.sin(ph * 2) + 0.4 * math.sin(ph * 3)) * (0.7 + 0.3 * math.sin(t * 90))
                return (buzz * 0.5 + lp * 1.5) * env
            end)
        end },
    victory = { bus = "sfx", voices = 1, gap = 1, volume = 0.55,
        data = function()
            -- fanfare: D F A then a held D major chord
            return synth(1.8, function(t)
                local v = 0
                local notes = { { 0, 587 }, { 0.14, 698 }, { 0.28, 880 } }
                for _, n in ipairs(notes) do
                    local d = t - n[1]
                    if d >= 0 and d < 0.14 then v = v + math.sin(d * n[2] * math.pi * 2) * 0.7 end
                end
                local d = t - 0.42
                if d >= 0 then
                    local env = math.min(1, d / 0.03) * math.exp(-d * 1.4)
                    for _, f in ipairs({ 587, 740, 880, 1175 }) do
                        local ph = d * f * math.pi * 2
                        v = v + (math.sin(ph) + 0.3 * math.sin(ph * 3)) * env * 0.35
                    end
                end
                return v * 0.6
            end)
        end },
    defeat = { bus = "sfx", voices = 1, gap = 1, volume = 0.5,
        data = function()
            -- three falling notes
            return synth(1.4, function(t)
                local v = 0
                for i, f in ipairs({ 440, 349, 294 }) do
                    local d = t - (i - 1) * 0.28
                    if d >= 0 then
                        local ph = d * f * math.pi * 2
                        v = v + (math.sin(ph) + 0.4 * math.sin(ph * 2)) * math.min(1, d / 0.02) * math.exp(-d * (i == 3 and 2 or 5))
                    end
                end
                return v * 0.45
            end)
        end },
    heartbeat = { bus = "sfx", voices = 1, gap = 0.3, volume = 0.5,
        data = function()
            -- lub-dub
            return synth(0.45, function(t)
                local v = 0
                for i, h in ipairs({ 0, 0.16 }) do
                    local d = t - h
                    if d >= 0 then v = v + math.sin(d * (50 + 30 * math.exp(-d * 30)) * math.pi * 2) * math.exp(-d * 18) * (i == 1 and 1 or 0.7) end
                end
                return v
            end)
        end },
    hint = { bus = "ui", voices = 1, gap = 0.3, volume = 0.3,
        data = function()
            return synth(0.25, function(t)
                local f = t < 0.08 and 988 or 1319
                return math.sin(t * f * math.pi * 2) * math.exp(-t * 10) * 0.6
            end)
        end },
    -- a level-up: a bright rising arpeggio (C E G C) with a shimmer on top
    level_up = { bus = "sfx", voices = 2, gap = 0.2, volume = 0.5,
        data = function()
            return synth(1.0, function(t)
                local v = 0
                for i, f in ipairs({ 523, 659, 784, 1047 }) do
                    local d = t - (i - 1) * 0.07
                    if d >= 0 then
                        v = v + (math.sin(d * f * math.pi * 2) + 0.35 * math.sin(d * f * 2 * math.pi * 2)) * math.exp(-d * (i == 4 and 3 or 6))
                    end
                end
                local sd = t - 0.2
                if sd > 0 then v = v + math.sin(sd * 2093 * math.pi * 2) * math.sin(sd * 31) * math.exp(-sd * 5) * 0.25 end
                return v * 0.3
            end)
        end },
    ui_move = { bus = "ui", voices = 3, gap = 0.02, volume = 0.3,
        data = function() return synth(0.04, function(t, p) return math.sin(t * 880 * math.pi * 2) * (1 - p) * 0.6 end) end },
    ui_confirm = { bus = "ui", voices = 2, gap = 0.03, volume = 0.35,
        data = function()
            return synth(0.12, function(t, p)
                local f = p < 0.4 and 660 or 990
                return math.sin(t * f * math.pi * 2) * (1 - p) * 0.6
            end)
        end },
    ui_back = { bus = "ui", voices = 2, gap = 0.03, volume = 0.35,
        data = function()
            return synth(0.1, function(t, p)
                local f = p < 0.4 and 660 or 440
                return math.sin(t * f * math.pi * 2) * (1 - p) * 0.6
            end)
        end },
}

function Audio.init()
    for name, def in pairs(defs) do
        local src = love.audio.newSource(def.data(), "static")
        local pool = { src }
        for i = 2, def.voices do pool[i] = src:clone() end
        Audio.sounds[name] = { def = def, pool = pool, next = 1, last = -1 }
    end
end

local function busVolume(bus)
    if not Audio.focused and Settings.get("muteUnfocused") then return 0 end
    local key = bus == "ui" and "uiVolume" or bus == "music" and "musicVolume" or "sfxVolume"
    return (Settings.get("masterVolume") / 100) * (Settings.get(key) / 100)
end

function Audio.play(name, opts)
    local s = Audio.sounds[name]
    if not s or Audio.muted then return end
    local now = love.timer.getTime()
    if now - s.last < s.def.gap then return end
    local vol = busVolume(s.def.bus) * (s.def.volume or 1) * (opts and opts.volume or 1)
    if vol <= 0 then return end
    s.last = now
    local src = s.pool[s.next]
    s.next = s.next % #s.pool + 1
    src:stop()
    src:setVolume(vol)
    local pv = s.def.pitchVar or 0
    src:setPitch((opts and opts.pitch or 1) * (1 + (love.math.random() - 0.5) * pv))
    src:play()
end

function Audio.setFocused(f) Audio.focused = f end

return Audio
