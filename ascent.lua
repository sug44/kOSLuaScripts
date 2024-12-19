local desired_roll, desired_heading, target_apoapsis, turn_target_altitude, throttle_down_altitude = ...
desired_roll = desired_roll or 0
desired_heading = desired_heading or 90
target_apoapsis = target_apoapsis or body.atm.height + 10000
turn_target_altitude = turn_target_altitude or target_apoapsis + 20000
throttle_down_altitude = throttle_down_altitude or target_apoapsis - 20000

local log = require "util/logging"
local util = require "util/util"

log.message("=== ascent ===")

throttle = 1
sas = false

function turn(target_altitude, exponent)
    target_altitude = target_altitude or turn_target_altitude
    exponent = exponent or 0.5
    steering => heading(desired_heading, max(0, 90*(1-(apoapsis/target_altitude)^exponent))) * r(0, 0, desired_roll)
end

turn()

local old_thrust = ship.maxthrustat(0)

local tanks_by_stage = {}
for _ = 0, stageinfo.number do
    table.insert(tanks_by_stage, {})
end

for _,p in ipairs(buildlist("parts")) do
    if p.stage >= 0 then
        for _,r in ipairs(p.resources) do
            if (r.name:lower() == "liquidfuel" and r.enabled and r.amount > 0) then
                table.insert(tanks_by_stage[p.stage+1], p)
                break
            end
        end
    end
end

local gravity => body.mu/(altitude+body.radius)^2
local twr => (ship.availablethrust / ship.mass / gravity())

when(> apoapsis > throttle_down_altitude and twr() > 1, function() throttle = 0.5 end)

while apoapsis < target_apoapsis do
    local should_stage = false

    if ship.maxthrustat(0) < old_thrust then
        should_stage = true
    end

    if stageinfo.number > 1 and not tanks_by_stage[stageinfo.number].empty then
        local fuel_in_stage = 0
        for _,t in ipairs(tanks_by_stage[stageinfo.number]) do
            for _,r in ipairs(t.resources) do
                if r.name:lower() == "liquidfuel" then
                    fuel_in_stage = fuel_in_stage + r.amount
                    break
                end
            end
        end
        if fuel_in_stage < 0.001 then
            log.message("empty fuel tank detected.")
            should_stage = true
        end
    end

    if should_stage then
        if (body.atm.exists and body.atm.altitudepressure(altitude) > 0.01) then
            steering => srfprograde * r(0, 0, desired_roll)
            log.message("turning prograde for staging")
            local start_stage_time = time.seconds
            waituntil(> vang(ship.facing.vector, srfprograde.vector) < 1 or time.seconds - start_stage_time > 5)
        end
        util.stage_to_next_engine()
        old_thrust = ship.maxthrustat(0)
        wait(1)
        log.message("resuming turn")
        turn()
    end
    wait(0.5)
end

steering => velocityat(ship, time.seconds + eta.apoapsis).orbit

throttle = 0
wait(0)

log.message("coasting to exit atmosphere")

waituntil(> altitude > body.atm.height)
wait(1)
