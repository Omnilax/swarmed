-- A mud dauber's pipe: a solid tube of mud that stands where it was built and crumbles away
-- after `life` seconds.
-- params: life (14)
-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.45, 0.33, 0.22 }
local PFX_2 = { 0.6, 0.48, 0.34 }
local PFX_3 = { grav = 300 }
local PFX_LIST_1 = { PFX_1, PFX_2 }

return {
    name = "Mud pipe",
    init = function(e) e.st.t = 0 end,
    update = function(e, world, dt, params)
        local st = e.st
        e.mx, e.my, e.kvx, e.kvy = 0, 0, 0, 0
        e.biteCd = 1
        st.t = st.t + dt
        e.scale = e.baseScale * math.min(1, 0.4 + st.t * 3)
        if st.t >= (params.life or 14) then
            -- crumbles: gone without counting as a kill
            world.particles:burst(e.x, e.y, 6, PFX_LIST_1, 40, 40, PFX_3)
            e.dead = true
        end
    end,
}
