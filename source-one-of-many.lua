--[[
**
**  source-one-of-many.lua -- OBS Studio Lua Script for Toggling One of Many Sources
**  Copyright (c) 2021-2022 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  global OBS API
local obs = obslua

--  global context information
local ctx = {
    settings = nil,
    set_visible = {}
}

--  send a trace message to the script log
local function script_log (level, msg)
    local time = os.date("%Y-%m-%d %X")
    obs.script_log(obs.LOG_INFO, string.format("%s [%s] %s\n", time, level, msg))
end

--  callback of "item_visible" handler (scene/source visibility changed)
local function cb_item_visible (calldata)
    --  determine current callback information
    local item    = obs.calldata_sceneitem(calldata, "item")
    local visible = obs.calldata_bool(calldata,      "visible")

    --  determine changed scene/source name
    local source = obs.obs_sceneitem_get_source(item)
    local sourceName = obs.obs_source_get_name(source)
    if visible then
        script_log("INFO", string.format("notice: source \"%s\" will be made visible (by OBS)", sourceName))
    else
        script_log("INFO", string.format("notice: source \"%s\" will be made non-visible (by OBS)", sourceName))
    end

    --  iterate over all scenes of scene/source
    local scene = obs.obs_sceneitem_get_scene(item)
    local sceneitems = obs.obs_scene_enum_items(scene)
    local found_other_visible = false
    for _, sceneitem in ipairs(sceneitems) do
        local itemsource = obs.obs_sceneitem_get_source(sceneitem)
        local name = obs.obs_source_get_name(itemsource)

        --  for another source which is visible...
        if sourceName ~= name and obs.obs_sceneitem_visible(sceneitem) then
            if visible then
                --  ...make it non-visible
                script_log("INFO", string.format("forcing source \"%s\" to be non-visible (by us)", name))
                obs.obs_sceneitem_set_visible(sceneitem, false)
            else
                --  ...or remember it is visible
                found_other_visible = true
            end
        end
    end
    obs.sceneitem_list_release(sceneitems)

    --  if a source is requested to be made non-visible and we have not
    --  found any other still visible source in the scene/group, make
    --  it visible again (but delay the toggling as the source is still
    --  just flagged to be made non-visible and is actually just to be
    --  made non-visible after this callback!)
    if not visible and not found_other_visible then
        script_log("INFO", string.format("forcing source \"%s\" to be visible again afterwards (by us)", sourceName))
        table.insert(ctx.set_visible, { item = item, delay = 10, visible = true })
    end
end

--  callback of "source_load" handler (called when a source is being loaded)
local function cb_source_load (calldata)
    --  skip operation of no global settings are available
    if ctx.settings == nil then
        return
    end

    --  determine current loaded source
    local source = obs.calldata_source(calldata, "source")
    local sn = obs.obs_source_get_name(source)

    --  (re)connect "item_visible" handler if one of our configured sources is loaded
    local sourceNames = obs.obs_data_get_array(ctx.settings, "sources")
    local sourceNamesCount = obs.obs_data_array_count(sourceNames)
    for i = 0, sourceNamesCount do
        local item = obs.obs_data_array_item(sourceNames, i)
        local sourceName = obs.obs_data_get_string(item, "value")
        if sn == sourceName then
            local sh = obs.obs_source_get_signal_handler(source)
            obs.signal_handler_disconnect(sh, "item_visible", cb_item_visible)
            obs.signal_handler_connect(sh,    "item_visible", cb_item_visible)
        end
        obs.obs_data_release(item)
    end
    obs.obs_data_array_release(sourceNames)
end

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Source One-of-Many</h2>

        Copyright &copy; 2021 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Toggle between one of many sources visible in a scene/group.
        If a source is made visible in a scene/group, all other sources
        are automatically made non-visible. The currently already
        visible source is made visible immediately again, if it is
        accidentally requested to be made non-visible. So, at each time,
        only one source is visible within the scene/group.</b>
    ]]
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()
    obs.obs_properties_add_editable_list(props, "sources", "Scenes/Groups",
        obs.OBS_EDITABLE_LIST_TYPE_STRINGS, nil, nil)
	return props
end

--  script hook: property values were updated
function script_update (settings)
    --  (re)connect "item_visible" handler on all configured sources
    local sourceNames = obs.obs_data_get_array(settings, "sources")
    local sourceNamesCount = obs.obs_data_array_count(sourceNames)
    for i = 0, sourceNamesCount do
        local item = obs.obs_data_array_item(sourceNames, i)
        local sourceName = obs.obs_data_get_string(item, "value")
        local source = obs.obs_get_source_by_name(sourceName)
        if source ~= nil then
            local sh = obs.obs_source_get_signal_handler(source)
            obs.signal_handler_disconnect(sh, "item_visible", cb_item_visible)
            obs.signal_handler_connect(sh,    "item_visible", cb_item_visible)
            obs.obs_source_release(source)
        end
        obs.obs_data_release(item)
    end
    obs.obs_data_array_release(sourceNames)
end

--  script hook: on script load
function script_load (settings)
    --  remember settings globally
    ctx.settings = settings

    --  hook into "source_load" handler
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_load", cb_source_load)
end

--  script hook: on script tick
function script_tick (seconds)
    local i = 1
    while i <= #ctx.set_visible do
        ctx.set_visible[i].delay = ctx.set_visible[i].delay - (seconds * 1000)
        if ctx.set_visible[i].delay <= 0 then
            obs.obs_sceneitem_set_visible(ctx.set_visible[i].item, ctx.set_visible[i].visible)
            table.remove(ctx.set_visible, i)
        else
            i = i + 1
        end
    end
end

