#!/usr/local/bin/lua

package.path = package.path .. ';/home/john/Kranz/KranzServer/lib/?.lua'


local signal = require "posix.signal"
local socket = require "socket"
local cjson  = require "cjson"

local create   = require "create"
local update   = require "update"
local session  = require "session"
local read     = require "read"
local searches = require "searches"


function _process_request(json_text)
    local lua_table = cjson.decode(json_text)

    local action = lua_table.action

    if action == "create" then
        return create.create_post(lua_table)
    elseif action == "update" then
        return update.update_post(lua_table)
    elseif action == "request_login_link" then
        return session.create_and_send_no_password_login_link(lua_table) 
    elseif action == "activate_login" then
        return session.activate_no_password_login(lua_table)
    elseif action == "read" then
        return read.get_post(lua_table)
    elseif action == "logout" then
        return session.logout(lua_table)
    elseif action == "search" then
        return searches.searches(lua_table)
    end

end



function _save_to_file(json_content)
    local content_table = cjson.decode(json_content)

    if string.len(content_table.markup) > 0 then
        local filename = "/home/john/Kranz/KranzServer/" .. os.time() .. ".gemtext"
        local f = io.open(filename, "w")
        if f == nil then
            error("unable to open file " .. " for write.")
        else
            f:write(content_table.markup)
            f:close()
        end
    end
end



-- create a TCP socket and bind it to the local host, at any port
-- local server = assert(socket.bind("127.0.0.1", 0))
-- another option:
-- create a TCP socket and bind it to the local host, at any port but make it available over the internet
-- local server = assert(socket.bind("*", 0))
-- i'm choosing to bind at a specific port and make it available over the internet
local server = assert(socket.bind("*", 51515))


-- for testing, use these two commands:
local ip, port = server:getsockname()
print(string.format("telnet %s %s", ip, port))

local running = 1

local function stop(sig)
    running = 0
    return 0
end

-- Interrupt
signal.signal(signal.SIGINT, stop)


while 1 == running do

    -- wait for a connection from any client
    local client = server:accept()

    -- make sure we don't block waiting for this client's line.
    -- timeout and close connection after 20 seconds of inactivity.
    client:settimeout(20)

    -- receive the line
    local msg, err = client:receive()

    if err then
        client:send("an error occurred: " .. err .. "\n")
    elseif msg == nil or string.len(msg) < 1 then
        client:send("nothing sent.\n")
    elseif msg ~= "stop" then
        -- print(string.format("received: %s", msg))
        -- client:send("server received: " .. msg .. "\n")
        -- client:send("server received info\n")
        client:send(_process_request(msg) .. "\n")
    end

    -- client:close()

    if msg == "stop" then
        stop()
    end

end

print("ending ...")
server:close()

