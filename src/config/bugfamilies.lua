-- Bug families: how bug select groups the playable bugs (a tab and a section each, in this
-- order). A character joins the first family whose tag it has (content/characters `tags`), or
-- names one itself with `family = "<id>"`. Bugs made in the Bug Creator always sit in "custom".
-- A new family is one more row here; a bug that fits none lands in "other".
--   id, label (tab and section heading), tags, color (tile tint and heading), blurb (section line)
local F = {}

F.list = {
    { id = "beetle", label = "Beetles", tags = { "beetle" }, color = { 0.92, 0.66, 0.32 },
        blurb = "Armoured bruisers with horns, jaws and chemistry." },
    { id = "spider", label = "Spiders", tags = { "spider" }, color = { 0.74, 0.56, 0.9 },
        blurb = "Eight legs, fangs and silk." },
    { id = "arachnid", label = "Scorpions", tags = { "arachnid" }, color = { 0.95, 0.47, 0.36 },
        blurb = "Scorpions and their kin: pincers, whips and stings." },
    { id = "crustacean", label = "Crustaceans", tags = { "crustacean" }, color = { 0.42, 0.74, 0.92 },
        blurb = "Shells and claws from the tide pools." },
    { id = "insect", label = "Insects", tags = { "insect" }, color = { 0.6, 0.82, 0.45 },
        blurb = "Mantises, roaches, true bugs and flyers." },
    { id = "myriapod", label = "Myriapods", tags = { "myriapod" }, color = { 0.88, 0.78, 0.42 },
        blurb = "Long bodies, a hundred legs." },
    { id = "other", label = "Others", tags = {}, color = { 0.75, 0.7, 0.62 },
        blurb = "Bugs that fit nowhere else." },
    { id = "custom", label = "Custom", tags = {}, color = { 0.96, 0.56, 0.74 },
        blurb = "Bugs you made in the Bug Creator." },
}

F.byId = {}
for i, f in ipairs(F.list) do
    f.order = i
    F.byId[f.id] = f
end

-- The family a character belongs to (a row of F.list).
function F.of(def)
    if not def then return F.byId.other end
    if def.custom then return F.byId.custom end
    if type(def.family) == "string" and F.byId[def.family] then return F.byId[def.family] end
    local tags = {}
    for _, t in ipairs(def.tags or {}) do tags[t] = true end
    for _, f in ipairs(F.list) do
        for _, t in ipairs(f.tags) do
            if tags[t] then return f end
        end
    end
    return F.byId.other
end

return F
