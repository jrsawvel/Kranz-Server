

local M = {}


local files    = require "files"
local rj       = require "returnjson"
local session  = require "session"


function M.get_post(hash)

    local post_id     = hash.post_id
    local author_name = hash.author
    local session_id  = hash.session_id
    local rev         = hash.rev

    if session.is_valid_login(author_name, session_id, rev) == false then 
        return rj.report_error("400", "Unable to peform action.", "You are not logged in.")
    else

        local hash = {}
        hash.post_id = post_id
        hash.markup = files.read_markup_file(post_id)        
        if hash.markup ~= "-999" then
           return rj.success(hash)
        else
            return rj.report_error("400", "Could not open " .. post_id .. ".gmi for read.", "")
        end

    end

end



return M
