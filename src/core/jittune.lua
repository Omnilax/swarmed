-- LuaJIT tuning for a big game.
-- LuaJIT's default limits are sized for small scripts: at most 1000 compiled traces and 512 KB
-- of machine code. Swarmed has hundreds of behaviours, items and draw paths, so in a real fight
-- it hits those limits within seconds, throws every compiled trace away ("trace flush") and
-- starts compiling again, over and over. Each flush drops the hot loops back to the
-- interpreter and the half-compiled traces leave lots of garbage behind. With roomier limits
-- the hot code is compiled once and stays compiled.
-- Nothing here changes what the game does, only how fast LuaJIT runs it. The web build runs
-- plain Lua (no `jit`), so this does nothing there.
local JitTune = { applied = false }

JitTune.options = {
    "maxtrace=60000",    -- traces kept before a flush (default 1000; 65535 is the most)
    "maxrecord=16000",   -- IR instructions per trace (default 4000)
    "maxirconst=1000",   -- constants per trace (default 500)
    "maxside=200",       -- side traces per root trace (default 100)
    "maxsnap=1000",      -- snapshots per trace (default 500)
    "sizemcode=256",     -- machine code area size in KB (default 32 on x64)
    "maxmcode=32768",    -- total machine code in KB before a flush (default 512)
}

function JitTune.apply()
    if JitTune.applied or not (jit and jit.opt and jit.status and jit.status()) then return false end
    local ok = pcall(jit.opt.start, unpack(JitTune.options))
    JitTune.applied = ok
    return ok
end

return JitTune
