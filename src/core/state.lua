-- Stack-based state manager. States are objects with optional methods:
-- enter, leave, resume, update, draw, keypressed, mousepressed, mousereleased, mousemoved,
-- wheelmoved, textinput, resize, focus. A state with `transparent = true` draws the state below it.
local State = { stack = {}, fade = 0 }

-- Every full-screen change fades in from the background colour so screens never pop.
local FADE_TIME = 0.22

function State.top() return State.stack[#State.stack] end

function State.push(state)
    if not state.transparent then State.fade = 1 end
    State.stack[#State.stack + 1] = state
    if state.enter then state:enter() end
    return state
end

function State.pop()
    local s = table.remove(State.stack)
    if s and s.leave then s:leave() end
    local top = State.top()
    if top and top.resume then top:resume() end
    return s
end

function State.switch(state)
    while #State.stack > 0 do
        local s = table.remove(State.stack)
        if s.leave then s:leave() end
    end
    return State.push(state)
end

function State.call(name, ...)
    local top = State.top()
    if top and top[name] then return top[name](top, ...) end
end

function State.update(dt)
    State.fade = math.max(0, State.fade - dt / FADE_TIME)
    State.call("update", dt)
end

function State.draw()
    local first = #State.stack
    while first > 1 and State.stack[first].transparent do first = first - 1 end
    for i = first, #State.stack do
        local s = State.stack[i]
        if s.draw then s:draw() end
    end
    if State.fade > 0 then
        love.graphics.setColor(0.065, 0.055, 0.05, State.fade * State.fade)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Find the nearest state of a given class (used by debug tools to reach the running game).
function State.find(class)
    for i = #State.stack, 1, -1 do
        if getmetatable(State.stack[i]) == class then return State.stack[i] end
    end
end

return State
