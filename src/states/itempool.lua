-- Item Pool (a Custom Waves set's Rules > Item Pool...): switch items in or out of that set's
-- item choices. Not reachable from Settings: the main game always offers every unlocked item.
-- Locked items (src/config/unlocks.lua) show their goal instead. The pool can't drop below
-- Unlocks.MIN_POOL items.
--   ItemPool.new(off, onChange)   off = the set's { [id] = true } list, edited in place
local State = require("src.core.state")
local Content = require("src.content")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Rarities = require("src.config.rarities")
local Unlocks = require("src.game.unlocks")
local util = require("src.core.util")

local ItemPool = {}
ItemPool.__index = ItemPool

function ItemPool.new(off, onChange)
    local self = setmetatable({ t = 0, flashT = 0, off = off or {}, onChange = onChange }, ItemPool)
    self.menu = Menu.new({
        onBack = function() self:close() end,
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = math.min(w - Theme.u(60), Theme.u(700))
            return math.floor((w - mw) / 2), Theme.u(130), mw, h - Theme.u(250)
        end,
    })
    self:build()
    return self
end

function ItemPool:build()
    local list = {}
    for _, d in ipairs(Content.items:all()) do if not d.molted then list[#list + 1] = d end end   -- molted items only come from molting
    table.sort(list, function(a, b)
        local ra, rb = Rarities[a.rarity].order, Rarities[b.rarity].order
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    local items = {}
    items[#items + 1] = { type = "button", label = "Switch all on", desc = "Put every unlocked item back in the pool.",
        onActivate = function()
            for k in pairs(self.off) do self.off[k] = nil end
            self:changed()
            Audio.play("ui_confirm")
        end }
    local rarity
    for _, d in ipairs(list) do
        if d.rarity ~= rarity then
            rarity = d.rarity
            items[#items + 1] = { type = "header", label = Rarities[rarity].label }
        end
        local id = d.id
        if Unlocks.item(id) then
            items[#items + 1] = { type = "toggle", label = d.name, desc = d.description, def = d,
                get = function() return Unlocks.inPool(id) end,
                set = function(v)
                    Unlocks.editing = self.off
                    if not Unlocks.setInPool(id, v) then
                        self.flashT = 1.5
                        Audio.play("ui_back")
                    end
                    self:changed()
                end }
        else
            local goal = Unlocks.itemGoal(id)
            items[#items + 1] = { type = "button", label = d.name, disabled = true, def = d, locked = true,
                desc = "Locked. " .. Unlocks.progressText(goal) .. "  (Settings > Gameplay > Unlock Everything opens every item.)", value = function() return "Locked" end }
        end
    end
    items[#items + 1] = { type = "button", label = "Back", onActivate = function() self:close() end }
    self.menu:setItems(items)
    self.menu:fixFocus(1)
end

function ItemPool:changed() if self.onChange then self.onChange(self.off) end end

function ItemPool:close()
    Unlocks.editing = nil
    State.pop()
end

-- (the list is live while the screen is up, so the counts and toggles show this set's pool)
function ItemPool:enter() Unlocks.editing = self.off end
function ItemPool:leave() Unlocks.editing = nil end

function ItemPool:update(dt)
    Unlocks.editing = self.off
    self.t = self.t + dt
    if self.flashT > 0 then self.flashT = self.flashT - dt end
    self.menu:update(dt)
end

function ItemPool:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local c = Theme.colors
    lg.setColor(c.bg[1], c.bg[2], c.bg[3], 0.97)
    lg.rectangle("fill", 0, 0, w, h)
    Theme.title("Item Pool", w)
    lg.setFont(Theme.font(17))
    local n, all = Unlocks.poolSize(), Content.items:count()
    local warn = self.flashT > 0
    lg.setColor(warn and c.bad or c.dim)
    local line = warn and ("The pool needs at least %d items."):format(Unlocks.MIN_POOL)
        or ("%d of %d items can show up in item choices."):format(n, all)
    lg.printf(line, 0, Theme.u(96), w, "center")
    self.menu:draw()
    local it = self.menu:focused()
    if it and it.desc then
        local col = it.def and util.hex(Rarities[it.def.rarity].color) or c.dim
        lg.setFont(Theme.font(17))
        lg.setColor(it.locked and c.dim or col)
        lg.printf(it.desc, Theme.u(40), h - Theme.u(100), w - Theme.u(80), "center")
    end
    Theme.footer(Input.lastDevice == "gamepad" and { { "A", "Switch" }, { "B", "Back" } }
        or { { "Enter", "Switch" }, { "Esc", "Back" } })
end

function ItemPool:mousemoved(x, y) self.menu:mousemoved(x, y) end
function ItemPool:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end
function ItemPool:wheelmoved(x, y) self.menu:wheelmoved(x, y) end

return ItemPool
