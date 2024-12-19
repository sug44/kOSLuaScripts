local M = {}

local util = require "util/util"

local function add_part_to_stage_info(part, stage_info)
    table.insert(stage_info.parts, part)

    stage_info.mass = stage_info.mass + part.mass

    local part_is_tank = false

    for _,resource in ipairs(part.resources) do
        if resource.enabled then
            stage_info.fuelmass = stage_info.fuelmass + resource.amount * resource.density

            if resource.density > 0 then
                part_is_tank = true
            end
        end
    end

    if part_is_tank then
        table.insert(stage_info.tanks, part)
    end
end

local function finalize_vessel_stage_info(vessel_stage_info)
    for stage_index=0,#vessel_stage_info-1 do
        local stage_info = vessel_stage_info[stage_index+1]

        stage_info.totalmass = stage_info.mass + (stage_index == 0 and 0 or vessel_stage_info[stage_index].totalmass)
        stage_info.isp = util.get_combined_isp(stage_info.engines)
        if stage_info.fuelmass > 0 and #stage_info.engines then
            local drymass = stage_info.totalmass - stage_info.fuelmass
            stage_info.dv = stage_info.isp * constant.g0 * ln(stage_info.totalmass / drymass)
            local mass_flow_rate = util.get_mass_flow_rate(stage_info.engines)
            stage_info.burntime = mass_flow_rate ==  0 and 0 or stage_info.fuelmass / mass_flow_rate
        end
    end
end

local function get_part_stage(part)
    local result = 0
    if (part.istype("launchclamp") or part.istype("decoupler")) and not part.istype("dockingport") then
        result = part.stage+1
    else
        result = part.decoupledin+1
    end

    return min(result, stageinfo.number)
end

function M.get_vessel_stage_info()
    local result = {}

    for i=0,stageinfo.number do
        table.insert(result, {
            parts = {},
            tanks = {},
            engines = {},
            resources = {},
            resourceslex = {},
            mass = 0,
            totalmass = 0,
            fuelmass = 0,
            thrust = 0,
            isp = 0,
            dv = 0,
            burntime = 0
        })
    end

    local engines = buildlist("engines")

    local any_active_engines = false
    for _,engine in ipairs(engines) do
        if engine.ignition then any_active_engines = true break end
    end

    for _,engine in ipairs(engines) do
        if not any_active_engines or engine.ignition or engine.stage ~= stageinfo.number then
            local last_stage_index = engine.ignition and stageinfo.number or engine.stage
            for stage_index = get_part_stage(engine), last_stage_index do -- TODO: check
                local stage_info = result[stage_index+1]
                table.insert(stage_info.engines, engine)
                stage_info.thrust = stage_info.thrust + engine.possiblethrust
            end
        end
    end

    for _,part in ipairs(ship.parts) do
        local stage_info = result[get_part_stage(part)+1]
        add_part_to_stage_info(part, stage_info)
    end

    finalize_vessel_stage_info(result)

    return result
end

return M
