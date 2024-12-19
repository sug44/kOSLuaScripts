local M = {}

log = require "util/logging"

M.normal => vcrs(ship.velocity.orbit, -body.position)
M.radialin => vcrs(ship.velocity.orbit, normal())

function M.get_active_engines()
    local result = {}
    for _,e in ipairs(buildlist("engines")) do
        if (e.ignition and not e.flameout) then
            table.insert(result, e)
        end
    end
    return result
end

function M.get_burn_duration(deltav)
    local engines = M.get_active_engines()
    local isp = M.get_combined_isp(engines)
    local final_mass = ship.mass / (constant.e ^ (deltav / constant.g0 / isp))
    local fuel_mass_remaining = M.get_fuel_mass_of_current_stage()
    local burn_duration = (ship.mass - final_mass) / M.get_mass_flow_rate(engines)
    log.debug("isp: " .. isp)
    log.debug("current mass: " .. round(ship.mass, 2))
    log.debug("final mass: " .. round(final_mass, 2))
    log.debug("delta mass: " .. round(ship.mass - final_mass, 2))
    log.debug("fuel remaining: " .. round(fuel_mass_remaining, 2))
    log.debug("mass flow rate: " .. M.get_mass_flow_rate(engines))
    log.debug("burn time: " .. round(burn_duration, 2))

    return burn_duration
end

function M.get_fuel_mass_of_current_stage()
    -- WARNING: stage.resourceslex can be wrong!
    local liquid_fuel = (stageinfo.resourceslex.liquidfuel or {}).amount or 0
    local oxidizer = (stageinfo.resourceslex.oxidizer or {}).amount or 0
    local density_t_per_L = 5/1000
    return density_t_per_L * (liquid_fuel + oxidizer)
end

function M.get_combined_isp(engines)
    local numerator = 0
    for _,e in ipairs(engines) do
        numerator = numerator + e.possiblethrust
    end
    local mass_flow_rate = M.get_mass_flow_rate(engines)
    if mass_flow_rate > 0 then
        return numerator / mass_flow_rate / constant.g0
    end
    return 0
end

function M.engines_are_vacuum(engines)
    local result = true
    for _,e in ipairs(engines) do
        if (e.ispat(0) / e.ispat(1) < 2) then
            result = false
        end
    end
    return result
end

function M.get_mass_flow_rate(engines)
    local result = 0
    for _,e in ipairs(engines) do
        if (e.ispat(0) > 0) then
            result = result + e.possiblethrustat(0) / (e.ispat(0) * constant.g0)
        end
    end
    return result
end

function M.warp_and_wait(duration)
    local endtime = time.seconds + duration
    if duration < 0 then return end
    log.message("waiting for " .. M.format_time(duration))
    kuniverse.timewarp.cancelwarp()
    while duration > 10 do
        warp = 0
        waituntil(>kuniverse.timewarp.issettled)
        warpmode = ship.altitude > body.atm.height and "rails" or "physics"
        warp = 1
        waituntil(> kuniverse.timewarp.issettled)
        kuniverse.timewarp.warpto(endtime - 5)
        waituntil(> warp == 0 and kuniverse.timewarp.issettled)
        duration = endtime - time.seconds
        log.debug("still " .. M.format_time(duration) .. " left")
    end
    wait(endtime - time.seconds - 5)
    warp = 0
    wait(endtime - time.seconds)
end

function M.stage_to_next_engine()
    stage()
    while ship.maxthrustat(0) <= 0 do
        waituntil(>stageinfo.ready)
        stage()
    end
    wait(0)
end

function M.format_time(t)
    local h = floor(t/60/60)
    local m = mod(floor(t/60), 60)
    local s = mod(t, 60)
    return tostring(h) .. "h" .. m .. "m" .. round(s, 2)
end

function M.get_maximum_periapsis_for_destruction(b)
    b = b or body

    if b.atm.exists then
        local upper_bound = b.atm.height
        local lower_bound = 0
        while upper_bound - lower_bound >= 1000 do
            local midpoint = (upper_bound + lower_bound) / 2
            local pressure = b.atm.altitudepressure(midpoint)
            if pressure > 0.01 then
                lower_bound = midpoint
            else
                upper_bound = midpoint
            end
        end
        return lower_bound
    else
        return 0
    end
end

return M
