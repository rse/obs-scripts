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

    --  hotkey registration
    hotkeyIdEnforce     = obs.OBS_INVALID_HOTKEY_ID,

    --  flag for recursion prevention
    changingScenes      = false,
    changingTimer       = 0,

    --  timer for automatic enforcement
    enforceTimer        = 0
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

--  tick every 10ms for changing timer
local function changingTimerTick ()
    if ctx.changingTimer > 0 then
        ctx.changingTimer = ctx.changingTimer - 10
        if ctx.changingTimer <= 0 then
            ctx.changingTimer = 0
            obs.timer_remove(changingTimerTick)
            ctx.changingScenes = false
            obs.obs_frontend_add_event_callback(ctx.onFrontendEvent)
        end
    end
end

--  enforce certain scenes
local function enforceScenes (mode)
    obs.script_log(obs.LOG_INFO,
        string.format("[%s] enforce scenes: mode=%s", os.date("%Y-%m-%d %H:%M:%S"), mode))

    --  short-circuit processing in case of mutex
    if ctx.changingScenes then
        obs.script_log(obs.LOG_INFO,
            string.format("[%s] enforce scenes: mutex prevents operation", os.date("%Y-%m-%d %H:%M:%S")))
        return
    end

    --  optional delay on automatic enforcement
    if mode == "automatic" then
        local react = ctx.propsVal.flagReactAutomatic
        local delay = ctx.propsVal.numberDelayAutomatic
        if react then
            if delay == 0 then
                enforceScenes("timeout")
            elseif ctx.enforceTimer == 0 then
                ctx.enforceTimer = delay
            end
        end
        return
    end

    --  mutex initialization
    local mutex = false
    local function acquire ()
        if not mutex then
            mutex = true
            ctx.changingScenes = true
            obs.obs_frontend_remove_event_callback(ctx.onFrontendEvent)
        end
    end

    --  enforce program
    if ctx.propsVal.textSourceNameProgram ~= "none" then
        local programSceneSourceCurrent = obs.obs_frontend_get_current_scene()
        local programSceneSourceTarget  = obs.obs_get_source_by_name(ctx.propsVal.textSourceNameProgram)
        if programSceneSourceCurrent ~= programSceneSourceTarget then
            acquire()
            obs.script_log(obs.LOG_INFO,
                string.format("[%s] switching PROGRAM to scene \"%s\"",
                os.date("%Y-%m-%d %H:%M:%S"), ctx.propsVal.textSourceNameProgram))
            obs.obs_frontend_set_current_scene(programSceneSourceTarget)
        end
        obs.obs_source_release(programSceneSourceCurrent)
        obs.obs_source_release(programSceneSourceTarget)
    end

    --  enforce preview (studio mode only)
    if obs.obs_frontend_preview_program_mode_active() and ctx.propsVal.textSourceNamePreview ~= "none" then
        local previewSceneSourceCurrent = obs.obs_frontend_get_current_preview_scene()
        local previewSceneSourceTarget  = obs.obs_get_source_by_name(ctx.propsVal.textSourceNamePreview)
        if previewSceneSourceCurrent ~= previewSceneSourceTarget then
            acquire()
            obs.script_log(obs.LOG_INFO,
                string.format("[%s] switching PREVIEW to scene \"%s\"",
                os.date("%Y-%m-%d %H:%M:%S"), ctx.propsVal.textSourceNamePreview))
            obs.obs_frontend_set_current_preview_scene(previewSceneSourceTarget)
        end
        obs.obs_source_release(previewSceneSourceCurrent)
        obs.obs_source_release(previewSceneSourceTarget)
    end

    --  handle mutex
    if mutex then
        ctx.changingTimer = 250
        obs.timer_add(changingTimerTick, 10)
    end
end

--  tick every 100ms for enforce timer
local function enforceTimerTick ()
    if ctx.enforceTimer > 0 then
        ctx.enforceTimer = ctx.enforceTimer - 100
        if ctx.enforceTimer <= 0 then
            ctx.enforceTimer = 0
            enforceScenes("timeout")
        end
    end
end

--  react on OBS Studio frontend events
ctx.onFrontendEvent = function (event)
    if event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
        enforceScenes("automatic")
    elseif event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        enforceScenes("automatic")
    elseif event == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then
        enforceScenes("automatic")
    elseif event == obs.OBS_FRONTEND_EVENT_STUDIO_MODE_ENABLED then
        if ctx.propsDefSrcPreview ~= nil then
            obs.obs_property_set_enabled(ctx.propsDefSrcPreview, true)
            obs.obs_properties_apply_settings(ctx.propsDef, ctx.propsSet)
        end
        enforceScenes("automatic")
    elseif event == obs.OBS_FRONTEND_EVENT_STUDIO_MODE_DISABLED then
        if ctx.propsDefSrcPreview ~= nil then
            obs.obs_property_set_enabled(ctx.propsDefSrcPreview, false)
            obs.obs_properties_apply_settings(ctx.propsDef, ctx.propsSet)
        end
        enforceScenes("automatic")
    elseif event == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then
        updateTextSources()
    end
    return true
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
        This is a small OBS Studio Lua script for enforcing certain scenes
        to be always in preview and program.
    ]]
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()
    ctx.propsDef = props

    --  create scene selection fields
    ctx.propsDefSrcPreview = obs.obs_properties_add_list(props,
        "textSourceNamePreview", "Preview Scene (Studio Mode only)",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    if obs.obs_frontend_preview_program_mode_active() then
        obs.obs_property_set_enabled(ctx.propsDefSrcPreview, true)
    else
        obs.obs_property_set_enabled(ctx.propsDefSrcPreview, false)
    end
    ctx.propsDefSrcProgram = obs.obs_properties_add_list(props,
        "textSourceNameProgram", "Program Scene",
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    updateTextSources()

    --  create boolean flag
    ctx.propsDefFlagReactAutomatic = obs.obs_properties_add_bool(props,
        "flagReactAutomatic", "Automatically enforce on any scene changes")

    --  create text field
    ctx.propsDefDelayAutomatic = obs.obs_properties_add_int(props,
        "numberDelayAutomatic", "Automatic enforcement delay (ms)", 0, 60 * 1000, 100)

    --  create button
    obs.obs_properties_add_button(props, "buttonEnforce", "Enforce Scenes Once", function ()
        enforceScenes("manual")
        return true
    end)

    obs.obs_properties_apply_settings(ctx.propsDef, ctx.propsSet)
    return props
end

--  script hook: define property defaults
function script_defaults (settings)
    obs.script_log(obs.LOG_INFO, string.format("[%s] initialize configuration", os.date("%Y-%m-%d %H:%M:%S")))

    --  provide default values
    obs.obs_data_set_default_string(settings, "textSourceNamePreview", "none")
    obs.obs_data_set_default_string(settings, "textSourceNameProgram", "none")
    obs.obs_data_set_default_bool(settings,   "flagReactAutomatic",    false)
    obs.obs_data_set_default_int(settings,    "numberDelayAutomatic",  10 * 1000)
end

--  script hook: update state from UI properties
function script_update (settings)
    --  remember settings
    ctx.propsSet = settings

    --  fetch property values
    ctx.propsVal.textSourceNamePreview  = obs.obs_data_get_string(settings, "textSourceNamePreview")
    ctx.propsVal.textSourceNameProgram  = obs.obs_data_get_string(settings, "textSourceNameProgram")
    ctx.propsVal.flagReactAutomatic     = obs.obs_data_get_bool(settings,   "flagReactAutomatic")
    ctx.propsVal.numberDelayAutomatic   = obs.obs_data_get_int(settings,    "numberDelayAutomatic")

    --  log the current configuration
    local automatic = "no"
    if ctx.propsVal.flagReactAutomatic then
        automatic = "yes"
        enforceScenes("automatic")
    end
    obs.script_log(obs.LOG_INFO,
        string.format("[%s] update configuration: preview=%s program=%s automatic=%s delay=%d",
        os.date("%Y-%m-%d %H:%M:%S"),
        ctx.propsVal.textSourceNamePreview, ctx.propsVal.textSourceNameProgram,
        automatic, ctx.propsVal.numberDelayAutomatic))
end

--  script hook: on script load
function script_load (settings)
    --  define hotkeys
    ctx.hotkeyIdEnforce = obs.obs_hotkey_register_frontend("enforce_scenes",
        "Enforce Scenes Once", function (pressed)
        if pressed then
            enforceScenes("manual")
        end
    end)
    local hotkeyArrayEnforce = obs.obs_data_get_array(settings, "enforce_scenes_array")
    obs.obs_hotkey_load(ctx.hotkeyIdEnforce, hotkeyArrayEnforce)
    obs.obs_data_array_release(hotkeyArrayEnforce)

    --  hook into the UI events
    obs.obs_frontend_add_event_callback(ctx.onFrontendEvent)

    --  start enforce timer ticker
    obs.timer_add(enforceTimerTick, 100)
end

--  script hook: on script unlod
function script_unload (settings)
    --  stop enforce timer ticker
    obs.timer_remove(enforceTimerTick)
end

--  script hook: on script save state
function script_save(settings)
    --  save hotkeys
    local hotkeyArrayEnforce = obs.obs_hotkey_save(ctx.hotkeyIdEnforce)
    obs.obs_data_set_array(settings, "enforce_scenes_array", hotkeyArrayEnforce)
    obs.obs_data_array_release(hotkeyArrayEnforce)
end

