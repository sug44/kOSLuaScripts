local M = {}

local log = require "util/logging"

function M.get_orbital_speed_at_altitude(a, sma, b)
    sma = sma or ship.orbit.semimajoraxis
    b = b or body
    return sqrt(b.mu * (2/(a + b.radius) - 1/sma))
end

function M.get_average_orbital_speed(sma, b)
    sma = sma or ship.orbit.semimajoraxis
    b = b or body
    return sqrt(b.mu/sma)
end

function M.get_average_orbital_speed_of(obj)
    obj = obj or ship
    return M.get_average_orbitable_speed(obj.orbit.semimajoraxis, obj.body)
end

function M.get_orbit_period(sma, b)
    sma = sma or ship.orbit.semimajoraxis
    b = b or body

    return 2 * constant.pi * sqrt(abs(sma^3) / b.mu)
end

function M.get_current_mean_anomaly(m_orbit)
    local time_since_epoch = time.seconds - m_orbit.epoch
    local mean_anomaly = m_orbit.meananomalyatepoch + sqrt(m_orbit.body.mu / abs(m_orbit.semimajoraxis^3)) * time_since_epoch * constant.radtodeg

    return mod(360 + mean_anomaly, 360)
end

function M.get_orbit_period_of(obj)
    obj = obj or ship
    return M.get_orbit_period(obj.orbit.semimajoraxis, obj.body)
end

function M.get_phase_angle_to_position(position)
    local ship_vec = ship.position - body.position
    local target_vec = position - body.position
    local angle = vang(ship_vec, target_vec)
    local cross = vcrs(ship_vec, target_vec)
    if (cross.y > 0) then angle = -angle end
    return angle
end

function M.get_phase_angle_to(tgt)
    tgt = tgt or target
    return M.get_phase_angle_to_position(tgt.position)
end

function M.mean_anomaly_from_true_anomaly(e, a)
    local eccentric_anomaly = 2 * arctan(((1+e)/(1-e))^(-1/2) * tan(a/2))
    local mean_anomaly_radians = eccentric_anomaly / 180 * constant.pi - e * sin(eccentric_anomaly)
    return mod(360 + mean_anomaly_radians * (180 / constant.pi), 360)
end

function M.true_anomaly_from_mean_anomaly(e, M)
    return M + (2*e - 1/4 * e^3) * sin(M) + 5/4 * e^2 * sin(2*M) + 13/12 * e^3 * sin(3*M)
end

function M.get_mean_anomaly_at_time(o, t)
    return mod(o.meananomalyatepoch + 360/o.period * (t - o.epoch), 360)
end

-- returns a table with keys.
-- inclination - the signed angle between the two orbits
-- vector_to_AN - a vector from the body center = the ascending node
-- true_anomaly_delta - how far ahead of the 'a' object (or behind if negative) the ascending node is
function M.get_inclination_info_between_orbits(orbit_a, orbit_b)
    if orbit_a.body ~= orbit_b.body then
        log.error("cannot compare inclination between orbits " .. orbit_a.name .. " and " .. orbit_b.name ..
        " because they are around different bodies. " .. orbit_a.body.name .. " and " .. orbit_b.body.name)
    end

    local vector_to_a = orbit_a.position - orbit_a.body.position
    local normal_a = vcrs(orbit_a.velocity.orbit, vector_to_a)
    local normal_b = vcrs(orbit_b.velocity.orbit, orbit_b.position - orbit_b.body.position)
    local vector_to_AN = vcrs(normal_a, normal_b)

    local true_anomaly_delta = vang(vector_to_a, vector_to_AN)

    local sign_test = vcrs(vector_to_AN, vector_to_a)
    if (vdot(sign_test, normal_a) < 0) then
        true_anomaly_delta = -true_anomaly_delta
    end

    return {
        inclination = vang(normal_a, normal_b),
        vector_to_AN = vector_to_AN,
        true_anomaly_delta = true_anomaly_delta
    }
end

function M.find_patch(body_name, orbit)
    orbit = orbit or ship.orbit

    local patch = orbit
    local eta = 0
    while patch.body.name ~= body_name do
        if (patch.hasnextpatch) then
            eta = patch.nextpatcheta
            patch = patch.nextpatch
        else
            log.error(body_name .. " NOT FOUND ON FLIGHT PATH!")
            break
        end
    end

    return { patch = patch, eta = eta }
end

-- returns the time at which the given orbit will be at the given mean anomaly
function M.get_timestamp_at_mean_anomaly(orbit, mean_anomaly)
    local current_mean_anomaly = M.get_current_mean_anomaly(orbit)
    local delta_mean_anomaly = mod(360 + mean_anomaly - current_mean_anomaly, 360)
    local delta_time = delta_mean_anomaly / 360 * orbit.period
    return time.seconds + delta_time
end

-- returns the time at which the given orbitable will be at the given true anomaly
function M.get_timestamp_at_true_anomaly (orbit, true_anomaly)
    local mean_anomaly = M.mean_anomaly_from_true_anomaly(orbit.eccentricity, true_anomaly)
    return M.get_timestamp_at_mean_anomaly(orbit, mean_anomaly)
end

return M
