--[[
**
**  clone-template-scene.lua -- OBS Studio Lua Script for Cloning Template Scene
**  Copyright (c) 2021 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  global OBS API
local obs = obslua

--  global context information
local ctx = {
    propsDef    = nil,  -- property definition
    propsDefSrc = nil,  -- property definition (source scene)
    propsSet    = nil,  -- property settings (model)
    propsVal    = {},   -- property values
    propsValSrc = nil,  -- property values (first source scene)
}

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Clone Template Scene</h2>

        Copyright &copy; 2021 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Clone an entire source scene (template), by creating a target
        scene (clone) and copying all corresponding sources, including
        their filters, transforms, etc.</b>

        <p>
        <u>Notice:</u> The same kind of cloning <i>cannot</i> to be achieved
        manually, as the scene <i>Duplicate</i> and the source
        <i>Copy</i> functions create references for many source types
        only and especially do not clone applied transforms. The only
        alternative is the tedious process of creating a new scene,
        step-by-step copying and pasting all sources and then also
        step-by-step copying and pasting all source transforms.

        <p>
        <u>Prerequisite:</u> This script assumes that the source
        scene is named <tt>XXX</tt> (e.g. <tt>Template-01</tt>),
        all of its sources are named <tt>XXX-ZZZ</tt> (e.g.
        <tt>Template-01-Placeholder-02</tt>), the target scene is
        named <tt>YYY</tt> (e.g. <tt>Scene-03</tt>) and all of
        its sources are consequently named <tt>YYY-ZZZ</tt> (e.g.
        <tt>Scene-03-Placeholder-02</tt>).
    ]]
end

--  helper function: update source scenes property
function updateSourceScenes ()
    if ctx.propsDefSrc == nil then
        return
    end
    obs.obs_property_list_clear(ctx.propsDefSrc)
    local scenes = obs.obs_frontend_get_scenes()
    if scenes == nil then
        return
    end
    ctx.propsValSrc = nil
    for i, scene in ipairs(scenes) do
        local n = obs.obs_source_get_name(scene)
        obs.obs_property_list_add_string(ctx.propsDefSrc, n, n)
        ctx.propsValSrc = n
    end
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    ctx.propsDef = obs.obs_properties_create()

    --  create source scene list
    ctx.propsDefSrc = obs.obs_properties_add_list(ctx.propsDef,
        "sourceScene", "Source Scene (Template):",
        obs.OBS_COMBO_TYPE_LIST, obslua.OBS_COMBO_FORMAT_STRING)
    updateSourceScenes()

    --  create target scene field
    obs.obs_properties_add_text(ctx.propsDef, "targetScene",
        "Target Scene (Clone):", obs.OBS_TEXT_DEFAULT)

    --  create clone button
    obs.obs_properties_add_button(ctx.propsDef, "clone",
        "Clone Template Scene", doClone)

    --  create status field (read-only)
    local status = obs.obs_properties_add_text(ctx.propsDef, "statusMessage",
        "Status Message:", obs.OBS_TEXT_MULTILINE)
    obs.obs_property_set_enabled(status, false)

    --  apply values to definitions
    obs.obs_properties_apply_settings(ctx.propsDef, ctx.propsSet)
    return ctx.propsDef
end

--  script hook: define property defaults
function script_defaults (settings)
    --  update our source scene list (for propsValSrc below)
    updateSourceScenes()

    --  provide default values
    obs.obs_data_set_default_string(settings, "sourceScene",   ctx.propsValSrc)
    obs.obs_data_set_default_string(settings, "targetScene",   "Scene-01")
    obs.obs_data_set_default_string(settings, "statusMessage", "")
end

--  script hook: property values were updated
function script_update (settings)
    --  remember settings
    ctx.propsSet = settings

    --  fetch property values
    ctx.propsVal.sourceScene   = obs.obs_data_get_string(settings, "sourceScene")
    ctx.propsVal.targetScene   = obs.obs_data_get_string(settings, "targetScene")
    ctx.propsVal.statusMessage = obs.obs_data_get_string(settings, "statusMessage")
end

--  react on script load
function script_load (settings)
    --  clear status message
    obs.obs_data_set_string(settings, "statusMessage", "")

    --  react on scene list changes
    obs.obs_frontend_add_event_callback(function (event)
        if event == obs.OBS_FRONTEND_EVENT_SCENE_LIST_CHANGED then
            --  update our source scene list
            updateSourceScenes()
        end
        return true
    end)
end

--  helper function: set status message
local function statusMessage (type, message)
    if type == "error" then
        obs.script_log(obs.LOG_INFO, message)
        obs.obs_data_set_string(ctx.propsSet, "statusMessage", string.format("ERROR: %s", message))
    else
        obs.script_log(obs.LOG_INFO, message)
        obs.obs_data_set_string(ctx.propsSet, "statusMessage", string.format("INFO: %s", message))
    end
    obs.obs_properties_apply_settings(ctx.propsDef, ctx.propsSet)
    return true
end

--  helper function: find scene by name
local function findSceneByName (name)
    local scenes = obs.obs_frontend_get_scenes()
    if scenes == nil then
        return nil
    end
    for i, scene in ipairs(scenes) do
        local n = obs.obs_source_get_name(scene)
        if n == name then
            -- obs.obs_frontend_source_list_free(scenes)
            return scene
        end
    end
    -- obs.obs_frontend_source_list_free(scenes)
    return nil
end

--  helper function: replace a string
local function stringReplace (str, from, to)
    local function regexEscape (s)
        return string.gsub(s, "[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
    end
    return string.gsub(str, regexEscape(from), to)
end

--  called for the actual cloning action
function doClone ()
    --  find source scene (template)
    local sourceScene = findSceneByName(ctx.propsVal.sourceScene)
    if sourceScene == nil then
        statusMessage("error", string.format("source scene \"%s\" not found!",
            ctx.propsVal.sourceScene))
        return true
    end

    --  find target scene (clone)
    local targetScene = findSceneByName(ctx.propsVal.targetScene)
    if targetScene ~= nil then
        statusMessage("error", string.format("target scene \"%s\" already exists!",
            ctx.propsVal.targetScene))
        return true
    end

    --  create target scene
    obs.script_log(obs.LOG_INFO, string.format("create: SCENE  \"%s\"",
        ctx.propsVal.targetScene))
    targetScene = obs.obs_scene_create(ctx.propsVal.targetScene)

    --  iterate over all source scene (template) sources
    local sourceSceneBase = obs.obs_scene_from_source(sourceScene)
    local sourceItems = obs.obs_scene_enum_items(sourceSceneBase)
    for i, sourceItem in ipairs(sourceItems) do
        local sourceSrc = obs.obs_sceneitem_get_source(sourceItem)

        --  determine source and destination name
        local sourceNameSrc = obs.obs_source_get_name(sourceSrc)
        local sourceNameDst = stringReplace(sourceNameSrc,
            ctx.propsVal.sourceScene, ctx.propsVal.targetScene)
        obs.script_log(obs.LOG_INFO, string.format("create: SOURCE \"%s/%s\"",
            ctx.propsVal.targetScene, sourceNameDst))

        --  create source
        local type = obs.obs_source_get_id(sourceSrc)
        local settings = obs.obs_source_get_settings(sourceSrc)
        local targetSource = obs.obs_source_create(type, sourceNameDst, settings, nil)

        --  add source to scene
        local targetItem = obs.obs_scene_add(targetScene, targetSource)

        --  copy source transforms
        local transform = obs.obs_transform_info()
        obs.obs_sceneitem_get_info(sourceItem, transform)
        obs.obs_sceneitem_set_info(targetItem, transform)

        --  copy source filters
        obs.obs_source_copy_filters(targetSource, sourceSrc)

        --  copy source volume
        local volume = obs.obs_source_get_volume(sourceSrc)
        obs.obs_source_set_volume(targetSource, volume)

        --  copy source muted state
        local muted = obs.obs_source_muted(sourceSrc)
        obs.obs_source_set_muted(targetSource, muted)

        --  copy source mixer state
        local mixers = obs.obs_source_get_audio_mixers(sourceSrc)
        obs.obs_source_set_audio_mixers(targetSource, mixers)

        --  copy source flags
        local flags = obs.obs_source_get_flags(sourceSrc)
        obs.obs_source_set_flags(targetSource, flags)

        --  copy source enabled state
        local enabled = obs.obs_source_enabled(sourceSrc)
        obs.obs_source_set_enabled(targetSource, enabled)

        --  copy source visible state
        local visible = obs.obs_sceneitem_visible(sourceItem)
        obs.obs_sceneitem_set_visible(targetItem, visible)

        --  copy source locked state
        local locked = obs.obs_sceneitem_locked(sourceItem)
        obs.obs_sceneitem_set_locked(targetItem, locked)

        --  release resources
        obs.obs_source_release(targetSource)
        obs.obs_data_release(settings)
    end

    --  release resources
    obs.obs_scene_release(targetScene)

    --  final hint
    statusMessage("info", string.format("scene \"%s\" successfully cloned to \"%s\".",
        ctx.propsVal.sourceScene, ctx.propsVal.targetScene))
    return true
end

