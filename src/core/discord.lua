-- Discord Rich Presence without any extra DLLs: talks to the Discord desktop app over its
-- local IPC pipe (Windows named pipe, or a Unix socket on Linux and macOS) through LuaJIT's FFI.
--
--   Discord.init(appId)        -- quietly does nothing without an app id, FFI or a desktop OS
--   Discord.setActivity(tbl)   -- tbl = { details, state, timestamps = { start }, assets = {...} }
--   Discord.update(dt)         -- call every frame: connects, retries, reads replies, sends
--   Discord.shutdown()         -- closing the pipe clears the status
--
-- Nothing here may ever break the game: every call into the OS is guarded, and any surprise
-- turns the whole module off for the session. The web build (PUC Lua 5.1, no FFI) and phones
-- never get past Discord.init. Protocol: each frame is a little-endian u32 opcode, a u32
-- length and a JSON body. Opcodes: 0 handshake, 1 frame, 2 close, 3 ping, 4 pong.
local Discord = { enabled = false, connected = false, ready = false, status = "off" }

local ffi, C, isWin, isMac
local conn             -- { write = fn(str) -> ok, read = fn() -> str|nil|false, close = fn() }
local appId, pid
local inbuf = ""
local wanted, sentJson -- the activity we want shown, and the JSON last sent
local lastSend, retryT, nonce = -100, 0, 0
local cfg = require("src.config.discord")

local function now() return love.timer.getTime() end

local function log(msg) print("[discord] " .. msg) end

-- Small JSON writer (strings, numbers, booleans, arrays and objects).
local function esc(s)
    return (s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
        elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t" end
        return string.format("\\u%04x", c:byte())
    end))
end
local function json(v)
    local t = type(v)
    if t == "string" then return '"' .. esc(v) .. '"' end
    if t == "number" then return (v == math.floor(v)) and string.format("%d", v) or tostring(v) end
    if t == "boolean" then return v and "true" or "false" end
    if t ~= "table" then return "null" end
    if #v > 0 then
        local out = {}
        for i = 1, #v do out[i] = json(v[i]) end
        return "[" .. table.concat(out, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)  -- stable order, so an unchanged activity gives the same text
    local out = {}
    for i, k in ipairs(keys) do out[i] = json(k) .. ":" .. json(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
Discord.json = json

local function u32(n)
    return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function readU32(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end
local function frame(op, body) return u32(op) .. u32(#body) .. body end
Discord.frame = frame

-- Platform pipes ------------------------------------------------------------------------------
local function openWindows()
    local GENERIC_RW, OPEN_EXISTING = 0xC0000000, 3
    for i = 0, 9 do
        local h = C.CreateFileA("\\\\.\\pipe\\discord-ipc-" .. i, GENERIC_RW, 0, nil, OPEN_EXISTING, 0, nil)
        if ffi.cast("intptr_t", h) ~= -1 then
            local n = ffi.new("uint32_t[1]")
            local avail = ffi.new("uint32_t[1]")
            local buf = ffi.new("uint8_t[?]", 8192)
            return {
                write = function(s)
                    return C.WriteFile(h, s, #s, n, nil) ~= 0 and n[0] == #s
                end,
                read = function()
                    if C.PeekNamedPipe(h, nil, 0, nil, avail, nil) == 0 then return false end
                    if avail[0] == 0 then return nil end
                    if C.ReadFile(h, buf, math.min(avail[0], 8192), n, nil) == 0 then return false end
                    return ffi.string(buf, n[0])
                end,
                close = function() C.CloseHandle(h) end,
            }
        end
    end
end

local function unixDirs()
    local dirs, seen = {}, {}
    for _, var in ipairs({ "XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP" }) do
        local d = os.getenv(var)
        if d and d ~= "" and not seen[d] then seen[d] = true; dirs[#dirs + 1] = d end
    end
    if not seen["/tmp"] then dirs[#dirs + 1] = "/tmp" end
    return dirs
end

local function openUnix()
    -- Linux sockaddr_un is { u16 family; char path[108] }, macOS { u8 len; u8 family; char path[104] }
    local addr = ffi.new(isMac and "struct swarmed_sun_mac" or "struct swarmed_sun_linux")
    local maxPath = isMac and 103 or 107
    local AF_UNIX, SOCK_STREAM = 1, 1
    local MSG_DONTWAIT = isMac and 0x80 or 0x40
    local MSG_NOSIGNAL = isMac and 0 or 0x4000
    local EAGAIN = isMac and 35 or 11
    local subdirs = { "", "app/com.discordapp.Discord/", "snap.discord/", ".flatpak/dev.vencord.Vesktop/xdg-run/" }
    for _, dir in ipairs(unixDirs()) do
        for _, sub in ipairs(subdirs) do
            for i = 0, 9 do
                local path = dir:gsub("/$", "") .. "/" .. sub .. "discord-ipc-" .. i
                if #path <= maxPath then
                    local fd = C.socket(AF_UNIX, SOCK_STREAM, 0)
                    if fd < 0 then return nil end
                    ffi.fill(addr, ffi.sizeof(addr))
                    if isMac then addr.len = ffi.sizeof(addr) end
                    addr.family = AF_UNIX
                    ffi.copy(addr.path, path)
                    if C.connect(fd, addr, ffi.sizeof(addr)) == 0 then
                        if isMac then -- no SIGPIPE when Discord closes on us
                            local one = ffi.new("int[1]", 1)
                            C.setsockopt(fd, 0xffff, 0x1022, one, 4)
                        end
                        local buf = ffi.new("uint8_t[?]", 8192)
                        return {
                            write = function(s)
                                return C.send(fd, s, #s, MSG_NOSIGNAL) == #s
                            end,
                            read = function()
                                local r = C.recv(fd, buf, 8192, MSG_DONTWAIT)
                                if r > 0 then return ffi.string(buf, r) end
                                if r == 0 then return false end
                                local e = ffi.errno()
                                if e == EAGAIN or e == 11 or e == 35 then return nil end
                                return false
                            end,
                            close = function() C.close(fd) end,
                        }
                    end
                    C.close(fd)
                end
            end
        end
    end
end

local function setupFFI()
    if pid then return true end  -- already set up (turned off and on again in the settings)
    local okF, f = pcall(require, "ffi")
    if not okF or not f then return false end
    ffi = f
    C = ffi.C
    local os_ = love.system.getOS()
    isWin, isMac = os_ == "Windows", os_ == "OS X"
    if os_ ~= "Windows" and os_ ~= "OS X" and os_ ~= "Linux" then return false end
    local ok = pcall(ffi.cdef, isWin and [[
        void* CreateFileA(const char*, uint32_t, uint32_t, void*, uint32_t, uint32_t, void*);
        int WriteFile(void*, const void*, uint32_t, uint32_t*, void*);
        int ReadFile(void*, void*, uint32_t, uint32_t*, void*);
        int PeekNamedPipe(void*, void*, uint32_t, uint32_t*, uint32_t*, uint32_t*);
        int CloseHandle(void*);
        uint32_t GetCurrentProcessId(void);
    ]] or [[
        struct swarmed_sun_linux { uint16_t family; char path[108]; };
        struct swarmed_sun_mac { uint8_t len; uint8_t family; char path[104]; };
        int socket(int, int, int);
        int connect(int, const void*, uint32_t);
        intptr_t send(int, const void*, size_t, int);
        intptr_t recv(int, void*, size_t, int);
        int close(int);
        int setsockopt(int, int, int, const void*, uint32_t);
        int getpid(void);
    ]])
    if not ok then return false end
    pid = isWin and tonumber(C.GetCurrentProcessId()) or tonumber(C.getpid())
    return true
end

-- Connection ----------------------------------------------------------------------------------
local function disconnect(why)
    if conn then pcall(conn.close) end
    conn, inbuf = nil, ""
    Discord.connected, Discord.ready = false, false
    sentJson = nil
    Discord.status = why or "waiting"
end

local function send(op, tbl)
    if not conn then return false end
    local ok, res = pcall(conn.write, frame(op, json(tbl)))
    if not ok or not res then disconnect("lost") return false end
    return true
end

local function tryConnect()
    local ok, c = pcall(isWin and openWindows or openUnix)
    if not ok then log("connect failed: " .. tostring(c)) end
    if not ok or not c then Discord.status = "no discord" return end
    conn = c
    Discord.connected, Discord.status = true, "handshake"
    send(0, { v = 1, client_id = appId })
end

local function handle(op, body)
    if op == 2 then
        log("Discord closed the connection: " .. body)
        disconnect("closed")
        retryT = 120  -- usually a wrong app id; don't hammer it
        return
    end
    if op == 1 then
        if body:find('"evt"%s*:%s*"READY"') then
            Discord.ready, Discord.status = true, "ready"
        elseif body:find('"evt"%s*:%s*"ERROR"') then
            log("error: " .. body)
        end
    end
end

local function pump()
    for _ = 1, 8 do
        local ok, chunk = pcall(conn.read)
        if not ok or chunk == false then disconnect("lost") return end
        if not chunk then break end
        inbuf = inbuf .. chunk
    end
    while #inbuf >= 8 do
        local op, len = readU32(inbuf, 1), readU32(inbuf, 5)
        if #inbuf < 8 + len then break end
        local body = inbuf:sub(9, 8 + len)
        inbuf = inbuf:sub(9 + len)
        if op == 3 then  -- ping: pong the same body back
            if conn then pcall(conn.write, frame(4, body)) end
        else
            handle(op, body)
        end
        if not conn then return end
    end
end

-- Public --------------------------------------------------------------------------------------
function Discord.init(id)
    appId = id or cfg.appId
    if Discord.enabled then return true end
    if not appId or appId == "" then Discord.status = "no app id" return false end
    local ok, res = pcall(setupFFI)
    if not ok or not res then
        Discord.status = "unsupported"
        if not ok then log("off: " .. tostring(res)) end
        return false
    end
    Discord.enabled, retryT = true, 0
    return true
end

-- tbl = nil clears the status (shown as just "Playing Swarmed" with no details).
function Discord.setActivity(tbl) wanted = tbl end

function Discord.update(dt)
    if not Discord.enabled then return end
    local ok, err = pcall(function()
        if not conn then
            retryT = retryT - dt
            if retryT > 0 then return end
            retryT = cfg.retryInterval or 20
            tryConnect()
            return
        end
        pump()
        if not conn or not Discord.ready then return end
        local body = json(wanted or false)
        if body ~= sentJson and now() - lastSend >= (cfg.minInterval or 4) then
            nonce = nonce + 1
            local args = { pid = pid }
            if wanted then args.activity = wanted end
            if send(1, { cmd = "SET_ACTIVITY", args = args, nonce = tostring(nonce) }) then
                sentJson, lastSend = body, now()
            end
        end
    end)
    if not ok then
        log("turned off after an error: " .. tostring(err))
        Discord.shutdown()
        Discord.enabled, Discord.status = false, "error"
    end
end

function Discord.shutdown()
    if conn then disconnect("off") end
    Discord.status = Discord.enabled and "off" or Discord.status
end

return Discord
