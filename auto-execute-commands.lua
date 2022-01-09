--[[
**
**  auto-execute-commands.lua -- OBS Studio Lua Script for Automatically Executing Commands
**  Copyright (c) 2021-2022 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
**
--]]

--  global OBS API
local obs = obslua

--  global context information
local ctx = {
    settings = nil,
    startExecPath = "",
    startExecClose = false,
    stopExecPath = ""
}

--  helper function: run start executable once
local function startExecOnce()
    if ctx.startExecPath == "" then
        return nil
    end
    local index = ctx.startExecPath:match("^.*()\\")
    local execDir = ctx.startExecPath:sub(1, index)
    local execName = ctx.startExecPath:sub(index + 1, ctx.startExecPath:len())
    local cmd = string.format("start \"\" /D \"%s\" \"%s\"", execDir, execName)
    obs.script_log(obs.LOG_INFO, string.format("executing command \"%s\"", cmd))
    os.execute(cmd)
end

--  helper function: run stop executable once
local function stopExecOnce()
    if ctx.stopExecPath == "" then
        return nil
    end
    local index = ctx.stopExecPath:match("^.*()\\")
    local execDir = ctx.stopExecPath:sub(1, index)
    local execName = ctx.stopExecPath:sub(index + 1, ctx.stopExecPath:len())
    local cmd = string.format("start \"\" /D \"%s\" \"%s\"", execDir, execName)
    obs.script_log(obs.LOG_INFO, string.format("executing command \"%s\"", cmd))
    os.execute(cmd)
end

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Automatically Execute Commands</h2>

        Copyright &copy; 2021 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/MIT.html">MIT license</a>

        <p>
        <b>Automatically execute commands when OBS Studio starts up and/or shuts down.</b>
    ]]
end

--  script hook: define UI properties
function script_properties ()
    --  create new properties
    local props = obs.obs_properties_create()
    obs.obs_properties_add_path(props, "startExecPath", "File",
        obs.OBS_PATH_FILE, "*.exe, *.bat, *.vbs, *.lnk, *.*", nil)
    obs.obs_properties_add_bool(props, "startExecClose", "Close again when OBS Studio shuts down?")
    obs.obs_properties_add_button(props, "startExecOnce", "Start Once", startExecOnce)
    obs.obs_properties_add_path(props, "stopExecPath", "File",
        obs.OBS_PATH_FILE, "*.exe, *.bat, *.vbs, *.lnk, *.*", nil)
    obs.obs_properties_add_button(props, "stopExecOnce", "Stop Once", stopExecOnce)
    return props
end

--  script hook: define property defaults
function script_defaults (settings)
    --  initialize property values
    obs.obs_data_set_default_string(settings, "startExecPath", "")
    obs.obs_data_set_default_bool(settings, "startExecClose", false)
    obs.obs_data_set_default_string(settings, "stopExecPath", "")
end

--  script hook: property values were updated
function script_update (settings)
    --  remember settings globally
    ctx.settings = settings

    --  fetch property values
    ctx.startExecPath  = obs.obs_data_get_string(settings, "startExecPath")
    ctx.startExecPath  = ctx.startExecPath:gsub("/", "\\")
    ctx.startExecClose = obs.obs_data_get_bool(settings, "startExecClose")
    ctx.stopExecPath   = obs.obs_data_get_string(settings, "stopExecPath")
    ctx.stopExecPath   = ctx.stopExecPath:gsub("/", "\\")
end

--  script hook: on script load
function script_load (settings)
    --  remember settings globally
    ctx.settings = settings

    --  run the start executable once
    startExecOnce()
end

--  script hook: on script unload
function script_unload ()
    --  close the start executable again
    if ctx.startExecClose then
        local cmd = string.format("taskkill /t /f /im \"%s\"", ctx.startExecName)
        obs.script_log(obs.LOG_INFO, string.format("executing command \"%s\"", cmd))
        os.execute(cmd)
    end

    --  run the stop executable once
    stopExecOnce()
end

