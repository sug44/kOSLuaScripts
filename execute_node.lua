tail_factor = ...
tail_factor = tail_factor or 0.2

local log = require "util/logging"
local util = require "util/util"
local stage_util = require "util/stage_utils"

local function get_fancy_burn_duration(burn_dv, vessel_stage_info)
    local stage_number = stageinfo.number
    local result = 0

    log.debug("calculating burn duration for " .. round(burn_dv, 1) .. " m/s dv")

    while burn_dv > 0.001 and stage_number >= 0 do
        local stage_info = vessel_stage_info[stage_number+1]
        
        local dv_from_this_stage = min(burn_dv, stage_info.dv)
        
        if (dv_from_this_stage > 0) then
            burn_dv = burn_dv - dv_from_this_stage

            local final_stage_mass = stage_info.totalmass / (constant.e ^ (dv_from_this_stage / constant.g0 / stage_info.isp))
            local fuel_mass_burned = stage_info.totalmass - final_stage_mass
            local stage_burn_time = fuel_mass_burned / util.get_mass_flow_rate(stage_info.engines)

            log.debug("stage: " .. stage_number)
            log.debug("stage dv: " .. round(dv_from_this_stage))
            log.debug("remaining burn dv: " .. round(burn_dv))
            log.debug("thrust: " .. round(stage_info.thrust, 1))
            log.debug("burn time: " .. util.format_time(stage_burn_time))

            result = result + stage_burn_time
        end

        stage_number = stage_number - 1
    end

    return result
end

local function get_total_ship_dv(vessel_stage_info)
    local result = 0

    for _,stage_info in ipairs(vessel_stage_info) do
        result = result + stage_info.dv
    end

    return result
end

log.message("=== execute_node ===")

if not sas or sasmode ~= "maneuver" then
	sas = false
	steering => nextnode.deltav
end

local vessel_stage_info = stage_util.get_vessel_stage_info()

if get_total_ship_dv(vessel_stage_info) < nextnode.deltav.mag then
    log.warning("*** vessel does not appear to have enough dv for this maneuver ***")
end

log.debug("-- half burn duration --")
local half_burn_duration = get_fancy_burn_duration(nextnode.deltav.mag/2, vessel_stage_info)

waituntil(> vang(ship.facing.vector, nextnode.deltav) < 0.5)

util.warp_and_wait(nextnode.eta - half_burn_duration - 5 - 60)

if not sas or sasmode ~= "maneuver" then
	sas = false
	steering => nextnode.deltav
end

waituntil(> vang(ship.facing.vector, nextnode.deltav) < 0.5)

local time_to_burn_start = nextnode.eta - half_burn_duration

if time_to_burn_start < -5 then
    log.error("PASSED BURN START TIME!")
end

util.warp_and_wait(time_to_burn_start)

initial_node_direction = nextnode.deltav

if tail_factor > 0 then
    throttle = function()
        local result = 0
        if (ship.maxthrust>0) then
            result = min(1, nextnode.deltav.mag / (tail_factor * ship.maxthrust / ship.mass))
        end
        return result
    end
else
    throttle = 1
end

local old_thrust = ship.maxthrust
while not (vang(initial_node_direction, nextnode.deltav) > 90 or nextnode.deltav.mag < 0.001) do
    if ship.maxthrust < old_thrust then
        log.message("stage expired during node execution; remaining dv. " .. round(nextnode.deltav.mag, 1))
        util.stage_to_next_engine()
        old_thrust = ship.maxthrust
    end
    wait(0)
end

sas = false
steering = "kill"

throttle = 0
throttle = nil
wait(1)
remove(nextnode)
wait(0)
