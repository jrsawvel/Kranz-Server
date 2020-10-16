

local M = {}


local rex   = require "rex_pcre"
local io    = require "io"
local cjson = require "cjson"
local pretty = require "resty.prettycjson"


local page      = require "page"
local config    = require "config"
local rj        = require "returnjson"
local utils     = require "utils"



function _save_markup_to_backup_directory(markup, hash)

    local tmp_post_id = hash.slug
    local tmp_slug    = hash.slug

    if hash.dir ~= nil then
        tmp_post_id = hash.dir .. "/" .. hash.slug
        tmp_slug = utils.clean_title(hash.dir) .. "-" .. tmp_slug
    end

    local previous_markup_version = M.read_markup_file(tmp_post_id)
    local epoch_secs = os.time()

    local markup_filename = config.get_value_for("versions_storage") .. "/" .. tmp_slug .. "-" .. epoch_secs .. "-version.gmi"

    local f = io.open(markup_filename, "w")
    if f == nil then
        -- return rj.report_error("500", "Unable to open backup file for write.", markup_filename)
        return false, {status = "500", user_message = "Unable to open backup file for write.", system_message = markup_filename}
    else
        f:write(previous_markup_version)
        f:close()
    end

    return true
end


function _create_hfeed_file(stream)

    local max_entries = config.get_value_for("max_entries")
    local mft_stream = {}

--    for i=1, max_entries and #stream do
    for i=1, max_entries do
        table.insert(mft_stream, stream[i])
    end


    page.set_template_name("hfeed")
    page.set_template_variable("site_name", config.get_value_for("site_name"))
    page.set_template_variable("site_description", config.get_value_for("site_description"))
    page.set_template_variable("article_loop", mft_stream)

    local hfeed_output = page.get_output("MicroFormats h-feed of h-entries")

    local hfeed_filename = config.get_value_for("default_doc_root") .. "/" .. config.get_value_for("hfeed_file")

    local o = io.open(hfeed_filename, "w")
    if o == nil then
        return rj.report_error("400", "Could not open h-feed file for write.", "")
    else
        o:write(hfeed_output .. "\n")
        o:close()
    end

    return true

end



function _create_atom_file(hash, stream)

    local max_entries = config.get_value_for("max_entries")
    local atom_hash = {}

    atom_hash.id              =  "gemini://sawv.org"
    atom_hash.title           =  config.get_value_for("site_name")
    atom_hash.updated         =  os.date("%Y-%m-%dT%XZ")
    atom_hash.linkalternate   =  "gemini://sawv.org/posts.gmi"
    atom_hash.linkself        =  "gemini://sawv.org/atom.xml"

    local entries = {}

    if max_entries > #stream then
        max_entries = #stream
    end

    for i=1, max_entries do
        local h = {}
        h.id    = stream[i].url
        h.title   = stream[i].title
        h.updated = stream[i].created
        h.link  = stream[i].url
        table.insert(entries, h)
    end

    atom_hash.entries = entries

    page.set_template_name("atom")

    page.set_template_variable("id",            atom_hash.id) 
    page.set_template_variable("title",         atom_hash.title)
    page.set_template_variable("updated",       atom_hash.updated)
    page.set_template_variable("linkalternate", atom_hash.linkalternate)
    page.set_template_variable("linkself",      atom_hash.linkself)
    page.set_template_variable("entries_loop",  atom_hash.entries)

    local atom_output = page.get_output_bare()

    local atom_feed_filename = config.get_value_for("default_doc_root") .. "/" .. config.get_value_for("atom_feed_file")

    local o = io.open(atom_feed_filename, "w")
    if o == nil then
        return rj.report_error("500", "Unable to open RSS3 feed file for write.", atom_feed_filename)
    else
        o:write(atom_output)
        o:close()
    end

    return true

end



-- Aaron Swartz's half-humorous and half-serious text-based spec from 2002, that I still like in 2018. 
-- http://www.aaronsw.com/2002/rss30

function _create_rss3_file(hash, stream)

    local max_entries = config.get_value_for("max_entries")
    local rss3_hash = {}

    rss3_hash.title          =  config.get_value_for("site_name")
    rss3_hash.description    =  config.get_value_for("site_description")
    rss3_hash.link           = "gemini://sawv.org/posts.gmi" 
--    rss3_hash.generator      =  config.get_value_for("app_name")
    rss3_hash.uri            =  "gemini://sawv.org/rss3.txt"
    rss3_hash.lastmodified   =  os.date("%Y-%m-%dT%XZ")

    local items = {}

    if max_entries > #stream then
        max_entries = #stream
    end

    for i=1, max_entries do
        local h = {}
        h.title   = stream[i].title
        h.link    = stream[i].url
        h.created = stream[i].created
        table.insert(items, h)
    end

    rss3_hash.items = items

    page.set_template_name("rss3")

    page.set_template_variable("title",       rss3_hash.title) 
    page.set_template_variable("description", rss3_hash.description)
    page.set_template_variable("link",        rss3_hash.link)
--    page.set_template_variable("generator",   rss3_hash.generator)
    page.set_template_variable("uri",         rss3_hash.uri)
    page.set_template_variable("lastmodified",rss3_hash.lastmodified)
    page.set_template_variable("items_loop",  rss3_hash.items)

    local rss3_output = page.get_output_bare()

    local rss3_feed_filename = config.get_value_for("default_doc_root") .. "/" .. config.get_value_for("rss3_feed_file")

    local o = io.open(rss3_feed_filename, "w")
    if o == nil then
        return rj.report_error("500", "Unable to open RSS3 feed file for write.", rss3_feed_filename)
    else
        o:write(rss3_output)
        o:close()
    end

    return true

end



function _update_links_json_file(hash)

    local filename = config.get_value_for("links_json_file_storage") .. "/" .. config.get_value_for("links_json_file")

    local json_text = ""

    local stream = {}

    local f = io.open(filename, "r")
    if f == nil then
        -- return rj.report_error("400", "Could not open links JSON file for read.", "")
        return false, {status = "400", user_message = "Could not open links JSON file for read.", system_message = ""}
    else
        for line in f:lines() do
            json_text = json_text .. line
        end

        local t = cjson.decode(json_text)

        stream = t.posts

        local tmp_hash = {
            title = hash.title,
            created = hash.created_date .. "T" .. hash.created_time .. "Z",
            author = hash.author 
        }

        -- doing some hard-coding here to make things simple for now. 
        -- maybe i'll set info as key-values in the yaml config file later.
        -- i'm using a web-based cms to create and update content for gemini.
        -- that means two different urls for the content.
        -- i want to the links.json file to point to the gemini url. i use this
        -- to create the atom feed for my gemini account.
        -- but i need working web urls for hfeed html page.

        if hash.dir ~= nil then
                 tmp_hash.url = "gemini://sawv.org" .. "/" .. hash.dir .. "/" .. hash.slug .. ".gmi"
            tmp_hash.hfeedurl = "http://gemini.soupmode.com" .. "/" .. hash.dir .. "/" .. hash.slug .. ".gmi"
        else
                 tmp_hash.url = "gemini://sawv.org" .. "/" .. hash.slug .. ".gmi"
            tmp_hash.hfeedurl = "http://gemini.soupmode.com" .. "/" .. hash.slug .. ".gmi"
        end

        table.insert(stream, 1, tmp_hash)

        t.posts = stream 

        json_text = pretty(t, "\n", "  ")

--        json_text = cjson.encode(t)

        local o = io.open(filename, "w")
        if o == nil then
            -- return rj.report_error("500", "Unable to open links JSON file for write.", filename)
            return false, {status = "500", user_message = "Unable to open links JSON file for write.", system_message = filename}
        else
            o:write(json_text .. "\n")
            o:close()
        end
    end

    return true, stream -- table of arrays of hashes for: title, author, created, and url.

end



function _save_markup_to_web_directory(markup, hash)

    local markup_filename

    if hash.dir ~= nil then
        markup_filename = config.get_value_for("default_doc_root") .. "/" .. hash.dir .. "/" .. hash.slug .. ".gmi"
        local dir_path = config.get_value_for("default_doc_root") .. "/" .. hash.dir
        local r = os.execute("mkdir -p " .. dir_path)
        if r == false then
            -- return rj.report_error("500", "Bad directory path.", "Could not create directory structure.")
            return false, {status = "500", user_message = "Bad directory path", system_message = "Could not create directory structure."}
        end
    else 
        markup_filename = config.get_value_for("default_doc_root") .. "/" .. hash.slug .. ".gmi"
    end
 
    if rex.match(markup_filename, "^[a-zA-Z0-9/%.%-_]+$") == nil then
        -- return rj.report_error("500", "Bad file name or directory path.", "Could not write markup for post id: " .. hash.title .. " filename: " .. markup_filename)
        return false, {status = "500", user_message = "Bad file name or directory path", system_message = "Could not write markup for post id: " .. hash.title .. " filename: " .. markup_filename}
    end

    local o = io.open(markup_filename, "w")
    if o == nil then
        -- return rj.report_error("500", "Saving Markup to Web Dir. Unable to open file for write.", "Post id: " .. hash.slug .. " filename: " .. markup_filename)
        return false, {status = "500", user_message = "Saving Markup to Web Dir. Unable to open file for write.", system_message = "Post id: " .. hash.slug .. " filename: " .. markup_filename}
    end

    o:write(markup .. "\n")
    o:close()

    return true

end


function _save_markup_to_storage_directory(submit_type, markup, hash)

    local save_markup = markup ..  "\n\n<!-- author_name: " .. config.get_value_for("author_name") .. " -->\n"
    save_markup = save_markup  ..  "<!-- published_date: "  .. hash.created_date .. " -->\n"
    save_markup = save_markup  ..  "<!-- published_time: "  .. hash.created_time .. " -->\n"

    local tmp_slug = hash.slug

    if hash.dir ~= nil then
        tmp_slug = utils.clean_title(hash.dir) .. "-" .. tmp_slug
    end 

    -- write markup to markup storage outside of document root
    -- if "create" then the file must not exist
    local domain_name = config.get_value_for("domain_name")
    local markup_filename = config.get_value_for("markup_storage") .. "/" .. domain_name .. "-" .. tmp_slug .. ".markup"

    if submit_type == "create" and io.open(markup_filename, "r") ~= nil then 
        -- return rj.report_error("400", "Unable to create markup and HTML files because they already exist.", "Change title or do an 'update'.")
        return false, {status = "400", user_message = "Unable to create markup and HTML files because they already exist.", system_message = "Change title or do an 'update'."}
    else
        local o = io.open(markup_filename, "w")
        if o == nil then
            -- return rj.report_error("500", "Save Markup to Storage Dir. Unable to open file for write.", "Post id: " .. hash.slug .. " filename: " .. markup_filename)
            return false, {status = "500", user_message = "Save Markup to Storage Dir: Unable to open file for write.", system_message = "Post id: " .. hash.slug .. " filename: " .. markup_filename}
        else
            o:write(save_markup .. "\n")
            o:close()
        end
    end

    return true

end



function M.output(submit_type, hash, markup)

    -- https://www.codetable.net/entitiesinhtml

    markup = string.gsub(markup, "%%u2013", "-")  -- en dash
    markup = string.gsub(markup, "%%u2014", "--") -- em dash
    markup = string.gsub(markup, "%%u2018", "'")  -- Left Single Quotation Mark
    markup = string.gsub(markup, "%%u2019", "'")  -- Right Single Quotation Mark
    markup = string.gsub(markup, "%%u201C", '"')  -- Left Double Quotation Mark
    markup = string.gsub(markup, "%%u201D", '"')  -- Right Double Quotation Mark
    markup = string.gsub(markup, "%%u2022", "*")  -- Bullet point
    markup = string.gsub(markup, "%%u2026", "...")  -- Horizontal ellipse

    markup = string.gsub(markup, "&#8211;", "-")  -- en dash
    markup = string.gsub(markup, "&#8212;", "--") -- em dash
    markup = string.gsub(markup, "&#8216;", "'")  -- Left Single Quotation Mark
    markup = string.gsub(markup, "&#8217;", "'")  -- Right Single Quotation Mark
    markup = string.gsub(markup, "&#8220;", '"')  -- Left Double Quotation Mark
    markup = string.gsub(markup, "&#8221;", '"')  -- Right Double Quotation Mark
    markup = string.gsub(markup, "&#8226;", "*")  -- Bullet point
    markup = string.gsub(markup, "&#8230;", "...")  -- Horizontal ellipse
    markup = string.gsub(markup, "&#9;", "    ") -- tab ?

    local error_status = true
    local error_messages = ""

--[[

    if hash.template ~= nil then
        page.set_template_name(hash.template)
    elseif hash.post_type == "article" then
        page.set_template_name("articlehtml")
    else
        page.set_template_name("notehtml")
    end

    page.set_template_variable("html", hash.html)
    page.set_template_variable("title", hash.title)
    page.set_template_variable("created_date", hash.created_date)
    page.set_template_variable("created_time", hash.created_time)
    page.set_template_variable("author", hash.author)
    page.set_template_variable("permalink", hash.location)

    if hash.custom_css ~= nil then
        page.set_template_variable("using_custom_css", true)
        page.set_template_variable("custom_css", hash.custom_css)
    end

    local html_output = page.get_output(hash.title)

    page.reset()
]]

    if submit_type == "update" then 
        hash.slug = hash.original_slug
    end

    error_status, error_messages = _save_markup_to_storage_directory(submit_type, markup, hash) 
    if error_status == false then
        return false, rj.report_error(error_messages.status, error_messages.user_message, error_messages.system_message)
    end

    if submit_type == "update" then
        error_status, error_messages = _save_markup_to_backup_directory(markup, hash)
        if error_status == false then
            return false, rj.report_error(error_messages.status, error_messages.user_message, error_messages.system_message)
        end
    end

    error_status, error_messages = _save_markup_to_web_directory(markup, hash) 
    if error_status == false then
        return false, rj.report_error(error_messages.status, error_messages.user_message, error_messages.system_message)
    end

    if submit_type == "create" then
        local error_status, stream = _update_links_json_file(hash)
        if error_status == false then
            return false, rj.report_error(stream.status, stream.user_message, stream.system_message)
        else
            return true
        end

--        if _create_hfeed_file(stream) == false then
--            return false
--        end
        -- _create_rss3_file(hash, stream)
        -- _create_atom_file(hash, stream)
    end

    return true

end



function M.read_markup_file(post_id)

    local markup = ""

    local markup_filename = config.get_value_for("default_doc_root") .. "/" .. post_id .. ".gmi"

    local f = io.open(markup_filename, "r")

    if f == nil then
        return "-999"
    else
        for line in f:lines() do
            markup = markup .. line .. "\n"
        end
        f:close()
    end

    return markup
end


return M
