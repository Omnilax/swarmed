-- Adaptive music. One 8-bar loop in D minor, synthesised at startup as six stems that all play
-- at once in sync (pad, arp, bass, drums, lead, boss); the game only changes how loud each stem
-- is, so the music swells with the fight without ever skipping a beat.
--
-- Moods (Music.drive is called by the game every frame, the menus get "menu" by default):
--   menu   soft pad and music-box arp          break  between waves, calm
--   wave   bass and drums come in              swarm  lots of enemies: the lead melody joins
--   boss   a queen is out: toms and brass      dead   everything falls away, pitch sinks
-- Stems are rendered a little each frame (so start-up never stalls) and cached as .wav files in
-- the save folder, so later launches load them instantly. Bump CACHE when the score changes.
local Settings = require("src.core.settings")

local Music = { stems = {}, ready = false, mood = "menu", gains = {}, pitch = 1, duck = 1 }

local RATE = 22050
local BPM = 120
local STEP = 60 / BPM / 4                 -- one sixteenth note, seconds
local BARS = 8
local LEN = math.floor(BARS * 16 * STEP * RATE + 0.5)
local CACHE = "music/v1_"
local ORDER = { "pad", "arp", "bass", "drums", "lead", "boss" }

-- How loud each stem is in each mood (0..1, before the music volume setting).
local MIX = {
    menu  = { pad = 0.8, arp = 0.55, bass = 0.35 },
    brk   = { pad = 0.85, arp = 0.7 },
    wave  = { pad = 0.5, arp = 0.45, bass = 0.9, drums = 0.85 },
    swarm = { pad = 0.4, arp = 0.3, bass = 1, drums = 1, lead = 0.5 },
    boss  = { pad = 0.35, bass = 1, drums = 0.9, boss = 1 },
    final = { pad = 0.3, bass = 1, drums = 1, lead = 0.4, boss = 1 },
    dead  = { pad = 0.5 },
}
MIX["break"] = MIX.brk

-- ---------------------------------------------------------------- score

-- chord per bar: root (MIDI, around D3) and whether it is minor
local CHORDS = {
    { 50, true }, { 46, false }, { 53, false }, { 48, false },
    { 50, true }, { 46, false }, { 55, true }, { 45, false },
}

-- lead melody: { bar, step, length (sixteenths), MIDI note }
local MELODY = {
    { 1, 0, 4, 81 }, { 1, 4, 2, 77 }, { 1, 6, 2, 74 }, { 1, 8, 6, 81 }, { 1, 14, 2, 79 },
    { 2, 0, 4, 77 }, { 2, 4, 2, 74 }, { 2, 6, 2, 70 }, { 2, 8, 6, 77 }, { 2, 14, 2, 76 },
    { 3, 0, 4, 84 }, { 3, 4, 2, 81 }, { 3, 6, 2, 77 }, { 3, 8, 4, 84 }, { 3, 12, 4, 81 },
    { 4, 0, 6, 79 }, { 4, 6, 2, 76 }, { 4, 8, 4, 72 }, { 4, 12, 2, 76 }, { 4, 14, 2, 79 },
    { 5, 0, 4, 81 }, { 5, 4, 4, 86 }, { 5, 8, 2, 84 }, { 5, 10, 2, 81 }, { 5, 12, 4, 77 },
    { 6, 0, 4, 77 }, { 6, 4, 4, 82 }, { 6, 8, 2, 81 }, { 6, 10, 2, 77 }, { 6, 12, 4, 74 },
    { 7, 0, 4, 79 }, { 7, 4, 2, 82 }, { 7, 6, 2, 86 }, { 7, 8, 4, 84 }, { 7, 12, 4, 82 },
    { 8, 0, 8, 81 }, { 8, 8, 4, 73 }, { 8, 12, 4, 76 },
}

local function freq(m) return 440 * 2 ^ ((m - 69) / 12) end
local function tones(bar)
    local c = CHORDS[bar]
    return c[1], c[1] + (c[2] and 3 or 4), c[1] + 7
end
local function at(bar, step) return math.floor(((bar - 1) * 16 + step) * STEP * RATE) end

local TAU = math.pi * 2
local sin, exp, random = math.sin, math.exp, math.random

-- Adds one note into buf. Every voice is a few sines, so it stays soft and round (and cheap).
local function note(buf, start, dur, f, vol, kind)
    local attack, decay, release, tail = 0.005, 0, 0.05, 0.05
    if kind == "pluck" then attack, decay, tail = 0.003, 9, 0.25
    elseif kind == "bass" then attack, decay, release = 0.004, 3.5, 0.03
    elseif kind == "pad" then attack, release, tail = 0.35, 0.45, 0.45
    elseif kind == "lead" then attack, decay, release = 0.02, 0.6, 0.08
    elseif kind == "brass" then attack, decay, release, tail = 0.25, 0.15, 0.3, 0.3 end
    local n = math.floor((dur + tail) * RATE)
    local hold = dur * RATE
    local rel = release * RATE
    local w = f * TAU / RATE
    local ph, ph2 = 0, random() * TAU
    for i = 0, n - 1 do
        local t = i / RATE
        local env = t < attack and t / attack or 1
        if decay > 0 then env = env * exp(-(t - math.min(t, attack)) * decay) end
        if i > hold then
            local r = 1 - (i - hold) / rel
            if r <= 0 then break end
            env = env * r
        end
        local v
        if kind == "pluck" then
            ph = ph + w
            v = sin(ph) + 0.25 * sin(ph * 3) + 0.1 * sin(ph * 2)
        elseif kind == "bass" then
            ph = ph + w
            v = sin(ph) + 0.5 * sin(ph * 2) + 0.25 * sin(ph * 3) + 0.12 * sin(ph * 4)
        elseif kind == "pad" then
            ph = ph + w
            ph2 = ph2 + w * 1.004
            v = (sin(ph) + sin(ph2) + 0.2 * sin(ph * 2)) * (0.85 + 0.15 * sin(t * 3))
        elseif kind == "lead" then
            ph = ph + w * (1 + (t > 0.15 and 0.006 * sin(t * 34) or 0))
            v = sin(ph) + 0.3 * sin(ph * 3) + 0.12 * sin(ph * 5)
        else -- brass
            ph = ph + w * (1 + 0.004 * sin(t * 30))
            v = sin(ph) + 0.6 * sin(ph * 2) + 0.4 * sin(ph * 3) + 0.25 * sin(ph * 4) + 0.12 * sin(ph * 5)
        end
        local j = start + i
        if j >= LEN then j = j - LEN end      -- tails wrap round to the loop start
        buf[j] = buf[j] + v * env * vol
        if i % 8192 == 8191 then coroutine.yield() end   -- keep each frame's slice short
    end
end

local function drum(buf, start, kind, vol)
    local n = math.floor((kind == "kick" and 0.3 or kind == "tom" and 0.4 or kind == "snare" and 0.2 or 0.05) * RATE)
    local ph, lp = 0, 0
    for i = 0, n - 1 do
        local t = i / RATE
        local v
        if kind == "kick" then
            ph = ph + (45 + 110 * exp(-t * 30)) * TAU / RATE
            v = sin(ph) * exp(-t * 11)
        elseif kind == "tom" then
            ph = ph + (70 + 50 * exp(-t * 14)) * TAU / RATE
            v = (sin(ph) + 0.3 * (random() * 2 - 1) * exp(-t * 40)) * exp(-t * 7)
        elseif kind == "snare" then
            ph = ph + 185 * TAU / RATE
            local nz = random() * 2 - 1
            lp = lp + (nz - lp) * 0.5
            v = (sin(ph) * 0.5 * exp(-t * 30) + lp * 0.8) * exp(-t * 18)
        else -- hat: noise minus its low part
            local nz = random() * 2 - 1
            lp = lp + (nz - lp) * 0.3
            v = (nz - lp) * exp(-t * 90)
        end
        local j = (start + i) % LEN
        buf[j] = buf[j] + v * vol
    end
end

local SCORE = {
    pad = function(buf)
        for bar = 1, BARS do
            local r, th, fi = tones(bar)
            for _, m in ipairs({ r + 12, th + 12, fi + 12, r }) do
                note(buf, at(bar, 0), 16 * STEP, freq(m), m == r and 0.5 or 0.3, "pad")
            end
        end
    end,
    arp = function(buf)
        local pattern = { 1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3, 4, 5, 4, 3, 2 }
        for bar = 1, BARS do
            local r, th, fi = tones(bar)
            local set = { r + 24, th + 24, fi + 24, r + 36, th + 36 }
            for s = 0, 15 do
                local k = pattern[s + 1]
                if bar % 2 == 0 and s >= 8 then k = 6 - pattern[s - 7] end   -- every other bar it falls
                note(buf, at(bar, s), STEP * 0.9, freq(set[k]), s % 4 == 0 and 0.32 or 0.22, "pluck")
            end
        end
    end,
    bass = function(buf)
        local offs = { 0, 0, 12, 0, 7, 0, 12, 7 }
        for bar = 1, BARS do
            local r = CHORDS[bar][1] - 12
            for e = 0, 7 do
                note(buf, at(bar, e * 2), STEP * 1.6, freq(r + offs[e + 1]), e % 2 == 0 and 0.55 or 0.42, "bass")
            end
        end
    end,
    drums = function(buf)
        for bar = 1, BARS do
            drum(buf, at(bar, 0), "kick", 0.9)
            drum(buf, at(bar, 8), "kick", 0.9)
            drum(buf, at(bar, 10), "kick", 0.5)
            drum(buf, at(bar, 4), "snare", 0.6)
            if bar == BARS then
                for s = 12, 15 do drum(buf, at(bar, s), "snare", 0.35 + (s - 12) * 0.1) end
            else
                drum(buf, at(bar, 12), "snare", 0.6)
            end
            for s = 0, 15 do
                if s % 2 == 0 then drum(buf, at(bar, s), "hat", s % 4 == 2 and 0.3 or 0.18)
                elseif bar > 4 then drum(buf, at(bar, s), "hat", 0.1) end
            end
        end
    end,
    lead = function(buf)
        for _, n in ipairs(MELODY) do
            note(buf, at(n[1], n[2]), n[3] * STEP * 0.92, freq(n[4]), 0.4, "lead")
        end
    end,
    boss = function(buf)
        for bar = 1, BARS do
            local r = CHORDS[1][1] - 12          -- the queen stays on D: a pedal under the chords
            local top = bar % 4 == 0 and r + 8 or r + 7
            note(buf, at(bar, 0), 15 * STEP, freq(r), 0.35, "brass")
            note(buf, at(bar, 0), 15 * STEP, freq(top), 0.25, "brass")
            for _, s in ipairs({ 0, 3, 6, 8, 11, 14 }) do drum(buf, at(bar, s), "tom", s == 0 and 0.8 or 0.5) end
        end
    end,
}

-- ---------------------------------------------------------------- rendering and caching

local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
local function u32(n) return u16(n % 65536) .. u16(math.floor(n / 65536)) end

local function wavHeader(bytes)
    return "RIFF" .. u32(36 + bytes) .. "WAVEfmt " .. u32(16) .. u16(1) .. u16(1) .. u32(RATE)
        .. u32(RATE * 2) .. u16(2) .. u16(16) .. "data" .. u32(bytes)
end

local function render(name)
    local buf = {}
    for i = 0, LEN - 1 do buf[i] = 0 end
    coroutine.yield()
    SCORE[name](buf)
    coroutine.yield()
    local peak = 0.001
    for i = 0, LEN - 1 do
        local a = buf[i] < 0 and -buf[i] or buf[i]
        if a > peak then peak = a end
    end
    coroutine.yield()
    local k = 0.9 / peak
    local sd = love.sound.newSoundData(LEN, RATE, 16, 1)
    for i = 0, LEN - 1 do
        sd:setSample(i, buf[i] * k)
        if i % 50000 == 0 then coroutine.yield() end
    end
    return sd
end

local function load(name)
    local path = CACHE .. name .. ".wav"
    if love.filesystem.getInfo(path) then
        local ok, sd = pcall(love.sound.newSoundData, path)
        if ok and sd:getSampleCount() == LEN then return sd end
    end
    local sd = render(name)
    pcall(function()
        love.filesystem.createDirectory("music")
        local raw = sd:getString()
        love.filesystem.write(path, wavHeader(#raw) .. raw)
    end)
    return sd
end

function Music.init(opts)
    Music.job = coroutine.create(function()
        local data = {}
        for _, name in ipairs(ORDER) do
            data[name] = load(name)
            coroutine.yield()
        end
        Music.data = data
        for _, name in ipairs(ORDER) do
            local src = love.audio.newSource(data[name], "static")
            src:setLooping(true)
            src:setVolume(0)
            Music.stems[name] = src
            Music.gains[name] = 0
        end
        Music.ready = true
    end)
    if opts and opts.now then Music.finish() end
end

-- Render everything right now (tests).
function Music.finish()
    while Music.job and coroutine.status(Music.job) ~= "dead" do
        local ok, err = coroutine.resume(Music.job)
        if not ok then error(err) end
    end
end

-- Called by the game every frame while a run is on screen.
-- mood: "break" | "wave" | "swarm" | "boss" | "final" | "dead"; duck: 0..1 (menus on top).
function Music.drive(mood, duck)
    Music.mood, Music.duck, Music.driven = mood, duck or 1, true
end

function Music.update(dt)
    local job = Music.job
    if job and coroutine.status(job) ~= "dead" then
        local t0 = love.timer.getTime()
        repeat
            local ok, err = coroutine.resume(job)
            if not ok then
                print("music: " .. tostring(err))
                Music.job = nil
                break
            end
        until coroutine.status(job) == "dead" or love.timer.getTime() - t0 > 0.005
        if not Music.ready then return end
    end
    if not Music.ready then return end
    if not Music.playing then
        local list = {}
        for _, name in ipairs(ORDER) do list[#list + 1] = Music.stems[name] end
        -- all in the same frame, so the stems stay locked together. Not love.audio.play(list):
        -- love.js (the web build) crashes in alSourcePlayv when given several sources.
        for _, src in ipairs(list) do src:play() end
        Music.playing = true
    end
    -- nothing drove it this frame: we are in the menus
    local mood, duck = Music.mood, Music.duck
    if not Music.driven then mood, duck = "menu", 1 end
    Music.driven = false
    Music.current = mood

    local vol = Settings.get("masterVolume") / 100 * Settings.get("musicVolume") / 100 * 0.4
    if Music.focused == false and Settings.get("muteUnfocused") then vol = 0 end
    local mix = MIX[mood] or MIX.menu
    local fade = math.min(1, dt * (mood == "dead" and 0.8 or 1.6))
    for _, name in ipairs(ORDER) do
        local g = Music.gains[name]
        g = g + ((mix[name] or 0) * duck - g) * fade
        Music.gains[name] = g
        Music.stems[name]:setVolume(g * vol)
    end
    -- when the player falls, the tape slows down a little
    local want = mood == "dead" and 0.82 or 1
    Music.pitch = Music.pitch + (want - Music.pitch) * math.min(1, dt * 1.2)
    for _, name in ipairs(ORDER) do Music.stems[name]:setPitch(Music.pitch) end
end

function Music.setFocused(f) Music.focused = f end

-- seconds the loop lasts (tests)
Music.length = LEN / RATE

return Music
