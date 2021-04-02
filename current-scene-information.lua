--[[
**
**  current-scene-information.lua -- OBS Studio Lua Script for Current Scene Information
**  Copyright (c) 2021 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  global OBS API
local obs = obslua

--  global context information
local ctx = {
    propsDef           = nil,  -- property definition
    propsDefSrcPreview = nil,  -- property definition (source scene of preview)
    propsDefSrcProgram = nil,  -- property definition (source scene of program)
    propsDefSrcTime    = nil,  -- property definition (source scene of time)
    propsSet           = nil,  -- property settings (model)
    propsVal           = {},   -- property values
    propsValSrcPreview = nil,  -- property values (source scene of preview)
    propsValSrcProgram = nil,  -- property values (source scene of program)
    propsValSrcTime    = nil,  -- property values (source scene of time)
}

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Current Scene Information</h2>

        Copyright &copy; 2021 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Render current Preview and Program scene names into corresponding text sources.</b>

        <p>
        This is a small OBS Studio script for rendering the current
        scene names visible in the Preview and Program channels and
        the current wall-clock time into pre-defined corresponding
        Text/GDI+ text sources. These text sources are usually part of
        an (invisible) scene which is either part of a locally shown OBS
        Studio Multiview or Projector or is broacasted via an attached
        "Dedicated NDI Output" filter to foreign monitors. In all
        cases, the intention is to globally show the current production
        information to all involved people during a production session.
    ]]
end

--  helper function: update text source properties
function updateTextSources ()
    if ctx.propsDefSrcPreview ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcPreview)
    end
    if ctx.propsDefSrcProgram ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcProgram)
    end
    if ctx.propsDefSrcTime ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcTime)
    end
    ctx.propsValSrcPreview = nil
    ctx.propsValSrcProgram = nil
    ctx.propsValSrcTime    = nil
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                local name = obs.obs_source_get_name(source)
                if ctx.propsDefSrcPreview ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcPreview, name, name)
                end
                if ctx.propsValSrcPreview == nil then
                    ctx.propsValSrcPreview = name
                end
                if ctx.propsDefSrcProgram ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcProgram, name, name)
                end
                if ctx.propsValSrcProgram == nil then
                    ctx.propsValSrcProgram = name
                end
                if ctx.propsDefSrcTime ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcTime, name, name)
                end
                if ctx.propsValSrcTime == nil then
                    ctx.propsValSrcTime = name
                end
			end
		end
	end
	obs.source_list_release(sources)
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()

    --  create two inputs
    ctx.propsDefSrcPreview = obs.obs_properties_add_list(props,
        "textSourceNamePreview", "Preview-Name Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    ctx.propsDefSrcProgram = obs.obs_properties_add_list(props,
        "textSourceNameProgram", "Program-Name Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    ctx.propsDefSrcTime = obs.obs_properties_add_list(props,
        "textSourceNameTime", "Wall-Clock Time Text-Source",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    updateTextSources()

    return props
end

--  script hook: define property defaults
function script_defaults (settings)
    --  update our text source list (for propsValSrcXXX below)
    updateTextSources()

    --  provide default values
    obs.obs_data_set_default_string(settings, "textSourceNamePreview", ctx.propsValSrcPreview)
    obs.obs_data_set_default_string(settings, "textSourceNameProgram", ctx.propsValSrcProgram)
    obs.obs_data_set_default_string(settings, "textSourceNameTime",    ctx.propsValSrcTime)
end

--  script hook: update state from UI properties
function script_update (settings)
    --  remember settings
    ctx.propsSet = settings

    --  fetch property values
	ctx.propsVal.textSourceNamePreview = obs.obs_data_get_string(settings, "textSourceNamePreview")
	ctx.propsVal.textSourceNameProgram = obs.obs_data_get_string(settings, "textSourceNameProgram")
	ctx.propsVal.textSourceNameTime    = obs.obs_data_get_string(settings, "textSourceNameTime")
end

--  update a single target text source
function updateTextSource (name, text)
    local source = obs.obs_get_source_by_name(name)
    if source ~= nil then
        obs.script_log(obs.LOG_INFO, "update: change Text source \"" .. name .. "\" to \"" .. text .. "\"")
        local settings = obs.obs_source_get_settings(source)
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

--  update targets for scenes
function updateTextSourcesScene ()
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
function updateTextSourcesTime ()
	local text = os.date("%H:%M:%S")
    updateTextSource(ctx.propsVal.textSourceNameTime, text)
end

--  script hook: on script load
function script_load (settings)
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

    --  start 1s timer
    obs.timer_add(updateTextSourcesTime, 1000)
end

--  script hook: on script unload
function script_unload ()
    --  stop 1s timer
    obs.timer_remove(updateTextSourcesTime)
end

