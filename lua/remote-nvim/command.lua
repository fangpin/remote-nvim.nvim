local devpod_utils = require("remote-nvim.providers.devpod.devpod_utils")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local M = {}

function M.RemoteStart(opts)
  local host_identifier = vim.trim(opts.args)
  if host_identifier == "" then
    require("telescope").extensions["remote-nvim"].connect()
  else
    ---@type remote-nvim.providers.WorkspaceConfig
    local workspace_config =
      remote_nvim.session_provider:get_config_provider():get_workspace_config(vim.trim(host_identifier))
    if vim.tbl_isempty(workspace_config) then
      vim.notify("Unknown host identifier. Run :RemoteStart to connect to a new host", vim.log.levels.ERROR)
    else
      remote_nvim.session_provider
        :get_or_initialize_session({
          host = workspace_config.host,
          provider_type = workspace_config.provider,
          conn_opts = { workspace_config.connection_options },
          unique_host_id = host_identifier,
          devpod_opts = devpod_utils.get_workspace_devpod_opts(workspace_config),
        })
        :launch_neovim()
    end
  end
end

vim.api.nvim_create_user_command("RemoteStart", M.RemoteStart, {
  nargs = "?",
  desc = "Start Neovim on remote machine",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local valid_hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
    if #args == 0 then
      return valid_hosts
    end
    return vim.fn.matchfuzzy(valid_hosts, args[1])
  end,
})

function M.RemoteLog()
  vim.api.nvim_cmd({
    cmd = "tabnew",
    args = { remote_nvim.config.log.filepath },
  }, {})
end

vim.api.nvim_create_user_command("RemoteLog", M.RemoteLog, {
  desc = "Open Remote Neovim logs",
})

function M.RemoteCleanup(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  if #host_ids > 1 then
    error("Please pass only one parameter at a time")
  end
  for _, host_id in ipairs(host_ids) do
    ---@type remote-nvim.providers.WorkspaceConfig
    local workspace_config = remote_nvim.session_provider:get_config_provider():get_workspace_config(host_id)

    if vim.tbl_isempty(workspace_config) then
      vim.notify("Unknown host identifier. Run :RemoteStart to connect to a new host", vim.log.levels.ERROR)
    else
      remote_nvim.session_provider
        :get_or_initialize_session({
          host = workspace_config.host,
          provider_type = workspace_config.provider,
          conn_opts = { workspace_config.connection_options },
          unique_host_id = host_id,
          devpod_opts = devpod_utils.get_workspace_devpod_opts(workspace_config),
        })
        :clean_up_remote_host()
    end
  end
end

vim.api.nvim_create_user_command("RemoteInfo", function(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local sessions = remote_nvim.session_provider:get_all_sessions()

  if #vim.tbl_keys(sessions) == 0 then
    vim.notify("No active sessions found. Please start remote session(s) with :RemoteStart first", vim.log.levels.WARN)
    return
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local session = sessions[host_ids[1]]

    if session == nil then
      vim.notify(("No active remote session to %s found"):format(host_ids[1]), vim.log.levels.WARN)
    else
      session:show_progress_view_window()
    end
  else
    vim.ui.select(vim.tbl_keys(sessions), {
      prompt = "Choose remote neovim session",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        sessions[choice]:show_progress_view_window()
      end
    end)
  end
end, {
  desc = "View Remote Neovim launched session's information",
  nargs = "?",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)

    -- Filter out those sessions whose port forwarding jobs are not running
    local active_sessions = remote_nvim.session_provider:get_all_sessions()
    local running_sessions = vim.tbl_keys(active_sessions)

    if #args == 0 then
      return running_sessions
    end
    local host_ids = vim.fn.filter(running_sessions, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(running_sessions, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(running_sessions, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteCleanup", M.RemoteCleanup, {
  desc = "Clean up Remote Neovim created resources from remote machine",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local valid_hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
    if #args == 0 then
      return valid_hosts
    end
    local host_ids = vim.fn.filter(valid_hosts, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(valid_hosts, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

local function get_running_sessions(filter)
  local sessions = remote_nvim.session_provider:get_all_sessions()
  local running_sessions = {}
  for host_id, session in pairs(sessions) do
    if session:is_remote_server_running() and (filter == nil or filter(session)) then
      table.insert(running_sessions, host_id)
    end
  end
  table.sort(running_sessions)

  return sessions, running_sessions
end

local function is_ssh_session(session)
  return session.provider_type == "ssh"
end

local function get_running_ssh_sessions()
  return get_running_sessions(is_ssh_session)
end

local function complete_running_sessions(_, line)
  local args = vim.split(vim.trim(line), "%s+")
  table.remove(args, 1)

  local _, running_sessions = get_running_sessions()

  if #args == 0 then
    return running_sessions
  end
  local host_ids = vim.fn.filter(running_sessions, function(_, item)
    return not vim.tbl_contains(args, item)
  end)
  local completion_word = table.remove(args, #args)

  -- If we have not provided any input, then the last word is the last completion
  if vim.tbl_contains(running_sessions, completion_word) then
    return host_ids
  end
  return vim.fn.matchfuzzy(running_sessions, completion_word)
end

function M._detached_registry()
  return require("remote-nvim.detached_registry")()
end

local function get_detached_records()
  return M._detached_registry():get_all()
end

local function is_reattachable_detached_record(record)
  return record.status ~= "stale"
end

local function get_reattachable_detached_records()
  local records = get_detached_records()
  local reattachable_records = {}
  for host_id, record in pairs(records) do
    if is_reattachable_detached_record(record) then
      reattachable_records[host_id] = record
    end
  end
  return reattachable_records
end

local function get_detached_record(host_id, opts)
  opts = opts or {}
  local record = M._detached_registry():get(host_id)
  if vim.tbl_isempty(record) then
    vim.notify(("No detached remote session to '%s' found"):format(host_id), vim.log.levels.WARN)
    return nil
  end
  if opts.require_reattachable and not is_reattachable_detached_record(record) then
    vim.notify(
      ("Detached session '%s' is stale. Use :RemoteKillDetached %s to clear it"):format(host_id, host_id),
      vim.log.levels.WARN
    )
    return nil
  end
  return record
end

local function complete_detached_sessions(_, line, opts)
  opts = opts or {}
  local args = vim.split(vim.trim(line), "%s+")
  table.remove(args, 1)

  local records = opts.reattachable_only and get_reattachable_detached_records() or get_detached_records()
  local detached_sessions = vim.tbl_keys(records)
  table.sort(detached_sessions)

  if #args == 0 then
    return detached_sessions
  end
  local host_ids = vim.fn.filter(detached_sessions, function(_, item)
    return not vim.tbl_contains(args, item)
  end)
  local completion_word = table.remove(args, #args)

  -- If we have not provided any input, then the last word is the last completion
  if vim.tbl_contains(detached_sessions, completion_word) then
    return host_ids
  end
  return vim.fn.matchfuzzy(host_ids, completion_word)
end

local function get_session_for_detached_record(host_id, record)
  return remote_nvim.session_provider:get_or_initialize_session({
    host = record.host,
    provider_type = record.provider,
    conn_opts = { record.connection_options },
    unique_host_id = host_id,
    working_dir = record.working_dir,
  })
end

function M.RemoteDetach(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local sessions, running_sessions = get_running_ssh_sessions()

  if #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local host_id = host_ids[1]
    local session = sessions[host_id]

    if session == nil or not session:is_remote_server_running() then
      vim.notify(("No active remote session to '%s' found"):format(host_id), vim.log.levels.WARN)
    elseif not is_ssh_session(session) then
      vim.notify("Detach is only supported for SSH sessions", vim.log.levels.WARN)
    else
      session:detach_neovim()
    end
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif (#vim.tbl_keys(sessions) == 0) or #running_sessions == 0 then
    vim.notify("No active sessions found. Please start remote session(s) with :RemoteStart first", vim.log.levels.WARN)
    return
  elseif #running_sessions == 1 then
    sessions[running_sessions[1]]:detach_neovim()
  else
    vim.ui.select(running_sessions, {
      prompt = "Choose active session that needs to be detached",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        sessions[choice]:detach_neovim()
      end
    end)
  end
end

vim.api.nvim_create_user_command("RemoteDetach", M.RemoteDetach, {
  desc = "Detach running Remote Neovim launched Neovim server",
  nargs = "?",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)

    local _, running_sessions = get_running_ssh_sessions()

    if #args == 0 then
      return running_sessions
    end
    local host_ids = vim.fn.filter(running_sessions, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    if vim.tbl_contains(running_sessions, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(running_sessions, completion_word)
  end,
})

function M.RemoteReattach(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local detached_records = get_reattachable_detached_records()

  if #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local host_id = host_ids[1]
    local record = get_detached_record(host_id, { require_reattachable = true })
    if record then
      get_session_for_detached_record(host_id, record):reattach_neovim(record)
    end
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif vim.tbl_isempty(detached_records) then
    vim.notify("No detached sessions found", vim.log.levels.WARN)
    return
  else
    local detached_sessions = vim.tbl_keys(detached_records)
    table.sort(detached_sessions)
    vim.ui.select(detached_sessions, {
      prompt = "Choose detached session to reattach",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        local record = detached_records[choice]
        get_session_for_detached_record(choice, record):reattach_neovim(record)
      end
    end)
  end
end

vim.api.nvim_create_user_command("RemoteReattach", M.RemoteReattach, {
  desc = "Reattach a detached Remote Neovim session",
  nargs = "?",
  complete = function(_, line)
    return complete_detached_sessions(_, line, { reattachable_only = true })
  end,
})

function M.RemoteKillDetached(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local detached_records = get_detached_records()

  if #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local host_id = host_ids[1]
    local record = get_detached_record(host_id)
    if record then
      get_session_for_detached_record(host_id, record):kill_detached_neovim(record)
    end
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif vim.tbl_isempty(detached_records) then
    vim.notify("No detached sessions found", vim.log.levels.WARN)
    return
  else
    local detached_sessions = vim.tbl_keys(detached_records)
    table.sort(detached_sessions)
    vim.ui.select(detached_sessions, {
      prompt = "Choose detached session to kill or clear",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        local record = detached_records[choice]
        get_session_for_detached_record(choice, record):kill_detached_neovim(record)
      end
    end)
  end
end

vim.api.nvim_create_user_command("RemoteKillDetached", M.RemoteKillDetached, {
  desc = "Kill or clear a detached Remote Neovim session",
  nargs = "?",
  complete = complete_detached_sessions,
})

vim.api.nvim_create_user_command("RemoteStop", function(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local sessions, running_sessions = get_running_sessions()

  if #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local session = sessions[host_ids[1]]

    if session == nil or not session:is_remote_server_running() then
      vim.notify(("No active remote session to '%s' found"):format(host_ids[1]), vim.log.levels.WARN)
    else
      session:stop_neovim()
    end
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif (#vim.tbl_keys(sessions) == 0) or #running_sessions == 0 then
    vim.notify("No active sessions found. Please start remote session(s) with :RemoteStart first", vim.log.levels.WARN)
    return
  else
    vim.ui.select(running_sessions, {
      prompt = "Choose active session that needs to be closed",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        sessions[choice]:stop_neovim()
      end
    end)
  end
end, {
  desc = "Stop running Remote Neovim launched Neovim server",
  nargs = "?",
  complete = complete_running_sessions,
})

local remote_clipboard_check_lua = [=[
local clipboard = vim.g.clipboard
local clipboard_type = type(clipboard)
local clipboard_name = nil
local copy_plus = nil
local copy_star = nil
local paste_plus = nil
local paste_star = nil
if clipboard_type == "table" then
  clipboard_name = clipboard.name
  copy_plus = type(clipboard.copy) == "table" and type(clipboard.copy["+"]) or nil
  copy_star = type(clipboard.copy) == "table" and type(clipboard.copy["*"]) or nil
  paste_plus = type(clipboard.paste) == "table" and type(clipboard.paste["+"]) or nil
  paste_star = type(clipboard.paste) == "table" and type(clipboard.paste["*"]) or nil
end

local osc52_available = pcall(require, "vim.ui.clipboard.osc52")
local remote_clipboard = vim.g.remote_nvim_clipboard
return {
  clipboard_option = tostring(vim.o.clipboard),
  clipboard_type = clipboard_type,
  clipboard_name = clipboard_name,
  copy_plus = copy_plus,
  copy_star = copy_star,
  paste_plus = paste_plus,
  paste_star = paste_star,
  osc52_available = osc52_available,
  loaded_clipboard_provider = vim.g.loaded_clipboard_provider,
  remote_nvim_clipboard = remote_clipboard,
  ui_count = #vim.api.nvim_list_uis(),
}
]=]

local function is_missing(value)
  return value == nil or value == vim.NIL or value == false or value == "nil"
end

local function format_value(value)
  if value == nil or value == vim.NIL then
    return "nil"
  end
  if type(value) == "boolean" then
    return value and "true" or "false"
  end
  return tostring(value)
end

local function format_remote_clipboard(value)
  if type(value) ~= "table" then
    return format_value(value)
  end

  local parts = {}
  for _, key in ipairs({ "installed", "provider", "name", "source", "install_count", "last_error" }) do
    if value[key] ~= nil and value[key] ~= vim.NIL then
      table.insert(parts, ("%s=%s"):format(key, format_value(value[key])))
    end
  end
  return table.concat(parts, ", ")
end

local function clipboard_option_has_unnamedplus(value)
  return vim.tbl_contains(vim.split(tostring(value or ""), ",", { trimempty = true }), "unnamedplus")
end

local function clipboard_diagnostics_missing(result)
  return not clipboard_option_has_unnamedplus(result.clipboard_option)
    or result.clipboard_type ~= "table"
    or is_missing(result.clipboard_name)
    or result.copy_plus ~= "function"
    or result.copy_star ~= "function"
    or result.paste_plus ~= "function"
    or result.paste_star ~= "function"
    or result.osc52_available ~= true
    or type(result.remote_nvim_clipboard) ~= "table"
    or result.remote_nvim_clipboard.installed ~= true
end

local function notify_clipboard_diagnostics(host_id, result)
  local lines = {
    ("Remote clipboard diagnostics for %s"):format(host_id),
    ("clipboard option: %s"):format(format_value(result.clipboard_option)),
    ("clipboard provider: %s (%s)"):format(format_value(result.clipboard_name), format_value(result.clipboard_type)),
    ("copy +/*: %s/%s"):format(format_value(result.copy_plus), format_value(result.copy_star)),
    ("paste +/*: %s/%s"):format(format_value(result.paste_plus), format_value(result.paste_star)),
    ("osc52 available: %s"):format(format_value(result.osc52_available)),
    ("loaded clipboard provider: %s"):format(format_value(result.loaded_clipboard_provider)),
    ("remote-nvim clipboard: %s"):format(format_remote_clipboard(result.remote_nvim_clipboard)),
    ("attached UIs: %s"):format(format_value(result.ui_count)),
  }

  local level = clipboard_diagnostics_missing(result) and vim.log.levels.WARN or vim.log.levels.INFO
  vim.notify(table.concat(lines, "\n"), level)
end

local function check_clipboard_for_session(host_id, session)
  local port = session:get_local_neovim_server_port()
  if is_missing(port) or tostring(port) == "" then
    vim.notify(("No local Neovim server port found for '%s'"):format(host_id), vim.log.levels.ERROR)
    return
  end

  local ok_connect, chan = pcall(vim.fn.sockconnect, "tcp", ("localhost:%s"):format(port), { rpc = true })
  if not ok_connect or is_missing(chan) or chan == 0 then
    vim.notify(
      ("Failed to connect to remote Neovim server for '%s': %s"):format(host_id, format_value(chan)),
      vim.log.levels.ERROR
    )
    return
  end

  local ok_rpc, result = pcall(vim.rpcrequest, chan, "nvim_exec_lua", remote_clipboard_check_lua, {})
  pcall(vim.fn.chanclose, chan)

  if not ok_rpc then
    vim.notify(
      ("Failed to query remote clipboard diagnostics for '%s': %s"):format(host_id, format_value(result)),
      vim.log.levels.ERROR
    )
    return
  end

  if type(session.set_clipboard_diagnostics) == "function" then
    session:set_clipboard_diagnostics(result)
  end

  notify_clipboard_diagnostics(host_id, result)
end

function M.RemoteClipboardCheck(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local sessions, running_sessions = get_running_sessions()

  if #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local host_id = host_ids[1]
    local session = sessions[host_id]

    if session == nil or not session:is_remote_server_running() then
      vim.notify(("No active remote session to '%s' found"):format(host_id), vim.log.levels.WARN)
    else
      check_clipboard_for_session(host_id, session)
    end
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif (#vim.tbl_keys(sessions) == 0) or #running_sessions == 0 then
    vim.notify("No active sessions found. Please start remote session(s) with :RemoteStart first", vim.log.levels.WARN)
    return
  elseif #running_sessions == 1 then
    local host_id = running_sessions[1]
    check_clipboard_for_session(host_id, sessions[host_id])
  else
    vim.ui.select(running_sessions, {
      prompt = "Choose remote neovim session for clipboard diagnostics",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        check_clipboard_for_session(choice, sessions[choice])
      end
    end)
  end
end

vim.api.nvim_create_user_command("RemoteClipboardCheck", M.RemoteClipboardCheck, {
  desc = "Check Remote Neovim clipboard diagnostics",
  nargs = "?",
  complete = complete_running_sessions,
})

vim.api.nvim_create_user_command("RemoteConfigDel", function(opts)
  local host_identifiers = vim.split(vim.trim(opts.args), "%s+")
  for _, host_id in ipairs(host_identifiers) do
    remote_nvim.session_provider:get_config_provider():remove_workspace_config(host_id)
  end
  vim.notify("Workspace configuration(s) deleted")
end, {
  desc = "Delete Remote Neovim workspace record",
  nargs = "+",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
    if #args == 0 then
      return hosts
    end
    local host_ids = vim.fn.filter(hosts, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(hosts, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

return M
