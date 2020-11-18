

local M = {}


local cjson  = require "cjson"
local rex     = require "rex_pcre"


-- local session = require "session"
local utils   = require "utils"
local rj      = require "returnjson"
local title   = require "title"
local config  = require "config"
local files   = require "files"
local session = require "session"



function M.update_post(hash)

    local logged_in_author_name = hash.author
    local session_id            = hash.session_id
    local rev                   = hash.rev
   
    if session.is_valid_login(logged_in_author_name, session_id, rev) == false then 
        return rj.report_error("400", "Unable to peform action.", "You are not logged in. ")
    else
           local original_slug   = hash.original_slug 
           local original_markup = hash.markup
           local markup = utils.trim_spaces(original_markup)
           if markup == nil or markup == "" then
               return rj.report_error("400", "Invalid post.", "You must enter text.")
           else
               local t = title.process(markup)
               if t.is_error then
                   return rj.report_error("400", "Error updating post.", t.error_message) -- diff from create
               else
                   local post_stats  = utils.calc_reading_time_and_word_count(markup) -- returns hash

                   local post_hash = {}
                   -- post_hash.pretty_date_time = os.date("%a, %b %d, %Y - %I:%M %p Z")
                     -- can assemble these two items into ISO 8601 format 2018-04-05T23:45:17Z
                   post_hash.created_date   = os.date("%Y-%m-%d") -- 2018-04-05 = year, month, day
                   post_hash.created_time   = os.date("%X") -- 23:45:17 in GMT
                   post_hash.title          = t.title
                   post_hash.slug           = t.slug
                   post_hash.post_type      = t.post_type
                   post_hash.reading_time   = post_stats.reading_time
                   post_hash.word_count     = post_stats.word_count 
                   post_hash.author         = config.get_value_for("author_name")
                   post_hash.original_slug  = original_slug -- diff from create
                   post_hash.action         = "update"

                   local tmp_diff_slug = rex.match(markup, "^<!--[ ]*slug[ ]*:[ ]*(.+)[ ]*-->", 1, "im")
                   if tmp_diff_slug ~= nil then
                       post_hash.slug = utils.trim_spaces(tmp_diff_slug)
                   end 
 
                   if original_slug ~= post_hash.slug then
                       return rj.report_error("400", "Invalid slug.", "New slug in update does not match original.")
                   end

                   local tmp_dir   = rex.match(markup, "^<!--[ ]*dir[ ]*:[ ]*(.+)[ ]*-->", 1, "im")
                   local tmp_dir_2 = rex.match(markup, "^```[ ]*dir[ ]*:[ ]*(.+)[ ]*", 1, "im")

                   if tmp_dir_2 ~= nil then
                       tmp_dir = tmp_dir_2
                   end

                   if tmp_dir ~= nil then
                       post_hash.dir = utils.trim_spaces(tmp_dir)
                       -- remove ending forward slash if it exists
                       if rex.match(post_hash.dir, "[/]$") ~= nil then
                           post_hash.dir = string.sub(post_hash.dir, 1, -2)
                       end
                       post_hash.location = config.get_value_for("home_page") .. "/" .. post_hash.dir .. "/" .. post_hash.slug .. ".gmi"   
                       post_hash.post_id        = post_hash.dir .. "/" .. original_slug 
                   else
                       post_hash.location = config.get_value_for("home_page") .. "/" .. post_hash.slug .. ".gmi"   
                       post_hash.post_id        = original_slug 
                   end

                  if post_hash.dir ~= nil and rex.match(post_hash.dir, "^[a-zA-Z0-9]") == nil then
                      return rj.report_error("400", "Invalid directory: [" .. post_hash.dir .. "]", "Directory structure must start with alpha-numeric.")
                  else

                      local rc_boolean = true
                      local returned_json_text = ""

                      rc_boolean, returned_json_text = files.output("update", post_hash, markup) -- diff from create

                      if rc_boolean == true then
                          return rj.success(post_hash)
                      else
                          return returned_json_text
                      end
                  end
               end
           end
        end 

end



return M
