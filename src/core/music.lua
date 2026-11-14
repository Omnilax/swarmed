-- Adaptive music. One 8-bar loop in D minor, synthesised at startup as six stems that all play
-- at once in sync (pad, arp, bass, drums, lead, boss); the game only changes how loud each stem
-- is, so the music swells with the fight without ever skipping a beat.
--
-- Moods (Music.drive is called by the game every frame, the menus get "menu" by default):
--   menu   soft pad and music-box arp          break  between waves, calm
--   wave   bass and drums come in              swarm  lots of enemies: the lead melody joins
--   boss   a queen is out: toms and brass      dead   everything falls away, pitch sinks
-- On top of the moods, the music follows the run (Music.drive's third argument, see below):
--   danger  low health: a throbbing drone and a ticking clock come in, the tune gets muffled
--           (a low-pass filter where the platform has one) and the tape wobbles
--   frenzy  a big kill combo: claps, shakers and a sparkle run pile on
--   night   the pad swells and the drums soften after dark
-- and the bug you play (Music.setCharacter): each body plan has its own signature stem (spiders
-- creep, beetles chug, crustaceans bubble, myriapods rattle, flyers whistle, other insects play a
-- kalimba), and the whole loop is played a few semitones lower and slower for big slow bugs,
-- higher and quicker for small fast ones. The final wave of a run lifts the key a semitone.
-- Stems are rendered a little each frame (so start-up never stalls) and cached as .wav files in
-- the save folder, so later launches load them instantly. A signature stem renders the first
-- time its bug is picked. Bump CACHE when the score changes.
local Settings = require("src.core.settings")

local Music = { stems = {}, ready = false, mood = "menu", gains = {}, pitch = 1, duck = 1, key = 0,
    extras = {}, filter = 1 }

local RATE = 22050
local BPM = 120
local STEP = 60 / BPM / 4                 -- one sixteenth note, seconds
local BARS = 8
local LEN = math.floor(BARS * 16 * STEP * RATE + 0.5)
local CACHE = "music/v1_"
local ORDER = { "pad", "arp", "bass", "drums", "lead", "boss", "danger", "frenzy" }
-- signature stems, one per body plan (rendered on demand)
local THEMES = { "creep", "chug", "bubble", "rattle", "flute", "kalimba" }

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
-- how loud the bug's signature stem is in each mood
local SIG = { menu = 0, brk = 0.55, wave = 0.6, swarm = 0.65, boss = 0.4, final = 0.55, dead = 0 }
SIG["break"] = SIG.brk
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
    elseif kind == "brass" then attack, decay, release, tail = 0.25, 0.15, 0.3, 0.3
    elseif kind == "marimba" then attack, decay, tail = 0.002, 11, 0.18
    elseif kind == "bubble" then attack, decay, tail = 0.002, 16, 0.12
    elseif kind == "chug" then attack, decay, release = 0.003, 7, 0.02
    elseif kind == "flute" then attack, release, tail = 0.07, 0.1, 0.1
    elseif kind == "drone" then attack, release, tail = 0.5, 0.5, 0.5 end
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
        elseif kind == "marimba" then
            ph = ph + w
            v = sin(ph) + 0.4 * sin(ph * 4) * exp(-t * 45) + 0.1 * sin(ph * 10) * exp(-t * 90)
        elseif kind == "bubble" then          -- a blip that glides upward
            ph = ph + w * (1 + t * 6)
            v = sin(ph) + 0.2 * sin(ph * 2)
        elseif kind == "chug" then            -- palm-muted power chord, softly clipped
            ph = ph + w
            local x = (sin(ph) + 0.8 * sin(ph * 1.5) + 0.6 * sin(ph * 2) + 0.3 * sin(ph * 3)) * 2.2
            v = x / (1 + (x < 0 and -x or x))
        elseif kind == "flute" then
            ph = ph + w * (1 + (t > 0.2 and 0.007 * sin(t * 31) or 0))
            v = sin(ph) + 0.18 * sin(ph * 2) + 0.07 * sin(ph * 3) + 0.06 * (random() * 2 - 1)
        elseif kind == "drone" then           -- throbs on the eighth notes (4 Hz at 120 bpm)
            ph = ph + w
            ph2 = ph2 + w * 2.006
            v = (sin(ph) + 0.45 * sin(ph2) + 0.2 * sin(ph * 3)) * (0.55 + 0.45 * sin(t * TAU * 4 - 1.57))
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
    local n = math.floor((kind == "kick" and 0.3 or kind == "tom" and 0.4 or kind == "snare" and 0.2
        or kind == "clap" and 0.18 or kind == "shaker" and 0.07 or kind == "tick" and 0.025 or 0.05) * RATE)
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
        elseif kind == "clap" then            -- three quick bursts, then a short tail
            local nz = random() * 2 - 1
            lp = lp + (nz - lp) * 0.6
            local tb = t < 0.024 and (t % 0.008) or (t - 0.016)
            v = (nz - lp) * exp(-tb * 120)
        elseif kind == "shaker" then
            local nz = random() * 2 - 1
            lp = lp + (nz - lp) * 0.2
            v = (nz - lp) * (t < 0.015 and t / 0.015 or exp(-(t - 0.015) * 60))
        elseif kind == "tick" then            -- a dry clock tick
            ph = ph + 2400 * TAU / RATE
            v = sin(ph) * exp(-t * 260)
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
    -- low health: a throbbing low D with a sour E-flat above, and a clock ticking the beats
    danger = function(buf)
        for bar = 1, BARS do
            note(buf, at(bar, 0), 16 * STEP, freq(38), 0.5, "drone")
            note(buf, at(bar, 0), 16 * STEP, freq(51), 0.22, "drone")
            for s = 0, 15, 4 do drum(buf, at(bar, s), "tick", s == 0 and 0.5 or 0.35) end
            for s = 2, 15, 4 do drum(buf, at(bar, s), "tick", 0.18) end
        end
    end,
    -- a big combo: claps on the backbeat, a running shaker and a sparkle run every other bar
    frenzy = function(buf)
        for bar = 1, BARS do
            drum(buf, at(bar, 4), "clap", 0.7)
            drum(buf, at(bar, 12), "clap", 0.7)
            if bar % 4 == 0 then drum(buf, at(bar, 14), "clap", 0.45); drum(buf, at(bar, 15), "clap", 0.55) end
            for s = 0, 15 do drum(buf, at(bar, s), "shaker", s % 2 == 1 and 0.4 or 0.22) end
            if bar % 2 == 0 then
                local r, th, fi = tones(bar)
                local run = { r + 36, th + 36, fi + 36, r + 48 }
                for k = 1, 4 do note(buf, at(bar, 11 + k), STEP * 0.8, freq(run[k]), 0.16 + k * 0.03, "pluck") end
            end
        end
    end,

    -- ---- signature stems, one per body plan
    -- spiders and other arachnids: a creeping, chromatically falling tremolo
    creep = function(buf)
        for bar = 1, BARS do
            local r, _, fi = tones(bar)
            for q = 0, 3 do
                local m = fi + 12 - q
                for k = 0, 3 do
                    note(buf, at(bar, q * 4 + k), STEP * 0.7, freq(m), k == 0 and 0.32 or 0.18, "pluck")
                end
            end
            if bar % 2 == 0 then note(buf, at(bar, 14), STEP * 2, freq(r + 1), 0.25, "marimba") end
        end
    end,
    -- beetles: heavy palm-muted power chords
    chug = function(buf)
        local hits = { 0, 1, 3, 6, 8, 9, 11, 14 }
        for bar = 1, BARS do
            local r = CHORDS[bar][1] - 12
            for i, s in ipairs(hits) do
                note(buf, at(bar, s), STEP * (i % 2 == 1 and 0.9 or 0.6), freq(r), i % 2 == 1 and 0.6 or 0.4, "chug")
            end
        end
    end,
    -- crustaceans: off-beat marimba and rising bubbles
    bubble = function(buf)
        for bar = 1, BARS do
            local r, th, fi = tones(bar)
            local set = { r + 24, fi + 12, th + 24, fi + 24 }
            for i, s in ipairs({ 2, 6, 10, 14 }) do note(buf, at(bar, s), STEP * 1.5, freq(set[i]), 0.4, "marimba") end
            note(buf, at(bar, 7), STEP, freq(fi + 24), 0.22, "marimba")
            for k = 0, (bar % 2 == 1 and 2 or 1) do
                note(buf, at(bar, 12 + k), STEP * 0.6, freq(r + 36 + k * 5), 0.18, "bubble")
            end
        end
    end,
    -- centipedes and millipedes: a scuttle of clicks over a low marimba ostinato
    rattle = function(buf)
        for bar = 1, BARS do
            local r, _, fi = tones(bar)
            for s = 0, 15 do drum(buf, at(bar, s), "tick", (s % 4 == 0 and 0.55) or (s % 2 == 0 and 0.35) or 0.22) end
            for _, s in ipairs({ 0, 3, 6, 10, 12 }) do
                note(buf, at(bar, s), STEP * 1.5, freq((s == 6 or s == 12) and fi or r), 0.45, "marimba")
            end
        end
    end,
    -- flyers: a high, airy flute line with trills
    flute = function(buf)
        for bar = 1, BARS do
            local r, th, fi = tones(bar)
            if bar % 4 == 0 then
                for s = 0, 7 do note(buf, at(bar, s), STEP * 0.95, freq((s % 2 == 0) and fi + 24 or fi + 26), 0.3, "flute") end
                note(buf, at(bar, 8), STEP * 7.5, freq(th + 24), 0.32, "flute")
            else
                note(buf, at(bar, 0), STEP * 5.5, freq(th + 24), 0.32, "flute")
                note(buf, at(bar, 6), STEP * 1.8, freq(fi + 24), 0.28, "flute")
                note(buf, at(bar, 8), STEP * 7.5, freq(r + 36), 0.3, "flute")
            end
        end
    end,
    -- every other insect: a bright kalimba counter-melody
    kalimba = function(buf)
        local pat = { { 0, 3 }, { 3, 2 }, { 6, 1 }, { 10, 2 }, { 12, 3 }, { 14, 4 } }
        for bar = 1, BARS do
            local r, th, fi = tones(bar)
            local set = { r + 24, th + 24, fi + 24, r + 36 }
            for i, p in ipairs(pat) do
                local k = p[2]
                if bar % 2 == 0 then k = 5 - k end
                note(buf, at(bar, p[1]), STEP * 1.8, freq(set[k]), i == 1 and 0.4 or 0.3, "marimba")
            end
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

-- Turns a stem's sound data into a looping source; joins in time with the others if they play.
local function addSource(name, sd)
    local src = love.audio.newSource(sd, "static")
    src:setLooping(true)
    src:setVolume(0)
    src:setPitch(Music.pitch)
    Music.stems[name] = src
    Music.gains[name] = Music.gains[name] or 0
    if Music.playing then
        local lead = Music.stems.pad
        if lead then pcall(src.seek, src, lead:tell("samples") % LEN, "samples") end
        src:play()
    end
end

-- Runs a render job a few milliseconds per frame; queued signature stems start when it ends.
local function startJob(fn)
    Music.job = coroutine.create(fn)
end

local function queueTheme(theme)
    if not theme or not Music.data or Music.stems[theme] or Music.loading == theme or not SCORE[theme] then return end
    if Music.job and coroutine.status(Music.job) ~= "dead" then
        Music.queued = theme                 -- the core stems first; this one right after
        return
    end
    Music.loading = theme
    startJob(function()
        local sd = load(theme)
        Music.data[theme] = sd
        addSource(theme, sd)
        Music.loading = nil
    end)
end

function Music.init(opts)
    Music.data = {}
    startJob(function()
        for _, name in ipairs(ORDER) do
            Music.data[name] = load(name)
            coroutine.yield()
        end
        for _, name in ipairs(ORDER) do addSource(name, Music.data[name]) end
        Music.ready = true
    end)
    if opts and opts.now then Music.finish() end
end

-- Render everything right now (tests).
function Music.finish()
    repeat
        while Music.job and coroutine.status(Music.job) ~= "dead" do
            local ok, err = coroutine.resume(Music.job)
            if not ok then error(err) end
        end
        local q = Music.queued
        Music.queued = nil
        if q then queueTheme(q) end
    until not (Music.job and coroutine.status(Music.job) ~= "dead")
end

-- ---------------------------------------------------------------- the bug you play

-- Which signature stem and key a character gets. A character file can choose with
-- `music = "chug"` or `music = { theme = "chug", key = -2 }`; otherwise it follows its tags,
-- and the key follows its size and speed (big and slow: lower and slower, small and fast: higher).
local TAG_THEME = {
    { "flying", "flute" }, { "spider", "creep" }, { "arachnid", "creep" }, { "beetle", "chug" },
    { "crustacean", "bubble" }, { "myriapod", "rattle" },
}
function Music.themeFor(def, radius, speed)
    if not def then return nil, 0 end
    local m = def.music
    local theme = type(m) == "string" and m or type(m) == "table" and m.theme or nil
    if not theme then
        local tags = {}
        for _, t in ipairs(def.tags or {}) do tags[t] = true end
        for _, tt in ipairs(TAG_THEME) do
            if tags[tt[1]] then theme = tt[2]; break end
        end
        theme = theme or "kalimba"
    end
    local key = type(m) == "table" and m.key
    if not key then
        local r = radius or def.radius or 8
        local v = speed or (def.stats and def.stats.moveSpeed) or 105
        key = math.floor(-(r - 8) * 0.7 + (v - 105) / 25 + 0.5)
        key = math.max(-3, math.min(3, key))
    end
    return theme, key
end

-- The bug on screen (a run, or the one highlighted in the character select). nil: none.
function Music.setCharacter(def, radius, speed)
    local theme, key = Music.themeFor(def, radius, speed)
    Music.theme, Music.key = theme, key or 0
    queueTheme(theme)
end

Music.THEMES = THEMES

-- Called by the game every frame while a run is on screen.
-- mood: "break" | "wave" | "swarm" | "boss" | "final" | "dead"; duck: 0..1 (menus on top).
-- extras (optional): danger 0..1 (low health), frenzy 0..1 (kill combo), night 0..1.
function Music.drive(mood, duck, extras)
    Music.mood, Music.duck, Music.driven = mood, duck or 1, true
    Music.extras = extras or {}
end

-- The character select previews a bug's signature stem over the menu music.
function Music.preview(def)
    Music.previewing = def
    if def then Music.setCharacter(def) end
end

local filterOK
local function canFilter()
    if filterOK == nil then
        filterOK = love.system.getOS() ~= "Web" and love.audio.isEffectsSupported
            and love.audio.isEffectsSupported() or false
    end
    return filterOK
end

-- muffles the tune at low health (desktop only; the web build skips it)
local function setFilter(amount)
    if not canFilter() then return end
    if amount >= 0.99 then amount = 1 end
    if amount == Music.filter or (amount < 1 and math.abs(amount - Music.filter) < 0.03) then return end
    Music.filter = amount
    for name, src in pairs(Music.stems) do
        if name ~= "danger" then
            local ok = pcall(function()
                if amount == 1 then src:setFilter() else src:setFilter({ type = "lowpass", volume = 1, highgain = amount }) end
            end)
            if not ok then filterOK = false; return end
        end
    end
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
                Music.loading = nil
                break
            end
        until coroutine.status(job) == "dead" or love.timer.getTime() - t0 > 0.005
    elseif Music.queued then
        local q = Music.queued
        Music.queued = nil
        queueTheme(q)
    end
    if not Music.ready then return end
    if not Music.playing then
        -- all in the same frame, so the stems stay locked together. Not love.audio.play(list):
        -- love.js (the web build) crashes in alSourcePlayv when given several sources.
        for _, name in ipairs(ORDER) do Music.stems[name]:play() end
        for _, name in ipairs(THEMES) do if Music.stems[name] then Music.stems[name]:play() end end
        Music.playing = true
    end
    -- nothing drove it this frame: we are in the menus
    local mood, duck, ex = Music.mood, Music.duck, Music.extras
    local inRun = Music.driven
    if not inRun then mood, duck, ex = "menu", 1, {} end
    Music.driven = false
    Music.current = mood
    local preview = not inRun and Music.previewing
    Music.previewing = nil                   -- the character select sets it again every frame
    if not inRun and not preview then Music.theme, Music.key = nil, 0 end

    local danger = mood == "dead" and 0 or (ex.danger or 0)
    local frenzy = ex.frenzy or 0
    local night = ex.night or 0
    Music.danger, Music.frenzy = danger, frenzy

    local vol = Settings.get("masterVolume") / 100 * Settings.get("musicVolume") / 100 * 0.4
    if Music.focused == false and Settings.get("muteUnfocused") then vol = 0 end
    local mix = MIX[mood] or MIX.menu
    local fade = math.min(1, dt * (mood == "dead" and 0.8 or 1.6))
    local function target(name)
        local g
        if name == "danger" then g = danger * 0.85
        elseif name == "frenzy" then g = frenzy * 0.75
        elseif name == Music.theme then
            g = preview and 0.6 or (SIG[mood] or 0)
            g = g * (1 - 0.4 * danger)
        else
            g = mix[name] or 0
            if name == "pad" then g = g * (1 + 0.3 * night) * (1 - 0.35 * danger)
            elseif name == "arp" or name == "lead" then g = g * (1 - 0.55 * danger)
            elseif name == "drums" then g = g * (1 - 0.25 * night) end
        end
        return math.min(1, g) * duck
    end
    for name, src in pairs(Music.stems) do
        local g = Music.gains[name] or 0
        g = g + (target(name) - g) * fade
        Music.gains[name] = g
        src:setVolume(g * vol)
    end
    setFilter(1 - 0.8 * Music.gains.danger / 0.85)

    -- the key: the bug's size, a lift for the final wave; the tape slows when the player falls
    -- and wobbles when they are nearly dead
    local semis = (Music.key or 0) + (mood == "final" and 1 or 0)
    local want = 2 ^ (semis / 12) * (mood == "dead" and 0.82 or 1)
    Music.pitch = Music.pitch + (want - Music.pitch) * math.min(1, dt * 1.2)
    Music.wobbleT = (Music.wobbleT or 0) + dt
    local p = Music.pitch * (1 + 0.01 * Music.gains.danger * math.sin(Music.wobbleT * 4.5))
    for _, src in pairs(Music.stems) do src:setPitch(p) end
end

function Music.setFocused(f) Music.focused = f end

-- seconds the loop lasts (tests)
Music.length = LEN / RATE

return Music
