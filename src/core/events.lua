-- Minimal event bus. Each run owns one, so listeners vanish with the run.
-- Used for hooks like "enemy_killed", "player_hurt", "wave_started" that items, events,
-- achievements and UI can listen to without the emitter knowing about them.
local Events = {}
Events.__index = Events

function Events.new() return setmetatable({ handlers = {} }, Events) end

function Events:on(name, fn)
    local list = self.handlers[name] or {}
    self.handlers[name] = list
    list[#list + 1] = fn
    return fn
end

function Events:off(name, fn)
    local list = self.handlers[name]
    if not list then return end
    for i = #list, 1, -1 do if list[i] == fn then table.remove(list, i) end end
end

function Events:emit(name, ...)
    local list = self.handlers[name]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

return Events
