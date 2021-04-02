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
    propsSet           = nil,  -- property settings (model)
    propsVal           = {},   -- property values
    propsValSrcPreview = nil,  -- property values (source scene of preview)
    propsValSrcProgram = nil,  -- property values (source scene of program)
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
        scene names visible in the Preview and Program channels into
        pre-defined corresponding Text/GDI+ text sources. These sources
        are usually part of an (invisible) scene which is either part
        of a locally shown OBS Studio Multiview or Projector or is
        broacasted via an attached "Dedicated NDI Output" filter to
        foreign monitors. In all cases, the intention is to globally
        show the current scene information to all involved people during
        a production session.
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
    ctx.propsValSrcPreview = nil
    ctx.propsValSrcProgram = nil
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
end

--  script hook: update state from UI properties
function script_update (settings)
    --  remember settings
    ctx.propsSet = settings

    --  fetch property values
	ctx.propsVal.textSourceNamePreview = obs.obs_data_get_string(settings, "textSourceNamePreview")
	ctx.propsVal.textSourceNameProgram = obs.obs_data_get_string(settings, "textSourceNameProgram")
end

--  update targets
function update_targets ()
    --  determine current scene in preview
	local previewSceneSource = obs.obs_frontend_get_current_preview_scene()
	local previewSceneName   = obs.obs_source_get_name(previewSceneSource)
	obs.obs_source_release(previewSceneSource)
    obs.script_log(obs.LOG_INFO, "update: current Preview scene name: \"" .. previewSceneName .. "\"")

    --  determine current scene in program
	local programSceneSource = obs.obs_frontend_get_current_scene()
	local programSceneName   = obs.obs_source_get_name(programSceneSource)
	obs.obs_source_release(programSceneSource)
    obs.script_log(obs.LOG_INFO, "update: current Program scene name: \"" .. previewSceneName .. "\"")

    --  update a single target text source
    function updateTextSource (name, text)
        local source = obs.obs_get_source_by_name(name)
        if source ~= nil then
            obs.script_log(obs.LOG_INFO, "update: change Text source: \"" .. name .. "\"")
            local settings = obs.obs_source_get_settings(source)
            obs.obs_data_set_string(settings, "text", text)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end

    --  update target text sources
    updateTextSource(ctx.propsVal.textSourceNamePreview, previewSceneName)
    updateTextSource(ctx.propsVal.textSourceNameProgram, programSceneName)
end

--  script hook: on script load
function script_load (settings)
    obs.obs_frontend_add_event_callback(function (event)
        if event == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then
            updateTextSources()
        elseif event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
            update_targets()
        elseif event == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then
            update_targets()
        end
        return true
    end)
end

