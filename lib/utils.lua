
-- module: utils.lua

local M = {}

local ltn12 = require "ltn12"
local http  = require "socket.http"
local rex   = require "rex_pcre"
local https = require "ssl.https"



function M.calc_reading_time_and_word_count(text)

    local hash = {}

    local dummy, n = text:gsub("%S+","") -- n = substitutions

    hash.word_count   = n or 0

    hash.reading_time = 0  -- minutes

    if hash.word_count >= 180 then
        hash.reading_time = math.floor(hash.word_count / 180) 
    end

    return hash

end



function M.clean_title(str)
    str = string.gsub(str, "-", "")
    str = string.gsub(str, " ", "-")
    str = string.gsub(str, ":", "-")
    str = rex.gsub(str, "--", "")
    str =  rex.gsub(str, "[^-a-zA-Z0-9]","")
    return string.lower(str)
end



function M.create_random_string(length) 

    -- https://gist.github.com/haggen/2fd643ea9a261fea2094

    local charset = {}  do -- [0-9a-zA-Z]
        for c = 48, 57  do table.insert(charset, string.char(c)) end
        for c = 65, 90  do table.insert(charset, string.char(c)) end
        for c = 97, 122 do table.insert(charset, string.char(c)) end
    end

    math.randomseed(os.time())

    if not length or length <= 0 then return '' end

    return M.create_random_string(length - 1) .. charset[math.random(1, #charset)]

end



-- https://stackoverflow.com/questions/19664666/check-if-a-string-isnt-nil-or-empty-in-lua
function M.is_empty(s)
  return s == nil or s == ''

--[[
    if s==nil or s=='' then
        return true
    else
        return false
    end
]]
end



function M.trim_spaces (str)
    if (str == nil) then
        return ""
    end
   
    -- remove leading spaces 
    str = string.gsub(str, "^%s+", "")

    -- remove trailing spaces.
    str = string.gsub(str, "%s+$", "")

    return str
end



function M.get_date_time()
-- time displayed for Toledo, Ohio (eastern time zone)
-- Thu, Jan 25, 2018 - 6:50 p.m.

    local time_type = "EDT"
    local epochsecs = os.time()
    local localsecs 
    local dt = os.date("*t", epochsecs)

    if ( dt.isdst ) then
        localsecs = epochsecs - (4 * 3600)
    else 
        localsecs = epochsecs - (5 * 3600)
        time_type = "EST"
    end

    -- damn hack - mar 11, 2018 - frigging isdst does not work as expected. it's always false.
    -- time_type = "EDT"
    -- localsecs = epochsecs - (4 * 3600)
    
    time_type = "GMT"

    -- local dt_str = os.date("%a, %b %d, %Y - %I:%M %p", localsecs)
    local dt_str = os.date("%a, %b %d, %Y - %I:%M %p", os.time())

    return(dt_str .. " " .. time_type)
end



function M.table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("[%s] => table\n", tostring (key)));
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("(\n");
        M.table_print (value, indent + 7, done)
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write(")\n");
      else
        io.write(string.format("[%s] => %s\n",
            tostring (key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end


function M.split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
         table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end


return M
