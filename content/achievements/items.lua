-- Items and the bag.
local list = {}
local function add(a) a.category = "Items"; list[#list + 1] = a; a.order = #list end

add({ id = "take_100", name = "Hoarder", description = "Take 100 items.", goal = 100, value = function(p) return p.itemsTaken end })
add({ id = "eat_1", name = "Peckish", description = "Eat an item.", value = function(p) return p.itemsEaten end })
add({ id = "eat_50", name = "Bottomless", description = "Eat 50 items.", goal = 50, value = function(p) return p.itemsEaten end })
add({ id = "eat_run8", name = "Gourmand", description = "Eat 8 items in one run.", goal = 8,
    value = function(p, run) return run and run.itemsEaten or 0 end })
add({ id = "bag_full", name = "Perfect Fit", description = "Fill every cell of your bag.", hidden = true,
    value = function(p, run)
        if not run then return false end
        local inv = run.world.player.inventory
        return inv:usedCells() >= inv.cols * inv.rows
    end })
return list
