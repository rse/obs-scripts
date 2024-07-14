--[[
**
**  enforce-current-scenes.lua -- OBS Studio Lua Script for Enforcing Preview/Program Scenes
**  Copyright (c) 2024 Dr. Ralf S. Engelschall <rse@engelschall.com>
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
    propsSet            = nil,   -- property settings (model)
    propsVal            = {},    -- property values
    propsValSrcPreview  = nil,   -- property values (source scene of preview)
    propsValSrcProgram  = nil,   -- property values (source scene of program)

    --  hotkey registration
    hotkeyIdEnforce     = obs.OBS_INVALID_HOTKEY_ID,

    --  flag for recursion prevention
    changingScenes      = false
}

--  helper function: update text source properties
local function updateTextSources ()
    --  clear already initialized property lists
    if ctx.propsDefSrcPreview ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcPreview)
        obs.obs_property_list_add_string(ctx.propsDefSrcPreview, "none", "none")
    end
    if ctx.propsDefSrcProgram ~= nil then
        obs.obs_property_list_clear(ctx.propsDefSrcProgram)
        obs.obs_property_list_add_string(ctx.propsDefSrcProgram, "none", "none")
    end

    --  clear all selected property values
    ctx.propsValSrcPreview = "none"
    ctx.propsValSrcProgram = "none"

    --  iterate over all sources...
	local scenes = obs.obs_frontend_get_scenes()
	if scenes ~= nil then
		for _, source in ipairs(scenes) do
            if obs.obs_source_get_type(source) == obs.OBS_SOURCE_TYPE_SCENE then
                --  ...and fetch their source names
                local name = obs.obs_source_get_name(source)

                --  add source to preview text source selection list
                if ctx.propsDefSrcPreview ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcPreview, name, name)
                end

                --  add source to program text source selection list
                if ctx.propsDefSrcProgram ~= nil then
                    obs.obs_property_list_add_string(ctx.propsDefSrcProgram, name, name)
                end
			end
		end
	end
	obs.source_list_release(scenes)
end

--  enforce certain scenes
local function enforceScenes ()
    if not ctx.changingScenes then
        --  enforce preview
        if ctx.propsVal.textSourceNamePreview ~= "none" then
            local previewSceneSourceCurrent = obs.obs_frontend_get_current_preview_scene()
            local previewSceneSourceTarget  = obs.obs_get_source_by_name(ctx.propsVal.textSourceNamePreview)
            if previewSceneSourceCurrent ~= previewSceneSourceTarget then
                ctx.changingScenes = true
                obs.obs_frontend_set_current_preview_scene(previewSceneSourceTarget)
                ctx.changingScenes = false
            end
            obs.obs_source_release(previewSceneSourceCurrent)
        end

        --  enforce program
        if ctx.propsVal.textSourceNameProgram ~= "none" then
            local programSceneSourceCurrent = obs.obs_frontend_get_current_scene()
            local programSceneSourceTarget  = obs.obs_get_source_by_name(ctx.propsVal.textSourceNameProgram)
            if programSceneSourceCurrent ~= programSceneSourceTarget then
                ctx.changingScenes = true
                obs.obs_frontend_set_current_scene(programSceneSourceTarget)
                ctx.changingScenes = false
            end
            obs.obs_source_release(programSceneSourceCurrent)
        end
    end
end

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Enforce Current Scenes</h2>

        Copyright &copy; 2024 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Enforce certain scences to be in preview/program.</b>

        <p>
        This is a small OBS Studio script for enforcing the current
        scenes in preview and program.
    ]]
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()

    --  create selection fields
    ctx.propsDefSrcPreview = obs.obs_properties_add_list(props,
        "textSourceNamePreview", "Preview Scene",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    ctx.propsDefSrcProgram = obs.obs_properties_add_list(props,
        "textSourceNameProgram", "Program Scene",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    updateTextSources()

    --  create buttons
	obs.obs_properties_add_button(props, "buttonEnforce", "Enforce Scenes", function ()
        enforceScenes()
	    return true
    end)

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
	ctx.propsVal.textSourceNamePreview  = obs.obs_data_get_string(settings, "textSourceNamePreview")
	ctx.propsVal.textSourceNameProgram  = obs.obs_data_get_string(settings, "textSourceNameProgram")
end

--  script hook: on script load
function script_load (settings)
    --  define hotkeys
	ctx.hotkeyIdEnforce = obs.obs_hotkey_register_frontend("enforce_scenes",
        "Enforce Scenes", function (pressed)
        if pressed then
            enforceScenes()
        end
    end)
	local hotkeyArrayEnforce = obs.obs_data_get_array(settings, "enforce_scenes_array")
	obs.obs_hotkey_load(ctx.hotkeyIdEnforce, hotkeyArrayEnforce)
	obs.obs_data_array_release(hotkeyArrayEnforce)

    --  hook into the UI events
    obs.obs_frontend_add_event_callback(function (event)
        if event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
            enforceScenes()
        elseif event == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then
            updateTextSources()
        elseif event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
            enforceScenes()
        elseif event == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then
            enforceScenes()
        end
        return true
    end)

    --  start timer
    obs.timer_add(enforceScenes, 10 * 1000)
end

--  script hook: on script save state
function script_save(settings)
    --  save hotkeys
	local hotkeyArrayEnforce = obs.obs_hotkey_save(ctx.hotkeyIdEnforce)
	obs.obs_data_set_array(settings, "enforce_scenes_array", hotkeyArrayEnforce)
	obs.obs_data_array_release(hotkeyArrayEnforce)
end

