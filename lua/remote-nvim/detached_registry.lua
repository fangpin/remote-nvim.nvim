local Path = require("plenary.path")

---@class remote-nvim.DetachedRegistry: remote-nvim.Object
---@field private _path table
---@field private _data table<string, table>
local DetachedRegistry = require("remote-nvim.middleclass")("DetachedRegistry")

function DetachedRegistry:init()
  self._path = Path:new({ vim.fn.stdpath("data"), "remote-nvim", "detached.json" })
  self._path:touch({ mode = 493, parents = true })

  self._data = self:_load()
end

function DetachedRegistry:_load()
  local raw = self._path:read()
  if raw == "" then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  return ok and type(decoded) == "table" and decoded or {}
end

function DetachedRegistry:_write()
  self._path:write(vim.json.encode(self._data), "w")
end

function DetachedRegistry:get_all()
  return self._data
end

function DetachedRegistry:get(host_id)
  return self._data[host_id] or {}
end

function DetachedRegistry:upsert(host_id, record)
  self._data = self:_load()
  self._data[host_id] = vim.tbl_extend("force", self:get(host_id), record)
  self:_write()
  return self._data[host_id]
end

function DetachedRegistry:mark_stale(host_id)
  return self:upsert(host_id, { status = "stale", last_seen_at = os.time() })
end

function DetachedRegistry:remove(host_id)
  self._data = self:_load()
  self._data[host_id] = nil
  self:_write()
end

return DetachedRegistry
