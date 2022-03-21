--[[
**
**  refresh-browser-sources.lua -- OBS Studio Lua Script for Refreshing Browser Sources
**  Copyright (c) 2021-2022 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

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
                --  trigger the refresh functionality through its "RefreshNoCache" button property
                local properties = obs.obs_source_properties(source)
                local property = obs.obs_properties_get(properties, "refreshnocache")
                obs.obs_property_button_clicked(property, source)
                obs.obs_properties_destroy(properties)
            end
        end
    end
    obs.source_list_release(sources)
end

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Refresh Browser Sources</h2>

        Copyright &copy; 2021-2022 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        Refresh all <i>Browser Source</i> sources. Either press the
        button below or assign a hotkey under <i>Settings / Hotkeys</i>
        to the global action <i>Refresh all browsers</i>. An alternative
        would be to assign the hotkey to all scene actions named
        "Refresh page of current page".
    ]]
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

