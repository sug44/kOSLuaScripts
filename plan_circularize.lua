local m_which, m_orbit = ...
m_which = m_which or ""
m_orbit = m_orbit or ship.orbit

local util = require "util/util"
local orbit_util = require "util/orbit_util"
local log = require "util/logging"

if m_orbit.hasnextpatch and m_which ~= "pe" then
    if m_which ~= "" then log.warning("specified orbit is not closed; circularizing at PE instead") end
    m_which = "pe"
elseif m_which == "" then
    m_which = "next"
end

if (m_which ~= "ap" and m_which ~= "pe" and m_which ~= "next") then
  log.error("first parameter must be one of 'pe', 'ap', or 'next'")
end

-- this works for future hyperbolic orbits since meananomalyatepoch should be negative
local pe_timestamp = m_orbit.epoch - (m_orbit.meananomalyatepoch*constant.degtorad / sqrt(m_orbit.body.mu / abs(m_orbit.semimajoraxis)^3))

-- if this if an elliptical patch in the future, need to make sure that the calculated PE is after the epoch
if m_orbit.epoch > time.seconds and m_orbit.semimajoraxis > 0 then
    pe_timestamp = pe_timestamp + m_orbit.period
end

-- and if the periapsis is in the past, bring it forward
if time.seconds > pe_timestamp then
    pe_timestamp = time.seconds + m_orbit.period - mod(time.seconds - pe_timestamp, m_orbit.period)
end

local time_until_next_pe = pe_timestamp - time.seconds
local orbit_period = orbit_util.get_orbit_period(m_orbit.semimajoraxis, m_orbit.body)

log.debug("orbit period: " .. util.format_time(orbit_period))

-- select the next closest AP
local time_until_next_ap = time_until_next_pe - orbit_period / 2

-- unless it's before the epoch
if time.seconds + time_until_next_ap < m_orbit.epoch then
    time_until_next_ap = time_until_next_ap + orbit_period
end

log.debug("time until next pe: " .. util.format_time(time_until_next_pe))
log.debug("time until next ap: " .. util.format_time(time_until_next_ap))

if m_which == "next" then m_which = time_until_next_pe < time_until_next_ap and "pe" or "ap" end

local node_timestamp = time.seconds + (m_which == "pe" and time_until_next_pe or time_until_next_ap)
local sma_at_node = m_orbit.semimajoraxis * (m_which == "pe" and (1 - m_orbit.eccentricity) or (1 + m_orbit.eccentricity))

log.debug("sma at node: " .. sma_at_node)

local altitude_at_node = sma_at_node - m_orbit.body.radius

log.message("=== circularizing at " .. round(altitude_at_node/1000, 1) .. "km ===")

local necessary_speed = orbit_util.get_orbital_speed_at_altitude(altitude_at_node, sma_at_node, m_orbit.body)
local current_speed = orbit_util.get_orbital_speed_at_altitude(altitude_at_node, m_orbit.semimajoraxis, m_orbit.body)
add(node(node_timestamp, 0, 0, necessary_speed - current_speed))

