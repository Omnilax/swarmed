-- Skill tree screen: the SKILLS tab of the bag (Tab / RB / the tab at the top switches). Shows
-- the bug's tree (content/skilltrees) as three branches; spend skill points earned from XP.
-- The game is paused while it is open.
--
-- Mouse/touch: click a node to learn it.  Keys/pad: arrows move, Enter / A learns, Tab / RB goes
-- back to the bag, I / B closes.
local State = require("src.core.state")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local Skills = require("src.game.skills")

local Tree = { transparent = true, touchControls = "inventory", noTouchScroll = true }
Tree.__index = Tree

local lg = love.graphics

function Tree.new(game)
    local self = setmetatable({ game = game, world = game.world, t = 0, pops = {} }, Tree)
    self.skills = game.world.player.skills
    self.tree = self.skills.tree
    -- cursor starts on the first thing you can learn (else the first node)
    self.cursor = nil
    if self.tree then
        for _, br in ipairs(self.tree.branches) do
            for _, n in ipairs(br.nodes) do
                if not self.cursor and self.skills:status(n) == "available" then self.cursor = n end
            end
        end
        self.cursor = self.cursor or self.tree.branches[1].nodes[1]
    end
    return self
end

function Tree:enter() love.mouse.setVisible(true) end

-- The bag and this screen are two tabs of one window: swap without unpausing.
function Tree.openFrom(inv)
    if inv.held then Audio.play("ui_back") return end
    State.pop()
    State.push(Tree.new(inv.game))
    Audio.play("ui_move")
end

function Tree:toBag()
    State.pop()
    State.push(require("src.states.inventory").new(self.game))
    Audio.play("ui_move")
end

----------------------------------------------------------------------------------------------
-- Layout

function Tree:layout()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local pw = math.min(w - u(40), u(1000))
    local ph = math.min(h - u(70), u(600))
    local px, py = math.floor((w - pw) / 2), math.floor((h - ph) / 2 - u(10))
    local pad = math.floor(u(16))
    local headH = math.floor(u(64))
    local infoH = math.floor(u(78))
    local area = { x = px + pad, y = py + headH, w = pw - pad * 2, h = ph - headH - infoH - pad }
    local L = { panel = { x = px, y = py, w = pw, h = ph }, pad = pad, area = area,
        info = { x = px + pad, y = py + ph - infoH - pad * 0.5, w = pw - pad * 2, h = infoH }, nodes = {} }
    if not self.tree then self.L = L return L end
    local branches = self.tree.branches
    local colW = area.w / #branches
    local maxTier = 1
    for _, n in pairs(self.tree.nodes) do maxTier = math.max(maxTier, n.tier) end
    local titleH = math.floor(u(26))
    local rowH = (area.h - titleH) / maxTier
    local nodeH = math.floor(math.min(rowH * 0.72, u(58)))
    local nodeW = math.floor(math.min(colW * 0.42, u(150)))
    for bi, br in ipairs(branches) do
        local cx = area.x + colW * (bi - 0.5)
        L["branch" .. bi] = { x = area.x + colW * (bi - 1), w = colW, cx = cx }
        for _, n in ipairs(br.nodes) do
            local x = cx + n.col * colW * 0.25 - nodeW / 2
            local y = area.y + titleH + (n.tier - 1) * rowH + (rowH - nodeH) / 2
            L.nodes[n.id] = { x = math.floor(x), y = math.floor(y), w = nodeW, h = nodeH }
        end
    end
    L.titleH = titleH
    -- the tabs in the header
    local f = Theme.font(18, "bold")
    L.tabs = {
        { id = "bag", x = px + pad, y = py + math.floor(u(10)), w = f:getWidth("BAG") + u(20), h = f:getHeight() + u(6) },
    }
    local t1 = L.tabs[1]
    L.tabs[2] = { id = "skills", x = t1.x + t1.w + u(6), y = t1.y, w = f:getWidth("SKILLS") + u(20), h = t1.h }
    self.L = L
    return L
end

local function inside(r, x, y) return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

function Tree:nodeAt(mx, my)
    if not self.tree then return nil end
    for id, r in pairs(self.L.nodes) do
        if inside(r, mx, my) then return self.tree.nodes[id] end
    end
end

----------------------------------------------------------------------------------------------
-- Actions

function Tree:learn(node)
    if not node then return end
    local st = self.skills:status(node)
    if st ~= "available" then
        Audio.play("ui_back")
        return
    end
    self.skills:buy(node.id)
    Audio.play("equip", { pitch = 1.2 })
    Audio.play("ui_confirm", { pitch = 1.4 })
    local r = self.L and self.L.nodes[node.id]
    if r then self.pops[#self.pops + 1] = { x = r.x + r.w / 2, y = r.y, t = 0, text = node.ranks > 1 and ("RANK " .. self.skills:rank(node.id)) or "LEARNED" } end
end

-- Arrow keys: up/down walk the tiers of a branch, left/right hop to the nearest node beside.
function Tree:moveCursor(dx, dy)
    local cur = self.cursor
    if not cur or not self.L then return end
    local a = self.L.nodes[cur.id]
    local ax, ay = a.x + a.w / 2, a.y + a.h / 2
    local best, bd
    for id, r in pairs(self.L.nodes) do
        local bx, by = r.x + r.w / 2 - ax, r.y + r.h / 2 - ay
        local along = bx * dx + by * dy
        if id ~= cur.id and along > 1 then
            local across = math.abs(bx * dy - by * dx)
            local d = along + across * 2.5
            if not bd or d < bd then best, bd = id, d end
        end
    end
    if best then
        self.cursor = self.tree.nodes[best]
        Audio.play("ui_move")
    end
end

----------------------------------------------------------------------------------------------
-- Input

function Tree:update(dt)
    self.t = self.t + dt
    if Input.pressed("inventory") or Input.pressed("ui_back") or Input.pressed("pause") then
        Input.consume("pause")
        State.pop()
        return
    end
    if Input.pressed("ui_tab_next") or Input.pressed("ui_tab_prev") then self:toBag() return end
    if Input.pressed("ui_left") then self:moveCursor(-1, 0) end
    if Input.pressed("ui_right") then self:moveCursor(1, 0) end
    if Input.pressed("ui_up") then self:moveCursor(0, -1) end
    if Input.pressed("ui_down") then self:moveCursor(0, 1) end
    if Input.pressed("ui_confirm") then self:learn(self.cursor) end
    for i = #self.pops, 1, -1 do
        local p = self.pops[i]
        p.t = p.t + dt
        if p.t > 1 then table.remove(self.pops, i) end
    end
end

function Tree:mousepressed(x, y, b)
    self:layout()
    for _, tab in ipairs(self.L.tabs) do
        if inside(tab, x, y) then
            if tab.id == "bag" then self:toBag() end
            return
        end
    end
    local n = self:nodeAt(x, y)
    if n then
        self.cursor = n
        if b == 1 then self:learn(n) end
    end
end

function Tree:mousemoved() self.mouseActive = true end

----------------------------------------------------------------------------------------------
-- Drawing

local STATUS_TEXT = {
    available = "Click to learn", poor = "Not enough skill points", locked = "Learn a node above it first",
    excluded = "Locked: you took the other side of this fork", maxed = "Learned",
}

-- The BAG / SKILLS tabs (shared with the bag screen).
function Tree.drawTabs(tabs, active, points)
    local Inv = require("src.states.inventory")
    local COL = Inv.COL
    local u = Theme.u
    lg.setFont(Theme.font(18, "bold"))
    for _, tab in ipairs(tabs) do
        local on = tab.id == active
        lg.setColor(on and COL.frameHi or COL.frameLo)
        lg.rectangle("fill", tab.x, tab.y, tab.w, tab.h)
        lg.setColor(on and COL.inner or COL.frame)
        lg.rectangle("fill", tab.x + 2, tab.y + 2, tab.w - 4, tab.h - 2)
        Theme.printShadow(tab.id == "bag" and "BAG" or "SKILLS", tab.x, tab.y + u(3), on and COL.label or COL.dim, "center", tab.w)
        if tab.id == "skills" and points and points > 0 then
            local r = u(8)
            local bx, by = tab.x + tab.w - u(2), tab.y + u(2)
            lg.setColor(0.35, 0.8, 1, 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
            lg.circle("fill", bx, by, r)
            lg.setFont(Theme.font(12, "bold"))
            lg.setColor(0.05, 0.1, 0.15)
            lg.printf(tostring(points), bx - r, by - u(7), r * 2, "center")
            lg.setFont(Theme.font(18, "bold"))
        end
    end
end

function Tree:draw()
    local w, h = lg.getDimensions()
    local u = Theme.u
    local Inv = require("src.states.inventory")
    local COL, plate = Inv.COL, Inv.plate
    local L = self:layout()
    local sk = self.skills
    local mx, my = love.mouse.getPosition()
    local useMouse = Input.lastDevice == "mouse" or Input.lastDevice == "touch" or Input.lastDevice == "keyboard" and self.mouseActive
    local hover = useMouse and self:nodeAt(mx, my) or nil
    local focus = hover or (not useMouse and self.cursor) or nil

    lg.setColor(0.02, 0.015, 0.02, 0.72)
    lg.rectangle("fill", 0, 0, w, h)
    local P = L.panel
    plate(P.x, P.y, P.w, P.h, COL.frame, true)
    Tree.drawTabs(L.tabs, "skills", sk.points)

    -- header: level, points, XP to the next point
    lg.setFont(Theme.font(16))
    local hx = L.tabs[2].x + L.tabs[2].w + u(24)
    Theme.printShadow("LEVEL " .. sk.level, hx, L.tabs[1].y + u(2), COL.label)
    local ptsCol = sk.points > 0 and { 0.45, 0.9, 1 } or COL.dim
    Theme.printShadow(sk.points .. (sk.points == 1 and " point" or " points") .. " to spend", hx + u(90), L.tabs[1].y + u(2), ptsCol)
    local bw = math.floor(u(220))
    local bx, by = P.x + P.w - L.pad - bw, L.tabs[1].y + u(8)
    lg.setColor(COL.frameLo)
    lg.rectangle("fill", bx - 1, by - 1, bw + 2, u(8) + 2)
    lg.setColor(0.35, 0.75, 1)
    lg.rectangle("fill", bx, by, bw * math.min(1, sk.into / sk.toNext), u(8))
    lg.setFont(Theme.font(13))
    lg.setColor(COL.dim)
    lg.printf(math.floor(sk.into) .. " / " .. sk.toNext .. " XP", bx - u(160), by - u(3), u(152), "right")

    if not self.tree then
        lg.setFont(Theme.font(18))
        Theme.printShadow("This bug has no skill tree yet.", P.x, P.y + P.h / 2, COL.dim, "center", P.w)
        return
    end

    local A = L.area
    plate(A.x - 3, A.y - 3, A.w + 6, A.h + 6, COL.frameLo)
    lg.setColor(COL.inner)
    lg.rectangle("fill", A.x, A.y, A.w, A.h)

    -- branches: title, then links, then nodes
    for bi, br in ipairs(self.tree.branches) do
        local B = L["branch" .. bi]
        local c = br.color or COL.label
        if bi > 1 then
            lg.setColor(COL.frameLo)
            lg.rectangle("fill", math.floor(B.x), A.y + u(4), 2, A.h - u(8))
        end
        lg.setFont(Theme.font(16, "bold"))
        Theme.printShadow(br.name:upper(), B.x, A.y + u(6), c, "center", B.w)
        -- links to the nodes each one needs
        for _, n in ipairs(br.nodes) do
            local r = L.nodes[n.id]
            for _, q in ipairs(n.requires) do
                local o = L.nodes[q]
                if o then
                    local owned = sk:rank(q) > 0
                    local lit = owned and sk:status(n) ~= "excluded"
                    lg.setColor(lit and c[1] or 0.3, lit and c[2] or 0.25, lit and c[3] or 0.22, lit and 0.9 or 0.6)
                    lg.setLineWidth(lit and 3 or 2)
                    lg.line(o.x + o.w / 2, o.y + o.h, r.x + r.w / 2, r.y)
                end
            end
        end
        lg.setLineWidth(1)
        -- "OR" between fork siblings
        local seen = {}
        for _, n in ipairs(br.nodes) do
            if #n.excludes > 0 and not seen[n.tier] then
                seen[n.tier] = true
                local r = L.nodes[n.id]
                lg.setFont(Theme.font(12, "bold"))
                Theme.printShadow("OR", B.x, r.y + r.h / 2 - u(7), COL.dim, "center", B.w)
            end
        end
        for _, n in ipairs(br.nodes) do self:drawNode(n, L.nodes[n.id], c, n == focus) end
    end

    -- the info strip: what the focused node does
    local I = L.info
    plate(I.x, I.y, I.w, I.h, COL.inner)
    local n = focus
    if n then
        local st = sk:status(n)
        local c = self.tree.branches[n.branch].color or COL.label
        lg.setFont(Theme.font(18, "bold"))
        Theme.printShadow(n.name, I.x + u(12), I.y + u(8), c)
        lg.setFont(Theme.font(14))
        local r = sk:rank(n.id)
        local meta = n.cost .. (n.cost == 1 and " point" or " points") .. (n.ranks > 1 and (" per rank  ·  rank " .. r .. "/" .. n.ranks) or "")
        lg.setColor(COL.dim)
        lg.printf(meta, I.x, I.y + u(11), I.w - u(12), "right")
        lg.setColor(Theme.colors.text)
        lg.printf(n.desc, I.x + u(12), I.y + u(32), I.w - u(24))
        local stc = st == "available" and Theme.colors.good or (st == "maxed" and { 0.45, 0.9, 1 } or Theme.colors.bad)
        local txt = STATUS_TEXT[st]
        if st == "available" and not useMouse then txt = "Press " .. (Input.lastDevice == "gamepad" and "A" or "Enter") .. " to learn" end
        if st == "excluded" then
            for _, x in ipairs(n.excludes) do
                if sk:rank(x) > 0 then txt = "Locked: you took " .. self.tree.nodes[x].name end
            end
        end
        lg.setColor(stc)
        lg.print(txt, I.x + u(12), I.y + I.h - u(22))
    else
        lg.setFont(Theme.font(14))
        lg.setColor(COL.dim)
        lg.printf("Every ant you kill is 1 XP. Each level is a skill point. You can't learn everything in one run, and forks are either/or: choose a path.",
            I.x + u(12), I.y + u(16), I.w - u(24))
    end

    lg.setFont(Theme.font(18, "bold"))
    for _, p in ipairs(self.pops) do
        Theme.printShadow(p.text, p.x - u(60), p.y - u(16) - p.t * u(26), { 0.5, 0.95, 1, 1 - p.t }, "center", u(120))
    end
    lg.setColor(1, 1, 1, 1)
end

function Tree:drawNode(n, r, c, focused)
    local u = Theme.u
    local Inv = require("src.states.inventory")
    local COL = Inv.COL
    local sk = self.skills
    local st = sk:status(n)
    local rank = sk:rank(n.id)
    local owned = rank > 0
    -- body
    local k = owned and 0.42 or (st == "available" and 0.22 or 0.1)
    lg.setColor(COL.frameLo)
    lg.rectangle("fill", r.x - 2, r.y - 2, r.w + 4, r.h + 4, 4)
    lg.setColor(c[1] * k + 0.04, c[2] * k + 0.035, c[3] * k + 0.03)
    lg.rectangle("fill", r.x, r.y, r.w, r.h, 3)
    -- edge
    local ea = owned and 1 or (st == "available" and (0.6 + 0.4 * math.sin(self.t * 5)) or 0.3)
    if st == "excluded" then lg.setColor(0.6, 0.25, 0.22, 0.6)
    elseif st == "available" then lg.setColor(1, 0.85, 0.4, ea)
    else lg.setColor(c[1], c[2], c[3], ea) end
    lg.setLineWidth(owned and 2 or 1)
    lg.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 3)
    lg.setLineWidth(1)
    if focused then
        lg.setColor(Theme.colors.focus)
        lg.rectangle("line", r.x - 3.5, r.y - 3.5, r.w + 7, r.h + 7, 5)
    end
    -- name
    local f = Theme.font(13, owned and "bold" or nil)
    lg.setFont(f)
    local tc = owned and { 1, 0.97, 0.9 } or (st == "available" and Theme.colors.text or COL.dim)
    if st == "excluded" or st == "locked" then tc = { 0.45, 0.4, 0.38 } end
    local _, lines = f:getWrap(n.name, r.w - u(8))
    local th = #lines * f:getHeight()
    lg.setColor(tc)
    lg.printf(n.name, r.x + u(4), math.floor(r.y + (r.h - th) / 2 - (n.ranks > 1 and u(4) or 0)), r.w - u(8), "center")
    -- rank pips, cost tag
    if n.ranks > 1 then
        local pw, gap = u(8), u(3)
        local total = n.ranks * pw + (n.ranks - 1) * gap
        local px = r.x + (r.w - total) / 2
        for i = 1, n.ranks do
            lg.setColor(i <= rank and { c[1], c[2], c[3] } or COL.socket)
            lg.rectangle("fill", math.floor(px + (i - 1) * (pw + gap)), r.y + r.h - u(8), pw, u(3))
        end
    end
    if st ~= "maxed" then
        lg.setFont(Theme.font(11, "bold"))
        lg.setColor(st == "available" and { 1, 0.85, 0.4 } or COL.dim)
        lg.print(tostring(n.cost), r.x + u(4), r.y + u(2))
    end
    if st == "excluded" then
        lg.setColor(0.6, 0.25, 0.22, 0.5)
        lg.line(r.x + 4, r.y + 4, r.x + r.w - 4, r.y + r.h - 4)
    end
end

return Tree
