--[[
**
**  production-information.lua -- OBS Studio Lua Script for Production Information
**  Copyright (c) 2021 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  global OBS API
local obs = obslua

--  global context information
local ctx = {
    --  properties
    propsDef            = nil,   -- property definition
    propsDefSrcPreview  = nil,   -- property definition (source scene of preview)
    propsDefSrcProgram  = nil,   -- property definition (source scene of program)
    propsDefSrcTime     = nil,   -- property definition (source scene of time)
    propsDefSrcDuration = nil,   -- property definition (source scene of duration)
    propsSet            = nil,   -- property settings (model)
    propsVal            = {},    -- property values
    propsValSrcPreview  = nil,   -- property values (source scene of preview)
    propsValSrcProgram  = nil,   -- property values (source scene of program)
    propsValSrcTime     = nil,   -- property values (source scene of time)
    propsValSrcDuration = nil,   -- property values (source scene of duration)

    -- duration timer
	timerStart          = 0,     -- timer start (in nannoseconds)
	timerPaused         = false, -- timer paused flag
	timerPausedSecs     = 0,     -- timer paused time (in seconds)

    -- hotkey registration
    hotkeyIdPause       = obs.OBS_INVALID_HOTKEY_ID,
    hotkeyIdReset       = obs.OBS_INVALID_HOTKEY_ID
}

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Production Information</h2>

        Copyright &copy; 2021 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Render production information into corresponding text sources.</b>

        <p>
        This is a small OBS Studio script for rendering the current
        scene name visible in the Preview and Program channels, the
        current wallclock time and the current on-air duration time into
        pre-defined corresponding Text/GDI+ text sources. These text
        sources are usually part of a (hidden) scene which is either
        just part of a locally shown OBS Studio Multiview or Projector
        or is broadcasted via an attached "Dedicated NDI Output" filter
        to foreign monitors. In all cases, the intention is to globally
        show current production information to the involved people
        during a production session.
    ]]
end

--  helper function: update text source properties
local function updateTextSources ()
    --  clear already initialized property lists
    if ctx.propsDefSrcPreview ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcPreview)
    end
    if ctx.propsDefSrcProgram ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcProgram)
    end
    if ctx.propsDefSrcTime ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcTime)
    end
    if ctx.propsDefSrcDuration ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcDuration)
    end

    --  clear all selected propety values
    ctx.propsValSrcPreview  = nil
    ctx.propsValSrcProgram  = nil
    ctx.propsValSrcTime     = nil
    ctx.propsValSrcDuration = nil

    --  iterate over all text sources...
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                --  ...and fetch their source names
                local name = obs.obs_source_get_name(source)

                --  add source to preview text source selection list
                --  and initialize selected value
                if ctx.propsDefSrcPreview ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcPreview, name, name)
                end
                if ctx.propsValSrcPreview == nil then
                    ctx.propsValSrcPreview = name
                end

                --  add source to program text source selection list
                --  and initialize selected value
                if ctx.propsDefSrcProgram ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcProgram, name, name)
                end
                if ctx.propsValSrcProgram == nil then
                    ctx.propsValSrcProgram = name
                end

                --  add source to time text source selection list
                --  and initialize selected value
                if ctx.propsDefSrcTime ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcTime, name, name)
                end
                if ctx.propsValSrcTime == nil then
                    ctx.propsValSrcTime = name
                end

                --  add source to duration text source selection list
                --  and initialize selected value
                if ctx.propsDefSrcDuration ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcDuration, name, name)
                end
                if ctx.propsValSrcDuration == nil then
                    ctx.propsValSrcDuration = name
                end
			end
		end
	end
	obs.source_list_release(sources)
end

--  helper function for duration pause
local function durationPause ()
    ctx.timerPaused = not ctx.timerPaused
end

--  helper function for duration reset
local function durationReset ()
    ctx.timerStart      = obs.os_gettime_ns()
    ctx.timerPausedSecs = 0
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()

    --  create selection fields
    ctx.propsDefSrcPreview = obs.obs_properties_add_list(props,
        "textSourceNamePreview", "Preview-Name Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    ctx.propsDefSrcProgram = obs.obs_properties_add_list(props,
        "textSourceNameProgram", "Program-Name Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    ctx.propsDefSrcTime = obs.obs_properties_add_list(props,
        "textSourceNameTime", "Wallclock-Time Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    ctx.propsDefSrcDuration = obs.obs_properties_add_list(props,
        "textSourceNameDuration", "Duration-Time Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    updateTextSources()

    --  create buttons
	obs.obs_properties_add_button(props, "buttonStartStop", "Duration: Start/Stop", function ()
        durationPause()
	    return true
    end)
	obs.obs_properties_add_button(props, "buttonReset",     "Duration: Reset", function ()
        durationReset()
	    return true
    end)

    return props
end

--  script hook: define property defaults
function script_defaults (settings)
    --  update our text source list (for propsValSrcXXX below)
    updateTextSources()

    --  provide default values
    obs.obs_data_set_default_string(settings, "textSourceNamePreview",  ctx.propsValSrcPreview)
    obs.obs_data_set_default_string(settings, "textSourceNameProgram",  ctx.propsValSrcProgram)
    obs.obs_data_set_default_string(settings, "textSourceNameTime",     ctx.propsValSrcTime)
    obs.obs_data_set_default_string(settings, "textSourceNameDuration", ctx.propsValSrcDuration)
end

--  script hook: update state from UI properties
function script_update (settings)
    --  remember settings
    ctx.propsSet = settings

    --  fetch property values
	ctx.propsVal.textSourceNamePreview  = obs.obs_data_get_string(settings, "textSourceNamePreview")
	ctx.propsVal.textSourceNameProgram  = obs.obs_data_get_string(settings, "textSourceNameProgram")
	ctx.propsVal.textSourceNameTime     = obs.obs_data_get_string(settings, "textSourceNameTime")
	ctx.propsVal.textSourceNameDuration = obs.obs_data_get_string(settings, "textSourceNameDuration")
end

--  update a single target text source
local function updateTextSource (name, text)
    local source = obs.obs_get_source_by_name(name)
    if source ~= nil then
        local settings = obs.obs_source_get_settings(source)
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

--  update targets for scenes
local function updateTextSourcesScene ()
    --  determine current scene in preview and update text source
	local previewSceneSource = obs.obs_frontend_get_current_preview_scene()
	local previewSceneName   = obs.obs_source_get_name(previewSceneSource)
    updateTextSource(ctx.propsVal.textSourceNamePreview, previewSceneName)
	obs.obs_source_release(previewSceneSource)

    --  determine current scene in program and update text source
	local programSceneSource = obs.obs_frontend_get_current_scene()
	local programSceneName   = obs.obs_source_get_name(programSceneSource)
    updateTextSource(ctx.propsVal.textSourceNameProgram, programSceneName)
	obs.obs_source_release(programSceneSource)
end

--  update targets for time
local function updateTextSourcesTime ()
    --  determine current wallclock-time and update text source
	local time = os.date("%H:%M:%S")
    updateTextSource(ctx.propsVal.textSourceNameTime, time)

    --  determine current duration-time and update text source
    if ctx.timerPaused then
        ctx.timerPausedSecs = ctx.timerPausedSecs + 1
    end
    local timerEnd = obs.os_gettime_ns()
    local duration = math.floor((timerEnd - ctx.timerStart) / (1000 * 1000 * 1000)) - ctx.timerPausedSecs
    local hour = math.floor(duration / (60 * 60))
    duration = math.fmod(duration, 60 * 60)
    local min = math.floor(duration / 60)
    duration = math.fmod(duration, 60)
    local sec = duration
    local text = string.format("%02d:%02d:%02d", hour, min, sec)
    if ctx.timerPaused then
        text = text .. " *"
    end
    updateTextSource(ctx.propsVal.textSourceNameDuration, text)
end

--  script hook: on script load
function script_load (settings)
    --  define hotkeys
	ctx.hotkeyIdPause = obs.obs_hotkey_register_frontend("duration_pause",
        "Duration: Start/Stop", function (pressed)
        if pressed then
            durationPause()
        end
    end)
	ctx.hotkeyIdReset = obs.obs_hotkey_register_frontend("duration_reset",
        "Duration: Reset", function (pressed)
        if pressed then
            durationReset()
        end
    end)
	local hotkeyArrayPause = obs.obs_data_get_array(settings, "hotkey_pause")
	local hotkeyArrayReset = obs.obs_data_get_array(settings, "hotkey_reset")
	obs.obs_hotkey_load(ctx.hotkeyIdPause, hotkeyArrayPause)
	obs.obs_hotkey_load(ctx.hotkeyIdReset, hotkeyArrayReset)
	obs.obs_data_array_release(hotkeyArrayPause)
	obs.obs_data_array_release(hotkeyArrayReset)

    --  hook into the UI events
    obs.obs_frontend_add_event_callback(function (event)
        if event == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then
            updateTextSources()
        elseif event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
            updateTextSourcesScene()
        elseif event == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then
            updateTextSourcesScene()
        end
        return true
    end)

    --  start timer
    durationReset()
    obs.timer_add(updateTextSourcesTime, 1000)
end

--  script hook: on script save state
function script_save(settings)
    --  save hotkeys
	local hotkeyArrayPause = obs.obs_hotkey_save(ctx.hotkeyIdPause)
	local hotkeyArrayReset = obs.obs_hotkey_save(ctx.hotkeyIdReset)
	obs.obs_data_set_array(settings, "hotkey_pause", hotkeyArrayPause)
	obs.obs_data_set_array(settings, "hotkey_reset", hotkeyArrayReset)
	obs.obs_data_array_release(hotkeyArrayPause)
	obs.obs_data_array_release(hotkeyArrayReset)
end

