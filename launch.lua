local countdown = ... or 3

local log = require "util/logging"

log.message("=== launch ===")

local v0 = getvoice(0)

for i=countdown,1,-1 do
    log.message(i)
    v0.play(note("f4", 0.1, 0.5))
    wait(1)
end

log.message("0")
v0.play(note("c5", 0.3, 0.5))

steering = nil
sas = true

throttle = 1

if ship.status == "prelaunch" then
	stage()
end

local clamps = ship.modulesnamed("LaunchClamp")
while not clamps.empty do
    waituntil(> stageinfo.ready)
    stage()
	wait(0)
	clamps = ship.modulesnamed("LaunchClamp")
end

waituntil(> velocity.surface.mag > 50)

sas = false
