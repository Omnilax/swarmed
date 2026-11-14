-- 2:1 isometric projection. The world is a flat square plane (x, y) plus height z.
-- Gameplay (movement, collision, ranges) happens in world space; only drawing projects.
local Iso = {}

function Iso.toScreen(x, y, z)
    return x - y, (x + y) * 0.5 - (z or 0)
end

function Iso.toWorld(sx, sy)
    return sy + sx * 0.5, sy - sx * 0.5
end

-- Convert a screen-space direction (e.g. stick or WASD) to a normalised world direction.
function Iso.screenDirToWorld(dx, dy)
    local wx, wy = dy + dx * 0.5, dy - dx * 0.5
    local l = math.sqrt(wx * wx + wy * wy)
    if l == 0 then return 0, 0 end
    return wx / l, wy / l
end

-- Depth key for draw sorting: things further "down" the screen draw later.
function Iso.depth(x, y) return x + y end

return Iso
