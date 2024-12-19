local ascent_roll, hdg, target_apoapsis = ...
target_apoapsis = target_apoapsis or body.atm.height + 10000

dofile("launch.lua")
loadfile("ascent.lua")(ascent_roll, hdg, target_apoapsis)
dofile("plan_circularize.lua")
dofile("execute_node.lua")
