describe("DetachedRegistry", function()
  local assert = require("luassert.assert")
  local stub = require("luassert.stub")
  local registry
  local stdpath_stub
  local tmpdir

  local function load_registry()
    package.loaded["remote-nvim.detached_registry"] = nil
    registry = require("remote-nvim.detached_registry")()
  end

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    stdpath_stub = stub(vim.fn, "stdpath").returns(tmpdir)
    load_registry()
  end)

  after_each(function()
    stdpath_stub:revert()
    package.loaded["remote-nvim.detached_registry"] = nil
    vim.fn.delete(tmpdir, "rf")
  end)

  it("starts empty when detached registry file is missing", function()
    assert.same({}, registry:get_all())
  end)

  it("adds, updates, and removes detached records", function()
    registry:upsert("host-a", {
      provider = "ssh",
      host = "host-a",
      remote_port = "32123",
      remote_pid = "4455",
      status = "detached",
    })

    assert.equals("32123", registry:get("host-a").remote_port)

    registry:mark_stale("host-a")
    assert.equals("stale", registry:get("host-a").status)

    registry:remove("host-a")
    assert.same({}, registry:get("host-a"))
  end)

  it("loads persisted records from disk", function()
    registry:upsert("host-a", { provider = "ssh", host = "host-a", status = "detached" })
    load_registry()

    assert.equals("detached", registry:get("host-a").status)
  end)

  it("falls back to an empty registry when the file is corrupt", function()
    vim.fn.writefile({ "not json" }, tmpdir .. "/remote-nvim/detached.json")
    load_registry()

    assert.same({}, registry:get_all())
  end)
end)
