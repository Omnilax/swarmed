-- Uniform grid for fast "what is near this point" queries. Rebuilt every frame, which is
-- cheaper than tracking moves when hundreds of things move every frame. Cell arrays are reused
-- so there is no garbage per frame.
local SpatialHash = {}
SpatialHash.__index = SpatialHash

local floor = math.floor

function SpatialHash.new(cellSize)
    return setmetatable({ size = cellSize, cells = {}, used = {}, usedN = 0, out = {} }, SpatialHash)
end

local function key(cx, cy) return cx * 65536 + cy end

function SpatialHash:clear()
    for i = 1, self.usedN do
        self.used[i].n = 0
        self.used[i] = nil
    end
    self.usedN = 0
end

function SpatialHash:insert(obj)
    local s = self.size
    local k = key(floor(obj.x / s), floor(obj.y / s))
    local cell = self.cells[k]
    if not cell then
        cell = { n = 0 }
        self.cells[k] = cell
    end
    if cell.n == 0 then
        self.usedN = self.usedN + 1
        self.used[self.usedN] = cell
    end
    cell.n = cell.n + 1
    cell[cell.n] = obj
end

-- Returns a shared list of objects whose cells overlap the circle. The caller still does
-- exact distance checks. The list is reused: copy it if you need to keep it.
function SpatialHash:query(x, y, r, out)
    out = out or self.out
    local n = 0
    local s = self.size
    local x0, x1 = floor((x - r) / s), floor((x + r) / s)
    local y0, y1 = floor((y - r) / s), floor((y + r) / s)
    local cells = self.cells
    for cx = x0, x1 do
        for cy = y0, y1 do
            local cell = cells[key(cx, cy)]
            if cell then
                for i = 1, cell.n do
                    n = n + 1
                    out[n] = cell[i]
                end
            end
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return out, n
end

function SpatialHash:eachCell(fn)
    local s = self.size
    for i = 1, self.usedN do
        local c = self.used[i]
        if c.n > 0 then fn(floor(c[1].x / s) * s, floor(c[1].y / s) * s, s, c.n) end
    end
end

return SpatialHash
