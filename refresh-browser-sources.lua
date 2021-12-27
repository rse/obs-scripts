--[[
**
**  refresh-browser-sources.lua -- OBS Studio Lua Script for Refreshing Browser Sources
**  Copyright (c) 2021 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Refresh Browser Sources</h2>

        Copyright &copy; 2021 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Refresh all <i>Browser Source</i> sources.</b>
    ]]
end

--  global OBS API
local obs = obslua

--  global context information
local ctx = {
    hotkey = obs.OBS_INVALID_HOTKEY_ID
}

--  helper function: refresh all browser sources
local function refreshBrowsers ()
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "browser_source" then
                --  fetch settings
                local settings = obs.obs_source_get_settings(source)

                --  touch CSS settings to force a refresh
                --  (technically we append/remove a trailing whitespace only)
                local css = obs.obs_data_get_string(settings, "css")
                if string.match(css, " $") then
                    css = string.gsub(css, " $", "")
                else
                    css = css .. " "
                end
                obs.obs_data_set_string(settings, "css", css)

                --  update sources
                obs.obs_source_update(source, settings)

                --  release settings
                obs.obs_data_release(settings)
            end
        end
    end
    obs.source_list_release(sources)
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()
    obs.obs_properties_add_button(props, "refresh_browsers",
        "Refresh All Browser Sources", refreshBrowsers)
    return props
end

--  script hook: on script load
function script_load (settings)
    ctx.hotkey = obs.obs_hotkey_register_frontend(
        "refresh_browsers.trigger", "Refresh all browsers",
        function (pressed)
            if not pressed then
                return
            end
            refreshBrowsers()
        end
    )
    local hotkey_save_array = obs.obs_data_get_array(settings,
        "refresh_browsers.trigger")
    obs.obs_hotkey_load(ctx.hotkey, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

--  script hook: on script save
function script_save (settings)
    local hotkey_save_array = obs.obs_hotkey_save(ctx.hotkey)
    obs.obs_data_set_array(settings,
        "refresh_browsers.trigger", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

