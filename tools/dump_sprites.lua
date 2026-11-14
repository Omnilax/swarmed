-- luajit tools/dump_sprites.lua content/sprites/x.lua : prints sprites in a simple text format
local f = assert(loadfile(arg[1]))
local data = f()
if data.id then data = { data } end
for _, s in ipairs(data) do
  print("S " .. s.id)
  for k, v in pairs(s.palette) do print("P " .. k .. " " .. v) end
  for _, fr in ipairs(s.frames) do
    print("F")
    for _, r in ipairs(fr) do print("R " .. r) end
  end
end
