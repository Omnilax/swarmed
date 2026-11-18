-- Generic content registry.
--
-- Every kind of content (enemies, items, characters, attacks, stages, ...) lives in its own
-- Registry. A registry can auto-load a whole folder: each .lua file returns one definition
-- (its id defaults to the file name) or a list of definitions. Files starting with "_" are
-- skipped, so templates can sit next to real content.
--
-- Adding new content therefore never requires touching engine code: drop a file in the folder.
local util = require("src.core.util")

local Registry = {}
Registry.__index = Registry

-- schema = { required = {"field", ...}, defaults = {...}, validate = function(def) -> ok, err }
function Registry.new(kind, schema)
    return setmetatable({ kind = kind, schema = schema or {}, byId = {}, list = {} }, Registry)
end

function Registry:register(def, fallbackId)
    assert(type(def) == "table", self.kind .. ": definition must be a table")
    def.id = def.id or fallbackId
    if not def.id then error(self.kind .. ": definition is missing an id") end
    if self.byId[def.id] then error(("%s: duplicate id '%s'"):format(self.kind, def.id)) end

    local schema = self.schema
    if schema.defaults then util.applyDefaults(def, schema.defaults) end
    for _, field in ipairs(schema.required or {}) do
        if def[field] == nil then
            error(("%s '%s' is missing required field '%s'"):format(self.kind, def.id, field))
        end
    end
    if schema.validate then
        local ok, err = schema.validate(def)
        if not ok then error(("%s '%s': %s"):format(self.kind, def.id, err)) end
    end

    self.byId[def.id] = def
    self.list[#self.list + 1] = def
    return def
end

function Registry:loadDirectory(dir)
    local files = love.filesystem.getDirectoryItems(dir)
    table.sort(files)
    for _, file in ipairs(files) do
        local name = file:match("^(.-)%.lua$")
        if name and name:sub(1, 1) ~= "_" then
            local modPath = (dir .. "/" .. name):gsub("/", ".")
            local result = require(modPath)
            if type(result) ~= "table" then
                error(("%s file '%s/%s' must return a table"):format(self.kind, dir, file))
            end
            if result.id == nil and type(result[1]) == "table" then
                for _, def in ipairs(result) do self:register(def) end
            else
                self:register(result, name)
            end
        end
    end
    self:sort()
end

-- Optional `order` field controls listing order (menus, sandbox pickers); ties sort by id.
function Registry:sort()
    table.sort(self.list, function(a, b)
        local oa, ob = a.order or 0, b.order or 0
        if oa ~= ob then return oa < ob end
        return a.id < b.id
    end)
end

-- Remove a definition (custom bugs are re-registered when edited or deleted).
function Registry:unregister(id)
    local def = self.byId[id]
    if not def then return nil end
    self.byId[id] = nil
    for i, d in ipairs(self.list) do
        if d == def then table.remove(self.list, i) break end
    end
    return def
end

function Registry:get(id) return self.byId[id] end

function Registry:require(id)
    local def = self.byId[id]
    if not def then error(("unknown %s '%s'"):format(self.kind, tostring(id))) end
    return def
end

function Registry:all() return self.list end

function Registry:count() return #self.list end

function Registry:filter(pred)
    local out = {}
    for _, def in ipairs(self.list) do
        if pred(def) then out[#out + 1] = def end
    end
    return out
end

function Registry:ids()
    local out = {}
    for i, def in ipairs(self.list) do out[i] = def.id end
    return out
end

function Registry:pickWeighted(weightFn, pred)
    return util.weightedPick(pred and self:filter(pred) or self.list, weightFn)
end

return Registry
