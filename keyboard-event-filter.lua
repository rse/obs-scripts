--[[
**
**  keyboard-event-filter.lua -- OBS Studio Lua Script for Keyboard Event Filter
**  Copyright (c) 2021-2022 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  global OBS API
local obs  = obslua
local bit  = require("bit")

--  create obs_source_info structure
local info = {}
info.id           = "keyboard_event_filter"
info.type         = obs.OBS_SOURCE_TYPE_FILTER
info.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

--  hook: provide name of filter
info.get_name = function ()
    return "Keyboard Event"
end

--  hook: provide default settings (initialization before create)
info.get_defaults = function (settings)
    --  provide an empty list of keyboard events
    local events = obs.obs_data_get_array(settings, "keyboard_events")
    if not events then
        events = obs.obs_data_array_create()
        obs.obs_data_set_array(settings, "keyboard_events", events)
    end
end

--  hook: create filter context
info.create = function (_settings, source)
    --  create new filter context object
    local filter = {}
    filter.source = source
    filter.parent = nil
    filter.width  = 0
    filter.height = 0
    filter.name = obs.obs_source_get_name(source)
    filter.cfg = {
        nn2kb = {},  --  property index to keyboard event (2 -> "CTRL+a")
        kb2id = {},  --  keyboard event to unique id      ("CTRL+a" -> "Keyboard Event: CTRL+a")
        id2hk = {},  --  unique id to hotkey number       ("Keyboard Event: CTRL+a" -> 47)
        id2cb = {}   --  unique id to callback function   ("Keyboard Event: CTRL+a" -> function...)
    }
    obs.script_log(obs.LOG_INFO, string.format("create: filter name: \"%s\"", filter.name))
    return filter
end

--  hook: destroy filter context
info.destroy = function (filter)
    --  free resources only (notice: no more logging possible)
    filter.source = nil
    filter.name   = nil
    filter.cfg    = nil
end

--  standard keys
local table_keys = {
    { key = "ESCAPE",    id = "OBS_KEY_ESCAPE",       mod = "" },
    { key = "INSERT",    id = "OBS_KEY_INSERT",       mod = "" },
    { key = "BACKSPACE", id = "OBS_KEY_BACKSPACE",    mod = "" },
    { key = "DELETE",    id = "OBS_KEY_DELETE",       mod = "" },
    { key = "RETURN",    id = "OBS_KEY_RETURN",       mod = "" },
    { key = "TAB",       id = "OBS_KEY_TAB",          mod = "" },
    { key = "END",       id = "OBS_KEY_END",          mod = "" },
    { key = "UP",        id = "OBS_KEY_UP",           mod = "" },
    { key = "DOWN",      id = "OBS_KEY_DOWN",         mod = "" },
    { key = "LEFT",      id = "OBS_KEY_LEFT",         mod = "" },
    { key = "RIGHT",     id = "OBS_KEY_RIGHT",        mod = "" },
    { key = "HOME",      id = "OBS_KEY_HOME",         mod = "" },
    { key = "PAGEUP",    id = "OBS_KEY_PAGEUP",       mod = "" },
    { key = "PAGEDOWN",  id = "OBS_KEY_PAGEDOWN",     mod = "" },
    { key = "^",         id = "OBS_KEY_ASCIICIRCUM",  mod = "" },
    { key = "~",         id = "OBS_KEY_ASCIITILDE",   mod = "" },
    { key = "`",         id = "OBS_KEY_FIXME",        mod = "" },
    { key = "´",         id = "OBS_KEY_FIXME",        mod = "" },
    { key = ",",         id = "OBS_KEY_COMMA",        mod = "" },
    { key = "=",         id = "OBS_KEY_EQUAL",        mod = "" },
    { key = "+",         id = "OBS_KEY_PLUS",         mod = "" },
    { key = "-",         id = "OBS_KEY_MINUS",        mod = "" },
    { key = "#",         id = "OBS_KEY_NUMBERSIGN",   mod = "" },
    { key = "*",         id = "OBS_KEY_ASTERISK",     mod = "" },
    { key = "%",         id = "OBS_KEY_PERCENT",      mod = "" },
    { key = "$",         id = "OBS_KEY_DOLLAR",       mod = "" },
    { key = "!",         id = "OBS_KEY_EXCLAM",       mod = "" },
    { key = "_",         id = "OBS_KEY_UNDERSCORE",   mod = "" },
    { key = "<",         id = "OBS_KEY_LESS",         mod = "" },
    { key = ">",         id = "OBS_KEY_GRATER",       mod = "" },
    { key = "[",         id = "OBS_KEY_BRACKETLEFT",  mod = "" },
    { key = "]",         id = "OBS_KEY_BRACKETRIGHT", mod = "" },
    { key = "{",         id = "OBS_KEY_BRACELEFT",    mod = "" },
    { key = "}",         id = "OBS_KEY_BRACERIGHT",   mod = "" },
    { key = "(",         id = "OBS_KEY_PARENLEFT",    mod = "" },
    { key = ")",         id = "OBS_KEY_PARENRIGHT",   mod = "" },
    { key = ".",         id = "OBS_KEY_PERIOD",       mod = "" },
    { key = "'",         id = "OBS_KEY_APOSTROPHE",   mod = "" },
    { key = "\"",        id = "OBS_KEY_QUOTEDBL",     mod = "" },
    { key = ";",         id = "OBS_KEY_SEMICOLON",    mod = "" },
    { key = "/",         id = "OBS_KEY_SLASH",        mod = "" },
    { key = "\\",        id = "OBS_KEY_BACKSLASH",    mod = "" },
    { key = "?",         id = "OBS_KEY_QUESTION",     mod = "" },
    { key = "&",         id = "OBS_KEY_AMPERSAND",    mod = "" },
    { key = ":",         id = "OBS_KEY_COLON",        mod = "" },
    { key = " ",         id = "OBS_KEY_SPACE",        mod = "" },
    { key = "@",         id = "OBS_KEY_AT",           mod = "" },
    { key = "0",         id = "OBS_KEY_0",            mod = "" },
    { key = "1",         id = "OBS_KEY_1",            mod = "" },
    { key = "2",         id = "OBS_KEY_2",            mod = "" },
    { key = "3",         id = "OBS_KEY_3",            mod = "" },
    { key = "4",         id = "OBS_KEY_4",            mod = "" },
    { key = "5",         id = "OBS_KEY_5",            mod = "" },
    { key = "6",         id = "OBS_KEY_6",            mod = "" },
    { key = "7",         id = "OBS_KEY_7",            mod = "" },
    { key = "8",         id = "OBS_KEY_8",            mod = "" },
    { key = "9",         id = "OBS_KEY_9",            mod = "" },
    { key = "a",         id = "OBS_KEY_A",            mod = "" },
    { key = "b",         id = "OBS_KEY_B",            mod = "" },
    { key = "c",         id = "OBS_KEY_C",            mod = "" },
    { key = "d",         id = "OBS_KEY_D",            mod = "" },
    { key = "e",         id = "OBS_KEY_E",            mod = "" },
    { key = "f",         id = "OBS_KEY_F",            mod = "" },
    { key = "g",         id = "OBS_KEY_G",            mod = "" },
    { key = "h",         id = "OBS_KEY_H",            mod = "" },
    { key = "i",         id = "OBS_KEY_I",            mod = "" },
    { key = "j",         id = "OBS_KEY_J",            mod = "" },
    { key = "k",         id = "OBS_KEY_K",            mod = "" },
    { key = "l",         id = "OBS_KEY_L",            mod = "" },
    { key = "m",         id = "OBS_KEY_M",            mod = "" },
    { key = "n",         id = "OBS_KEY_N",            mod = "" },
    { key = "o",         id = "OBS_KEY_O",            mod = "" },
    { key = "p",         id = "OBS_KEY_P",            mod = "" },
    { key = "q",         id = "OBS_KEY_Q",            mod = "" },
    { key = "r",         id = "OBS_KEY_R",            mod = "" },
    { key = "s",         id = "OBS_KEY_S",            mod = "" },
    { key = "t",         id = "OBS_KEY_T",            mod = "" },
    { key = "u",         id = "OBS_KEY_U",            mod = "" },
    { key = "v",         id = "OBS_KEY_V",            mod = "" },
    { key = "w",         id = "OBS_KEY_W",            mod = "" },
    { key = "x",         id = "OBS_KEY_X",            mod = "" },
    { key = "y",         id = "OBS_KEY_Y",            mod = "" },
    { key = "z",         id = "OBS_KEY_Z",            mod = "" },
    { key = "A",         id = "OBS_KEY_A",            mod = "SHIFT" },
    { key = "B",         id = "OBS_KEY_B",            mod = "SHIFT" },
    { key = "C",         id = "OBS_KEY_C",            mod = "SHIFT" },
    { key = "D",         id = "OBS_KEY_D",            mod = "SHIFT" },
    { key = "E",         id = "OBS_KEY_E",            mod = "SHIFT" },
    { key = "F",         id = "OBS_KEY_F",            mod = "SHIFT" },
    { key = "G",         id = "OBS_KEY_G",            mod = "SHIFT" },
    { key = "H",         id = "OBS_KEY_H",            mod = "SHIFT" },
    { key = "I",         id = "OBS_KEY_I",            mod = "SHIFT" },
    { key = "J",         id = "OBS_KEY_J",            mod = "SHIFT" },
    { key = "K",         id = "OBS_KEY_K",            mod = "SHIFT" },
    { key = "L",         id = "OBS_KEY_L",            mod = "SHIFT" },
    { key = "M",         id = "OBS_KEY_M",            mod = "SHIFT" },
    { key = "N",         id = "OBS_KEY_N",            mod = "SHIFT" },
    { key = "O",         id = "OBS_KEY_O",            mod = "SHIFT" },
    { key = "P",         id = "OBS_KEY_P",            mod = "SHIFT" },
    { key = "Q",         id = "OBS_KEY_Q",            mod = "SHIFT" },
    { key = "R",         id = "OBS_KEY_R",            mod = "SHIFT" },
    { key = "S",         id = "OBS_KEY_S",            mod = "SHIFT" },
    { key = "T",         id = "OBS_KEY_T",            mod = "SHIFT" },
    { key = "U",         id = "OBS_KEY_U",            mod = "SHIFT" },
    { key = "V",         id = "OBS_KEY_V",            mod = "SHIFT" },
    { key = "W",         id = "OBS_KEY_W",            mod = "SHIFT" },
    { key = "X",         id = "OBS_KEY_X",            mod = "SHIFT" },
    { key = "Y",         id = "OBS_KEY_Y",            mod = "SHIFT" },
    { key = "Z",         id = "OBS_KEY_Z",            mod = "SHIFT" },
}

--  standard modifiers
local table_mods = {
    { mod = "SHIFT", val = obs.INTERACT_SHIFT_KEY   },
    { mod = "CTRL",  val = obs.INTERACT_CONTROL_KEY },
    { mod = "ALT",   val = obs.INTERACT_ALT_KEY     },
    { mod = "CMD",   val = obs.INTERACT_COMMAND_KEY },
}

--  inject keyboard event
local keyboard_event_inject = function (filter, kb, pressed)
    local isPressed = "no"
    if pressed then
        isPressed = "yes"
    end
    obs.script_log(obs.LOG_INFO,
        string.format("keyboard event: \"%s\" (pressed: %s)", kb, isPressed))

    --  helper function for splitting a string by separator character
    local split = function (str, sep)
        local fields = {}
        local pattern = string.format("([^%s]+)", sep)
        string.gsub(str, pattern, function(c) fields[#fields+1] = c end)
        return fields
    end

    --  helper function for mapping a modifier name to its value
    local lookupModifier = function (name)
        for _, row in pairs(table_mods) do
            if row.mod == name then
                return row.val
            end
        end
        return nil
    end

    --  parse keyboard event
    local keys = split(kb, "+ ")
    local n = table.getn(keys)
    if n == 0 then
        return
    end
    local M = 0
    local K = nil
    local key = keys[n]
    for _, row in pairs(table_keys) do
        if row.key == key then
            local k = obs.obs_key_from_name(row.id)
            K = obs.obs_key_to_virtual_key(k)
            if row.mod ~= "" then
                M = lookupModifier(row.mod)
            end
        end
    end
    if K == nil then
        obs.script_log(obs.LOG_ERROR, string.format("invalid key: \"%s\"", key))
        return
    end
    if n > 1 then
        for i = 1, n - 1 do
            M = bit.bor(M, lookupModifier(keys[i]))
        end
    end

    --  sanity check context
    if filter.parent == nil then
        obs.script_log(obs.LOG_WARNING,
            "still cannot send keyboard event, because parent source information is still not available")
        return
    end

    --  send keyboard event to source
    local event = obs.obs_key_event()
    event.native_vkey      = K
    event.modifiers        = M
    event.native_scancode  = K
    event.native_modifiers = M
    event.text             = ""
    obs.obs_source_send_key_click(filter.parent, event, pressed)
    obs.script_log(obs.LOG_INFO,
        string.format("keyboard event: sent: vkey %d, modifier %d", K, M))
end

--  update hotkeys
local keyboard_event_reconfigure = function (filter, settings)
    --  start new a fresh configuration
    local cfg = { nn2kb = {}, kb2id = {}, id2hk = {}, id2cb = {} }

    --  determine current keyboard events
    local events = obs.obs_data_get_array(settings, "keyboard_events")
    local n = obs.obs_data_array_count(events)
    for i = 0, n - 1 do
        local eventObj = obs.obs_data_array_item(events, i)
        local kb = obs.obs_data_get_string(eventObj, "value")
        obs.obs_data_release(eventObj)
        table.insert(cfg.nn2kb, kb)
        local id = string.format("%s: %s", filter.name, kb)
        cfg.kb2id[kb] = id
    end
    obs.obs_data_array_release(events)

    --  remove obsolete keyboard events
    for kb, id in pairs(filter.cfg.kb2id) do
        if not cfg.kb2id[kb] then
            obs.script_log(obs.LOG_INFO, string.format("keyboard event: \"%s\" [removed]", kb))
            local cb = filter.cfg.id2cb[id]
            obs.obs_hotkey_unregister(cb)
            filter.cfg.kb2id[kb] = nil
            filter.cfg.id2hk[id] = nil
            filter.cfg.id2cb[id] = nil
        end
    end

    --  create new keyboard events (or take over existing ones)
    for kb, id in pairs(cfg.kb2id) do
        if filter.cfg.kb2id[kb] then
            --  take over existing one
            cfg.id2cb[id] = filter.cfg.id2cb[id]
            cfg.id2hk[id] = filter.cfg.id2hk[id]
            obs.script_log(obs.LOG_INFO, string.format("keyboard event: \"%s\" [kept]", kb))
        else
            --  create new one
            cfg.id2cb[id] = function (pressed)
                keyboard_event_inject(filter, kb, pressed)
            end
            cfg.id2hk[id] = obs.obs_hotkey_register_frontend(id, id, cfg.id2cb[id])
            obs.script_log(obs.LOG_INFO, string.format("keyboard event: \"%s\" [created]", kb))
        end
    end

    --  replace configuration
    filter.cfg = cfg
end

--  hook: after loading settings
info.load = function (filter, settings)
    --  reconfigure (to make configuration available)
    keyboard_event_reconfigure(filter, settings)

    --  load hotkeys from settings
    for _, id in pairs(filter.cfg.kb2id) do
        local a = obs.obs_data_get_array(settings, id)
        obs.obs_hotkey_load(filter.cfg.id2hk[id], a)
        obs.obs_data_array_release(a)
    end
end

--  hook: before saving settings
info.save = function (filter, settings)
    --  reconfigure (to make configuration available)
    keyboard_event_reconfigure(filter, settings)

    --  save hotkeys to settings
    for _, id in pairs(filter.cfg.kb2id) do
        local a = obs.obs_hotkey_save(filter.cfg.id2hk[id])
        obs.obs_data_set_array(settings, id, a)
        obs.obs_data_array_release(a)
    end
end

--  hook: provide filter properties
info.get_properties = function (_filter)
    --  create properties
    local props = obs.obs_properties_create()
    obs.obs_properties_add_editable_list(props,
        "keyboard_events", "Keyboard Events:", obs.OBS_EDITABLE_LIST_TYPE_STRINGS, "", "")
    return props
end

--  hook: react on filter property update
info.update = function (filter, settings)
    --  reconfigure (because keyboard events might have changed)
    keyboard_event_reconfigure(filter, settings)
end

--  hook: render video
info.video_render = function (filter, _effect)
    if filter.parent == nil then
        filter.parent = obs.obs_filter_get_parent(filter.source)
    end
    if filter.parent ~= nil then
        filter.width  = obs.obs_source_get_base_width(filter.parent)
        filter.height = obs.obs_source_get_base_height(filter.parent)
    end
    obs.obs_source_skip_video_filter(filter.source)
end

--  hook: provide size
info.get_width = function (filter)
    return filter.width
end
info.get_height = function (filter)
    return filter.height
end

--  register the filter
obs.obs_register_source(info)

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Keyboard Event Filter</h2>

        Copyright &copy; 2021-2022 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Define a Keyboard Event filter for sources. This is intended
        to map OBS Studio global hotkeys onto keyboard events for
        Browser Source sources.</b>
        </p>

        <p>
        Use it by performing two steps:
        <ol>
            <li style="margin-bottom: 6px;">
                <b>DEFINE:</b> Add the "Keyboard Event" pseudo-effect
                filter to your Browser Source based source. Give it
                a globally unique name in case you are using this
                filter more than once inside your particular OBS
                Studio scene/source configuration (because the name
                is used as the prefix for the hotkey). Then define
                the available keyboard events in its properies. The
                syntax for defining keyboard events is "<tt>a</tt>",
                "<tt>SHIFT+a</tt>", "<tt>CTRL+a</tt>", "<tt>ALT+a</tt>"
                and "<tt>CMD+a</tt>".
            </li>
            <li>
                <b>MAP</b>: Map global OBS hotkeys onto
                the source keyboard events under <b>File
                &rarr; Settings &rarr; Hotkeys</b>. You can
                find the keyboard events under the name
                "<i>FilterName</i> <i>KeyboardEvent</i>".
                For example, <tt>Keyboard Event CTRL+a</tt>.
            </li>
        </ol>
        </p>
    ]]
end

