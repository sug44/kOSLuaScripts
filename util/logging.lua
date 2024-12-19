local M = {}

local severity_stack = { 0 }

local severities = {
    debug = 0,
    message = 1,
    warning = 2,
    error = 3
}

function M.get_threshold()
    return severity_stack[#severity_stack]
end

function M.push_threshold(threshold)
    table.insert(severity_stack, threshold)
end

function M.pop_threshold()
    table.remove(severity_stack)
end

function M.event(text, severity)
    if severity >= M.get_threshold() then
        print(text)
    end
end

function M.debug(text)
    M.event(text, severities.debug)
end

function M.message(text)
    M.event(text, severities.message)
end

function M.warning(text)
    M.event(text, severities.warning)
end

function M.error(text)
    M.event(text, severities.error)
    error()
end

return M
